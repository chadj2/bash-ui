##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-panel-vmenu.sh
# Description:  Display a scrollable vertical menu.
##

# placeholder for empty data set
declare -r VMENU_EMPTY_TEXT="<empty>"

# Data indexes
declare -i vmenu_idx_active
declare -i vmenu_idx_last
declare -a vmenu_data_values

# panel geometry
declare -i vmenu_height
declare -i vmenu_width
declare -i vmenu_row_pos

# indexes at the top and bottom of panel
declare -i vmenu_idx_panel_top

# last index in panel that has data
declare -i vmenu_idx_panel_end

# if non-zero then an indicator will show a row as being "checked".
declare -i vmenu_idx_checked=-1

# debug statistics only
declare -i vmenu_idx_redraws=0

function fn_vmenu_init()
{
    # Geometry
    vmenu_height=$((BIW_PANEL_HEIGHT - HMENU_HEIGHT))
    vmenu_width=$BIW_PANEL_WIDTH
    vmenu_row_pos=$HMENU_HEIGHT

    # get refrence to array with menu entries
    vmenu_data_values=( "${!1-$VMENU_EMPTY_TEXT}" )
    local -i vmenu_data_size=${#vmenu_data_values[*]}
    vmenu_idx_last=$((vmenu_data_size - 1))

    # set active index if passed as an argument. Else default to 0.
    vmenu_idx_active=${2:-0}
    vmenu_idx_checked=-1

    # panel display area defaults to the start of the list. This 
    # be adjusted by redraw.
    vmenu_idx_panel_top=0
}

fn_vmenu_actions()
{
    local _key=$1

    case "$_key" in
        $CSI_KEY_UP)
            fn_vmenu_action_up
            return $?
            ;;
        $CSI_KEY_DOWN)
            fn_vmenu_action_down
            return $?
            ;;
        $CSI_KEY_PG_UP)
            fn_vmenu_action_page_up
            return $?
            ;;
        $CSI_KEY_PG_DOWN)
            fn_vmenu_action_page_down
            return $?
            ;;
        $CSI_KEY_HOME)
            fn_vmenu_action_home
            return $?
            ;;
        $CSI_KEY_END)
            fn_vmenu_action_end
            return $?
            ;;
    esac

    fn_biw_debug_msg "BIW_ACT_IGNORED: _key=%s" "$_key"
    return $BIW_ACT_IGNORED
}

function fn_vmenu_get_current_val()
{
    echo ${vmenu_data_values[$vmenu_idx_active]}
}

function fn_vmenu_action_down()
{
    if ((vmenu_idx_active >= vmenu_idx_last))
    then
        # we are at the end of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    # move active index
    ((vmenu_idx_active += 1))

    if ((vmenu_idx_active > vmenu_idx_panel_end))
    then
        # new index has exceeded the bounds of the window
        ((vmenu_idx_panel_top += 1))
        fn_vmenu_redraw
    else
        # redraw affected rows
        fn_vmenu_draw_row $((vmenu_idx_active - 1))
        fn_vmenu_draw_row $vmenu_idx_active

        fn_biw_debug_msg "idx=%s" $vmenu_idx_active
    fi

    return $BIW_ACT_HANDLED
}

function fn_vmenu_action_up()
{
    if ((vmenu_idx_active <= 0))
    then
        # we are at the start of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    ((vmenu_idx_active -= 1))

    if ((vmenu_idx_active < vmenu_idx_panel_top))
    then
        # new index has exceeded the bounds of the window
        ((vmenu_idx_panel_top -= 1))
        fn_vmenu_redraw
    else
        # redraw affected rows
        fn_vmenu_draw_row $((vmenu_idx_active + 1))
        fn_vmenu_draw_row $vmenu_idx_active

        fn_biw_debug_msg "idx=%s" $vmenu_idx_active
    fi

    return $BIW_ACT_HANDLED
}

function fn_vmenu_action_page_down()
{
    if ((vmenu_idx_active >= vmenu_idx_last))
    then
        # we are at the end of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    ((vmenu_idx_active += vmenu_height))

    if((vmenu_idx_active > vmenu_idx_last))
    then
        vmenu_idx_active=$vmenu_idx_last
    fi

    fn_vmenu_redraw

    return $BIW_ACT_HANDLED
}

function fn_vmenu_action_page_up()
{
    if ((vmenu_idx_active <= 0))
    then
        # we are at the end of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    ((vmenu_idx_active -= vmenu_height))

    if((vmenu_idx_active <= 0))
    then
        vmenu_idx_active=0
    fi

    fn_vmenu_redraw

    return $BIW_ACT_HANDLED
}

