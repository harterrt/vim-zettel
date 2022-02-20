" make fulltext search in all VimWiki files and insert link to the found file
" command! -bang -nargs=* ZettelSearch call fzf#vim#ag(<q-args>, 
command! -bang -nargs=* ZettelSearch call zettel#fzf#sink_onefile(<q-args>, 'zettel#fzf#wiki_search')

" make fulltext search in all VimWiki files and open the found file
command! -bang -nargs=* ZettelOpen call zettel#fzf#sink_onefile(<q-args>, 'zettel#fzf#search_open')

" crate new zettel using command
command! -bang -nargs=* ZettelNew call zettel#vimwiki#zettel_new(<q-args>)


imap <c-l> <esc>:ZettelSearch<cr>
nmap <leader>zo :ZettelOpen<cr>
