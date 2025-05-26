######################################################
##											                            ##
##		          BASHRC by Miyago				            ##
##													                        ##
######################################################

# Export config
export TERM="xterm-256color"
export UPDATE_ZSH_DAYS=7
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=3"
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8
export EDITOR="vim"
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000000
export SAVEHIST=10000000

# Enable alias
if [ -f ~/alias.sh ]; then
  source ~/alias.sh
elif [ -f ~/dotfile/alias.sh ]; then
  source ~/dotfile/alias.sh
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

POWERLINE_SCRIPT=/usr/share/powerline/bindings/bash/powerline.sh
if [ -f $POWERLINE_SCRIPT ]; then
  source $POWERLINE_SCRIPT
fi

# Fuck NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$HOME/.pyenv/bin:$HOME/.pyenv/shims:$PATH"
export PATH="$HOME/.local/bin:$HOME/.zplug/repos/zplug/zplug/bin:$HOME/.zplug/bin:$PATH"
export PATH="/usr/local/opt/gcc/bin:$PATH"
export PATH="$HOME/.vscode-server/cli/servers/Stable-eaa41d57266683296de7d118f574d0c2652e1fc4/server/bin/remote-cli:$PATH"
export PATH="$HOME/.local/share/pnpm:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.16.0/bin:$PATH"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
