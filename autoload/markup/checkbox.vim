let s:save_cpo = &cpoptions
set cpoptions&vim

function! markup#checkbox#add() " {{{1
    if markup#checkbox#has_box()
        return
    endif
    silent!s/\(\s*\%(-\|[0-9]\+.\)\s\+\)\([^[].*$\)/\1[ ] \2
    nohlsearch
endfunction

function! markup#checkbox#remove() " {{{1
    if !markup#checkbox#has_box()
        return
    endif
    silent!s/\[[x ]\] //
    nohlsearch
endfunction

function! markup#checkbox#tick() " {{{1
    if !markup#checkbox#has_box()
        call markup#checkbox#add()
    endif
    silent!s/\[ \]/\[x\]/
    nohlsearch
endfunction

function! markup#checkbox#untick() " {{{1
    if !markup#checkbox#has_box()
        return
    endif
    silent!s/\[x\]/\[ \]/
    nohlsearch
endfunction

function! markup#checkbox#has_box() " {{{1
    return markup#checkbox#has_ticked_box() || markup#checkbox#has_empty_box()
endfunction

function! markup#checkbox#has_ticked_box() " {{{1
    return (getline(".") =~ "\\[x\\]")
endfunction

function! markup#checkbox#has_empty_box() " {{{1
    return (getline(".") =~ "\\[ \\]")
endfunction

function! markup#checkbox#toggle() " {{{1
    if !markup#checkbox#has_box()
        call markup#checkbox#add()
        call markup#checkbox#tick()
    elseif markup#checkbox#has_empty_box()
        call markup#checkbox#tick()
    elseif markup#checkbox#has_ticked_box()
        call markup#checkbox#tick()
        call markup#checkbox#untick()
    endif
endfunction

function! markup#checkbox#rotate() " {{{1
    if !markup#checkbox#has_box()
        call markup#checkbox#add()
    elseif markup#checkbox#has_empty_box()
        call markup#checkbox#tick()
    elseif markup#checkbox#has_ticked_box()
        call markup#checkbox#remove()
    end
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: sw=2 ts=2 et

