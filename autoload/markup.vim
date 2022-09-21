function! s:titlecase(str) abort "{{{
    let words=split(a:str, '\W\+')
    let titled=map(l:words, {_, word -> toupper(word[0]) . word[1:]})
    return join(l:titled, ' ')
endfunction "}}}

" Are we on a markdown ATX heading?
function! markup#on_heading() "{{{1
    return getline(".") =~ '^#\+ '
endfunction


let s:header_regexp="^#\\+ "
if !exists("g:markdown_filename_as_header_suppress")
  let g:markdown_filename_as_header_suppress = 0
endif

" Convert filename to a 'readable' H1 header
function! markup#filename_as_header() abort "{{{1
    let filename=expand('%:t:r')
    let header='# ' . s:titlecase(substitute(l:filename, '-', ' ', 'g'))
    call append(0, l:header)
endfunction

function! markup#find_next_reference_link() abort "{{{1
    let link_re='\[\(.*\)\]\[\]'
    let pos=searchpos(l:link_re, 'cn')
    if l:pos == [0, 0]
        return
    endif
    let line=getline(pos[0])
    let text=matchlist(l:line, l:link_re)[1]
    let url_re='\[' . l:text . '\]: \(.*\)'
    let posurl=searchpos(l:url_re, 'n')
    if l:posurl == [0, 0]
        return
    endif
    let urlline=getline(l:posurl[0])
    let url=matchlist(l:urlline, l:url_re, l:posurl[1]-1)[1]
    return [l:pos, l:url]
endfunction

function! markup#find_reference_link_from_anchor() abort "{{{1
    let link_re='\[.*\]: \(.*\)'
    let pos=searchpos(l:link_re, 'n')
    if l:pos == [0, 0]
        return
    endif
    let text=matchlist(getline(l:pos[0]), l:link_re)[1]
    return [l:pos, l:text]
endfunction

function! markup#find_next_plain_link() abort "{{{1
    let link_re='\[.*\](\(.*\))'
    let pos=searchpos(l:link_re, "n")
    if pos[:2] == [0, 0]
        return
    endif
    let line=getline(pos[0])
    let url=matchlist(l:line, l:link_re, pos[1]-1)[1]
    return [l:pos, l:url]
endfunction

function! s:compare_link_matches(i1, i2) "{{{1
    let [row1, col1] = a:i1[0]
    let [row2, col2] = a:i2[0]
    if row1 == row2
        return col1 == col2 ? 0 : col1 < col2 ? -1 : 1
    elseif row1 < row2
        return -1
    else
        return 1
    endif
endfunction

function! markup#find_next_link() abort "{{{1
    let nearest_links=filter([
                \ markup#find_next_reference_link(),
                \ markup#find_reference_link_from_anchor(),
                \ markup#find_next_plain_link()
                \ ], {_, v -> len(v) > 1})
    call sort(l:nearest_links, function("<sid>compare_link_matches"))
    return l:nearest_links[0]
endfunction

function! markup#goto_file(split) abort "{{{1
    let [next_link_pos, next_link_url]=markup#find_next_link()
    call cursor(l:next_link_pos)
    let command = "edit "
    if a:split > 0
        if winwidth(0) > 160
            " Vertical split if we have 160 columns
            " (i.e. 2 buffers at 80 columns wide)
            let command = "vsplit "
        else
            let command = "split "
        endif
    endif
    if filereadable(l:next_link_url)
        execute "silent!" . l:command . l:next_link_url
        return [1, l:next_link_url]
    endif
    " ----
    let next_link_url_res = resolve(expand("%:p:h") . "/" . l:next_link_url)
    if filereadable(l:next_link_url_res)
        let header=matchlist(l:next_link_url_res, ".*#\(.*\)")
        execute "silent!" . l:command . l:next_link_url_res
        if len(l:header)
            let l:tidy=substitute(l:header[1], "%20", " ", "g")
            if !search("# " . l:tidy)
                echo "Couldn't find header: " . l:tidy
            end
        end
        return [1, l:next_link_url_res]
    endif
    " ----
    echom "Couldn't find valid link. Tried: " . l:next_link_url
    return [0, l:next_link_url]
endfunction

function! markup#backlinks(use_grep) abort "{{{1
    " Use tail (only filename) so that relative links work
    let l:fname=expand("%:t")
    if a:use_grep
        exec "silent grep! '\\((\./)*" . l:fname . "'"
        if len(getqflist()) == 0
            exec "cclose"
        endif
    else
        call fzf#vim#grep(
        \ "rg --column --line-number --no-heading --color=always --smart-case -g '!tags' ".l:fname, 1,
        \ fzf#vim#with_preview('right:50%:hidden', '?'), 0)
    end
endfunction

