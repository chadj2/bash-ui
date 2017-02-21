##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# Data indexes
declare -i vmenu_idx_active
declare -i vmenu_idx_last
declare -a vmenu_data_values

# indexes at the top and bottom of panel
declare -i vmenu_idx_panel_top

# last index in panel that has data
declare -i vmenu_idx_panel_end

# Layout
declare -ri vmenu_width=50
declare -ri vmenu_height=8

# placeholder for empty data set
declare -r vmenu_empty_text="<empty>"

# if non-zero then an indicator will show a row as being "checked".
declare -i vmenu_idx_checked=-1

# debug statistics only
declare -i vmenu_idx_redraws=0

function fn_vmenu_init()
{
    # get refrence to array with menu entries
    vmenu_data_values=( "${!1-$vmenu_empty_text}" )
    local -i vmenu_data_size=${#vmenu_data_values[*]}
    vmenu_idx_last=$((vmenu_data_size - 1))

    # set active index if passed as an argument. Else default to 0.
    vmenu_idx_active=${2:-0}
    vmenu_idx_checked=-1

    # if data set fits entirely in the window then there is no need for
    # scrolling
    if ((vmenu_data_size < vmenu_height))
    then
        vmenu_idx_panel_top=0
    else
        vmenu_idx_panel_top=$vmenu_idx_active
    fi
}

fn_vmenu_actions()
{
    local _key=$1

    case "$_key" in
        $csi_key_up)
            fn_vmenu_action_up || return $biw_act_terminate
            ;;
        $csi_key_down)
            fn_vmenu_action_down || return $biw_act_terminate
            ;;
    esac

    return $biw_act_continue
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
        return $biw_act_terminate
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
    fi

    return $biw_act_continue
}

function fn_vmenu_action_up()
{
    if ((vmenu_idx_active <= 0))
    then
        # we are at the start of the data so we can't move
        return $biw_act_terminate
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
    fi

    return $biw_act_continue
}

function fn_vmenu_redraw()
{
    local -i vmenu_idx_panel_bottom=$((vmenu_idx_panel_top + vmenu_height - 1))

    # adjust the last index if there are not enough values to display
    vmenu_idx_panel_end=${vmenu_idx_panel_bottom}

    if((vmenu_idx_panel_end > vmenu_idx_last))
    then
        vmenu_idx_panel_end=$vmenu_idx_last
    fi

    # calculate indexes to draw
    local _indexes=$(eval echo {$vmenu_idx_panel_top..$vmenu_idx_panel_bottom})

    # draw all menu items
    for _line_idx in ${_indexes}
    do
        fn_vmenu_draw_row $_line_idx
    done

    ((vmenu_idx_redraws++))
}

function fn_move_cursor()
{
    local -i _line_idx=$1
    fn_csi_op $csi_op_cursor_restore
    local -i _abs_index=$((_line_idx - vmenu_idx_panel_top))
    fn_csi_op $csi_op_row_up $((vmenu_height - _abs_index))
}

function fn_vmenu_draw_row()
{
    local -i _line_idx=$1

    # position cursor
    fn_move_cursor $_line_idx
    fn_csi_op $csi_op_col_pos $biw_margin

    if((_line_idx > vmenu_idx_last))
    then
        # no data to draw so erase row
        fn_csi_op $csi_op_row_erase
        return
    fi

    fn_menu_draw_indicator $_line_idx
    local -i _line_offset=$?
    fn_vmenu_draw_selection $_line_idx $_line_offset
    fn_vmenu_draw_slider $_line_idx

    # reset colors
    fn_sgr_set $sgr_attr_default
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
            _line_indicator=$csi_char_diamond
        fi
    else
        _line_indicator=$_line_idx
        _line_indicator_size=${#_line_indicator}
    fi

    _line_indicator="[${_line_indicator}]"
    ((_line_indicator_size += 2))

    if ((vmenu_idx_active == _line_idx))
    then
        fn_theme_set_bg_attr $theme_attr_sl_active
    else
        fn_theme_set_bg_attr $theme_attr_sl_inactive
    fi

    echo -n "${_line_indicator}"

    return $_line_indicator_size
}

function fn_vmenu_draw_selection()
{
    local -i _line_idx=$1
    local -i _line_offset=$2

    # get line data from array and add space padding
    local _line_result=" ${vmenu_data_values[$_line_idx]}"

    # pad and trim line
    local -i _padding_size=$((vmenu_width - _line_offset))
    printf -v _line_result "%-${_padding_size}s" "${_line_result}"
    _line_result="${_line_result:0:${_padding_size}}"

    if ((vmenu_idx_active == _line_idx))
    then
        fn_theme_set_bg_attr $theme_attr_active
    else
        fn_theme_set_bg_attr $theme_attr_background
    fi

    # output line
    echo -n "${_line_result}"
}

function fn_vmenu_draw_slider()
{
    local -i _line_idx=$1
    local _last_char=$csi_char_line_vert

    if ((_line_idx == vmenu_idx_panel_top))
    then
        # Top charachter
        if ((_line_idx == 0))
        then
            _last_char=$csi_char_line_top
        else
            _last_char='^'
        fi
    elif ((_line_idx == vmenu_idx_panel_end))
    then
        # Bottom Charachter
        if ((_line_idx == vmenu_idx_last))
        then
            _last_char=$csi_char_line_bottom
        else
            _last_char='v'
        fi
    fi

    if ((vmenu_idx_active == _line_idx))
    then
        fn_theme_set_bg_attr $theme_attr_sl_active
    else
        fn_theme_set_bg_attr $theme_attr_sl_inactive
    fi

    echo -n "${_last_char}"
}

