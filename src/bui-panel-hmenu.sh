##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
# 
# File:         bui-panel-hmenu.sh
# Description:  Panel for horizontal menu.
##

# Layout
declare -ri HMENU_ROW_SIZE=1
declare -ri HMENU_ITEM_WIDTH=10

declare -i hmenu_col_size
declare -i hmenu_row_pos

# Indexes
declare -i hmenu_idx_selected
declare -i hmenu_idx_last

# Data
declare -a hmenu_data_values
declare -i hmenu_data_size

# debug statistics only
declare -i hmenu_idx_redraws=0

function fn_hmenu_init()
{
    hmenu_data_values=("${!1}")
    hmenu_idx_selected=${2:-0}

    hmenu_data_size=${#hmenu_data_values[*]}
    hmenu_idx_last=$((hmenu_data_size - 1))

    # Layout
    hmenu_row_pos=0
}

function fn_hmenu_controller_sub()
{
    declare -a _menu_values=("${!1}")

    # save the hmenu state
    local -a _old_values=( "${hmenu_data_values[@]}" )
    local -i _old_selected=hmenu_idx_selected
    local _old_selected_value
    fn_hmenu_get_current_val '_old_selected_value'

    # Init the sub-menu
    fn_hmenu_init '_menu_values[@]' -1
    hmenu_row_pos=1
    fn_hmenu_redraw

    local _panel_msg
    mapfile -t _panel_msg <<-EOM
    
    
${_old_selected_value} Menu Options:

[Down-Arrow]: Enter sub-menu
[Up-Arrow] or [ESC]: Exit sub-menu
[Enter] or [Space]: Save a selection
[CTRL-C]: Exit application
EOM

    # fill the panel with a box showing the above text.
    fn_draw_box_panel $((hmenu_row_pos + 1)) '_panel_msg[@]'

    # the user should use up and down keys to navigate
    local _key
    fn_util_process_key _key
    case "$_key" in
        $CSI_KEY_UP)
            util_exit_dispatcher=1
            ;;
        $CSI_KEY_DOWN)
            # user is moving into lower menu
            hmenu_idx_selected=0
            fn_util_dispatcher
            ;;
    esac

    # restore old hmenu
    fn_hmenu_init '_old_values[@]' $_old_selected
    hmenu_row_pos=0

    # allow the top menu to process the key that 
    # could be left/right
    fn_hmenu_actions $_key
}

fn_hmenu_actions()
{
    local _key=$1
    local _result=$UTIL_ACT_IGNORED

    case "$_key" in
        $CSI_KEY_LEFT)
            fn_hmenu_action_move -1
            _result=$?
            ;;
        $CSI_KEY_RIGHT)
            fn_hmenu_action_move 1
            _result=$?
            ;;
    esac
    
    return $_result
}

function fn_hmenu_get_current_val()
{
    local _result_ref=$1
    local _current_val="${hmenu_data_values[hmenu_idx_selected]}"

    printf -v $_result_ref '%s' "$_current_val"
}

function fn_hmenu_action_move()
{
    if((hmenu_idx_selected < 0))
    then
        # nothing is selected
        return $UTIL_ACT_IGNORED
    fi

    local _direction=$1
    local _new_idx=$((hmenu_idx_selected + _direction))

    if((_new_idx <= 0))
    then
        _new_idx=0
    fi

    if((_new_idx >= hmenu_idx_last))
    then
        _new_idx=$hmenu_idx_last
    fi

    if((hmenu_idx_selected == _new_idx))
    then
        # no change
        return $UTIL_ACT_IGNORED
    fi

    hmenu_idx_selected=$_new_idx

    # redraw affected items
    fn_hmenu_draw_item $((hmenu_idx_selected - _direction))
    fn_hmenu_draw_item $((hmenu_idx_selected))
    
    return $UTIL_ACT_CHANGED
}

function fn_hmenu_redraw()
{
    local _item_idx
    local -i _total_width=0
    local -i _print_width

    hmenu_col_size=$draw_panel_col_size

    for((_item_idx = 0; _item_idx < hmenu_data_size; _item_idx++))
    do
        fn_hmenu_draw_item $_item_idx
        _print_width=$?
        ((_total_width += _print_width))
    done

    # Fill the reset of the line
    fn_sgr_seq_start
    fn_theme_set_attr $THEME_SET_DEF_INACTIVE
    fn_sgr_op $SGR_ATTR_UNDERLINE
    fn_draw_print_pad '' $((hmenu_col_size - _total_width))
    fn_sgr_seq_flush

    ((hmenu_idx_redraws++))
}

function fn_hmenu_draw_item()
{
    local -i _item_idx=$1
    local _item_value=${hmenu_data_values[_item_idx]}

    fn_sgr_seq_start

    fn_draw_set_cursor_pos $hmenu_row_pos $((_item_idx*HMENU_ITEM_WIDTH))
    fn_theme_set_attr_panel $((_item_idx == hmenu_idx_selected))
    fn_sgr_op $SGR_ATTR_UNDERLINE

    if ((_item_idx == hmenu_idx_selected))
    then
        fn_sgr_print '['
        fn_draw_print_pad "$_item_value" $((HMENU_ITEM_WIDTH - 2))
        fn_sgr_print ']'
    else
        fn_sgr_print ' '
        fn_draw_print_pad "$_item_value" $((HMENU_ITEM_WIDTH - 1))
    fi

    fn_sgr_seq_flush

    return $HMENU_ITEM_WIDTH
}
