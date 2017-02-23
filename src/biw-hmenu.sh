##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# Layout
declare -ri HMENU_HEIGHT=1
declare -ri HMENU_ITEM_WIDTH=12

# Indexes
declare -i hmenu_idx_active=0
declare -i hmenu_idx_end

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

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active + 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $BIW_ACT_HANDLED
}

function fn_hmenu_action_right()
{
    if((hmenu_idx_active >= hmenu_idx_end))
    then
        # can't move
        return $BIW_ACT_IGNORED
    fi

    ((hmenu_idx_active += 1))

    # move to correct row
    fn_biw_cursor_home

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_active - 1))
    fn_hmenu_draw_item $((hmenu_idx_active))
    
    return $BIW_ACT_HANDLED
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

    local -i _adj_menu_width=$((HMENU_ITEM_WIDTH - 2))
    printf -v _item_value "%-${_adj_menu_width}s" $_item_value

    if ((_item_idx == hmenu_idx_active))
    then
        _item_value="[${_item_value}]"
        fn_theme_set_bg_attr $TATTR_ACTIVE
    else
        _item_value=" ${_item_value} "
        fn_theme_set_bg_attr $TATTR_BACKGROUND
    fi

    fn_csi_op $CSI_OP_COL_POS $((BIW_MARGIN + _item_idx*HMENU_ITEM_WIDTH))
    fn_sgr_set $SGR_ATTR_UNDERLINE
    echo -n "$_item_value"

    # reset colors
    fn_sgr_set $SGR_ATTR_DEFAULT
}
