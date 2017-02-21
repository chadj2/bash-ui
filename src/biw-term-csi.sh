##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# CSI op codes used with fn_csi_op
readonly csi_op_scroll_up='S'
readonly csi_op_scroll_down='T'
readonly csi_op_row_insert='L'
readonly csi_op_row_delete='M'
readonly csi_op_row_up='A'
readonly csi_op_row_down='B'
readonly csi_op_row_erase='K'
readonly csi_op_col_pos='G'
readonly csi_op_cursor_hide='?25l'
readonly csi_op_cursor_show='?25h'
readonly csi_op_cursor_save='?1048h'
readonly csi_op_cursor_restore='?1048l'

# key codes returned by fn_csi_read_key
readonly csi_key_up='[A'
readonly csi_key_down='[B'
readonly csi_key_left='[D'
readonly csi_key_right='[C'
readonly csi_key_eol='eol'

# Codes to print from the DEC graphics charset
readonly csi_char_line_vert=$'\e(0\x78\e(B'
readonly csi_char_line_top=$'\e(0\x77\e(B'
readonly csi_char_line_bottom=$'\e(0\x76\e(B'
readonly csi_char_block=$'\e(0\x61\e(B'
readonly csi_char_bullet=$'\e(0\x7e\e(B'
readonly csi_char_diamond=$'\e(0\x60\e(B'

# Executre a CSI termial command
function fn_csi_op()
{
    local _op=$1

    # default to empty if not set
    local _param=${2:-''}

    # send CSI command to terminal
    echo -en "\e[${_param}${_op}"
}

# read a key that could include an ESC code
function fn_csi_read_key()
{
    local -r _result_var=$1
    local -r _read_delay=0.1

    # read character
    local _read_result
    read -s -N1 _read_result

    # default to empty of not set
    _read_result=${_read_result:-${csi_key_eol}}

    # check for escape char
    if [[ $_read_result == $'\e' ]]
    then
        # read the rest of the escape code
        read -t$_read_delay -s -N2 _read_result
    fi

    # set result
    eval $_result_var=$_read_result
}

# Wait a short amount of time measured in milliseconds. 
function fn_csi_milli_wait()
{
    # we use read insted of sleep because it is a 
    # bash builtin and sleep would be too slow
    local -r _animate_delay=0.015
    read -s -n1 -t$_animate_delay
}
