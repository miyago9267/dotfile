let g:ale_disable_lsp = 1

call plug#begin('~/.vim/plugged')

" Plug 'VundleVim/Vundle.vim'

" lightline faq airline
Plug 'itchyny/lightline.vim'
Plug 'itchyny/vim-gitbranch'
Plug 'mengelbrecht/lightline-bufferline'
Plug 'maximbaz/lightline-ale'
Plug 'maximbaz/lightline-trailing-whitespace'

" Syntax Highlighting
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'jelera/vim-javascript-syntax'

" Nerdtree
Plug 'preservim/nerdtree' 
Plug 'scrooloose/nerdcommenter'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" Coding
Plug 'Yggdroot/indentLine'
Plug 'luochen1990/rainbow'
Plug 'alvan/vim-closetag'
Plug 'dense-analysis/ale'
Plug 'jiangmiao/auto-pairs'
Plug 'zxqfl/tabnine-vim'

Plug 'posva/vim-vue'
Plug 'leafOfTree/vim-vue-plugin'

" vim scheme
" Plug 'sheerun/vim-wombat-scheme'
Plug 'rakr/vim-one'
Plug 'altercation/solarized'
" Plug 'chuling/equinusocio-material.vim'
Plug 'yunlingz/ci_dark'
Plug 'kjssad/quantum.vim'
Plug 'sainnhe/edge'

" NeoVim
Plug 'scrooloose/syntastic'
Plug 'neoclide/coc.nvim', {'branch': 'master'}
Plug 'majutsushi/tagbar'
Plug 'ap/vim-css-color'

call plug#end()

filetype plugin indent on

" global setting

set nu rnu
set ai
set nowrap
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
set clipboard=unnamed
set fileencodings=utf-8,big5,euc-jp,euc-kr,latin1
set fileformat=unix
set hlsearch
set incsearch
set guifont=Uni2-Terminus16
set laststatus=2
set expandtab smarttab
set wildmenu
set title
set cmdheight=2
set showtabline=2
set updatetime=300
set shortmess+=c
set signcolumn=yes
set splitbelow splitright
set t_Co=256
set paste
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"

syntax enable
syntax on


if has('termguicolors')
    set termguicolors
endif


" nvim hahapeeyen
if has('nvim')
    let s:editor_root=expand('~/.config/nvim')
else
    let s:editor_root=expand('~/.vim')
endif

"""""""""""""""""""""""""""""
"" vim convenience setting ""
"""""""""""""""""""""""""""""

" Change different tabspace setting for different language
au Filetype c,cpp setlocal ts=4 sw=4 sts=4 noexpandtab
au Filetype php setlocal ts=4 sw=4 sts=4 expandtab
au Filetype javascript,vue setlocal ts=2 sw=2 sts=2 expandtab
au Filetype vim setlocal ts=4 sw=4 sts=4 expandtab
au Filetype cs setlocal ts=4 sw=4 sts=4 expandtab
au Filetype make setlocal ts=4 sw=4 sts=4 noexpandtab

" filetype alias
au BufRead,BufNewFile *.ino set filetype=cpp
au BufRead,BufNewFile *.sage set filetype=python

" display
let g:ale_disable_lsp = 1
set background=dark
let g:edge_style = 'neon'
let g:edge_enable_italic = 1
let g:edge_disable_italic_comment = 1
set fillchars+=vert:│
let g:ci_dark_enable_bold = 1
colorscheme ci_dark
let g:airline_theme = 'edge'
hi LineNr cterm=bold ctermfg=DarkGrey ctermbg=NONE
hi CursorLinNr cterm=bold ctermfg=Green ctermbg=NONE


" execution/compilation utils
nnoremap <silent>Q <ESC>:q!<CR>
nnoremap <C-F> <ESC>/
nnoremap <F7> <ESC>:w<CR>:!python %<CR>
nnoremap <F8> <ESC>:w<CR>:!python3 %<CR>
nnoremap <F9> <ESC>:w<CR>:!g++ -std=c++17 -O2 -Wall -Wextra -Wshadow %<CR>
nnoremap <C-,> <ESC>:terminal<CR>


