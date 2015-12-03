" Vim syntax file
" Language: Zig
" Maintainer: Andrew Kelley
" Latest Revision: 02 December 2015

if exists("b:current_syntax")
  finish
endif

syn keyword zigKeyword fn return mut const extern unreachable export pub as use if else let void goto
syn keyword zigType bool i8 u8 i16 u16 i32 u32 i64 u64 isize usize f32 f64 f128

syn region zigCommentLine start="//" end="$" contains=zigTodo,@Spell
syn region zigCommentLineDoc start="//\%(//\@!\|!\)" end="$" contains=zigTodo,@Spell
syn region zigCommentBlock matchgroup=zigCommentBlock start="/\*\%(!\|\*[*/]\@!\)\@!" end="\*/" contains=zigTodo,zigCommentBlockNest,@Spell
syn region zigCommentBlockDoc matchgroup=zigCommentBlockDoc start="/\*\%(!\|\*[*/]\@!\)" end="\*/" contains=zigTodo,zigCommentBlockDocNest,@Spell
syn region zigCommentBlockNest matchgroup=zigCommentBlock start="/\*" end="\*/" contains=zigTodo,zigCommentBlockNest,@Spell contained transparent
syn region zigCommentBlockDocNest matchgroup=zigCommentBlockDoc start="/\*" end="\*/" contains=zigTodo,zigCommentBlockDocNest,@Spell contained transparent

syn keyword zigTodo contained TODO XXX

syn match     zigEscapeError   display contained /\\./
syn match     zigEscape        display contained /\\\([nrt0\\'"]\|x\x\{2}\)/
syn match     zigEscapeUnicode display contained /\\\(u\x\{4}\|U\x\{8}\)/
syn match     zigEscapeUnicode display contained /\\u{\x\{1,6}}/
syn match     zigStringContinuation display contained /\\\n\s*/
syn region    zigString      start=+b"+ skip=+\\\\\|\\"+ end=+"+ contains=zigEscape,zigEscapeError,zigStringContinuation
syn region    zigString      start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=zigEscape,zigEscapeUnicode,zigEscapeError,zigStringContinuation,@Spell
syn region    zigString      start='b\?r\z(#*\)"' end='"\z1' contains=@Spell

let b:current_syntax = "zig"

hi def link zigKeyword Keyword
hi def link zigType Type
hi def link zigCommentLine Comment
hi def link zigCommentLineDoc SpecialComment
hi def link zigCommentBlock zigCommentLine
hi def link zigCommentBlockDoc zigCommentLineDoc
hi def link zigTodo Todo
hi def link zigStringContinuation Special
hi def link zigString String
hi def link zigEscape Special
hi def link zigEscapeUnicode zigEscape
hi def link zigEscapeError Error
