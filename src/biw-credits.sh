##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
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

    fn_cred_blank_panel
    fn_cred_load_data
    fn_generate_color_map
    fn_cred_print_data

    # if animation was canceled then we get a non-zero status
    return $?
}

function fn_generate_color_map()
{
    fn_theme_get_sgr $SGR_ATTR_FG $TATTR_TEXT
    _sgr_text_color=$(($? - SGR_ATTR_FG))

    cred_color_map=(
        [1]=$_sgr_text_color
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

    cred_color_map_size=${#cred_color_map[@]}
}

function fn_cred_print_data()
{
    local -i _line_idx
    local -i _persist_cursor=0

    for((_line_idx = 0; _line_idx < cred_canvas_height; _line_idx++))
    do
        local _line_val="${cred_line_data[_line_idx]:-}"
        fn_cred_canvas_set_cursor $_line_idx 0

        if((_line_idx == (cred_canvas_height - 1)))
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

    # sprite indicators
    local -i _text_active=1
    local -i _alpha_active=1
    local -i _cursor_active=0

    local -i _char_idx=0
    local -i _cursor_counter=$CRED_CURSOR_MAX
    local _result_char

    # start main animation loop
    while fn_biw_process_key _result_char $CRED_ANIMATE_DELAY
    do
        # activate chars in alpha map
        if((_text_active))
        then
            if ! fn_cred_animate_text $_char_idx $_line_width
            then
                _text_active=0
                _cursor_active=1
            fi
            ((_char_idx++))
        fi

        # process alpha map
        if((_alpha_active))
        then
            if ! fn_cred_print_alpha "$_line_val" $_line_start
            then
                _alpha_active=0
            fi
        fi

        # process cursor
        if((_cursor_active))
        then
            if ! fn_cred_animate_cursor $((_line_start + _line_width))
            then
                _cursor_active=$_persist_cursor
            fi
            ((_cursor_counter--))
        fi

        if((!_alpha_active && !_cursor_active))
        then
            # nothing left for fn_cred_print_alpha
            # normal termination
            return 0
        fi
    done

    # cancel by user input
    return 1
}

function fn_cred_animate_text()
{
    local -i _char_idx=$1
    local -i _line_width=$2

    # add characters to the alpha map
    if((_char_idx < _line_width))
    then
        cred_alpha_map[_char_idx]=${#cred_color_map[@]}
    else
        return 1
    fi

    return 0
}

function fn_cred_animate_cursor()
{
    local -i _cursor_pos=$1

    if(( _cursor_counter % (CRED_CURSOR_PERIOD / 2) ))
    then
        # nothing to do
        return 0
    fi

    fn_biw_set_col_pos $_cursor_pos

    local _sgr_color=${cred_color_map[cred_color_map_size - 1]}
    fn_sgr_set $((SGR_ATTR_FG + _sgr_color))

    if((_cursor_counter <= 0))
    then
        # terminate
        _cursor_counter=$((CRED_CURSOR_MAX + 1))
        fn_sgr_print " "
        return 1
    fi

    local _sgr_char=" "
    if(( !(_cursor_counter % CRED_CURSOR_PERIOD) ))
    then
        _sgr_char="_"
    fi

    fn_sgr_print "$_sgr_char"

    return 0
}

function fn_cred_print_alpha()
{
    local _line_val=$1
    local -i _line_start=$2
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
        fn_sgr_set $((SGR_ATTR_FG + _alpha_color))

        _char_val=${_line_val:_alpha_idx:1}
        fn_sgr_print "${_char_val}"

        # each value in the alpha list needs to get decremented
        cred_alpha_map[_alpha_idx]=$((_alpha_val - 1))
    done

    # this will flush the buffer and print the output
    fn_sgr_seq_flush

    return 0
}

function fn_cred_load_data()
{
    mapfile -n${cred_height} -t cred_line_data <<-EOM

BIW - Bash Inline Widgets
Copyright 2017 by Chad Juliano
chadj@pobox.com

Find it at:
https://github.com/chadj2/biw-tools
EOM

    cred_line_data_size=${#cred_line_data[*]}
}

function fn_cred_canvas_set_cursor()
{
    local -i _row_pos=$1
    local -i _col_pos=$2
    fn_biw_set_cursor_pos \
        $((cred_canvas_row_pos + _row_pos)) \
        $((cred_canvas_col_pos + _col_pos))

    fn_theme_set_bg_attr $TATTR_BG_INACTIVE
}

function fn_cred_blank_panel()
{
    local -i _line_idx

    for((_line_idx = 0; _line_idx < cred_height; _line_idx++))
    do
        local -i _row_pos=$((cred_row_pos + _line_idx))
        fn_biw_set_cursor_pos $_row_pos 0

        fn_sgr_seq_start
        fn_theme_set_bg_attr $TATTR_BG_INACTIVE

        if((_line_idx < cred_canvas_height))
        then
            fn_cred_blank_line
        else
            fn_cred_draw_bottom
        fi
        fn_sgr_seq_flush
    done
}

function fn_cred_blank_line()
{
    local _line_val
    fn_cred_repeat_chars "_line_val" $cred_canvas_width
    fn_sgr_print $CSI_CHAR_LINE_VERT
    fn_sgr_print "$_line_val"
    fn_sgr_print $CSI_CHAR_LINE_VERT
}

function fn_cred_draw_bottom()
{
    local _dsc_start=$'\e(0'
    local _dsc_horiz_line=$'\x71'
    local _dsc_end=$'\e(B'

    # draw bottom box
    fn_sgr_print $CSI_CHAR_LINE_BL
    fn_sgr_print $_dsc_start

    local _bottom_line
    fn_cred_repeat_chars "_bottom_line" $cred_canvas_width $_dsc_horiz_line
    fn_sgr_print $_bottom_line

    fn_sgr_print $CSI_CHAR_LINE_BR
    fn_sgr_print $_dsc_end
}

function fn_cred_repeat_chars()
{
    local _var_name=$1
    local -i _pad_width=$2
    local _pad_char=${3:- }

    printf -v $_var_name '%*s' $_pad_width
    local _result_val=${!_var_name// /${_pad_char}}
    eval $_var_name='$_result_val'
}
