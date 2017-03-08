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

# global widget params
declare -ri BIW_MARGIN=10
declare -ri BIW_PANEL_HEIGHT=20
declare -ri BIW_PANEL_WIDTH=60

source ${BIW_HOME}/biw-util.sh
source ${BIW_HOME}/biw-theme-mgr.sh
source ${BIW_HOME}/biw-panel-hmenu.sh
source ${BIW_HOME}/biw-panel-vmenu.sh
source ${BIW_HOME}/biw-panel-browse.sh
source ${BIW_HOME}/biw-panel-credits.sh

declare -r BIW_VERSION=0.9

# selected result when a panel is closed
declare biw_selection_result

# controllers will set this when the app should terminate
declare -i biw_terminate_app=0

function fn_biw_main()
{
    # remove any existing result file.
    rm -f $BIW_RESULT_FILE

    # show the widgets
    fn_biw_show

    if [ -n "$biw_selection_result" ]
    then
        # save to temporary file
        echo "$biw_selection_result" > $BIW_RESULT_FILE
    fi
}

function fn_biw_show()
{

    fn_utl_panel_open

    fn_theme_init

    # Entires in HMenu
    local -r BIW_MENU_HISTORY='History'
    local -r BIW_MENU_BROWSE='File'
    local -r BIW_MENU_THEME='Theme'
    local -r BIW_MENU_CREDITS='Credits'
    local -r BIW_MENU_HOTKEY='Hotkey'

    local -a _hmenu_values=(
        $BIW_MENU_HISTORY 
        $BIW_MENU_BROWSE 
        $BIW_MENU_THEME
        $BIW_MENU_HOTKEY
        $BIW_MENU_CREDITS)

    fn_hmenu_init _hmenu_values[@]

    while [ 1 ]
    do
        fn_hmenu_get_current_val '_menu_val'
        fn_hmenu_redraw
        biw_selection_result=''

        case $_menu_val in
            $BIW_MENU_HISTORY)
                fn_ctl_history_controller
                ;;
            $BIW_MENU_BROWSE)
                fn_ctl_browse_controller
                ;;
            $BIW_MENU_THEME)
                fn_ctl_cfg_theme_controller
                ;;
            $BIW_MENU_CREDITS)
                fn_ctl_credits_controller
                ;;
            $BIW_MENU_HOTKEY)
                fn_ctl_hotkey_controller
                ;;
            *)
                fn_ctl_default
                ;;
        esac

        # terminate if controller returned action ignored status
        if((biw_terminate_app))
        then
            break
        fi
    done

    fn_utl_panel_close
}

##
# Controller: Default with no panel.
##

function fn_ctl_default()
{
    local _key

    while fn_utl_process_key _key
    do
        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            biw_terminate_app=1
            break
        fi
    done
}

##
# Controller: Hotkey configuration panel.
##

function fn_ctl_hotkey_controller()
{
    local -A _bind_selections=(
        ['Arrow-Up']=$CSI_KEY_UP
        ['Arrow-Down']=$CSI_KEY_DOWN
        ['Arrow-Left']=$CSI_KEY_LEFT
        ['Arrow-Right']=$CSI_KEY_RIGHT
        ['Page-Up']=$CSI_KEY_PG_UP
        ['Page-Down']=$CSI_KEY_PG_DOWN
        ['Function-F9']=$CSI_KEY_F9
        ['Function-F10']=$CSI_KEY_F10
        ['Function-F11']=$CSI_KEY_F11
        ['Function-F12']=$CSI_KEY_F12 )

    # create a sorted list of key descriptions
    local -a _key_descr_list
    local IFS=$'\n'
    mapfile -t _key_descr_list < <(echo "${!_bind_selections[*]}" | sort)

    fn_vmenu_init _key_descr_list[@]
    fn_vmenu_set_message "Choose activation hotkey"

    fn_ctl_load_hotkey_idx
    vmenu_idx_selected=$?

    vmenu_ind_values=( [vmenu_idx_selected]=$BIW_CHAR_BULLET )
    fn_vmenu_redraw

    local _key
    while fn_utl_process_key _key
    do
        fn_vmenu_actions "$_key"

        case "$_key" in
            $CSI_KEY_ENTER|$CSI_KEY_SPC) 
                fn_ctl_save_hotkey
                fn_vmenu_redraw
                ;;
        esac
    done
}

