##
# BIW-MAIN - Bash Inline Widgets
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# event types
readonly biw_event_show=0
readonly biw_event_up=1
readonly biw_event_down=2

# function error_exit {
#     echo "Got ERR signal from: <$BASH_COMMAND> (${FUNCNAME[1]}:${BASH_LINENO[0]})"
#     return
# }

# trap "error_exit 'Received signal ERR'" ERR

# generate errors if unset vars are used.
set -o nounset

source ${BIW_HOME}/biw-terminal.sh
source ${BIW_HOME}/biw-chooser.sh

function fn_biw_show()
{
	local _active_focus=fn_choose_router

	# state variables
	local -i _choose_idx_start
	local -i _choose_idx_end

	fn_biw_open
	$_active_focus $biw_event_show

	local _key
	while fn_read_key "_key"
	do
		case $_key in
			'[A')
				$_active_focus $biw_event_up
				;;
			'[B')
				$_active_focus $biw_event_down
				;;
			'') 
				# enter key hit
				break
				;;
			*)
				# do nothing
				;;
		esac
	done

	fn_biw_close
}

function fn_biw_open()
{
	# make sure we call menu close during terminate to restore terminal settings
	trap "fn_biw_close; exit 1" SIGHUP SIGINT SIGTERM

	# disable echo during redraw or else quickly repeated arrow keys
	# could move the cursor
	stty -echo

	# hide the cursor to eliminate flicker
	fn_csi $csi_cursor_hide

	# save the cursor for a "home position"
	fn_esc $esc_save_cursor

	# animate open
	for _line_idx in $(eval echo {1..$choose_height})
	do
		fn_csi $csi_row_up 1
		fn_csi $csi_scroll_up 1
		fn_csi $csi_row_insert 1
		fn_animate_wait
	done

	# non-animated open:
	#fn_csi $csi_scroll_up $choose_height
	#fn_choose_cursor_home
	#fn_csi $csi_row_insert $choose_height
}

function fn_biw_close()
{
	# goto home position
	fn_choose_cursor_home

	# animate close
	for _line_idx in $(eval echo {1..$choose_height})
	do
		fn_csi $csi_row_delete 1
		fn_csi $csi_scroll_down 1
		fn_csi $csi_row_down 1
		fn_animate_wait
	done

	# non-animate close:
	#fn_csi $csi_row_delete $choose_height
	#fn_csi $csi_scroll_down $choose_height

	# restore original cursor position
	fn_esc $esc_restore_cursor

	# restore terminal settings
	fn_csi $csi_cursor_show

	# restore terminal settings
	#commenting this out because bash does not like it
	#stty echo

	# remove signal handler
	trap - SIGHUP SIGINT SIGTERM
}
