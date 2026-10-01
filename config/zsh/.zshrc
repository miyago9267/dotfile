######################################################
##																									##
##						ZSHRC CONFIGURE USE ZPLUG							##
##																									##
######################################################

export PERL_BADLANG=0
typeset -i FUNCNEST=1000


if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Zplug plugins 宣告在 zplug-packages.zsh（init.zsh 會自動讀 ZPLUG_LOADFILE）
export ZPLUG_LOADFILE="${${(%):-%x}:A:h}/zplug-packages.zsh"
# /bin/zsh 預設 fpath 不含 Homebrew completions；要在 compinit 前加入
[[ -d /opt/homebrew/share/zsh/site-functions ]] && fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

# Export config
export TERM="xterm-256color"
export UPDATE_ZSH_DAYS=7
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#616e88"
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8
export EDITOR="vim"
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000000
export SAVEHIST=10000000
# export FUNCNEST=100000

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Load environment variables from .env
if [ -f ~/.env ]; then
  source ~/.env
elif [ -f ~/dotfile/.env ]; then
  source ~/dotfile/.env
fi

# Load aliases
if [ -f ~/alias.sh ]; then
  source ~/alias.sh
elif [ -f ~/dotfile/config/zsh/alias.sh ]; then
  source ~/dotfile/config/zsh/alias.sh
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

# Load plugins (run `zplug install` manually when adding new plugins)
# 平常只 source 由 zplug cache 產生的 static loader，跳過 zplug 每次啟動的
# 偵測與 parse（~250ms）；宣告檔或 zplug cache 較新時才走完整 zplug load 並重建。
__zplug_static="$HOME/.zplug/static-load.zsh"
__zplug_build_static() {
  local k line tmp="$__zplug_static.$$"
  local -a words
  # cache 被清空時（例如 git pull 途中啟動 shell）不可產生空 loader，
  # 否則它比所有來源都新，之後每個 shell 都會沿用而載不到 theme。
  [[ -s $_zplug_cache[plugin] && -s $_zplug_cache[theme] ]] || return 2
  {
    print -r -- "# Generated from ~/.zplug/cache by .zshrc; do not edit."
    [[ -n $ZSH ]] && print -r -- "export ZSH=${(q)ZSH} ZSH_CACHE_DIR=${(q)ZSH_CACHE_DIR}"
    print -r -- "fpath=(${(j: :)${(@qf)"$(<$_zplug_cache[fpath])"}} \$fpath)"
    # 同 zplug init：先用既有 dump 讓 compdef 可用，defer 點再完整 compinit
    print -r -- "autoload -Uz compinit && compinit -C -d ${(q)ZPLUG_HOME}/zcompdump"
    for k in plugin lazy_plugin theme command defer_1_plugin compinit defer_2_plugin defer_3_plugin; do
      if [[ $k == compinit ]]; then
        print -r -- "setopt prompt_subst"
        print -r -- "compinit -d ${(q)ZPLUG_HOME}/zcompdump"
        continue
      fi
      for line in "${(@f)"$(<$_zplug_cache[$k])"}"; do
        [[ -z $line ]] && continue
        [[ $line == *--hook* || $line == *--lazy* ]] && return 1
        words=(${(z)line})
        case $words[1] in
          __zplug::core::load::as_plugin|__zplug::core::load::as_theme)
            print -r -- "source ${words[-1]}" ;;
          __zplug::core::load::as_command) ;;  # symlink 已由 zplug load 建好
          *) return 1 ;;
        esac
      done
    done
  } >| "$tmp" && mv -f "$tmp" "$__zplug_static"
}
if [[ -r $__zplug_static && $__zplug_static -nt $ZPLUG_LOADFILE && $__zplug_static -nt ${${(%):-%x}:A} \
   && $__zplug_static -nt $HOME/.zplug/cache/plugin.zsh ]]; then
  source "$__zplug_static"
  zplug() { unfunction zplug; source ~/.zplug/init.zsh && zplug "$@" }
else
  source ~/.zplug/init.zsh
  zplug load && {
    __zplug_build_static
    case $? in
      0) ;;
      2) rm -f "$__zplug_static" "$HOME"/.zplug/cache/*(N.) ;;  # 空 cache：下個 shell 重新產生
      *) rm -f "$__zplug_static" "$__zplug_static".* ;;
    esac
  }
fi
unset -f __zplug_build_static
unset __zplug_static

# search keybind
if (( $+widgets[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi

# Load p10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

## Modular environment: load snippets from ~/.zshrc.d/*.zsh
ZSHRC_D="$HOME/.zshrc.d"
if [ -d "$ZSHRC_D" ]; then
  setopt local_options no_nomatch
  for f in "$ZSHRC_D"/*.zsh; do
    [ -e "$f" ] || continue
    [ -r "$f" ] && . "$f"
  done
fi

# Load only the platform layer that matches the current Unix environment.
case "$(uname -s)" in
  Darwin)
    ZSH_PLATFORM="darwin"
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      ZSH_PLATFORM="wsl"
    else
      ZSH_PLATFORM="linux"
    fi
    ;;
esac
if [ -n "${ZSH_PLATFORM:-}" ] && [ -r "$ZSHRC_D/platform/$ZSH_PLATFORM.zsh" ]; then
  . "$ZSHRC_D/platform/$ZSH_PLATFORM.zsh"
fi
unset ZSH_PLATFORM
unset -f __zshrc_prepend_path 2>/dev/null
unset -f __zshrc_prepend_path_if_dir 2>/dev/null

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