" Monika Waifuuuuu
" Change Background to invisible or one theme (Copy from CSY54)
let t:is_transparent_background=1
fu! Change_Background()
  if t:is_transparent_background == 0
    highlight Normal guibg=NONE ctermbg=NONE
    let t:is_transparent_background=1
  else
    colors ci_dark
    let t:is_transparent_background=0
  endif
endf
nnoremap <F1> :call Change_Background()<CR>


autocmd FileType cpp call DefaultCode()
fu! DefaultCode()
  if line("$") == 1
    call append(0, "// By myg9267")
    call append(1, "// i m bad in coding, so sad")
    call append(2, "// it a me mario")
    call append(3, "#include <bits/stdc++.h>")
    call append(4, "#pragma GCC optimize("O1")")
    call append(5, "#pragma GCC optimize("O2")")
    call append(6, "#pragma GCC optimize("O3")")
    call append(7, "#define endl "\n"")
    call append(8, "#define endll "\n\n"")
    call append(9, "#define pb emplace_back")
    call append(10, "#define IO ios_base::sync_with_stdio(0);cin.tie(0);cout.sync_with_stdio(0)")
    call append(11, "#define ll long long")
    call append(12, "#define MAXN maxn")
    call append(13, "#define MODN modn")
    call append(14, "")
    call append(15, "using namespace std;")
    call append(16, "")
    call append(17, "class Solution{")
    call append(18, "    public:")
    call append(19, "")
    call append(20, "    private:")
    call append(21, "    ")
    call append(22, "};")
    call append(23, "")
    call append(24, "signed main(){")
    call append(25, "    IO;")
    call append(26, "    #ifdef DEBUG")
    call append(27, "		freopen("p.in", "r", stdin);")
    call append(28, "		freopen("p.out", "w", stdout);")
    call append(29, "	#endif")
    call append(30, "    return EXIT_SUCCESS;")
    call append(31, "}")
  endif
endf

"""""""""""""""
"""  Plugin """
"""""""""""""""

" Yggdroot/indentLine
let g:indentLine_char_list=['|', '¦', '┆', '┊']
set list lcs=tab:\|\ ,trail:·
let g:indentLine_bufNameExclude=['_.*', 'NERD_tree.*']

" scrooloose/syntastic

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_cpp_compiler = 'g++'
let g:syntastic_cpp_compiler_options = ' -std=c++2a --stdlib=libc++'


" NerdTree settings 
nnoremap <silent> <F4> :NERDTree<CR>
autocmd VimEnter * NERDTree | wincmd p " Open on startup and focus on the opened file
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" coc setting
" so ~/.config/nvim/coc-config.vim

" UI setting
" let NERDTreeMinimalUI=1
let NERDTreeShowHidden=1

" nerdcommenter setting
let g:NERDSpaceDelims=1
let g:NERDDefaultAlign='left'
let g:NERDCommentEmptyLines=1
let g:NERDTrimTrailingWhitespace=1
let g:NERDToggleCheckAllLines=1


let g:ft = ''
function! NERDCommenter_before()
    if &ft == 'vue'
        let g:ft = 'vue'
        let stack = synstack(line('.'), col('.'))
        if len(stack) > 0
            let syn = synIDattr((stack)[0], 'name')
            if len(syn) > 0
                exe 'setf ' . substitute(tolower(syn), '^vue_', '', '')
            endif
        endif
    endif
endfunction

function! NERDCommenter_after()
    if g:ft == 'vue'
        setf vue
        let g:ft = ''
    endif
endfunction

let g:NERDTreeGitStatusUseNerdFonts=1
let g:NERDTreeGitStatusShowIgnored=1

" vim-devicons
let g:webdevicons_conceal_nerdtree_brackets=1
if exists('g:loaded_webdevicons')
    call webdevicons#refresh()
