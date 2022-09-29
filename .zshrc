######################################################
##																									##
##						ZSHRC CONFIGURE USE ZPLUG							##
##																									##			
######################################################

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/.zplug/init.zsh

# Zplug plugins
zplug "romkatv/powerlevel10k", as:theme, depth:1
zplug 'zplug/zplug', hook-build:'zplug --self-manage'
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-autosuggestions"
zplug "zdharma/fast-syntax-highlighting"
zplug "zpm-zsh/ls"
zplug "plugins/docker", from:oh-my-zsh
zplug "plugins/composer", from:oh-my-zsh
zplug "plugins/extract", from:oh-my-zsh
zplug "lib/completion", from:oh-my-zsh
zplug "plugins/sudo", from:oh-my-zsh
zplug "b4b4r07/enhancd", use:init.sh

# Export config
export TERM="xterm-256color"
export UPDATE_ZSH_DAYS=7
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=3"
export LC_ALL=en_US.UTF-8
export EDITOR="vim"
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000000
export SAVEHIST=10000000

# Set a fancy prompt
case "$TERM" in
		xterm-color|*-256color) color_prompt=yes;;
esac

# Zsh
ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"

# Configure
# search keybind
if zplug check zsh-users/zsh-history-substring-search; then
  bindkey '^[[a' history-substring-search-up
  bindkey '^[[b' history-substring-search-down
fi
# ...

# Check plugin
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    else
        echo
    fi
fi
zplug load

# Load p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# Fuck NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
