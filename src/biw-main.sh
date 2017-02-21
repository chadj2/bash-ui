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

declare -ri biw_enable_debug=0

# global widget params
declare -ri biw_margin=10

# max values to load for history and file lists
declare -ri biw_values_max=30

declare -r biw_act_terminate=1
declare -r biw_act_continue=0

# Options for HMenu
declare -r biw_menu_history="History"
declare -r biw_menu_comp="FileCompl"
declare -r biw_menu_theme="Theme"


function fn_biw_main()
{
    # truncate result file
    :> $BIW_CH_RES_FILE

    local -a _hmenu_values=(
        $biw_menu_history 
        $biw_menu_comp 
        $biw_menu_theme)

    fn_hmenu_init _hmenu_values[@]

    # show the widgets
    fn_biw_show

    # get result from index
    local _result=$(fn_vmenu_get_current_val)

    # save to temporary file
    echo $_result > $BIW_CH_RES_FILE
}

function fn_biw_show()
{
    local -i _panel_height=$((vmenu_height + hmenu_height))

    fn_theme_init
    fn_biw_open

    fn_hmenu_redraw
    fn_biw_reload_vmenu
    fn_biw_debug_stats

    local _key
    while fn_csi_read_key _key
    do
        fn_biw_all_actions "$_key"
        local _result=$?
        fn_biw_debug_stats
        (( $_result == $biw_act_terminate )) && continue

        if [ "$_key" == $csi_key_eol ]
        then
            # we got the enter key so close the menu
            break
        fi
    done

    fn_biw_close
}

fn_biw_all_actions()
{
    local _key=$1

    # each action handler decides if the action chain should terminate
    fn_hmenu_actions "$_key" || return $biw_act_terminate
    fn_vmenu_actions "$_key" || return $biw_act_terminate
    fn_biw_menu_actions "$_key" || return $biw_act_terminate
    fn_biw_theme_actions "$_key" || return $biw_act_terminate

    return $biw_act_continue
}

fn_biw_menu_actions()
{
    local _key=$1

    # update vmenu if hmenu is changed
    case "$_key" in
        $csi_key_left|$csi_key_right)
            fn_biw_reload_vmenu
            return $biw_act_terminate
            ;;
    esac

    return $biw_act_continue
}

fn_biw_theme_actions()
{
    local _key=$1
    local _menu_val=$(fn_hmenu_get_current_val)

    if [ "$_menu_val" != "$biw_menu_theme" ]
    then
        return $biw_act_continue
    fi

    case "$_key" in
        $csi_key_up|$csi_key_down)
            # use the vmenu index to determine the selected theme
            fn_theme_set_idx_active $vmenu_idx_active

            # redraw with new theme
            fn_hmenu_redraw
            fn_vmenu_redraw
            ;;
        $csi_key_eol) 
            # Save selected Theme
            vmenu_idx_checked=$theme_active_idx
            fn_theme_save
            fn_vmenu_redraw
            ;;
    esac

    return $biw_act_terminate
}

fn_biw_reload_vmenu()
{
    local _menu_val=$(fn_hmenu_get_current_val)

    # restore theme from before we previewed
    fn_theme_set_idx_active $theme_saved_idx
 
    case $_menu_val in
        $biw_menu_history)
            fn_biw_vmenu_init_command "fc -lnr -$biw_values_max"
            ;;
        $biw_menu_comp)
            fn_biw_vmenu_init_command "compgen -A file ${READLINE_LINE}"
            ;;
        $biw_menu_theme)
            fn_vmenu_init "theme_name_list[@]" $theme_active_idx
            vmenu_idx_checked=$theme_active_idx
            ;;
    esac
    
    fn_hmenu_redraw
    fn_vmenu_redraw
}

fn_biw_vmenu_init_command()
{
    local _data_command=$1
    local -a _values

    # read command into _values
    mapfile -t -n $biw_values_max _values < <($_data_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
}

function fn_biw_cursor_home()
{
    # position the cursor at the start of the menu
    fn_csi_op $csi_op_cursor_restore
    fn_csi_op $csi_op_row_up $_panel_height
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
    fn_csi_op $csi_op_cursor_hide

    # save the cursor for a "home position"
    fn_csi_op $csi_op_cursor_save

    # animate open
    for _line_idx in $(eval echo {1..$_panel_height})
    do
        fn_csi_op $csi_op_scroll_up 1
        fn_csi_milli_wait
    done

    # non-animated open:
    #fn_csi_op $csi_op_scroll_up $_panel_height
    #fn_biw_cursor_home
    #fn_csi_op $csi_op_row_insert $_panel_height
}

function fn_biw_close()
{
    # goto home position
    fn_biw_cursor_home

    # animate close
    for _line_idx in $(eval echo {1..$_panel_height})
    do
        fn_csi_op $csi_op_row_delete 1
        fn_csi_op $csi_op_scroll_down 1
        fn_csi_op $csi_op_row_down 1
        fn_csi_milli_wait
    done

    # non-animate close:
    #fn_csi_op $csi_op_row_delete $_panel_height
    #fn_csi_op $csi_op_scroll_down $_panel_height

    # restore original cursor position
    fn_csi_op $csi_op_cursor_restore

    # restore terminal settings
    fn_csi_op $csi_op_cursor_show

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
    # show cursor
    fn_csi_op $csi_op_cursor_show

    # restore default colors
    fn_sgr_set $sgr_attr_default

    local _fail_func=${FUNCNAME[1]}
    local _fail_line=${BASH_LINENO[0]}

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
    if((biw_enable_debug <= 0))
    then
        return
    fi

    fn_csi_op $csi_op_cursor_restore

    echo -n "redraw_h(${hmenu_idx_redraws}) redraw_v(${vmenu_idx_redraws}) "
    echo -n "theme_s(${theme_saved_idx}) theme_a(${theme_active_idx}) "
}

# entry point
fn_biw_main
