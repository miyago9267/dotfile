set nocompatible
set nu rnu
set ai
set mouse=a
set ruler cursorline
set scrolloff=5
set tabstop=4
set shiftwidth=4
set sw=2 sts=2 ts=2
set noshowmode
set showcmd
set encoding=utf-8
set fileencodings=utf-8,big5,euc-jp,euc-kr,latin1
set hlsearch
set incsearch
set guifont=Uni2-Terminus16
set expandtab smarttab
set wildmenu
set t_Co=256
set paste

inoremap ( ()<Esc>i
inoremap " ""<Esc>i
inoremap ' ''<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i

filetype on
filetype indent on


syntax enable
syntax on
" color default
set bg=dark
hi LineNr cterm=bold ctermfg=DarkGrey ctermbg=NONE
hi CursorLinNr cterm=bold ctermfg=Green ctermbg=NONE


let g:ranbow_active=1
