##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-panel-credits.sh
# Description:  Panel for animated credits.
##


# panel layout
declare -i cred_height
declare -i cred_width
declare -i cred_row_pos

declare -i cred_canvas_row_pos
declare -i cred_canvas_col_pos
declare -i cred_canvas_width
declare -i cred_canvas_height

function fn_cred_show()
{
    # Panel geometry
    cred_height=$((biw_panel_row_size - HMENU_ROW_SIZE))
    cred_width=$biw_panel_col_size
    cred_row_pos=$HMENU_ROW_SIZE

    cred_canvas_col_pos=1
    cred_canvas_width=$((cred_width - 2))
    fn_sprite_buf_init

    # geometry of drawing canvas
    cred_canvas_height=$((cred_height - 1))
    cred_canvas_row_pos=$(( (cred_canvas_height - sprite_buf_size - 1)/2 ))

    fn_util_draw_box_panel $cred_row_pos
    fn_cred_start_state
}

function fn_cred_canvas_set_cursor()
{
    local -i _row_pos=$1
    local -i _col_pos=$2

    fn_util_set_cursor_pos \
        $((cred_canvas_row_pos + _row_pos)) \
        $((cred_canvas_col_pos + _col_pos))
}

declare -a sprite_buf_data
declare -a sprite_buf_col_pos
declare -i sprite_buf_size

function fn_sprite_buf_init()
{

    mapfile -n${cred_height} -t sprite_buf_data <<-EOM

BIW - Bash Inline Widgets

Version ${BIW_VERSION}
Copyright 2017 by Chad Juliano
chadj@pobox.com

Find it at:
https://github.com/chadj2/biw-tools
EOM

    mapfile -n${cred_height} -t sprite_buf_data <<-EOM
X1234567890123456789012345678901234567890

X12345678901234567890
EOM

    # center text in buffer
    sprite_buf_size=${#sprite_buf_data[*]}
    local -i _line_idx
    local -i _line_size
    local _current_line

    for((_line_idx=0; _line_idx < sprite_buf_size; _line_idx++))
    do
        _current_line="${sprite_buf_data[_line_idx]}"
        _line_size=${#_current_line}
        sprite_buf_col_pos[_line_idx]=$(((cred_canvas_width - _line_size) / 2))
    done
}

function fn_cred_start_state()
{
    # init sprite state
    fn_sprite_init
    fn_sprite_alpha_init

    local -i _last_inactive=$SPRITE_ID_CURSOR
    local -i _row_idx=0

    # Sprites follow a basic cycle:
    # 
    # 1. Sprites are started with fn_sprite_start.
    # 2. Sprites are animated with fn_sprite_timer_loop.
    # 3. fn_sprite_timer_loop returns when a single sprite terminates or user
    #    hits a key to cancel.
    # 4. The terminated sprite is evaluated to determine the next action 
    #    in the sequence.
    # 5. fn_sprite_timer_loop is called to resume animation until another 
    #    sprite terminates.
    # 
    # Note: At least one sprite must be active when calling fn_sprite_timer_loop 
    #    or process will exit.

    while ((_row_idx < sprite_buf_size))
    do
        case $_last_inactive in
            $SPRITE_ID_CURSOR)
                # cursor finished so print next line
                fn_sprite_start $SPRITE_ID_PRINT $_row_idx
                fn_sprite_start $SPRITE_ID_ALPHA $_row_idx
                ;;
            $SPRITE_ID_PRINT)
                ((_row_idx++))
                if((sprite_print_col_size))
                then
                    # show cursor and goto next line
                    fn_sprite_start $SPRITE_ID_CURSOR $((_row_idx - 1))
                else
                    # This is an empty line so get next line
                    _last_inactive=$SPRITE_ID_CURSOR
                    continue
                fi
                ;;
            $SPRITE_ID_ALPHA)
                # do nothing
                ;;
        esac

        # return if user cancel
        fn_sprite_timer_loop && return
        _last_inactive=$?
    done

    fn_util_assert_equals '_last_inactive' 'SPRITE_ID_ALPHA'

    while [ 1 ]
    do
        case $_last_inactive in
            $SPRITE_ID_CURSOR)
                # continuously show the cursor
                fn_sprite_start $SPRITE_ID_CURSOR $((_row_idx - 1))
                ;;
            $SPRITE_ID_ALPHA)
                # do nothing
                ;;
        esac

        # return if user cancel
        fn_sprite_timer_loop && return
        _last_inactive=$?
    done
}

##
# Sprite: Group control framework
##

declare -ir SPRITE_ID_NONE=0
declare -ir SPRITE_ID_PRINT=1
declare -ir SPRITE_ID_ALPHA=2
declare -ir SPRITE_ID_CURSOR=3

declare -ra SPRITE_ANIMATE_MAP=(
    id_reserved
    fn_sprite_print_animate
    fn_sprite_alpha_animate
    fn_sprite_cursor_animate )

