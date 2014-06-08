# -*- mode: sh; -*-
# tmux-load completion settings for zsh(1)
#

## It is expected that following compinit settings are written above the _tmux-load code
#
#autoload -U compinit
#compinit

function _tmux-load {
    _files -W ${HOME}/.tmux-load-conf/ && return 0;
    return 1;
}

compdef _tmux-load tmux-load
