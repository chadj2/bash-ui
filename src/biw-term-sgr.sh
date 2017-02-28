##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-sgr.sh
# Description:  Send terminal control SGR sequences to set colors and display
#               RGB attributes.
##

# These are added to a color code to make an SGR code
readonly SGR_ATTR_DEFAULT=0
readonly SGR_ATTR_BOLD=1
readonly SGR_ATTR_UNDERLINE=4
readonly SGR_ATTR_INVERT=7
readonly SGR_ATTR_FG=30
readonly SGR_ATTR_BG=40
readonly SGR_ATTR_BRIGHT=60

# color codes must be added to SGR_ATTR_FG or SGR_ATTR_BG
readonly SGR_COL_BLACK=0
readonly SGR_COL_RED=1
readonly SGR_COL_GREEN=2
readonly SGR_COL_YELLOW=3
readonly SGR_COL_BLUE=4
readonly SGR_COL_MAGENTA=5
readonly SGR_COL_CYAN=6
readonly SGR_COL_WHITE=7
readonly SGR_COL_DEFAULT=9

# used for buffering of SGR commands
declare -i sgr_buffer_active=0
declare -a sgr_buffer_data


# Optionally save output to an array buffer.
function fn_sgr_print()
{
    local _out="$1"

    if((sgr_buffer_active > 0))
    then
        sgr_buffer_data+="$_out"
    else
        echo -en "$_out"
    fi
}

# output an SGR command sequence
function fn_sgr_set()
{
    local _param=$1
    fn_sgr_print "\e[${_param}m"
}

# Enable buffering. 
# Statements will accumulate in sgr_buffer_data.
function fn_sgr_seq_start()
{
    if((sgr_buffer_active > 0))
    then
        echo "ERROR: SGR is already in a transaction"
        exit
    fi
    sgr_buffer_data=()
    sgr_buffer_active=1
}

# flush buffer. 
# This must be called if used with fn_sgr_seq_start.
function fn_sgr_seq_flush()
{
    if((sgr_buffer_active == 0))
    then
        return
    fi

    # join buffer lines and echo
    local IFS=''
    echo -en "${sgr_buffer_data[*]}"

    # clear out buffer
    sgr_buffer_data=()
    sgr_buffer_active=0
}

# Simple color space (8x2)
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   1) Color [0-7]
#   2) Light [0-1]: luminosity
function fn_sgr_color16_set()
{
    local -i _sgr_attr=$1
    local -i _color=$2

    local -i _sgr_code=$((_color + _sgr_attr))
    fn_sgr_set $_sgr_code
}

# Send 216 color SGR code.
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) SGR color code
function fn_sgr_color216_set()
{
    local -i _sgr_attr=$1
    local -i _sgr_code=$2
    local -i _sgr_op=$((_sgr_attr + 8))
    fn_sgr_set "${_sgr_op};5;${_sgr_code}"
}

# Greyscale color space (26)
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Light [0-25]: luminosity
function fn_sgr_grey26_set()
{
    local -i _mode=$1
    local -i _light=$2

    local -i _sgr_code

    case $_light in
        0)
            _sgr_code=$((16))
            ;;
        25)
            _sgr_code=$((16 + 215))
            ;;
        *)
            _sgr_code=$((16 + 215 + _light))
            ;;
    esac

    fn_sgr_color216_set $_mode $_sgr_code
}

# RGB color space (6x6x6).
function fn_sgr_color216_get()
{
    local -i _red=$1
    local -i _green=$2
    local -i _blue=$3

    local -i _sgr_code=$((36*$_red + 6*$_green + $_blue + 16))
    return $_sgr_code
}

# RGB color space (6x6x6).
# Params:
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Red [0-5]
#   3) Green [0-5]
#   4) Blue [0-5]
function fn_sgr_rgb216_set() 
{
    # TODO: Add missing fn_sgr_color16_set colors to space
    local -i _mode=$1
    local -i _red=$2
    local -i _green=$3
    local -i _blue=$4

    fn_sgr_color216_get $_red $_green $_blue
    local -i _sgr_code=$?

    fn_sgr_color216_set $_mode $_sgr_code
}
