##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-decg.sh
# Description:  Send UTF-8 characters.
##

# UTF-8 codepoints are cached as encoded values.
function fn_utf8_init()
{
    fn_utf8_set_readonly BIW_CHAR_QUOTE_LT      0x00AB
    fn_utf8_set_readonly BIW_CHAR_QUOTE_RT      0x00BB
    fn_utf8_set_readonly BIW_CHAR_BULLET        0x2022
    fn_utf8_set_readonly BIW_CHAR_DBL_EXCL      0x203C
    fn_utf8_set_readonly BIW_CHAR_CHECK         0x221A
    fn_utf8_set_readonly BIW_CHAR_LINE_HZ       0x2500
    fn_utf8_set_readonly BIW_CHAR_LINE_VT       0x2502
    fn_utf8_set_readonly BIW_CHAR_LINE_BT_LT    0x2514
    fn_utf8_set_readonly BIW_CHAR_LINE_BT_RT    0x2518
    fn_utf8_set_readonly BIW_CHAR_LINE_T_TOP    0x252C
    fn_utf8_set_readonly BIW_CHAR_LINE_T_BT     0x2534
    fn_utf8_set_readonly BIW_CHAR_BLOCK         0x2592
    fn_utf8_set_readonly BIW_CHAR_TRIANGLE_UP   0x25B2
    fn_utf8_set_readonly BIW_CHAR_TRIANGLE_RT   0x25BA
    fn_utf8_set_readonly BIW_CHAR_TRIANGLE_DN   0x25BC
    fn_utf8_set_readonly BIW_CHAR_TRIANGLE_LT   0x25C4
    fn_utf8_set_readonly BIW_CHAR_DIAMOND       0x25C6
}

function fn_utf8_set()
{
    local _result_ref=$1
    local _utf8_encoded="$2"
    
    printf -v $_result_ref '%b' "$_utf8_encoded"
}

function fn_utf8_print()
{
    local _utf8_encoded=$1
    local _utf8_raw

    printf -v _utf8_raw '%b' $_utf8_encoded
    fn_sgr_seq_write "$_utf8_raw"
}

function fn_utf8_cp_print()
{
    local -i _ordinal=$1
    local _utf8_raw

    fn_utf8_get_encoded _utf8_raw $_ordinal
    fn_sgr_seq_write "$_utf8_raw"
}

function fn_utf8_print_h_line()
{
    local -i _line_width=$1
    local _sgr_line
    local _pad_char=$BIW_CHAR_LINE_HZ

    printf -v _sgr_line '%*s' $cred_canvas_width
    printf -v _sgr_line '%b' "${_sgr_line// /${_pad_char}}"
    fn_sgr_seq_write $_sgr_line
}

function fn_utf8_set_readonly()
{
    local _result_ref=$1
    local -i _ordinal=$2

    local _result_val
    fn_utf8_get_encoded '_result_val' $_ordinal

    # set the result to a new readonly variable
    readonly $_result_ref=$_result_val
}

function fn_utf8_get_encoded()
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
        fn_utl_die "Could not convert UTF-8 ordinal: <$_ordinal>"
    fi
}

fn_utf8_init
