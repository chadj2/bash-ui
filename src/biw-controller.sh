##
##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-controller.sh
# Description:  Controller functions for panels
##

# returned by actions to indicate if the menu contents changed. 
declare -ri CTL_ACT_IGNORED=1
declare -ri CTL_ACT_CHANGED=0

# max values to load for history and file lists
declare -ri CTL_LIST_MAX=50

# max number of files to populate in file browser
declare -ir CTL_BROWSE_MAX_FILES=50

# used so we can generate a relative path
declare -r CTL_ORIG_PWD=$PWD

function fn_ctl_theme_set_default()
{
    fn_theme_set_idx_active $theme_saved_idx
    fn_hmenu_redraw
}

function fn_ctl_process_key()
{
    local _key_ref=$1
    local _timeout=${2:-''}

    # don't print debug if we are animating something 
    if [ -z "$_timeout" ]
    then
        fn_biw_debug_print
    fi

    if ! fn_csi_read_key $_key_ref $_timeout
    then
        # got timeout
        return 0
    fi

    fn_biw_debug_msg "_key=<%s>" "${!_key_ref}"

    fn_hmenu_actions "${!_key_ref}"
    if [ $? == $CTL_ACT_CHANGED ]
    then
        # hmenu was changed so panel is being switched
        # return 1 so the controller will exit
        return 1
    fi
    
    # return 0 so the loop will continue
    return 0
}

function fn_ctl_credits_controller()
{
    # change to matrix theme
    fn_theme_idx_from_name THEME_TYPE_MATRIX
    local -i _theme_idx=$?
    fn_theme_set_idx_active $_theme_idx

    fn_hmenu_redraw

    # show animation
    fn_cred_show
    if [ $? == 0 ]
    then
        # if redraw terminated normally then wait for user input
        local _key
        while fn_ctl_process_key _key
        do
            # ignore all input not from hmenu
            echo -n
        done
    fi

    fn_ctl_theme_set_default

    return 0
}

function fn_ctl_list_controller()
{
    local _panel_command=$1
    local -a _values

    fn_ctl_theme_set_default

    # read command into _values
    mapfile -t -n $CTL_LIST_MAX _values < <($_panel_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
    fn_vmenu_redraw

    local _key
    while fn_ctl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $CTL_ACT_CHANGED ]
        then
            continue
        fi

        if [ "$_key" == $CSI_KEY_ENTER ]
        then
            # we got the enter key so close the menu
            fn_vmenu_get_current_val "biw_selection_result"
            return 1
        fi
    done

    return 0
}

function fn_ctl_theme_controller()
{
    # load theme data into menu
    fn_vmenu_init "theme_name_list[@]" $theme_active_idx
    vmenu_ind_values=( [theme_active_idx]=$BIW_CHAR_BULLET )
    fn_vmenu_redraw

    local _key
    while fn_ctl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $CTL_ACT_CHANGED ]
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

    return 0
}

function fn_ctl_browse_controller()
{
    fn_ctl_theme_set_default

    fn_ctl_browse_update

    local _key
    while fn_ctl_process_key _key
    do
        fn_vmenu_actions "$_key"
        if [ $? == $CTL_ACT_CHANGED ]
        then
            continue
        fi

        if [ "$_key" == $CSI_KEY_ENTER ]
        then
        	fn_ctl_browse_select || return 1
            continue
        fi
    done

    return 0
}

function fn_ctl_browse_select()
{
    local _selected_file
    fn_vmenu_get_current_val '_selected_file'

    if [ ! -d "$_selected_file" ]
    then
        # we got the enter key so close the menu
    	local _rel_dir
        fn_ctl_get_relpath '_rel_dir' "$CTL_ORIG_PWD" "$PWD"
        biw_selection_result="${_rel_dir}/${_selected_file}"
        return 1
    fi

	# change real directories
    cd "$_selected_file" || exit 1

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
    mapfile -n$CTL_BROWSE_MAX_FILES -s1 -t _ls_output < <($_ls_command)

    local -a _file_list=()
    local -a _file_list_ind=()
    local -a _dir_list=()
    local -a _dir_list_ind=()

    local -i _file_idx
    local _file

    for((_file_idx=0; _file_idx < ${#_ls_output[@]}; _file_idx++))
    do
        _file=${_ls_output[_file_idx]}

        if [ "$_file" == '../' ]
        then
            _dir_list+=( "$_file" )
            _dir_list_ind+=( $BIW_CHAR_TRIANGLE_LT )
        elif [[ "$_file" =~ ^(.*)/$ ]]
        then
            _dir_list+=( "$_file" )
            _dir_list_ind+=( $BIW_CHAR_TRIANGLE_RT )
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

    fn_vmenu_init _dir_view[@]
    vmenu_ind_values=( "${_dir_list_ind[@]}" "${_file_list_ind[@]:-}" )

    fn_vmenu_redraw
}

# Return relative path from canonical absolute dir path $1 to canonical
# absolute dir path $2 ($1 and/or $2 may end with one or no "/").
# Does only need POSIX shell builtins (no external command)
# source: http://stackoverflow.com/a/18898782/4316647
function fn_ctl_get_relpath() 
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
