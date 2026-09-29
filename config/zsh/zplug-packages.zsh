# zplug 宣告（ZPLUG_LOADFILE）。改完開新 shell 會自動重建 static loader；
# 新增 plugin 後手動跑 `zplug install`。
zplug "romkatv/powerlevel10k", as:theme, depth:1, use:powerlevel10k.zsh-theme
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-autosuggestions"
zplug "junegunn/fzf", from:github, as:command, hook-build:"./install --all"
zplug "Aloxaf/fzf-tab"
zplug "plugins/git", from:oh-my-zsh
zplug "zdharma-continuum/fast-syntax-highlighting", defer:2
zplug "zpm-zsh/ls"
zplug "plugins/docker", from:oh-my-zsh
zplug "plugins/composer", from:oh-my-zsh
zplug "plugins/extract", from:oh-my-zsh
zplug "lib/completion", from:oh-my-zsh
zplug "plugins/sudo", from:oh-my-zsh
