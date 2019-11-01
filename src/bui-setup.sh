##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-setup.sh
# Description:  Setup script to be added to .bashrc.
##
#set -o nounset

function fn_bui_setup_init()
{
    local BIW_MIN_BASH_VERSION='4.1.17'

    if [[ ! "$-" =~ "i" ]]
    then
        echo "ERROR: ${BASH_SOURCE[0]}: This script must be sourced and not executed." 2>&1
        return 1
    fi

    if ! fn_bui_setup_version_check "$BIW_MIN_BASH_VERSION"
    then
        return 1
    fi
    
    # load env vars
    fn_bui_setup_set_home

    if ! source ${BUI_HOME}/bui-settings.sh
    then
        return 1
    fi

    local _bind_key
    fn_settings_get_hotkey '_bind_key'

    fn_bui_setup_bind $_bind_key
}

function fn_bui_setup_version_check()
{
    local _min_version_str=$1

    local _current_str
    printf -v _current_str '%s.%s.%s' \
        "${BASH_VERSINFO[0]}" \
        "${BASH_VERSINFO[1]}" \
        "${BASH_VERSINFO[2]}"

    local -i _current_version
    fn_bui_setup_version $_current_str '_current_version'

    local -i _min_version
    fn_bui_setup_version $_min_version_str '_min_version'

    if((_current_version < _min_version))
    then
        echo "ERROR: ${BASH_SOURCE[0]}: Bash version too old: $_current_str < $_min_version_str" 2>&1
        return 1
    fi
}

function fn_bui_setup_version()
{
    local _version_str=$1
    local _result_ref=$2

    local -a _version_arr=( ${_version_str//./ } )
    local -i _version_int=0
    ((_version_int += _version_arr[0]))
    ((_version_int *= 100))
    ((_version_int += _version_arr[1]))
    ((_version_int *= 1000))
    ((_version_int += _version_arr[2]))

    printf -v $_result_ref '%d' $_version_int
}

function fn_bui_setup_set_home()
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
    
    export BUI_HOME=$_script_dir
}

function fn_bui_setup_show()
{
    # Flush cached history to file. This is part of a workaround mentioned in
    # fn_bui_load_history
    history -a 

    # show the app
    bash ${BUI_HOME}/bui-main.sh

    fn_update_key_binding

    if [ ! -r $BUI_RESULT_FILE ]
    then
        return 1
    fi

    READLINE_LINE="${READLINE_LINE}$(cat $BUI_RESULT_FILE)"
    READLINE_POINT=${#READLINE_LINE}

    rm $BUI_RESULT_FILE

    return 0
}

declare BUI_LAST_BIND_KEY

function fn_update_key_binding()
{
    if [ ! -r $BUI_BIND_UPDATE_FILE ]
    then
        return 0
    fi

    local _bind_update=$(cat $BUI_BIND_UPDATE_FILE)
    rm -f $BUI_BIND_UPDATE_FILE

    if [ "$_bind_update" == "$BUI_LAST_BIND_KEY" ]
    then
        # nothing to do
        return 0
    fi

    echo "BUI hotkey update: ESC${BUI_LAST_BIND_KEY} => ESC${_bind_update}"

    bind -r "\e$BUI_LAST_BIND_KEY"
    fn_bui_setup_bind "$_bind_update"
}

function fn_bui_setup_bind()
{
    local -r _bind_key=$1

    # We use a random character for an intermediate bind because 
    # bash has issues with multi-byte ESC sequences.
    local -r bind_int_char=$'\201'
    local -r bind_esc_char="\e${_bind_key}"
    
    bind -x "\"${bind_int_char}\":fn_bui_setup_show"
    bind "\"${bind_esc_char}\":\"${bind_int_char}\""

    BUI_LAST_BIND_KEY="$_bind_key"
}

# entry point
if ! fn_bui_setup_init
then
    return 1
fi
