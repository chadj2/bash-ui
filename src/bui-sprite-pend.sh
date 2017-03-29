##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         bui-sprite-pend.sh
# Description:  Circular swinging pendulum effect.
##

declare -ir SPRITE_ID_PENDULUM=$((sprite_count++))
sprite_start_map[$SPRITE_ID_PENDULUM]=fn_sprite_pend_start
sprite_animate_map[$SPRITE_ID_PENDULUM]=fn_sprite_pend_animate

# Because BASH does not support floating points we do calculations
# in a higher resolution and scale down for display. We also use
# bit shifting to avoid the need for integer divide. Increasing the 
# scale factor by 1 will double the resolution of the calculation space.
declare -ir SPRITE_PEND_SCALE=8

declare -i sprite_pend_last_col_pos
declare -i sprite_pend_last_row_pos

function fn_sprite_pend_start()
{
    fn_sprite_pend_init_x
    fn_sprite_pend_init_y
}

function fn_sprite_pend_animate()
{
    local -i _col_pos=$((sprite_pend_x_pos >> SPRITE_PEND_SCALE))
    local -i _row_pos=$((sprite_pend_y_pos >> SPRITE_PEND_SCALE))

    fn_sprite_pend_draw \
        $sprite_pend_last_row_pos $_row_pos \
        $sprite_pend_last_col_pos $_col_pos

    sprite_pend_last_row_pos=$_row_pos
    sprite_pend_last_col_pos=$_col_pos

    fn_sprite_pend_calc_x
    fn_sprite_pend_calc_y
}

function fn_sprite_pend_draw()
{
    local -i _old_row=$1
    local -i _new_row=$2
    local -i _old_col=$3
    local -i _new_col=$4

    local -i _direction
    local -i _row_diff=$((_new_row - _old_row))

    if((_row_diff > 0))
    then
        _direction=1
    elif((_row_diff < 0))
    then
        _direction=-1
    else
        # same position
        fn_sprite_alpha_map_set $_new_row $_new_col -1
        return
    fi

    # draw to connect spaces between frames of Y position
    ((_row_diff *= _direction))

    local -i _row_idx
    local -i _row_tmp
    for((_row_idx=0; _row_idx <= _row_diff; _row_idx++))
    do
        _row_tmp=$(( _direction*(_row_idx + 1) + _old_row))
        fn_sprite_alpha_map_set $_row_tmp $_new_col -1
    done
}

# Simulate the acceleration of a spring.
# Note: We could have made a pendulum with constant accleration which 
#       would give parabolic motion like a ball thrown in the air. Instead
#       we simulate a spring because it gives more natural sinusoid motion.
# 
# (vf) = (vi) + (k)(d)/(dMax)
# vf   = final velocity
# vi   = initial velocity
# d    = distance from center
# k    = spring constant
# dMax = max distance 

##
# X axis calculation
##

declare -i sprite_pend_x_center
declare -i sprite_pend_x_pos
declare -i sprite_pend_x_vel
declare -ir SPRITE_PEND_SPRING_K_X=$((1 << 4))

function fn_sprite_pend_init_x()
{
    local -i _col_center=$((sprite_canvas_width/2))
    sprite_pend_x_center=$((_col_center << SPRITE_PEND_SCALE))

    local -i _col_pos=$((sprite_canvas_width - 1))
    sprite_pend_last_col_pos=$_col_pos
    sprite_pend_x_pos=$((_col_pos << SPRITE_PEND_SCALE))
    
    sprite_pend_x_vel=0
}

function fn_sprite_pend_calc_x()
{
    local -i _center_dist=$((sprite_pend_x_center - sprite_pend_x_pos))
    local -i _x_acc=$((_center_dist * SPRITE_PEND_SPRING_K_X ))
    ((_x_acc /= sprite_pend_x_center))
    ((sprite_pend_x_vel += _x_acc))
    ((sprite_pend_x_pos += sprite_pend_x_vel))
}

##
# Y axis calculation
##

declare -i sprite_pend_y_center
declare -i sprite_pend_y_pos
declare -i sprite_pend_y_vel
declare -ir SPRITE_PEND_SPRING_K_Y=$((1 << 8))

function fn_sprite_pend_init_y()
{
    local -i _row_center=$((sprite_canvas_height/2))
    sprite_pend_y_center=$((_row_center << SPRITE_PEND_SCALE))

    local -i _row_pos=$((sprite_canvas_height - 1))
    sprite_pend_last_row_pos=$_row_pos
    sprite_pend_y_pos=$((_row_pos << SPRITE_PEND_SCALE))
    
    sprite_pend_y_vel=0
}

function fn_sprite_pend_calc_y()
{
    local -i _center_dist=$((sprite_pend_y_center - sprite_pend_y_pos))
    local -i _y_acc=$((_center_dist * SPRITE_PEND_SPRING_K_Y ))
    ((_y_acc /= sprite_pend_y_center))
    ((sprite_pend_y_vel += _y_acc))
    ((sprite_pend_y_pos += sprite_pend_y_vel))
}
