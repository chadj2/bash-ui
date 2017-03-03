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

# create pseudo colors for attributes that we will remap later
# [0..9]: SGR Colors
# [10..20]: Attributes
# [SGR_ATTR_BRIGHT..+10]: Bright SGR Colors
declare -ri TATTR_SGR_BASE=10
declare -ri TATTR_SGR_BOLD=$((TATTR_SGR_BASE + SGR_ATTR_BOLD))
declare -ri TATTR_SGR_UNDERLINE=$((TATTR_SGR_BASE + SGR_ATTR_UNDERLINE))
declare -ri TATTR_SGR_INVERT=$((TATTR_SGR_BASE + SGR_ATTR_INVERT))

# Theme option names
declare -ri TATTR_NAME=0
declare -ri TATTR_TEXT=1
declare -ri TATTR_BG_INACTIVE=2
declare -ri TATTR_BG_ACTIVE=3
declare -ri TATTR_SL_INACTIVE=4
declare -ri TATTR_SL_ACTIVE=5

declare -ra THEME_TYPE_BRIGHT=(
    [$TATTR_NAME]="Bright"
    [$TATTR_TEXT]=$SGR_COL_BLACK
    [$TATTR_BG_INACTIVE]=$((SGR_COL_BLUE + SGR_ATTR_BRIGHT))
    [$TATTR_BG_ACTIVE]=$((SGR_COL_RED + SGR_ATTR_BRIGHT))
    [$TATTR_SL_INACTIVE]=$SGR_COL_CYAN
    [$TATTR_SL_ACTIVE]=$SGR_COL_YELLOW
)

declare -ra THEME_TYPE_DARK=(
    [$TATTR_NAME]="Dark"
    [$TATTR_TEXT]=$SGR_COL_WHITE
    [$TATTR_BG_INACTIVE]=$SGR_COL_BLACK
    [$TATTR_BG_ACTIVE]=$SGR_COL_RED
    [$TATTR_SL_INACTIVE]=$SGR_COL_BLACK
    [$TATTR_SL_ACTIVE]=$TATTR_SGR_INVERT
)

declare -ra THEME_TYPE_MONO=(
    [$TATTR_NAME]="Monochrome"
    [$TATTR_TEXT]=$SGR_COL_DEFAULT
    [$TATTR_BG_INACTIVE]=$SGR_COL_DEFAULT
    [$TATTR_BG_ACTIVE]=$TATTR_SGR_INVERT
    [$TATTR_SL_INACTIVE]=$TATTR_SGR_INVERT
    [$TATTR_SL_ACTIVE]=$SGR_COL_DEFAULT
)

declare -ra THEME_TYPE_MATRIX=(
    [$TATTR_NAME]="Matrix"
    [$TATTR_TEXT]=$((SGR_COL_GREEN + SGR_ATTR_BRIGHT))
    [$TATTR_BG_INACTIVE]=$SGR_COL_BLACK
    [$TATTR_BG_ACTIVE]=$TATTR_SGR_INVERT
    [$TATTR_SL_INACTIVE]=$SGR_COL_BLACK
    [$TATTR_SL_ACTIVE]=$TATTR_SGR_INVERT
)

declare -ra THEME_TYPE_IMPACT=(
    [$TATTR_NAME]="Impact"
    [$TATTR_TEXT]=$((SGR_COL_YELLOW + SGR_ATTR_BRIGHT))
    [$TATTR_BG_INACTIVE]=$((SGR_COL_BLACK + SGR_ATTR_BRIGHT))
    [$TATTR_BG_ACTIVE]=$SGR_COL_BLUE
    [$TATTR_SL_INACTIVE]=$SGR_COL_RED
    [$TATTR_SL_ACTIVE]=$TATTR_SGR_INVERT
)

# make a list of all the themes
declare -ra THEME_LIST=(
    THEME_TYPE_BRIGHT
    THEME_TYPE_DARK
    THEME_TYPE_MONO
    THEME_TYPE_MATRIX
    THEME_TYPE_IMPACT
)

# file for persisting theme
declare -r BIW_SETTINGS_FILE=$HOME/.biw_settings

# initialize the default theme
declare -a theme_active
declare -i theme_active_idx=-1

# indicates the loaded or last saved theme
declare -i theme_saved_idx=-1

# reference of theme names
declare -a theme_name_list

fn_theme_init()
{
    fn_theme_set_name_list

    if [ ! -r $BIW_SETTINGS_FILE ]
    then
        # nothing to load
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
    local _theme_ref="${_selected_theme}[*]"
    theme_active=( ${!_theme_ref} )

    theme_active_idx=$_selected_idx
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

function fn_theme_set_name_list()
{
    local _theme_idx
    local _theme_name
    local _theme_type

    theme_name_list=()

    for _theme_type in "${THEME_LIST[@]}"
    do
        _theme_idx=${_theme_type}[$TATTR_NAME]
        _theme_name=${!_theme_idx}
        theme_name_list+=( $_theme_name )
    done
}

function fn_theme_set_attr_default()
{
    local -i _is_active=$1
    if ((_is_active == 0))
    then
        #set -x
        fn_theme_set_attr $TATTR_BG_INACTIVE
        #exit
    else
        fn_theme_set_attr $TATTR_BG_ACTIVE
    fi
}

function fn_theme_set_attr_slider()
{
    local -i _is_active=$1
    if ((_is_active == 0))
    then
        fn_theme_set_attr $TATTR_SL_INACTIVE
    else
        fn_theme_set_attr $TATTR_SL_ACTIVE
    fi
}

function fn_theme_set_attr()
{
    local -i _bg_attr_name=$1

    local -i _bg_sgr_nested=$((!sgr_buffer_active))

    if((_bg_sgr_nested))
    then
        fn_sgr_seq_start
    fi

    fn_sgr_op $SGR_ATTR_DEFAULT

    fn_theme_set_color $SGR_ATTR_BG $_bg_attr_name
    local -i _sgr_attr_bg=$?

    if((_sgr_attr_bg))
    then
        # this is a attribute and not a color so set the background
        fn_theme_set_color $SGR_ATTR_BG $TATTR_BG_INACTIVE
        fn_sgr_op $_sgr_attr_bg
    fi

    fn_theme_set_color $SGR_ATTR_FG $TATTR_TEXT
    local -i _sgr_attr_fg=$?

    if((_sgr_attr_fg))
    then
        if((_sgr_attr_bg))
        then
            echo "ERROR: _sgr_attr_fg and _sgr_attr_bg can't both be set."
        fi
        fn_sgr_op $_sgr_attr_fg
    fi

    if((_bg_sgr_nested))
    then
        fn_sgr_seq_flush
    fi
}

function fn_theme_set_color()
{
    local -i _sgr_mode=$1
    local -i _theme_attr_name=$2

    local -i _theme_attr_val=${theme_active[$_theme_attr_name]}

    if ((_theme_attr_val >= TATTR_SGR_BASE && _theme_attr_val < SGR_ATTR_BRIGHT))
    then
        # This is an attribute and not a color so return the attribute
        local -i _sgr_attr=$((_theme_attr_val - TATTR_SGR_BASE))
        return $_sgr_attr
    fi

    fn_sgr_color16_set $_sgr_mode $_theme_attr_val

    return 0
}

# always init theme
fn_theme_init
