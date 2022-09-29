# common cmd
export alias rm='rm -i'
export alias cp='cp -i'
export alias mv='mv -i'
export alias l='ls -l'
export alias ll='ls -alF'
export alias py='python3'
export alias nv='nvim'
export alias clr='clear'
export alias sudo='sudo '
export alias rc='~/script/rc.sh '
export alias lnk='~/script/lnk.sh '

# enable ls color
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolor -b ~/.dircolors)" || eval "$(dircolors -b)"
	export alias ls='ls --color=auto'
	export alias dir='dir --color=auto'
	export alias grep='grep --color=auto'
	export alias fgrep='fgrep --color=auto'
	export alias egrep='egrap --color=auto'
fi
