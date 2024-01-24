# common cmd
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='ls -l --color=auto'
alias ll='ls -alF'
alias py='python3.10'
alias nv='nvim'
alias clr='clear'
alias sudo='sudo '
alias rc='bash ~/dotfile/script/rc.sh '
alias lnk='~/dotfile/script/lnk.sh '
alias codegpt='~/lib/codegpt'
alias neofetch='neofetch;printcat'
alias rc='~/dotfile/script/coderun.sh '

# enable ls color
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolor -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrap --color=auto'
fi
