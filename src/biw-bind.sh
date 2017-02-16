##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

function fn_biw_init()
{   
    fn_check_interactive
    fn_biw_set_env

    # some keys you can bind
    local -r key_f1='OP'
    local -r key_f2='OQ'
    local -r key_f10='[21~'
    local -r key_f11='[23~'
    local -r key_f12='[24~'
    local -r key_up='[A'
    local -r key_down='[B'
    local -r key_left='[D'
    local -r key_right='[C'

    # set bind key here
    fn_choose_bind $key_down
}

function fn_choose_bind()
{
    local -r _bind_key=$1

    # We use 2 binds here because of an issue bash has with 
    # multi-char escape sequences.
    local -r bind_int_char=$'"\201"'
    local -r bind_esc_char="\"\e${_bind_key}\""

    bind -x ${bind_int_char}:fn_choose_show
    bind ${bind_esc_char}:${bind_int_char}
}

function fn_choose_show()
{
    if ! ${BIW_HOME}/biw-main.sh
    then
        return 1
    fi

    READLINE_LINE=$(cat $BIW_CH_RES_FILE)
    READLINE_POINT=${#READLINE_LINE}

    rm $BIW_CH_RES_FILE
}

function fn_check_interactive()
{
    if [[ ! "$-" =~ "i" ]]
    then
        echo "ERROR: This script must be sourced and not executed."
        exit 1
    fi
}

function fn_biw_set_env()
{
    # file where history result will be saved
    export BIW_CH_RES_FILE=$HOME/.biw_selection

    # save the home dir
    local _script_name=${BASH_SOURCE[0]}
    local _script_dir=${_script_name%/*}

    if [ "$_script_name" == "$_script_dir" ]
    then
        # _script name has no path
        _script_dir="."
    fi

    # convert to absolute path
    _script_dir=$(cd $_script_dir; pwd -P)
    
    export BIW_HOME=$_script_dir
}

# Activate bindings
fn_biw_init