function fn_vmenu_action_home()
{
    if ((vmenu_idx_active <= 0))
    then
        # we are at the end of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    vmenu_idx_active=0
    fn_vmenu_redraw

    return $BIW_ACT_HANDLED
}

function fn_vmenu_action_end()
{
    if ((vmenu_idx_active >= vmenu_idx_last))
    then
        # we are at the end of the data so we can't move
        return $BIW_ACT_IGNORED
    fi

    vmenu_idx_active=$vmenu_idx_last
    fn_vmenu_redraw

    return $BIW_ACT_HANDLED
}

function fn_vmenu_redraw()
{
    # snap window up to the active row
    if((vmenu_idx_panel_top > vmenu_idx_active))
    then
        vmenu_idx_panel_top=$vmenu_idx_active
    fi

    local -i _idx_panel_bottom=$((vmenu_idx_panel_top + vmenu_height - 1))

    # snap window down to the active row
    if((_idx_panel_bottom < vmenu_idx_active))
    then
        ((vmenu_idx_panel_top += (vmenu_idx_active - _idx_panel_bottom)))
        _idx_panel_bottom=$vmenu_idx_active
    fi

    # adjust the last index if there are not enough values to display
    vmenu_idx_panel_end=${_idx_panel_bottom}

    if((vmenu_idx_panel_end > vmenu_idx_last))
    then
        vmenu_idx_panel_end=$vmenu_idx_last
    fi

    fn_biw_debug_msg 'fn_vmenu_redraw <A=%s T=%s E=%s B=%s>' \
        $vmenu_idx_active \
        $vmenu_idx_panel_top \
        $vmenu_idx_panel_end \
        $_idx_panel_bottom
    
    # draw all menu items
    for((_line_idx = vmenu_idx_panel_top; _line_idx <= _idx_panel_bottom; _line_idx++))
    do
        fn_vmenu_draw_row $_line_idx
    done

    ((vmenu_idx_redraws++))
}

function fn_vmenu_draw_row()
{
    local -i _line_idx=$1

    # position cursor
    local -i _abs_index=$((_line_idx - vmenu_idx_panel_top))
    local -i _row_pos=$((vmenu_row_pos + _abs_index))
    fn_biw_set_cursor_pos $_row_pos 0

    if((_line_idx > vmenu_idx_last))
    then
        # no data to draw so erase row
        fn_csi_op $CSI_OP_ROW_ERASE
        return
    fi

    fn_sgr_seq_start

        fn_menu_draw_indicator $_line_idx
        local -i _ind_width=$?
        local -i _selection_width=$((vmenu_width - _ind_width - 1))
        fn_vmenu_draw_selection $_line_idx $_selection_width
        fn_vmenu_draw_slider $_line_idx

    fn_sgr_seq_flush

    # reset colors
    fn_sgr_set $SGR_ATTR_DEFAULT
}

function fn_menu_draw_indicator()
{
    local -i _line_idx=$1
    local _line_indicator
    local -i _line_indicator_size

    if ((vmenu_idx_checked >= 0))
    then
        _line_indicator_size=1
        _line_indicator=' '

        if((_line_idx == vmenu_idx_checked))
        then
            _line_indicator=$CSI_CHAR_DIAMOND
        fi
    else
        _line_indicator=$_line_idx
        _line_indicator_size=${#_line_indicator}
    fi

    _line_indicator="[${_line_indicator}]"
    ((_line_indicator_size += 2))

    fn_theme_set_attr_slider $((vmenu_idx_active == _line_idx))
    fn_sgr_print "${_line_indicator}"

    return $_line_indicator_size
}

function fn_vmenu_draw_selection()
{
    local -i _line_idx=$1
    local -i _print_width=$2

    # get line data from array and add space padding
    local _line_result=" ${vmenu_data_values[$_line_idx]}"
    fn_csi_pad_string "_line_result" $_print_width

    fn_theme_set_attr_default $((vmenu_idx_active == _line_idx))
    fn_sgr_print "${_line_result}"
}

function fn_vmenu_draw_slider()
{
    local -i _line_idx=$1
    local _last_char=$CSI_CHAR_LINE_VERT

    if ((_line_idx == vmenu_idx_panel_top))
    then
        # Top charachter
        if ((_line_idx == 0))
        then
            _last_char=$CSI_CHAR_LINE_TOP_T
        else
            _last_char='^'
        fi
    elif ((_line_idx == vmenu_idx_panel_end))
    then
        # Bottom Charachter
        if ((_line_idx == vmenu_idx_last))
        then
            _last_char=$CSI_CHAR_LINE_BOTTOM_T
        else
            _last_char='v'
        fi
    fi

    fn_theme_set_attr_slider $((vmenu_idx_active == _line_idx))
    fn_sgr_print "${_last_char}"
}
