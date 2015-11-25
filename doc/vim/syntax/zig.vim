" Vim syntax file
" Language: Zig
" Maintainer: Andrew Kelley
" Latest Revision: 24 November 2015

if exists("b:current_syntax")
  finish
endif

syn keyword zigKeyword fn return mut const extern unreachable

let b:current_syntax = "zig"

hi def link zigKeyword Keyword
