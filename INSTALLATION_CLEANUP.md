# 安裝過程中間檔案清理說明

## 已處理的中間檔案

### 1. **自動清理的檔案**（使用 `trap` 和臨時目錄）

以下腳本已更新為使用臨時目錄，執行完畢後自動刪除：

- ✅ `setup_fonts.sh` - 字型 `.ttf` 檔案
- ✅ `install_golang.sh` - Go 安裝包 `.tar.gz`
- ✅ `install_android_sdk.sh` - Android SDK `.zip` 檔案

### 2. **已加入 .gitignore 的檔案**

以下類型的檔案已加入 `.gitignore`，不會被追蹤：

#### 壓縮檔案
- `*.tar`
- `*.zip`
- `*.tar.gz`
- `*.tgz`
- `*.gz`
- `*.deb`
- `*.rpm`

#### 字型檔案
- `*.ttf`
- `*.otf`
- `*.woff`
- `*.woff2`

#### Vim/Neovim 備份檔案
- `*~`
- `*.swp`, `*.swo`, `*.swn`
- `.*.sw[a-z]`
- `Session.vim`
- `.netrwhist`

#### 外部依賴（安裝腳本建立的）
- `.tmux_gpakosz/` - tmux 配置
- `.pyenv/` - Python 版本管理
- `.nvm/` - Node 版本管理
- `.cargo/`, `.rustup/` - Rust 工具鏈
- `google-cloud-sdk/` - Google Cloud SDK
- `development/flutter/` - Flutter SDK
- `Library/Android/`, `Android/` - Android SDK

#### 臨時目錄
- `tmp/`
- `temp/`
- `*.tmp`

## 安裝後手動清理檢查清單

執行完所有安裝腳本後，建議檢查以下位置：

```bash
# 1. 檢查 home 目錄是否有殘留檔案
ls -la ~/ | grep -E '\.(tar|zip|gz|ttf)$'

# 2. 檢查是否有臨時目錄
ls -la ~/ | grep -E '^d.*tmp'

# 3. 清理 Vim/Neovim 備份檔案
find ~/dotfile -name '*.sw[a-z]' -o -name '*~' -o -name '*.bak'

# 4. 檢查 git 狀態
cd ~/dotfile && git status
```

## 建議的清理命令

如果發現有未被追蹤的中間檔案：

```bash
# 清理所有 git 未追蹤的檔案（謹慎使用！）
cd ~/dotfile
git clean -fd -X  # 只刪除 .gitignore 中的檔案
git clean -fdn    # 預覽會刪除什麼（不實際刪除）
```

## 注意事項

1. **不要將以下檔案加入 .gitignore**：
   - 配置檔案本身（`.vimrc`, `init.lua`, `.zshrc` 等）
   - 自訂腳本（`script/` 目錄）
   - 模板檔案（`template/` 目錄）

2. **定期檢查**：
   - 在提交前執行 `git status` 確認沒有不應該追蹤的檔案
   - 使用 `git ls-files --others --ignored --exclude-standard` 查看被忽略的檔案

3. **外部工具產生的檔案**：
   - CoC.nvim: `~/.config/coc/` (不在此 repo)
   - Lazy.nvim: `~/.local/share/nvim/lazy/` (不在此 repo)
   - Vim-plug: `~/.vim/plugged/` (不在此 repo)
