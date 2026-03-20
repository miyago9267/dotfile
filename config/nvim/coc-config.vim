" CoC 擴展列表
let g:coc_global_extensions = [
\ 'coc-sh',
\ 'coc-html',
\ 'coc-clangd',
\ 'coc-css',
\ 'coc-tsserver',
\ 'coc-json',
\ 'coc-yaml',
\ 'coc-python',
\ 'coc-java',
\ 'coc-go',
\ 'coc-docker',
\ 'coc-cmake',
\ 'coc-copilot',
\ ]

" CoC 自動補全設定
" 顯示文檔窗口
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" 高亮當前符號
autocmd CursorHold * silent call CocActionAsync('highlight')

" GoTo 代碼導航
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" 重命名符號
nmap <leader>rn <Plug>(coc-rename)

" 代碼格式化
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

" 應用代碼操作
nmap <leader>ac  <Plug>(coc-codeaction)
nmap <leader>qf  <Plug>(coc-fix-current)

" 診斷導航
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" 顯示所有診斷
nnoremap <silent><nowait> <space>a  :<C-u>CocList diagnostics<cr>

" Copilot 狀態顯示
let g:coc_status_error_sign = '✗'
let g:coc_status_warning_sign = ''
