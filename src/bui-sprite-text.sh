
##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-sprite-text.sh
# Description:  Rednder text and cursor to color map.
##

##
# Sprite: Print
# Description: Print text to alpha map
##

declare -ir SPRITE_ID_PRINT=$((sprite_count++))
sprite_animate_map[$SPRITE_ID_PRINT]=fn_sprite_print_animate
sprite_start_map[$SPRITE_ID_PRINT]=fn_sprite_print_start

declare -i sprite_print_col_idx
declare -i sprite_print_col_size
declare -i sprite_print_row_pos


function fn_sprite_buf_init()
{
    local -a _text_ref=( "${!1}" )

    # center text in buffer
    local -i _line_idx
    local -i _text_size=${#_text_ref[@]}
    local -i _text_start_idx=$(( (sprite_canvas_height - _text_size)/2 ))

    for((_line_idx=0; _line_idx < sprite_canvas_height; _line_idx++))
    do
        local -i _text_idx=$((_line_idx - _text_start_idx))
        local _current_line=''
        if((_text_idx >= 0 && _text_idx < _text_size))
        then
            _current_line="${_text_ref[_text_idx]}"
        fi

        local -i _line_size=${#_current_line}
        sprite_buf_col_pos[_line_idx]=$(((sprite_canvas_width - _line_size) / 2))
        sprite_buf_data[_line_idx]="$_current_line"
    done
}

function fn_sprite_print_start()
{
    sprite_print_row_pos=$1

    local _current_line="${sprite_buf_data[sprite_print_row_pos]:-}"
    local _line_size=${#_current_line}

    if((!_line_size))
    then
        return 1
    fi

    sprite_print_col_idx=${sprite_buf_col_pos[sprite_print_row_pos]}
    sprite_print_col_size=$((_line_size + sprite_print_col_idx))

    return 0
}

function fn_sprite_print_animate()
{
    # add characters to the alpha map
    if((sprite_print_col_idx >= sprite_print_col_size))
    then
        return 1
    fi
    
    fn_sprite_alpha_map_set $sprite_print_row_pos $sprite_print_col_idx -1
    ((sprite_print_col_idx++))

    return 0
}

##
# Sprite: Cursor
# Description: Show flashing cursor
##

declare -ir SPRITE_ID_CURSOR=$((sprite_count++))
sprite_animate_map[$SPRITE_ID_CURSOR]=fn_sprite_cursor_animate
sprite_start_map[$SPRITE_ID_CURSOR]=fn_sprite_cursor_start

declare -ir SPRITE_CURSOR_PERIOD=8
declare -ir SPRITE_CURSOR_PERIOD_MAX=$(( SPRITE_CURSOR_PERIOD*2 ))

declare -i sprite_cursor_counter
declare -i sprite_cursor_col_pos
declare -i sprite_cursor_row_pos

function fn_sprite_cursor_start()
{
    sprite_cursor_row_pos=$1

    local -i _col_pos=${sprite_buf_col_pos[sprite_cursor_row_pos]}
    local _char_data=${sprite_buf_data[sprite_cursor_row_pos]}
    local -i _char_size=${#_char_data}

    sprite_cursor_col_pos=$((_col_pos + _char_size))
    sprite_cursor_counter=$SPRITE_CURSOR_PERIOD_MAX
}

function fn_sprite_cursor_animate()
{
    local -i _should_show=0

    if((sprite_cursor_counter <= 0))
    then
        # hide
        fn_sprite_cursor_print $_should_show
        return 1
    fi

    if(( !(sprite_cursor_counter % (SPRITE_CURSOR_PERIOD / 2)) ))
    then
        _should_show=$(( !(sprite_cursor_counter % SPRITE_CURSOR_PERIOD) ))
        fn_sprite_cursor_print $_should_show
    fi

    ((sprite_cursor_counter--))

    return 0
}

function fn_sprite_cursor_print()
{
    local -i _should_show=$1

    fn_sprite_canvas_set_row $sprite_cursor_row_pos
    fn_sprite_canvas_set_col $sprite_cursor_col_pos

    local _sgr_char=' '
    if((_should_show))
    then
        _sgr_char='_'
    fi

    fn_sgr_print "$_sgr_char"
}
