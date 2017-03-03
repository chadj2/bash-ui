##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-decg.sh
# Description:  Send terminal graphic characters using the DEC special 
#				graphics charachter set.
##

# Codes to print from the DEC graphics charset
declare -r BIW_CHAR_DIAMOND=$'\x60'
declare -r BIW_CHAR_BLOCK=$'\x61'
declare -r BIW_CHAR_LINE_BT_RT=$'\x6A'
declare -r BIW_CHAR_LINE_BT_LT=$'\x6D'
declare -r BIW_CHAR_LINE_HZ=$'\x71'
declare -r BIW_CHAR_LINE_T_BT=$'\x76'
declare -r BIW_CHAR_LINE_T_TOP=$'\x77'
declare -r BIW_CHAR_LINE_VT=$'\x78'
declare -r BIW_CHAR_BULLET=$'\x7E'

declare -r SGI_GRAPHIC_START=$'\e(0'
declare -r SGI_GRAPHIC_END=$'\e(B'


function fn_utf8_set()
{
    local _result_ref=$1
    local _octal_num=$2

    printf -v $_result_ref '%b' \
        $SGI_GRAPHIC_START \
        $_octal_num \
        $SGI_GRAPHIC_END
}

function fn_utf8_print()
{
    local _octal_num=$1
    local _out

    fn_utf8_set _out $_octal_num
    fn_sgr_print "$_out"
}

function fn_utf8_print_h_line()
{
    local -i _line_width=$1

    local _sgr_line
    local _pad_char=$BIW_CHAR_LINE_HZ
    printf -v _sgr_line '%*s' $cred_canvas_width
    printf -v _sgr_line '%b' "${_sgr_line// /${_pad_char}}"

    fn_sgr_print $SGI_GRAPHIC_START
    fn_sgr_print $_sgr_line
    fn_sgr_print $SGI_GRAPHIC_END
}
