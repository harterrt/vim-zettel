# Desired Behaviors

* Create new note in Zett quickly 
  [x] from cli
  [ ] TODO: from vim
* Insert link to new zettel in current zett 
  (allows us to format, then click through)
  * ~~Needs a shortcut - <leader>-~~ Nvm - do this in insert mode, otherwise messy
  * **Done** with Ultisnip, includes visual creation of link
    * zz<tab> -> link to a new zett (reletive to current directory)
    * visual: zz<tab> -> `[$(visual)](new zettel)`
* Issue interactive full-text search for zettel,
  * **DONE** : and insert link into current note (ZettelSearch)
      * Needs a shortcut - `c-l` (similar to search in Firefox)
  * **DONE**  or open note in current window 
      * TODO: Needs a shortcut - `<leader>z/`
      * (*almost* ZettelOpen) - ZettelOpen opens, but disables navigating back
        to origintating note (i.e. backspace doesn't work) w
* TODO: Open past note in a split or current buffer (possibly fzf?)
* TODO: Keep purging code, there's a lot of errant (and confusing) code.
