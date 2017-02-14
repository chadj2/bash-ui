##
# BIW-BIND - Key binder for BIW Menus
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# file where history result will be saved
export BIW_CH_RES_FILE=$HOME/.chooser_history

function fn_choose_show()
{
	if ! ./biw-hist-chooser.sh
	then
		return 1
	fi

	READLINE_LINE=$(cat $BIW_CH_RES_FILE)
	READLINE_POINT=${#READLINE_LINE}

	rm $BIW_CH_RES_FILE
}

function fn_choose_bind()
{
	local _bind_key=$1

	# We use 2 binds here because of an issue bash has with 
	# multi-char escape sequences.
	local bind_int_char=$'"\201"'
	local bind_esc_char="\"\e${_bind_key}\""

	bind -x ${bind_int_char}:fn_choose_show
	bind ${bind_esc_char}:${bind_int_char}
}

# some keys you can bind
key_f1='OP'
key_f2='OQ'
key_f10='[21~'
key_f11='[23~'
key_f12='[24~'
key_up='[A'
key_down='[B'
key_left='[D'
key_right='[C'

fn_choose_bind $key_down
