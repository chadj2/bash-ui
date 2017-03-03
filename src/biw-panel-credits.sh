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

# constants
declare -r CRED_ANIMATE_DELAY=0.03
declare -ir CRED_CURSOR_PERIOD=14
declare -ir CRED_CURSOR_MAX=$((CRED_CURSOR_PERIOD * 3))

# panel layout
declare -i cred_height
declare -i cred_width
declare -i cred_row_pos

declare -a cred_line_data
declare -i cred_line_data_size

declare -i cred_canvas_row_pos
declare -i cred_canvas_col_pos
declare -i cred_canvas_width
declare -i cred_canvas_height

declare -a cred_color_map
declare -i cred_color_map_size
declare -i cred_color_use_216=0
declare -a cred_alpha_map

function fn_cred_show()
{
    # Panel geometry
    cred_height=$((BIW_PANEL_HEIGHT - HMENU_HEIGHT))
    cred_width=$BIW_PANEL_WIDTH
    cred_row_pos=$HMENU_HEIGHT

    # geometry of drawing canvas
    cred_canvas_row_pos=$cred_row_pos
    cred_canvas_col_pos=1
    cred_canvas_width=$((cred_width - 2))
    cred_canvas_height=$((cred_height - 1))

    cred_alpha_map[cred_canvas_width]=0

    # Use one of 3 color map types:
    fn_color_map_hsl_hue
    #fn_color_map_hsl_saturation
    #fn_color_map_simple

    cred_color_map_size=${#cred_color_map[@]}

    fn_cred_blank_panel
    fn_cred_load_data
    fn_biw_debug_print
    
    fn_cred_print_data
    local -i _result=$?

    fn_biw_debug_msg "result: %d" $_result

    # if animation was canceled then we get a non-zero status
    return $_result
}

function fn_cred_load_data()
{
    mapfile -n${cred_height} -t cred_line_data <<-EOM

BIW - Bash Inline Widgets
Version ${BIW_VERSION}
Copyright 2017 by Chad Juliano
chadj@pobox.com

Find it at:
https://github.com/chadj2/biw-tools
EOM

    cred_line_data_size=${#cred_line_data[*]}
}

function fn_cred_set_color()
{
    local -i _sgr_color=$1
    if((cred_color_use_216))
    then
        fn_sgr_color216_set $SGR_ATTR_FG $_sgr_color
    else
        fn_sgr_color16_set $SGR_ATTR_FG $_sgr_color
    fi
}

function fn_color_map_simple()
{
    cred_color_map=(
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

function fn_color_map_hsl_hue()
{
    local -ir _hsl_sat=4
    local -ir _hsl_light=5
    local -ir _color_repeat=2

    local -i _hsl_hue
    local -i _sgr_code
    local -i _map_idx=0

    # 0 index is reserved
    cred_color_use_216=1
    cred_color_map=()
    cred_color_map[_map_idx++]=0

    for((_hsl_hue = HSL216_HUE_GREEN; _hsl_hue <= HSL216_HUE_BLUE; _hsl_hue++))
    do
        fn_hsl216_get $_hsl_hue $_hsl_sat $_hsl_light
        _sgr_code=$?

        for((_hsl_sat_length = 0; _hsl_sat_length <= $_color_repeat; _hsl_sat_length++))
        do
            cred_color_map[_map_idx++]=$_sgr_code
        done
    done
}

function fn_color_map_hsl_saturation()
{
    # move through the HSL cylinder on hue=12 (120 degrees)
    local -ir _max_hsl_hue=3
    local -ir _min_hsl_hue=-5
    local -ir _hsl_hue=12
    local -ir _hsl_light=5

    local -i _hsl_sat
    local -i _sgr_code
    local -i _map_idx=0

    # 0 index is reserved
    cred_color_use_216=1
    cred_color_map=()
    cred_color_map[_map_idx++]=0

    # go through cylinder from the color indicated by hue to its inverse.
    # we go from partially saturated green (sat=3) because (sat=5) is too deep.
    for((_hsl_sat = _max_hsl_hue; _hsl_sat >= _min_hsl_hue; _hsl_sat--))
    do
        fn_hsl216_get $_hsl_hue $_hsl_sat $_hsl_light
        _sgr_code=$?

        for((_hsl_sat_length = 0; _hsl_sat_length <= 4; _hsl_sat_length++))
        do
            cred_color_map[_map_idx++]=$_sgr_code
        done
    done
}

function fn_cred_print_data()
{
    local -i _line_idx
    local -i _persist_cursor=0

    for((_line_idx = 0; _line_idx < cred_line_data_size; _line_idx++))
    do
        local _line_val="${cred_line_data[_line_idx]:-}"
        fn_cred_canvas_set_cursor $_line_idx 0

        if((_line_idx == (cred_line_data_size - 1)))
        then
            _persist_cursor=1
        fi

        if ! fn_cred_print_line "${_line_val}" $_persist_cursor
        then
            # cancel by user input
            return 1
        fi
    done

    return 0
}

function fn_cred_print_line()
{
    local _line_val=$1
    local -i _persist_cursor=$2

    local -i _line_width=${#_line_val}

    if((_line_width == 0))
    then
        return 0
    fi

    # init zero valued array
    local _char_idx
    for((_char_idx=0; _char_idx < _line_width; _char_idx++))
    do
        cred_alpha_map[_char_idx]=0
    done

    # set the cursor in a position that will center the text
    local -i _line_start=$(((cred_canvas_width - _line_width) / 2))

    local _result_char
    local -i _terminate_loop

    # sprite indicators
    local -i _text_active=1
    local -i _text_idx=0

    local -i _alpha_active=1

    local -i _cursor_active=0
    local -i _cursor_counter=$CRED_CURSOR_MAX

    # start main animation loop. 
    # Elements execute asynchronously.
    while fn_biw_process_key '_result_char' $CRED_ANIMATE_DELAY
    do
        _terminate_loop=1

        # render sprites
        if((_text_active)); then
            if ! fn_cred_animate_text; then _text_active=0; fi
            _terminate_loop=0
        fi

        if((_alpha_active)); then
            if ! fn_cred_print_alpha; then  _alpha_active=0; fi
            _terminate_loop=0
        fi

        if((_cursor_active)); then
            if ! fn_cred_animate_cursor; then _cursor_active=0; fi
            _terminate_loop=0
        fi

        # apply logic to sprites
        if((!_cursor_active))
        then
            # if text ended but counter still has ticks then activate
            if((!_text_active && _cursor_counter > 0))
            then
                _cursor_active=1
            fi

            # if we are at the end of the last line then 
            # keep the cursor going
            if((_persist_cursor && _terminate_loop))
            then
                _cursor_active=1
            fi

            if((_cursor_active))
            then
                _cursor_counter=$CRED_CURSOR_MAX
                _terminate_loop=0
            fi
        fi

        if((_terminate_loop))
        then
            # normal termination
            return 0
        fi
    done

    # cancel by user input
    return 1
}

function fn_cred_animate_text()
{
    # add characters to the alpha map
    if((_text_idx >= _line_width))
    then
        return 1
    fi
    
    cred_alpha_map[_text_idx]=$((cred_color_map_size - 1))
    ((_text_idx++))

    return 0
}

function fn_cred_print_alpha()
{
    local -i _line_width=${#_line_val}

    local -i _alpha_idx
    local -i _alpha_val
    local -i _alpha_start=-1

    # find the first nonzero alpha value
    for((_alpha_idx=0; _alpha_idx < $_line_width; _alpha_idx++))
    do
        _alpha_val=${cred_alpha_map[_alpha_idx]}

        if((_alpha_val > 0))
        then
            _alpha_start=_alpha_idx
            break
        fi
    done

    if((_alpha_start < 0))
    then
        # nothing to do
        return 1
    fi

    fn_biw_set_col_pos $((_line_start + _alpha_start))

    fn_sgr_seq_start

    local _char_val
    local -i _alpha_color

    for((_alpha_idx=_alpha_start; _alpha_idx < $_line_width; _alpha_idx++))
    do
        _alpha_val=${cred_alpha_map[_alpha_idx]}
        if((_alpha_val == 0))
        then
            # we hit the end
            break
        fi

        _alpha_color=${cred_color_map[_alpha_val]}
        fn_cred_set_color $_alpha_color

        _char_val=${_line_val:_alpha_idx:1}
        fn_sgr_print "${_char_val}"

        # each value in the alpha list needs to get decremented
        cred_alpha_map[_alpha_idx]=$((_alpha_val - 1))
    done

    # this will flush the buffer and print the output
    fn_sgr_seq_flush

    return 0
}

function fn_cred_animate_cursor()
{
    local -i _should_show=0

    if((_cursor_counter <= 0))
    then
        # hide
        fn_cred_print_cursor $_should_show
        return 1
    fi

    if(( !(_cursor_counter % (CRED_CURSOR_PERIOD / 2)) ))
    then
        _should_show=$(( !(_cursor_counter % CRED_CURSOR_PERIOD) ))
        fn_cred_print_cursor $_should_show
    fi

    ((_cursor_counter--))

    return 0
}

function fn_cred_print_cursor()
{
    local -i _cursor_pos=$((_line_start + _line_width))
    local -i _should_show=$1

    fn_biw_set_col_pos $_cursor_pos

    local _sgr_color=${cred_color_map[cred_color_map_size - 1]}
    fn_cred_set_color $_sgr_color

    local _sgr_char=" "
    if((_should_show))
    then
        _sgr_char="_"
    fi

    fn_sgr_print "$_sgr_char"
}

function fn_cred_canvas_set_cursor()
{
    local -i _row_pos=$1
    local -i _col_pos=$2
    fn_biw_set_cursor_pos \
        $((cred_canvas_row_pos + _row_pos)) \
        $((cred_canvas_col_pos + _col_pos))

    fn_theme_set_attr $TATTR_BG_INACTIVE
}

function fn_cred_blank_panel()
{
    local -i _line_idx

    for((_line_idx = 0; _line_idx < cred_height; _line_idx++))
    do
        local -i _row_pos=$((cred_row_pos + _line_idx))
        fn_biw_set_cursor_pos $_row_pos 0

        fn_sgr_seq_start
        fn_theme_set_attr $TATTR_BG_INACTIVE

        if((_line_idx < cred_canvas_height))
        then
            fn_cred_blank_line
        else
            fn_cred_bottom_line
        fi
        fn_sgr_seq_flush
    done
}

function fn_cred_blank_line()
{
    local _line_val=""
    fn_sgr_pad_string "_line_val" $cred_canvas_width
    fn_utf8_print $BIW_CHAR_LINE_VERT
    fn_sgr_print "$_line_val"
    fn_utf8_print $BIW_CHAR_LINE_VERT
}

function fn_cred_bottom_line()
{
    # draw bottom box
    fn_utf8_print $BIW_CHAR_LINE_BL
    fn_utf8_print_h_line $cred_canvas_width
    fn_utf8_print $BIW_CHAR_LINE_BR
}
