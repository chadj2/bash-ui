##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-theme.sh
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

# There are 3 color spaces that can be used:
#   color16) 8 dark and 8 light colors (SGR_COL*)
#   HSL216) Hue/Saturation/Light (36x6x6) color space.
#   grey26) 26 shades of Grey. Much more than is offered by HSL.

declare -ra THEME_TYPE_BRIGHT=(
    [$THEME_CFG_DESC]="Bright"
    [$THEME_CFG_BG_COLOR]=$SGR_COL_BLACK
    [$THEME_CFG_DEF_COLOR]=$((SGR_COL_BLUE + SGR_ATTR_BRIGHT))
    [$THEME_CFG_SEL_COLOR]=$((SGR_COL_RED + SGR_ATTR_BRIGHT))
    [$THEME_CFG_SLI_COLOR]=$((SGR_COL_CYAN + SGR_ATTR_BRIGHT))
    [$THEME_CFG_SLA_COLOR]=$((SGR_COL_CYAN + SGR_ATTR_BRIGHT))
    [$THEME_CFG_DEF_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLA_ATTR]=0
)

declare -ra THEME_TYPE_BRIGHT_216=(
    [$THEME_CFG_DESC]='Bright (HSL 216)'
    [$THEME_CFG_BG_COLOR]=$SGR_COL_BLACK
    [$THEME_CFG_DEF_COLOR]="HSL216 $((HSL216_HUE_BLUE - 4)) 3 4"
    [$THEME_CFG_SEL_COLOR]="HSL216 $((HSL216_HUE_BLUE - 4)) 2 5"
    [$THEME_CFG_SLI_COLOR]="HSL216 $((HSL216_HUE_RED + 3)) 1 3"
    [$THEME_CFG_SLA_COLOR]="HSL216 $((HSL216_HUE_RED + 3)) 1 5"
    [$THEME_CFG_DEF_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLA_ATTR]=$SGR_ATTR_INVERT
)

declare -ra THEME_TYPE_DARK=(
    [$THEME_CFG_DESC]='Dark'
    [$THEME_CFG_BG_COLOR]=$SGR_COL_BLACK
    [$THEME_CFG_DEF_COLOR]=$SGR_COL_WHITE
    [$THEME_CFG_SEL_COLOR]=$SGR_COL_RED
    [$THEME_CFG_SLI_COLOR]=$SGR_COL_WHITE
    [$THEME_CFG_SLA_COLOR]=$SGR_COL_WHITE
    [$THEME_CFG_DEF_ATTR]=0
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLA_ATTR]=0
)

declare -ra THEME_TYPE_MONO=(
    [$THEME_CFG_DESC]='Monochrome'
    [$THEME_CFG_BG_COLOR]=$SGR_COL_DEFAULT
    [$THEME_CFG_DEF_COLOR]=$SGR_COL_DEFAULT
    [$THEME_CFG_SEL_COLOR]=$SGR_COL_DEFAULT
    [$THEME_CFG_SLI_COLOR]=$SGR_COL_DEFAULT
    [$THEME_CFG_SLA_COLOR]=$SGR_COL_DEFAULT
    [$THEME_CFG_DEF_ATTR]=0
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=0
    [$THEME_CFG_SLA_ATTR]=$SGR_ATTR_INVERT
)

declare -ra THEME_TYPE_MATRIX=(
    [$THEME_CFG_DESC]='Matrix (HSL 216)'
    [$THEME_CFG_BG_COLOR]="G26 2"
    [$THEME_CFG_DEF_COLOR]="HSL216 $((HSL216_HUE_GREEN)) 2 5"
    [$THEME_CFG_SEL_COLOR]="HSL216 $((HSL216_HUE_GREEN)) 4 4"
    [$THEME_CFG_SLI_COLOR]="HSL216 $((HSL216_HUE_GREEN)) 2 5"
    [$THEME_CFG_SLA_COLOR]="HSL216 $((HSL216_HUE_GREEN)) 4 4"
    [$THEME_CFG_DEF_ATTR]=0
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=0
    [$THEME_CFG_SLA_ATTR]=$SGR_ATTR_INVERT
)

declare -ra THEME_TYPE_IMPACT=(
    [$THEME_CFG_DESC]='Impact (HSL 216)'
    [$THEME_CFG_BG_COLOR]="G26 2"
    [$THEME_CFG_DEF_COLOR]="HSL216 $((HSL216_HUE_YELLOW)) 3 5"
    [$THEME_CFG_SEL_COLOR]="HSL216 $((HSL216_HUE_BLUE - 3)) 3 5"
    [$THEME_CFG_SLI_COLOR]="HSL216 $((HSL216_HUE_RED + 3)) 3 3"
    [$THEME_CFG_SLA_COLOR]="HSL216 $((HSL216_HUE_RED + 3)) 1 5"
    [$THEME_CFG_DEF_ATTR]=0
    [$THEME_CFG_SEL_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLI_ATTR]=$SGR_ATTR_INVERT
    [$THEME_CFG_SLA_ATTR]=$SGR_ATTR_INVERT
)

