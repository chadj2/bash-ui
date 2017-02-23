##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# These are added to a color code to make an SGR code
readonly SGR_ATTR_DEFAULT=0
readonly SGR_ATTR_BOLD=1
readonly SGR_ATTR_UNDERLINE=4
readonly SGR_ATTR_INVERT=7
readonly SGR_ATTR_FG=30
readonly SGR_ATTR_BG=40
readonly SGR_ATTR_BRIGHT=60

# color codes
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

# lookup table for HSV-RGB transformations
declare -a sgr_hsl_table
declare -ri SGR_HSL_TABLE_SIZE=$((6 * 6 * 36))

# Optionally save output to an array buffer.
function fn_sgr_print()
{
    local _out="$1"

    if((sgr_buffer_active > 0))
    then
        sgr_buffer_data+=( "$_out" )
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
    sgr_buffer_data=()
    sgr_buffer_active=1
}

# flush buffer. 
# This must be called if used with fn_sgr_seq_start.
function fn_sgr_seq_flush()
{
    # add color reset to the end of the buffer
    fn_sgr_set $SGR_ATTR_DEFAULT
    
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

# Send 216 color SGR code.
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) SGR color code
function fn_sgr_color216_set()
{
    local -i _sgr_mode=$1
    local -i _sgr_code=$2
    local -i _sgr_op=$((_sgr_mode + 8))
    fn_sgr_set "${_sgr_op};5;${_sgr_code}"
}

# Simple color space (8x2)
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   1) Color [0-7]
#   2) Light [0-1]: luminosity
function fn_sgr_color16_set()
{
    local -i _sgr_mode=$1
    local -i _color=$2
    local -i _light=$3

    local -i _sgr_light=$((_light ? SGR_ATTR_BRIGHT : 0))
    local -i _sgr_code=$((_color + _sgr_mode + _sgr_light))
    fn_sgr_set $_sgr_code
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

# Interpolate y coordinates
# Parameters)
#   1) x2: max X
#   2) y1: min Y
#   3) y2: max Y
#   4) xp: point to map
#
# This function will map a point yp in the range [0..x2] => [y1..y2] given xp:
#     yp = fn_sgr_interp_y( xp: [0..x2] => [y1..y2] )
#
# The points (0,y1) and (x2,y2) make a line. We determine the point (xp,yp) by 
# calculating yp given xp. The line is defined as:
#    (y2 - y1)/(x2 - x1) = (yp - y1)/(xp - x1)
#
# Setting x1=0 and solving for yp we have:
#    yp = (xp*y2 + x2*y1 - xp*y1)/x2
function fn_sgr_interp_y()
{
    local -i _x2=$1
    local -i _y1=$2
    local -i _y2=$3
    local -i _xp=$4

    local -i _yp_numerator=$((_xp*_y2 + _x2*_y1 - _xp*_y1))
    local -i _yp_div=$((_yp_numerator / _x2))
    return $_yp_div
}

# Calculate HSL color space (36x6x6) for the lookup table. 
# Normalization for S<0 or H>=36 # are handled after the table calculation
# in fn_sgr_hsl_set.
# This algorithm makes use of the fn_sgr_interp_y routine to simplify code at the 
# cost of minor additional computations. It is adapted for integer 
# calculations for a small set of colors.
function fn_sgr_hsl_calc()
{
    local -i _hue=$1
    local -i _sat=$2
    local -i _light=$3

    # step within a sector [0-5]
    local -i _sect_step=$(($_hue % 6))

    # sectors of the cylinder [0-5]
    local -i _sector=$(($_hue / 6))

    # minimum lightness:
    # Lmin = fn_sgr_interp_y(S: [0..5]->[0..L])
    fn_sgr_interp_y 5 $_light 0 $_sat
    local -i _l_min=$?
    
    # step scaled for lightness.
    # Lstep = fn_sgr_interp_y(step: [0..5]->[lMin..L])
    fn_sgr_interp_y 5 $_l_min $_light $_sect_step
    local -i _l_sc=$?

    # inverse of the scaled lightness step.
    # Linv = fn_sgr_interp_y(step: [0..5]->[L..lMin])
    fn_sgr_interp_y 5 $_light $_l_min $_sect_step
    local -i _l_sci=$?

    # for each sector add the contribution of RGB channels
    case $_sector in
        0) fn_sgr_color216_get $_light     $_l_sc      $_l_min ;;
        1) fn_sgr_color216_get $_l_sci     $_light     $_l_min ;;
        2) fn_sgr_color216_get $_l_min     $_light     $_l_sc ;;
        3) fn_sgr_color216_get $_l_min     $_l_sci     $_light ;;
        4) fn_sgr_color216_get $_l_sc      $_l_min     $_light ;;
        5) fn_sgr_color216_get $_light     $_l_min     $_l_sci ;;
    esac

    local -i _sgr_code=$?
    return $_sgr_code
}

# Compute HSV table of 6*6*36=1296 values. 
function fn_sgr_hsl_init()
{
    sgr_hsl_table[SGR_HSL_TABLE_SIZE - 1]=0

    local -i _hue _sat _light
    local -i _sgr_code
    local -i _lut_idx

    for _light in {0..5}
    do
        for _sat in {0..5}
        do
            for _hue in {0..35} 
            do
                fn_sgr_hsl_calc $_hue $_sat $_light
                _sgr_code=$?

                _lut_idx=$((_light*6*36 + _sat*36 + _hue))
                sgr_hsl_table[_lut_idx]=$_sgr_code
            done
        done
    done
}

# HSL color space (36x6x6).
# Params:
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Hue [0..35]: Angular indicator of color. This parameter is cyclic 
#          where 0 and 36 are equivalent.
#   3) Saturation [-5..5]: Indicates amount of color. Negative values will 
#          invert color.
#   4) Light [0..5]: Indicates luminosity.
function fn_sgr_hsl_set()
{ 
    local -i _mode=$1

    local -i _hue=$2
    local -i _sat=$3
    local -i _light=$4

    if((_light >= 6))
    then
        echo "Error: L value must be the range [0..5]: ${_light}"
        return 1
    fi

    # handle negative saturation
    if((_sat < 0))
    then
        _sat=$((_sat * -1))
        _hue=$((_hue + 36/2 - 1))
    fi

    # handle cyclic hue
    if((_hue >= 36))
    then
        _hue=$((_hue % 36))
    fi

    # get value from lookup table
    local -i _lut_size=${#sgr_hsl_table[*]}
    if((_lut_size != SGR_HSL_TABLE_SIZE))
    then
        echo "Error: HSV table not initialized."
        return 1
    fi

    local -i _lut_idx=$((_light*6*36 + _sat*36 + _hue))
    local -i _sgr_code=${sgr_hsl_table[_lut_idx]}

    fn_sgr_color216_set $_mode $_sgr_code
    return 0
}
