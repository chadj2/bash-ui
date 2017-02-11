##
# BIW-CHOOSER - Bash Inline Widgets Scrollable Chooser
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

source 'biw-util.sh'

function fn_chooser_top()
{
	# position the cursor at the start of the menu
	fn_esc $esc_restore_cursor
	fn_csi $csi_row_up $((_menu_size))
}

function fn_chooser_line()
{
	local _idx=$1
	local _name=${_menu_entries[$_idx]}

	# calculate colors
	local _panel_color=$menu_color_nsel
	local _slider_color=$menu_color_slider_bar

	if ((_menu_idx_active == _idx))
	then
		_panel_color=$menu_color_sel
		_slider_color=$menu_color_handle
	fi

	# calculate characters
	local _last_char=$decg_hz_line
	local _first_char=$decg_bullet

	if ((_idx == _menu_idx_start))
	then
		# Top charachter
		if ((_idx == 0))
		then
			_last_char=$decg_t_top
		else
			_last_char='^'
		fi
	elif ((_idx == _menu_idx_end))
	then
		# Bottom Charachter
		if ((_idx == _menu_idx_last))
		then
			_last_char=$decg_t_bottom
		else
			_last_char='v'
		fi
	fi

	# draw menu text
	fn_csi $csi_col_pos $menu_margin
	fn_csi $csi_set_color $((color_fg + menu_color_text))

	fn_csi $csi_set_color $((color_bg + _panel_color))
	printf "${_first_char}"
	printf "%-${menu_width}s" $_name
	
	fn_csi $csi_set_color $((color_bg + _slider_color))
	printf "${_last_char}"

	# reset colors
	fn_csi $csi_set_color 0
}

function fn_chooser_redraw()
{
	# move to the top of where we will draw the menu
	fn_chooser_top

	# calculate indexes to draw
	local _indexes=$(eval echo {$_menu_idx_start..$_menu_idx_end})
	#echo -n "{$_menu_idx_start..$_menu_idx_end}"

	# draw all menu items
	for _idx in ${_indexes}
	do
		fn_chooser_line $_idx
		fn_csi $csi_row_down 1
	done

	# set the cursor after the active item
	fn_csi $csi_row_up $((_menu_idx_end - _menu_idx_active + 1))
}

function fn_animate_wait()
{
	# we use read insted of sleep because it is in-process
	read -sn1 -t 0.02
}

function fn_chooser_init()
{
	# menu state
	_menu_data_size=${#_menu_entries[*]}
	_menu_size=$_menu_data_size
	if ((_menu_size > _menu_size_max))
	then
		_menu_size=$_menu_size_max
	fi

	_menu_idx_start=$_menu_idx_active
	_menu_idx_end=$((_menu_size + _menu_idx_start - 1))
	_menu_idx_last=$((_menu_data_size - 1))

	# make sure we call menu close during terminate to restore terminal settings
	trap "fn_chooser_close; exit 1" SIGHUP SIGINT SIGTERM

	# disable echo during redraw or else quickly repeated arrow keys
	# could move the cursor
	stty -echo

	# hide the cursor to eliminate flicker
	fn_csi $csi_cursor_hide

	# save the cursor for a "home position"
	fn_esc $esc_save_cursor

	# animate open
	for _idx in $(eval echo {1..$_menu_size})
	do
		fn_csi $csi_row_up 1
		fn_csi $csi_scroll_up 1
		fn_csi $csi_row_insert 1
		fn_animate_wait
	done

	# non-animated insert:
	#fn_csi $csi_scroll_up $_menu_size
	#fn_chooser_top
	#fn_csi $csi_row_insert $_menu_size

	# draw entire menu
	fn_chooser_redraw

	# activate current menu line
	fn_chooser_line $_menu_idx_active
}

function fn_chooser_close()
{
	# goto home position
	fn_chooser_top

	# non-animate close:
	#fn_csi $csi_row_delete $_menu_size
	#fn_csi $csi_scroll_down $_menu_size

	# animate close
	for _idx in $(eval echo {1..$_menu_size})
	do
		fn_csi $csi_row_delete 1
		fn_csi $csi_scroll_down 1
		fn_csi $csi_row_down 1
		fn_animate_wait
	done

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

function fn_chooser_down()
{
	if ((_menu_idx_active >= _menu_idx_last))
	then
		# we are at the end of the data so we can't move
		return
	fi

	((_menu_idx_active += 1))

	if ((_menu_idx_active > _menu_idx_end))
	then
		# new index has exceeded the bounds of the window
		# so we need to move the window and redraw
		_menu_idx_end=$_menu_idx_active
		_menu_idx_start=$((_menu_idx_end - _menu_size + 1))
		fn_chooser_redraw
		return
	fi

	# new index is inside the current window and so we just
	# move the active menu item
	fn_chooser_line $((_menu_idx_active - 1))
	fn_csi $csi_row_down 1
	fn_chooser_line $_menu_idx_active
}

function fn_chooser_up()
{
	if ((_menu_idx_active <= 0))
	then
		# we are at the start of the data so we can't move
		return
	fi

	((_menu_idx_active -= 1))

	if ((_menu_idx_active < _menu_idx_start))
	then
		# new index has exceeded the bounds of the window
		# so we need to move the window and redraw
		_menu_idx_start=$_menu_idx_active
		_menu_idx_end=$((_menu_size + _menu_idx_start - 1))
		fn_chooser_redraw
		return
	fi

	# new index is inside the current window and so we just
	# move the active menu item
	fn_chooser_line $((_menu_idx_active + 1))
	fn_csi $csi_row_up 1
	fn_chooser_line $_menu_idx_active
}

function fn_chooser_display()
{
	# initial active entry
	local _menu_idx_active=0

	# get refrence to array with menu entries
	local _menu_entries=("${!1}")

	# menu size with default
	local _menu_size_max=${2:-5}

	# colors
	local menu_color_text=$color_black
	local menu_color_sel=$color_red
	local menu_color_nsel=$color_blue
	local menu_color_slider_bar=$color_cyan
	local menu_color_handle=$color_yellow

	# width of displayed menu
	local menu_width=30

	# left margin
	local menu_margin=10

	fn_chooser_init

	local _key
	while fn_read_key "_key"
	do
		case $_key in
			'[A')
				fn_chooser_up
				;;
			'[B')
				fn_chooser_down
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

	fn_chooser_close

	return $_menu_idx_active
}
