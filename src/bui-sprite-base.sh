##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-sprite-base.sh
# Description:  Sprites for rendering animations.
##

# boundaries of sprite canvas
declare -i sprite_canvas_row_pos
declare -i sprite_canvas_col_pos
declare -i sprite_canvas_width
declare -i sprite_canvas_height

# text buffer for alpha map
declare -a sprite_buf_data
declare -a sprite_buf_col_pos

# varables that declare the sprites and status
declare -i sprite_count=0
declare -a sprite_animate_map=()
declare -a sprite_status_map

# default sprite
declare -ir SPRITE_ID_NONE=$((sprite_count++))
sprite_animate_map[$SPRITE_ID_NONE]=id_none
sprite_start_map[$SPRITE_ID_NONE]=id_none

function fn_sprite_canvas_set_row()
{
    local -i _row_pos=$1
    fn_draw_set_row_pos $((sprite_canvas_row_pos + _row_pos))
}

function fn_sprite_canvas_set_col()
{
    local -i _col_pos=$1
    fn_draw_set_col_pos $((sprite_canvas_col_pos + _col_pos))
}

function fn_sprite_init()
{
    local -i _sprite_idx
    for((_sprite_idx = 0; _sprite_idx < sprite_count; _sprite_idx++))
    do
        sprite_status_map[_sprite_idx]=0
    done

    fn_sprite_debug_init
}

function fn_sprite_start()
{
    local -i _sprite_id=$1
    local -i _sprite_status=${sprite_status_map[_sprite_id]}
    local _start_function=${sprite_start_map[_sprite_id]}

    if((_sprite_status))
    then
        fn_util_die "Sprite already active: ${_start_function} (${sprite_status_map[*]})"
    fi

    $_start_function "${@:2}"
    local _result=$?

    if((_result))
    then
        # failed to start
        return 1
    fi

    sprite_status_map[_sprite_id]=1
    return 0
}

function fn_sprite_timer_loop()
{
    local -r SPRITE_ANIMATE_DELAY=0.03
    local _result_char
    local -i _last_inactive

    while fn_util_process_key '_result_char' $SPRITE_ANIMATE_DELAY
    do
        if [ $_result_char == $CSI_KEY_UP ]
        then
            # up key should exit the app
            util_exit_dispatcher=1
            break
        fi

        fn_sprite_animate
        _last_inactive=$?

        if ((_last_inactive > 0))
        then
            fn_sprite_debug_update_msg $_last_inactive
            # normal termination
            return $_last_inactive
        fi
    done

    # user cancel
    return 0
}

function fn_sprite_animate()
{
    local -i _run_check=0
    local -i _sprite_idx

    local -i _last_inactive=$SPRITE_ID_NONE

    fn_sgr_seq_start

    for((_sprite_idx=1; _sprite_idx < sprite_count; _sprite_idx++))
    do
        local -i _sprite_status=${sprite_status_map[_sprite_idx]}
        local _animate_function=${sprite_animate_map[_sprite_idx]}

        if((_sprite_status))
        then
            fn_theme_set_attr $THEME_SET_DEF_INACTIVE
            _run_check=1
            
            if ! $_animate_function
            then
                sprite_status_map[_sprite_idx]=0
                _last_inactive=$_sprite_idx
                break
            fi
        fi
    done

    # this will flush the buffer and print the output
    fn_sgr_seq_flush

    if((!_run_check))
    then
        fn_util_die "No active sprites!"
    fi

    # keep going
    return $_last_inactive
}

##
# Sprite: Timer
# Description: Timer sprite that does nothing
##

declare -ir SPRITE_ID_TIMER=$((sprite_count++))
sprite_start_map[$SPRITE_ID_TIMER]=fn_sprite_timer_start
sprite_animate_map[$SPRITE_ID_TIMER]=fn_sprite_timer_animate

declare -i sprite_timer_counter

function fn_sprite_timer_start()
{
    sprite_timer_counter=$1
}

function fn_sprite_timer_animate()
{
    ((sprite_timer_counter--))

    if((sprite_timer_counter <= 0))
    then
        return 1
    fi

    return 0
}

##
# Sprite: Alpha
# Description: Render alpha color map
##

declare -ir SPRITE_ID_ALPHA=$((sprite_count++))
sprite_start_map[$SPRITE_ID_ALPHA]=fn_sprite_alpha_start
sprite_animate_map[$SPRITE_ID_ALPHA]=fn_sprite_alpha_animate

