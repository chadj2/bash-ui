##
# BIW-UTIL - Bash Inline Widgets Utilities
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# ESC op codes used with fn_esc
esc_save_cursor='7'
esc_restore_cursor='8'

# CSI op codes used with fn_csi
csi_scroll_up='S'
csi_scroll_down='T'
csi_row_insert='L'
csi_row_delete='M'
csi_row_up='A'
csi_row_down='B'
csi_row_erase='K'
csi_col_pos='G'
csi_set_color='m'
csi_cursor_hide='?25l'
csi_cursor_show='?25h'

# codes for DEC graphics charset
decg_hz_line='\e(0\x78\e(B'
decg_t_top='\e(0\x77\e(B'
decg_t_bottom='\e(0\x76\e(B'
decg_bullet='\e(0\x60\e(B'
decg_block='\e(0\xe1\e(B'

# color codes
color_fg=30
color_bg=40
color_bright=60
color_black=0
color_red=1
color_green=2
color_yellow=3
color_blue=4
color_magenta=5
color_cyan=6
color_white=7

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
	local _param=$2

	# send CSI command to terminal
	echo -en "\e[${_param}${_op}"
}

function fn_read_key()
{
	local _result_var=$1
	local _read_result

	# read character
	read -sN1 _read_result

	# check for escape char
	if [[ $_read_result == $'\x1b' ]]
	then
		# read the rest of the escape code
		read -t 0.1 -sN2 _read_result
	fi

	# set result
	eval $_result_var=$_read_result
}
