##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

set -o nounset

source ${BUI_HOME}/bui-term-sgr.sh

function fn_hsl_gradient_print()
{
    local -i _hue_start=$1
    local -i _hue_end=$2
    local -i _sat=$3
    local -i _bright=$4

    fn_sgr_hsv216_get $_hue_start $_sat $_bright
    local -i _sgr_start=$?

    fn_sgr_hsv216_get $_hue_end $_sat $_bright
    local -i _sgr_end=$?

    # generate color map
    local -i _map_size=24
    local -a _cmap=()
    fn_sgr_rgb216_grad '_cmap' $_map_size $_sgr_start $_sgr_end

    local -i _map_idx
    local -i _sgr_color

    for((_map_idx=0; _map_idx < _map_size; _map_idx++))
    do
        _sgr_color=${_cmap[_map_idx]}
        fn_sgr_xterm240_set $SGR_ATTR_BG $_sgr_color
        fn_sgr_print ' '
    done
    fn_sgr_op $SGR_ATTR_DEFAULT
    echo
}

function fn_hsl_gradient_demo()
{
    echo "Green to Cyan gradient for Saturation: "

    local -i _sat
    for((_sat = HSV216_SAT_SIZE - 1; _sat >= 0; _sat--))
    do
        fn_sgr_print "S=${_sat}) "
        fn_hsl_gradient_print $HSV216_HUE_GREEN $HSV216_HUE_RED $_sat 5
    done
    echo

    echo "Green to Cyan gradient for Light: "

    local -i _bright
    for((_bright = HSV216_VAL_SIZE - 1; _bright >= 0; _bright--))
    do
        fn_sgr_print "V=${_bright}) "
        fn_hsl_gradient_print $HSV216_HUE_GREEN $HSV216_HUE_RED 5 $_bright
    done
    echo
}

# compute a gradient between 2 HSV colors in RGB space
fn_hsl_gradient_demo
