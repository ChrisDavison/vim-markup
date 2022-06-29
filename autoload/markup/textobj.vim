let s:save_cpo = &cpoptions
set cpoptions&vim

" IN a section (i.e. EXCLUDE header)
function! markup#textobj#section_inside() "{{{
    " INSIDE a markdown section
    " section is defined as the nearest parent header
    let parent=markup#previous_sibling_or_parent()
    let parent=l:parent+1
    let after=markup#next_sibling_or_section()
    if l:after != line('$')
        let after=l:after-1
    end
    let parent=[0, l:parent, 1, 0]
    exec "normal " . l:after . "g"
    call cursor(l:after, 1)
    normal! g_
    let after=getpos('.')
    return ['v', l:parent, l:after]
endfunction "}}}

" AROUND a section (i.e. INCLUDE header)
function! markup#textobj#section_around() "{{{
    " AROUND a markdown section
    " section is defined as the nearest parent header
    let parent=markup#previous_sibling_or_parent()
    if on_heading()
        let l:parent=line('.')
    end
    let after=markup#next_sibling_or_section()
    if l:after != line('$')
        let after=l:after-1
    end
    let parent=[0, l:parent, 1, 0]
    exec "normal " . l:after . "g"
    call cursor(l:after, 1)
    normal! g_
    let after=getpos('.')
    return ['v', l:parent, l:after]
endfunction "}}}

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: sw=2 ts=2 et