declare -ir SPRITE_COUNT=${#SPRITE_ANIMATE_MAP[*]}

declare -ra SPRITE_START_MAP=(
    id_reserved
    fn_sprite_print_start
    fn_sprite_alpha_start
    fn_sprite_cursor_start )

declare -a sprite_status_map

function fn_sprite_init()
{
    local -i _sprite_idx
    for((_sprite_idx = 0; _sprite_idx < SPRITE_COUNT; _sprite_idx++))
    do
        sprite_status_map[_sprite_idx]=0
    done
}

function fn_sprite_is_inactive()
{
    local -i _sprite_id=$1
    local -i _sprite_status=${sprite_status_map[_sprite_id]}
    return $_sprite_status
}

function fn_sprite_start()
{
    local -i _sprite_id=$1
    local -i _sprite_status=${sprite_status_map[_sprite_id]}
    local _start_function=${SPRITE_START_MAP[_sprite_id]}

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

    fn_util_debug_msg "status<%s> last_sprite<%s>" \
            "${sprite_status_map[*]}" ${SPRITE_ANIMATE_MAP[_last_inactive]}

    fn_util_debug_print

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

    for((_sprite_idx=1; _sprite_idx < SPRITE_COUNT; _sprite_idx++))
    do
        local -i _sprite_status=${sprite_status_map[_sprite_idx]}
        local _animate_function=${SPRITE_ANIMATE_MAP[_sprite_idx]}

        if((_sprite_status))
        then
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
# Sprite: Render text to color map
##

declare -i sprite_print_col_idx
declare -i sprite_print_col_size
declare -i sprite_print_row_pos

function fn_sprite_print_start()
{
    sprite_print_row_pos=$1

    local _current_line="${sprite_buf_data[sprite_print_row_pos]:-}"
    sprite_print_col_size=${#_current_line}
    sprite_print_col_idx=0

    return 0
}

function fn_sprite_print_animate()
{
    # add characters to the alpha map
    if((sprite_print_col_idx >= sprite_print_col_size))
    then
        return 1
    fi
    
    sprite_alpha_map[sprite_print_col_idx]=$((sprite_alpha_colormap_size - 1))
    ((sprite_print_col_idx++))

    return 0
}

##
# Sprite: Render alpha color map
##

declare -a sprite_alpha_colormap
declare -i sprite_alpha_colormap_size
declare -i sprite_alpha_use_color216=0

declare -a sprite_alpha_map
declare -i sprite_alpha_row_pos
declare sprite_alpha_char_data
declare -i sprite_alpha_char_pos
declare -i sprite_alpha_char_size

function fn_sprite_alpha_init()
{
    sprite_alpha_map[cred_canvas_width]=0
    fn_sprite_alpha_colormap_hsl_hue
    #fn_sprite_alpha_colormap_simple
    sprite_alpha_colormap_size=${#sprite_alpha_colormap[@]}
}

function fn_sprite_alpha_start()
{
    sprite_alpha_row_pos=$1

    sprite_alpha_char_data=${sprite_buf_data[sprite_alpha_row_pos]}
    sprite_alpha_char_pos=${sprite_buf_col_pos[sprite_alpha_row_pos]}
    sprite_alpha_char_size=${#sprite_alpha_char_data}

    if((!sprite_alpha_char_size))
    then
        return 1
    fi

    # init zero valued array
    local _char_idx
    for((_char_idx=0; _char_idx < sprite_alpha_char_size; _char_idx++))
    do
        sprite_alpha_map[_char_idx]=0
    done

    return 0
}

function fn_sprite_alpha_animate()
{
    local -i _char_idx
    local -i _alpha_color
    local -i _cursor_pos=-1

    for((_char_idx=0; _char_idx < sprite_alpha_char_size; _char_idx++))
    do
        _alpha_color=${sprite_alpha_map[_char_idx]}
        if((_alpha_color == 0))
        then
            continue
        fi

        if((_cursor_pos < _char_idx))
        then
            _cursor_pos=$_char_idx
            fn_cred_canvas_set_cursor $sprite_alpha_row_pos $((sprite_alpha_char_pos + _cursor_pos))
            fn_theme_set_attr $THEME_SET_DEF_INACTIVE
        fi

        fn_sprite_alpha_set_color $_alpha_color
        fn_sgr_print "${sprite_alpha_char_data:_char_idx:1}"
        ((_cursor_pos++))

        # each value in the alpha list needs to get decremented
        sprite_alpha_map[_char_idx]=$((_alpha_color - 1))
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
    local -i _sgr_color=${sprite_alpha_colormap[_alpha_color]}

    if((sprite_alpha_use_color216))
    then
        fn_sgr_color216_set $SGR_ATTR_FG $_sgr_color
    else
        fn_sgr_color16_set $SGR_ATTR_FG $_sgr_color
    fi
}

function fn_sprite_alpha_colormap_simple()
{
    sprite_alpha_colormap=(
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
}

function fn_sprite_alpha_colormap_hsl_hue()
{
    local -ir _hsl_sat=4
    local -ir _hsl_light=5
    local -ir _color_repeat=2
    local -i _hsl_hue
    local -i _sgr_code
    local -i _map_idx=0

    # 0 index is reserved
    sprite_alpha_use_color216=1
    sprite_alpha_colormap=()
    sprite_alpha_colormap[_map_idx++]=0

    for((_hsl_hue = HSL216_HUE_GREEN; _hsl_hue <= HSL216_HUE_BLUE; _hsl_hue++))
    do
        fn_hsl216_get $_hsl_hue $_hsl_sat $_hsl_light
        _sgr_code=$?

        for((_hsl_sat_length = 0; _hsl_sat_length <= $_color_repeat; _hsl_sat_length++))
        do
            sprite_alpha_colormap[_map_idx++]=$_sgr_code
        done
    done
}

##
# Sprite: Show flashing cursor
##

declare -ir SPRITE_CURSOR_PERIOD=14
declare -ir SPRITE_CURSOR_PERIOD_MAX=$((SPRITE_CURSOR_PERIOD * 3))

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

    fn_cred_canvas_set_cursor $sprite_cursor_row_pos $sprite_cursor_col_pos
    fn_theme_set_attr $THEME_SET_DEF_INACTIVE
    fn_sprite_alpha_set_color $((sprite_alpha_colormap_size - 1))

    local _sgr_char=' '
    if((_should_show))
    then
        _sgr_char='_'
    fi

    fn_sgr_print "$_sgr_char"
}
