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

source ${BIW_HOME}/biw-util.sh
source ${BIW_HOME}/biw-term-sgr.sh
source ${BIW_HOME}/biw-term-csi.sh
source ${BIW_HOME}/biw-theme-mgr.sh
source ${BIW_HOME}/biw-term-utf8.sh
source ${BIW_HOME}/biw-panel-hmenu.sh
source ${BIW_HOME}/biw-panel-vmenu.sh
source ${BIW_HOME}/biw-panel-credits.sh

declare -r BIW_VERSION=0.9

# Entires in HMenu
declare -r BIW_MENU_HISTORY='History'
declare -r BIW_MENU_BROWSE='File'
declare -r BIW_MENU_THEME='Theme'
declare -r BIW_MENU_CREDITS='Credits'
declare -r BIW_MENU_CONFIG='Config'

# selected result when a panel is closed
declare biw_selection_result

# max values to load for history and file lists
declare -ri BIW_LIST_MAX=50

# max number of files to populate in file browser
declare -ir BIW_BROWSE_MAX_FILES=50

# used so we can generate a relative path
declare -r BIW_ORIG_PWD=$PWD

function fn_biw_main()
{
    # truncate result file
    :> $BIW_CH_RES_FILE

    local -a _hmenu_values=(
        $BIW_MENU_HISTORY 
        $BIW_MENU_BROWSE 
        $BIW_MENU_THEME
        $BIW_MENU_CONFIG
        $BIW_MENU_CREDITS)

    fn_hmenu_init _hmenu_values[@]

    fn_theme_init

    # show the widgets
    fn_biw_show

    # save to temporary file
    echo $biw_selection_result > $BIW_CH_RES_FILE
}

function fn_biw_show()
{
    local -r _history_cmd="fc -lnr -$BIW_LIST_MAX"


    fn_utl_panel_open

    while [ 1 ]
    do
        fn_hmenu_get_current_val '_menu_val'
        fn_hmenu_redraw
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
            *)
                fn_ctl_default
                ;;
        esac

        # exit if controller returned action ignored status
        if [ $? == $UTL_ACT_IGNORED ]
        then
            break
        fi
    done

    fn_utl_panel_close
}

# this is used when we add a menu entry which has no controller
function fn_ctl_default()
{
    local _key

    while fn_utl_process_key _key
    do
        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            # exit application
            return $UTL_ACT_IGNORED
        fi
    done

    # return changed action status so we don't exit
    return $UTL_ACT_CHANGED
}

function fn_ctl_credits_controller()
{
    # change to matrix theme
    fn_theme_idx_from_name THEME_TYPE_MATRIX
    local -i _theme_idx=$?
    fn_theme_set_idx_active $_theme_idx
    fn_hmenu_redraw

    # show animation. This will block until cancelled.
    fn_cred_show

    # restore original theme
    fn_theme_set_idx_active $theme_saved_idx

    return $UTL_ACT_CHANGED
}

function fn_ctl_list_controller()
{
    local _panel_command=$1
    local -a _values

    # read command into _values
    mapfile -t -n $BIW_LIST_MAX _values < <($_panel_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
    fn_vmenu_redraw

    local _key
    while fn_utl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $UTL_ACT_CHANGED ]
        then
            # vmenu handled the action so get next key
            continue
        fi

        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            # we got the enter key so close the menu
            fn_vmenu_get_current_val "biw_selection_result"
            return $UTL_ACT_IGNORED
        fi
    done

    return $UTL_ACT_CHANGED
}

function fn_ctl_theme_controller()
{
    # load theme data into menu
    fn_vmenu_init "theme_name_list[@]" $theme_active_idx
    vmenu_ind_values=( [theme_active_idx]=$BIW_CHAR_BULLET )
    fn_vmenu_redraw

    local _key
    while fn_utl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $UTL_ACT_CHANGED ]
        then
            # use the vmenu index to determine the selected theme
            fn_theme_set_idx_active $vmenu_idx_selected
            fn_hmenu_redraw
            fn_vmenu_redraw
        fi

        case "$_key" in
            $CSI_KEY_ENTER) 
                # Save selected Theme
                fn_theme_save

                # update checkbox
                vmenu_ind_values=( [theme_active_idx]=$BIW_CHAR_BULLET )
                fn_vmenu_redraw
                ;;
        esac
    done

    fn_theme_set_idx_active $theme_saved_idx
    return $UTL_ACT_CHANGED
}

function fn_ctl_browse_controller()
{
    fn_ctl_browse_update

    local _key
    while fn_utl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $UTL_ACT_CHANGED ]
        then
            # vmenu handled the action so get next key
            continue
        fi

        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            # enter key was hit so update the screen
            fn_ctl_browse_select

            if [ $? == 1 ]
            then
                # user selected a file so exit program
                return $UTL_ACT_IGNORED
            fi

            continue
        fi
    done

    return $UTL_ACT_CHANGED
}

function fn_ctl_browse_select()
{
    local _selected_file
    fn_vmenu_get_current_val '_selected_file'

    if [ ! -d "$_selected_file" ]
    then
        # we got the enter key so close the menu
        local _rel_dir
        fn_utl_get_relpath '_rel_dir' "$BIW_ORIG_PWD" "$PWD"
        biw_selection_result="${_rel_dir}/${_selected_file}"
        return 1
    fi

    if [ ! -x "$_selected_file" ]
    then    
        fn_vmenu_set_message "ERROR: Directory permission denied."
        fn_vmenu_redraw
        return 0
    fi

    # change real directories
    cd "$_selected_file" || fn_utl_die "Failed to change directory: $PWD"

    # update panel with new directory
    fn_ctl_browse_update

    return 0
}

function fn_ctl_browse_update()
{
    # fetch files
    local -a _ls_output
    local -r _ls_command="/bin/ls -a -p -1"

    # read ls command results into an array
    mapfile -n$BIW_BROWSE_MAX_FILES -s1 -t _ls_output < <($_ls_command)

    local -a _file_list=()
    local -a _file_list_ind=()
    local -a _dir_list=()
    local -a _dir_list_ind=()

    local -i _file_idx
    local _file

    for((_file_idx=0; _file_idx < ${#_ls_output[@]}; _file_idx++))
    do
        _file=${_ls_output[_file_idx]}

        if [[ "$_file" =~ ^(.*)/$ ]]
        then
            _dir_list+=( "$_file" )

            if [ ! -x "$_file" ]
            then
                _dir_list_ind+=( $BIW_CHAR_DBL_EXCL )
            elif [ "$_file" == '../' ]
            then
                _dir_list_ind+=( $BIW_CHAR_TRIANGLE_LT )
            else 
                _dir_list_ind+=( $BIW_CHAR_TRIANGLE_RT )
            fi
        else
            _file_list+=( "$_file" )
            _file_list_ind+=( $BIW_CHAR_BULLET )
        fi
    done

    local -a _dir_view=( "${_dir_list[@]}" )

    if [ ${#_file_list[@]} != 0 ]
    then
        _dir_view+=( "${_file_list[@]}" )
    fi

    local _rel_dir
    fn_utl_get_relpath '_rel_dir' "$BIW_ORIG_PWD" "$PWD"

    fn_vmenu_init _dir_view[@]
    vmenu_ind_values=( "${_dir_list_ind[@]}" "${_file_list_ind[@]:-}" )
    fn_vmenu_set_message "PWD [${_rel_dir}]"
    
    fn_vmenu_redraw
}

# entry point
fn_biw_main
