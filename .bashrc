# .bashrc made by miyago

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='ls -l'
alias ll='ls -alF'

# set a fancy prompt
case "$TERM" in
		xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
		if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
		# We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
    else
    color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable ls color
if [ -x /usr/bin/dircolors ]; then
		test -r ~/.dircolors && eval "$(dircolor -b ~/.dircolors)" || eval "$(dircolors -b)"
 		alias ls='ls --color=auto'
		alias dir='dir --color=auto'
		alias grep='grep --color=auto'
		alias fgrep='fgrep --color=auto'
		alias egrep='egrap --color=auto'
fi

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

POWERLINE_SCRIPT=/usr/share/powerline/bindings/bash/powerline.sh
if [ -f $POWERLINE_SCRIPT ]; then
  source $POWERLINE_SCRIPT
fi

export TERM=xterm-256color
