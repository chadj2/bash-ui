##
# BIW-TERMINAL - BIW Terminal Control
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# ESC op codes used with fn_esc
readonly esc_save_cursor='7'
readonly esc_restore_cursor='8'

# CSI op codes used with fn_csi
readonly csi_scroll_up='S'
readonly csi_scroll_down='T'
readonly csi_row_insert='L'
readonly csi_row_delete='M'
readonly csi_row_up='A'
readonly csi_row_down='B'
readonly csi_row_erase='K'
readonly csi_col_pos='G'
readonly csi_set_color='m'
readonly csi_cursor_hide='?25l'
readonly csi_cursor_show='?25h'

readonly sgr_bold=1
readonly sgr_underline=4
readonly sgr_invert=7

# color codes
readonly sgr_color_fg=30
readonly sgr_color_bg=40
readonly sgr_color_bright=60
readonly sgr_color_black=0
readonly sgr_color_red=1
readonly sgr_color_green=2
readonly sgr_color_yellow=3
readonly sgr_color_blue=4
readonly sgr_color_magenta=5
readonly sgr_color_cyan=6
readonly sgr_color_white=7

# codes for DEC graphics charset
readonly decg_hz_line='\e(0\x78\e(B'
readonly decg_t_top='\e(0\x77\e(B'
readonly decg_t_bottom='\e(0\x76\e(B'
readonly decg_block='\e(0\xe1\e(B'

# input keys
readonly key_up='[A'
readonly key_down='[B'
readonly key_left='[D'
readonly key_right='[C'

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

function fn_animate_wait()
{
	# we use read insted of sleep because it is in-process
	local -r _animate_delay=0.015
	read -sn1 -t $_animate_delay
}