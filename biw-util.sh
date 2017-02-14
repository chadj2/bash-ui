##
# BIW-UTIL - Bash Inline Widgets Utilities
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# ESC op codes used with fn_esc
declare -r esc_save_cursor='7'
declare -r esc_restore_cursor='8'

# CSI op codes used with fn_csi
declare -r csi_scroll_up='S'
declare -r csi_scroll_down='T'
declare -r csi_row_insert='L'
declare -r csi_row_delete='M'
declare -r csi_row_up='A'
declare -r csi_row_down='B'
declare -r csi_row_erase='K'
declare -r csi_col_pos='G'
declare -r csi_set_color='m'
declare -r csi_cursor_hide='?25l'
declare -r csi_cursor_show='?25h'

# color codes
declare -ir color_fg=30
declare -ir color_bg=40
declare -ir color_bright=60
declare -ir color_black=0
declare -ir color_red=1
declare -ir color_green=2
declare -ir color_yellow=3
declare -ir color_blue=4
declare -ir color_magenta=5
declare -ir color_cyan=6
declare -ir color_white=7

# generate errors if unset vars are used.
set -o nounset

# function error_exit {
#     echo "Got ERR signal from: <$BASH_COMMAND> (${FUNCNAME[1]}:${BASH_LINENO[0]})"
#     return
# }

# trap "error_exit 'Received signal ERR'" ERR

function fn_esc()
{
	local _op=$1

	# send ESC command to terminal
	echo -en "\e${_op}"
}

function fn_csi()
{
	local _op=$1

	# default to empty if not set
	local _param=${2:-''}

	# send CSI command to terminal
	echo -en "\e[${_param}${_op}"
}

function fn_animate_wait()
{
	# we use read insted of sleep because it is in-process
	local -r _animate_delay=0.02
	read -sn1 -t $_animate_delay
}

function fn_read_key()
{
	local -r _result_var=$1
	local _read_result

	# read character
	read -sN1 _read_result

	# default to empty of not set
	_read_result=${_read_result:-''}

	# check for escape char
	if [[ $_read_result == $'\x1b' ]]
	then
		# read the rest of the escape code
		read -t 0.1 -sN2 _read_result
	fi

	# set result
	eval $_result_var=$_read_result
}
