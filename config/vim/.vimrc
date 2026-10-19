" Neovim loads this file for the shared base only. Its plugin and mapping
" layer belongs to the Vim fallback below.
let s:shared_root = fnamemodify(resolve(expand('<sfile>:p')), ':h')
execute 'source ' . fnameescape(s:shared_root . '/base.vim')
unlet s:shared_root

if has('nvim')
  finish
endif

" =====================
"   Plugin Section
" =====================
call plug#begin('~/.vim/plugged')

" Plug 'VundleVim/Vundle.vim'

" lightline faq airline
Plug 'itchyny/lightline.vim'
Plug 'itchyny/vim-gitbranch'

" Git: gutter signs、GitLens 風格 inline blame、完整 blame
Plug 'airblade/vim-gitgutter'
if has('textprop')
  Plug 'APZelos/blamer.nvim'
endif
Plug 'tpope/vim-fugitive'
Plug 'christoomey/vim-tmux-navigator'
" 新版用了 `..` 語法，Vim 8.1.1114 以前不支援
if has('patch-8.1.1114')
  Plug 'mengelbrecht/lightline-bufferline'
endif
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
" Plug 'jiangmiao/auto-pairs'  " 已改用 mini.pairs (init.lua)
" Plug 'zxqfl/tabnine-vim'

Plug 'posva/vim-vue'
Plug 'leafOfTree/vim-vue-plugin'

" vim scheme
" Plug 'sheerun/vim-wombat-scheme'
Plug 'rakr/vim-one'
Plug 'altercation/solarized'
" Plug 'chuling/equinusocio-material.vim'
Plug 'yunlingz/ci_dark'
" Plug 'kjssad/quantum.vim'
Plug 'sainnhe/edge'

" Fuzzy Finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

call plug#end()

" =====================
"   Vim-only Settings
" =====================
set cindent
set guifont=Uni2-Terminus16
set laststatus=2
set showtabline=2
set smarttab
set t_Co=256
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"


" =====================
"   VIM AutoCmd
" =====================

" Change different tabspace setting for different language

" 統一所有語言 tab 設定為 4 格
augroup tab4
  autocmd!
  autocmd FileType * setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
augroup END

" filetype alias
au BufRead,BufNewFile *.ino set filetype=cpp
au BufRead,BufNewFile *.sage set filetype=python

" display
set background=dark
let g:edge_style = 'neon'
let g:edge_enable_italic = 1
let g:edge_disable_italic_comment = 1
set fillchars+=vert:│
let g:ci_dark_enable_bold = 1
colorscheme ci_dark
hi LineNr cterm=bold ctermfg=DarkGrey ctermbg=NONE
hi CursorLinNr cterm=bold ctermfg=Green ctermbg=NONE

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

autocmd FileType cpp call DefaultCode()
fu! DefaultCode()
  if readfile(fnameescape(expand('%'))) == []
    exec "0r ~/dotfile/template/template.cpp"
    normal! gg
  endif
endf

" =====================
"   Plugin Settings
" =====================

" christoomey/vim-tmux-navigator（Ctrl-h/j/k/l 由 keymaps.vim 的 MiyagoNavigate 處理）
let g:tmux_navigator_no_mappings = 1

" Yggdroot/indentLine
let g:indentLine_char_list=['|', '¦', '┆', '┊']
set list lcs=tab:\|\ ,trail:·
let g:indentLine_bufNameExclude=['_.*', 'NERD_tree.*']


" NerdTree settings 
nnoremap <silent> <F4> :NERDTree<CR>
autocmd VimEnter * if exists(':NERDTree') | execute 'NERDTree | wincmd p' | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

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
fu! NERDCommenter_before()
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
endfu

fu! NERDCommenter_after()
    if g:ft == 'vue'
        setf vue
        let g:ft = ''
    endif
endfu

let g:NERDTreeGitStatusUseNerdFonts=1
let g:NERDTreeGitStatusShowIgnored=1

" vim-devicons
let g:webdevicons_conceal_nerdtree_brackets=1



