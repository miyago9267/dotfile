" Shared VSCode-style keymaps for Vim and Neovim (Windows/Linux VSCode, Ctrl-based).
"
" MiyagoMap() records every mapping with a description in g:miyago_keymaps.
" Vim applies it immediately; Neovim applies it in lua/config/keymaps.lua so
" which-key and the palette show the description. Space p lists the table.
" Keys owned by tmux (Ctrl-a, Ctrl-b) and Ghostty (Cmd-*, Ctrl-`) stay unmapped.
"
" Flags (optional 5th argument, space separated):
"   expr   rhs is an expression
"   remap  rhs uses other mappings
"   loud   not <silent>; needed when rhs leaves text in the command line

let mapleader = ' '
let maplocalleader = ' '
let g:miyago_keymaps = []

function! MiyagoMap(modes, lhs, rhs, desc, ...) abort
  let flags = split(get(a:, 1, ''))
  let entry = {'modes': a:modes, 'lhs': a:lhs, 'rhs': a:rhs, 'desc': a:desc,
        \ 'expr': index(flags, 'expr') >= 0, 'remap': index(flags, 'remap') >= 0,
        \ 'loud': index(flags, 'loud') >= 0}
  call add(g:miyago_keymaps, entry)
  if has('nvim')
    return
  endif
  for mode in split(a:modes, '\zs')
    execute mode . (entry.remap ? 'map' : 'noremap')
          \ . (entry.loud ? '' : ' <silent>') . (entry.expr ? ' <expr>' : '')
          \ . ' ' . a:lhs . ' ' . a:rhs
  endfor
endfunction

function! MiyagoNavigate(dir) abort
  let name = 'TmuxNavigate' . {'h': 'Left', 'j': 'Down', 'k': 'Up', 'l': 'Right'}[a:dir]
  if exists(':' . name) == 2
    execute name
  else
    execute 'wincmd ' . a:dir
  endif
endfunction

function! MiyagoZoom() abort
  if exists('t:miyago_zoom')
    execute t:miyago_zoom
    unlet t:miyago_zoom
    return
  endif
  let t:miyago_zoom = winrestcmd()
  wincmd _
  wincmd |
endfunction

" Space p in Vim: fzf list of the table (Enter runs normal-mode entries).
" Neovim uses fzf-lua keymaps instead, which reads the same descriptions.
function! MiyagoKeys() abort
  let lines = map(copy(g:miyago_keymaps), {_, k -> printf('%-4s %-16s %s', k.modes, k.lhs, k.desc)})
  if exists('*fzf#run')
    call fzf#run(fzf#wrap({'source': lines, 'sink': function('s:run_key'),
          \ 'options': ['--prompt', 'Keys> ']}))
  else
    echo join(lines, "\n")
  endif
endfunction

