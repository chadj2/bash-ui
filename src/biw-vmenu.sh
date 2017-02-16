##
# BIW-VMENU - BIW Horizontal Scrollable Menu
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# Indexes
declare -i vmenu_idx_active
declare -i vmenu_idx_last
declare -i vmenu_idx_start
declare -i vmenu_idx_end

# Data
declare -a vmenu_data_values
declare -i vmenu_data_size

# Layout
declare -ri vmenu_width=50
declare -ri vmenu_height=8

# Colors
declare -ri vmenu_color_slider_bar=$sgr_color_cyan
declare -ri vmenu_color_handle=$sgr_color_yellow


function fn_vmenu_init()
{
    # get refrence to array with menu entries
    vmenu_data_values=("${!1}")
    vmenu_data_size=${#vmenu_data_values[*]}

    # setup index values
    vmenu_idx_active=0
    vmenu_idx_last=$((vmenu_data_size - 1))
    vmenu_idx_start=$vmenu_idx_active
    vmenu_idx_end=$((vmenu_idx_active + vmenu_height - 1))

    # adjust the last index if there are not enough values to display
    if((vmenu_idx_end > vmenu_idx_last))
    then
        vmenu_idx_end=$vmenu_idx_last
    fi
}

function fn_vmenu_down()
{
    if ((vmenu_idx_active >= vmenu_idx_last))
    then
        # we are at the end of the data so we can't move
        return
    fi

    # move active index
    ((vmenu_idx_active += 1))

    if ((vmenu_idx_active > vmenu_idx_end))
    then
        # new index has exceeded the bounds of the window
        ((vmenu_idx_start += 1))
        ((vmenu_idx_end += 1))
        fn_vmenu_redraw
    else
        # redraw affected rows
        fn_vmenu_draw_row $((vmenu_idx_active - 1))
        fn_vmenu_draw_row $vmenu_idx_active
    fi
}

function fn_vmenu_up()
{
    if ((vmenu_idx_active <= 0))
    then
        # we are at the start of the data so we can't move
        return
    fi

    ((vmenu_idx_active -= 1))

    if ((vmenu_idx_active < vmenu_idx_start))
    then
        # new index has exceeded the bounds of the window
        ((vmenu_idx_start -= 1))
        ((vmenu_idx_end -= 1))
        fn_vmenu_redraw
    else
        # redraw affected rows
        fn_vmenu_draw_row $((vmenu_idx_active + 1))
        fn_vmenu_draw_row $vmenu_idx_active
    fi
}

function fn_vmenu_move_bounds()
{
    # location is specified by the start
    vmenu_idx_start=$1

    # end is calculateed
    vmenu_idx_end=$((vmenu_idx_start + vmenu_height - 1))
    fn_vmenu_redraw
}

function fn_vmenu_redraw()
{
    local -i _redraw_idx_end=$((vmenu_idx_start + vmenu_height - 1))
    # calculate indexes to draw
    local _indexes=$(eval echo {$vmenu_idx_start..$_redraw_idx_end})
    #echo -n "{$vmenu_idx_start..$_redraw_idx_end}"

    # draw all menu items
    for _line_idx in ${_indexes}
    do
        fn_vmenu_draw_row $_line_idx
    done
}

function fm_move_cursor()
{
    local -i _line_idx=$1
    local -i _abs_index=$((_line_idx - vmenu_idx_start))

    fn_esc $esc_restore_cursor
    #echo "${_line_idx}, ${vmenu_idx_start}"

    fn_csi $csi_row_up $((vmenu_height - _abs_index))
    #fn_csi $csi_row_up $((vmenu_height - _abs_index))
}

function fn_vmenu_draw_row()
{
    local -i _line_idx=$1

    # position cursor
    fm_move_cursor $_line_idx
    fn_csi $csi_col_pos $biw_margin

    if((_line_idx > vmenu_idx_last))
    then
        # no data to draw so erase row
        fn_csi $csi_row_erase
        return
    fi

    # set text color (BG will be set later)
    fn_csi $csi_set_color $((sgr_color_fg + biw_color_text))

    fn_vmenu_draw_selection $_line_idx
    fn_vmenu_draw_slider $_line_idx
}

function fn_vmenu_draw_slider()
{
    local -i _line_idx=$1
    local _last_char=$decg_hz_line

    if ((_line_idx == vmenu_idx_start))
    then
        # Top charachter
        if ((_line_idx == 0))
        then
            _last_char=$decg_t_top
        else
            _last_char='^'
        fi
    elif ((_line_idx == vmenu_idx_end))
    then
        # Bottom Charachter
        if ((_line_idx == vmenu_idx_last))
        then
            _last_char=$decg_t_bottom
        else
            _last_char='v'
        fi
    fi

    local -i _slider_color=$vmenu_color_slider_bar

    if ((vmenu_idx_active == _line_idx))
    then
        _slider_color=$vmenu_color_handle
    fi

    fn_csi $csi_set_color $((sgr_color_fg + biw_color_text))
    fn_csi $csi_set_color $((sgr_color_bg + _slider_color))
    echo -en "${_last_char}"

    # reset colors
    fn_csi $csi_set_color 0
}

function fn_vmenu_draw_selection()
{
    local -i _line_idx=$1
    local -i _panel_color=$biw_color_inactive

    if ((vmenu_idx_active == _line_idx))
    then
        _panel_color=$biw_color_active
        #fn_csi $csi_set_color $sgr_underline
    fi

    # get line data from array
    local _line_result="${vmenu_data_values[$_line_idx]}"

    # selection contents
    _line_result="[${_line_idx}] ${_line_result}"

    # pad and trim line
    printf -v _line_result "%-${vmenu_width}s" "${_line_result}"
    _line_result="${_line_result:0:${vmenu_width}}"

    # output line
    fn_csi $csi_set_color $((sgr_color_fg + biw_color_text))
    fn_csi $csi_set_color $((sgr_color_bg + _panel_color))
    echo -n "${_line_result}"

    # reset colors
    fn_csi $csi_set_color 0
}
