" checkbox.vim - Toggle markdown checkboxes
" Maintainer: Chris Davison <https://chrisdavison.github.io>
" Version: 20200211

" Initialisation {{{1
if exists("g:loaded_markup") || &cp || v:version < 700
    finish
endif
let g:loaded_markup = 1

let s:cpo_save = &cpo
set cpo&vim

" Command bindings {{{1
command! -range Tick <line1>,<line2>call markup#checkbox#tick()
command! -range RTick <line1>,<line2>call markup#checkbox#rotate()
command! -range Untick <line1>,<line2>call markup#checkbox#untick()
command! -range=% RMCheck <line1>,<line2>call markup#checkbox#remove()

" Highlight a list. the first left-aligned entry is made a H1 # header
" a newline is added, and the rest are de-indented.
command! -range ListToH1 call markup#list_to_h1(<line1>, <line2>)

" OPTIONAL default bindings {{{1
if !exists("g:markup_no_checkbox_mappings") || !g:markup_no_checkbox_mappings
  nnoremap <leader>x :call markup#checkbox#toggle()<CR>
  vnoremap <leader>x :call markup#checkbox#toggle()<CR>
  nnoremap <leader>X :call markup#checkbox#remove()<CR>
  vnoremap <leader>X :call markup#checkbox#remove()<CR>
endif

command! -range MoveVisualToFile call markup#move_visual_selection_to_file(<line1>, <line2>)
command! FilenameAsHeader call markup#filename_as_header()
command! -bang Backlinks call markup#backlinks(<bang>1)

if !exists("g:markup_no_replace_mappings") || !g:markup_no_replace_mappings
  nnoremap <buffer> PB :call markup#replace_cWORD_with_bold()<CR>
  nnoremap <buffer> PI :call markup#replace_cWORD_with_italic()<CR>
  nnoremap <buffer> PE :call markup#replace_cWORD_with_bolditalic()<CR>

  vnoremap <buffer> PB :call markup#replace_region_with_bold()<CR>
  vnoremap <buffer> PI :call markup#replace_region_with_italic()<CR>
  vnoremap <buffer> PE :call markup#replace_region_with_bolditalic()<CR>
endif

call textobj#user#plugin('markdown',  {
            \ 'section': {
                \ 'select-a-function': 'markup#textobj#section_around',
                \ 'select-a': [],
                \ 'select-i-function': 'markup#textobj#section_inside',
                \ 'select-i': [],
                \},
            \})

augroup markdown_textobjs
    autocmd!
    autocmd Filetype markdown call textobj#user#map('markdown', {
                \ 'section': {
                    \ 'select-a': '<buffer> aS',
                    \ 'select-i': '<buffer> iS',
                    \},
                \})
augroup END

let &cpo = s:cpo_save
" vim:set et sw=2 sts=2:
