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
let s:modes = {
      \ 'h': 'split',
      \ 'v': 'vsplit',
      \ 't': 'tabedit',
      \ }

if exists('g:ctrlp_ext_vars') && !empty(g:ctrlp_ext_vars)
  let g:ctrlp_ext_vars = add(g:ctrlp_ext_vars, s:project_var)
else
  let g:ctrlp_ext_vars = [s:project_var]
endif

if !exists('g:ctrlp_project_cache')
  let g:ctrlp_project_cache = expand('~/.cache/ctrlp-project')
endif

" Make sure that it always exists
if !filereadable(g:ctrlp_project_cache)
  call writefile([], g:ctrlp_project_cache)
endif

" Guess project roots. Will traverse $HOME for directories that contain more
" than three git repositories. If it does, add it to the list of project roots.
function! s:guess_roots() abort
  let roots = []
  for root in split(globpath(expand('~'), '*'), '\n')
    if !isdirectory(root)
      continue
    endif

    let idx = 0
    for dir in split(globpath(root, '*'), '\n')
      if isdirectory(dir . '/.git/')
        let idx += 1
        if idx == 3
          let roots = add(roots, root)
          break
        endif
      endif
    endfor
  endfor

  return sort(roots, 's:weight_sort')
endfunction

if !exists('g:ctrlp_projects') || empty(g:ctrlp_projects)
  let g:ctrlp_projects = s:guess_roots()
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

function! s:weight_sort(a1, b1)
  " Sort by which directory contains the most repositories
  return s:dirweight(a:b1) - s:dirweight(a:a1)
endfunction

function! s:dirweight(dir)
  " Return number of repositories in path
  let ret = 0
  for dir in split(globpath(a:dir, '*'), '\n')
    let ret += isdirectory(dir . '/.git/')
  endfor
  return ret
endfunction

function! s:mru_sort(a1, b1)
  if !has_key(s:cpmru, a:a1) && !has_key(s:cpmru, a:b1)
    return 0
  elseif has_key(s:cpmru, a:a1) && !has_key(s:cpmru, a:b1)
    return -1
  elseif !has_key(s:cpmru, a:a1) && has_key(s:cpmru, a:b1)
    return 1
  endif

  return s:cpmru[a:b1] - s:cpmru[a:a1]
endfunction

function! s:index_sort(a1, b1)
  return index(g:ctrlp_projects, a:a1) - index(g:ctrlp_projects, a:b1)
endfunction

function! ctrlp#project#init()
  let results = {}
  let s:cpmru = {}

  " Read the MRU file
  for key in readfile(g:ctrlp_project_cache)
    if !has_key(s:cpmru, key)
      let s:cpmru[key] = 0
    endif
    let s:cpmru[key] += 1
  endfor

  for dir in g:ctrlp_projects
    let path = fnamemodify(expand(dir), ':a')
    let results[dir] = {}
    for fp in split(globpath(path, '*'), '\n')
      if len(globpath(fp, '.git', 1)) != 0
        let submodules = globpath(fp, '.gitmodules', 1)
        let key = fnamemodify(path, ':t') . '/' . fnamemodify(fp, ':t')
        let results[dir][key] = fp

        " Submodule support
        if len(submodules) != 0
          for line in readfile(submodules)
            let ret = matchlist(line, '^\s*path = \(.*\)$')
            if len(ret) != 0
              let spath = fp . '/' . ret[1]
              let skey = key . '/' . fnamemodify(ret[1], ':t')
              let results[dir][skey] = spath
            endif
          endfor
        endif
      endif
    endfor
  endfor

  " Apply score sorting
  let ret = []
  for key in sort(keys(results), 's:index_sort')
    let ret = extend(ret, sort(keys(results[key])))
    let s:projects = extend(s:projects, results[key])
  endfor

  " And finally apply MRU sorting. Ineffective, but shh.
  let ret = sort(ret, 's:mru_sort')

  cal s:syntax()
  return ret
endfunc

function! ctrlp#project#accept(mode, str)
  call ctrlp#exit()

  " Split, vsplit or tab
  if a:mode != 'e'
    exec s:modes[a:mode]
  endif

  " Write into use list
  let cachefile = g:ctrlp_project_cache
  call writefile(readfile(cachefile) + [a:str], cachefile)

  call ctrlp#init(0, {'dir': s:projects[a:str]})
endfunction

function! ctrlp#project#exit()
endfunction

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
function! ctrlp#project#id()
  return s:id
endfunction

" vim:fen:fdl=0:ts=2:sw=2:sts=2
