##
# BIW-HIST-CHOOSER - History Chooser Widget
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

source ${BIW_HOME}/biw-main.sh

function fn_hist_display()
{
	# Number of history entries in the list
	readonly _hist_size=30

	# truncate result file
	:> $BIW_CH_RES_FILE

	# load history into array
	mapfile -t _hist_values < <(fc -lnr -$_hist_size)

	# remove first 2 leading blanks
	local _hist_values=("${_hist_values[@]#[[:blank:]][[:blank:]]}")

	# initialize the chooser menu
	fn_choose_init _hist_values[@]

	# show the widgets
	fn_biw_show

	# get result from index
	local _result=${_hist_values[$choose_idx_active]}

	# save to temporary file
	echo $_result > $BIW_CH_RES_FILE
}

fn_hist_display
