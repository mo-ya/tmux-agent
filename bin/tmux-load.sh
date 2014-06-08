#!/bin/bash
##
## Copyright (C) 2014 Y.Morikawa <http://moya-notes.blogspot.jp/>
##
## License: MIT License  (See LICENSE.md)
##
########################################
## Settings
########################################
TMUX_YAML_PATH="${HOME}/.tmux-load-conf"

##### Functions #####
reset_files(){
    for file in $*; do
        rm -f ${file} ; touch ${file}
    done
}

##### Internal Settings #####
tmpd="/tmp/tmux-load.$$"

load_file_tmp="${tmpd}/load_file"
err_file="${tmpd}/error"
session_file="${tmpd}/session"
window_file="${tmpd}/window"
pane_file="${tmpd}/pane"
pane_sync_file="${tmpd}/pane-sync"
pane_layout_file="${tmpd}/pane-layout"
window_cmd_file="${tmpd}/window-command"
pane_cmd_file="${tmpd}/pane-command"

tmp_files="${load_file_tmp} ${err_file} ${session_file} ${window_file} ${pane_file} ${pane_sync_file} ${pane_layout_file} ${window_cmd_file} ${pane_cmd_file}"

##### Main Routine #####

if [ -z "$1" ]; then
    echo 
    echo "  Usage: ./$(basename $0) file"
    echo
    exit 1
fi

load_file="${TMUX_YAML_PATH}/$1"

if [ ! -r "${load_file}" ]; then
    echo 
    echo "  ERROR:  \"${load_file}\" is not found or not readable."
    echo
    exit 1
fi

test -d $tmpd || mkdir $tmpd
reset_files ${tmp_files}

cat ${load_file} > ${load_file_tmp}
echo "" >> ${load_file_tmp}

window_1st=1
cat ${load_file_tmp} | while read line; do

    if [[ "$line" =~ ^# ]]; then
        continue
    fi

    if [[ "$line" =~ ^$ ]]; then
        continue
    fi
    
    case "$line" in
        session:*) 
            session=$(echo $line | awk -F: '{print $2}')
            if [ -z "$session" ]; then
                cnt=0
                dup=1

                while [ -n "$dup" ]; do
                    session="anon${cnt}"
                    tmux has-session -t $session > /dev/null 2>&1
                    if [ $? -ne 0 ];then
                        dup=
                        break
                    fi
                    cnt=$(expr $cnt + 1)
                done
            fi
            
            echo $session > $session_file
            
            tmux has-session -t $session > /dev/null 2>&1
            if [ $? -eq 0 ];then
                break
            fi

            ;;
        window-command:*)
            window_command="$(echo $line | sed 's/^window-command: *//g')"
            #echo $window_command | tr ';' '\n' > $window_cmd_file
            echo $window_command >> $window_cmd_file
            ;;
        window:*)
            session=$(cat $session_file)
            if [ -z "$session" ]; then
                echo ""
                echo "  ERROR: \"session\" is not found. Please write \"session:\" on the file."
                echo ""
                echo "1" > ${err_file}
                exit 1
            fi
            
            windows="$(echo $line | sed 's/^window: *//g')"
            if [ -z "$windows" ]; then
                windows="$session"
            fi

            echo $windows > $window_file

            for window in $(eval echo $windows); do
                tmux has-session -t $session > /dev/null 2>&1
                if [ $? -eq 0 ];then
                    tmux new-window -n $window
                else
                    tmux new-session -d -n $window -s $session
                fi
                cat ${window_cmd_file} | while read cmd; do
                    tmux send-keys "eval $(echo ${cmd} | sed "s/\$window/$window/g")" C-m
                done
            done
            reset_files ${window_cmd_file}

            window_1st=1
            ;;
        pane-command:*)
            pane_command="$(echo $line | sed 's/^pane-command: *//g')"
            #echo $pane_command | tr ';' '\n'  > $pane_cmd_file
            echo $pane_command >> $pane_cmd_file
            ;;
        pane-sync:*)
            echo 1 >> $pane_sync_file
            ;;
        pane-layout:*)
            pane_layout="$(echo $line | sed 's/^pane-layout: *//g')"
            echo $pane_layout >> $pane_layout_file
            ;;
        pane:*)
            panes="$(echo $line | sed 's/^pane: *//g')"
            echo $pane > $pane_file
            windows=$(cat $window_file)

            pane_layout=$(cat ${pane_layout_file})
            if [ -z "$pane_layout" ]; then
                pane_layout="even-vertical"
            fi
            reset_files ${pane_layout_file}
            
            for window in $windows; do

                tmux has-session -t $session > /dev/null 2>&1
                if [ $? -ne 0 ];then
                    tmux new-session -d -n $session -s $session
                    window_1st=1
                fi

                tmux select-window -t $window
                
                for pane in $(eval echo $panes); do
                    if [ -n "$window_1st" ]; then
                        window_1st=
                    else
                        tmux split-window
                        tmux select-layout -t $window $pane_layout >/dev/null 2>&1
                    fi
                    cat ${pane_cmd_file} | while read cmd; do
                        tmux send-keys "eval $(echo ${cmd} | sed "s/\$pane/$pane/g" | sed "s/\$window/$window/g" )" C-m
                    done
                done
                
                pane_sync=$(cat ${pane_sync_file})
                if [ -n "$pane_sync" ]; then
                    tmux set-window-option synchronize-panes on >/dev/null 2>&1
                fi
                window_1st=1
            done

            reset_files ${pane_cmd_file} ${pane_sync_file}
            
            ;;
        *)
            echo ""
            echo "  ERROR: \"$line\" can not be parsed"
            echo ""
            echo "1" > ${err_file}
            exit 1
            ;;
    esac
done

err=$(cat ${err_file})
session=$(cat $session_file)

tmux has-session -t $session > /dev/null 2>&1
if [ $? -ne 0 ];then
    tmux new-session -d -n $session -s $session
fi

rm -f ${tmpd}/*
test -d $tmpd && rmdir $tmpd

if [ -n "$err" ]; then
    exit 1
fi

tmux select-window -t 0
tmux select-pane -t 0
tmux attach-session -t $session

exit 0
