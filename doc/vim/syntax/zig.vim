" Vim syntax file
" Language: Zig
" Maintainer: Andrew Kelley
" Latest Revision: 03 August 2016

if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "zig"

syn keyword zigStorage const var extern export pub noalias inline noinline
syn keyword zigStructure struct enum union
syn keyword zigStatement goto break return continue asm defer
syn keyword zigConditional if else switch
syn keyword zigRepeat while for

syn keyword zigConstant null undefined zeroes
syn keyword zigKeyword fn use
syn keyword zigType bool f32 f64 void unreachable type error
syn keyword zigType i8  u8  i16  u16  i32  u32  i64  u64  isize  usize
syn keyword zigType c_short c_ushort c_int c_uint c_long c_ulong c_longlong c_ulonglong c_long_double

syn keyword zigBoolean true false

syn match zigOperator display "\%(+%\?\|-%\?\|/\|*%\?\|=\|\^\|&\|?\||\|!\|>\|<\|%\|<<%\?\|>>\|&&\|||\)=\?"
syn match zigArrowCharacter display "->"

syn match zigDecNumber display "\<[0-9]*\%(.[0-9]\+\)\=\%([eE][+-]\?[0-9]\+\)\="
syn match zigHexNumber display "\<0x[a-fA-F0-9]\+\%(.[a-fA-F0-9]\+\%([pP][+-]\?[0-9]\+\)\?\)\="
syn match zigOctNumber display "\<0o[0-7]\+"
syn match zigBinNumber display "\<0b[01]\+\%(.[01]\+\%([eE][+-]\?[0-9]\+\)\?\)\="


syn match zigCharacterInvalid display contained /b\?'\zs[\n\r\t']\ze'/
syn match zigCharacterInvalidUnicode display contained /b'\zs[^[:cntrl:][:graph:][:alnum:][:space:]]\ze'/
syn match zigCharacter /b'\([^\\]\|\\\(.\|x\x\{2}\)\)'/ contains=zigEscape,zigEscapeError,zigCharacterInvalid,zigCharacterInvalidUnicode
syn match zigCharacter /'\([^\\]\|\\\(.\|x\x\{2}\|u\x\{4}\|U\x\{6}\)\)'/ contains=zigEscape,zigEscapeUnicode,zigEscapeError,zigCharacterInvalid

syn region zigCommentLine start="//" end="$" contains=zigTodo,@Spell
syn region zigCommentLineDoc start="//\%(//\@!\|!\)" end="$" contains=zigTodo,@Spell

" TODO match only the first '\\' within the zigMultilineString as zigMultilineStringPrefix
syn match zigMultilineStringPrefix display contained /c\?\\\\/
syn region zigMultilineString start="c\?\\\\" end="$" contains=zigMultilineStringPrefix

syn keyword zigTodo contained TODO XXX

syn match     zigEscapeError   display contained /\\./
syn match     zigEscape        display contained /\\\([nrt\\'"]\|x\x\{2}\)/
syn match     zigEscapeUnicode display contained /\\\(u\x\{4}\|U\x\{6}\)/
syn region    zigString      start=+c\?"+ skip=+\\\\\|\\"+ end=+"+ oneline contains=zigEscape,zigEscapeUnicode,zigEscapeError,@Spell

hi def link zigDecNumber zigNumber
hi def link zigHexNumber zigNumber
hi def link zigOctNumber zigNumber
hi def link zigBinNumber zigNumber

hi def link zigKeyword Keyword
hi def link zigType Type
hi def link zigCommentLine Comment
hi def link zigCommentLineDoc SpecialComment
hi def link zigTodo Todo
hi def link zigString String
hi def link zigMultilineString String
hi def link zigMultilineStringPrefix Comment
hi def link zigCharacterInvalid Error
hi def link zigCharacterInvalidUnicode zigCharacterInvalid
hi def link zigCharacter Character
hi def link zigEscape Special
hi def link zigEscapeUnicode zigEscape
hi def link zigEscapeError Error
hi def link zigBoolean Boolean
hi def link zigConstant Constant
hi def link zigNumber Number
hi def link zigArrowCharacter zigOperator
hi def link zigOperator Operator
hi def link zigStorage StorageClass
hi def link zigStructure Structure
hi def link zigStatement Statement
hi def link zigConditional Conditional
hi def link zigRepeat Repeat
