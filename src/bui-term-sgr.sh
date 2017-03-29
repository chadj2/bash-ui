##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-term-sgr.sh
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

# used for buffering of SGR commands
declare -i sgr_buffer_active=0
declare -a sgr_buffer_data

# number of colors each for RGB
declare -ir RGB216_COLOR_SIZE=6


# Enable buffering. 
# Statements will accumulate in sgr_buffer_data.
function fn_sgr_seq_start()
{
    if((sgr_buffer_active > 0))
    then
        fn_util_die "SGR is already in a transaction"
    fi
    sgr_buffer_data=()
    sgr_buffer_active=1
}

# output data to the buffer
function fn_sgr_seq_write()
{
    local _data=$1

    if((sgr_buffer_active > 0))
    then
        sgr_buffer_data+="$_data"
    else
        echo -en "$_data"
    fi
}

# output an SGR command sequence
function fn_sgr_op()
{
    local _param=$1
    local _cmd="\e[${_param}m"

    fn_sgr_seq_write "$_cmd"
}

# flush buffer. 
# This must be called if used with fn_sgr_seq_start.
function fn_sgr_seq_flush()
{
    if((sgr_buffer_active == 0))
    then
        return
    fi

    fn_sgr_op $SGR_ATTR_DEFAULT

    local -i _buf_size=${#sgr_buffer_data[@]}
    if((_buf_size > 0)) 
    then
        # join buffer lines and echo
        local IFS=''
        echo -en "${sgr_buffer_data[*]}"
    fi 

    # clear out buffer
    sgr_buffer_data=()
    sgr_buffer_active=0
}

# output an escaped text
function fn_sgr_print()
{
    local _out="$1"

    # escape slashes
    _out="${_out//\\/\\\\}"
    fn_sgr_seq_write "$_out"
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
    fn_sgr_op $_sgr_code
}

# Send 216 color SGR code.
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) SGR color code
function fn_sgr_color216_set()
{
    local -i _sgr_attr=$1
    local -i _sgr_color=$2
    local -i _sgr_op=$((_sgr_attr + 8))
    local -i _sgr_code=$((_sgr_color + 16))
    fn_sgr_op "${_sgr_op};5;${_sgr_code}"
}

# Greyscale color space (26)
# Parameters)
#   2) Light [0-25]: luminosity
function fn_sgr_grey26_get()
{
    local -i _light=$1
    local -i _sgr_code

    case $_light in
        0)
            _sgr_code=0
            ;;
        25)
            _sgr_code=215
            ;;
        *)
            _sgr_code=$((215 + _light))
            ;;
    esac
    
    return $_sgr_code
}

# Greyscale color space (26)
# Parameters)
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Light [0-25]: luminosity
function fn_sgr_grey26_set()
{
    local -i _mode=$1
    local -i _light=$2

    fn_sgr_grey26_get $_light
    local -i _sgr_code=$?

    fn_sgr_color216_set $_mode $_sgr_code
}

