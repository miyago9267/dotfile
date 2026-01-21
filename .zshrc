######################################################
##																									##
##						ZSHRC CONFIGURE USE ZPLUG							##
##																									##
######################################################

# macOS Homebrew 路徑修復
if [ -d /opt/homebrew/bin ]; then
  export PATH="/opt/homebrew/bin:$PATH"
elif [ -d /usr/local/bin ]; then
  export PATH="/usr/local/bin:$PATH"
fi

export PERL_BADLANG=0
typeset -i FUNCNEST=1000


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
zplug "junegunn/fzf", from:github, as:command, hook-build:"./install --all"
zplug "Aloxaf/fzf-tab"
zplug "plugins/git", from:oh-my-zsh
zplug "direnv/direnv"
zplug "knqyf263/pet"
zplug "zdharma/fast-syntax-highlighting"
zplug "zpm-zsh/ls"
zplug "plugins/docker", from:oh-my-zsh
zplug "plugins/composer", from:oh-my-zsh
zplug "plugins/extract", from:oh-my-zsh
zplug "lib/completion", from:oh-my-zsh
zplug "plugins/sudo", from:oh-my-zsh

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
# export FUNCNEST=100000

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Load environment variables from .env
if [ -f ~/.env ]; then
  source ~/.env
elif [ -f ~/dotfile/.env ]; then
  source ~/dotfile/.env
fi

# Load aliases
if [ -f ~/alias.sh ]; then
  source ~/alias.sh
elif [ -f ~/dotfile/alias.sh ]; then
  source ~/dotfile/alias.sh
fi

# Set a fancy prompt
case "$TERM" in
		xterm-color|*-256color) color_prompt=yes;;
esac

# Zsh
ENABLE_CORRECTION="true"
HIST_STAMPS="yyyy-mm-dd"
ZSH_DISABLE_COMPFIX=true
skip_global_compinit=1

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

## Modular environment: load snippets from ~/.zshrc.d/*.zsh
ZSHRC_D="$HOME/.zshrc.d"
if [ -d "$ZSHRC_D" ]; then
  for f in "$ZSHRC_D"/*.zsh; do
    [ -e "$f" ] || continue
    [ -r "$f" ] && . "$f"
  done
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bun completions
[ -s "/Users/miyago/.bun/_bun" ] && source "/Users/miyago/.bun/_bun"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="/Users/miyago/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
