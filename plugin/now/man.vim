if exists('loaded_plugin_now_man')
  finish
endif
let loaded_plugin_now_man = 1

let s:cpo_save = &cpo
set cpo&vim

" disable maps in $VIMRUNTIME/ftplugin/man.vim (this should naturally not be
" necessary!)
let no_man_maps = 1

map <Leader>K :call <SID>load_page(v:count)<CR>
command! -nargs=* -complete=customlist,s:man_completion Man call s:man(<f-args>)

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

augroup plugin-now-man
  autocmd!
  execute 'autocmd BufUnload'
        \ escape(g:now_man_buffer_name, '\ ') . '* setlocal nobuflisted'
augroup END

function! s:globpath(paths, expr)
  return split(globpath(join(a:paths, ','), a:expr), "\n")
endfunction

function! s:man_path_initialize()
  if exists('s:man_path')
    return
  endif

  if exists('g:now_man_path')
    let s:man_path = g:now_man_path
    return
  endif

  let man_path = split(substitute(system('manpath 2>/dev/null'), '\n$', "", ""), ':')
  if len(man_path) > 0
    let s:man_path = man_path
  elseif exists('$MANPATH')
    let s:man_path = split('$MANPATH')
  else
    let s:man_path = [
          \ '/usr/man',
          \ '/usr/pkg/man',
          \ '/usr/pkg/catman',
          \ '/usr/dt/man',
          \ '/usr/dt/catman',
          \ '/usr/share/man',
          \ '/usr/share/catman',
          \ '/usr/X11R6/man',
          \ '/usr/X11R6/catman',
          \ '/usr/local/man',
          \ '/usr/local/catman',
          \ '/opt/pkg/man',
          \ '/opt/pkg/catman',
          \ '/opt/dt/man',
          \ '/opt/dt/catman',
          \ '/opt/share/man',
          \ '/opt/share/catman',
          \ '/opt/X11R6/man',
          \ '/opt/X11R6/catman',
          \ '/opt/local/man',
          \ '/opt/local/catman' ]
  endif
endfunction

" TODO: Need to do shell quoting of s:mrd.
" TODO: Bug in Vim?  We need to copy(s:man_path).
function! s:mrd_update()
  let lang = exists('$LANG') && len($LANG) > 0 ? $LANG : 'En_US.ASCII'
  if exists('s:mrd_lang') && s:mrd_lang == lang
    return
  endif
  let s:mrd_lang = lang

  let s:mrd = join(filter(map(copy(s:man_path), 'substitute(v:val, "%L", lang, "") . "/mandb"'),
        \                 'filereadable(v:val) || isdirectory(v:val)'),
        \          ' ')
endfunction

function! s:man_completion(lead, line, cursor)
  call s:man_path_initialize()
  call s:mrd_update()
  
  let words = split(a:line, '\s\+')
  let line_left = strpart(a:line, 0, a:cursor)
  let current = len(split(line_left, '\s\+', 1))

  let section = ""
  if current > 2
    let section = words[1]
  elseif exists('$MANSECT')
    let section = $MANSECT
  endif
  let brace_section = substitute(section, ':', ',', 'g')
  if section != brace_section
    let section = '{' . brace_section . '}'
  endif

  if section =~ '^\%(\d.\{-}\|1M\|[ln]\)$' || section =~ '^{.*,.*}$'
    let dirs = s:globpath(s:man_path, '{sman,man,cat}' . section)
    let awk = '$2 == "' . section . '" {print $1}'
  else
    let dirs = s:globpath(s:man_path, '{sman,man,cat}*')
    let awk = '{print $1}'
  endif

  let pages = map(s:globpath(dirs, '*'), 'v:val[strridx(v:val, "/")+1:-1]')

  if len(s:mrd) > 0
    let mrd_pages = system('awk ' . awk . ' ' . s:mrd)
    if v:shell_error == 0
      call extend(pages, mrd_pages)
    endif
  endif

  call map(pages, 'substitute(v:val, ''\.\%(\d.\{-}\|1M\|[ln]\)\%(\.\%(gz\|bz2\|Z\)\)\=$'', "", "")')

  if current == 1
    call map(dirs, 'substitute(substitute(v:val, ''^.*\%(man\|cat\)'', "", ""), "/$", "", "")')
    let pages = extend(dirs, pages)
  endif

  call filter(pages, 'v:val =~ ''^' . now#regex#escape(a:lead) . '''')
  if len(pages) == 1
    return [pages[0] . ' ']
  endif
  return pages
endfunction

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
      let prev_mark = now#vim#mark#cursor()
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

function! s:man_buffer_init()
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

function! s:help()
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

function! s:load_page(...)
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

function! s:prev_page()
  if exists('b:prev_page')
    call s:man_load(b:prev_sect, b:prev_page, b:prev_mark)
  endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
