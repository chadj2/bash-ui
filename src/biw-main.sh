##
# BIW-MAIN - Bash Inline Widgets
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
##

# generate errors if unset vars are used.
set -o nounset

# event types
readonly biw_event_init=0
readonly biw_event_up=1
readonly biw_event_down=2
readonly biw_event_left=3
readonly biw_event_right=4

source ${BIW_HOME}/biw-terminal.sh
source ${BIW_HOME}/biw-vmenu.sh
source ${BIW_HOME}/biw-hmenu.sh

# global widget params
declare -ri biw_margin=10
declare -ri biw_color_text=$sgr_color_black
declare -ri biw_color_active=$sgr_color_red
declare -ri biw_color_inactive=$sgr_color_blue

declare -r biw_menu_history="History"
declare -r biw_menu_comp="FileCompl"
declare -r biw_menu_config="Config"

function fn_biw_main()
{
    # truncate result file
    :> $BIW_CH_RES_FILE

    local -a _hmenu_values=($biw_menu_history $biw_menu_comp $biw_menu_config)
    fn_hmenu_init _hmenu_values[@]

    # show the widgets
    fn_biw_show

    # get result from index
    local _result=${vmenu_data_values[$vmenu_idx_active]}

    # save to temporary file
    echo $_result > $BIW_CH_RES_FILE
}

function fm_biw_controller()
{
    local -r _event=$1

    case $_event in
        $biw_event_init)
            fn_vmenu_reload
            fn_hmenu_redraw
            fn_vmenu_redraw
            ;;
        $biw_event_up)
            fn_vmenu_up
            ;;
        $biw_event_down)
            fn_vmenu_down
            ;;
        $biw_event_left)
            fm_hmenu_left
            fn_vmenu_reload
            fn_vmenu_redraw
            ;;
        $biw_event_right)
            fm_hmenu_right
            fn_vmenu_reload
            fn_vmenu_redraw
            ;;
    esac
}

function fn_biw_show()
{
    local -i _panel_height=$((vmenu_height + hmenu_height))

    fn_biw_open
    fm_biw_controller $biw_event_init

    local _key
    while fn_read_key "_key"
    do
        case $_key in
            $key_up)
                fm_biw_controller $biw_event_up
                ;;
            $key_down)
                fm_biw_controller $biw_event_down
                ;;
            $key_left)
                fm_biw_controller $biw_event_left
                ;;
            $key_right)
                fm_biw_controller $biw_event_right
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

fn_vmenu_reload()
{
    local -r _menu_val=${hmenu_data_values[$hmenu_idx_active]}
    local -i _values_max=30
    local -a _values=()
    local _data_command

    case $_menu_val in
        $biw_menu_history)
            _data_command="fc -lnr -$_values_max"
            ;;
        $biw_menu_comp)
            _data_command="compgen -A file ${READLINE_LINE}"
            ;;
        $biw_menu_config)
            _data_command='echo -e conf1\nconf2\nconf3'
            ;;
    esac

    # read command into _values
    mapfile -t -n $_values_max _values < <($_data_command)

    # remove first 2 leading blanks for history case
    _values=("${_values[@]#[[:blank:]][[:blank:]]}")

    fn_vmenu_init _values[@]
}

function fn_biw_cursor_home()
{
    # position the cursor at the start of the menu
    fn_esc $esc_restore_cursor
    fn_csi $csi_row_up $_panel_height
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
    for _line_idx in $(eval echo {1..$_panel_height})
    do
        fn_csi $csi_scroll_up 1
        fn_animate_wait
    done

    # non-animated open:
    #fn_csi $csi_scroll_up $_panel_height
    #fn_biw_cursor_home
    #fn_csi $csi_row_insert $_panel_height
}

function fn_biw_close()
{
    # goto home position
    fn_biw_cursor_home

    # animate close
    for _line_idx in $(eval echo {1..$_panel_height})
    do
        fn_csi $csi_row_delete 1
        fn_csi $csi_scroll_down 1
        fn_csi $csi_row_down 1
        fn_animate_wait
    done

    # non-animate close:
    #fn_csi $csi_row_delete $_panel_height
    #fn_csi $csi_scroll_down $_panel_height

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

# entry point
fn_biw_main
