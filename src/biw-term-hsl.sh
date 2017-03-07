##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-hsi.sh
# Description:  Compute HSL (Hue/Saturation/Light) color space in 216 
#               color SGR mode.
##

# colorspace params
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
# This function will map a point yp in the range [0..x2] => [y1..y2] given xp:
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
        fn_utl_die "L value must be the range [0..5]: ${_light}"
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
