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
source ${BIW_HOME}/biw-theme-mgr.sh
source ${BIW_HOME}/biw-panel-hmenu.sh
source ${BIW_HOME}/biw-panel-vmenu.sh
source ${BIW_HOME}/biw-panel-browse.sh
source ${BIW_HOME}/biw-panel-credits.sh
source ${BIW_HOME}/biw-panel-slider.sh

declare -r BIW_VERSION=0.9

# a controller can set a result here when it is closed.
declare biw_selection_result

function fn_biw_main()
{
    # remove any existing result file.
    rm -f $BIW_RESULT_FILE

    fn_util_panel_open
    fn_theme_init

    # show the panel
    fn_biw_controller_hmenu_top

    fn_util_panel_close

    if [ -n "$biw_selection_result" ]
    then
        # save to temporary file
        echo "$biw_selection_result" > $BIW_RESULT_FILE
    fi
}

# Entires in H-Menu
declare -r BIW_MENU_HISTORY='History'
declare -r BIW_MENU_BROWSE='File'
declare -r BIW_MENU_THEME='Theme'
declare -r BIW_MENU_HOTKEY='Hotkey'
declare -r BIW_MENU_CREDITS='Credits'
declare -r BIW_MENU_DIMENSIONS='Dims'
declare -r BIW_MENU_CONFIG='Config'
#declare -r BIW_MENU_DEFAULT='Default'

# BIW_DISPATCH_MAP: 
# This determines what controller is invoked when an H-Menu entry is 
# selected.
#
# A controller can also invoke a second-level H-Menu but regardless
# of the level, it uses this map to determine what its menu entries
# invoke.
declare -A BIW_DISPATCH_MAP=(
    [$BIW_MENU_HISTORY]=fn_biw_controller_history
    [$BIW_MENU_BROWSE]=fn_biw_controller_browse
    [$BIW_MENU_CREDITS]=fn_biw_controller_credits
    [$BIW_MENU_CONFIG]=fn_biw_controller_cfg_hmenu
    [$BIW_MENU_THEME]=fn_biw_controller_cfg_theme
    [$BIW_MENU_HOTKEY]=fn_biw_controller_cfg_hotkey
    [$BIW_MENU_DIMENSIONS]=fn_biw_controller_cfg_dims)

function fn_biw_controller_hmenu_top()
{
    local -a _top_menu=(
        $BIW_MENU_HISTORY
        $BIW_MENU_BROWSE
        $BIW_MENU_CONFIG
        $BIW_MENU_CREDITS)

    # setup the H-Menu
    fn_hmenu_init '_top_menu[@]'

    # call the main dispatcher that will invoke the 
    # appropriate controller.
    fn_util_dispatcher
}

function fn_biw_controller_cfg_hmenu()
{
    # If we are at this point then it means:
    #   1. The user selected the "Config" entry in the H-Menu.
    #   2. The dispatcher looked up the associated controller 
    #      in BIW_DISPATCH_MAP.
    #   3. The dispatcher invoked this controller and is expecting
    #      it to return when done.

    local -a _config_menu=(
        $BIW_MENU_THEME
        $BIW_MENU_DIMENSIONS
        $BIW_MENU_HOTKEY)

    # Call the dispatcher that will handle actions 
    # for a second-level menu
    fn_hmenu_controller_sub '_config_menu[@]'

    # If we are at this point and the user used a config panel then it means:
    #   1. The H-Menu controller displayed the secondary menu and 
    #      waited for the user to hit the down key.
    #   2. If the down key was hit the H-Menu controller invoked 
    #      a second level dispatcher which is a recursive call.
    #   3. The dispatcher compared selected item of the secondary H-Menu and invoked
    #      the associated controller for the panel.
    #   4. The panel controller set the util_exit_dispatcher flag and returned.
    #   5. The second level dispatcher caught the exit flag and returned.
}

##
# Controller: Hotkey configuration panel.
##

function fn_biw_controller_cfg_hotkey()
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
    fn_biw_cfg_hotkey_load
    vmenu_idx_selected=$?

    fn_vmenu_set_message "Choose activation hotkey"
    fn_vmenu_set_checked
    fn_vmenu_redraw

    local _key
    while fn_util_process_key _key
    do
        fn_vmenu_actions "$_key"

        case "$_key" in
            $CSI_KEY_ENTER|$CSI_KEY_SPC) 
                fn_biw_cfg_hotkey_save
                fn_vmenu_redraw
                ;;
        esac
    done
}