function! s:first_line_from_file(filename) "{{{1
    if !filereadable(a:filename)
        echom a:filename . " doesn't exist"
    endif
    let title=trim(system('head -n1 ' . a:filename))
    return substitute(l:title, "^\#\\+ \\+", "", "")
endfunction

function! markup#move_visual_selection_to_file(start, end) abort "{{{1
    " Need to write to a file relative to PWD
    " but copy link relative to file of origin
    " e.g. if origin file is DIRECTORY/parentfile.md
    " need to write to DIRECTORY/childfile.md
    " but link to [child](./childfile.md)
    let filename=input("Filename (relative to `" . expand("%:h") . "/`): ")
    let dir_of_origin=expand('%:.:h')
    let curdir=getcwd()
    let filename_nospace=tolower(substitute(l:filename, ' ', '-', 'g')) . ".md"
    let linequery=a:start . "," . a:end
    let full_filename=l:dir_of_origin . "/" . l:filename_nospace
    silent! exec ":" . l:linequery . "w " . l:full_filename
    let text=<SID>first_line_from_file(l:full_filename)
    let link="[" . l:text . "](./" . l:filename_nospace . ")"
    silent! exec ":" . l:linequery . "d"
    write
    let @+=l:link
    echo "Link copied to clipboard."
    exec "edit " . l:full_filename
    call markup#promote_till_l1()
    exec "edit #"
endfunction

function! markup#previous_heading_linum(same) "{{{1
    let cur_level=markup#current_heading_level()
    let regexp=s:header_regexp
    let regexp_same="^" . repeat("#", cur_level) . " "
    let heading_line=search(l:regexp, "nb")
    let heading_line_same=search(l:regexp_same, "nb")
    if a:same
        let l:heading_line=max([l:heading_line, l:heading_line_same])
    endif
    return min([line('.'), l:heading_line])
endfunction

function! markup#next_heading_linum(same) "{{{1
    " if on a heading, set cur_level to num #
    " if not on a heading, find PREVIOUS heading, set cur_level to num #
    "
    " if looking for same header_level, go to same number of cur_level UNLESS
    " a less-nested header exists before it
    " e.g go h3 -> h3 if document is [h3] h3 h3,
    "    but h3 -> h2 if document is [h3] h2 h3
    let curline=line(".")
    if markup#on_heading()
        let cur_level=split(getline('.'), " ")[0]
    else
        let prev_heading_line=markup#previous_heading_linum(0)
        if getline(l:prev_heading_line) =~ "^#\+ "
            let cur_level=split(getline(l:prev_heading_line), " ")[0]
        else
            let cur_level='#'
        end
    end
    let regexp=s:header_regexp
    let heading_line=search(l:regexp, "n")
    if a:same
        let regexp_same="^" . l:cur_level . " "
        let heading_line_same=search(l:regexp_same, "n")
        let l:heading_line=min([l:heading_line, l:heading_line_same])
    endif
    echom l:cur_level
    return max([l:curline, l:heading_line])
endfunction