# make a list of all the themes
declare -ra THEME_LIST=(
    THEME_TYPE_BRIGHT
    THEME_TYPE_BRIGHT_216
    THEME_TYPE_DARK
    THEME_TYPE_MONO
    THEME_TYPE_MATRIX
    THEME_TYPE_IMPACT
)

# Options for setting theme attributes
declare -ri THEME_SET_DEF_INACTIVE=20
declare -ri THEME_SET_DEF_ACTIVE=30
declare -ri THEME_SET_SLI_INACTIVE=40
declare -ri THEME_SET_SLI_ACTIVE=50

# Base for HSL colors
declare -ri THEME_CFG_HSL_BASE=100

# file for persisting theme
declare -r BIW_SETTINGS_FILE=$HOME/.biw_settings

# initialize the default theme
declare -i theme_active_idx=-1

# updated with the selected theme settings
declare -a theme_active_data

# indicates the loaded or last saved theme
declare -i theme_saved_idx=-1

# reference of theme names
declare -a theme_name_list

fn_theme_init()
{
    fn_theme_set_desc_list

    if [ ! -r $BIW_SETTINGS_FILE ]
    then
        # nothing to load so set default
        fn_theme_set_idx_active -1
        return
    fi

    local _saved_name=$(cat $BIW_SETTINGS_FILE)

    fn_theme_idx_from_name $_saved_name
    theme_saved_idx=$?
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
    local _color_params=$2

    local -a _color_params=( $_color_params )
    local -i _color_params_size=${#_color_params[@]}
    local -i _color_result

    if((_color_params_size == 1))
    then
        # this is a simple color
        _color_result=${_color_params[0]}

    elif((_color_params_size == 2))
    then
        # this is a greyscale-26 color
        if [ "${_color_params[0]}" != "G26" ]
        then
            echo "ERROR: Expected G26 params for ${_theme_name}: ${_color_params[@]}"
            exit 1
        fi

        local -i _light=${_color_params[1]}
        fn_sgr_grey26_get $_light
        _color_result=$?
        ((_color_result += THEME_CFG_HSL_BASE))

    elif((_color_params_size == 4))
    then
        if [ ${_color_params[0]} != "HSL216" ]
        then
            echo "ERROR: Expected HSL params for ${_theme_name}: ${_color_params[@]}"
            exit 1
        fi

        # this must be an HSL color
        local -i _hue=${_color_params[1]}
        local -i _sat=${_color_params[2]}
        local -i _light=${_color_params[3]}

        fn_hsl216_get $_hue $_sat $_light
        _color_result=$?
        ((_color_result += THEME_CFG_HSL_BASE))
    else
        echo "ERROR: Bad color for ${_theme_name}: ${_color_params[@]}"
        exit 1
    fi

    printf -v $_result_ref '%d' $_color_result
}

fn_theme_save()
{
    theme_saved_idx=$theme_active_idx
    local _saved_theme=${THEME_LIST[$theme_saved_idx]}
    echo ${_saved_theme} > $BIW_SETTINGS_FILE
}

fn_theme_idx_from_name()
{
    local -r _theme_name=$1

    local -i _theme_idx
    for _theme_idx in ${!THEME_LIST[@]}
    do
        if [ ${THEME_LIST[$_theme_idx]} == $_theme_name ]
        then
            return $_theme_idx
        fi
    done

    echo "ERROR Theme not identified: $_theme_name"
    exit 1
}

function fn_theme_set_desc_list()
{
    local _theme_name
    local _theme_type

    theme_name_list=()

    for _theme_type in "${THEME_LIST[@]}"
    do
        _theme_ref="$_theme_type[$THEME_CFG_DESC]"
        _theme_name="${!_theme_ref}"
        theme_name_list+=( "$_theme_name" )
    done
}

function fn_theme_set_attr_default()
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

    local -i _bg_color=${theme_active_data[THEME_CFG_BG_COLOR]}
    local -i _fg_color=${theme_active_data[_set_name]}
    local -i _attr=${theme_active_data[_set_name + 1]}

    # handle nested sgr transaction
    local -i _bg_sgr_nested=$((!sgr_buffer_active))
    if((_bg_sgr_nested))
    then
        fn_sgr_seq_start
    fi

    fn_sgr_op $SGR_ATTR_DEFAULT
    fn_theme_set_color $SGR_ATTR_BG $_bg_color
    fn_theme_set_color $SGR_ATTR_FG $_fg_color

    if((_attr > 0))
    then
        fn_sgr_op $_attr
    fi

    # handle nested sgr transaction
    if((_bg_sgr_nested))
    then
        fn_sgr_seq_flush
    fi
}

function fn_theme_set_color()
{
    local -i _mode=$1
    local -i _theme_color=$2

    if((_theme_color >= THEME_CFG_HSL_BASE))
    then
        fn_sgr_color216_set $_mode $((_theme_color - THEME_CFG_HSL_BASE))
    else
        fn_sgr_color16_set $_mode $_theme_color
    fi
}

# always init theme
fn_theme_init
