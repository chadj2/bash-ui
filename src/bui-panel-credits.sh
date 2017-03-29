##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-panel-credits.sh
# Description:  Panel for animated credits.
##

source ${BUI_HOME}/bui-sprite-base.sh
source ${BUI_HOME}/bui-sprite-pend.sh
source ${BUI_HOME}/bui-sprite-text.sh

function fn_cred_show()
{
    # Panel geometry
    local -i _cred_height=$((draw_panel_row_size - HMENU_ROW_SIZE))
    local -i _cred_width=$draw_panel_col_size
    local -i _cred_row_pos=$HMENU_ROW_SIZE

    local -a _text_data
    fn_cred_text_buf_init '_text_data'
    local -i _text_max_width=$?
    local -i _text_data_size=${#_text_data[@]}

    # center the canvas in the panel
    sprite_canvas_width=$((_text_max_width + 4))
    sprite_canvas_col_pos=$(( (_cred_width - 2 - sprite_canvas_width )/2 + 1))

    sprite_canvas_height=$((_text_data_size + 4))
    sprite_canvas_row_pos=$(( (_cred_height - sprite_canvas_height)/2 + _cred_row_pos))

    # load the text data
    fn_sprite_buf_init '_text_data[@]'

    fn_draw_box_panel $_cred_row_pos
    fn_cred_start_animate
}

function fn_cred_text_buf_init()
{
    local _text_data_ref=$1

    mapfile -t $_text_data_ref <<-EOM
BUI - Bash User Interface

Version ${BUI_VERSION}
Copyright 2017 by Chad Juliano
chadj@pobox.com

Find it at:
https://github.com/chadj2/bash-ui
EOM

#     if((UTIL_DEBUG_ENABLE))
#     then
#     mapfile -n${cred_height} -t $_text_data_ref <<-EOM
# X1234567890123456789012345678901234567890
# YYYYYY YYYYYYYYY YYY
# EOM
#     fi

    local _tmp_ref="${_text_data_ref}[@]"
    local -a _tmp_buf=( "${!_tmp_ref}" )
    local -i _buf_size=${#_tmp_buf[@]}

    # get the max width of the text buffer
    local -i _max_width=0
    local -i _line_idx

    for((_line_idx=0; _line_idx < _buf_size; _line_idx++))
    do
        local _line_data="${_tmp_buf[_line_idx]}"
        local -i _line_size=${#_line_data}

        if((_max_width < _line_size))
        then
            _max_width=$_line_size
        fi
    done

    return $_max_width
}

function fn_cred_start_animate()
{
    # init sprite state
    fn_sprite_init
    fn_sprite_alpha_init

    local -i _last_inactive=$SPRITE_ID_CURSOR
    local -i _row_idx=-1
    local -i _cursor_idx=0

    # Sprites follow a basic cycle:
    # 
    # 1. Sprites are started with fn_sprite_start.
    # 2. Sprites are animated with fn_sprite_timer_loop.
    # 3. fn_sprite_timer_loop returns when a single sprite terminates or user
    #    hits a key to cancel.
    # 4. The terminated sprite is evaluated to determine the next action 
    #    in the sequence.
    # 5. fn_sprite_timer_loop is called to resume animation until another 
    #    sprite terminates.
    # 
    # Note: At least one sprite must be active when calling fn_sprite_timer_loop 
    #    or process will exit.

    # Start the alpha mapper. It will never terminate.
    fn_sprite_start $SPRITE_ID_ALPHA

    # Set colormap as Yellow/white gradient
    fn_sprite_cmap_grad 30 $((HSL216_HUE_YELLOW - 1)) 1 5

    while ((_row_idx < sprite_canvas_height))
    do
        case $_last_inactive in
            $SPRITE_ID_CURSOR)

                ((_row_idx++))
                if ! fn_sprite_start $SPRITE_ID_PRINT $_row_idx
                then
                    # This is an empty line so get next line
                    continue
                fi
                ;;
            $SPRITE_ID_PRINT)

                # Show cursor and goto next line
                _cursor_idx=$_row_idx
                fn_sprite_start $SPRITE_ID_CURSOR $_cursor_idx
                ;;
        esac

        # return if user cancel
        fn_sprite_timer_loop && return
        _last_inactive=$?
    done

    # Cursor should just have terminated
    fn_util_assert_equals '_last_inactive' 'SPRITE_ID_CURSOR'

    local -ir COLOR_TIMER=50
    local -ir HUE_INCREMENT=$((HSL216_HUE_SECTORS/2))
    local -i _color_hue=$((HSL216_HUE_YELLOW - 1))

    # Start the with 1 cycle so it will reset and update the colormap.
    fn_sprite_start $SPRITE_ID_TIMER 1

    # Start the pendulum. It will never terminate.
    fn_sprite_start $SPRITE_ID_PENDULUM

    while [ 1 ]
    do
        case $_last_inactive in
            $SPRITE_ID_CURSOR)

                # continuously show the cursor
                fn_sprite_start $SPRITE_ID_CURSOR $_cursor_idx
                ;;
            $SPRITE_ID_TIMER)

                # timer expired so change the colormap
                fn_sprite_cmap_grad 15 $_color_hue 2 3
                ((_color_hue += HUE_INCREMENT))
                if((_color_hue >= HSL216_HUE_SIZE))
                then
                    ((_color_hue -= HSL216_HUE_SIZE))
                fi

                # re-start timer
                fn_sprite_start $SPRITE_ID_TIMER $COLOR_TIMER
        esac

        # return if user cancel
        fn_sprite_timer_loop && return
        _last_inactive=$?
    done
}
