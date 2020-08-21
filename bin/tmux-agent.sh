#!/bin/bash
##
## Copyright (C) 2020 Y.Morikawa <http://moya-notes.blogspot.jp/>
##
## License: MIT License  (See LICENSE.md)
##
########################################
## Settings (Please modify for your environment)
########################################
TMUX_YAML_PATH="${HOME}/.tmux-agent"
TMUX_CMD="tmux"


########################################
## Main Routine, etc.
########################################

##### Internal Variables #####
VERSION="1.12"
UPDATE="2020-08-13"

##### Functions #####
help(){
    show_version
    echo ""
    echo "  Usage: tmux-agent <init-action-file|session>"
    echo ""
}

show_version(){
    echo "tmux-agent v${VERSION} (update: ${UPDATE})"
}

reset_files(){
    for file in $*; do
        rm -f ${file} ; touch ${file}
    done
}

session_already_load_check(){
    session=$(cat $session_file | tr \\r \\n)
    if [ -z "$session" ]; then
        echo ""
        echo "  ERROR: \"session\" is not found. Please write \"session:\" on the file."
        echo ""
        echo "1" > ${err_file}
        exit 1
    fi
}

tmux_session_exist(){
    session_name=$1
    ${TMUX_CMD} new-session -x ${width} -y ${height} -d -s $session_name 2>/dev/null
    if [ $? -eq 0 ]; then
        ${TMUX_CMD} kill-session -t $session_name
        return 1
    else
        return 0
    fi
}

