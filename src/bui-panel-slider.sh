###!/bin/bash
##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-panel-slider.sh
# Description:  Panel that displays a set of slider controls.
##

# panel state

declare -a slider_ctl_list

declare -i slider_panel_row_pos
declare -i slider_panel_row_size
declare -i slider_ctl_selected_idx
declare -i slider_ctl_count

# attributes for slider array
declare -ir SLIDER_CTL_ATTR_LABEL=0
declare -ir SLIDER_CTL_ATTR_MIN=1
declare -ir SLIDER_CTL_ATTR_MAX=2
declare -ir SLIDER_CTL_ATTR_VAL=3

# panel constants
declare -ir SLIDER_CTL_POSITIONS=25
declare -ir SLIDER_CTL_ROW_SIZE=3
declare -ir SLIDER_CTL_COL_SIZE=$((SLIDER_CTL_POSITIONS + 6))
declare -ir SLIDER_DIGITS_COL_SIZE=5

# virtual canvas with sliders that is centered
declare -i slider_canvas_row_size
declare -ir SLIDER_CANVAS_COL_SIZE=$((SLIDER_CTL_COL_SIZE + SLIDER_DIGITS_COL_SIZE))
declare -i slider_canvas_col_pos
declare -i slider_canvas_row_pos

function fn_slider_init()
{
    local _slider_list_ref=$1

    slider_ctl_list=( "${!_slider_list_ref}" )
    slider_ctl_count=${#slider_ctl_list[@]}

    slider_panel_row_pos=$((hmenu_row_pos + 1))
    slider_ctl_selected_idx=-1
}

function fn_slider_actions()
{
    local _key=$1
    local _result=$UTIL_ACT_IGNORED

    case "$_key" in
        $CSI_KEY_UP)
            if ((slider_ctl_selected_idx < 0))
            then
                # user pressed up on first row so exit controller
                util_exit_dispatcher=1
                break
            fi
            fn_slider_ctl_set_active $((slider_ctl_selected_idx - 1))
            _result=$UTIL_ACT_IGNORED
            ;;
        $CSI_KEY_DOWN)
            fn_slider_ctl_set_active $((slider_ctl_selected_idx + 1))
            _result=$UTIL_ACT_IGNORED
            ;;
        $CSI_KEY_LEFT)
            fn_slider_ctl_drag -1
            _result=$?
            ;;
        $CSI_KEY_RIGHT)
            fn_slider_ctl_drag 1
            _result=$?
            ;;
    esac

    return $_result
}

function fn_slider_redraw()
{
    # fill the panel with an empty box
    fn_draw_clear_screen $slider_panel_row_pos

    # calculate slider position
    slider_canvas_col_pos=$(( (draw_panel_col_size - SLIDER_CANVAS_COL_SIZE)/2 ))

    slider_panel_row_size=$((draw_panel_row_size - hmenu_row_pos - 1))
    slider_canvas_row_size=$((slider_ctl_count*SLIDER_CTL_ROW_SIZE))
    slider_canvas_row_pos=$(( (slider_panel_row_size - slider_canvas_row_size)/2 ))

    local -i _ctl_idx
    for((_ctl_idx = 0; _ctl_idx < slider_ctl_count; _ctl_idx++))
    do
        fn_slider_ctl_draw_full $_ctl_idx
    done
}

function fn_slider_ctl_drag()
{
    local _direction=$1

    # fetch slider attributes
    local _slider_name=${slider_ctl_list[slider_ctl_selected_idx]}
    local _attr_ref="$_slider_name[@]"
    local -a _slider_data=( ${!_attr_ref} )

    local -i _slider_val=${_slider_data[$SLIDER_CTL_ATTR_VAL]}
    local -i _pos_min=${_slider_data[$SLIDER_CTL_ATTR_MIN]}
    local -i _pos_max=${_slider_data[$SLIDER_CTL_ATTR_MAX]}

    local -i _new_idx=$((_slider_val + _direction))

    if((_new_idx > $_pos_max))
    then
        return $UTIL_ACT_IGNORED
    elif((_new_idx < $_pos_min))
    then
        return $UTIL_ACT_IGNORED
    fi

    # update slider value attribute
    eval $_slider_name[$SLIDER_CTL_ATTR_VAL]=$_new_idx

    # redraw slider
    fn_slider_ctl_draw_slider $slider_ctl_selected_idx $_pos_min $_pos_max $_new_idx

    return $UTIL_ACT_CHANGED
}

function fn_slider_ctl_set_active()
{
    local -i _new_slider=$1
    local -i _old_slider=$slider_ctl_selected_idx

    if((_new_slider >= slider_ctl_count))
    then
        _new_slider=$((slider_ctl_count - 1))
    fi

    if((_new_slider < -1))
    then
        _new_slider=-1
    fi

    if((_new_slider == _old_slider))
    then
        return $UTIL_ACT_IGNORED
    fi

    slider_ctl_selected_idx=$_new_slider
    fn_slider_ctl_idx_draw $_new_slider
    fn_slider_ctl_idx_draw $_old_slider

    return $UTIL_ACT_CHANGED
}

