##
# BIW-HIST-CHOOSER - History Chooser Widget
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

source 'biw-chooser.sh'

# Number of history entries in the list
declare -r _hist_size=30

# size of chooser
declare -r _choose_size_set=6

# truncate result file
:> $BIW_CH_RES_FILE

# load history into array
mapfile -t _hist_values < <(fc -lnr -$_hist_size)

# remove first 2 leading blanks
_hist_values=("${_hist_values[@]#[[:blank:]][[:blank:]]}")

# display the menu
fn_choose_display _hist_values[@] $_choose_size_set

# selected index is in the result
_result_idx=$?

# get result from index
_result=${_hist_values[$_result_idx]}

# save to temporary file
echo $_result > $BIW_CH_RES_FILE
