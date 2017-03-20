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

source ${BUI_HOME}/bui-settings.sh
source ${BUI_HOME}/bui-term-utf8.sh
source ${BUI_HOME}/bui-term-sgr.sh
source ${BUI_HOME}/bui-term-csi.sh

# global panel geometry
declare -ir BUI_MARGIN=10
declare -ir BUI_PANEL_COL_SIZE_DEFAULT=60
declare -i bui_panel_col_size
declare -ir BUI_PANEL_ROW_SIZE_DEFAULT=20
declare -i bui_panel_row_size

# returned by actions to indicate if the menu contents changed. 
declare -ri UTIL_ACT_IGNORED=1
declare -ri UTIL_ACT_CHANGED=0

# debug only
declare -i UTIL_DEBUG_ENABLE=0
declare -i UTIL_DEBUG_SEQ=0
declare UTIL_DEBUG_MSG=''

# determines speed of panel open/close
declare -r UTIL_OC_ANIMATE_DELAY=0.01

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
    fn_util_draw_box_panel $((hmenu_row_pos + 1))

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

function fn_util_set_cursor_pos()
{
    local -i _abs_row=$1
    local -i _abs_col=$2

    fn_csi_op $CSI_OP_CURSOR_RESTORE
    fn_csi_op $CSI_OP_ROW_UP $((bui_panel_row_size - _abs_row))
    fn_util_set_col_pos $_abs_col
}

function fn_util_set_col_pos()
{
    local -i _abs_col=$1
    fn_csi_op $CSI_OP_COL_POS $((BUI_MARGIN + _abs_col))
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
        'bui_panel_row_size' $BUI_PANEL_ROW_SIZE_DEFAULT

    fn_settings_get_param "$UTIL_PARAM_PANEL_COLS" \
        'bui_panel_col_size' $BUI_PANEL_COL_SIZE_DEFAULT

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
    local -i _move_lines=$((sgr_cache_row_pos - bui_panel_row_size - 1))

    # if we are too close to the top of the screen then we need 
    # to move down instead of scroll up.
    if((_move_lines < 0))
    then
        fn_csi_op $CSI_OP_ROW_DOWN $bui_panel_row_size

        # update cursor position
        fn_csi_get_row_pos 'sgr_cache_row_pos'
        return
    fi

    fn_util_scroll_resize $bui_panel_row_size
}

function fn_util_panel_close()
{
    fn_util_scroll_resize $((bui_panel_row_size*-1))

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

    if((_rows != bui_panel_row_size))
    then
        fn_settings_set_param $UTIL_PARAM_PANEL_ROWS $_rows
        fn_util_scroll_resize $((_rows - bui_panel_row_size))
        bui_panel_row_size=$_rows
    fi

    if((_cols != bui_panel_col_size))
    then
        fn_settings_set_param $UTIL_PARAM_PANEL_COLS $_cols
        fn_util_clear_screen 0
        bui_panel_col_size=$_cols
    fi

    fn_hmenu_redraw
}

function fn_util_scroll_resize()
{
    local -i _rows=$1

    local -i _line_idx
    local -i _row_count

    if((_rows < 0))
    then
        # position the cursor at the start of the menu
        fn_util_set_cursor_pos 0 0

        _row_count=$((_rows*-1))

        # animate close
        for((_line_idx = 0; _line_idx < _row_count; _line_idx++))
        do
            fn_csi_op $CSI_OP_ROW_DELETE 1
            fn_csi_op $CSI_OP_SCROLL_DOWN 1
            fn_csi_op $CSI_OP_ROW_DOWN 1
            fn_csi_milli_wait $UTIL_OC_ANIMATE_DELAY
        done

        # clear out any junk on the line
        fn_csi_op $CSI_OP_ROW_ERASE
        
        # non-animate close:
        #fn_csi_op $CSI_OP_ROW_DELETE $bui_panel_row_size
        #fn_csi_op $CSI_OP_SCROLL_DOWN $bui_panel_row_size
    else

        _row_count=$_rows

        # animate open
        for((_line_idx = 0; _line_idx < _row_count; _line_idx++))
        do
            fn_csi_op $CSI_OP_SCROLL_UP 1
            fn_csi_milli_wait $UTIL_OC_ANIMATE_DELAY
        done

        # non-animated open:
        #fn_csi_op $CSI_OP_SCROLL_UP $bui_panel_row_size
        #fn_bui_cursor_home
        #fn_csi_op $CSI_OP_ROW_INSERT $bui_panel_row_size
    fi
}

function fn_util_die()
{
    local _err_msg=$1

    fn_util_set_col_pos 0
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
    printf -v UTIL_DEBUG_MSG "%s: ${_pattern}" ${FUNCNAME[1]} "$@" 
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

function fn_util_draw_footer()
{
    local _message="$1"

    fn_sgr_seq_start
    fn_util_set_cursor_pos $bui_panel_row_size 0

    fn_theme_set_attr_slider 1
    fn_utf8_print $BUI_CHAR_LINE_BT_LT
    fn_sgr_print ' '
    fn_csi_print_width "$_message" $((bui_panel_col_size - 2))
    
    fn_sgr_seq_flush
}

function fn_util_clear_screen()
{
    local -i _start_row=$1

    local -i _row_idx
    local -i _last_idx=$((bui_panel_row_size - 1))

    fn_sgr_seq_start

    for((_row_idx=_start_row; _row_idx <= _last_idx; _row_idx++))
    do
        fn_util_set_cursor_pos $_row_idx 0
        fn_theme_set_attr_panel 0
        fn_csi_op $CSI_OP_COL_ERASE $bui_panel_col_size
        fn_csi_op $CSI_OP_COL_FORWARD $bui_panel_col_size
    done

    fn_sgr_seq_flush
}

function fn_util_draw_box_panel()
{
    local -i _start_row=$1
    local _msg_ref=${2:-}
    local -i _theme_attr=${3:-$THEME_SET_DEF_INACTIVE}

    local -a _msg_array=()

    if [ -n "$_msg_ref" ]
    then
        _msg_array=( "${!_msg_ref}" )
    fi

    local -i _msg_idx=0
    local -i _row_idx
    local -i _last_idx=$((bui_panel_row_size - 1))

    for((_row_idx=hmenu_row_pos + 1; _row_idx <= _last_idx; _row_idx++))
    do
        fn_sgr_seq_start

        fn_util_set_cursor_pos $_row_idx 0
        fn_theme_set_attr $_theme_attr

        if((_row_idx < _last_idx))
        then
            fn_utf8_print $BUI_CHAR_LINE_VT

            local _msg_line="${_msg_array[_msg_idx++]:-}"
            fn_csi_print_center " $_msg_line" $((bui_panel_col_size - 2))
            
            fn_utf8_print $BUI_CHAR_LINE_VT
        else
            fn_utf8_print $BUI_CHAR_LINE_BT_LT
            fn_util_print_hz_line $((bui_panel_col_size - 2))
            fn_utf8_print $BUI_CHAR_LINE_BT_RT
        fi
        fn_sgr_seq_flush
    done
}

function fn_util_print_hz_line()
{
    local -i _line_width=$1
    local _sgr_line
    local _pad_char=$BUI_CHAR_LINE_HZ

    printf -v _sgr_line '%*s' $_line_width
    printf -v _sgr_line '%b' "${_sgr_line// /${_pad_char}}"
    fn_sgr_seq_write $_sgr_line
}
