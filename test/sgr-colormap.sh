##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

set -o nounset

source ${BUI_HOME}/bui-term-sgr.sh

function fn_sgr_map_all()
{
    echo 'SGR Map 16x16:'
    echo '       0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15'
    local -i _sgr_row

    for((_sgr_row=0; _sgr_row < 16; _sgr_row++))
    do
        printf '%3d) ' $((_sgr_row*16))

        local -i _sgr_col
        for((_sgr_col=0; _sgr_col < 16; _sgr_col++))
        do
            local _sgr_color=$((_sgr_row*16 + _sgr_col))
            local _sgr_op=$((SGR_ATTR_BG + 8))
            fn_sgr_op "${_sgr_op};5;${_sgr_color}"
            fn_sgr_print '   '
        done
        fn_sgr_op $SGR_ATTR_DEFAULT
        echo
    done
    echo
}

# Map of all SGR colors
fn_sgr_map_all
