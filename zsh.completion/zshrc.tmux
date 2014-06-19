# -*- mode: sh; -*-
# tmux-initload completion settings for zsh(1)
#

## It is expected that following compinit settings are written above the _tmux-initload code
#
#autoload -U compinit
#compinit

function _tmux-initload {
    _files -W ${HOME}/.tmux-initload-conf/ && return 0;
    return 1;
}

compdef _tmux-initload tmux-initload
