##
# BASH-UI - Bash User Interface Tools
# Copyright 2017 by Chad Juliano
# 
# Licensed under GNU Lesser General Public License v3.0 only. Some rights
# reserved. See LICENSE.
#
# File:         test-browse.sh
# Description:  Standalone tester for browse menu.
##

# generate errors if unset vars are used.
set -o nounset

if [ -o posix ]
then
    echo "ERROR: Bash-UI should not be run in posix mode." 2>&1
    exit 1
fi

_script_dir="$(cd "$(dirname $0)" && pwd -P)"
BUI_HOME=${_script_dir}/../src

source ${BUI_HOME}/bui-term-draw.sh
source ${BUI_HOME}/bui-settings.sh
source ${BUI_HOME}/bui-util.sh
source ${BUI_HOME}/bui-theme-mgr.sh
source ${BUI_HOME}/bui-panel-hmenu.sh
source ${BUI_HOME}/bui-panel-vmenu.sh
source ${BUI_HOME}/bui-panel-browse.sh

function fn_test_browse()
{
    # enable echo on exit
    util_exit_echo=1
    
    fn_util_panel_open
    fn_theme_init
    
    # set the location of where the hmenu would be
    hmenu_row_pos=-1

    # show the panel
    fn_bui_controller_browse

    fn_util_panel_close
    
    echo "Browse result: ${bui_selection_result}"
}

# entry point
fn_test_browse
