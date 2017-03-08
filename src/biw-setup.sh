##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-setup.sh
# Description:  Setup script to be added to .bashrc.
##
set -o nounset

function fn_biw_setup_init()
{
    if [[ ! "$-" =~ "i" ]]
    then
        echo "ERROR: This script must be sourced and not executed." 2>&1
    fi

    # load env vars
    fn_biw_setup_get_env

    if ! source ${BIW_HOME}/biw-settings.sh
    then
        return 1
    fi

    local _bind_key
    fn_settings_get_hotkey '_bind_key'

    fn_biw_setup_bind $_bind_key
}

function fn_biw_setup_show()
{
    # show the app
    ${BIW_HOME}/biw-main.sh

    fn_update_key_binding

    if [ ! -r $BIW_RESULT_FILE ]
    then
        return 1
    fi

    READLINE_LINE="${READLINE_LINE}$(cat $BIW_RESULT_FILE)"
    READLINE_POINT=${#READLINE_LINE}

    rm $BIW_RESULT_FILE

    return 0
}

declare biw_last_bind_key

function fn_update_key_binding()
{
    if [ ! -r $BIW_BIND_UPDATE_FILE ]
    then
        return 0
    fi

    local _bind_update=$(cat $BIW_BIND_UPDATE_FILE)
    rm -f $BIW_BIND_UPDATE_FILE

    if [ "$_bind_update" == "$biw_last_bind_key" ]
    then
        # nothing to do
        return 0
    fi

    echo "BIW hotkey update: ESC${biw_last_bind_key} => ESC${_bind_update}"

    bind -r "\e$biw_last_bind_key"
    fn_biw_setup_bind "$_bind_update"
}

function fn_biw_setup_bind()
{
    local -r _bind_key=$1

    # We use a random character for an intermediate bind because 
    # bash has issues with multi-byte ESC sequences.
    local -r bind_int_char=$'\201'
    local -r bind_esc_char="\e${_bind_key}"
    
    bind -x "\"${bind_int_char}\":fn_biw_setup_show"
    bind "\"${bind_esc_char}\":\"${bind_int_char}\""

    biw_last_bind_key="$_bind_key"
}

function fn_biw_setup_get_env()
{
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

# entry point
fn_biw_setup_init
