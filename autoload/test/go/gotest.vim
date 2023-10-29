if !exists('g:test#go#gotest#file_pattern')
  let g:test#go#gotest#file_pattern = '\v[^_].*_test\.go$'
endif

function! test#go#gotest#test_file(file) abort
  return test#go#test_file('gotest', g:test#go#gotest#file_pattern, a:file)
endfunction

function! test#go#gotest#build_position(type, position) abort
  if a:type ==# 'suite'
    return ['./...']
  else
    let path = './'.fnamemodify(a:position['file'], ':h')

    if a:type ==# 'file'
      return path ==# './.' ? [] : [path . '/...']
    elseif a:type ==# 'nearest'
      let name = s:nearest_test(a:position, path)
      return empty(name) ? [] : name
    endif
  endif
endfunction

function! test#go#gotest#build_args(args) abort
  if index(a:args, './...') >= 0
    return a:args
  endif
  let tags = []
  let index = 1
  let pattern = '^//\s*+build\s\+\(.\+\)'
  while index <= getbufinfo('%')[0]['linecount']
    let line = trim(getbufline('%', l:index)[0])
    if l:line =~# '^package '
      break
    endif
    let tag = substitute(line, l:pattern, '\1', '')
    if l:tag != l:line
      " replace OR tags with AND, since we are going to use all the tags anyway
      let tag = substitute(l:tag, ' \+', ',', 'g')
      call add(l:tags, l:tag)
    endif
    let index += 1
  endwhile
  if len(l:tags) == 0
    return a:args
  else
    let args = ['-tags=' . join(l:tags, ',')] + a:args
    return l:args
  endif
endfunction

function! test#go#gotest#executable() abort
  return 'go test'
endfunction


function! s:nearest_test(position, path) abort
  " Check if the buffer has imported testify
  " let testifyImported = len(filter(getbufline('%', 1, '$'), 'v:val =~# "\v^\\"github.com/stretchr/testify\\"$"')) > 0
  let testifyImported = len(filter(getbufline('%', 1, '$'), 'v:val =~# ''\v^"github.com/stretchr/testify"$''')) > 0
  echo testifyImported

    " Previous behavior or any other fallback
  let name = test#base#nearest_test(a:position, g:test#go#patterns)
  let name = join(name['namespace'] + name['test'], '/')

  " if !testifyImported
  "   let without_spaces = substitute(name, '\s', '_', 'g')
  "   let escaped_regex = substitute(without_spaces, '\([\[\].*+?|$^()]\)', '\\\1', 'g')
  "   " return escaped_regex
  "   return ['-run '.shellescape(escaped_regex.'$', 1), path]
  " else
    " Look for setup function with testing.T argument
    for line in getbufline('%', 1, '$')
      if line =~# '\\vfunc (\w+)\\(t \*testing.T\\) {'
        let setupFunctionName = matchstr(line, '\\vfunc (\w+)\\(t \*testing.T\\) {')
        " return '-timeout 30s -tags integration -run ^' . setupFunctionName . '$ -testify.m ^' . name . '$'
        return ['-timeout 30s', '-run ^'.setupFunctionName.'$', '-testify.m ^'.name.'$', path]
      endif
    endfor
  endif

  return ''
endfunction