function fn_biw_cfg_hotkey_load()
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

function fn_biw_cfg_hotkey_save()
{
    local _selected_bind_desc
    fn_vmenu_get_current_val '_selected_bind_desc'

    local _selected_bind_key=${_bind_selections[$_selected_bind_desc]}
    fn_settings_set_hotkey $_selected_bind_key

    fn_vmenu_set_checked
    fn_vmenu_set_message "Hotkey saved: [${_selected_bind_desc}]=${_selected_bind_key}"
}

##
# Controller: Credits Animation panel
##

function fn_biw_controller_credits()
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

function fn_biw_controller_history()
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
    while fn_util_process_key _key
    do
        fn_vmenu_actions "$_key"

        case "$_key" in
            $CSI_KEY_ENTER) 
                # we got the enter key so close the menu
                fn_vmenu_get_current_val "biw_selection_result"
                util_exit_dispatcher=1
                break
                ;;
        esac
    done
}

##
# Controller: Theme configuration panel.
##

function fn_biw_controller_cfg_theme()
{
    # load theme data into menu
    fn_vmenu_init "theme_desc_lookup[@]" $theme_active_idx
    fn_vmenu_set_message "Choose default theme"
    fn_vmenu_set_checked
    fn_vmenu_redraw

    local _key
    while fn_util_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $UTIL_ACT_CHANGED ]
        then
            # use the vmenu index to determine the selected theme
            fn_theme_set_idx_active $vmenu_idx_selected
            fn_hmenu_redraw
            fn_vmenu_redraw
        fi

        case "$_key" in
            $CSI_KEY_ENTER|$CSI_KEY_SPC) 
                fn_biw_cfg_theme_save
                fn_vmenu_redraw
                ;;
        esac
    done

    fn_theme_load
}

function fn_biw_cfg_theme_save()
{
    local _saved_theme=${THEME_LIST[$theme_active_idx]}
    fn_settings_set_param $THEME_PARAM_NAME $_saved_theme

    fn_vmenu_set_checked
    fn_vmenu_set_message "Theme saved: ${_saved_theme}"
}

##
# Controller: Dimensions Configuration
##

declare -i biw_dims_save_pending

function fn_biw_controller_cfg_dims()
{
    biw_dims_save_pending=0

    declare -a slider_ctl_width=(
        [$SLIDER_CTL_ATTR_LABEL]='Width'
        [$SLIDER_CTL_ATTR_MIN]=40
        [$SLIDER_CTL_ATTR_MAX]=80
        [$SLIDER_CTL_ATTR_VAL]=$biw_panel_col_size
        )

    declare -a slider_ctl_height=(
        [$SLIDER_CTL_ATTR_LABEL]='Height'
        [$SLIDER_CTL_ATTR_MIN]=8
        [$SLIDER_CTL_ATTR_MAX]=40
        [$SLIDER_CTL_ATTR_VAL]=$biw_panel_row_size
        )

    local -a _slider_list=(
        slider_ctl_width
        slider_ctl_height )

    fn_slider_init '_slider_list[@]'
    fn_slider_redraw
    fn_util_draw_footer 'Set Panel Dimensions'

    local _key

    # we add a condition to fn_util_process_key so that it enable the hmenu
    # only when no slider controls are active.
    while fn_util_process_key _key '' $((slider_ctl_selected_idx >= 0))
    do
        fn_slider_actions "$_key"
        if [ $? == $UTIL_ACT_CHANGED ]
        then
            # action handled so get next key
            if((!biw_dims_save_pending))
            then
                fn_util_draw_footer 'Hit [Enter] or [Space] to save; [ESC] to cancel.'
                biw_dims_save_pending=1
            fi
            continue
        fi

        case "$_key" in
            $CSI_KEY_ENTER|$CSI_KEY_SPC)
                fn_biw_cfg_dims_save
                ;;
        esac
    done
}

function fn_biw_cfg_dims_save()
{
    if((!biw_dims_save_pending))
    then
        return
    fi

    local -i _rows=${slider_ctl_height[$SLIDER_CTL_ATTR_VAL]}
    local -i _cols=${slider_ctl_width[$SLIDER_CTL_ATTR_VAL]}

    fn_util_panel_set_dims $_rows $_cols

    fn_slider_redraw
    fn_util_draw_footer 'Changes saved to settings file.'
    
    biw_dims_save_pending=0
}

# entry point
fn_biw_main