function fn_ctl_load_hotkey_idx()
{
    # create lookups
    local -A _bind_desc_lookup=()
    local -i _bind_idx
    local -i _key_descr_size=${#_key_descr_list[@]}
    local _key_descr
    local _key_code
    for((_bind_idx=0; _bind_idx < _key_descr_size; _bind_idx++))
    do
        _key_descr="${_key_descr_list[_bind_idx]}"
        _key_code="${_bind_selections[$_key_descr]}"
        _bind_desc_lookup+=( ["$_key_code"]=$_bind_idx )
    done

    fn_settings_get_param $BIW_BIND_PARAM_NAME '_selected_bind_key' $BIW_DEFAULT_BIND_KEY

    local _selected_bind_key
    fn_settings_get_hotkey '_selected_bind_key'

    local -i _selected_bind_idx=${_bind_desc_lookup["$_selected_bind_key"]:--1}
    if((_selected_bind_idx < 0))
    then
        local -i _default_bind_idx=${_bind_desc_lookup[$BIW_DEFAULT_BIND_KEY]}
        return $_default_bind_idx
    fi

    return $_selected_bind_idx
}

function fn_ctl_save_hotkey()
{
    local _selected_bind_desc
    fn_vmenu_get_current_val '_selected_bind_desc'

    local _selected_bind_key=${_bind_selections[$_selected_bind_desc]}
    fn_settings_set_hotkey $_selected_bind_key

    # update bullet in panel
    vmenu_ind_values=( [vmenu_idx_selected]=$BIW_CHAR_BULLET )

    fn_vmenu_set_message "Hotkey saved: [${_selected_bind_desc}]=${_selected_bind_key}"
}

##
# Controller: Credits Animation panel
##

function fn_ctl_credits_controller()
{
    # change to matrix theme
    local -i _theme_idx=${theme_id_lookup[THEME_TYPE_MATRIX]}
    fn_theme_set_idx_active $_theme_idx
    fn_hmenu_redraw

    # show animation. This will block until cancelled.
    fn_cred_show

    # restore original theme
    fn_theme_load
}

##
# Controller: History selection panel
##

# max values to load for history and file lists
declare -ri BIW_LIST_MAX=50

function fn_ctl_history_controller()
{
    local _panel_command="fc -lnr -$BIW_LIST_MAX"
    local -a _values

    # read command into _values
    mapfile -t -n $BIW_LIST_MAX _values < <($_panel_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
    fn_vmenu_set_message "[ENTER] key copies to prompt"

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

        case "$_key" in
            $CSI_KEY_ENTER) 
                # we got the enter key so close the menu
                fn_vmenu_get_current_val "biw_selection_result"
                biw_terminate_app=1
                break
                ;;
        esac
    done
}

##
# Controller: Theme configuration panel.
##

function fn_ctl_cfg_theme_controller()
{
    # load theme data into menu
    fn_vmenu_init "theme_desc_lookup[@]" $theme_active_idx
    fn_vmenu_set_message "Choose default theme"
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
            $CSI_KEY_ENTER|$CSI_KEY_SPC) 
                fn_theme_save
                fn_vmenu_redraw
                ;;
        esac
    done

    fn_theme_load
}

function fn_theme_save()
{
    local _saved_theme=${THEME_LIST[$theme_active_idx]}
    vmenu_ind_values=( [theme_active_idx]=$BIW_CHAR_BULLET )

    fn_settings_set_param $THEME_PARAM_NAME $_saved_theme
    fn_vmenu_set_message "Theme saved: ${_saved_theme}"
}

# entry point
fn_biw_main
