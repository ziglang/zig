# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: not lld-link /out:%t.exe %t.obj 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: ?foo@@YAHXZ
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(main)
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(main)

# CHECK: error: undefined symbol: ?bar@@YAHXZ
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(main)
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(f1)

# CHECK: error: undefined symbol: ?baz@@YAHXZ
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(f2)

        .section        .text,"xr",one_only,main
.globl main
main:
	call	"?foo@@YAHXZ"
	call	"?foo@@YAHXZ"
	call	"?bar@@YAHXZ"

f1:
	call	"?bar@@YAHXZ"
.Lfunc_end1:

        .section        .text,"xr",one_only,f2
.globl f2
f2:
	call	"?baz@@YAHXZ"
