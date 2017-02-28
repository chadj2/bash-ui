##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
# 
# File:         biw-panel-hmenu.sh
# Description:  Panel for horizontal menu.
##

# Layout
declare -ri HMENU_HEIGHT=1
declare -ri HMENU_ITEM_WIDTH=10

declare -i hmenu_width
declare -i hmenu_row_pos

# Indexes
declare -i hmenu_idx_active=0

# Data
declare -a hmenu_data_values
declare -i hmenu_data_size

# debug statistics only
declare -i hmenu_idx_redraws=0

function fn_hmenu_init()
{
    # Layout
    hmenu_width=$BIW_PANEL_WIDTH
    hmenu_row_pos=0
    
    hmenu_data_values=("History" "Completions")
    hmenu_data_values=("${!1}")
    hmenu_data_size=${#hmenu_data_values[*]}
}

fn_hmenu_actions()
{
    local _key=$1
    case "$_key" in
        $CSI_KEY_LEFT)
            fn_hmenu_action_left
            return $?
            ;;
        $CSI_KEY_RIGHT)
            fn_hmenu_action_right
            return $?
            ;;
    esac
    
    return $BIW_ACT_IGNORED
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
        return $BIW_ACT_IGNORED
    fi

    ((hmenu_idx_active -= 1))

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active + 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $BIW_ACT_HANDLED
}

function fn_hmenu_action_right()
{
    if((hmenu_idx_active >= (hmenu_data_size - 1)))
    then
        # can't move
        return $BIW_ACT_IGNORED
    fi

    ((hmenu_idx_active += 1))

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active - 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $BIW_ACT_HANDLED
}

function fn_hmenu_redraw()
{
    local _item_idx
    local -i _total_width=0
    local -i _print_width

    for((_item_idx = 0; _item_idx < hmenu_data_size; _item_idx++))
    do
        fn_hmenu_draw_item $_item_idx
        _print_width=$?
        ((_total_width += _print_width))
    done

    # fill remaining line
    local _r_pad=" "
    fn_csi_pad_string "_r_pad" $((hmenu_width - _total_width))

    fn_sgr_seq_start

        fn_theme_set_attr $TATTR_BG_INACTIVE
        fn_sgr_set $SGR_ATTR_UNDERLINE
        fn_sgr_print "$_r_pad"
        fn_sgr_set $SGR_ATTR_DEFAULT
    
    fn_sgr_seq_flush

    ((hmenu_idx_redraws++))
}

function fn_hmenu_draw_item()
{
    local -i _item_idx=$1
    local _item_value=${hmenu_data_values[_item_idx]}
    local -i _print_width=$((HMENU_ITEM_WIDTH - 2))

    fn_csi_pad_string "_item_value" $_print_width

    if ((_item_idx == hmenu_idx_active))
    then
        _item_value="[${_item_value}]"
    else
        _item_value=" ${_item_value} "
    fi

    local -i _col_pos=$((_item_idx*HMENU_ITEM_WIDTH))
    fn_biw_set_cursor_pos $hmenu_row_pos $_col_pos

    fn_sgr_seq_start

        fn_theme_set_attr_default $((_item_idx == hmenu_idx_active))
        fn_sgr_set $SGR_ATTR_UNDERLINE
        fn_sgr_print "$_item_value"
        fn_sgr_set $SGR_ATTR_DEFAULT

    fn_sgr_seq_flush

    return $HMENU_ITEM_WIDTH
}
