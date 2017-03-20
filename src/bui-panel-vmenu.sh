##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-panel-vmenu.sh
# Description:  Display a scrollable vertical menu.
##

# placeholder for empty data set
declare -r VMENU_EMPTY_TEXT='<empty>'

# Data indexes
declare -i vmenu_idx_selected
declare -i vmenu_idx_last
declare -a vmenu_data_values

# panel geometry
declare -i vmenu_row_size
declare -i vmenu_col_size
declare -i vmenu_row_pos

# indexes at the top and bottom of panel
declare -i vmenu_idx_panel_top

# last index in panel that has data
declare -i vmenu_idx_panel_end

# index of the bottom row the panel (could be outside data set)
declare -i vmenu_idx_panel_bottom

# List of indicators displayed before the data.
declare -a vmenu_ind_values

# debug statistics only
declare -i vmenu_idx_redraws=0

# display a message at the bottom
declare vmenu_footer_message
declare -i vmenu_footer_show=0

function fn_vmenu_init()
{
    # get refrence to array with menu entries
    vmenu_data_values=( "${!1:-$VMENU_EMPTY_TEXT}" )
    local -i vmenu_data_size=${#vmenu_data_values[*]}

    # set active index if passed as an argument. Else default to 0.
    vmenu_idx_selected=${2:-0}

    # Geometry
    vmenu_row_pos=$((hmenu_row_pos + 1))
    vmenu_row_size=$((bui_panel_row_size - vmenu_row_pos))
    vmenu_col_size=$bui_panel_col_size
    vmenu_footer_show=0

    # panel display area defaults to the start of the list. This 
    # be adjusted by redraw.
    vmenu_idx_last=$((vmenu_data_size - 1))
    vmenu_idx_panel_top=0

    vmenu_ind_values=()
}

fn_vmenu_actions()
{
    local _key=$1
    local _result=$UTIL_ACT_IGNORED

    case "$_key" in
        $CSI_KEY_UP)
            if ((vmenu_idx_selected == 0))
            then
                # user pressed up on first row so exit controller
                util_exit_dispatcher=1
                break
            fi
            fn_vmenu_action_move -1
            _result=$?
            ;;
        $CSI_KEY_DOWN)
            fn_vmenu_action_move 1
            _result=$?
            ;;
        $CSI_KEY_PG_UP)
            fn_vmenu_action_move $((-1 * vmenu_row_size))
            _result=$?
            ;;
        $CSI_KEY_PG_DOWN)
            fn_vmenu_action_move $((vmenu_row_size))
            _result=$?
            ;;
        $CSI_KEY_HOME)
            fn_vmenu_action_move $((-1 * vmenu_idx_selected))
            _result=$?
            ;;
        $CSI_KEY_END)
            fn_vmenu_action_move $((vmenu_idx_last - vmenu_idx_selected))
            _result=$?
            ;;
    esac

    return $_result
}

function fn_vmenu_set_message()
{
    vmenu_footer_message=$1

    if((vmenu_footer_show == 0))
    then
        # make space for footer message
        ((vmenu_row_size--))
        vmenu_footer_show=1
    fi
}

function fn_vmenu_set_checked()
{
    vmenu_ind_values=( [vmenu_idx_selected]=$BUI_CHAR_BULLET )
}

function fn_vmenu_get_current_val()
{
    local _result_ref=$1
    printf -v $_result_ref '%s' "${vmenu_data_values[$vmenu_idx_selected]}"
}

function fn_vmenu_action_move()
{
    local -i _relative_idx=$1
    local -i _new_idx=$((vmenu_idx_selected + _relative_idx))

    if((_new_idx < 0))
    then
        _new_idx=0
    fi

    if((_new_idx >= vmenu_idx_last))
    then
        _new_idx=$vmenu_idx_last
    fi

    if ((vmenu_idx_selected == _new_idx))
    then
        # no change
        return $UTIL_ACT_IGNORED
    fi

    local -i _old_idx=vmenu_idx_selected
    vmenu_idx_selected=$_new_idx

    if (((vmenu_idx_selected >= vmenu_idx_panel_top) 
        && (vmenu_idx_selected <= vmenu_idx_panel_end)))
    then
        # moving selection within existing bounds
        fn_vmenu_draw_row $_old_idx
        fn_vmenu_draw_row $vmenu_idx_selected

        fn_util_debug_msg 'old_idx=%+d new_idx=%d' $_old_idx $vmenu_idx_selected
        return $UTIL_ACT_CHANGED
    fi

    if((_relative_idx == -1 || _relative_idx == 1))
    then
        # use fast single row scroll
        fn_vmenu_fast_scroll $_relative_idx
        return $UTIL_ACT_CHANGED
    fi

    # redraw entire screen
    fn_vmenu_redraw

    return $UTIL_ACT_CHANGED
}

function fn_vmenu_fast_scroll()
{
    local -i _direction=$1

    # draw the row to be scrolled to update the selection color
    fn_vmenu_draw_row $((vmenu_idx_selected - _direction)) $_direction

    fn_csi_scroll_region $vmenu_row_pos $vmenu_row_size $_direction

    ((vmenu_idx_panel_top += _direction))
    ((vmenu_idx_panel_end += _direction))

    fn_vmenu_draw_row $((vmenu_idx_panel_top))
    fn_vmenu_draw_row $((vmenu_idx_panel_top + vmenu_row_size - 1))

    #fn_vmenu_redraw
    fn_util_debug_msg 'direction=%+d idx=%d' $_direction $vmenu_idx_selected
}

