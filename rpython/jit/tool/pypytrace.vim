" Language   : PyPy JIT traces
" Maintainer : Armin Rigo
" Usage      : set syntax=pypytrace

if exists("b:current_syntax")
 finish
endif

syn case ignore

syn match pypyNumber      '\<[0-9.]\+\>'
syn match pypyConstPtr    '\<ptr\d\+\>'
syn region pypyDescr      start=/descr=</ end=/>/ contains=pypyDescrField
syn match pypyDescrField  '[.]\w\+ ' contained
syn match pypyOpNameStart '^' nextgroup=pypyOpName
syn match pypyOpNameEqual ' = ' nextgroup=pypyOpName
syn match pypyOpName      '\l\l\w\+' contained
syn match pypyFailArgs    '[[].*[]]'
syn match pypyLoopArgs    '^[[].*'
syn match pypyLoopStart   '^#.*'
syn match pypyDebugMergePoint  '^debug_merge_point(.\+)'
syn match pypyLogBoundary '[[][0-9a-f]\+[]] \([{].\+\|.\+[}]\)$'

hi def link pypyLoopStart   Structure
"hi def link pypyLoopArgs    PreProc
hi def link pypyFailArgs    Special
"hi def link pypyOpName      Statement
hi def link pypyDebugMergePoint  String
hi def link pypyConstPtr    Constant
hi def link pypyNumber      Number
hi def link pypyDescr       PreProc
hi def link pypyDescrField  Label
hi def link pypyLogBoundary Statement
