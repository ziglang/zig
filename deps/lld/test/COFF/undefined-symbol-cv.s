# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: not lld-link /out:%t.exe %t.obj 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: int __cdecl foo(void)
# CHECK-NEXT: >>> referenced by file1.cpp:1
# CHECK-NEXT: >>>               {{.*}}.obj:(main)
# CHECK-NEXT: >>> referenced by file1.cpp:2
# CHECK-NEXT: >>>               {{.*}}.obj:(main)
# CHECK-EMPTY:
# CHECK-NEXT: error: undefined symbol: int __cdecl bar(void)
# CHECK-NEXT: >>> referenced by file2.cpp:3
# CHECK-NEXT: >>>               {{.*}}.obj:(main)
# CHECK-NEXT: >>> referenced by file1.cpp:4
# CHECK-NEXT: >>>               {{.*}}.obj:(f1)
# CHECK-EMPTY:
# CHECK-NEXT: error: undefined symbol: int __cdecl baz(void)
# CHECK-NEXT: >>> referenced by file1.cpp:5
# CHECK-NEXT: >>>               {{.*}}.obj:(f2)

	.cv_file	1 "file1.cpp" "EDA15C78BB573E49E685D8549286F33C" 1
	.cv_file	2 "file2.cpp" "EDA15C78BB573E49E685D8549286F33D" 1

        .section        .text,"xr",one_only,main
.globl main
main:
	.cv_func_id 0
	.cv_loc	0 1 1 0 is_stmt 0
	call	"?foo@@YAHXZ"
	.cv_loc	0 1 2 0
	call	"?foo@@YAHXZ"
	.cv_loc	0 2 3 0
	call	"?bar@@YAHXZ"
.Lfunc_end0:

f1:
	.cv_func_id 1
	.cv_loc	1 1 4 0 is_stmt 0
	call	"?bar@@YAHXZ"
.Lfunc_end1:

        .section        .text,"xr",one_only,f2
.globl f2
f2:
	.cv_func_id 2
	.cv_loc	2 1 5 0 is_stmt 0
	call	"?baz@@YAHXZ"
.Lfunc_end2:

	.section	.debug$S,"dr",associative,main
	.long	4
	.cv_linetable	0, main, .Lfunc_end0
	.cv_linetable	1, f1, .Lfunc_end1

	.section	.debug$S,"dr",associative,f2
	.long	4
	.cv_linetable	2, f2, .Lfunc_end2

	.section	.debug$S,"dr"
	.long	4
	.cv_filechecksums
	.cv_stringtable
