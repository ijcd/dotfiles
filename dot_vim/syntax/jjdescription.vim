" LOCAL OVERRIDE — shadows the buggy jjdescription.vim in vim 9.2.0340's runtime.
" Upstream (#19905, 2026-04-11) shipped a broken `get(:g,...)` summary-length line
" that throws E121/E116 on `jj commit`; upstream REVERTED it (v9.2.0341+). This is
" the post-revert master copy. Loaded before $VIMRUNTIME (~/.vim is first in rtp);
" setting b:current_syntax makes the buggy system file `finish` before its bad line.
" Remove once nixpkgs vim is >= 9.2.0341. Source: vim/vim master runtime/syntax.
" Vim syntax file
" Language:	jj description
" Maintainer:	Gregory Anders <greg@gpanders.com>
" Last Change:	2024 May 8
" 2025 Apr 17 by Vim Project (don't require space to start comments, #17130)
" 2026 Apr 09 by Vim Project (anchor status regex to beginning of line, #19879)
" 2026 Apr 09 by Vim Project (detect renames of files, #19879)

if exists('b:current_syntax')
  finish
endif

syn match jjAdded "^JJ:\s\+\zsA\s.*" contained
syn match jjRemoved "^JJ:\s\+\zsD\s.*" contained
syn match jjChanged "^JJ:\s\+\zsM\s.*" contained
syn match jjRenamed "^JJ:\s\+\zsR\s.*" contained

syn region jjComment start="^JJ:" end="$" contains=jjAdded,jjRemoved,jjChanged,jjRenamed

syn include @jjCommitDiff syntax/diff.vim
syn region jjCommitDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@jjCommitDiff

hi def link jjComment Comment
hi def link jjAdded Added
hi def link jjRemoved Removed
hi def link jjChanged Changed
hi def link jjRenamed Changed

let b:current_syntax = 'jjdescription'
