if exists('g:loaded_ctrlp_project') && g:loaded_ctrlp_project
  finish
endif
let g:loaded_ctrlp_project = 1

let s:project_var = {
\  'init':   'ctrlp#project#init()',
\  'exit':   'ctrlp#project#exit()',
\  'accept': 'ctrlp#project#accept',
\  'lname':  'project',
\  'sname':  'project',
\  'type':   'project',
\  'sort':   0,
\}

let s:projects = {}

if exists('g:ctrlp_ext_vars') && !empty(g:ctrlp_ext_vars)
  let g:ctrlp_ext_vars = add(g:ctrlp_ext_vars, s:project_var)
else
  let g:ctrlp_ext_vars = [s:project_var]
endif

fu! s:syntax()
  if !ctrlp#nosy()
    cal ctrlp#hicheck('CtrlPTabExtra', 'Comment')
    cal ctrlp#hicheck('CtrlPProjectSubmodule', 'Statement')
    " y u no work
    sy match CtrlPProjectSubmodule '.*/\zs.\+\ze/'
    sy match CtrlPTabExtra '^\zs[^/]*/\ze'
  en
endf

function! ctrlp#project#init()
  let default = [
        \ '~/git', '~/code', '~/vcs', '~/work', '~/projects', '~/.vim/bundle']

  for dir in extend(default, g:ctrlp_project_roots)
    let path = fnamemodify(expand(dir), ':a')
    for fp in split(globpath(path, '*'), '\n')
      if len(globpath(fp, '.git', 1)) != 0
        let submodules = globpath(fp, '.gitmodules', 1)
        let key = fnamemodify(path, ':t') . '/' . fnamemodify(fp, ':t')
        let s:projects[key] = fp

        if len(submodules) != 0
          for line in readfile(submodules)
            let ret = matchlist(line, '^\s*path = \(.*\)$')
            if len(ret) != 0
              " TODO: fix fp path to be correct
              let s:projects[key . '/' . fnamemodify(ret[1], ':t')] = fp
            endif
          endfor
        endif
      endif
    endfor
  endfor

  cal s:syntax()
  return sort(keys(s:projects))
endfunc

function! ctrlp#project#accept(mode, str)
  call ctrlp#exit()
  cd `=s:projects[a:str]`
  call ctrlp#init(0, {})
endfunction

function! ctrlp#project#exit()
endfunction

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
function! ctrlp#project#id()
  return s:id
endfunction

" vim:fen:fdl=0:ts=2:sw=2:sts=2
