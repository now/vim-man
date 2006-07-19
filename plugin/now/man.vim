" Vim plugin file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-07-19

if exists('loaded_plugin_now_man')
  finish
endif

let loaded_plugin_now_man = 1

let s:cpo_save = &cpo
set cpo&vim

runtime lib/now.vim
runtime lib/now/vim.vim
runtime lib/now/vim/position.vim

" disable maps in $VIMRUNTIME/ftplugin/man.vim (this should naturally not be
" necessary!)
let no_man_maps = 1

map <Leader>K :call <SID>load_page(v:count)<CR>
command! -nargs=* Man call s:man(<f-args>)

if !exists('g:now_man_man_cmd')
  let g:now_man_man_cmd = 'man'
endif

if !exists('g:now_man_sect_opt')
  let g:now_man_sect_opt = ''
endif

if !exists('g:now_man_page_opt')
  let g:now_man_page_opt = ''
endif

if !exists('g:now_man_buffer_name')
  let g:now_man_buffer_name = 'Man: '
endif

augroup Man
  execute 'au BufUnload'
        \ escape(g:now_man_buffer_name, '\ ') . '* setlocal nobuflisted'
augroup END

function! s:man(...)
  if a:0 >= 2
    let sect = a:1
    let page = a:2
  elseif a:0 == 1
    let sect = ''
    let page = a:1
  else
    echohl Error
    echo Missing manual page argument.
    echohl None
    return
  endif

  call s:man_load(sect, page)

  if winheight(0) < &helpheight
    execute 'resize ' . &helpheight
  endif
endfunction

function! s:man_load(sect, page, ...)
  if a:0 > 0
    let mark = a:1
  else
    let mark = 1
    if exists('b:man_sect')
      let prev_sect = b:man_sect
      let prev_page = b:man_page
      let prev_mark = g:NOW.Vim.Position.current()
    endif
  endif

  let bufname = g:now_man_buffer_name . a:page
  if (buflisted(bufname) && !getbufvar(bufname, '&hidden')) && a:0 < 2
    silent execute (&ft == 'info' ? 'b!' : 'sb') escape(bufname, '\ ')
  else
    silent! execute (&ft == 'man' ? 'e!' : 'new')
          \ '+setlocal\ modifiable\ noswapfile\ buftype=nofile' .
                   \ '\ bufhidden=unload\ nobuflisted'
          \ escape(bufname, '\ ')
    let man_width = $MANWIDTH
    let man_pager = $MANPAGER
    if man_width == ""
      let $MANWIDTH = winwidth('%')
    endif
    let $MANPAGER = 'cat'
    let cmd = g:now_man_man_cmd . ' -P "/bin/cat" ' . g:now_man_sect_opt .
          \ a:sect . ' ' . g:now_man_page_opt . a:page . ' | col -b'
    execute 'silent 0read!' cmd
    let $MANPAGER = man_pager
    let $MANWIDTH = man_width
    setfiletype man

    call s:man_buffer_init()
  endif

  let b:man_sect = a:sect
  let b:man_page = a:page
  if exists('prev_sect')
    let b:prev_sect = prev_sect
    let b:prev_page = prev_page
    let b:prev_mark = prev_mark
  endif

  setlocal nomodifiable
  if type(mark) == type({})
    call mark.restore()
  else
    call cursor(mark, 1)
  endif
endfunction

function s:man_buffer_init()
  noremap <buffer> <silent> <CR>            :call <SID>load_page()<CR>
  noremap <buffer> <silent> <C-]>           :call <SID>load_page()<CR>
  noremap <buffer> <silent> <C-T>           :call <SID>prev_page()<CR>
  noremap <buffer> <silent> <Space>         <C-F>
  noremap <buffer> <silent> >               <C-F>
  noremap <buffer> <silent> <Backspace>     <C-B>
  noremap <buffer> <silent> <               <C-B>
  noremap <buffer> <silent> q               :q!<CR>
  noremap <buffer> <silent> H               :call <SID>help()<CR>
endfunction

function s:help()
  echohl Title
  echo '                   Man Browser Keys'
  echo 'Key           Opt. Key   Action'
  echo '------------------------------------------------------'
  echohl None
  echo '<Space>       >          Scroll forward (page down)'
  echo '<Backspace>   <          Scroll backward (page up)'
  echo '<C-]>         Enter      Follow reference under cursor'
  echo '<C-T>                    Return to previous page'
  echo 'H                        This screen'
  echo 'q                        Quit browser'
endfunction

function s:load_page(...)
  if a:0 != 0
    let sect = a:1
    let page = expand('<cword>')
  else
    if &ft == 'man'
      let save_iskeyword = &iskeyword
      setlocal iskeyword+=-,(,)
    endif
    let cword = expand('<cword>')
    if exists('save_iskeyword')
      let &iskeyword = save_iskeyword
    endif
    let page = substitute(cword, '^\([^(]\+\).*', '\1', '')
    let sect = substitute(cword, '^[^(]\+(\([^()]*\)).*', '\1', '')
    if match(sect, '^[0-9n]\+$') == -1 || sect == page
      let sect = ''
    endif
  endif

  call s:man_load(sect, page)
endfunction

function s:prev_page()
  if exists('b:prev_page')
    call s:man_load(b:prev_sect, b:prev_page, b:prev_mark)
  endif
endfunction

let &cpo = s:cpo_save
