##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-theme-mgr.sh
# Description:  Manage SGR attributes based on display themes.
##

# Theme description
declare -r THEME_CFG_DESC=1

# Background color
declare -r THEME_CFG_BG_COLOR=10

# Panel (unselected)
declare -r THEME_CFG_DEF_COLOR=20
declare -r THEME_CFG_DEF_ATTR=21

# Panel (Selected)
declare -r THEME_CFG_SEL_COLOR=30
declare -r THEME_CFG_SEL_ATTR=31

# Slider (unselected)
declare -r THEME_CFG_SLI_COLOR=40
declare -r THEME_CFG_SLI_ATTR=41

# Slider (selected)
declare -r THEME_CFG_SLA_COLOR=50
declare -r THEME_CFG_SLA_ATTR=51

# Base for HSV colors
declare -ri THEME_CFG_HSV_BASE=100
declare -ri THEME_ATTR_INVERT=$((THEME_CFG_HSV_BASE + 1))

source ${BUI_HOME}/bui-theme-config.sh

# Options for setting theme attributes
declare -ri THEME_SET_DEF_INACTIVE=20
declare -ri THEME_SET_DEF_ACTIVE=30
declare -ri THEME_SET_SLI_INACTIVE=40
declare -ri THEME_SET_SLI_ACTIVE=50

# currently active theme
declare -i theme_active_idx=-1

# updated with the selected theme settings
declare -a theme_active_data

# Indexes computed from THEME_LIST
declare -a theme_desc_lookup
declare -A theme_id_lookup

# settings param name
declare -r THEME_PARAM_NAME='theme-name'

function fn_theme_init()
{
    local _theme_desc
    local _theme_name
    local _array_ref
    local -i _theme_idx

    # populate lookups
    theme_id_lookup=()
    theme_desc_lookup=()

    local -i _theme_list_size=${#THEME_LIST[@]}

    for((_theme_idx=0; _theme_idx < _theme_list_size; _theme_idx++))
    do
        _theme_name="${THEME_LIST[_theme_idx]}"
        _array_ref="$_theme_name[$THEME_CFG_DESC]"
        _theme_desc="${!_array_ref}"

        theme_desc_lookup+=( "$_theme_desc" )
        theme_id_lookup+=( ["$_theme_name"]=$_theme_idx )
    done

    fn_theme_load
}

function fn_theme_load()
{
    local _saved_name
    fn_settings_get_param $THEME_PARAM_NAME '_saved_name' $THEME_DEFAULT_NAME
    local -i _saved_idx=${theme_id_lookup["$_saved_name"]}
    fn_theme_set_idx_active $_saved_idx
}

function fn_theme_set_idx_active()
{
    local -i _selected_idx=$1

    if((_selected_idx == theme_active_idx))
    then
        return
    fi

    local _selected_theme=${THEME_LIST[$_selected_idx]}

    # clear out existing theme
    theme_active_data=()
    local _array_ref
    local -i _color_code

    _array_ref=$_selected_theme[THEME_CFG_BG_COLOR]
    fn_theme_parse_color '_color_code' "${!_array_ref}"
    theme_active_data[THEME_CFG_BG_COLOR]=$_color_code

    fn_theme_set_color_attr $_selected_theme $THEME_CFG_DEF_COLOR
    fn_theme_set_color_attr $_selected_theme $THEME_CFG_SEL_COLOR
    fn_theme_set_color_attr $_selected_theme $THEME_CFG_SLI_COLOR
    fn_theme_set_color_attr $_selected_theme $THEME_CFG_SLA_COLOR

    theme_active_idx=$_selected_idx
}

function fn_theme_set_color_attr()
{
    local _theme_name=$1
    local -i _cfg_id=$2

    # calculate color code
    local _array_ref=$_theme_name[$_cfg_id]
    local _color_val="${!_array_ref}"
    local -i _color_code
    fn_theme_parse_color '_color_code' "$_color_val"
    theme_active_data[$_cfg_id]=$_color_code

    # copy attribute
    local -i _attr_id=$((_cfg_id + 1))
    _array_ref=$_theme_name[$_attr_id]
    local _attr_code=${!_array_ref}
    theme_active_data[$_attr_id]=$_attr_code
}

function fn_theme_parse_color()
{
    local _result_ref=$1
    local _color_params_in=$2

    local -a _color_params=( $_color_params_in )
    local -i _color_params_size=${#_color_params[@]}
    local -i _color_result

    if((_color_params_size == 1))
    then
        # this is a simple color
        _color_result=${_color_params[0]}

    elif((_color_params_size == 2))
    then
        # this is a greyscale-26 color
        if [ "${_color_params[0]}" != 'G26' ]
        then
            fn_util_die "Expected G26 params for ${_theme_name}: ${_color_params[@]}"
        fi

        local -i _light=${_color_params[1]}
        fn_sgr_grey26_get $_light
        _color_result=$?
        ((_color_result += THEME_CFG_HSV_BASE))

    elif((_color_params_size == 4))
    then
        if [ ${_color_params[0]} != 'HSV216' ]
        then
            fn_util_die "Expected HSV params for ${_theme_name}: ${_color_params[@]}"
        fi

        # this must be an HSV color
        local -i _hue=${_color_params[1]}
        local -i _sat=${_color_params[2]}
        local -i _light=${_color_params[3]}

        fn_sgr_hsv216_get $_hue $_sat $_light
        _color_result=$?
        ((_color_result += THEME_CFG_HSV_BASE))
    else
        fn_util_die "Bad color for ${_theme_name}: ${_color_params[@]}"
    fi

    printf -v $_result_ref '%d' $_color_result
}

function fn_theme_set_attr_panel()
{
    local -i _is_active=$1

    if ((_is_active == 0))
    then
        fn_theme_set_attr $THEME_SET_DEF_INACTIVE
    else
        fn_theme_set_attr $THEME_SET_DEF_ACTIVE
    fi
}

function fn_theme_set_attr_slider()
{
    local -i _is_active=$1

    if ((_is_active == 0))
    then
        fn_theme_set_attr $THEME_SET_SLI_INACTIVE
    else
        fn_theme_set_attr $THEME_SET_SLI_ACTIVE
    fi
}

function fn_theme_set_attr()
{
    local -i _set_name=$1

    fn_sgr_op $SGR_ATTR_DEFAULT

    local -i _bg_color=${theme_active_data[THEME_CFG_BG_COLOR]}
    local -i _fg_color=${theme_active_data[_set_name]}
    local -i _attr=${theme_active_data[_set_name + 1]}
    
    if((_attr == THEME_ATTR_INVERT))
    then
        local -i _temp=$_bg_color
        _bg_color=$_fg_color
        _fg_color=$_temp
    elif((_attr == SGR_ATTR_INVERT))
    then
        fn_sgr_op $_attr
    fi

    fn_theme_set_color $SGR_ATTR_BG $_bg_color
    fn_theme_set_color $SGR_ATTR_FG $_fg_color
}

function fn_theme_set_color()
{
    local -i _mode=$1
    local -i _theme_color=$2

    if((_theme_color >= THEME_CFG_HSV_BASE))
    then
        fn_sgr_xterm240_set $_mode $((_theme_color - THEME_CFG_HSV_BASE))
    else
        fn_sgr_ansi16_set $_mode $_theme_color
    fi
}
