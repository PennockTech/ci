" Phil Pennock "reduced" vimrc, used away from normal git checkout.
" This includes root on some systems.
" Must be usable in constrained environments, including inside read-only
" jails.

" ======================================================================

" Security settings:
set nomodeline		"root doesn't trust files being edited
set secure		"limit what can be in per-dir .vimrc files

set nocompatible	"don't emulate bugs; nb: this resets viminfo
set shortmess+=I	"no startup message on blank file
set tildeop		"tilde is an op like any other, taking a movement

" Because /root in my jails is mounted read-only, test if home directory is
" writable; if not, disable .viminfo.  Note this must come after nocompatible.
" Note that we also support $XDG_CACHE_HOME though (but assume that the
" default of ~/.cache is covered by the writable test).
if has("eval")
  let s:old_viminfo=&viminfo
  if filewritable(expand("~")) != 2
    set viminfo=
  endif
  if exists("$XDG_CACHE_HOME") && isdirectory(eval("$XDG_CACHE_HOME"))
    let s:pdp_cache_okay=0
    let s:pdp_cachedir=eval("$XDG_CACHE_HOME") . "/vim"
    if isdirectory(s:pdp_cachedir)
      let s:pdp_cache_okay=1
    else
      if exists("*mkdir")
        try
          call mkdir(s:pdp_cachedir, "", 0700)
          let s:pdp_cache_okay=1
        catch /^Vim(\a\+):E739:/
          echoerr "mkdir(" . s:pdp_cachedir . ") failed"
        endtry
      else
        echoerr "missing mkdir, can not create " . s:pdp_cachedir
      endif
    endif
    if s:pdp_cache_okay
      let &viminfo=s:old_viminfo . ",n" . s:pdp_cachedir . "/viminfo"
      " prefer the cache dir for swap-files where home is not writable,
      " because constrained box and avoid littering
      if filewritable(expand("~")) != 2
        let &directory=s:pdp_cachedir . "," . &directory
      else
        let &directory+=s:pdp_cachedir
      endif
    endif
    unlet s:pdp_cache_okay s:pdp_cachedir
  endif
else
  set viminfo=
endif

" indent & formatting
set autoindent
set nocindent		"not by default, but can be enabled via setl
set cino=:0,(0,Ws,l1,g0,t0
set formatoptions-=l
set shiftround
set smartindent
set smarttab
set wrap

" visual cues
set nohlsearch
set scrolloff=1
set showmatch

" user-environment & keyboard
set encoding=utf-8
set pastetoggle=<F4>
"I do actually use ex mode, for my sins.  So don't let "Q" map to "gq"
if maparg("Q") != ""
  unmap Q
endif
map <F1> <Nop>
map <F3> :set invlist<CR>
imap <F3> <Esc>:set invlist<CR>a
if has("user_commands")
  " lazy shift release
  command W write
endif
if !has("gui_running")
  let g:showmarks_enable=0
  set background=dark
endif
if &t_Co >= 256
  let g:solarized_termcolors=256
  try
    colorscheme desert256
  catch /^Vim(\a\+):E185:/
    colorscheme desert
  endtry
  " That does a ctermbg/Normal, so reset again:
  set background=dark
elseif &t_Co >= 16
  colorscheme desert
else
  colorscheme ron
endif

if has("virtualedit")
  set virtualedit=block
endif

if has("eval")
  let g:is_posix = 1	"default sh highlighting errors on $(..)
endif

if has("autocmd")
  filetype plugin on
  filetype indent on
endif

" status-bar
set ruler
set showmode
set showcmd
if has("statusline")
  set laststatus=2	" always use statusline
endif

if &encoding =~ "utf-8"
  "set listchars=tab:»⋯,trail:·,extends:⇒,precedes:⇐,nbsp:␠,eol:¶
  set listchars=tab:»⋯,trail:⌴,extends:⇒,precedes:⇐,nbsp:␠
  set fillchars=vert:│,fold:§,diff:⣿
  set list
endif

" ======================================================================

" Enabling "filetype" stuff above would likely reset any of these:
if has("autocmd")
  " with modelines disabled, still set style for _this_ file
  au BufNewFile,BufRead *vim* setl ft=vim shiftwidth=2 expandtab
  au BufNewFile,BufRead *zsh* setl ft=zsh shiftwidth=2 foldmethod=marker

  " .md is Markdown, not Modula2
  au BufRead,BufNewFile *.md setl ft=markdown spell spelllang=en tw=78

  " sometimes vim updates seem to break usage with crontab?
  au BufRead,BufNewFile crontab.* setl nobackup nowritebackup

  au FileType bindzone setl comments=:;
endif

" Syntax highlighting: grandfathered in as already enabled, and makes sense
" but make it not error on minimal vim or break for mono displays
if has("syntax") && &t_Co > 2 || has("gui_running")
  syntax on
endif

" ======================================================================
" EOF
