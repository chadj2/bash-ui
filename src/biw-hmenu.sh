##
# BIW-HMENU - BIW Horizontal Menu
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# Indexes
declare -i hmenu_idx_active=0
declare -i hmenu_idx_end

# Layout
declare -ri hmenu_height=1
declare -i hmenu_item_width=14

# Data
declare -a hmenu_data_values
declare -i hmenu_data_size


function fn_hmenu_init()
{
    hmenu_data_values=("History" "Completions")
    hmenu_data_values=("${!1}")
    hmenu_data_size=${#hmenu_data_values[*]}
    hmenu_idx_end=$((hmenu_data_size - 1))
}

function fm_hmenu_left()
{
    if((hmenu_idx_active <= 0))
    then
        # can't move
        return
    fi

    ((hmenu_idx_active -= 1))

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fm_hmenu_draw_item $((hmenu_idx_active + 1))
    fm_hmenu_draw_item $((hmenu_idx_active))
}

function fm_hmenu_right()
{
    if((hmenu_idx_active >= hmenu_idx_end))
    then
        # can't move
        return
    fi

    ((hmenu_idx_active += 1))

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fm_hmenu_draw_item $((hmenu_idx_active - 1))
    fm_hmenu_draw_item $((hmenu_idx_active))
}

function fn_hmenu_redraw()
{
    local _indexes=$(eval echo {0..$hmenu_idx_end})
    local _item_idx

    # move to correct row
    fn_biw_cursor_home

    for _item_idx in ${_indexes}
    do
        fm_hmenu_draw_item $_item_idx
    done
}

function fm_hmenu_draw_item()
{
    local -i _item_idx=$1
    local _item_value=${hmenu_data_values[_item_idx]}

    local -i _adj_menu_width=$((hmenu_item_width - 2))
    printf -v _item_value "%-${_adj_menu_width}s" $_item_value

    local -i _item_color=$biw_color_inactive
    
    if ((_item_idx == hmenu_idx_active))
    then
        _item_value="[${_item_value}]"
        _item_color=$biw_color_active
    else
        _item_value=" ${_item_value} "
    fi

    fn_csi $csi_col_pos $((biw_margin + _item_idx*hmenu_item_width))
    fn_csi $csi_set_color $sgr_underline
    fn_csi $csi_set_color $((sgr_color_fg + biw_color_text))
    fn_csi $csi_set_color $((sgr_color_bg + _item_color))
    echo -n "$_item_value"

    # reset colors
    fn_csi $csi_set_color 0
}
