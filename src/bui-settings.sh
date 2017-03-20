##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-settings.sh
# Description:  Configuration settings load/save.
##

# file for persisting theme
declare -r BUI_SETTINGS_FILE=$HOME/.bui_settings

# file to store selection result
readonly BUI_RESULT_FILE=$HOME/.bui_selection

# file used to pass back updates to the key binding
readonly BUI_BIND_UPDATE_FILE=$HOME/.bui_bind_update

# array with settings parameters
declare -A bui_settings_params=()

declare -r BUI_BIND_PARAM_NAME='bind-key-code'

# default key set to CSI_KEY_DOWN
declare -r BUI_DEFAULT_BIND_KEY='[B'

function fn_settings_get_param()
{
    local _param_name=$1
    local _param_ref=$2
    local _param_default=${3:-}

    if [ ${#bui_settings_params[@]} == 0 ]
    then
        fn_settings_load
    fi

    local _param_val=${bui_settings_params[$_param_name]:-}
    if [ -n "$_param_val" ]
    then
        printf -v $_param_ref '%s' "$_param_val"
        return 0
    fi

    if [ -n "$_param_default" ]
    then
        printf -v $_param_ref '%s' "$_param_default"
        return 1
    fi

    # no param and no default?
    return 1
}

function fn_settings_set_param()
{
    local _param_name=$1
    local _param_val=$2

    bui_settings_params[$_param_name]="$_param_val"
    fn_settings_save
}

function fn_settings_load()
{
    bui_settings_params=()

    if [ ! -r $BUI_SETTINGS_FILE ]
    then
        # nothing to do
        return 1
    fi

    local _line
    while read -r _line
    do
        _key=${_line%%=*}
        _value="${_line##*=}"

        if [ -z "$_key" ] || [ -z "$_value" ]
        then
            # skip this because we did not get a complete 
            # key/val pair
            continue
        fi

        bui_settings_params[$_key]="$_value"

    done < $BUI_SETTINGS_FILE
    return 0
}

function fn_settings_save()
{
    local _key
    local _value

    local IFS=$'\n'
    
    for _key in $(echo "${!bui_settings_params[*]}" | sort)
    do
        _value="${bui_settings_params[$_key]}"
        printf '%s=%s\n' $_key "$_value"
    done > $BUI_SETTINGS_FILE
}

function fn_settings_get_hotkey()
{
    local _result_ref=$1

    fn_settings_get_param \
        $BUI_BIND_PARAM_NAME \
        $_result_ref \
        $BUI_DEFAULT_BIND_KEY
}

function fn_settings_set_hotkey()
{
    local _bind_key=$1

    fn_settings_set_param \
        $BUI_BIND_PARAM_NAME \
        $_bind_key

    echo "$_bind_key" > $BUI_BIND_UPDATE_FILE
}
