##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-settings.sh
# Description:  Configuration settings load/save.
##

# file for persisting theme
declare -r BIW_SETTINGS_FILE=$HOME/.biw_settings

# file to store selection result
readonly BIW_RESULT_FILE=$HOME/.biw_selection

# file used to pass back updates to the key binding
readonly BIW_BIND_UPDATE_FILE=$HOME/.biw_bind_update

# array with settings parameters
declare -A biw_settings_params=()

declare -r BIW_BIND_PARAM_NAME='bind-key-code'

# default key set to CSI_KEY_DOWN
declare -r BIW_DEFAULT_BIND_KEY='[6'

function fn_settings_get_param()
{
    local _param_name=$1
    local _param_ref=$2
    local _param_default=${3:-}

    if [ ${#biw_settings_params[@]} == 0 ] && ! fn_settings_load
    then
        printf -v $_param_ref '%s' "$_param_default"
        return 1
    fi

    local _param_val=${biw_settings_params[$_param_name]:-}
    if [ -z "$_param_val" ]
    then
        printf -v $_param_ref '%s' "$_param_default"
        return 1
    fi

    printf -v $_param_ref '%s' "$_param_val"

    return 0
}

function fn_settings_set_param()
{
    local _param_name=$1
    local _param_val=$2

    biw_settings_params[$_param_name]="$_param_val"
    fn_settings_save
}

function fn_settings_load()
{
    biw_settings_params=()

    if [ ! -r $BIW_SETTINGS_FILE ]
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

        biw_settings_params[$_key]="$_value"

    done < $BIW_SETTINGS_FILE
    return 0
}

function fn_settings_save()
{
    local _key
    local _value

    local IFS=$'\n'
    
    for _key in $(echo "${!biw_settings_params[*]}" | sort)
    do
        _value="${biw_settings_params[$_key]}"
        printf '%s=%s\n' $_key "$_value"
    done > $BIW_SETTINGS_FILE
}

function fn_settings_get_hotkey()
{
    local _result_ref=$1

    fn_settings_get_param \
        $BIW_BIND_PARAM_NAME \
        $_result_ref \
        $BIW_DEFAULT_BIND_KEY
}

function fn_settings_set_hotkey()
{
    local _bind_key=$1

    fn_settings_set_param \
        $BIW_BIND_PARAM_NAME \
        $_bind_key

    echo "$_bind_key" > $BIW_BIND_UPDATE_FILE
}
