call plug#begin('~/.local/share/nvim/plugged')

" language　auto-completion
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
" Plug 'davidhalter/jedi-vim'

" airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" auto-pair
Plug 'jiangmiao/auto-pairs'

" commenter
Plug 'scrooloose/nerdcommenter'

" Auto Layout format
" pip install yapf
Plug 'sbdchd/neoformat'

" 自動顯示定義處(Code Jump)
Plug 'davidhalter/jedi-vim'

" File Tree
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'kristijanhusak/defx-git'
Plug 'kristijanhusak/defx-icons'

" neomake
" pipenv install pylint
Plug 'neomake/neomake'

" multi cursor
" Plug 'terryma/vim-multiple-cursors'

" HighLight
Plug 'machakann/vim-highlightedyank'

" Code Fold
Plug 'tmhedberg/SimpylFold'

" Theme
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'
Plug 'itchyny/lightline.vim'
Plug 'sheerun/vim-polyglot'

call plug#end()


"--------------------------------------------------------------
" Setting
"--------------------------------------------------------------

filetype plugin indent on

set timeout timeoutlen=1500
set mouse=a
set nu rnu
set ai
set nowrap
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
set t_Co=256
set paste

au Filetype c,cpp,vim setlocal ts=4 sw=4 sts=4 noexpandtab
au Filetype javascript setlocal ts=2 sw=2 sts=2 expandtab

syntax enable
syntax on

"--------------------------------------------------------------


"--------------------------------------------------------------
" configure
"--------------------------------------------------------------

" auto-completion
"
let g:deoplete#enable_at_startup = 1

" automatically close the method preview window
autocmd InsertLeave, CompleteDone * if pumvisible() == 0 | pclose | endif

" Navigate through the auto-completion list with Tab key
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"

"
" Airline
"
let g:airline_theme='luna'


"
" Auto Layout Format
"

" Vim Command
" :Neoformat! [python [yapf]]

" Enable alignment
let g:neoformat_basic_format_align = 1

" Enable tab to spaces conversion
let g:neoformat_basic_format_retab = 1

" Enable trimming of trailing whitespace
let g:neoformat_basic_format_trim = 1

" Run a formatter on save
augroup fmt
	autocmd!
	autocmd BufWritePre * undojoin | Neoformat
augroup END


"
" Code Jump
"

" disable autocompletion, cause we use deoplete for completion
let g:jedi#completions_enabled = 0

" open the go-to function in split, not another buffer
let g:jedi#use_splits_not_buffers = 'right'


"
" defx vim
"
map <silent> <F4> :Defx<CR>
" Keymap in defx
autocmd FileType defx call s:defx_my_settings()
function! s:defx_my_settings() abort
	setl nospell
	setl signcolumn=no
	setl nonumber
	nnoremap <silent><buffer><expr> <CR>
				\ defx#is_directory() ?
				\ defx#do_action('open_or_close_tree') :
				\ defx#do_action('drop',)
	nmap <silent><buffer><expr> <2-LeftMouse>
				\ defx#is_directory() ?
				\ defx#do_action('open_or_close_tree') :
				\ defx#do_action('drop',)
	nnoremap <silent><buffer><expr> C defx#do_action('copy')
	nnoremap <silent><buffer><expr> P defx#do_action('paste')
	nnoremap <silent><buffer><expr> <F2> defx#do_action('rename')
	nnoremap <silent><buffer><expr> D defx#do_action('remove_trash')
	nnoremap <silent><buffer><expr> U defx#do_action('cd', ['..'])
	nnoremap <silent><buffer><expr> . defx#do_action('toggle_ignored_files')
	nnoremap <silent><buffer><expr> <C-r> defx#do_action('redraw')
endfunction

call defx#custom#option('_', {
			\ 'winwidth': 30,
			\ 'split': 'vertical',
			\ 'direction': 'topleft',
			\ 'show_ignored_files': 0,
			\ 'buffer_name': '',
			\ 'toggle': 1,
			\ 'resume': 1
			\ })

let g:defx_git#indicators = {
			\ 'Modified'  : '✹',
			\ 'Staged'    : '✚',
			\ 'Untracked' : '✭',
			\ 'Renamed'   : '➜',
			\ 'Unmerged'  : '═',
			\ 'Ignored'   : '☒',
			\ 'Deleted'   : '✖',
			\ 'Unknown'   : '?'
			\ }

let g:defx_git#column_length = 0

" Defx icons
" Requires nerd-font, install at https://github.com/ryanoasis/nerd-fonts or
" brew cask install font-hack-nerd-font
" Then set non-ascii font to Driod sans mono for powerline in iTerm2
" disbale syntax highlighting to prevent performence issue
let g:defx_icons_enable_syntax_highlight = 1

"
" Code check
"
" Vim Command:
"  - Neomake: Manually start syntax checking
"  - lwindow / lopen: Navigate them using the buil-in methods
"  - lprev / lnext : Go back and forth
"
"  pylint --generate-rcfile > ~/.pylintrc
"  Usage Ref: https://stackoverflow.com/questions/4341746/how-do-i-disable-a-pylint-warning/23542817#23542817

let g:neomake_python_enabled_makers = ['pylint']

" Open the list automatically
let g:neomake_open_list = 2

" enable automatical code check: normal mode (after 1s; no delay when writing)
call neomake#configure#automake('nrwi', 500)


"
" Highlight Copy
"

highlight HighlightedyankRegion cterm=reverse gui=reverse

" set highlight duration time to 1000 ms, i.e., 1 second
let g:highlightedyank_highlight_duration = 1000


let g:SimpylFold_docstring_preview = 1
let g:SimpylFold_fold_docstring = 0
let g:SimpylFold_fold_import = 0


"
" Theme
"

" support true color
set notermguicolors

" airline theme
set laststatus=2
if !has('gui_running')
	set t_Co=256
endif
set noshowmode
let g:lightline = {
			\ 'colorscheme': 'wombat',
			\ }
let g:airline_theme='tomorrow'

" gruvbox theme
colorscheme gruvbox
set background=dark
"set background=light


"
" Change background
"

let t:is_transparent_background=1
fu! Change_Background()
	if t:is_transparent_background == 0
		highlight Normal guibg=None ctermbg=None
		highlight NonText guibg=None ctermbg=None
		let t:is_transparent_background=1
	else
		colors wombat
		let t:is_transparent_background=0
	endif
endf
nnoremap <F1> :call Change_Background()<CR>

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
    call append(9, "signed main(){")
    call append(10, "")
    call append(11, "\tIO;")
    call append(12, "")
    call append(13, "\treturn 0;")
    call append(14, "}")
  endif
endf