function! markup#new_section(levels_to_add) abort "{{{1
    if markup#on_heading()
        let headerdepth=strlen(split(getline("."), " ")[0])
    else
        let headerdepth=strlen(split(getline(markup#previous_heading_linum(0)), " ")[0])
    endif

    if markup#next_heading_linum(0) == line(".") " if we're the last heading
        let insert_pos = line("$")                " insert at end of doc
    else
        let insert_pos = markup#next_heading_linum(0) - 1  " otherwise, before next heading
    endif

    let markers=repeat("#", l:headerdepth + a:levels_to_add) . " "
    call append(l:insert_pos, ["", l:markers, ""])
    call cursor(l:insert_pos + 2, 1)
    startinsert!
endfunction

function! markup#header_increase() abort "{{{1
    let save_cursor = getcurpos()
    exec "silent %s/^\\(#\\+\\)/\\1#/"
    call setpos('.', l:save_cursor)
endfunction

function! markup#header_decrease() abort "{{{1
    let save_cursor = getcurpos()
    exec "silent %s/^\\(#\\+\\)#/\\1/"
    call setpos('.', l:save_cursor)
endfunction

function! markup#jump_to_heading(location) abort "{{{1
    exec "edit " . expand(a:location)
    BLines ^\#\+[ ]
endfunction

function! markup#file_headers(location) "{{{1
    let filename=expand(a:location)
    let headers=filter(copy(readfile(l:filename)), {idx, val -> match(val, s:header_regexp) >= 0})
    return l:headers
endfunction

function! markup#goto_previous_heading(same) "{{{1
    call setpos('.', [0, markup#previous_heading_linum(a:same), 1, 0])
endfunction

function! markup#goto_next_heading(same) "{{{1
    call setpos('.', [0, markup#next_heading_linum(a:same), 1, 0])
endfunction

function! markup#choose_header(location) "{{{1
    let headers=markup#file_headers(a:location)
    let choice=inputlist(map(headers, {idx, val -> idx . ". " . val}))
    let chosen_title=headers[l:choice]
    return l:chosen_title
endfunction

function! markup#lowest_header_level() "{{{1
    let has_l1=search("^# ", "n") > 0
    let has_l2=search("^## ", "n") > 0
    let has_l3=search("^### ", "n") > 0
    let has_l4=search("^#### ", "n") > 0
    if has_l1
        return 1
    elseif has_l2
        return 2
    elseif has_l3
        return 3
    elseif has_l4
        return 4
    else
        return 0
    end
endfunction

function! markup#promote_till_l1() "{{{1
    let to_replace=repeat("#", markup#lowest_header_level())
    exec "%s/" . l:to_replace . " /# /g"
    write
endfunction

function! markup#current_heading_level() "{{{1
    let curlevel = 0
    let heading_line=search("^#\\+ ", "nbc")
    if heading_line == 0
        return 0
    endif
    let level=strlen(split(getline(l:heading_line), " ")[0])
    return l:level
endfunction

function! markup#previous_sibling_or_parent() "{{{1
    " Go backwards to a heading of the same level
    " or UP a level, if no headings of the same level
    let curlevel=markup#current_heading_level()
    let rx_same="^" . repeat("#", curlevel) . " "
    let line_previous=search(rx_same, "nb")
    if curlevel > 1
        let rx_up="^" . repeat("#", curlevel-1) . " "
        let line_up=search(rx_up, "nb")
    else
        let line_up=1
    end
    return max([l:line_previous, l:line_up])
endfunction

function! markup#goto_previous_sibling_or_parent() "{{{1
    call setpos('.', [0, markup#previous_sibling_or_parent(), 1, 0])
endfunction

function! markup#next_sibling_or_section() "{{{1
    " Go forwards to a heading of the same level
    " or to the next heading of a higher level
    let curlevel=markup#current_heading_level()
    let rx_same="^" . repeat("#", curlevel) . " "
    let line_next=search(rx_same, "nW")
    if line_next == 0
        let l:line_next=line('$')
    end
    if curlevel > 1
        let rx_up="^" . repeat("#", curlevel-1) . " "
        let line_up=search(rx_up, "nW")
        if line_up == 0
            let l:line_up=line("$")
        end
    else
        let line_up=max([line('.'), search("^#\\+ ", "nW"), line('$')])
    end
    return min([l:line_next, l:line_up])
endfunction

function! markup#goto_next_sibling_or_section() "{{{1
    call setpos('.', [0, markup#next_sibling_or_section(), 1, 0])
endfunction

function! markup#fold_all_but_this_h1() "{{{1
    call search('^# ', 'bc')
    norm zM
    norm zO
endfunction

function! markup#fold_all_but_current_heading() "{{{1
    if !markup#on_heading()
        call search('^' . repeat('#', markup#current_heading_level()), 'bc')
    end
    norm zM
    let c=markup#current_heading_level()
    while c > 1
        let c -= 1
        norm zo
    endwhile
    norm zO
endfunction

function! markup#list_to_h1(line1, line2) abort "{{{
    let num_spaces=substitute(getline(a:line1 + 1), "\\( \\+\\)-.*", "\\1", "")
    let header=substitute(getline(a:line1), "^- \\+", "# ", "")
    let lines = ["", l:header, ""]
    for line in range(a:line1+1, a:line2, 1)
        let replaced=substitute(getline(l:line), "^" . l:num_spaces, "", "")
        call add(l:lines, l:replaced)
    endfor
    exec ":" . a:line1 . "," . a:line2 "delete"
    call append(line('$'), l:lines)
endfunction "}}}


function! markup#replace_cWORD_with_bold() "{{{
    let msg="**" . expand("<cWORD>") . "**"
    exec "norm ciW" . l:msg
endfunction "}}}

function! markup#replace_cWORD_with_italic() "{{{
    let msg="*" . expand("<cWORD>") . "*"
    exec "norm ciW" . l:msg
endfunction "}}}

function! markup#replace_cWORD_with_bolditalic() "{{{
    let msg="***" . expand("<cWORD>") . "***"
    exec "norm ciW" . l:msg
endfunction "}}}

function! markup#replace_region_with_bold() "{{{
    norm y
    norm gv
    let msg="**" . getreg('*') . "**"
    echom l:msg
    exec "norm c" . l:msg
endfunction "}}}

function! markup#replace_region_with_italic() "{{{
    norm y
    norm gv
    let msg="*" . getreg('*') . "*"
    echom l:msg
    exec "norm c" . l:msg
endfunction "}}}

function! markup#replace_region_with_bolditalic() "{{{
    norm y
    norm gv
    let msg="***" . getreg('*') . "***"
    echom l:msg
    exec "norm c" . l:msg
endfunction "}}}