set_status_left_length(){

    session=$1

    status_left=$( ${TMUX_CMD} show-options -g status-left | awk '{print $2}' | sed -e 's|\#\[[^]]*\]||g' | sed -e 's|\"||g' )

    if [[ "$status_left" =~ ^(.*)#S ]]; then
        left_prefix=${BASH_REMATCH[1]}
        left_len=${#left_prefix}
        
        need_status_left_length=$( expr $(cat ${status_left_length_file} | tr \\r \\n) + $left_len )
        default_status_left_length=$( ${TMUX_CMD} show-options -g status-left-length 2>/dev/null | awk '{print $2}' )
        if [ $need_status_left_length -gt $default_status_left_length ]; then
            ${TMUX_CMD} set-option -t $session status-left-length $need_status_left_length >/dev/null
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
height=$(tput lines)
width=$(tput cols)

wait_prompt_keyword="wait_prompt"
wait_prompt_interval_sec=0.1
wait_prompt_loop_num=50

tmpd="/tmp/tmux-agent.$$"

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
window_cmd_prev_file="${tmpd}/window-command-prev"
pane_cmd_file="${tmpd}/pane-command"
pane_cmd_prev_file="${tmpd}/pane-command-prev"
status_left_length_file="${tmpd}/status-left-length"

tmp_files="${load_file_tmp} ${err_file} ${session_file} ${window_file} ${window_anon_cnt_file} ${windows_need_split_ary_file} ${window_base_index_file} ${window_increment_num_file} ${pane_file} ${pane_sync_file} ${pane_layout_file} ${window_cmd_file} ${window_cmd_prev_file} ${pane_cmd_file} ${pane_cmd_prev_file} ${status_left_length_file}"

##### Main Routine #####

if [ -z "$1" ]; then
    help
    exit 1
fi

while [ -z "${init_act_file}" ]; do
    case $1 in
        -[hH]*)
            shift
            help
            exit 0
            ;;
        -[vV]*)
            shift
            show_version
            exit 0
            ;;
        -l)
            shift
            find ${TMUX_YAML_PATH}/* -maxdepth 0  \( -type f -or -type l \) -exec basename '{}' ';' 2>/dev/null
            exit 0
            ;;
        -*)
            echo ""
            echo "  ERROR: Unknown option\"$1\""
            echo ""
            help
            exit 1
            ;;
        *)
            init_act_file=$1
            ;;
    esac
done

init_act_file=$1
load_file="${TMUX_YAML_PATH}/$init_act_file"

if [ ! -r "${load_file}" ]; then
    tmux_session_exist $init_act_file
    if [ $? -ne 0 ]; then
        echo 
        echo "  ERROR:  \"${load_file}\" is not readable, "
        echo "          and session \"$init_act_file\" not found."
        echo
        exit 1
    else
        ${TMUX_CMD} attach-session -t $init_act_file
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

cat ${load_file_tmp} | sed 's|\\|\\\\|g' | while read line; do

    if [[ "$line" =~ ^# ]]; then
        continue
    fi

    if [[ "$line" =~ ^$ ]]; then
        continue
    fi
    
    case "$line" in
        session:*) 
            session=$( echo $line | awk -F: '{print $2}' | sed "s|\${argv}|$argv|g" | sed "s|\${file}|$init_act_file|g"  | sed "s|^[ ]*||g" | sed "s|[ ]*$||g" | tr -s " " | sed "s|[. ]|_|g" )
            
            if [ -z "$session" ]; then
                session="$init_act_file\${id}"
            fi
            
            if [[ "$session" =~ \$\{id\} ]]; then
                cnt=0
                new=
                while [ -z "$new" ]; do
                    session_tmp=$( echo $session | sed "s|\${id}|$cnt|g" )
                    echo $session | sed "s|\${id}.*$|$cnt|g" | wc -c > ${status_left_length_file}
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
            if [ $? -eq 0 ]; then
                break
            fi

            ;;
        window-command:*)
            session_already_load_check
            window_command="$(echo $line | sed 's|\\|\\\\|g' | sed 's/"/\\\\"/g' | sed 's|^window-command: *||g')"
            #echo $window_command | tr ';' '\n' > $window_cmd_file
            echo $window_command >> $window_cmd_file
            ;;
        window:*)
            session_already_load_check
            session=$(cat $session_file | tr \\r \\n)

            window_increment_num=$(cat ${window_increment_num_file} | tr \\r \\n)
            window_base_index=$(cat ${window_base_index_file} | tr \\r \\n)
            window_base_index=$(expr ${window_base_index} + ${window_increment_num})
            echo ${window_base_index} | tr \\r \\n > ${window_base_index_file}
            window_increment_num=0
            windows="$(echo $line | sed 's|^window: *||g' | sed "s|\${argv}|$argv|g" | sed "s|\${file}|$init_act_file|g" )"
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
                    ${TMUX_CMD} new-window -n $window
                    window_countup
                else
                    ${TMUX_CMD} new-session -x ${width} -y ${height} -d -n $window -s $session
                    set_status_left_length $session
                    window_countup
                fi
                echo "$(LANG=C date +"%Y-%m-%d %H:%M:%S") $(hostname -s) tmux-agent: window[$window] is preparing .." >&2
                cat ${window_cmd_file} | while read cmd; do

                    if [[ ${cmd} =~ ^(sleep|usleep) ]]; then
                        ${cmd}
                    elif [ "${cmd}" == "${wait_prompt_keyword}" ]; then
                        :
                    elif [ "$(cat ${window_cmd_prev_file} 2>/dev/null)" == "${wait_prompt_keyword}" ]; then
                        # If "wait_prompt" was set to command immediately before,
                        # wait Prompt ($,#,>,:) before next send-keys
                        echo "$(LANG=C date +"%Y-%m-%d %H:%M:%S") $(hostname -s) tmux-agent: window[$window] waiting prompt .." >&2
                        last_char_rec1=
                        last_char_rec2=
                        for i in $(seq 1 ${wait_prompt_loop_num}); do
                            last_char=$(${TMUX_CMD} capture-pane -p | grep -v ^$ | tail -1 | sed 's/[ ]\+[^ ]\+\]$//' | sed 's/[ ]\+$//' | rev | cut -c 1)
                            if [ "$last_char_rec1" == "$last_char" ] && [ "$last_char_rec2" == "$last_char" ]  ; then
                                case "$last_char" in
                                    "$" | "#" | ">" | "%" | ":" ) break ;;
                                    * ) ;;
                                esac
                            fi
                            last_char_rec2=$last_char_rec1
                            last_char_rec1=$last_char
                            sleep ${wait_prompt_interval_sec}
                        done

                        ${TMUX_CMD} send-keys "eval \"$(echo ${cmd} | sed "s|\${window}|$window|g" | sed "s|\${file}|$init_act_file|g" | sed 's/\$\([A-Za-z]\)/\\$\1/g' | sed 's/\${\([A-Za-z]\)/\\${\1/g' )\"" C-m
                    else
                        ${TMUX_CMD} send-keys "eval \"$(echo ${cmd} | sed "s|\${window}|$window|g" | sed "s|\${file}|$init_act_file|g" | sed 's/\$\([A-Za-z]\)/\\$\1/g' | sed 's/\${\([A-Za-z]\)/\\${\1/g' )\"" C-m
                    fi

                    echo ${cmd} > ${window_cmd_prev_file}

                done
            done
            reset_files ${window_cmd_file} ${window_cmd_prev_file}
            echo ${window_increment_num} | tr \\r \\n > ${window_increment_num_file}
            
            ;;
        pane-command:*)
            session_already_load_check
            pane_command="$(echo $line | sed 's|\\|\\\\|g' | sed 's/"/\\\\"/g' | sed 's|^pane-command: *||g')"
            #echo $pane_command | tr ';' '\n'  > $pane_cmd_file
            echo $pane_command >> $pane_cmd_file
            ;;
        pane-sync:*)
            session_already_load_check
            echo 1 >> $pane_sync_file
            ;;
        pane-layout:*)
            session_already_load_check
            pane_layout="$(echo $line | sed 's|^pane-layout: *||g')"
            echo $pane_layout >> $pane_layout_file
            ;;
        pane:*)
            session_already_load_check
            panes="$(echo $line | sed 's|^pane: *||g' | sed "s|\${argv}|$argv|g" | sed "s|\${file}|$init_act_file|g" )"
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
                    ${TMUX_CMD} new-session -x ${width} -y ${height} -d -n $session -s $session
                    set_status_left_length $session
                    window_countup
                fi

                ${TMUX_CMD} select-window -t :${window_current_index}
                windows_need_split_ary=($(cat ${windows_need_split_ary_file} | tr \\r \\n))
                for pane in $(eval echo $panes); do
                    if [ ${windows_need_split_ary[${window_current_index}]} -eq 0 ]; then
                        windows_need_split_ary[${window_current_index}]=1
                    else
                        # Process to prevent the screen from becoming narrow enough not to divide
                        ${TMUX_CMD} select-layout -t :${window_current_index} tiled >/dev/null
                        ${TMUX_CMD} split-window
                        ${TMUX_CMD} select-layout -t :${window_current_index} "$pane_layout" >/dev/null
                    fi
                    sync_mode=$( ${TMUX_CMD} show-window-options synchronize-panes )
                    if [ "$sync_mode" == "synchronize-panes on" ]; then
                        ${TMUX_CMD} set-window-option synchronize-panes off >/dev/null
                    fi

                    echo "$(LANG=C date +"%Y-%m-%d %H:%M:%S") $(hostname -s) tmux-agent: pane[$pane] is preparing .." >&2
                    cat ${pane_cmd_file} | while read cmd; do

                        if [[ ${cmd} =~ ^(sleep|usleep) ]]; then
                            ${cmd}
                        elif [ "${cmd}" == "${wait_prompt_keyword}" ]; then
                            :
                        elif [ "$(cat ${pane_cmd_prev_file} 2>/dev/null)" == "${wait_prompt_keyword}" ]; then
                            # If "wait_prompt" was set to command immediately before,
                            # wait Prompt ($,#,>,:) before next send-keys
                            echo "$(LANG=C date +"%Y-%m-%d %H:%M:%S") $(hostname -s) tmux-agent: pane[$pane] waiting prompt .." >&2
                            last_char_rec1=
                            last_char_rec2=
                            for i in $(seq 1 ${wait_prompt_loop_num}); do
                                last_char=$(${TMUX_CMD} capture-pane -p | grep -v ^$ | tail -1 | sed 's/[ ]\+[^ ]\+\]$//' | sed 's/[ ]\+$//' | rev | cut -c 1)
                                if [ "$last_char_rec1" == "$last_char" ] && [ "$last_char_rec2" == "$last_char" ]  ; then
                                    case "$last_char" in
                                        "$" | "#" | ">" | "%" | ":" ) break ;;
                                        * ) ;;
                                    esac
                                fi
                                last_char_rec2=$last_char_rec1
                                last_char_rec1=$last_char
                                sleep ${wait_prompt_interval_sec}
                            done

                            ${TMUX_CMD} send-keys "eval \"$(echo ${cmd} | sed "s|\${pane}|$pane|g" | sed "s|\${window}|$window|g" | sed "s|\${file}|$init_act_file|g" | sed 's/\$\([A-Za-z]\)/\\$\1/g' | sed 's/\${\([A-Za-z]\)/\\${\1/g' )\"" C-m
                        else
                            ${TMUX_CMD} send-keys "eval \"$(echo ${cmd} | sed "s|\${pane}|$pane|g" | sed "s|\${window}|$window|g" | sed "s|\${file}|$init_act_file|g" | sed 's/\$\([A-Za-z]\)/\\$\1/g' | sed 's/\${\([A-Za-z]\)/\\${\1/g' )\"" C-m
                        fi

                        echo ${cmd} > ${pane_cmd_prev_file}

                    done

                    if [ "$sync_mode" == "synchronize-panes on" ]; then
                        ${TMUX_CMD} set-window-option synchronize-panes on >/dev/null
                    fi
                done
                
                pane_sync=$(cat ${pane_sync_file} | tr \\r \\n)
                if [ -n "$pane_sync" ]; then
                    ${TMUX_CMD} set-window-option synchronize-panes on >/dev/null
                fi

                echo ${windows_need_split_ary[@]} | tr \\r \\n > ${windows_need_split_ary_file}
                window_current_index=$(expr ${window_current_index} + 1)
            done

            reset_files ${pane_cmd_file} ${pane_sync_file} ${pane_cmd_prev_file}
            
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
    ${TMUX_CMD} new-session -x ${width} -y ${height} -d -n $session -s $session
    set_status_left_length $session
    window_countup
fi

rm -f ${tmpd}/*
test -d $tmpd && rmdir $tmpd

if [ -n "$err" ]; then
    exit 1
fi

${TMUX_CMD} select-window -t 0
${TMUX_CMD} select-pane -t 0
${TMUX_CMD} attach-session -t $session

exit 0