function fn_vmenu_set_row_idx()
{
    local -i _line_idx=$1
    local -i _abs_index=$((_line_idx - vmenu_idx_panel_top))
    local -i _row_pos=$((vmenu_row_pos + _abs_index))
    fn_util_set_cursor_pos $_row_pos 0
}

function fn_vmenu_redraw()
{
    # snap window up to the active row
    if((vmenu_idx_panel_top > vmenu_idx_selected))
    then
        vmenu_idx_panel_top=$vmenu_idx_selected
    fi

    vmenu_idx_panel_bottom=$((vmenu_idx_panel_top + vmenu_row_size - 1))

    # snap window down to the active row
    if((vmenu_idx_panel_bottom < vmenu_idx_selected))
    then
        ((vmenu_idx_panel_top += (vmenu_idx_selected - vmenu_idx_panel_bottom)))
        vmenu_idx_panel_bottom=$vmenu_idx_selected
    fi

    # adjust the last index if there are not enough values to display
    vmenu_idx_panel_end=${vmenu_idx_panel_bottom}

    if((vmenu_idx_panel_end > vmenu_idx_last))
    then
        vmenu_idx_panel_end=$vmenu_idx_last
    fi

    fn_util_debug_msg 'A=%d T=%d E=%d B=%d' \
        $vmenu_idx_selected \
        $vmenu_idx_panel_top \
        $vmenu_idx_panel_end \
        $vmenu_idx_panel_bottom

    # draw all menu items
    for((_line_idx = vmenu_idx_panel_top; _line_idx <= vmenu_idx_panel_bottom; _line_idx++))
    do
        fn_vmenu_draw_row $_line_idx
    done

    if((vmenu_footer_show))
    then
        fn_util_draw_footer "$vmenu_footer_message"
    fi

    ((vmenu_idx_redraws++))
}

function fn_vmenu_draw_row()
{
    local -i _line_idx=$1
    local -i _slider_lookahead=${2:-0}

    fn_vmenu_set_row_idx $_line_idx

    # if((_line_idx > vmenu_idx_last))
    # then
    #     # no data to draw so erase row
    #     fn_csi_op $CSI_OP_ROW_ERASE
    #     return
    # fi

    fn_sgr_seq_start

    fn_menu_draw_indicator $_line_idx
    local -i _ind_width=$?

    fn_vmenu_draw_selection $_line_idx $((vmenu_col_size - _ind_width - 1))
    fn_vmenu_draw_slider $((_line_idx - _slider_lookahead))

    fn_sgr_seq_flush
}

function fn_menu_draw_indicator()
{
    local -i _line_idx=$1
    local _line_indicator
    local -i _line_indicator_size

    if((_line_idx > vmenu_idx_last))
    then
        _line_indicator='   '
        _line_indicator_size=3
    else
        if [ ${#vmenu_ind_values[@]} != 0 ]
        then
            _line_indicator="${vmenu_ind_values[_line_idx]:- }"
            fn_utf8_set _line_indicator "$_line_indicator"
            _line_indicator_size=1
        else
            _line_indicator=$_line_idx
            _line_indicator_size=${#_line_indicator}
        fi

        _line_indicator="[${_line_indicator}]"
        ((_line_indicator_size += 2))
    fi

    fn_theme_set_attr_slider $((vmenu_idx_selected == _line_idx))
    fn_sgr_print "$_line_indicator"

    return $_line_indicator_size
}

function fn_vmenu_draw_selection()
{
    local -i _line_idx=$1
    local -i _print_width=$2
    local _selection="${vmenu_data_values[$_line_idx]:- }"

    fn_theme_set_attr_panel $((vmenu_idx_selected == _line_idx))
    fn_csi_print_width " ${_selection}" $((_print_width))
}

function fn_vmenu_draw_slider()
{
    local -i _line_idx=$1
    
    local _last_char=' '

    if ((_line_idx == vmenu_idx_panel_top))
    then
        # Top charachter
        if ((_line_idx == 0))
        then
            fn_utf8_set _last_char $BUI_CHAR_LINE_T_TOP
        else
            fn_utf8_set _last_char $BUI_CHAR_TRIANGLE_UP
        fi
    elif ((_line_idx < vmenu_idx_panel_end))
    then
        fn_utf8_set _last_char $BUI_CHAR_LINE_VT

    elif ((_line_idx == vmenu_idx_panel_end))
    then
        # Bottom Charachter
        if ((_line_idx == vmenu_idx_last))
        then
            fn_utf8_set _last_char $BUI_CHAR_LINE_T_BT
        else
            fn_utf8_set _last_char $BUI_CHAR_TRIANGLE_DN
        fi
    fi

    fn_util_set_col_pos $((vmenu_col_size - 1))
    fn_theme_set_attr_slider $((vmenu_idx_selected == _line_idx))
    fn_sgr_print "$_last_char"
}

