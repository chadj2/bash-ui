##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

set -o nounset

source ${BIW_HOME}/biw-term-sgr.sh

function fn_rgb16_demo()
{
    echo "Color 8x2:"

    local _color
    local _light

    for _light in {0..1}
    do
        for _color in {0..7}
        do
            fn_sgr_color16_set $((SGR_ATTR_BG + _light*SGR_ATTR_BRIGHT)) $_color || exit 1
            echo -n " "
        done
        fn_sgr_op $SGR_ATTR_DEFAULT
        echo
    done
    echo
}

function fn_grey26_demo()
{
    echo "Grey 26x1:"

    local _light

    for _light in {0..25}
    do
        fn_sgr_grey26_set $SGR_ATTR_BG $_light || exit 1
        echo -n " "
    done

    fn_sgr_op $SGR_ATTR_DEFAULT
    echo
    echo
}

function fn_rgb216_grad_demo()
{
    echo "RGB 6x4:"

    for _red in {0..5}
    do
        fn_sgr_rgb216_set $SGR_ATTR_BG $_red 0 0 || exit 1
        echo -n " "
    done
    fn_sgr_op $SGR_ATTR_DEFAULT
    echo

    for _green in {0..5}
    do
        fn_sgr_rgb216_set $SGR_ATTR_BG 0 $_green 0 || exit 1
        echo -n " "
    done
    fn_sgr_op $SGR_ATTR_DEFAULT
    echo

    for _blue in {0..5}
    do
        fn_sgr_rgb216_set $SGR_ATTR_BG 0 0 $_blue || exit 1
        echo -n " "
    done
    fn_sgr_op $SGR_ATTR_DEFAULT
    echo

    for _grey in {0..5}
    do
        fn_sgr_rgb216_set $SGR_ATTR_BG $_grey $_grey $_grey || exit 1
        echo -n " "
    done
    fn_sgr_op $SGR_ATTR_DEFAULT
    echo

    echo
}

function fn_rgb216_grid_demo()
{
    echo "RGB 36x6:"
    local _red _green _blu

    for _red in {0..5}
    do
        for _green in {0..5}
        do
            for _blue in {0..5}
            do
                fn_sgr_rgb216_set $SGR_ATTR_BG $_red $_green $_blue || exit 1
                echo -n " "
            done
        done
        fn_sgr_op $SGR_ATTR_DEFAULT
        echo
    done
    echo
}

# display 16 basic colors
fn_rgb16_demo

# display a linear gradient of grayscale
fn_grey26_demo

# display linear gradients of RGB
fn_rgb216_grad_demo

# display a 6x36 block of all RGB colors
fn_rgb216_grid_demo
