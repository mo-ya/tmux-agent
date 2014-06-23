# -*- mode: sh; -*-
# tmux-initload completion settings for zsh(1)
#

## It is expected that following compinit settings are written above the _tmux-initload code
#
#autoload -U compinit
#compinit

function _tmux-initload {
    local -a _confs _attacheds _detacheds
    _confs=( $(find ${HOME}/.tmux-initload-conf/* -type f -maxdepth 0 -exec basename '{}' ';' | sed -e "s/$/\:config/g" ) )
    for _conf in $_confs; do
        _describe "Initial Actions Config File: $_conf" _conf
    done
    
    _attacheds=( $(tmux ls | awk -F: '/(attached)/ {print $1}' | sed -e "s/$/\:attached/g") )
    for _attached in $_attacheds; do
        _describe "Attached Session: $_attached" _attached
    done
    
    _detacheds=( $(tmux ls | awk -F: '!/(attached)/ {print $1}' | sed -e "s/$/\:detached/g") )
    for _detached in $_detacheds; do
        _describe "Detached Session: $_detached" _detached
    done

    return 0;
}

compdef _tmux-initload tmux-initload
