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
function fn_sgr_ansi16_set()
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
function fn_sgr_xterm240_set()
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
    local -i _intensity=$1
    local -i _sgr_code

    case $_intensity in
        0)
            _sgr_code=0
            ;;
        25)
            _sgr_code=215
            ;;
        *)
            _sgr_code=$((215 + _intensity))
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
    local -i _intensity=$2

    fn_sgr_grey26_get $_intensity
    local -i _sgr_code=$?

    fn_sgr_xterm240_set $_mode $_sgr_code
}

# RGB color space (6x6x6).
function fn_sgr_rgb216_get()
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
    # TODO: Add missing fn_sgr_ansi16_set colors to space
    local -i _mode=$1
    local -i _red=$2
    local -i _green=$3
    local -i _blue=$4

    fn_sgr_rgb216_get $_red $_green $_blue
    local -i _sgr_code=$?

    fn_sgr_xterm240_set $_mode $_sgr_code
}

# HSV colorspace params
declare -ir HSV216_HUE_SIZE=36
declare -ir HSV216_HUE_SECTORS=6
declare -ir HSV216_SAT_SIZE=6
declare -ir HSV216_VAL_SIZE=6

# Hue colors
declare -ir HSV216_HUE_RED=$((0*HSV216_HUE_SECTORS))
declare -ir HSV216_HUE_YELLOW=$((1*HSV216_HUE_SECTORS))
declare -ir HSV216_HUE_GREEN=$((2*HSV216_HUE_SECTORS))
declare -ir HSV216_HUE_CYAN=$((3*HSV216_HUE_SECTORS))
declare -ir HSV216_HUE_BLUE=$((4*HSV216_HUE_SECTORS))
declare -ir HSV216_HUE_MAGENTA=$((5*HSV216_HUE_SECTORS))

# lookup table for HSV-RGB transformations
declare -a HSV216_TABLE_DATA
declare -ir HSV216_TABLE_SIZE=$((HSV216_HUE_SIZE * HSV216_SAT_SIZE * HSV216_VAL_SIZE))

# Interpolate y coordinates
# Parameters)
#   1) x2: max X
#   2) y1: min Y
#   3) y2: max Y
#   4) xp: point to map
#
# This function will map a point yp in the range [0..x2] => [y1..y2] given yp:
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
    local -i _round_nearest=${5:-0}

    local -i _yp_numerator=$((_xp*_y2 + _x2*_y1 - _xp*_y1))
    local -i _yp_div=$((_yp_numerator / _x2))

    if((_round_nearest))
    then
        local -i _yp_error=$((_yp_numerator % _x2))
        if((_yp_error > (_x2/2 ) ))
        then
            ((_yp_div++))
        fi
    fi

    return $_yp_div
}

# Calculate HSV color space (36x6x6) for the lookup table. 
# Normalization for S<0 or H>=36 # are handled after the table calculation
# in fn_sgr_hsv216_set.
# This algorithm makes use of the fn_sgr_interp_y routine to simplify code at the 
# cost of minor additional computations. It is adapted for integer 
# calculations for a small set of colors.
function fn_sgr_hsv216_calc()
{
    local -i _hue=$1
    local -i _sat=$2
    local -i _intensity=$3

    # step within a sector [0-5]
    local -i _h_step=$(($_hue % 6))

    # sectors of the cylinder [0-5]
    local -i _h_sector=$(($_hue / 6))

    # minimum lightness:
    # Lmin = fn_sgr_interp_y(S: [0..5]->[0..V])
    fn_sgr_interp_y 5 $_intensity 0 $_sat
    local -i _v_min=$?
    
    # We round the interpolation only for the step and not the 
    # lightness because if we did to much error would carry over.
    local -ir ROUND_STEP=1

    # step scaled for lightness.
    # Vstep = fn_sgr_interp_y(step: [0..5]->[lMin..V])
    fn_sgr_interp_y 5 $_v_min $_intensity $_h_step $ROUND_STEP
    local -i _v_up=$?

    # inverse of the scaled lightness step.
    # Vinv = fn_sgr_interp_y(step: [0..5]->[V..lMin])
    fn_sgr_interp_y 5 $_intensity $_v_min $_h_step $ROUND_STEP
    local -i _v_dn=$?

    # for each sector add the contribution of RGB channels
    case $_h_sector in
        0) fn_sgr_rgb216_get $_intensity $_v_up      $_v_min ;;
        1) fn_sgr_rgb216_get $_v_dn      $_intensity $_v_min ;;
        2) fn_sgr_rgb216_get $_v_min     $_intensity $_v_up ;;
        3) fn_sgr_rgb216_get $_v_min     $_v_dn      $_intensity ;;
        4) fn_sgr_rgb216_get $_v_up      $_v_min     $_intensity ;;
        5) fn_sgr_rgb216_get $_intensity $_v_min     $_v_dn ;;
    esac

    local -i _sgr_code=$?
    return $_sgr_code
}

