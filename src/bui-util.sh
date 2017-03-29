##
##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-controller.sh
# Description:  Controller functions for vmenu panels
##

# set to 1 for debug line
declare -i UTIL_DEBUG_ENABLE=0

# debug state
declare -i UTIL_DEBUG_SEQ=0
declare UTIL_DEBUG_MSG=''

declare -ir BUI_PANEL_COL_SIZE_DEFAULT=60
declare -ir BUI_PANEL_COL_SIZE_MIN=40
declare -ir BUI_PANEL_COL_SIZE_MAX=80

declare -ir BUI_PANEL_ROW_SIZE_DEFAULT=20
declare -ir BUI_PANEL_ROW_SIZE_MIN=14
declare -ir BUI_PANEL_ROW_SIZE_MAX=40

# returned by actions to indicate if the menu contents changed. 
declare -ri UTIL_ACT_IGNORED=1
declare -ri UTIL_ACT_CHANGED=0

# controllers will set this when the app should terminate
declare -i util_exit_dispatcher=0

# settings keys
declare -r UTIL_PARAM_PANEL_ROWS='panel-rows'
declare -r UTIL_PARAM_PANEL_COLS='panel-cols'

function fn_util_dispatcher()
{
    local _menu_val
    local _controller

    while((!util_exit_dispatcher))
    do
        # redraw hmenu in case of change in theme, contents, etc.
        fn_hmenu_redraw

        bui_selection_result=''

        # get the current menu entry
        fn_hmenu_get_current_val '_menu_val'

        # find the controller function in the map
        _controller=${BUI_DISPATCH_MAP["$_menu_val"]:-fn_util_controller_default}

        # invoke the controller
        $_controller
        local -i _result=$?

        if [ $_result == 127 ]
        then
            fn_util_die "Controller not found: ${_controller}"
        fi
    done

    # exit request recieved so reset.
    util_exit_dispatcher=0
}

function fn_util_controller_default()
{
    # fill the panel with an empty box
    fn_draw_box_panel $((hmenu_row_pos + 1))

    local _key
    while fn_util_process_key _key
    do
        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            util_exit_dispatcher=1
            break
        fi
    done
}

function fn_util_process_key()
{
    local _key_ref=$1
    local _timeout=${2:-''}
    local -i _suppress_hmenu=${3:-0}

    # don't print debug if we are animating something 
    if [ -z "$_timeout" ]
    then
        fn_util_debug_print
    fi

    if ! fn_csi_read_key $_key_ref $_timeout
    then
        # got timeout
        return $UTIL_ACT_CHANGED
    fi

    fn_util_debug_msg "_key=<%s>" "${!_key_ref}"

    if [ "${!_key_ref}" == $CSI_KEY_ESC ]
    then
        # user pressed ESC so get out
        util_exit_dispatcher=1
        return $UTIL_ACT_IGNORED
    fi

    if [ $_suppress_hmenu != 0 ]
    then
        return $UTIL_ACT_CHANGED
    fi

    fn_hmenu_actions "${!_key_ref}"
    if [ $? == $UTIL_ACT_CHANGED ]
    then
        # hmenu was changed so panel is being switched
        # return 1 so the controller will exit
        return $UTIL_ACT_IGNORED
    fi
    
    # return 0 so the loop will continue
    return $UTIL_ACT_CHANGED
}

function fn_util_bash_version_check()
{
    local _min_version_str=$1

    local _current_str
    printf -v _current_str '%s.%s.%s' \
        "${BASH_VERSINFO[0]}" \
        "${BASH_VERSINFO[1]}" \
        "${BASH_VERSINFO[2]}"

    local -i _current_version
    fn_util_parse_version $_current_str '_current_version'

    local -i _min_version
    fn_util_parse_version $_min_version_str '_min_version'

    if((_current_version < _min_version))
    then
        fn_util_die "Bash Version too old (${_current_str} < ${_min_version_str})"
    fi
}

