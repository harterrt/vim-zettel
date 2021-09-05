let g:zettel_fzf_command = "rg --column --line-number --no-heading --smart-case --color=always "
let g:zettel_dir = "~/zett/lit"
let g:search_ext = "*.md"
let g:zettel_fzf_options = ['--exact', '--tiebreak=end']
let g:zettel_link_format="[%title](%link)"


" The first H1 heading is the title of the Zettel
function! s:get_zettel_title(filename)
  return zettel#vimwiki#get_title(a:filename)
endfunction


" fzf returns selected filename and matched line from the file, we need to
" strip the unnecessary text to get just the filename
function! s:get_fzf_filename(line)
  " line is in the following format:
  " filename:linenumber:number:matched_text
  " remove spurious text from the line to get just the filename
  echo a:line
  let filename = split(a:line, '\:')[0]
  return filename
endfunction


" strip extension from wiki filename (assumes .md suffix)
function! s:strip_extension(filename)
   return a:filename[0:-4]
endfunction


function! s:format_link(file, title)
  let link = substitute(g:zettel_link_format, "%title", a:title, "")
  let link = substitute(link, "%link", a:file, "")
  return link
endfunction


" execute fzf function
function! zettel#fzf#execute_fzf(a, b, options)
  " search only files in the current wiki syntax
  " it doesn't work with ag searcher
  return fzf#vim#grep(g:zettel_fzf_command . " " . shellescape(a:a) . " " . g:search_ext, 1, a:options)
endfunction


" insert link for the searched zettel in the current note
function! zettel#fzf#wiki_search(line,...)
  let filename = s:get_fzf_filename(a:line)
  let title = s:get_zettel_title(filename)
  " insert the filename and title into the current buffer
  let wikiname = s:strip_extension(filename)
  " if the title is empty, the link will be hidden by vimwiki, use the filename
  " instead
  if empty(title)
    let title = wikiname
  end
  let link = s:format_link(filename, title)
  execute "normal! a" . link
endfunction


" search for a note and the open it in Vimwiki
function! zettel#fzf#search_open(line,...)
  let filename = s:get_fzf_filename(a:line)
  let prev_links = vimwiki#vars#get_bufferlocal('prev_links')
  call insert(prev_links, filename)
  exec vimwiki#vars#set_bufferlocal('prev_links', prev_links)
  call vimwiki#base#open_link(':e ', filename)
endfunction

" get options for fzf#vim#with_preview function
" pass empty dictionary {} if you don't want additinal_options
function! zettel#fzf#preview_options(sink_function, additional_options)
  let options = {'sink':function(a:sink_function),
      \'down': '~40%',
      \'dir':g:zettel_dir,
      \'options':g:zettel_fzf_options}
  " make it possible to pass additional options that overwrite the default
  " ones
  let options = extend(options, a:additional_options)
  return options
endfunction

" helper function to open FZF preview window and pass one selected file to a
" sink function. useful for opening found files
function! zettel#fzf#sink_onefile(params, sink_function,...)
  " get optional argument that should contain additional options for the fzf
  " preview window
  let additional_options = get(a:, 1, {})
  call zettel#fzf#execute_fzf(a:params, 
      \'--skip-vcs-ignores', fzf#vim#with_preview(zettel#fzf#preview_options(a:sink_function, additional_options)))
endfunction

" open wiki page using FZF search
function! zettel#fzf#execute_open(params)
  call zettel#fzf#sink_onefile(a:params, 'zettel#fzf#search_open')
endfunction

" return list of unique wiki pages selected in FZF 
function! zettel#fzf#get_files(lines)
  " remove duplicate lines
  let new_list = [] 
  for line in a:lines
    if line !="" 
      let new_list = add(new_list, s:get_fzf_filename(line))
    endif
  endfor
  return uniq(new_list)
endfunction

" map between Vim filetypes and Pandoc output formats
let s:supported_formats = {
      \"tex":"latex",
      \"latex":"latex",
      \"markdown":"markdown",
      \"wiki":"vimwiki",
      \"md":"markdown",
      \"org":"org",
      \"html":"html",
      \"default":"markdown",
\}

" this global variable can hold additional mappings between Vim and Pandoc
if exists('g:export_formats')
  let s:supported_formats = extend(s:supported_formats, g:export_formats)
endif

" return section title depending on the syntax
function! s:make_section(title, ft)
  if a:ft ==? "md"
    return "# " . a:title
  else
    return "= " . a:title . " ="
  endif
endfunction

" this function is just a test for retrieving multiple results from FZF. see
" plugin/zettel.vim for call example
function! zettel#fzf#insert_note(lines)
  " get Pandoc output format for the current file filetype
  let output_format = get(s:supported_formats,&filetype, "markdown")
  let lines_to_convert = []
  let input_format = "vimwiki"
  for line in zettel#fzf#get_files(a:lines)
    " convert all files to the destination format
    let filename = vimwiki#vars#get_wikilocal('path',0). line
    let ext = fnamemodify(filename, ":e")
    " update the input format
    let input_format = get(s:supported_formats, ext, "vimwiki")
    " convert note title to section
    let sect_title = s:make_section( zettel#vimwiki#get_title(filename), ext)
    " find start of the content
    let header_end = zettel#vimwiki#find_header_end(filename)
    let lines_to_convert = add(lines_to_convert, sect_title)
    let i = 0
    " read note contents without metadata header
    for fline in readfile(filename)
      if i >= header_end
        let lines_to_convert = add(lines_to_convert, fline)
      endif
      let i = i + 1
    endfor
  endfor
  let command_to_execute = "pandoc -f " . input_format . " -t " . output_format
  echom("Executing :" .command_to_execute)
  let result = systemlist(command_to_execute, lines_to_convert)
  call append(line("."), result)
  " Todo: move this to execute_open 
  call setqflist(map(zettel#fzf#get_files(a:lines), '{ "filename": v:val }'))
endfunction
