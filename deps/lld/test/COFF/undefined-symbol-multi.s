# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s

# All references to a single undefined symbol count as a single error -- but
# at most 10 references are printed.
# RUN: echo ".globl bar" > %t.moreref.s
# RUN: echo "bar:" >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: echo '  call "?foo@@YAHXZ"' >> %t.moreref.s
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t2.obj %t.moreref.s
# RUN: not lld-link /out:/dev/null  %t.obj %t2.obj 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: int __cdecl foo(void)
# CHECK-NEXT: >>> referenced by {{.*}}tmp.obj:(main)
# CHECK-NEXT: >>> referenced by {{.*}}tmp.obj:(main)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.obj:(bar)
# CHECK-NEXT: >>> referenced 2 more times
# CHECK-EMPTY:
# CHECK-NEXT: error: undefined symbol: int __cdecl bar(void)
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(main)
# CHECK-NEXT: >>> referenced by {{.*}}.obj:(f1)

        .section        .text,"xr",one_only,main
.globl main
main:
	call	"?foo@@YAHXZ"
	call	"?foo@@YAHXZ"
	call	"?bar@@YAHXZ"

f1:
	call	"?bar@@YAHXZ"
.Lfunc_end1:
