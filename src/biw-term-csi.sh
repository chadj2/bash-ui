##
# BIW-TOOLS - Bash Inline Widget Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         biw-term-csi.sh
# Description:  Send terminal control CSI sequences to manipulate the cursor.
##

# key codes returned by fn_csi_read_key
declare -r CSI_KEY_UP='[A'
declare -r CSI_KEY_DOWN='[B'
declare -r CSI_KEY_LEFT='[D'
declare -r CSI_KEY_RIGHT='[C'
declare -r CSI_KEY_PG_UP='[5'
declare -r CSI_KEY_PG_DOWN='[6'
declare -r CSI_KEY_HOME='[H'
declare -r CSI_KEY_END='[F'
declare -r CSI_KEY_F9='[20~'
declare -r CSI_KEY_F10='[21~'
declare -r CSI_KEY_F11='[23~'
declare -r CSI_KEY_F12='[24~'
declare -r CSI_KEY_ENTER='NL'
declare -r CSI_KEY_SPC='SP'
declare -r CSI_KEY_ESC='ESC'

# CSI op codes used with fn_csi_op
declare -r CSI_OP_SCROLL_UP='S'
declare -r CSI_OP_SCROLL_DOWN='T'
declare -r CSI_OP_ROW_INSERT='L'
declare -r CSI_OP_ROW_DELETE='M'
declare -r CSI_OP_ROW_UP='A'
declare -r CSI_OP_ROW_DOWN='B'
declare -r CSI_OP_ROW_ERASE='K'
declare -r CSI_OP_COL_POS='G'
declare -r CSI_OP_COL_BACK='D'
declare -r CSI_OP_COL_FORWARD='C'
declare -r CSI_OP_COL_INSERT='@'
declare -r CSI_OP_COL_ERASE='X'
declare -r CSI_OP_GET_POSITION='6n'
declare -r CSI_OP_SET_SCROLL='r'
declare -r CSI_OP_SOFT_RESET='!p'
declare -r CSI_OP_CLEAR_TABS='3g'
declare -r CSI_OP_CURSOR_HIDE='?25l'
declare -r CSI_OP_CURSOR_SHOW='?25h'
declare -r CSI_OP_CURSOR_SAVE='?1048h'
declare -r CSI_OP_CURSOR_RESTORE='?1048l'

# cached position of the curor after restore
declare -i sgr_cache_row_pos

# This controls how long we wait for ESC codes to arrive.
declare -r CSI_READ_ESC_TIMEOUT=0.1

# execute a CSI command
function fn_csi_op()
{
    local _op=$1
    local _param=${2:-''}

    # Executre a CSI termial command
    local _cmd="\e[${_param}${_op}"
    fn_sgr_seq_write "$_cmd"
}


function fn_csi_read_key()
{
    local -r _result_ref=$1
    local _timeout=${2:-''}

    local _timeout_opt=''
    if [ -n "$_timeout" ]
    then
        _timeout_opt="-t${_timeout}"
    fi

    # change IFS so newline can be read
    local IFS=

    # read first character with potentially no timeout.
    # This is where the call will wait for user input.
    if ! read $_timeout_opt -s -r -N1 $_result_ref
    then
        printf -v $_result_ref '%s' "TIMEOUT"
        return 1
    fi

    case "${!_result_ref}" in
        $'\n') 
            # enter key
            printf -v $_result_ref '%s' $CSI_KEY_ENTER
            ;;
        ' ')
            # spacebar
            printf -v $_result_ref '%s' $CSI_KEY_SPC
            ;;
        $'\e')
            # read the rest of the ESC code
            fn_csi_read_esc $_result_ref
            ;;
        *)
            # not a supported key
            printf -v $_result_ref '%s' "BAD_KEY"
            return 1
            ;;
    esac

    return 0
}

fn_csi_read_esc()
{
    local -r _result_ref=$1

    # check for ESC. 
    if ! fn_csi_read_char $_result_ref
    then
        # just a plain ESC
        printf -v $_result_ref $CSI_KEY_ESC
        return 0
    fi

    # at this point we should have a code
    if [ "${!_result_ref}" != '[' ]
    then
        printf -v $_result_ref '%s' "BAD_ESC"
        return 1
    fi

    # If we have an escape char then we check for a 2 byte 
    # code like KEY_UP='[A'.
    fn_csi_read_char $_result_ref
    if [[ "${!_result_ref}" == [[:alpha:]] ]]
    then
        # this is a 3 byte alpha code
        printf -v $_result_ref '[%s' "${!_result_ref}"
        return 0
    fi

    # If did not get an alpha character then we assume this is a 
    # numeric code like KEY_PG_DOWN='\e[6~'.
    local _numeric_code
    fn_csi_read_delim '_numeric_code' '~'

    printf -v $_result_ref '[%s' "${!_result_ref}${_numeric_code}"
    return 0
}

function fn_csi_milli_wait()
{
    local -r _animate_delay=$1
    
    # we use read insted of sleep because it is a 
    # bash builtin and sleep would be too slow
    read -s -N0 -t$_animate_delay
}

function fn_csi_get_row_pos()
{
    local _row_ref=$1

    # Here we request a DSR that will return the position 
    # of the row/column as: '\e[<row>;<col>R'
    fn_csi_op $CSI_OP_GET_POSITION

    local _read_temp

    # wait up to 0.5 seconds for the response
    fn_csi_read_delim '_read_temp' '[' 0.5
    if [ "$_read_temp" != $'\e' ]
    then
        return 1
    fi

    # read the row
    fn_csi_read_delim '_read_temp' ';'

    # Bug: If there are lots of keypresses we could get an ESC code for 
    # the key before we get the DSR response. 
    # Fix: Need to remove any leading ESC code that is recieved back.
    if ! printf -v $_row_ref '%d' "$_read_temp"
    then
        # format output as quoted
        printf -v _read_temp '%q' "$_read_temp"
        fn_utl_die "Terminal sent garbled response to DSR: ${_read_temp}"
    fi

    # read the column position. We don't use this.
    fn_csi_read_delim '_read_temp' 'R'
}

function fn_csi_scroll_region()
{
    local -i _start_row=$1
    local -i _region_height=$2
    local -i _direction=$3

    # set the scrolling bounds
    local -i _abs_top=$((sgr_cache_row_pos - BIW_PANEL_HEIGHT + _start_row))
    local -i _abs_bottom=$((_abs_top + _region_height - 1))

    # set the scrolling bounds
    fn_csi_op $CSI_OP_SET_SCROLL "${_abs_top};${_abs_bottom}"

    # Set default attributes because this affects the fill color
    fn_sgr_op $SGR_ATTR_DEFAULT

    if((_direction > 0))
    then
        fn_csi_op $CSI_OP_SCROLL_UP 1
    else
        fn_csi_op $CSI_OP_SCROLL_DOWN 1
    fi

    # reset the scrolling bounds to default
    fn_csi_op $CSI_OP_SET_SCROLL
}

function fn_csi_read_delim()
{
    local _result_ref=$1
    local _delimiter=$2
    local _timeout=${3:-$CSI_READ_ESC_TIMEOUT}

    # change IFS so newline can be read
    local IFS=

    if ! read -t$_timeout -s -d$_delimiter $_result_ref
    then
        fn_utl_die "Failed to read delimiter <$_delimiter> within timeout."
    fi

    return 0
}

function fn_csi_read_char()
{
    local _result_ref=$1

    # change IFS so newline can be read
    local IFS=

    if ! read -t$CSI_READ_ESC_TIMEOUT -s -N1 $_result_ref
    then
        # got timeout
        return 1
    fi

    return 0
}
