# PSReadLine 配置（替代 zsh-autosuggestions / zsh-history-substring-search / fast-syntax-highlighting）

if (-not (Get-Module PSReadLine -ListAvailable)) { return }

Import-Module PSReadLine

# -- 編輯模式 --
Set-PSReadLineOption -EditMode Emacs

# -- 歷史搜尋（對應 zsh-history-substring-search） --
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# -- 自動建議（對應 zsh-autosuggestions） --
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# -- 語法高亮色彩（對應 fast-syntax-highlighting） --
Set-PSReadLineOption -Colors @{
    Command   = 'DarkYellow'
    Parameter = 'DarkGray'
    String    = 'DarkGreen'
    Operator  = 'DarkCyan'
    Variable  = 'Green'
    Comment   = 'DarkGray'
    Keyword   = 'Magenta'
    Number    = 'Cyan'
    Type      = 'DarkYellow'
    Error     = 'Red'
}

# -- Tab 補全 --
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious

# -- 快捷鍵 --
# Ctrl+d 退出（對應 Zsh 預設行為）
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

# Ctrl+w 刪除前一個詞
Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord

# Ctrl+u 刪除到行首
Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine

# Ctrl+k 刪除到行尾
Set-PSReadLineKeyHandler -Key Ctrl+k -Function ForwardDeleteLine

# Ctrl+a 跳到行首
Set-PSReadLineKeyHandler -Key Ctrl+a -Function BeginningOfLine

# Ctrl+e 跳到行尾
Set-PSReadLineKeyHandler -Key Ctrl+e -Function EndOfLine

# Ctrl+r 反向搜尋歷史
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory
