##
# BIW-TOOLS - Bash Inline Widget Tools
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
declare -i hmenu_item_width=12

# Data
declare -a hmenu_data_values
declare -i hmenu_data_size

# debug statistics only
declare -i hmenu_idx_redraws=0

function fn_hmenu_init()
{
    hmenu_data_values=("History" "Completions")
    hmenu_data_values=("${!1}")
    hmenu_data_size=${#hmenu_data_values[*]}
    hmenu_idx_end=$((hmenu_data_size - 1))
}

fn_hmenu_actions()
{
    local _key=$1
    case "$_key" in
        $key_left)
            fn_hmenu_action_left || return $biw_act_terminate
            ;;
        $key_right)
            fn_hmenu_action_right || return $biw_act_terminate
            ;;
    esac
    
    return $biw_act_continue
}

function fn_hmenu_get_current_val()
{
    echo ${hmenu_data_values[$hmenu_idx_active]}
}

function fn_hmenu_action_left()
{
    if((hmenu_idx_active <= 0))
    then
        # can't move
        return $biw_act_terminate
    fi

    ((hmenu_idx_active -= 1))

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active + 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $biw_act_continue
}

function fn_hmenu_action_right()
{
    if((hmenu_idx_active >= hmenu_idx_end))
    then
        # can't move
        return $biw_act_terminate
    fi

    ((hmenu_idx_active += 1))

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active - 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $biw_act_continue
}

function fn_hmenu_redraw()
{
    local _indexes=$(eval echo {0..$hmenu_idx_end})
    local _item_idx

    # move to correct row
    fn_biw_cursor_home

    for _item_idx in ${_indexes}
    do
        fn_hmenu_draw_item $_item_idx
    done

    ((hmenu_idx_redraws++))
}

function fn_hmenu_draw_item()
{
    local -i _item_idx=$1
    local _item_value=${hmenu_data_values[_item_idx]}

    local -i _adj_menu_width=$((hmenu_item_width - 2))
    printf -v _item_value "%-${_adj_menu_width}s" $_item_value

    if ((_item_idx == hmenu_idx_active))
    then
        _item_value="[${_item_value}]"
        fn_theme_set_bg_attr $theme_attr_active
    else
        _item_value=" ${_item_value} "
        fn_theme_set_bg_attr $theme_attr_background
    fi

    fn_csi $csi_col_pos $((biw_margin + _item_idx*hmenu_item_width))
    fn_csi $csi_set_color $sgr_attr_underline
    echo -n "$_item_value"

    # reset colors
    fn_csi $csi_set_color $sgr_attr_default
}