endif


if !has('gui_running')
  set t_Co=256
endif

" itchyny/lightline.vim
let g:lightline = {
\   'colorscheme': 'edge',
\   'separator': {'left': '', 'right': ''},
\   'subseparator': {'left': '', 'right': ''},
\   'active': {
\       'left': [
\           ['mode', 'paste'],
\           ['gitbranch', 'cocstatus', 'currentfunction', 'readonly', 'filename', 'modified'],
\       ],
\       'right': [
\           ['percent', 'lineinfo'],
\           ['fileformat', 'fileencoding', 'filetype'],
\           ['linter_checking', 'linter_errors', 'linter_warnings', 'linter_ok', 'trailing']
\       ]
\   },
\   'tabline': {
\       'left': [
\           ['buffers']
\       ],
\       'right': [
\           ['close']
\       ]
\   },
\   'component_expand': {
\       'buffers': 'lightline#bufferline#buffers',
\       'trailing': 'lightline#trailing_whitespace#component',
\       'linter_checking': 'lightline#ale#checking',
\       'linter_warnings': 'lightline#ale#warnings',
\       'linter_errors': 'lightline#ale#errors',
\       'linter_ok': 'lightline#ale#ok'
\   },
\   'component_type': {
\       'buffers': 'tabsel',
\       'trailing': 'error',
\       'linter_checking': 'right',
\       'linter_warnings': 'warning',
\       'linter_errors': 'error',
\       'linter_ok': 'right'
\   },
\   'component_function': {
\       'readonly': 'LightlineReadonly',
\       'gitbranch': 'gitbranch#name',
\       'cocstatus': 'coc#status',
\       'currentfunction': 'CocCurrentFunction'
\   },
\   'component_raw': {
\       'buffers': 1
\   }
\ }

fu! LightlineReadonly()
  return &readonly ? '' : ''
endfu


" mengelbrecht/lightline-bufferline
let g:lightline#bufferline#filename_modifier=':~:.'
let g:lightline#bufferline#shorten_path=1
let g:lightline#bufferline#show_number=2
let g:lightline#bufferline#number_map={
\   0: '₀', 1: '₁', 2: '₂', 3: '₃', 4: '₄',
\   5: '₅', 6: '₆', 7: '₇', 8: '₈', 9: '₉'
\ }
let g:lightline#bufferline#unnamed='[No Name]'
let g:lightline#bufferline#enable_devicons=1
let g:lightline#bufferline#unicode_symbols=1
let g:lightline#bufferline#clickable=1

nmap <Leader>1 <Plug>lightline#bufferline#go(1)
nmap <Leader>2 <Plug>lightline#bufferline#go(2)
nmap <Leader>3 <Plug>lightline#bufferline#go(3)
nmap <Leader>4 <Plug>lightline#bufferline#go(4)
nmap <Leader>5 <Plug>lightline#bufferline#go(5)
nmap <Leader>6 <Plug>lightline#bufferline#go(6)
nmap <Leader>7 <Plug>lightline#bufferline#go(7)
nmap <Leader>8 <Plug>lightline#bufferline#go(8)
nmap <Leader>9 <Plug>lightline#bufferline#go(9)
nmap <Leader>0 <Plug>lightline#bufferline#go(10)

nmap <Leader>c1 <Plug>lightline#bufferline#delete(1)
nmap <Leader>c2 <Plug>lightline#bufferline#delete(2)
nmap <Leader>c3 <Plug>lightline#bufferline#delete(3)
nmap <Leader>c4 <Plug>lightline#bufferline#delete(4)
nmap <Leader>c5 <Plug>lightline#bufferline#delete(5)
nmap <Leader>c6 <Plug>lightline#bufferline#delete(6)
nmap <Leader>c7 <Plug>lightline#bufferline#delete(7)
nmap <Leader>c8 <Plug>lightline#bufferline#delete(8)
nmap <Leader>c9 <Plug>lightline#bufferline#delete(9)
nmap <Leader>c0 <Plug>lightline#bufferline#delete(10)

