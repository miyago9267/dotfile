# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='ls -l'
alias ll='ls -la'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

POWERLINE_SCRIPT=/usr/share/powerline/bindings/bash/powerline.sh
if [ -f $POWERLINE_SCRIPT ]; then
  source $POWERLINE_SCRIPT
fi
