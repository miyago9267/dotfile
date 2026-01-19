# common cmd
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='ls -l --color=auto'
alias ll='ls -alF'
alias py='python3'
alias nv='nvim'
alias clr='clear'
alias sudo='sudo '
alias neofetch='neofetch;printcat'
alias rc='~/dotfile/script/utils/runcpp.sh '
alias cb='carbonyl '
alias god='go '
alias du='du -had1'
alias ptr='poetry run '

OS_NAME="$(uname -s)"

case "$OS_NAME" in
  Darwin)
    alias ls='ls -G'
    alias l='ls -l -G'
    alias ll='ls -alFG'
    alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
    alias brewu='brew update && brew upgrade && brew cleanup'
    ;;
  Linux)
    if command -v pacman >/dev/null 2>&1; then
      alias updatepkg='sudo pacman -Syu'
      alias ls='ls --color=auto'
    elif command -v apt >/dev/null 2>&1; then
      alias updatepkg='sudo apt update && sudo apt upgrade'
    fi
    ;;
esac

# enable ls color (GNU dircolors)
if [ -x /usr/bin/dircolors ]; then
	if [ -r ~/.dircolors ]; then
		eval "$(dircolors -b ~/.dircolors)"
	else
		eval "$(dircolors -b)"
	fi
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi
