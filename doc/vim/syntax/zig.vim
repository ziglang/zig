" Vim syntax file
" Language: Zig
" Maintainer: Andrew Kelley
" Latest Revision: 27 November 2015

if exists("b:current_syntax")
  finish
endif

syn keyword zigKeyword fn return mut const extern unreachable export pub
syn keyword zigType bool i8 u8 i16 u16 i32 u32 i64 u64 isize usize f32 f64 f128 void

let b:current_syntax = "zig"

hi def link zigKeyword Keyword
hi def link zigType Type
