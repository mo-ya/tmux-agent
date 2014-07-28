# -*- mode: sh; -*-
# tmux-agent completion settings for zsh(1)
#

## It is expected that following compinit settings are written above the _tmux-agent code
#
#autoload -U compinit
#compinit

function _tmux-agent {
    local -a _confs _attacheds _detacheds
    _confs=( $( find ${HOME}/.tmux-agent/* -maxdepth 0  \( -type f -or -type l \) -exec basename '{}' ';' 2>/dev/null | sed -e "s/$/\:init-action/g" ) )
    for _conf in $_confs; do
        _describe "Initial Action File: $_conf" _conf
    done
    
    _attacheds=( $(tmux ls 2>/dev/null | awk -F: '/(attached)/ {print $1}' | sed -e "s/$/\:attached/g") )
    for _attached in $_attacheds; do
        _describe "Attached Session: $_attached" _attached
    done
    
    _detacheds=( $(tmux ls 2>/dev/null | awk -F: '!/(attached)/ {print $1}' | sed -e "s/$/\:detached/g") )
    for _detached in $_detacheds; do
        _describe "Detached Session: $_detached" _detached
    done

    return 0;
}

compdef _tmux-agent tmux-agent
