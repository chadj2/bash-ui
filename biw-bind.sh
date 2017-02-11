##
# BIW-BIND - Key binder for BIW Menus
# 
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

function fn_show_chooser()
{
	./biw-hist-chooser.sh
	READLINE_LINE=$(cat $HOME/.chooser_history)
	READLINE_POINT=${#READLINE_LINE}
}

function fn_bind_chooser()
{
	local _bind_key=$1

	# We use 2 binds here because of an issue bash has with 
	# multi-char escape sequences.
	local bind_int_char=$'"\201"'
	local bind_esc_char="\"\e${key_f1}\""

	bind -x ${bind_int_char}:fn_show_chooser
	bind ${bind_esc_char}:${bind_int_char}
}

key_f1='OP'
key_f2='OQ'
key_f10='21~'
key_f11='23~'
key_f12='24~'

fn_bind_chooser $key_f1
