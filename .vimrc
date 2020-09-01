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
