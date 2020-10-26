# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/home/miyago/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"


ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

zstyle ':zim:git' aliases-prefix 'g'
WORDCHARS=${WORDCHARS//[\/]}

# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )
# CASE_SENSITIVE="true"
# HYPHEN_INSENSITIVE="true"
# DISABLE_AUTO_UPDATE="true"
# DISABLE_UPDATE_PROMPT="true"
# export UPDATE_ZSH_DAYS=13
# DISABLE_MAGIC_FUNCTIONS="true"
# DISABLE_LS_COLORS="true"
# DISABLE_AUTO_TITLE="true"
# COMPLETION_WAITING_DOTS="true"
# DISABLE_UNTRACKED_FILES_DIRTY="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh


# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# antigen settings

source ~/.antigen.zsh
#source /usr/share/zsh-antigen/antigen.zsh
antigen use oh-my-zsh

function _z() { _zlua "$@"; }

antigen bundle skywind3000/z.lua
antigen bundle changyuheng/fz
antigen bundle command-not-found
antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle autopep8
antigen bundle cargo
antigen bundle docker
antigen bundle dotnet
antigen bundle emoji
antigen bundle git-auto-fetch
antigen bundle gradle
antigen bundle npm
antigen bundle python
antigen bundle ruby
antigen bundle sudo
antigen bundle thefuck
antigen bundle ufw
antigen bundle vscode
antigen bundle archlinux
antigen bundle systemd

antigen theme romkatv/powerlevel10k
antigen apply

# aliases

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias l='ls -l'
alias ll='ls -alF'
alias py='python3'

# set a fancy prompt
case "$TERM" in
		xterm-color|*-256color) color_prompt=yes;;
esac

ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"

# enable ls color
if [ -x /usr/bin/dircolors ]; then
		test -r ~/.dircolors && eval "$(dircolor -b ~/.dircolors)" || eval "$(dircolors -b)"
 		alias ls='ls --color=auto'
		alias dir='dir --color=auto'
		alias grep='grep --color=auto'
		alias fgrep='fgrep --color=auto'
		alias egrep='egrap --color=auto'
fi

export TERM="xterm-256color"
export UPDATE_ZSH_DAYS=7
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=3"
export LC_ALL=en_US.UTF-8
export EDITOR="vim"
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000000
export SAVEHIST=10000000

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
