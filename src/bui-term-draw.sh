##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-term-draw.sh
# Description:  Screen drawing primitives and UTF8 support. 
##

source ${BUI_HOME}/bui-term-csi.sh

# global panel geometry
declare -ir DRAW_PANEL_MARGIN=10

# determines speed of panel open/close
declare -r DRAW_OC_ANIMATE_DELAY=0.01

declare -i draw_panel_col_size
declare -i draw_panel_row_size

# UTF-8 codepoints are cached as encoded values.
function fn_draw_utf8_init()
{
    fn_draw_utf8_set_readonly BUI_CHAR_QUOTE_LT      0x00AB
    fn_draw_utf8_set_readonly BUI_CHAR_QUOTE_RT      0x00BB
    fn_draw_utf8_set_readonly BUI_CHAR_BULLET        0x2022
    fn_draw_utf8_set_readonly BUI_CHAR_DBL_EXCL      0x203C
    fn_draw_utf8_set_readonly BUI_CHAR_CHECK         0x221A
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_HZ       0x2500
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_VT       0x2502
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_BT_LT    0x2514
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_BT_RT    0x2518
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_T_LT     0x251C
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_T_RT     0x2524
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_T_TOP    0x252C
    fn_draw_utf8_set_readonly BUI_CHAR_LINE_T_BT     0x2534
    fn_draw_utf8_set_readonly BUI_CHAR_BLOCK         0x2592
    fn_draw_utf8_set_readonly BUI_CHAR_TRIANGLE_UP   0x25B2
    fn_draw_utf8_set_readonly BUI_CHAR_TRIANGLE_RT   0x25BA
    fn_draw_utf8_set_readonly BUI_CHAR_TRIANGLE_DN   0x25BC
    fn_draw_utf8_set_readonly BUI_CHAR_TRIANGLE_LT   0x25C4
    fn_draw_utf8_set_readonly BUI_CHAR_DIAMOND       0x25C6
}

function fn_draw_set_cursor_pos()
{
    local -i _abs_row=$1
    local -i _abs_col=$2

    fn_draw_set_row_pos $_abs_row
    fn_draw_set_col_pos $_abs_col
}

function fn_draw_set_row_pos()
{
    local -i _abs_row=$1
    fn_csi_op $CSI_OP_ROW_POS $((sgr_cache_row_pos - draw_panel_row_size + _abs_row))

    # old method:
    #fn_csi_op $CSI_OP_CURSOR_RESTORE
    #fn_csi_op $CSI_OP_ROW_UP $((draw_panel_row_size - _abs_row))
}

function fn_draw_set_col_pos()
{
    local -i _abs_col=$1
    fn_csi_op $CSI_OP_COL_POS $((DRAW_PANEL_MARGIN + _abs_col))
}

function fn_draw_print_pad()
{
    local _pad_str=$1
    local -i _pad_width=$2

    printf -v _pad_str "%-${_pad_width}s" "$_pad_str"
    printf -v _pad_str '%s' "${_pad_str:0:${_pad_width}}"
    fn_sgr_print "$_pad_str"
}

