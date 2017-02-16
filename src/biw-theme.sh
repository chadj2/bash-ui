##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# create pseudo colors for attributes that we will remap later
readonly theme_sgr_base=10
readonly theme_sgr_attr_bold=$((theme_sgr_base + sgr_attr_bold))
readonly theme_sgr_attr_underline=$((theme_sgr_base + sgr_attr_underline))
readonly theme_sgr_attr_invert=$((theme_sgr_base + sgr_attr_invert))

# Theme option names
declare -ri theme_attr_name=0
declare -ri theme_attr_foreground=1
declare -ri theme_attr_background=2
declare -ri theme_attr_active=3
declare -ri theme_attr_sl_inactive=4
declare -ri theme_attr_sl_active=5

declare -ra theme_type_bright=(
    [$theme_attr_name]="Bright"
    [$theme_attr_foreground]=$sgr_color_black
    [$theme_attr_background]=$((sgr_color_blue + sgr_prefix_bright))
    [$theme_attr_active]=$((sgr_color_red + sgr_prefix_bright))
    [$theme_attr_sl_inactive]=$((sgr_color_cyan + sgr_prefix_bright))
    [$theme_attr_sl_active]=$((sgr_color_yellow + sgr_prefix_bright))
)

declare -ra theme_type_dark=(
    [$theme_attr_name]="Dark"
    [$theme_attr_foreground]=$((sgr_color_white + sgr_prefix_bright))
    [$theme_attr_background]=$sgr_color_black
    [$theme_attr_active]=$sgr_color_red
    [$theme_attr_sl_inactive]=$sgr_color_black
    [$theme_attr_sl_active]=$theme_sgr_attr_invert
)

declare -ra theme_type_mono=(
    [$theme_attr_name]="Monochrome"
    [$theme_attr_foreground]=$sgr_color_default
    [$theme_attr_background]=$sgr_color_default
    [$theme_attr_active]=$theme_sgr_attr_invert
    [$theme_attr_sl_inactive]=$theme_sgr_attr_invert
    [$theme_attr_sl_active]=$sgr_color_default
)

declare -ra theme_type_matrix=(
    [$theme_attr_name]="Matrix"
    [$theme_attr_foreground]=$(($sgr_color_green + sgr_prefix_bright))
    [$theme_attr_background]=$sgr_color_black
    [$theme_attr_active]=$theme_sgr_attr_invert
    [$theme_attr_sl_inactive]=$sgr_color_black
    [$theme_attr_sl_active]=$theme_sgr_attr_invert
)

declare -ra theme_type_impact=(
    [$theme_attr_name]="Impact"
    [$theme_attr_foreground]=$((sgr_color_yellow + sgr_prefix_bright))
    [$theme_attr_background]=$((sgr_color_black + sgr_prefix_bright))
    [$theme_attr_active]=$((sgr_color_blue))
    [$theme_attr_sl_inactive]=$((sgr_color_red))
    [$theme_attr_sl_active]=$theme_sgr_attr_invert
)

# make a list of all the themes
declare -ra theme_list=(
    theme_type_bright
    theme_type_dark
    theme_type_mono
    theme_type_matrix
    theme_type_impact
)

# initialize the default theme
declare -a theme_active
declare -i theme_active_idx=-1

# indicates the loaded or last saved theme
declare -i theme_saved_idx=-1

# file for persisting theme
declare -r biw_settings_file=$HOME/.biw_settings

# reference of theme names
declare -a theme_name_list

fn_theme_init()
{
    fn_theme_set_name_list

    if [ ! -r $biw_settings_file ]
    then
        # nothing to load
        fn_theme_set_idx_active -1
        return
    fi

    local _saved_name=$(cat $biw_settings_file)

    fn_theme_idx_from_name $_saved_name
    theme_saved_idx=$?

    fn_theme_set_idx_active $theme_saved_idx
}

function fn_theme_set_idx_active()
{
    local -i _selected_idx=$1

    if ((_selected_idx == -1))
    then
        # use the default
        _selected_idx=0
    fi

    if((_selected_idx == theme_active_idx))
    then
        return
    fi

    local _selected_theme=${theme_list[$_selected_idx]}
    local _theme_ref="${_selected_theme}[*]"
    theme_active=( ${!_theme_ref} )

    theme_active_idx=$_selected_idx
}

fn_theme_save()
{
    theme_saved_idx=$theme_active_idx
    local _saved_theme=${theme_list[$theme_saved_idx]}
    echo ${_saved_theme} > $biw_settings_file
}

fn_theme_idx_from_name()
{
    local -r _theme_name=$1
    local -i _theme_idx

    for _theme_idx in ${!theme_list[@]}
    do
        if [ ${theme_list[$_theme_idx]} == $_theme_name ]
        then
            return $_theme_idx
        fi
    done

    return -1
}

function fn_theme_set_name_list()
{
    local _theme_idx
    local _theme_name
    local _theme_type

    theme_name_list=()

    for _theme_type in "${theme_list[@]}"
    do
        _theme_idx=${_theme_type}[$theme_attr_name]
        _theme_name=${!_theme_idx}
        theme_name_list+=( $_theme_name )
    done
}

function fn_theme_set_bg_attr()
{
    local -i _bg_attr_name=$1
    local -i _sgr_modifier=$sgr_attr_default
    
    fn_theme_get_sgr $sgr_prefix_bg $_bg_attr_name
    local -i _sgr_bg_color=$?

    if ((_sgr_bg_color < theme_sgr_base))
    then
        # this is a modifier and not a color
        _sgr_modifier=$_sgr_bg_color

        # use the default background color
        fn_theme_get_sgr $sgr_prefix_bg $theme_attr_background
        _sgr_bg_color=$?
    fi

    fn_theme_get_sgr $sgr_prefix_fg $theme_attr_foreground
    local -i _sgr_fg_color=$?

    # send triplet command
    fn_csi $csi_set_color "${_sgr_modifier};${_sgr_fg_color};${_sgr_bg_color}"
}

function fn_theme_get_sgr()
{
    local -i _sgr_type=$1
    local -i _attr_name=$2
    local -i _attr_val=${theme_active[$_attr_name]}
    local -i _sgr_code_result

    if ((_attr_val >= theme_sgr_base && _attr_val < sgr_prefix_bright))
    then
        # This is an attribute and not a color
        _sgr_code_result=$((_attr_val - theme_sgr_base))
    else
        # regular SGR color
        _sgr_code_result=$((_attr_val + _sgr_type))
    fi

    return $_sgr_code_result
}
