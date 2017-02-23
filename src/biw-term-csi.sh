##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# CSI op codes used with fn_csi_op
readonly CSI_OP_SCROLL_UP='S'
readonly CSI_OP_SCROLL_DOWN='T'
readonly CSI_OP_ROW_INSERT='L'
readonly CSI_OP_ROW_DELETE='M'
readonly CSI_OP_ROW_UP='A'
readonly CSI_OP_ROW_DOWN='B'
readonly CSI_OP_ROW_ERASE='K'
readonly CSI_OP_COL_POS='G'
readonly CSI_OP_CURSOR_HIDE='?25l'
readonly CSI_OP_CURSOR_SHOW='?25h'
readonly CSI_OP_CURSOR_SAVE='?1048h'
readonly CSI_OP_CURSOR_RESTORE='?1048l'

# key codes returned by fn_csi_read_key
readonly CSI_KEY_UP='[A'
readonly CSI_KEY_DOWN='[B'
readonly CSI_KEY_LEFT='[D'
readonly CSI_KEY_RIGHT='[C'
readonly CSI_KEY_EOL='eol'

# Codes to print from the DEC graphics charset
readonly CSI_CHAR_LINE_VERT=$'\e(0\x78\e(B'
readonly CSI_CHAR_LINE_TOP=$'\e(0\x77\e(B'
readonly CSI_CHAR_LINE_BOTTOM=$'\e(0\x76\e(B'
readonly CSI_CHAR_BLOCK=$'\e(0\x61\e(B'
readonly CSI_CHAR_BULLET=$'\e(0\x7e\e(B'
readonly CSI_CHAR_DIAMOND=$'\e(0\x60\e(B'

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
    local -r _read_delay=0.05

    # read character
    local _read_result
    read -s -N1 _read_result

    # default to empty of not set
    _read_result=${_read_result:-${CSI_KEY_EOL}}

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
