function! zettel#vimwiki#new_zettel_name(...)
  let newformat = g:zettel_format
  if a:0 > 0 && a:1 != "" 
    " title contains safe version of the original title
    " raw_title is exact title
    let title = zettel#vimwiki#escape_filename(a:1)
    let raw_title = a:1 
  else
    let title = zettel#vimwiki#escape_filename(g:zettel_default_title)
    let raw_title = g:zettel_default_title
  endif
  " expand title in the zettel_format
  let newformat = substitute(g:zettel_format, "%title", title, "")
  let newformat = substitute(newformat, "%raw_title", raw_title, "")
  if matchstr(newformat, "%file_no") != ""
    " file_no counts files in the current wiki and adds 1
    let next_file = zettel#vimwiki#next_counted_file()
    let newformat = substitute(newformat,"%file_no", next_file, "")
  endif
  if matchstr(newformat, "%file_alpha") != ""
    " same as file_no, but convert numbers to letters
    let next_file = s:numtoletter(zettel#vimwiki#next_counted_file())
    let newformat = substitute(newformat,"%file_alpha", next_file, "")
  endif
  if matchstr(newformat, "%random") != ""
    " generate random characters, their number is set by g:zettel_random_chars
    " random characters are set using zettel#vimwiki#make_random_chars()
    " this function is set at the startup and then each time
    " zettel#vimwiki#create() is called. we don't call it here because we
    " would get wrong links in zettel_new_selected(). It calls new_zettel_name
    " twice.
    let newformat = substitute(newformat, "%random", s:randomchars, "")
  endif
  let final_format =  strftime(newformat)
  if !s:wiki_file_not_exists(final_format)
    " if the current file name is used, increase counter and add it as a
    " letter to the file name. this ensures that we don't reuse the filename
    let file_count = zettel#vimwiki#count_files(final_format . "*")
    let final_format = final_format . s:numtoletter(file_count)
  endif
  let g:zettel_current_id = final_format
  return final_format
endfunction

" the optional argument is the wiki number
function! zettel#vimwiki#save_wiki_page(format, ...)
  let defaultidx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let idx = get(a:, 1, defaultidx)
  let newfile = vimwiki#vars#get_wikilocal('path',idx ) . a:format . vimwiki#vars#get_wikilocal('ext',idx )
  " copy the captured file to a new zettel
  execute "w! " . newfile
  return newfile
endfunction

" find title in the zettel file and return correct link to it
function! zettel#vimwiki#get_link(filename)
  let title =zettel#vimwiki#get_title(a:filename)
  let wikiname = fnamemodify(a:filename, ":t:r")
  if title == ""
    " use the Zettel filename as title if it is empty
    let title = wikiname
  endif
  let link= zettel#vimwiki#format_link(wikiname, title)
  return link
endfunction

" copy of function from Vimwiki
" Params: full path to a wiki file and its wiki number
" Returns: a list of all links inside the wiki file
" Every list item has the form
" [target file, anchor, line number of the link in source file, column number]
function! s:get_links(wikifile, idx)
  if !filereadable(a:wikifile)
    return []
  endif

  let syntax = vimwiki#vars#get_wikilocal('syntax', a:idx)
  let rx_link = vimwiki#vars#get_syntaxlocal('wikilink', syntax)
  let links = []
  let lnum = 0

  for line in readfile(a:wikifile)
    let lnum += 1

    let link_count = 1
    while 1
      let col = match(line, rx_link, 0, link_count)+1
      let link_text = matchstr(line, rx_link, 0, link_count)
      echomsg("link text " . line . " - " . link_text)
      if link_text == ''
        break
      endif
      let link_count += 1
      let target = vimwiki#base#resolve_link(link_text, a:wikifile)
      if target.filename != '' && target.scheme =~# '\mwiki\d\+\|diary\|file\|local'
        call add(links, [target.filename, target.anchor, lnum, col])
      endif
    endwhile
  endfor

  return links
endfunction

" return list of files that match a pattern
function! zettel#vimwiki#wikigrep(pattern)
  let paths = []
  let idx = vimwiki#vars#get_bufferlocal('wiki_nr')
  let path = fnameescape(vimwiki#vars#get_wikilocal('path', idx))
  let ext = vimwiki#vars#get_wikilocal('ext', idx)
  try
    let command = 'vimgrep ' . a:pattern . 'j ' . path . "*" . ext
    noautocmd  execute  command
  catch /^Vim\%((\a\+)\)\=:E480/   " No Match
    "Ignore it, and move on to the next file
  endtry
  for d in getqflist()
    let filename = fnamemodify(bufname(d.bufnr), ":p")
    call add(paths, filename)
  endfor
  call uniq(paths)
  return paths
endfunction

function! zettel#vimwiki#format_file_title(format, file, title)
  let link = substitute(a:format, "%title", a:title, "")
  let link = substitute(link, "%link", a:file, "")
  return link
endfunction

" use different link style for wiki and markdown syntaxes
function! zettel#vimwiki#format_link(file, title)
  return zettel#vimwiki#format_file_title(s:link_format, a:file, a:title)
endfunction

function! zettel#vimwiki#format_search_link(file, title)
  return zettel#vimwiki#format_file_title(s:link_stub, a:file, a:title)
endfunction

" This function is executed when the page referenced by the inserted link
" doesn't contain  title. The cursor is placed at the position where title 
" should start, and insert mode is started
function! zettel#vimwiki#insert_mode_in_title()
  execute "normal! " .s:insert_mode_title_format | :startinsert
endfunction

function! zettel#vimwiki#get_title(filename)
  let filename = a:filename
  let title = ""
  let lsource = readfile(filename)
  " this code comes from vimwiki's html export plugin
  for line in lsource 
    if line =~# '^# .*'
      let title = line[2:]
      return title
    endif
  endfor 
  return ""
endfunction


" check if the file with the current filename exits in wiki
function! s:wiki_file_not_exists(filename)
  let link_info = vimwiki#base#resolve_link(a:filename)
  return empty(glob(link_info.filename)) 
endfunction

" create new zettel note
" there is one optional argument, the zettel title
function! zettel#vimwiki#create(...)
  " name of the new note
  let format = zettel#vimwiki#new_zettel_name(a:1)
  let date_format = g:zettel_date_format
  let date = strftime(date_format)
  echomsg("new zettel: ". format)
  " update random chars used in %random name format 
  let s:randomchars = zettel#vimwiki#make_random_chars()
  let s:zettel_date = date " save zettel date
  " detect if the wiki file exists
  let wiki_not_exists = s:wiki_file_not_exists(format)
  " let vimwiki to open the wiki file. this is necessary  
  " to support the vimwiki navigation commands.
  call vimwiki#base#open_link(':e ', format)
  " add basic template to the new file
  if wiki_not_exists
    call zettel#vimwiki#template(a:1, date)
    return format
  endif
  return -1
endfunction

" front_matter can be either list or dict. if it is a dict, then convert it to
" list
function! s:front_matter_list(front_matter)
  if type(a:front_matter) ==? v:t_list
    return a:front_matter
  endif
  " it is prefered to use a list for front_matter, as it keeps the order of
  " keys. but it is possible to use dict, to keep the backwards compatibility
  let newlist = []
  for key in keys(a:front_matter)
    call add(newlist, [key, a:front_matter[key]])
  endfor
  return newlist
endfunction

function! zettel#vimwiki#zettel_new(...)
  let filename = zettel#vimwiki#create(a:1)
  " the wiki file already exists
  if filename ==? -1
    return 0
  endif
  let front_matter = zettel#vimwiki#get_option("front_matter")
  if g:zettel_disable_front_matter == 0
    if !empty(front_matter)
      let newfile = zettel#vimwiki#save_wiki_page(filename)
      let last_header_line = zettel#vimwiki#find_header_end(newfile)
      " ensure that front_matter is a list
      let front_list = s:front_matter_list(front_matter)
      " we must reverse the list, because each line is inserted before the
      " ones inserted earlier
      for values in reverse(copy(front_list))
        call append(last_header_line, <sid>make_header_item(values[0], values[1]))
      endfor
    endif
  endif

  " insert the template text from a template file if it is configured in
  " g:zettel_options for the current wiki
  let template = zettel#vimwiki#get_option("template")
  if !empty(template)
    let variables = get(a:, 2, 0)
    if empty(variables)
      " save file, in order to prevent errors in variable reading
      execute "w"
      let variables = zettel#vimwiki#prepare_template_variables(expand("%"), a:1)
      " backlink contains link to the new note itself, so we will just disable
      " it. backlinks are available only when the new note is created using
      " ZettelNewSelectedMap (`z` letter in visual mode by default).
      let variables.backlink = ""
    endif
    " we may reuse varaibles from the parent zettel. date would be wrong in this case,
    " so we will overwrite it with the current zettel date
    let variables.date = s:zettel_date 
    call zettel#vimwiki#expand_template(template, variables)
  endif
  " save the new wiki file
  execute "w"

endfunction

" crate zettel link from a selected text
function! zettel#vimwiki#zettel_new_selected()
  let title = <sid>get_visual_selection()
  let name = zettel#vimwiki#new_zettel_name(title)
  " prepare_template_variables needs the file saved on disk
  execute "w"
  " make variables that will be available in the new page template
  let variables = zettel#vimwiki#prepare_template_variables(expand("%"), title)
  " replace the visually selected text with a link to the new zettel
  " \\%V.*\\%V. should select the whole visual selection
  execute "normal! :'<,'>s/\\%V.*\\%V./" . zettel#vimwiki#format_link( name, "\\\\0") ."\<cr>\<C-o>"
  call zettel#vimwiki#zettel_new(title, variables)
endfunction

" prepare variables that will be available to expand in the new note template
function! zettel#vimwiki#prepare_template_variables(filename, title)
  let variables = {}
  let variables.title = a:title
  let variables.date = s:zettel_date
  " add variables from front_matter, to make them available in the template
  let front_matter = zettel#vimwiki#get_option("front_matter")
  if !empty(front_matter)
    let front_list = s:front_matter_list(front_matter)
    for entry in copy(front_list)
      let variables[entry[0]] = <sid>expand_front_matter_value(entry[1])
    endfor
  endif
  let variables.backlink = zettel#vimwiki#get_link(a:filename)
  " we want to save footer of the parent note. It can contain stuff that can
  " be useful in the child note, like citations,  etc. Footer is everything
  " below last horizontal rule (----)
  let variables.footer = s:read_footer(a:filename)
  return variables
endfunction

" find and return footer in the file
" footer is content below last horizontal rule (----)
function! s:read_footer(filename)
  let lines = readfile(a:filename)
  let footer_lines = []
  let found_footer = -1
  " return empty footer if we couldn't find the footer
  let footer = "" 
  " process lines from the last one and try to find the rule
  for line in reverse(lines) 
    if match(line, "^ \*----") == 0
      let found_footer = 0
      break
    endif
    call add(footer_lines, line)
  endfor
  if found_footer == 0
    let footer = join(reverse(footer_lines), "\n")
  endif
  return footer
endfunction

" populate new note using template
function! zettel#vimwiki#expand_template(template, variables)
  " readfile returns list, we need to convert it to string 
  " in order to do global replace
  let template_file = expand(a:template)
  if !filereadable(template_file) 
    return 
  endif
  let content = readfile(template_file)
  let text = join(content, "\n")
  for key in keys(a:variables)
    let text = substitute(text, "%" . key, a:variables[key], "g")
  endfor
  " when front_matter is disabled, there is an empty line before 
  " start of the inserted template. we need to ignore it.
  let correction = 0
  if line('$') == 1 
    let correction = 1
  endif
  " add template at the end
  " we must split it, 
  for xline in split(text, "\n")
    call append(line('$') - correction, xline)
  endfor
endfunction

" make new zettel from a file. the file contents will be copied to a new
" zettel, the original file contents will be replaced with the zettel filename
" use temporary file if you want to keep the original file
function! zettel#vimwiki#zettel_capture(wnum,...)
  let origfile = expand("%")
  execute "set ft=vimwiki"
  " This probably doesn't work with current vimwiki code
  if a:wnum > vimwiki#vars#number_of_wikis()
    echomsg 'Vimwiki Error: Wiki '.a:wnum.' is not registered in g:vimwiki_list!'
    return
  endif
  if a:wnum > 0
    let idx = a:wnum
  else
    let idx = 0
  endif
  let title = zettel#vimwiki#get_title(origfile)
  let format = zettel#vimwiki#new_zettel_name(title)
  " let link_info = vimwiki#base#resolve_link(format)
  let newfile = zettel#vimwiki#save_wiki_page(format, idx)
  " delete contents of the captured file
  execute "normal! ggdG"
  " replace it with a address of the zettel file
  execute "normal! i" . newfile 
  execute "w"
  " open the new zettel
  execute "e " . newfile
endfunction

" based on vimwikis "get wiki links", not stripping file extension
function! zettel#vimwiki#get_wikilinks(wiki_nr, also_absolute_links)
  let files = vimwiki#base#find_files(a:wiki_nr, 0)
  if a:wiki_nr == vimwiki#vars#get_bufferlocal('wiki_nr')
    let cwd = vimwiki#path#wikify_path(expand('%:p:h'))
  elseif a:wiki_nr < 0
    let cwd = vimwiki#vars#get_wikilocal('path') . vimwiki#vars#get_wikilocal('diary_rel_path')
  else
    let cwd = vimwiki#vars#get_wikilocal('path', a:wiki_nr)
  endif
  let result = []
  for wikifile in files
    let wikifile = vimwiki#path#relpath(cwd, wikifile)
    call add(result, wikifile)
  endfor
  if a:also_absolute_links
    for wikifile in files
      if a:wiki_nr == vimwiki#vars#get_bufferlocal('wiki_nr')
        let cwd = vimwiki#vars#get_wikilocal('path')
      elseif a:wiki_nr < 0
        let cwd = vimwiki#vars#get_wikilocal('path') . vimwiki#vars#get_wikilocal('diary_rel_path')
      endif
      let wikifile = '/'.vimwiki#path#relpath(cwd, wikifile)
      call add(result, wikifile)
    endfor
  endif
  return result
endfunction

" add link with title of the file referenced in the second argument to the
" array in the first argument
function! s:add_bulleted_link(lines, abs_filepath)
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  call add(a:lines, bullet.
        \ zettel#vimwiki#get_link(a:abs_filepath))
  return a:lines
endfunction

  

" insert list of links to the current page
function! s:insert_link_array(title, lines)
  let links_rx = '\m^\s*'.vimwiki#u#escape(vimwiki#lst#default_symbol()).' '
  call zettel#vimwiki#update_listing(a:lines, a:title, links_rx)
endfunction


" based on vimwikis "generate links", adding the %title to the link
function! zettel#vimwiki#generate_links()
  let lines = []

  let links = zettel#vimwiki#get_wikilinks(vimwiki#vars#get_bufferlocal('wiki_nr'), 0)
  call reverse(sort(links))

  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  for link in links
    let abs_filepath = vimwiki#path#abs_path_of_link(link)
    "let abs_filepath = link
    "if !s:is_diary_file(abs_filepath)
      call add(lines, bullet.
            \ zettel#vimwiki#get_link(abs_filepath))
    "endif
  endfor
  call s:insert_link_array('Generated Index', lines)
endfunction


" test if link in the Backlinks section
function! s:is_in_backlinks(file, filenamepattern)
  let f = readfile(a:file)
  let content = join(f, "\n")
  " search for backlinks section
  let backlinks_pattern = printf(s:section_pattern, g:zettel_backlinks_title)
  let backlinks_pos = matchstrpos(content, backlinks_pattern)
  " if we cannot find backlinks in the page return false
  if backlinks_pos[1] == -1 
    return -1
  endif
  let file_pos = matchstrpos(content, a:filenamepattern)
  " link is in backlinks when it is placed after the Backlinks section title
  return backlinks_pos[1] < file_pos[1]
endfunction


" based on vimwikis "backlinks"
" insert backlinks of the current page in a section
function! zettel#vimwiki#backlinks()
  let current_filename = expand("%:t:r")
  " find [filename| or [filename] to support both wiki and md syntax
  let filenamepattern = printf(s:grep_link_pattern, current_filename)
  let locations = []
  let backfiles = zettel#vimwiki#wikigrep(filenamepattern)
  for file in backfiles
    " only add backlink if it is not already backlink
    let is_backlink = s:is_in_backlinks(file, current_filename)
    if is_backlink < 1
      " Make sure we don't add ourselves
      if !(file ==# expand("%:p"))
        call s:add_bulleted_link(locations, file)
      endif
    endif
  endfor

  if empty(locations)
    echomsg 'Vimzettel: No other file links to this file'
  else
    call uniq(locations)
    " Insert back links section
    call s:insert_link_array(g:zettel_backlinks_title, locations)
  endif
endfunction

function! zettel#vimwiki#inbox()
  call vimwiki#base#check_links()
  let linklist = getqflist()
  cclose
  let paths = []
  " normalize the current wiki path
  let cwd = fnamemodify(vimwiki#vars#get_wikilocal('path'), ":p:h")
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()) . vimwiki#lst#default_symbol().' '
  for d in linklist
    " detect files that are not reachable from the wiki index
    let filenamematch = matchstr(d.text,'\zs.*\ze is not reachable')
    if filenamematch != "" && filereadable(filenamematch)
      " use only files from the current wiki, we get files from all registered
      " wikis here
      let filepath = fnamemodify(filenamematch, ":p:h")
      if filepath ==# cwd
        call add(paths, bullet.
              \ zettel#vimwiki#get_link(filenamematch))
      endif
    endif
  endfor
  if empty(paths)
  else
    " remove duplicates and insert inbox section
    call uniq(paths)
    call s:insert_link_array('Unlinked Notes', paths)
  endif

endfunction

" based on vimwiki
"   Loads tags metadata from file, returns a dictionary
function! s:load_tags_metadata() abort
  let metadata_path = vimwiki#tags#metadata_file_path()
  if !filereadable(metadata_path)
    return {}
  endif
  let metadata = {}
  for line in readfile(metadata_path)
    if line =~ s:tag_pattern
      continue
    endif
    let parts = matchlist(line, '^\(.\{-}\);"\(.*\)$')
    if parts[0] == '' || parts[1] == '' || parts[2] == ''
      throw 'VimwikiTags1: Metadata file corrupted'
    endif
    let std_fields = split(parts[1], '\t')
    if len(std_fields) != 3
      throw 'VimwikiTags2: Metadata file corrupted'
    endif
    let vw_part = parts[2]
    if vw_part[0] != "\t"
      throw 'VimwikiTags3: Metadata file corrupted'
    endif
    let vw_fields = split(vw_part[1:], "\t")
    if len(vw_fields) != 1 || vw_fields[0] !~ '^vimwiki:'
      throw 'VimwikiTags4: Metadata file corrupted'
    endif
    let vw_data = substitute(vw_fields[0], '^vimwiki:', '', '')
    let vw_data = substitute(vw_data, '\\n', "\n", 'g')
    let vw_data = substitute(vw_data, '\\r', "\r", 'g')
    let vw_data = substitute(vw_data, '\\t', "\t", 'g')
    let vw_data = substitute(vw_data, '\\\\', "\\", 'g')
    let vw_fields = split(vw_data, "\t")
    if len(vw_fields) != 2
      throw 'VimwikiTags5: Metadata file corrupted'
    endif
    let pagename = vw_fields[0]
    let entry = {}
    let entry.tagname  = std_fields[0]
    let entry.filename  = std_fields[1]
    let entry.lineno   = std_fields[2]
    let entry.link     = vw_fields[1]
    if has_key(metadata, pagename)
      call add(metadata[pagename], entry)
    else
      let metadata[pagename] = [entry]
    endif
  endfor
  return metadata
endfunction

" based on vimwiki
function! zettel#vimwiki#generate_tags(...) abort
  let need_all_tags = (a:0 == 0)
  let specific_tags = a:000

  let metadata = s:load_tags_metadata()

  " make a dictionary { tag_name: [tag_links, ...] }
  let tags_entries = {}
  for entries in values(metadata)
    for entry in entries
      if has_key(tags_entries, entry.tagname)
        call add(tags_entries[entry.tagname], entry.filename)
      else
        let tags_entries[entry.tagname] = [entry.filename]
      endif
    endfor
  endfor

  let lines = []
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()).vimwiki#lst#default_symbol().' '
  for tagname in sort(keys(tags_entries))
    if need_all_tags || index(specific_tags, tagname) != -1
      call extend(lines, [
            \ '',
            \ substitute(vimwiki#vars#get_syntaxlocal('rxH2_Template'), '__Header__', tagname, ''),
            \ '' ])
      for taglink in reverse(sort(tags_entries[tagname]))
        let filepath = vimwiki#path#abs_path_of_link(taglink)
        if filereadable(filepath)
          call add(lines, bullet . zettel#vimwiki#get_link(filepath))
        endif
      endfor
    endif
  endfor

  let links_rx = '\m\%(^\s*$\)\|\%('.vimwiki#vars#get_syntaxlocal('rxH2').'\)\|\%(^\s*'
        \ .vimwiki#u#escape(vimwiki#lst#default_symbol()).' '
        \ .vimwiki#vars#get_syntaxlocal('rxWikiLink').'$\)'

  call zettel#vimwiki#update_listing(lines, 'Generated Tags', links_rx)
endfunction

