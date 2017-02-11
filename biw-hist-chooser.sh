##
# BIW-CHOOSER - Bash Inline Widgets Scrollable Chooser
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

source 'biw-chooser.sh'

_hist_values=(opt0 opt1 opt2 opt3 opt4 opt5 opt6 opt7 opt8)
_menu_size=6

# display the menu
fn_chooser_display _hist_values[@] $_menu_size

# selected index is in the result
_result_idx=$?

# get result from index
_result=${_hist_values[$_result_idx]}

# save to temporary file
echo $_result > $HOME/.chooser_history