# RGB color space (6x6x6).
function fn_sgr_color216_get()
{
    local -i _red=$1
    local -i _green=$2
    local -i _blue=$3

    local -i _sgr_code=0
    ((_sgr_code += _red ))
    ((_sgr_code *= RGB216_COLOR_SIZE))
    ((_sgr_code += _green))
    ((_sgr_code *= RGB216_COLOR_SIZE))
    ((_sgr_code += _blue))

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

# HSL colorspace params
declare -ir HSL216_HUE_SIZE=36
declare -ir HSL216_HUE_SECTORS=6
declare -ir HSL216_SAT_SIZE=6
declare -ir HSL216_LIGHT_SIZE=6

# Hue colors
declare -ir HSL216_HUE_RED=$((0*HSL216_HUE_SECTORS))
declare -ir HSL216_HUE_YELLOW=$((1*HSL216_HUE_SECTORS))
declare -ir HSL216_HUE_GREEN=$((2*HSL216_HUE_SECTORS))
declare -ir HSL216_HUE_CYAN=$((3*HSL216_HUE_SECTORS))
declare -ir HSL216_HUE_BLUE=$((4*HSL216_HUE_SECTORS))
declare -ir HSL216_HUE_MAGENTA=$((5*HSL216_HUE_SECTORS))

# lookup table for HSV-RGB transformations
declare -a HSL216_TABLE_DATA
declare -ir HSL216_TABLE_SIZE=$((HSL216_HUE_SIZE * HSL216_SAT_SIZE * HSL216_LIGHT_SIZE))

# Interpolate y coordinates
# Parameters)
#   1) x2: max X
#   2) y1: min Y
#   3) y2: max Y
#   4) xp: point to map
#
# This function will map a point yp in the range [0..x2] => [y1..y2] given yp:
#     yp = fn_hsl_interp_y( xp: [0..x2] => [y1..y2] )
#
# The points (0,y1) and (x2,y2) make a line. We determine the point (xp,yp) by 
# calculating yp given xp. The line is defined as:
#    (y2 - y1)/(x2 - x1) = (yp - y1)/(xp - x1)
#
# Setting x1=0 and solving for yp we have:
#    yp = (xp*y2 + x2*y1 - xp*y1)/x2
function fn_hsl_interp_y()
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
# in fn_hsl216_set.
# This algorithm makes use of the fn_hsl_interp_y routine to simplify code at the 
# cost of minor additional computations. It is adapted for integer 
# calculations for a small set of colors.
function fn_hsl216_calc()
{
    local -i _hue=$1
    local -i _sat=$2
    local -i _light=$3

    # step within a sector [0-5]
    local -i _sect_step=$(($_hue % 6))

    # sectors of the cylinder [0-5]
    local -i _sector=$(($_hue / 6))

    # minimum lightness:
    # Lmin = fn_hsl_interp_y(S: [0..5]->[0..L])
    fn_hsl_interp_y 5 $_light 0 $_sat
    local -i _l_min=$?
    
    # step scaled for lightness.
    # Lstep = fn_hsl_interp_y(step: [0..5]->[lMin..L])
    fn_hsl_interp_y 5 $_l_min $_light $_sect_step
    local -i _l_sc=$?

    # inverse of the scaled lightness step.
    # Linv = fn_hsl_interp_y(step: [0..5]->[L..lMin])
    fn_hsl_interp_y 5 $_light $_l_min $_sect_step
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
function fn_hsl216_init()
{
    HSL216_TABLE_DATA[HSL216_TABLE_SIZE - 1]=0

    local -i _hue _sat _light
    local -i _sgr_code
    local -i _lut_idx

    for((_light = 0; _light < HSL216_LIGHT_SIZE; _light++))
    do
        for((_sat = 0; _sat < HSL216_SAT_SIZE; _sat++))
        do
            for((_hue = 0; _hue < HSL216_HUE_SIZE; _hue++))
            do
                fn_hsl216_calc $_hue $_sat $_light
                _sgr_code=$?

                _lut_idx=$((_light*HSL216_SAT_SIZE*HSL216_HUE_SIZE + _sat*HSL216_HUE_SIZE + _hue))
                HSL216_TABLE_DATA[_lut_idx]=$_sgr_code
            done
        done
    done
}

# HSL color space (36x6x6).
# Params:
#   2) Hue [0..35]: Angular indicator of color. This parameter is cyclic 
#          where 0 and 36 are equivalent.
#   3) Saturation [-5..5]: Indicates amount of color. Negative values will 
#          invert color.
#   4) Light [0..5]: Indicates luminosity.
function fn_hsl216_get()
{ 
    local -i _hue=$1
    local -i _sat=$2
    local -i _light=$3

    if((_light >= HSL216_LIGHT_SIZE))
    then
        fn_util_die "L value must be the range [0..5]: ${_light}"
    fi

    # handle negative saturation
    if((_sat < 0))
    then
        _sat=$((_sat * -1))
        _hue=$((_hue + HSL216_HUE_SIZE/2 - 1))
    fi

    # handle cyclic hue
    if((_hue >= HSL216_HUE_SIZE))
    then
        _hue=$((_hue % HSL216_HUE_SIZE))
    fi

    # get value from lookup table
    local -i _lut_size=${#HSL216_TABLE_DATA[*]}
    local -i _sgr_code

    if((_lut_size > 0))
    then
        # get from table
        _lut_idx=$((_light*HSL216_SAT_SIZE*HSL216_HUE_SIZE + _sat*HSL216_HUE_SIZE + _hue))
        _sgr_code=${HSL216_TABLE_DATA[_lut_idx]}

    else
        fn_hsl216_calc $_hue $_sat $_light
        _sgr_code=$?
    fi

    return $_sgr_code
}

# HSL color space (36x6x6).
# Params:
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Hue [0..35]: Angular indicator of color. This parameter is cyclic 
#          where 0 and 36 are equivalent.
#   3) Saturation [-5..5]: Indicates amount of color. Negative values will 
#          invert color.
#   4) Light [0..5]: Indicates luminosity.
function fn_hsl216_set()
{
    local -i _mode=$1
    local -i _hue=$2
    local -i _sat=$3
    local -i _light=$4

    local -i _sgr_code
    fn_hsl216_get $_hue $_sat $_light
    _sgr_code=$?

    fn_sgr_color216_set $_mode $_sgr_code
    return 0
}

# Compute a gradient given 2 RGB colors
function fn_rgb216_gradient()
{
    local _map_name=$1
    local -i _map_size=$2
    local -i _start_sgr_color=$3
    local -i _end_sgr_color=$4

    # unpack RGB colors
    local -i _start_blue=$((_start_sgr_color % RGB216_COLOR_SIZE))
    ((_start_sgr_color /= RGB216_COLOR_SIZE))
    local -i _start_green=$((_start_sgr_color % RGB216_COLOR_SIZE))
    ((_start_sgr_color /= RGB216_COLOR_SIZE))
    local -i _start_red=$((_start_sgr_color % RGB216_COLOR_SIZE))

    # unpack RGB colors
    local -i _end_blue=$((_end_sgr_color % RGB216_COLOR_SIZE))
    ((_end_sgr_color /= RGB216_COLOR_SIZE))
    local -i _end_green=$((_end_sgr_color % RGB216_COLOR_SIZE))
    ((_end_sgr_color /= RGB216_COLOR_SIZE))
    local -i _end_red=$((_end_sgr_color % RGB216_COLOR_SIZE))

    local -i _map_idx
    local -i _last_idx=$((_map_size - 1))

    local -i _interp_red
    local -i _interp_green
    local -i _interp_blue
    local -i _sgr_color
    local _map_ref

    for((_map_idx=0; _map_idx < _map_size; _map_idx++))
    do
        fn_hsl_interp_y $_last_idx $_start_red $_end_red $_map_idx
        _interp_red=$?

        fn_hsl_interp_y $_last_idx $_start_green $_end_green $_map_idx
        _interp_green=$?

        fn_hsl_interp_y $_last_idx $_start_blue $_end_blue $_map_idx
        _interp_blue=$?

        fn_sgr_color216_get $_interp_red $_interp_green $_interp_blue
        _sgr_color=$?

        _map_ref="$_map_name[$_map_idx]"
        eval "${_map_ref}=$_sgr_color"
    done
}
