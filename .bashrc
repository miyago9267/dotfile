######################################################
##											                            ##
##		          BASHRC by Miyago				            ##
##													                        ##
######################################################

# macOS Homebrew 路徑修復
if [ -d /opt/homebrew/bin ]; then
  export PATH="/opt/homebrew/bin:$PATH"
elif [ -d /usr/local/bin ]; then
  export PATH="/usr/local/bin:$PATH"
fi

export PERL_BADLANG=0

# Export config
export TERM="xterm-256color"
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8
export EDITOR="vim"
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=10000000
export SAVEHIST=10000000

# Enable alias
if [ -f ~/alias.sh ]; then
  source ~/alias.sh
elif [ -f ~/dotfile/alias.sh ]; then
  source ~/dotfile/alias.sh
fi

# Load environment variables from .env
if [ -f ~/.env ]; then
  source ~/.env
elif [ -f ~/dotfile/.env ]; then
  source ~/dotfile/.env
fi

# set a fancy prompt
case "$TERM" in
	xterm-color|*-256color) color_prompt=yes;;
esac

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
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias dir='dir --color=auto'
	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Modular environment: load snippets from ~/.zshrc.d/*.zsh (shared with zsh)
ZSHRC_D="$HOME/.zshrc.d"
if [ -d "$ZSHRC_D" ]; then
  for f in "$ZSHRC_D"/*.zsh; do
    [ -e "$f" ] || continue
    [ -r "$f" ] && . "$f"
  done
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
. "$HOME/.cargo/env"
