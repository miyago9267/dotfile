" Shared editor defaults for Vim and Neovim.

set nocompatible
filetype plugin indent on

set number
set autoindent
set nowrap
set mouse=a
set ruler
set cursorline
set scrolloff=5
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set smartindent
set noshowmode
set showcmd
set encoding=utf-8
set fileencodings=utf-8,big5,euc-jp,euc-kr,latin1
set fileformat=unix
set hlsearch
set incsearch
set wildmenu
set title
set cmdheight=2
set updatetime=300
set shortmess+=c
set whichwrap+=<,>,[,]
set signcolumn=yes
set splitbelow
set splitright
set shell=/bin/zsh

" Keep the habitual force-quit key available in both Vim and Neovim.
nnoremap Q :q!<CR>

if has('clipboard')
  set clipboard=unnamed
endif

if has('termguicolors')
  set termguicolors
endif

syntax enable
syntax on

augroup miyago_shared_editor
  autocmd!
  autocmd FileType * setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
  autocmd BufRead,BufNewFile *.ino setfiletype cpp
  autocmd BufRead,BufNewFile *.sage setfiletype python
augroup END