" itchyny/lightline.vim
let g:lightline = {
\   'colorscheme': 'edge',
\   'separator': {'left': '', 'right': ''},
\   'subseparator': {'left': '', 'right': ''},
\   'active': {
\       'left': [
\           ['mode', 'paste'],
\           ['gitbranch', 'readonly', 'filename', 'modified'],
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
\       'gitbranch': 'gitbranch#name'
\   },
\   'component_raw': {
\       'buffers': 1
\   }
\ }

if !has('patch-8.1.1114')
  call remove(g:lightline, 'tabline')
endif

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

" maximbaz/lightline-ale
let g:lightline#ale#indicator_checking=" "
let g:lightline#ale#indicator_warnings=""
let g:lightline#ale#indicator_errors="✗"
let g:lightline#ale#indicator_ok="✓"


" maximbaz/lightline-trailing-whitespace
let g:lightline#trailing_whitespace#indicator = '•'

" rainbow
let g:rainbow_active=1
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
call MiyagoMap('n', ']d', '<Plug>(ale_next_wrap)', 'Next diagnostic', 'remap')
call MiyagoMap('n', '[d', '<Plug>(ale_previous_wrap)', 'Previous diagnostic', 'remap')


" for Vue
let g:vue_pre_processors=['pug', 'scss']


" leafOfTree/vim-vue-plugin
let g:vim_vue_plugin_use_pug=1
let g:vim_vue_plugin_use_scss=1
let g:vim_vue_plugin_highlight_vue_attr=1
let g:vim_vue_plugin_highlight_vue_keyword=1


" Insert completion fallback
" 只用 Vim 內建補全（不依賴 Node/coc）；新版自動彈出，舊版用 Ctrl-N 手動觸發
set completeopt=menuone,noinsert
set shortmess+=c
if exists('+autocomplete')
  set autocomplete
endif


" 上下鍵選擇補全項；無補全選單時，第一行／最後一行跳到行首／行尾（同 Nvim completion.lua）
inoremap <silent><expr> <Up> pumvisible() ? "\<C-p>" : line('.') == 1 ? "\<Home>" : "\<Up>"
inoremap <silent><expr> <Down> pumvisible() ? "\<C-n>" : line('.') == line('$') ? "\<End>" : "\<Down>"

" execution/compilation utils
fu! CompileRunGcc()
    exec "w"
    if &filetype == 'cpp' || &filetype == 'c'
        exec "!rc -s %"
    endif
endf

command Q q!
command Wq wq
command WQ wq

"
nnoremap <F1> :call Change_Background()<CR>
nnoremap <F3> :set nu!<BAR>set nonu?<CR>
nnoremap <F4> :NERDTreeToggle<CR>
nnoremap <F7> <ESC>:w<CR>:!python %<CR>
nnoremap <F8> <ESC>:w<CR>:!python3 %<CR>
nnoremap <F9> <ESC>:w<CR>:call CompileRunGcc()<CR>
nnoremap <F10> <ESC>:w<CR>:call CompileRunGcc()<CR>
nnoremap <C-,> <ESC>:terminal<CR>

" 共用 VSCode 風格 keymap 在 keymaps.vim；以下只放依賴 Vim 外掛的 map
call MiyagoMap('n', '<C-p>', ':Files<CR>', 'Find files')
call MiyagoMap('n', '<leader>p', ':call MiyagoKeys()<CR>', 'Search keymaps')
call MiyagoMap('n', '<leader>?', ':call MiyagoKeys()<CR>', 'Search keymaps')

" F12 (Go to definition) 替代 (原生 vim 跳轉)
call MiyagoMap('n', '<leader>gd', '<C-]>', 'Jump to tag definition')
call MiyagoMap('n', '<F12>', '<C-]>', 'Jump to tag definition')

" Git（與 Nvim 的 <leader>g* 對齊）
let g:blamer_enabled=1
let g:blamer_delay=300
let g:blamer_prefix='   '
let g:blamer_template='<author>, <author-time> • <summary>'
let g:blamer_relative_time=1
" 全域搜尋（與 Nvim 的 <leader>f* 對齊）；沒有 rg 的舊系統退回內建 grep + quickfix
call MiyagoMap('n', '<leader>ff', ':Files<CR>', 'Find files')
call MiyagoMap('n', '<leader>fb', ':Buffers<CR>', 'Find buffers')
call MiyagoMap('n', '<leader>fr', ':History<CR>', 'Recent files')
if executable('rg')
  call MiyagoMap('n', '<leader>fg', ':Rg<CR>', 'Live grep')
  call MiyagoMap('n', '<leader>fw', ':Rg <C-r><C-w><CR>', 'Grep word under cursor')
else
  call MiyagoMap('n', '<leader>fg', ':grep! -rnI --exclude-dir=.git  .<Left><Left>', 'Live grep', 'loud')
  call MiyagoMap('n', '<leader>fw', ':grep! -rnI --exclude-dir=.git <C-r><C-w> .<CR>:copen<CR>', 'Grep word under cursor', 'loud')
endif

call MiyagoMap('n', '<leader>gB', ':Git blame<CR>', 'Git blame')
call MiyagoMap('n', '<leader>gp', ':GitGutterPreviewHunk<CR>', 'Preview hunk')
call MiyagoMap('n', '<leader>gt', ':BlamerToggle<CR>', 'Toggle inline blame')
call MiyagoMap('n', ']h', '<Plug>(GitGutterNextHunk)', 'Next hunk', 'remap')
call MiyagoMap('n', '[h', '<Plug>(GitGutterPrevHunk)', 'Previous hunk', 'remap')

" Sudo save when forgot to use sudo
" Use :W! to save with sudo
command! W w !sudo tee % > /dev/null

" Ctrl+/ 註解（nerdcommenter）；多數 terminal 把 Ctrl-/ 送成 Ctrl-_
for s:lhs in ['<C-/>', '<C-_>']
  call MiyagoMap('nx', s:lhs, '<Plug>NERDCommenterToggle', 'Toggle comment', 'remap')
  call MiyagoMap('i', s:lhs, '<Esc><Plug>NERDCommenterToggle gi', 'Toggle comment', 'remap')
endfor
unlet s:lhs
call MiyagoMap('n', '<C-e>', ':NERDTreeToggle<CR>', 'Toggle file tree')
