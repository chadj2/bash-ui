###!/bin/bash
##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-main.sh
# Description:  Top-level script for panel menus.
##

# generate errors if unset vars are used.
set -o nounset

source ${BIW_HOME}/biw-term-sgr.sh
source ${BIW_HOME}/biw-term-csi.sh
source ${BIW_HOME}/biw-theme-mgr.sh
source ${BIW_HOME}/biw-term-utf8.sh
source ${BIW_HOME}/biw-panel-hmenu.sh
source ${BIW_HOME}/biw-panel-credits.sh
source ${BIW_HOME}/biw-controller.sh

declare -r BIW_VERSION=0.9

# global widget params
declare -ri BIW_MARGIN=10
declare -ri BIW_PANEL_HEIGHT=20
declare -ri BIW_PANEL_WIDTH=60

declare -r BIW_OC_ANIMATE_DELAY=0.01

# Entires in HMenu
declare -r BIW_MENU_HISTORY='History'
declare -r BIW_MENU_BROWSE='File'
declare -r BIW_MENU_THEME='Theme'
declare -r BIW_MENU_CREDITS='Credits'

# cached position of the curor after restore
declare -i biw_cache_row_pos

# selected result when a panel is closed
declare biw_selection_result

# debug only
declare -i BIW_DEBUG_ENABLE=0
declare -i BIW_DEBUG_SEQ=0
declare BIW_DEBUG_MSG=''

function fn_biw_main()
{
    # truncate result file
    :> $BIW_CH_RES_FILE

    local -a _hmenu_values=(
        $BIW_MENU_HISTORY 
        $BIW_MENU_BROWSE 
        $BIW_MENU_THEME
        $BIW_MENU_CREDITS)

    fn_hmenu_init _hmenu_values[@]

    # show the widgets
    fn_biw_show

    # save to temporary file
    echo $biw_selection_result > $BIW_CH_RES_FILE
}

function fn_biw_show()
{
    local -r _history_cmd="fc -lnr -$CTL_LIST_MAX"

    fn_biw_open

    while [ 1 ]
    do
        fn_hmenu_get_current_val '_menu_val'
        biw_selection_result=''

        case $_menu_val in
            $BIW_MENU_HISTORY)
                fn_ctl_list_controller "$_history_cmd"
                ;;
            $BIW_MENU_BROWSE)
                fn_ctl_browse_controller
                ;;
            $BIW_MENU_THEME)
                fn_ctl_theme_controller
                ;;
            $BIW_MENU_CREDITS)
                fn_ctl_credits_controller
                ;;
        esac

        # exit if controller gave non-zero status
        if [ $? != 0 ]
        then
            break
        fi
    done

    fn_biw_close
}

function fn_biw_set_cursor_pos()
{
    local -i _abs_row=$1
    local -i _abs_col=$2

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_UP $((BIW_PANEL_HEIGHT - _abs_row))
    fn_biw_set_col_pos $_abs_col
}

function fn_biw_set_col_pos()
{
    local -i _abs_col=$1
    fn_csi_op $CSI_OP_COL_POS $((BIW_MARGIN + _abs_col))
}

function fn_biw_open()
{
    # Install panic handler
    #set -o errexit 
    trap 'fn_biw_panic' EXIT

    # make sure we call menu close during terminate to restore terminal settings
    trap 'fn_biw_close; exit 1' SIGHUP SIGINT SIGTERM

    # disable echo during redraw or else quickly repeated arrow keys
    # could move the cursor
    stty -echo

    # hide the cursor to eliminate flicker
    fn_csi_op $CSI_OP_CURSOR_HIDE

    # get the current position of the cursor
    fn_csi_get_row_pos 'biw_cache_row_pos'

    # scroll the screen to make space.
    fn_biw_scroll_open

    # save the cursor for a "home position"
    fn_csi_op $CSI_OP_CURSOR_SAVE
}

function fn_biw_scroll_open()
{
    local -i _move_lines=$((biw_cache_row_pos - BIW_PANEL_HEIGHT - 1))
    #echo "biw_cache_row_pos: $biw_cache_row_pos"
    #exit

    # if we are too close to the top of the screen then we need 
    # to move down instead of scroll up.
    if((_move_lines < 0))
    then
        fn_csi_op $CSI_OP_ROW_DOWN $BIW_PANEL_HEIGHT

        # update cursor position
        fn_csi_get_row_pos 'biw_cache_row_pos'
        return
    fi

    # animate open
    for((_line_idx = 0; _line_idx < BIW_PANEL_HEIGHT; _line_idx++))
    do
        fn_csi_op $CSI_OP_SCROLL_UP 1
        fn_csi_milli_wait $BIW_OC_ANIMATE_DELAY
    done

    # non-animated open:
    #fn_csi_op $CSI_OP_SCROLL_UP $BIW_PANEL_HEIGHT
    #fn_biw_cursor_home
    #fn_csi_op $CSI_OP_ROW_INSERT $BIW_PANEL_HEIGHT
}

function fn_biw_close()
{
    # position the cursor at the start of the menu
    fn_biw_set_cursor_pos 0 0

    # animate close
    for((_line_idx = 0; _line_idx < BIW_PANEL_HEIGHT; _line_idx++))
    do
        fn_csi_op $CSI_OP_ROW_DELETE 1
        fn_csi_op $CSI_OP_SCROLL_DOWN 1
        fn_csi_op $CSI_OP_ROW_DOWN 1
        fn_csi_milli_wait $BIW_OC_ANIMATE_DELAY
    done

    # non-animate close:
    #fn_csi_op $CSI_OP_ROW_DELETE $BIW_PANEL_HEIGHT
    #fn_csi_op $CSI_OP_SCROLL_DOWN $BIW_PANEL_HEIGHT

    # restore original cursor position
    fn_csi_op $CSI_OP_CURSOR_RESTORE

    # clear out any junk on the line
    fn_csi_op $CSI_OP_ROW_ERASE

    # restore terminal settings
    fn_csi_op $CSI_OP_CURSOR_SHOW

    # remove signal handler
    trap - SIGHUP SIGINT SIGTERM

    # remove panic handler
    trap - EXIT
}

function fn_biw_panic()
{
    set +x
    local _fail_func=${FUNCNAME[1]}
    local _fail_line=${BASH_LINENO[0]}
    local _command=$BASH_COMMAND

    # flush any commands in the buffer
    fn_sgr_seq_flush

    # show and restore cursor
    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_CURSOR_SHOW

    echo
    echo "PANIC Failure at (${_fail_func}:${_fail_line}):"
    echo "=> ${_command}"
    echo

    echo 'Call stack:'
    local _frame=0
    while caller $_frame
    do
        ((_frame++))
    done

    exit 1
}

fn_biw_debug_print()
{
    if((BIW_DEBUG_ENABLE <= 0))
    then
        return
    fi

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_ERASE

    printf 'DEBUG(%03d): %s' $BIW_DEBUG_SEQ "${BIW_DEBUG_MSG:-<none>}"

    BIW_DEBUG_MSG=''
    ((BIW_DEBUG_SEQ++))
}

fn_biw_debug_msg()
{
    if((BIW_DEBUG_ENABLE <= 0))
    then
        return
    fi

    local _pattern="${1:-<empty>}"
    shift
    printf -v BIW_DEBUG_MSG "%s: ${_pattern}" ${FUNCNAME[1]} "$@" 
}

# entry point
fn_biw_main