function! s:run_key(line) abort
  let [modes, lhs] = split(a:line)[0:1]
  if modes !~# 'n'
    return
  endif
  let lhs = substitute(lhs, '\c<leader>', escape(g:mapleader, '\'), 'g')
  call feedkeys(eval('"' . substitute(lhs, '<\([^>]\+\)>', '\\<\1>', 'g') . '"'), 'm')
endfunction

" =====================
"   Editing
" =====================
" j/k swapped (Miyago's habit); first/last line jumps to line start/end like VSCode
call MiyagoMap('nx', 'j', "line('.') == 1 && v:count <= 1 ? '0' : 'k'", 'Move up', 'expr')
call MiyagoMap('nx', 'k', "line('.') == line('$') && v:count <= 1 ? '$' : 'j'", 'Move down', 'expr')
call MiyagoMap('nx', '<Up>', "line('.') == 1 && v:count <= 1 ? '0' : 'k'", 'Move up', 'expr')
call MiyagoMap('nx', '<Down>', "line('.') == line('$') && v:count <= 1 ? '$' : 'j'", 'Move down', 'expr')
call MiyagoMap('o', 'j', 'k', 'Move up')
call MiyagoMap('o', 'k', 'j', 'Move down')

call MiyagoMap('n', '<C-s>', ':write<CR>', 'Save')
call MiyagoMap('x', '<C-s>', '<Esc>:write<CR>', 'Save')
call MiyagoMap('i', '<C-s>', '<C-o>:write<CR>', 'Save')
call MiyagoMap('n', '<C-z>', 'u', 'Undo')
call MiyagoMap('i', '<C-z>', '<C-o>u', 'Undo')
call MiyagoMap('n', '<C-y>', '<C-r>', 'Redo')
call MiyagoMap('i', '<C-y>', '<C-o><C-r>', 'Redo')

call MiyagoMap('x', '<C-c>', '"+y', 'Copy')
call MiyagoMap('x', '<C-x>', '"+d', 'Cut')
call MiyagoMap('n', '<C-v>', '"+P', 'Paste')
call MiyagoMap('x', '<C-v>', '"+P', 'Paste over selection')
call MiyagoMap('i', '<C-v>', '<C-r><C-o>+', 'Paste')
call MiyagoMap('c', '<C-v>', '<C-r>+', 'Paste', 'loud')
call MiyagoMap('nx', '<C-q>', '<C-v>', 'Visual block (Vim Ctrl-v)')
call MiyagoMap('x', '<BS>', '"_d', 'Delete selection')
call MiyagoMap('x', '<Del>', '"_d', 'Delete selection')
call MiyagoMap('x', '<Tab>', '>gv', 'Indent')
call MiyagoMap('x', '<S-Tab>', '<gv', 'Dedent')

call MiyagoMap('n', '<M-Up>', ':move .-2<CR>', 'Move line up')
call MiyagoMap('n', '<M-Down>', ':move .+1<CR>', 'Move line down')
call MiyagoMap('x', '<M-Up>', ":move '<-2<CR>gv", 'Move selection up')
call MiyagoMap('x', '<M-Down>', ":move '>+1<CR>gv", 'Move selection down')
call MiyagoMap('i', '<M-Up>', '<Esc>:move .-2<CR>gi', 'Move line up')
call MiyagoMap('i', '<M-Down>', '<Esc>:move .+1<CR>gi', 'Move line down')

call MiyagoMap('n', '<C-f>', '/', 'Search in file', 'loud')
call MiyagoMap('i', '<C-f>', '<Esc>/', 'Search in file', 'loud')
call MiyagoMap('c', '<Down>', "getcmdtype() =~ '[/?]' ? \"\\<lt>C-g>\" :\"\\<lt>Down>\"", 'Next match while searching', 'expr loud')
call MiyagoMap('c', '<Up>', "getcmdtype() =~ '[/?]' ? \"\\<lt>C-t>\" :\"\\<lt>Up>\"", 'Previous match while searching', 'expr loud')
call MiyagoMap('n', '<leader>rr', ':%s/\<<C-r><C-w>\>//g<Left><Left>', 'Replace word under cursor', 'loud')
call MiyagoMap('n', '<C-g>', ':', 'Go to line', 'loud')

" =====================
"   Buffer / Tab
" =====================
call MiyagoMap('n', '<C-w>', ':bdelete<CR>', 'Close buffer')
call MiyagoMap('n', '<C-Left>', ':bprevious<CR>', 'Previous buffer')
call MiyagoMap('n', '<C-Right>', ':bnext<CR>', 'Next buffer')
call MiyagoMap('n', '<leader>bn', ':bnext<CR>', 'Next buffer')
call MiyagoMap('n', '<leader>bp', ':bprevious<CR>', 'Previous buffer')
call MiyagoMap('n', '<leader>bc', ':enew<CR>', 'New buffer')
call MiyagoMap('n', '<leader>bx', ':bdelete<CR>', 'Close buffer')
call MiyagoMap('n', '<leader>c', ':tabnew<CR>', 'New tab')
call MiyagoMap('n', '<leader>[', ':tabprevious<CR>', 'Previous tab')
call MiyagoMap('n', '<leader>]', ':tabnext<CR>', 'Next tab')
call MiyagoMap('n', '<leader><Tab>', ':tabprevious<CR>', 'Previous tab')
call MiyagoMap('n', '<leader>x', ':tabclose<CR>', 'Close tab')
for s:i in range(1, 9)
  call MiyagoMap('n', '<leader>' . s:i, ':tabnext ' . s:i . '<CR>', 'Go to tab ' . s:i)
endfor
unlet s:i

" =====================
"   Window（同 tmux pane 邏輯）
" =====================
for [s:dir, s:arrow, s:split, s:resize] in [
      \ ['h', 'Left', 'leftabove vsplit', 'vertical resize -2'],
      \ ['j', 'Down', 'rightbelow split', 'resize +2'],
      \ ['k', 'Up', 'leftabove split', 'resize -2'],
      \ ['l', 'Right', 'rightbelow vsplit', 'vertical resize +2']]
  let s:focus = ":call MiyagoNavigate('" . s:dir . "')<CR>"
  call MiyagoMap('n', '<C-' . s:dir . '>', s:focus, 'Focus window ' . s:arrow)
  call MiyagoMap('n', '<leader>' . s:dir, s:focus, 'Focus window ' . s:arrow)
  call MiyagoMap('n', '<leader><' . s:arrow . '>', s:focus, 'Focus window ' . s:arrow)
  call MiyagoMap('n', '<leader>' . toupper(s:dir), ':' . s:resize . '<CR>', 'Resize window ' . s:arrow)
  call MiyagoMap('n', '<leader><S-' . s:arrow . '>', ':' . s:resize . '<CR>', 'Resize window ' . s:arrow)
  call MiyagoMap('n', '<leader>w' . s:dir, ':' . s:split . '<CR>', 'Split ' . s:arrow)
  call MiyagoMap('n', '<leader>w<' . s:arrow . '>', ':' . s:split . '<CR>', 'Split ' . s:arrow)
  call MiyagoMap('n', '<leader>w' . toupper(s:dir), '<C-w>' . toupper(s:dir), 'Move window far ' . s:arrow)
  call MiyagoMap('n', '<leader>w<S-' . s:arrow . '>', '<C-w>' . toupper(s:dir), 'Move window far ' . s:arrow)
endfor
unlet s:dir s:arrow s:split s:resize s:focus
call MiyagoMap('n', '<C-\>', '<C-w>p', 'Previous window')
call MiyagoMap('n', '<leader>-', ':split<CR>', 'Split horizontal')
call MiyagoMap('n', '<leader><Bar>', ':vsplit<CR>', 'Split vertical')
call MiyagoMap('n', '<leader>ws', ':split<CR>', 'Split horizontal')
call MiyagoMap('n', '<leader>wv', ':vsplit<CR>', 'Split vertical')
call MiyagoMap('n', '<leader>wx', '<C-w>x', 'Swap with next window')
call MiyagoMap('n', '<leader>=', '<C-w>=', 'Equalize windows')
call MiyagoMap('n', '<leader>z', ':call MiyagoZoom()<CR>', 'Toggle window zoom')