" maximbaz/lightline-ale
let g:lightline#ale#indicator_checking=" "
let g:lightline#ale#indicator_warnings=""
let g:lightline#ale#indicator_errors="✗"
let g:lightline#ale#indicator_ok="✓"


" maximbaz/lightline-trailing-whitespace
let g:lightline#trailing_whitespace#indicator = '•'

" rainbow
let g:ranbow_active=1
let g:rainbow_conf={
\   'guifgs': ['lightred', 'lightgreen', 'lightcyan', 'lightmagenta'],
\   'ctermfgs': ['lightred', 'lightyellow', 'lightcyan', 'lightmagenta'],
\   'separately': {
\       'nerdtree': 0
\   }
\ }

" closetag
let g:closetag_html_style='*.html,*.ejs,*.vue,*.blade.php'
let g:closetag_filetypes='html,ejs,vue,blade'

" editorconfig-vim
au FileType gitcommit let b:EditorConfig_disable=1

" cpp enhanced highlight
let g:cpp_class_scope_highlight=1
let g:cpp_member_variable_highlight=1
let g:cpp_class_decl_highlight=1
let g:cpp_posix_standard=1
let g:cpp_concepts_highlight=1
let c_no_curly_error=1


" dense-analysis/ale (Copy from CSY54)
let g:ale_linter_aliases={
\   'vue': ['vue', 'javascript']
\ }
let g:ale_linters={
\   'javascript': ['eslint', 'prettier'],
\   'css': ['prettier'],
\   'vue': ['eslint', 'vls']
\ }

let g:ale_pattern_options={
\   '\.min\.js$': {'ale_linters': [], 'ale_fixers': []},
\   '\.min\.css$': {'ale_linters': [], 'ale_fixers': []}
\}
let g:ale_fixers={
\   'javascript': ['eslint'],
\   'vue': ['eslint']
\ }
let g:ale_linters_explicit=1
let g:ale_sign_column_always=1
let g:ale_sign_error='✗'
let g:ale_sign_warning=''
let g:ale_sign_style_error='⚡'
let g:ale_sign_style_warning='⚡'
let g:ale_echo_msg_error_str='✗'
let g:ale_echo_msg_warning_str=''
let g:ale_echo_msg_format='[%linter%] [%severity%] %s'
let g:ale_lint_on_text_changed='never'
let g:ale_lint_on_insert_leave=0
let g:ale_lint_on_enter=0
let g:ale_fix_on_save=1
let g:ale_floating_preview=1
let g:ale_hover_to_floating_preview=1
let g:ale_detail_to_floating_preview=1
let g:ale_cursor_detail=1
let g:ale_hover_cursor=1
let g:ale_close_preview_on_insert=1
nmap <silent> <leader>k <Plug>(ale_previous_wrap)
nmap <silent> <leader>j <Plug>(ale_next_wrap)

" lint only on save
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 0

" for Vue
let b:ale_linter_aliases = ['javascript', 'vue']
let g:vue_pre_processors=['pug', 'scss']


" leafOfTree/vim-vue-plugin
let g:vim_vue_plugin_use_pug=1
let g:vim_vue_plugin_use_scss=1
let g:vim_vue_plugin_highlight_vue_attr=1
let g:vim_vue_plugin_highlight_vue_keyword=1

" neoclide/coc.nvim
" <TAB> navigation
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() : "\<C-g>u\<CR>"
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ coc#refresh()

function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
endfunction


" majutsushi/tagbar
let g:SuperTabMappingForward='<s-tab>'
let g:SuperTabMappingBackward='<tab>'

" closetag 
" inoremap ( ()<Esc>i
" inoremap " ""<Esc>i
" inoremap ' ''<Esc>i
" inoremap [ []<Esc>i
" inoremap { {}<Esc>i