function fn_slider_set_cursor_pos()
{
    local -i _row_pos=$1
    local -i _col_pos=$2

    local -i _real_col_pos=$((_col_pos + slider_canvas_col_pos))
    local -i _real_row_pos=$((_row_pos + slider_panel_row_pos + slider_canvas_row_pos))

    fn_draw_set_cursor_pos $_real_row_pos $_real_col_pos
}

function fn_slider_ctl_idx_draw()
{
    local -i _ctl_idx=$1

    if((_ctl_idx < 0))
    then
        return
    fi

    # fetch slider attributes
    local _slider_name=${slider_ctl_list[_ctl_idx]}
    local _attr_ref="$_slider_name[@]"
    local -a _slider_data=( ${!_attr_ref} )

    local -i _pos_val=${_slider_data[$SLIDER_CTL_ATTR_VAL]}
    local -i _pos_min=${_slider_data[$SLIDER_CTL_ATTR_MIN]}
    local -i _pos_max=${_slider_data[$SLIDER_CTL_ATTR_MAX]}

    fn_slider_ctl_draw_slider $_ctl_idx $_pos_min $_pos_max $_pos_val
}

function fn_slider_ctl_draw_full()
{
    local -i _ctl_idx=$1

    local _slider_name=${slider_ctl_list[_ctl_idx]}
    local _attr_ref="$_slider_name[@]"
    local -a _slider_data=( ${!_attr_ref} )
    
    local _label="${_slider_data[$SLIDER_CTL_ATTR_LABEL]}"
    local -i _idx_pos=${_slider_data[$SLIDER_CTL_ATTR_VAL]}
    local -i _pos_min=${_slider_data[$SLIDER_CTL_ATTR_MIN]}
    local -i _pos_max=${_slider_data[$SLIDER_CTL_ATTR_MAX]}

    fn_slider_ctl_draw_header $_ctl_idx "$_label" $_pos_min $_pos_max

    fn_slider_ctl_draw_slider $_ctl_idx $_pos_min $_pos_max $_idx_pos
}

function fn_slider_ctl_draw_header()
{
    local -i _ctl_idx=$1
    local _label=$2
    local -i _pos_min=$3
    local -i _pos_max=$4

    local -ir DIGITS_SIZE=2
    local _digits
    local -i _row_pos=$((SLIDER_CTL_ROW_SIZE*_ctl_idx))

    fn_slider_set_cursor_pos $_row_pos 0

    fn_theme_set_attr_panel 0
    printf -v _digits '%2d' $_pos_min
    fn_sgr_print "$_digits"

    fn_draw_print_center "$_label" $((SLIDER_CTL_COL_SIZE - DIGITS_SIZE*2))

    printf -v _digits '%2d' $_pos_max
    fn_sgr_print "$_digits"
}

function fn_slider_ctl_draw_slider()
{
    local -i _ctl_idx=$1
    local -i _pos_min=$2
    local -i _pos_max=$3
    local -i _pos_val=$4

    local -i _active=$((slider_ctl_selected_idx == _ctl_idx))
    local -i _row_pos=$((SLIDER_CTL_ROW_SIZE*_ctl_idx + 1))

    fn_sgr_seq_start

    fn_util_interp_x $SLIDER_CTL_POSITIONS $_pos_min $_pos_max $_pos_val
    local -i _slider_interp=$?

    local _digits
    printf -v _digits ' [%2d]' $_pos_val

    fn_slider_set_cursor_pos $_row_pos 0
    fn_slider_draw_ctl_bar $_slider_interp $SLIDER_CTL_POSITIONS $_active

    fn_theme_set_attr_panel 0
    fn_sgr_print "$_digits"

    fn_sgr_seq_flush
}

function fn_slider_draw_ctl_bar()
{
    local -i _position_idx=$1
    local -i _position_max=$2
    local -i _active=$3
    
    fn_theme_set_attr_panel $_active
    fn_draw_utf8_print $BUI_CHAR_TRIANGLE_LT

    # leading space
    fn_theme_set_attr_panel 0
    if((_position_idx == 0))
    then
        fn_draw_utf8_print $BUI_CHAR_LINE_VT
    else
        fn_draw_utf8_print $BUI_CHAR_LINE_T_LT
    fi

    fn_draw_utf8_print $BUI_CHAR_LINE_HZ $((_position_idx))

    fn_theme_set_attr_panel $_active
    fn_sgr_print '('
    fn_sgr_print ')'

    fn_theme_set_attr_panel 0
    fn_draw_utf8_print $BUI_CHAR_LINE_HZ $((_position_max - _position_idx))

    # trailing space
    if((_position_idx == _position_max))
    then
        fn_draw_utf8_print $BUI_CHAR_LINE_VT
    else
        fn_theme_set_attr_panel 0
        fn_draw_utf8_print $BUI_CHAR_LINE_T_RT
    fi

    fn_theme_set_attr_panel $_active
    fn_draw_utf8_print $BUI_CHAR_TRIANGLE_RT
}