declare -a sprite_alpha_cmap
declare -i sprite_alpha_cmap_size
declare -i sprite_alpha_use_color216=0
declare -a sprite_alpha_map

function fn_sprite_alpha_init()
{
    local -i _map_size=$((sprite_canvas_width*sprite_canvas_height))
    sprite_alpha_map[_map_size]=-1

    # init zero valued array
    local _char_idx
    for((_char_idx=0; _char_idx < _map_size; _char_idx++))
    do
        sprite_alpha_map[_char_idx]=-1
    done

    return 0
}

function fn_sprite_alpha_map_set()
{
    local -i _row_pos=$1
    local -i _col_pos=$2
    local -i _cmap_val=$3

    if((_cmap_val < 0))
    then
        # handle case where we are using reverse index
        _cmap_val=$((sprite_alpha_cmap_size + _cmap_val))
    fi

    if((_col_pos >= sprite_canvas_width || _col_pos < 0))
    then
        # out of range
        return 
    fi

    if((_row_pos >= sprite_canvas_height || _row_pos < 0 ))
    then
        # out of range
        return 
    fi
    
    local -i _map_idx=$((_row_pos*sprite_canvas_width + _col_pos))
    sprite_alpha_map[_map_idx]=$_cmap_val
}

function fn_sprite_alpha_start()
{
    # init FPS monitor
    fn_sprite_debug_update_fps

    return 0
}

function fn_sprite_alpha_animate()
{
    local _char_data
    local -i _row_idx
    local -i _char_pos
    sprite_active_rows=0

    for((_row_idx=0; _row_idx < sprite_canvas_height; _row_idx++))
    do
        _char_data="${sprite_buf_data[_row_idx]}"
        _char_pos=${sprite_buf_col_pos[_row_idx]}

        if fn_sprite_alpha_print_row $_row_idx $_char_pos "$_char_data"
        then
            ((sprite_active_rows++))
        fi
    done

    ((sprite_fps_counter++))

    return 0
}

