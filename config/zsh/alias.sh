# common cmd
alias rm='rm -i'
alias cp='cp -i -r'
alias mv='mv -i'
alias l='ls -l'
alias ll='ls -alFh'
alias py='uv run python'
alias uvr='uv run'
alias uvp='uv run python'
alias nv='nvim'
alias clr='clear'
alias sudo='sudo '
alias neofetch='neofetch;printcat'
alias rc='~/dotfile/script/utils/runcpp.sh '
alias god='go '
alias du='du -had1'
alias ptr='poetry run '

OS_NAME="$(uname -s)"

case "$OS_NAME" in
  Darwin)
    alias ls='ls -G'
    alias l='ls -l -G'
    alias ll='ls -alFG'
    alias du='gdu -had1'
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

# yazi: 退出後 cd 到最後所在目錄
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

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