function fn_draw_print_width()
{
    local _out="$1"
    local -i _line_width=$2

    local _out_trim="${_out:0:${_line_width}}"
    local -i _out_size=${#_out_trim}
    local -i _pad_chars=$((_line_width - _out_size))

    fn_sgr_print "$_out_trim"
    fn_csi_op $CSI_OP_COL_ERASE $_pad_chars
    fn_csi_op $CSI_OP_COL_FORWARD $_pad_chars
}

function fn_draw_print_center()
{
    local _out="$1"
    local -i _line_width=$2

    local _out_trim="${_out:0:${_line_width}}"
    local -i _out_size=${#_out_trim}

    local _pad_chars=$(( (_line_width - _out_size)/2 ))
    fn_csi_op $CSI_OP_COL_ERASE $_pad_chars
    fn_csi_op $CSI_OP_COL_FORWARD $_pad_chars
    ((_line_width -= _pad_chars))

    fn_sgr_print "$_out_trim"
    ((_line_width -= _out_size))

    fn_csi_op $CSI_OP_COL_ERASE $_line_width
    fn_csi_op $CSI_OP_COL_FORWARD $_line_width
}


function fn_draw_hz_line()
{
    local -i _line_width=$1
    local _sgr_line
    local _pad_char=$BUI_CHAR_LINE_HZ

    printf -v _sgr_line '%*s' $_line_width
    printf -v _sgr_line '%b' "${_sgr_line// /${_pad_char}}"
    fn_sgr_seq_write $_sgr_line
}


function fn_draw_box_panel()
{
    local -i _start_row=$1
    local _msg_ref=${2:-}
    local -i _theme_attr=${3:-$THEME_SET_DEF_INACTIVE}

    local -a _msg_array=()

    if [ -n "$_msg_ref" ]
    then
        _msg_array=( "${!_msg_ref}" )
    fi

    local -i _msg_idx=0
    local -i _row_idx
    local -i _last_idx=$((draw_panel_row_size - 1))

    for((_row_idx=hmenu_row_pos + 1; _row_idx <= _last_idx; _row_idx++))
    do
        fn_sgr_seq_start

        fn_draw_set_cursor_pos $_row_idx 0
        fn_theme_set_attr $_theme_attr

        if((_row_idx < _last_idx))
        then
            fn_draw_utf8_print $BUI_CHAR_LINE_VT

            local _msg_line="${_msg_array[_msg_idx++]:-}"
            fn_draw_print_center " $_msg_line" $((draw_panel_col_size - 2))
            
            fn_draw_utf8_print $BUI_CHAR_LINE_VT
        else
            fn_draw_utf8_print $BUI_CHAR_LINE_BT_LT
            fn_draw_hz_line $((draw_panel_col_size - 2))
            fn_draw_utf8_print $BUI_CHAR_LINE_BT_RT
        fi
        fn_sgr_seq_flush
    done
}

function fn_draw_clear_screen()
{
    local -i _start_row=$1

    local -i _row_idx
    local -i _last_idx=$((draw_panel_row_size - 1))

    fn_sgr_seq_start

    for((_row_idx=_start_row; _row_idx <= _last_idx; _row_idx++))
    do
        fn_draw_set_cursor_pos $_row_idx 0
        fn_theme_set_attr_panel 0
        fn_csi_op $CSI_OP_COL_ERASE $draw_panel_col_size
        fn_csi_op $CSI_OP_COL_FORWARD $draw_panel_col_size
    done

    fn_sgr_seq_flush
}

function fn_draw_footer_bar()
{
    local _message="$1"

    fn_sgr_seq_start
    fn_draw_set_cursor_pos $((draw_panel_row_size - 1)) 0

    fn_theme_set_attr_slider 1
    fn_draw_utf8_print $BUI_CHAR_LINE_BT_LT
    fn_sgr_print ' '
    fn_draw_print_width "$_message" $((draw_panel_col_size - 2))
    
    fn_sgr_seq_flush
}

function fn_draw_scroll_resize()
{
    local -i _rows=$1

    local -i _line_idx
    local -i _row_count

    if((_rows < 0))
    then
        # position the cursor at the start of the menu
        fn_draw_set_cursor_pos 0 0

        _row_count=$((_rows*-1))

        # animate close
        for((_line_idx = 0; _line_idx < _row_count; _line_idx++))
        do
            fn_csi_op $CSI_OP_ROW_DELETE 1
            fn_csi_op $CSI_OP_SCROLL_DOWN 1
            fn_csi_op $CSI_OP_ROW_DOWN 1
            fn_csi_milli_wait $DRAW_OC_ANIMATE_DELAY
        done

        # clear out any junk on the line
        fn_csi_op $CSI_OP_ROW_ERASE
        
        # non-animate close:
        #fn_csi_op $CSI_OP_ROW_DELETE $draw_panel_row_size
        #fn_csi_op $CSI_OP_SCROLL_DOWN $draw_panel_row_size
    else

        _row_count=$_rows

        # animate open
        for((_line_idx = 0; _line_idx < _row_count; _line_idx++))
        do
            fn_csi_op $CSI_OP_SCROLL_UP 1
            fn_csi_milli_wait $DRAW_OC_ANIMATE_DELAY
        done

        # non-animated open:
        #fn_csi_op $CSI_OP_SCROLL_UP $draw_panel_row_size
        #fn_bui_cursor_home
        #fn_csi_op $CSI_OP_ROW_INSERT $draw_panel_row_size
    fi
}

function fn_draw_utf8_print()
{
    local _utf8_encoded=$1
    local _repeat=${2:-1}

    local _utf8_raw
    printf -v _utf8_raw '%b' $_utf8_encoded

    local -i _count
    for((_count = 0; _count < _repeat; _count++))
    do
        fn_sgr_seq_write "$_utf8_raw"
    done
}

function fn_draw_utf8_cp_print()
{
    local -i _ordinal=$1
    local _utf8_raw

    fn_draw_utf8_get_encoded _utf8_raw $_ordinal
    fn_draw_utf8_print "$_utf8_raw"
}

function fn_draw_utf8_set_var()
{
    local _result_ref=$1
    local _utf8_encoded="$2"
    
    printf -v $_result_ref '%b' "$_utf8_encoded"
}

function fn_draw_utf8_set_readonly()
{
    local _result_ref=$1
    local -i _ordinal=$2

    local _result_val
    fn_draw_utf8_get_encoded '_result_val' $_ordinal

    # set the result to a new readonly variable
    readonly $_result_ref=$_result_val
}

function fn_draw_utf8_get_encoded()
{
    local _result_ref=$1
    local -i _ordinal=$2

    # Bash only supports \u \U since 4.2 so we encode manually.

    if [[ $_ordinal -le 0x7f ]]
    then
        printf -v $_result_ref '\\%03o' "$_ordinal"

    elif [[ $_ordinal -le 0x7ff        ]]
    then
        printf -v $_result_ref '\\%03o' \
            $((  (${_ordinal}>> 6)      |0xc0 )) \
            $(( ( ${_ordinal}     &0x3f)|0x80 ))

    elif [[ $_ordinal -le 0xffff       ]]
    then
        printf -v $_result_ref '\\%03o' \
            $(( ( ${_ordinal}>>12)      |0xe0 )) \
            $(( ((${_ordinal}>> 6)&0x3f)|0x80 )) \
            $(( ( ${_ordinal}     &0x3f)|0x80 ))

    elif [[ $_ordinal -le 0x1fffff     ]]
    then
        printf -v $_result_ref '\\%03o'  \
            $(( ( ${_ordinal}>>18)      |0xf0 )) \
            $(( ((${_ordinal}>>12)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>> 6)&0x3f)|0x80 )) \
            $(( ( ${_ordinal}     &0x3f)|0x80 ))

    elif [[ $_ordinal -le 0x3ffffff    ]]
    then
        printf -v $_result_ref '\\%03o'  \
            $(( ( ${_ordinal}>>24)      |0xf8 )) \
            $(( ((${_ordinal}>>18)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>>12)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>> 6)&0x3f)|0x80 )) \
            $(( ( ${_ordinal}     &0x3f)|0x80 ))

    elif [[ $_ordinal -le 0x7fffffff ]]
    then
        printf -v $_result_ref '\\%03o'  \
            $(( ( ${_ordinal}>>30)      |0xfc )) \
            $(( ((${_ordinal}>>24)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>>18)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>>12)&0x3f)|0x80 )) \
            $(( ((${_ordinal}>> 6)&0x3f)|0x80 )) \
            $(( ( ${_ordinal}     &0x3f)|0x80 ))

    else
        fn_util_die "Could not convert UTF-8 ordinal: <$_ordinal>"
    fi
}

fn_draw_utf8_init
