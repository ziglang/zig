; RUN: llc -mtriple=i686-pc-windows-msvc -filetype=obj -o %T/lto-lazy-reference-quadruple.obj %S/Inputs/lto-lazy-reference-quadruple.ll
; RUN: llvm-as -o %T/lto-lazy-reference-dummy.bc %S/Inputs/lto-lazy-reference-dummy.ll
; RUN: rm -f %t.lib
; RUN: llvm-ar cru %t.lib %T/lto-lazy-reference-quadruple.obj %T/lto-lazy-reference-dummy.bc
; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /out:%t.exe /entry:main /subsystem:console %t.obj %t.lib

target datalayout = "e-m:x-p:32:32-i64:64-f80:32-n8:16:32-a:0:32-S32"
target triple = "i686-pc-windows-msvc18.0.0"

define double @main(double %x) {
entry:
  ; When compiled, this defines the __real@40800000 symbol, which already has a
  ; lazy definition in the lib file from  lto-lazy-reference-quadruple.obj. This
  ; test makes sure we *don't* try to take the definition from the lazy
  ; reference, because that can bring in new references to bitcode files after
  ; LTO, such as lto-lazy-reference-dummy.bc in this case.
  %mul = fmul double %x, 4.0

  ret double %mul
}
