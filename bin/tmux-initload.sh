#!/bin/bash
##
## Copyright (C) 2014 Y.Morikawa <http://moya-notes.blogspot.jp/>
##
## License: MIT License  (See LICENSE.md)
##
########################################
## Settings (Please modify for your environment)
########################################
TMUX_YAML_PATH="${HOME}/.tmux-initload-conf"



########################################
## Main Routine, etc.
########################################

##### Functions #####
reset_files(){
    for file in $*; do
        rm -f ${file} ; touch ${file}
    done
}

tmux_session_exist(){
    session_name=$1
    tmux new-session -d -s $session_name 2>/dev/null
    if [ $? -eq 0 ]; then
        tmux kill-session -t $session_name
        return 1
    else
        return 0
    fi
}

set_status_left_length(){

    session=$1

    status_left=$( tmux show-options -g status-left | awk '{print $2}' | sed -e 's/\#\[[^]]*\]//g' | sed -e 's/\"//g' )

    if [[ "$status_left" =~ ^#S ]]; then
        status_left_length=$(cat ${status_left_length_file} | tr \\r \\n)
        default_status_left_length=$( tmux show-options -g status-left-length 2>/dev/null | awk '{print $2}' )
        if [ $status_left_length -gt $default_status_left_length ]; then
            tmux set-option -t $session status-left-length $status_left_length >/dev/null
        fi
    fi
}

window_countup(){
    windows_need_split_ary=($(cat ${windows_need_split_ary_file} | tr \\r \\n))
    if [ ${#windows_need_split_ary[@]} -lt 1 ]; then
        windows_need_split_ary=( 0 )
    else
        windows_need_split_ary=( $(echo ${windows_need_split_ary[@]}) 0 )
    fi
    echo ${windows_need_split_ary[@]} | tr \\r \\n > ${windows_need_split_ary_file}
}

##### Internal Settings #####
tmpd="/tmp/tmux-initload.$$"

load_file_tmp="${tmpd}/load_file"
err_file="${tmpd}/error"
session_file="${tmpd}/session"
window_file="${tmpd}/window"
window_anon_cnt_file="${tmpd}/window_anon_cnt"
windows_need_split_ary_file="${tmpd}/windows_need_split_ary"
window_base_index_file="${tmpd}/window_base_index"
window_increment_num_file="${tmpd}/window_increment_num"
pane_file="${tmpd}/pane"
pane_sync_file="${tmpd}/pane-sync"
pane_layout_file="${tmpd}/pane-layout"
window_cmd_file="${tmpd}/window-command"
pane_cmd_file="${tmpd}/pane-command"
status_left_length_file="${tmpd}/status-left-length"

tmp_files="${load_file_tmp} ${err_file} ${session_file} ${window_file} ${window_anon_cnt_file} ${windows_need_split_ary_file} ${window_base_index_file} ${window_increment_num_file} ${pane_file} ${pane_sync_file} ${pane_layout_file} ${window_cmd_file} ${pane_cmd_file} ${status_left_length_file}"

##### Main Routine #####

if [ -z "$1" ]; then
    echo 
    echo "  Usage: ./$(basename $0) <file|session>"
    echo
    exit 1
fi

conf_file=$1
load_file="${TMUX_YAML_PATH}/$conf_file"

if [ ! -r "${load_file}" ]; then
    tmux_session_exist $conf_file
    if [ $? -ne 0 ]; then
        echo 
        echo "  ERROR:  \"${load_file}\" is not readable, "
        echo "          and session \"$conf_file\" not found."
        echo
        exit 1
    else
        tmux attach-session -t $conf_file
        exit 0
    fi
fi

shift
argv="$*"

test -d $tmpd || mkdir $tmpd
reset_files ${tmp_files}

cat ${load_file} | tr \\r \\n > ${load_file_tmp}
echo "" >> ${load_file_tmp}

echo 0 > ${status_left_length_file}
echo 0 > ${window_base_index_file}
echo 0 > ${window_increment_num_file}

cat ${load_file_tmp} | while read line; do

    if [[ "$line" =~ ^# ]]; then
        continue
    fi

    if [[ "$line" =~ ^$ ]]; then
        continue
    fi
    
    case "$line" in
        session:*) 
            session=$( echo $line | awk -F: '{print $2}' | sed "s/\${argv}/$argv/g" | sed "s/\${file}/$conf_file/g"  | sed "s/^[ ]*//g" | sed "s/[ ]*$//g" | tr -s " " | sed "s/[. ]/_/g" )
            
            if [ -z "$session" ]; then
                session="$conf_file\${id}"
            fi
            
            if [[ "$session" =~ \$\{id\} ]]; then
                cnt=0
                new=
                while [ -z "$new" ]; do
                    session_tmp=$( echo $session | sed "s/\${id}/$cnt/g" )
                    echo $session | sed "s/\${id}.*$/$cnt/g" | wc -c > ${status_left_length_file}
                    tmux_session_exist $session_tmp
                    if [ $? -ne 0 ];then
                        new=1
                        session="$session_tmp"
                        break
                    fi
                    cnt=$(expr $cnt + 1)
                done
            fi

            echo $session > $session_file
            echo "0" > $window_anon_cnt_file

            tmux_session_exist $session
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
            session=$(cat $session_file | tr \\r \\n)
            if [ -z "$session" ]; then
                echo ""
                echo "  ERROR: \"session\" is not found. Please write \"session:\" on the file."
                echo ""
                echo "1" > ${err_file}
                exit 1
            fi

            window_increment_num=$(cat ${window_increment_num_file} | tr \\r \\n)
            window_base_index=$(cat ${window_base_index_file} | tr \\r \\n)
            window_base_index=$(expr ${window_base_index} + ${window_increment_num})
            echo ${window_base_index} | tr \\r \\n > ${window_base_index_file}
            window_increment_num=0
            windows="$(echo $line | sed 's/^window: *//g' | sed "s/\${argv}/$argv/g" | sed "s/\${file}/$conf_file/g" )"
            if [ -z "$windows" ]; then
                window_anon_cnt=$(cat $window_anon_cnt_file | tr \\r \\n)
                windows="${session}_${window_anon_cnt}"
                expr $window_anon_cnt + 1 > $window_anon_cnt_file
            fi

            echo $windows > $window_file
            windows=$(cat $window_file | tr \\r \\n)

            for window in $(eval echo $windows); do
                window_increment_num=$(expr ${window_increment_num} + 1)

                tmux_session_exist $session
                if [ $? -eq 0 ];then
                    tmux new-window -n $window
                    window_countup
                else
                    tmux new-session -d -n $window -s $session
                    set_status_left_length $session
                    window_countup
                fi
                cat ${window_cmd_file} | while read cmd; do
                    tmux send-keys "eval \"$(echo ${cmd} | sed "s/\${window}/$window/g" | sed "s/\${file}/$conf_file/g" )\"" C-m
                done
            done
            reset_files ${window_cmd_file}
            echo ${window_increment_num} | tr \\r \\n > ${window_increment_num_file}
            
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
            panes="$(echo $line | sed 's/^pane: *//g' | sed "s/\${argv}/$argv/g" | sed "s/\${file}/$conf_file/g" )"
            echo $panes > $pane_file
            panes=$(cat $pane_file | tr \\r \\n)
            windows=$(cat $window_file | tr \\r \\n)
            if [ -z "$windows" ]; then
                windows="$session"
            fi
            if [ -z "$panes" ]; then
                for window in $windows; do
                    panes="$window"
                    break
                done
            fi
            pane_layout=$(cat ${pane_layout_file} | tr \\r \\n)
            if [ -z "$pane_layout" ]; then
                pane_layout="even-vertical"
            fi
            reset_files ${pane_layout_file}

            window_current_index=$(cat ${window_base_index_file} | tr \\r \\n)
            
            for window in $(eval echo $windows); do
                tmux_session_exist $session
                if [ $? -ne 0 ];then
                    tmux new-session -d -n $session -s $session
                    set_status_left_length $session
                    window_countup
                fi

                tmux select-window -t :${window_current_index}
                windows_need_split_ary=($(cat ${windows_need_split_ary_file} | tr \\r \\n))
                for pane in $(eval echo $panes); do
                    if [ ${windows_need_split_ary[${window_current_index}]} -eq 0 ]; then
                        windows_need_split_ary[${window_current_index}]=1
                    else
                        tmux select-layout -t :${window_current_index} tiled >/dev/null
                        tmux split-window
                        tmux select-layout -t :${window_current_index} $pane_layout >/dev/null
                    fi
                    cat ${pane_cmd_file} | while read cmd; do
                        tmux send-keys "eval \"$(echo ${cmd} | sed "s/\${pane}/$pane/g" | sed "s/\${window}/$window/g" | sed "s/\${file}/$conf_file/g" )\"" C-m
                    done
                done
                
                pane_sync=$(cat ${pane_sync_file} | tr \\r \\n)
                if [ -n "$pane_sync" ]; then
                    tmux set-window-option synchronize-panes on >/dev/null
                fi

                echo ${windows_need_split_ary[@]} | tr \\r \\n > ${windows_need_split_ary_file}
                window_current_index=$(expr ${window_current_index} + 1)
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

err=$(cat ${err_file} | tr \\r \\n)
session=$(cat $session_file | tr \\r \\n)

tmux_session_exist $session
if [ $? -ne 0 ]; then
    tmux new-session -d -n $session -s $session
    set_status_left_length $session
    window_countup
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
