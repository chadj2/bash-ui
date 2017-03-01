##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-sgr.sh
# Description:  Send terminal control SGR sequences to set text colors and
#               attributes. 
##

# These are added to a color code to make an SGR code
declare -ri  SGR_ATTR_DEFAULT=0
declare -ri  SGR_ATTR_BOLD=1
declare -ri  SGR_ATTR_UNDERLINE=4
declare -ri  SGR_ATTR_INVERT=7
declare -ri  SGR_ATTR_FG=30
declare -ri  SGR_ATTR_BG=40
declare -ri  SGR_ATTR_BRIGHT=60

# color codes must be added to SGR_ATTR_FG or SGR_ATTR_BG
declare -ri  SGR_COL_BLACK=0
declare -ri  SGR_COL_RED=1
declare -ri  SGR_COL_GREEN=2
declare -ri  SGR_COL_YELLOW=3
declare -ri  SGR_COL_BLUE=4
declare -ri  SGR_COL_MAGENTA=5
declare -ri  SGR_COL_CYAN=6
declare -ri  SGR_COL_WHITE=7
declare -ri  SGR_COL_DEFAULT=9

# Codes to print from the DEC graphics charset
declare -ri SGI_CHAR_LINE_VERT=170
declare -ri SGI_CHAR_LINE_HORIZ=161
declare -ri SGI_CHAR_LINE_TOP_T=167
declare -ri SGI_CHAR_LINE_BOTTOM_T=166
declare -ri SGI_CHAR_LINE_BL=155
declare -ri SGI_CHAR_LINE_BR=152
declare -ri SGI_CHAR_BLOCK=141
declare -ri SGI_CHAR_BULLET=176
declare -ri SGI_CHAR_DIAMOND=140

declare -r SGI_GRAPHIC_START=$'\e(0'
declare -r SGI_GRAPHIC_END=$'\e(B'

# used for buffering of SGR commands
declare -i sgr_buffer_active=0
declare -a sgr_buffer_data


# Optionally save output to an array buffer.
function fn_sgr_print()
{
    local _out="$1"

    # escape slashes
    _out="${_out//\\/\\\\}"

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
    local _cmd="\e[${_param}m"

    if((sgr_buffer_active > 0))
    then
        sgr_buffer_data+="$_cmd"
    else
        echo -en "$_cmd"
    fi
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

function fn_sgr_graphic_set()
{
    local _result_ref=$1
    local -i _octal_num=$2

    printf -v $_result_ref '%b' \
        $SGI_GRAPHIC_START \
        "\\$_octal_num" \
        $SGI_GRAPHIC_END
}

function fn_sgr_graphic_print()
{
    local -i _octal_num=$1
    local _out

    fn_sgr_graphic_set _out $_octal_num
    fn_sgr_print "$_out"
}

function fn_sgr_pad_string()
{
    local _result_ref=$1
    local -i _pad_width=$2

    printf -v $_result_ref "%-${_pad_width}s" "${!_result_ref}"
    printf -v $_result_ref '%s' "${!_result_ref:0:${_pad_width}}"
}

function fn_sgr_print_h_line()
{
    local -i _line_width=$1

    local _sgr_line
    local _pad_char="\\$SGI_CHAR_LINE_HORIZ"
    printf -v _sgr_line '%*s' $cred_canvas_width
    printf -v _sgr_line '%b' "${_sgr_line// /${_pad_char}}"

    fn_sgr_print $SGI_GRAPHIC_START
    fn_sgr_print $_sgr_line
    fn_sgr_print $SGI_GRAPHIC_END
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
