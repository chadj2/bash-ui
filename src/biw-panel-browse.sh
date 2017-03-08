
##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-panel-browse.sh
# Description:  File browser panel.
##

# used so we can generate a relative path
declare -r BIW_ORIG_PWD=$PWD

# max number of files to populate in file browser
declare -ir BIW_BROWSE_MAX_FILES=50

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
                # exit app
                biw_terminate_app=1
                break
            fi
        fi
    done
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