function fn_util_parse_version()
{
    local _version_str=$1
    local _result_ref=$2

    local -a _version_arr=( ${_version_str//./ } )
    local -i _version_int=0
    ((_version_int += _version_arr[0]))
    ((_version_int *= 100))
    ((_version_int += _version_arr[1]))
    ((_version_int *= 1000))
    ((_version_int += _version_arr[2]))

    printf -v $_result_ref '%d' $_version_int
}

function fn_util_panel_open()
{
    # Install panic handler
    #set -o errexit 
    trap 'fn_util_panic' EXIT

    # make sure we call menu close during terminate to restore terminal settings
    trap 'fn_util_panel_close; exit 1' SIGHUP SIGINT SIGTERM

    # disable echo during redraw or else quickly repeated arrow keys
    # could move the cursor
    stty -echo

    # load size prefs
    fn_settings_get_param "$UTIL_PARAM_PANEL_ROWS" \
        'draw_panel_row_size' $BUI_PANEL_ROW_SIZE_DEFAULT

    fn_settings_get_param "$UTIL_PARAM_PANEL_COLS" \
        'draw_panel_col_size' $BUI_PANEL_COL_SIZE_DEFAULT

    # hide the cursor to eliminate flicker
    fn_csi_op $CSI_OP_CURSOR_HIDE

    # get the current position of the cursor
    fn_csi_get_row_pos 'sgr_cache_row_pos'

    # scroll the screen to make space.
    fn_util_scroll_open

    # save the cursor for a "home position"
    fn_csi_op $CSI_OP_CURSOR_SAVE
}

function fn_util_scroll_open()
{
    local -i _move_lines=$((sgr_cache_row_pos - draw_panel_row_size - 1))

    # if we are too close to the top of the screen then we need 
    # to move down instead of scroll up.
    if((_move_lines < 0))
    then
        fn_csi_op $CSI_OP_ROW_DOWN $draw_panel_row_size

        # update cursor position
        fn_csi_get_row_pos 'sgr_cache_row_pos'
        return
    fi

    fn_draw_scroll_resize $draw_panel_row_size
}

function fn_util_panel_close()
{
    fn_draw_scroll_resize $((draw_panel_row_size*-1))

    # restore original cursor position
    fn_csi_op $CSI_OP_CURSOR_RESTORE

    # restore terminal settings
    fn_csi_op $CSI_OP_CURSOR_SHOW

    # remove signal handler
    trap - SIGHUP SIGINT SIGTERM

    # remove panic handler
    trap - EXIT
}

function fn_util_panel_set_dims()
{
    local -i _rows=$1
    local -i _cols=$2

    if((_rows != draw_panel_row_size))
    then
        fn_settings_set_param $UTIL_PARAM_PANEL_ROWS $_rows
        fn_draw_scroll_resize $((_rows - draw_panel_row_size))
        draw_panel_row_size=$_rows
    fi

    if((_cols != draw_panel_col_size))
    then
        fn_settings_set_param $UTIL_PARAM_PANEL_COLS $_cols
        fn_draw_clear_screen 0
        draw_panel_col_size=$_cols
    fi

    fn_hmenu_redraw
}


function fn_util_die()
{
    local _err_msg=$1

    fn_draw_set_col_pos 0
    echo "ERROR: $_err_msg" 2>&1

    # this exit should trigger the fn_util_panic trap.
    exit 1
}

function fn_util_assert_equals()
{
    local var1_ref=$1
    local var2_ref=$2
    local var1="${!var1_ref}"
    local var2="${!var2_ref}"

    if [ "${var1}" != "${var2}" ]
    then
        local _msg
        printf -v '_msg' '"Assert failed! %s(%s) != %s(%s)' \
            "$var1_ref" "$var1" "$var2_ref" "$var2"
        fn_util_die "$_msg"
    fi
}

function fn_util_panic()
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

    # move cursor down so we don't overwrite error messages
    fn_csi_op $CSI_OP_ROW_DOWN 5

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

function fn_util_debug_print()
{
    if((UTIL_DEBUG_ENABLE <= 0))
    then
        return
    fi

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_ERASE

    printf 'DEBUG(%03d): %s' $UTIL_DEBUG_SEQ "${UTIL_DEBUG_MSG:-<none>}"

    UTIL_DEBUG_MSG=''
    ((UTIL_DEBUG_SEQ++))
}

function fn_util_debug_msg()
{
    if((UTIL_DEBUG_ENABLE <= 0))
    then
        return
    fi

    local _pattern="${1:-<empty>}"
    shift
    #printf -v UTIL_DEBUG_MSG "%s: ${_pattern}" ${FUNCNAME[1]} "$@" 
    printf -v UTIL_DEBUG_MSG "${_pattern}" "$@"
}

# Return relative path from canonical absolute dir path $1 to canonical
# absolute dir path $2 ($1 and/or $2 may end with one or no "/").
# Only needs need POSIX shell builtins (no external command)
# source: http://stackoverflow.com/a/18898782/4316647
function fn_util_get_relpath() 
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

# Interpolate x coordinates
# Parameters)
#   1) x2: max X
#   2) y1: min Y
#   3) y2: max Y
#   4) yp: point to map
#
# This function will map a point yp in the range [0..x2] => [y1..y2] given xp:
#     xp = fn_util_interp_x( xp: [y1..y2] => [0..x2] )
#
# The points (0,y1) and (x2,y2) make a line. We determine the point (xp,yp) by 
# calculating xp given yp. The line is defined as:
#    (y2 - y1)/(x2 - x1) = (yp - y1)/(xp - x1)
#
# Setting x1=0 and solving for xp we have:
#    xp = (x2*yp - x2*y1)/(y2 - y1)
function fn_util_interp_x()
{
    local -i _x2=$1
    local -i _y1=$2
    local -i _y2=$3
    local -i _yp=$4

    local -i _xp_numerator=$((_x2*_yp - _x2*_y1))
    local -i _xp_demom=$((_y2 - _y1))
    local -i _xp_div=$((_xp_numerator / _xp_demom ))
    return $_xp_div
}