# Compute HSV table of 6*6*36=1296 values. 
function fn_sgr_hsv216_init()
{
    HSV216_TABLE_DATA[HSV216_TABLE_SIZE - 1]=0

    local -i _hue _sat _intensity
    local -i _sgr_code
    local -i _lut_idx

    for((_intensity = 0; _intensity < HSV216_VAL_SIZE; _intensity++))
    do
        for((_sat = 0; _sat < HSV216_SAT_SIZE; _sat++))
        do
            for((_hue = 0; _hue < HSV216_HUE_SIZE; _hue++))
            do
                fn_sgr_hsv216_calc $_hue $_sat $_intensity
                _sgr_code=$?

                _lut_idx=$((_intensity*HSV216_SAT_SIZE*HSV216_HUE_SIZE + _sat*HSV216_HUE_SIZE + _hue))
                HSV216_TABLE_DATA[_lut_idx]=$_sgr_code
            done
        done
    done
}

# HSV color space (36x6x6).
# Params:
#   2) Hue [0..35]: Angular indicator of color. This parameter is cyclic 
#          where 0 and 36 are equivalent.
#   3) Saturation [-5..5]: Indicates amount of color. Negative values will 
#          invert color.
#   4) Light [0..5]: Indicates luminosity.
function fn_sgr_hsv216_get()
{ 
    local -i _hue=$1
    local -i _sat=$2
    local -i _intensity=$3

    if((_intensity >= HSV216_VAL_SIZE))
    then
        fn_util_die "L value must be the range [0..5]: ${_intensity}"
    fi

    # handle negative saturation
    if((_sat < 0))
    then
        _sat=$((_sat * -1))
        _hue=$((_hue + HSV216_HUE_SIZE/2 - 1))
    fi

    # handle cyclic hue
    if((_hue >= HSV216_HUE_SIZE))
    then
        _hue=$((_hue % HSV216_HUE_SIZE))
    fi

    # get value from lookup table
    local -i _lut_size=${#HSV216_TABLE_DATA[*]}
    local -i _sgr_code

    if((_lut_size > 0))
    then
        # get from table
        _lut_idx=$((_intensity*HSV216_SAT_SIZE*HSV216_HUE_SIZE + _sat*HSV216_HUE_SIZE + _hue))
        _sgr_code=${HSV216_TABLE_DATA[_lut_idx]}

    else
        fn_sgr_hsv216_calc $_hue $_sat $_intensity
        _sgr_code=$?
    fi

    return $_sgr_code
}

# HSV color space (36x6x6).
# Params:
#   1) Mode [SGR_ATTR_FG|SGR_ATTR_BG]
#   2) Hue [0..35]: Angular indicator of color. This parameter is cyclic 
#          where 0 and 36 are equivalent.
#   3) Saturation [-5..5]: Indicates amount of color. Negative values will 
#          invert color.
#   4) Light [0..5]: Indicates luminosity.
function fn_sgr_hsv216_set()
{
    local -i _mode=$1
    local -i _hue=$2
    local -i _sat=$3
    local -i _intensity=$4

    local -i _sgr_code
    fn_sgr_hsv216_get $_hue $_sat $_intensity
    _sgr_code=$?

    fn_sgr_xterm240_set $_mode $_sgr_code
    return 0
}

# Compute a gradient given 2 RGB colors
function fn_sgr_rgb216_grad()
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

    local -ir ROUND=1

    for((_map_idx=0; _map_idx < _map_size; _map_idx++))
    do
        fn_sgr_interp_y $_last_idx $_start_red $_end_red $_map_idx $ROUND
        _interp_red=$?

        fn_sgr_interp_y $_last_idx $_start_green $_end_green $_map_idx $ROUND
        _interp_green=$?

        fn_sgr_interp_y $_last_idx $_start_blue $_end_blue $_map_idx $ROUND
        _interp_blue=$?

        fn_sgr_rgb216_get $_interp_red $_interp_green $_interp_blue $ROUND
        _sgr_color=$?

        _map_ref="$_map_name[$_map_idx]"
        eval "${_map_ref}=$_sgr_color"
    done
}
