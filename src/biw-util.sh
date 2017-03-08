##
##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-controller.sh
# Description:  Controller functions for vmenu panels
##


# global widget params
declare -ri BIW_MARGIN=10
declare -ri BIW_PANEL_HEIGHT=20
declare -ri BIW_PANEL_WIDTH=60

# returned by actions to indicate if the menu contents changed. 
declare -ri UTL_ACT_IGNORED=1
declare -ri UTL_ACT_CHANGED=0

# debug only
declare -i UTL_DEBUG_ENABLE=0
declare -i UTL_DEBUG_SEQ=0
declare UTL_DEBUG_MSG=''

declare -r UTL_OC_ANIMATE_DELAY=0.01

# file for persisting theme
declare -r BIW_SETTINGS_FILE=$HOME/.biw_settings
declare -A biw_settings_params

function fn_utl_set_cursor_pos()
{
    local -i _abs_row=$1
    local -i _abs_col=$2

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_UP $((BIW_PANEL_HEIGHT - _abs_row))
    fn_utl_set_col_pos $_abs_col
}

function fn_utl_set_col_pos()
{
    local -i _abs_col=$1
    fn_csi_op $CSI_OP_COL_POS $((BIW_MARGIN + _abs_col))
}

function fn_utl_process_key()
{
    local _key_ref=$1
    local _timeout=${2:-''}

    # don't print debug if we are animating something 
    if [ -z "$_timeout" ]
    then
        fn_utl_debug_print
    fi

    if ! fn_csi_read_key $_key_ref $_timeout
    then
        # got timeout
        return $UTL_ACT_CHANGED
    fi

    fn_utl_debug_msg "_key=<%s>" "${!_key_ref}"

    fn_hmenu_actions "${!_key_ref}"
    if [ $? == $UTL_ACT_CHANGED ]
    then
        # hmenu was changed so panel is being switched
        # return 1 so the controller will exit
        return $UTL_ACT_IGNORED
    fi
    
    # return 0 so the loop will continue
    return $UTL_ACT_CHANGED
}

function fn_utl_panel_open()
{
    # Install panic handler
    #set -o errexit 
    trap 'fn_utl_panic' EXIT

    # make sure we call menu close during terminate to restore terminal settings
    trap 'fn_utl_panel_close; exit 1' SIGHUP SIGINT SIGTERM

    # disable echo during redraw or else quickly repeated arrow keys
    # could move the cursor
    stty -echo

    # hide the cursor to eliminate flicker
    fn_csi_op $CSI_OP_CURSOR_HIDE

    # get the current position of the cursor
    fn_csi_get_row_pos 'sgr_cache_row_pos'

    # scroll the screen to make space.
    fn_utl_scroll_open

    # save the cursor for a "home position"
    fn_csi_op $CSI_OP_CURSOR_SAVE
}

function fn_utl_scroll_open()
{
    local -i _move_lines=$((sgr_cache_row_pos - BIW_PANEL_HEIGHT - 1))

    # if we are too close to the top of the screen then we need 
    # to move down instead of scroll up.
    if((_move_lines < 0))
    then
        fn_csi_op $CSI_OP_ROW_DOWN $BIW_PANEL_HEIGHT

        # update cursor position
        fn_csi_get_row_pos 'sgr_cache_row_pos'
        return
    fi

    # animate open
    for((_line_idx = 0; _line_idx < BIW_PANEL_HEIGHT; _line_idx++))
    do
        fn_csi_op $CSI_OP_SCROLL_UP 1
        fn_csi_milli_wait $UTL_OC_ANIMATE_DELAY
    done

    # non-animated open:
    #fn_csi_op $CSI_OP_SCROLL_UP $BIW_PANEL_HEIGHT
    #fn_biw_cursor_home
    #fn_csi_op $CSI_OP_ROW_INSERT $BIW_PANEL_HEIGHT
}

function fn_utl_panel_close()
{
    # position the cursor at the start of the menu
    fn_utl_set_cursor_pos 0 0

    # animate close
    for((_line_idx = 0; _line_idx < BIW_PANEL_HEIGHT; _line_idx++))
    do
        fn_csi_op $CSI_OP_ROW_DELETE 1
        fn_csi_op $CSI_OP_SCROLL_DOWN 1
        fn_csi_op $CSI_OP_ROW_DOWN 1
        fn_csi_milli_wait $UTL_OC_ANIMATE_DELAY
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

function fn_settings_get_param()
{
    local _param_ref=$1
    local _param_name=$2

    fn_settings_load
    local _param_val=${biw_settings_params[$_param_name]:-}
    printf -v $_param_ref '%s' "$_param_val"
}

function fn_settings_set_param()
{
    local _param_name=$1
    local _param_val=$2

    biw_settings_params[$_param_name]="$_param_val"
    fn_settings_save
}

function fn_settings_load()
{
    biw_settings_params=()

    if [ ! -r $BIW_SETTINGS_FILE ]
    then
        # nothing to do
        return 0
    fi

    local _line
    while read -r _line
    do
        _key="${_line%%=*}"
        _value=${_line##*=}

        if [ -z "$_key" ] || [ -z "$_value" ]
        then
            # skip this because we did not get a complete 
            # key/val pair
            continue
        fi

        biw_settings_params[$_key]="$_value"

    done < $BIW_SETTINGS_FILE
}

function fn_settings_save()
{
    local _key
    local _value

    for _key in "${!biw_settings_params[@]}"
    do
        _value="${biw_settings_params[$_key]}"
        printf '%s=%s\n' $_key "$_value"
    done > $BIW_SETTINGS_FILE
}

function fn_utl_die()
{
    local _err_msg=$1

    fn_utl_set_col_pos 0
    echo "ERROR: $msg" 2>&1

    # this exit should trigger the fn_utl_panic trap.
    exit 1
}

function fn_utl_panic()
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
}

function fn_utl_debug_print()
{
    if((UTL_DEBUG_ENABLE <= 0))
    then
        return
    fi

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_ERASE

    printf 'DEBUG(%03d): %s' $UTL_DEBUG_SEQ "${UTL_DEBUG_MSG:-<none>}"

    UTL_DEBUG_MSG=''
    ((UTL_DEBUG_SEQ++))
}

function fn_utl_debug_msg()
{
    if((UTL_DEBUG_ENABLE <= 0))
    then
        return
    fi

    local _pattern="${1:-<empty>}"
    shift
    printf -v UTL_DEBUG_MSG "%s: ${_pattern}" ${FUNCNAME[1]} "$@" 
}

# Return relative path from canonical absolute dir path $1 to canonical
# absolute dir path $2 ($1 and/or $2 may end with one or no "/").
# Only needs need POSIX shell builtins (no external command)
# source: http://stackoverflow.com/a/18898782/4316647
function fn_utl_get_relpath() 
{
    local _result_ref=$1
    local _source_path="${2%/}"
    local _dest_path="${3%/}/"

    local _up_path=''

    while [ "${_dest_path#"$_source_path"/}" = "$_dest_path" ]
    do
        _source_path="${_source_path%/*}"
        _up_path="../${_up_path}"
    done

    _dest_path="${_up_path}${_dest_path#"$_source_path"/}"
    _dest_path="${_dest_path%/}"

    printf -v $_result_ref '%s' "${_dest_path:-.}"
}
