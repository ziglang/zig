" Vim syntax file
" Language: Zig
" Maintainer: Andrew Kelley
" Latest Revision: 27 November 2015

if exists("b:current_syntax")
  finish
endif

syn keyword zigKeyword fn return mut const extern unreachable export pub
syn keyword zigType bool i8 u8 i16 u16 i32 u32 i64 u64 isize usize f32 f64 f128 void

syn region zigCommentLine start="//" end="$" contains=zigTodo,@Spell
syn region zigCommentLineDoc start="//\%(//\@!\|!\)" end="$" contains=zigTodo,@Spell
syn region zigCommentBlock matchgroup=zigCommentBlock start="/\*\%(!\|\*[*/]\@!\)\@!" end="\*/" contains=zigTodo,zigCommentBlockNest,@Spell
syn region zigCommentBlockDoc matchgroup=zigCommentBlockDoc start="/\*\%(!\|\*[*/]\@!\)" end="\*/" contains=zigTodo,zigCommentBlockDocNest,@Spell
syn region zigCommentBlockNest matchgroup=zigCommentBlock start="/\*" end="\*/" contains=zigTodo,zigCommentBlockNest,@Spell contained transparent
syn region zigCommentBlockDocNest matchgroup=zigCommentBlockDoc start="/\*" end="\*/" contains=zigTodo,zigCommentBlockDocNest,@Spell contained transparent

syn keyword zigTodo contained TODO XXX

let b:current_syntax = "zig"

hi def link zigKeyword Keyword
hi def link zigType Type
hi def link zigCommentLine Comment
hi def link zigCommentLineDoc SpecialComment
hi def link zigCommentBlock zigCommentLine
hi def link zigCommentBlockDoc zigCommentLineDoc
hi def link zigTodo Todo

