# 別名與常用 function（對應 alias.sh）

# -- 安全操作 --
function rm-i { Remove-Item -Confirm @args }
function cp-r { Copy-Item -Recurse -Confirm @args }
function mv-i { Move-Item -Confirm @args }

# -- 目錄列表 --
Set-Alias -Name l -Value Get-ChildItem
function ll { Get-ChildItem -Force @args }

# -- 編輯器 --
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias -Name nv -Value nvim
    Set-Alias -Name vim -Value nvim
}

# -- 清除畫面 --
Set-Alias -Name clr -Value Clear-Host

# -- 語言 runtime 捷徑 --
if (Get-Command uv -ErrorAction SilentlyContinue) {
    function py { uv run python @args }
    function uvr { uv run @args }
    function uvp { uv run python @args }
}

if (Get-Command go -ErrorAction SilentlyContinue) {
    function god { go @args }
}

if (Get-Command poetry -ErrorAction SilentlyContinue) {
    function ptr { poetry run @args }
}

# -- 磁碟用量（人類可讀） --
function duf {
    if (Get-Command dust -ErrorAction SilentlyContinue) {
        dust -d 1 @args
    } else {
        Get-ChildItem -Force @args |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Size = if ($_.PSIsContainer) { '(dir)' } else { '{0:N2} MB' -f ($_.Length / 1MB) }
                }
            } | Format-Table -AutoSize
    }
}

# -- Windows 專屬 --
function flushdns { ipconfig /flushdns }

# -- scoop 更新 --
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    function scoopup { scoop update; scoop update --all; scoop cleanup --all }
}

# -- Git 捷徑（對應 oh-my-zsh git plugin 常用的） --
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gst { git status @args }
    function gd { git diff @args }
    function gds { git diff --staged @args }
    function ga { git add @args }
    function gc { git commit @args }
    function gp { git push @args }
    function gl { git pull @args }
    function gco { git checkout @args }
    function gsw { git switch @args }
    function gb { git branch @args }
    function glog { git log --oneline --graph --decorate -20 @args }
}