function fn_sprite_alpha_print_row()
{
    local -i _row_idx=$1
    local -i _char_pos=$2
    local _char_data=$3

    local -i _char_size=${#_char_data}
    local -i _cursor_pos=-1
    local -i _alpha_start=$((_row_idx*sprite_canvas_width))

    local -i _char_idx
    local -i _alpha_color
    local _print_char
    local -i _col_idx
    local -i _alpha_idx

    local -i _row_set=0

    for((_col_idx=0; _col_idx < sprite_canvas_width; _col_idx++))
    do
        _alpha_idx=$((_alpha_start + _col_idx))
        _alpha_color=${sprite_alpha_map[_alpha_idx]}
        if((_alpha_color == -1))
        then
            continue
        fi

        _char_idx=$((_col_idx - _char_pos))
        if((_char_idx >= 0 && _char_idx < _char_size))
        then
            _print_char="${_char_data:_char_idx:1}"
        else
            if((_alpha_color > 1))
            then
                _print_char='.'
            else
                _print_char=' '
            fi
        fi

        if((_cursor_pos < _col_idx))
        then
            if((!_row_set))
            then
                fn_sprite_canvas_set_row $_row_idx
                _row_set=1
            fi

            _cursor_pos=$_col_idx
            fn_sprite_canvas_set_col $_cursor_pos
        fi

        fn_sprite_alpha_set_color $_alpha_color
        fn_sgr_print "$_print_char"
        ((_cursor_pos++))

        # each value in the alpha list needs to get decremented
        sprite_alpha_map[_alpha_idx]=$((_alpha_color - 1))
    done


    if((_cursor_pos < 0))
    then
        # did nothing
        return 1
    fi

    return 0
}

function fn_sprite_alpha_set_color()
{
    local -i _alpha_color=$1

    if((_alpha_color < 0))
    then
        _alpha_color=$((sprite_alpha_cmap_size + _alpha_color))
    fi

    local -i _sgr_color=${sprite_alpha_cmap[_alpha_color]}

    if((sprite_alpha_use_color216))
    then
        fn_sgr_color216_set $SGR_ATTR_FG $_sgr_color
    else
        fn_sgr_color16_set $SGR_ATTR_FG $_sgr_color
    fi
}

function fn_sprite_cmap_simple()
{
    sprite_alpha_cmap=(
        [0]=0
        [1]=$SGR_COL_GREEN
        [2]=$SGR_COL_YELLOW
        [3]=$SGR_COL_YELLOW
        [4]=$SGR_COL_YELLOW
        [5]=$SGR_COL_YELLOW
        [6]=$SGR_COL_YELLOW
        [7]=$SGR_COL_YELLOW
        [8]=$SGR_COL_YELLOW
        [9]=$SGR_COL_YELLOW
        [10]=$SGR_COL_YELLOW
        [11]=$SGR_COL_YELLOW
        [12]=$SGR_COL_YELLOW
    )

    sprite_alpha_cmap_size=${#sprite_alpha_cmap[@]}
    sprite_alpha_use_color216=0
}

function fn_sprite_cmap_grad()
{
    local -i _map_size=$1
    local -i _hue_end=$2
    local -i _sat_end=$3
    local -i _end_pad=$4

    # start color is from the theme
    #local -i _sgr_start=${theme_active_data[THEME_SET_DEF_INACTIVE]}
    #((_sgr_start -= THEME_CFG_HSL_BASE))

    # compute start color
    fn_hsl216_get $HSL216_HUE_GREEN 4 4
    local -i _sgr_start=$?

    # compute end color
    fn_hsl216_get $_hue_end $_sat_end 5
    local -i _sgr_end=$?

    # compute gradient colormap
    sprite_alpha_use_color216=1
    sprite_alpha_cmap=()
    local -i _grad_size=$((_map_size - _end_pad))
    fn_rgb216_gradient 'sprite_alpha_cmap' $_grad_size $_sgr_start $_sgr_end

    # add repeating colors to the end
    local -i _map_idx
    for((_map_idx=_grad_size; _map_idx < _map_size; _map_idx++))
    do
        sprite_alpha_cmap[_map_idx]=$_sgr_end
    done

    sprite_alpha_cmap_size=${#sprite_alpha_cmap[@]}
}

##
# Debugging only.
##

declare -i sprite_fps_last_time
declare -i sprite_fps_counter
declare -i sprite_fps_last_value
declare -i sprite_active_rows

function fn_sprite_debug_init()
{
    sprite_fps_last_time=$(date +%s)
    sprite_fps_counter=0
    sprite_fps_last_value=0
    sprite_active_rows=0
    
    fn_sprite_debug_update_msg
}

function fn_sprite_debug_update_msg()
{
    local -i _last_inactive=${1:-0}

    fn_sprite_debug_update_fps

    if((!UTIL_DEBUG_ENABLE))
    then
        return
    fi

    fn_util_debug_msg "FPS<%d> active_rows<%d> last_sprite<%s>     " \
            $sprite_fps_last_value \
            $sprite_active_rows \
            ${sprite_animate_map[_last_inactive]}

    fn_util_debug_print
}

function fn_sprite_debug_update_fps()
{
    if((sprite_fps_counter < 70))
    then
        # don't update
        return
    fi

    # calculate FPS value
    local -i _new_time=$(date +%s)
    local -i _time_diff=$((_new_time - sprite_fps_last_time))
    sprite_fps_last_value=$((sprite_fps_counter / _time_diff))

    # reset timer
    sprite_fps_last_time=$_new_time
    sprite_fps_counter=0
}

##
# Functions not currently used.
##

function fn_sprite_set_col_flare()
{
    fn_sprite_random_int $sprite_canvas_width
    local -i _col_rand=$?
    local -i _row_idx
    local -i _col_pos

    for((_row_idx=0; _row_idx < sprite_canvas_height; _row_idx++))
    do
        _col_pos=${sprite_buf_col_pos[_row_idx]}
        fn_sprite_alpha_map_set $_row_idx $((_col_rand)) -1
    done
}

declare -i sprite_rand_last=$$

# Linear-feedback shift register
# https://en.wikipedia.org/wiki/Linear-feedback_shift_register
function fn_sprite_random_int()
{
    local -i _max=$1

    local -i _bit_temp
    local -i _lfsr=$sprite_rand_last

    # taps: 16 14 13 11; feedback polynomial: x^16 + x^14 + x^13 + x^11 + 1 
    _bit_temp=$(( ((_lfsr >> 0) ^ (_lfsr >> 2) ^ (_lfsr >> 3) ^ (_lfsr >> 5) ) & 1 ))
    _lfsr=$(( (_lfsr >> 1) | (_bit_temp << 15) ))

    sprite_rand_last=$_lfsr

    return $(( _lfsr % _max ))
}
