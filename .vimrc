set nocompatible
filetype off

" set plugin
set rtp+=~/.vim/bundle/Vundle.vim/
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

" lightline faq airline
Plugin 'itchyny/lightline.vim'
Plugin 'itchyny/vim-gitbranch'

" Syntax Highlighting
Plugin 'octol/vim-cpp-enhanced-highlight'
Plugin 'jelera/vim-javascript-syntax'

" Coding
Plugin 'preservim/nerdtree' 
Plugin 'Yggdroot/indentLine'
Plugin 'luochen1990/rainbow'
Plugin 'alvan/vim-closetag'
Plugin 'dense-analysis/ale'

" wombat scheme
Plugin 'sheerun/vim-wombat-scheme'


call vundle#end()
filetype plugin indent on

set nu rnu
set ai
set mouse=a
set ruler cursorline
set scrolloff=5
set tabstop=4
set shiftwidth=4
set autoindent smartindent cindent
set sw=2 sts=2 ts=2
set noshowmode
set showcmd
set encoding=utf-8
set fileencodings=utf-8,big5,euc-jp,euc-kr,latin1
set hlsearch
set incsearch
set guifont=Uni2-Terminus16
set laststatus=2
set expandtab smarttab
set wildmenu
set t_Co=256
set paste

" different setting for different language
au Filetype c,cpp setlocal ts=4 sw=4 sts=4 noexpandtab
au Filetype javascript setlocal ts=2 sw=2 sts=2 expandtab

syntax enable
syntax on
colorscheme wombat
set bg=dark
hi LineNr cterm=bold ctermfg=DarkGrey ctermbg=NONE
hi CursorLinNr cterm=bold ctermfg=Green ctermbg=NONE

" fu! s:transparent_background()
"     highlight Normal guibg=None ctermbg=None
"     highlight NonText guibg=None ctermbg=None
" endf
" autocmd colorscheme * call s:transparent_background()

nnoremap <silent> <F5> :NERDTree<CR>

autocmd FileType cpp call DefaultCode()
fu! DefaultCode()
  if line("$") == 1
    call append(0, "#include <bits/stdc++.h>")
    call append(1, "#define IO ios::sync_with_stdio(0);cin.tie(0)")
    call append(2, "#define endl '\\n'")
    call append(3, "#define MAXN maxn")
    call append(4, "")
    call append(5, "using namespace std;")
    call append(6, "")
    call append(7, "")
    call append(8, "")
    call append(9, "signed main()")
    call append(10, "{")
    call append(11, "\tIO;")
    call append(12, "")
    call append(13, "\treturn 0;")
    call append(14, "}")
  endif
endf

if !has('gui_running')
  set t_Co=256
endif

let g:lightline = {
\ 'colorscheme': 'wombat',
\ 'active': {
\   'left': [
\     [ 'mode', 'paste' ],
\     [ 'gitbranch', 'readonly', 'filename', 'modified' ]
\   ],
\   'right': [ 
\     [ 'lineinfo' ],
\     [ 'percent' ],
\     [ 'fileformat', 'fileencoding', 'filetype' ] 
\   ]
\ },
\ 'component_function': {
\   'gitbranch': 'gitbranch#name',
\   'fileformat': 'LightlineFileformat',
\   'fileencoding': 'LighterFileencoding',
\   'filetype': 'LightlineFiletype'
\ }
\ }

" rainbow
let g:ranbow_active=1

" closetag
let g:closetag_html_style='*.html,*.xhtml,*.phtml,*.ejs,*.vue'
let g:closetag_filetypes='html,xhtml,phtml,ejs,vue'

" cpp enhanced highlight
let g:cpp_class_scope_highlight=1
let g:cpp_member_variable_highlight=1
let g:cpp_class_decl_highlight=1
let g:cpp_posix_standard=1
let g:cpp_concepts_highlight=1
let c_no_curly_error=1

" ale
let g:ale_linters = {
\   'javascript': ['eslint', 'prettier'],
\   'css': ['prettier']
\ }

let g:ale_sign_column_always = 1

" lint only on save
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 0

" for Vue
let b:ale_linter_aliases = ['javascript', 'vue']

inoremap ( ()<Esc>i
inoremap " ""<Esc>i
inoremap ' ''<Esc>i
inoremap [ []<Esc>i
inoremap { {}<Esc>i
