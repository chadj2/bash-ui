###!/bin/bash
##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# generate errors if unset vars are used.
set -o nounset

source ${BIW_HOME}/biw-term-csi.sh
source ${BIW_HOME}/biw-term-sgr.sh
source ${BIW_HOME}/biw-theme.sh
source ${BIW_HOME}/biw-vmenu.sh
source ${BIW_HOME}/biw-hmenu.sh

declare -ri BIW_ENABLE_DEBUG=0

# global widget params
declare -ri BIW_MARGIN=10
declare -ri BIW_PANEL_HEIGHT=9

# max values to load for history and file lists
declare -ri BIW_VALUES_MAX=30

declare -ri BIW_ACT_IGNORED=1
declare -ri BIW_ACT_HANDLED=0

# Options for HMenu
declare -r BIW_MENU_HISTORY="History"
declare -r BIW_MENU_COMP="FileCompl"
declare -r BIW_MENU_THEME="Theme"

function fn_biw_main()
{
    # truncate result file
    :> $BIW_CH_RES_FILE

    local -a _hmenu_values=(
        $BIW_MENU_HISTORY 
        $BIW_MENU_COMP 
        $BIW_MENU_THEME)

    fn_hmenu_init _hmenu_values[@]

    # show the widgets
    fn_theme_init
    fn_biw_show

    # get result from index
    local _result=$(fn_vmenu_get_current_val)

    # save to temporary file
    echo $_result > $BIW_CH_RES_FILE
}

function fn_biw_show()
{
    local -r _history_cmd="fc -lnr -$BIW_VALUES_MAX"
    local -r _comp_cmd="compgen -A file ${READLINE_LINE}"

    fn_biw_open
    fn_hmenu_redraw

    local _continue=0
    while ((_continue == 0))
    do
        local _menu_val=$(fn_hmenu_get_current_val)

        case $_menu_val in
            $BIW_MENU_HISTORY)
                fn_biw_list_controller "$_history_cmd"
                ;;
            $BIW_MENU_COMP)
                fn_biw_list_controller "$_comp_cmd"
                ;;
            $BIW_MENU_THEME)
                fn_biw_theme_controller
                ;;
        esac

        _continue=$?
    done

    fn_biw_close
}

function fn_biw_process_key()
{
    fn_biw_debug_stats

    local _result_var=$1
    fn_csi_read_key $_result_var

    fn_hmenu_actions "$_key"
    if [ $? == $BIW_ACT_HANDLED ]
    then
        # hmenu was changed so panel is being switched
        # return 1 so the controller will exit
        return 1
    fi

    # return 0 so the loop will continue
    return 0
}

function fn_biw_list_controller()
{
    local _panel_command=$1
    local -a _values

    # read command into _values
    mapfile -t -n $BIW_VALUES_MAX _values < <($_panel_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
    fn_vmenu_redraw

    local _key
    while fn_biw_process_key _key
    do
        fn_vmenu_actions "$_key"

        if [ "$_key" == $CSI_KEY_EOL ]
        then
            # we got the enter key so close the menu
            return 1
        fi
    done

    return 0
}

function fn_biw_theme_controller()
{
    # load theme data into menu
    fn_vmenu_init "theme_name_list[@]" $theme_active_idx
    vmenu_idx_checked=$theme_active_idx
    fn_vmenu_redraw

    local _key
    while fn_biw_process_key _key
    do
        fn_vmenu_actions "$_key"

        case "$_key" in
            $CSI_KEY_UP|$CSI_KEY_DOWN)
                # use the vmenu index to determine the selected theme
                fn_theme_set_idx_active $vmenu_idx_active

                # redraw with new theme
                fn_hmenu_redraw
                fn_vmenu_redraw
                ;;
            $CSI_KEY_EOL) 
                # Save selected Theme
                fn_theme_save

                # update checkbox
                vmenu_idx_checked=$theme_active_idx
                fn_vmenu_redraw
                ;;
        esac
    done

    # restore theme from before we previewed
    fn_theme_set_idx_active $theme_saved_idx
    fn_hmenu_redraw

    return 0
}

function fn_biw_cursor_home()
{
    # position the cursor at the start of the menu
    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_UP $BIW_PANEL_HEIGHT
}

function fn_biw_open()
{
    # Install panic handler
    trap "fn_biw_panic" EXIT

    # make sure we call menu close during terminate to restore terminal settings
    trap "fn_biw_close; exit 1" SIGHUP SIGINT SIGTERM

    # disable echo during redraw or else quickly repeated arrow keys
    # could move the cursor
    stty -echo

    # hide the cursor to eliminate flicker
    fn_csi_op $CSI_OP_CURSOR_HIDE

    # save the cursor for a "home position"
    fn_csi_op $CSI_OP_CURSOR_SAVE

    # animate open
    for _line_idx in $(eval echo {1..$BIW_PANEL_HEIGHT})
    do
        fn_csi_op $CSI_OP_SCROLL_UP 1
        fn_csi_milli_wait
    done

    # non-animated open:
    #fn_csi_op $CSI_OP_SCROLL_UP $BIW_PANEL_HEIGHT
    #fn_biw_cursor_home
    #fn_csi_op $CSI_OP_ROW_INSERT $BIW_PANEL_HEIGHT
}

function fn_biw_close()
{
    # goto home position
    fn_biw_cursor_home

    # animate close
    for _line_idx in $(eval echo {1..$BIW_PANEL_HEIGHT})
    do
        fn_csi_op $CSI_OP_ROW_DELETE 1
        fn_csi_op $CSI_OP_SCROLL_DOWN 1
        fn_csi_op $CSI_OP_ROW_DOWN 1
        fn_csi_milli_wait
    done

    # non-animate close:
    #fn_csi_op $CSI_OP_ROW_DELETE $BIW_PANEL_HEIGHT
    #fn_csi_op $CSI_OP_SCROLL_DOWN $BIW_PANEL_HEIGHT

    # restore original cursor position
    fn_csi_op $CSI_OP_CURSOR_RESTORE

    # restore terminal settings
    fn_csi_op $CSI_OP_CURSOR_SHOW

    # restore terminal settings
    #commenting this out because bash does not like it
    #stty echo

    # remove signal handler
    trap - SIGHUP SIGINT SIGTERM

    # remove panic handler
    trap - EXIT
}

function fn_biw_panic()
{
    local _fail_func=${FUNCNAME[1]}
    local _fail_line=${BASH_LINENO[0]}

    # show cursor
    fn_csi_op $CSI_OP_CURSOR_SHOW

    # restore default colors
    fn_sgr_set $SGR_ATTR_DEFAULT

    echo
    echo "PANIC Failure at: "
    echo "<${BASH_COMMAND}>(${_fail_func}:${_fail_line})"
    echo

    echo "Call stack:"
    local _frame=0
    while caller $_frame; do
        ((_frame++));
    done

    exit 1
}

fn_biw_debug_stats()
{
    if((BIW_ENABLE_DEBUG <= 0))
    then
        return
    fi

    fn_csi_op $CSI_OP_CURSOR_RESTORE

    echo -n "redraw_h(${hmenu_idx_redraws}) redraw_v(${vmenu_idx_redraws}) "
    echo -n "theme_s(${theme_saved_idx}) theme_a(${theme_active_idx}) "
}

# entry point
fn_biw_main
