; RUN: llvm-as -o %t.o %s
; RUN: wasm-ld -o %t0 -e main --lto-O0 %t.o
; RUN: obj2yaml %t0 | FileCheck --check-prefix=CHECK-O0 %s
; RUN: wasm-ld -o %t2 -e main --lto-O2 %t.o
; RUN: obj2yaml %t2 | FileCheck --check-prefix=CHECK-O2 %s
; RUN: wasm-ld -o %t2a -e main %t.o
; RUN: obj2yaml %t2a | FileCheck --check-prefix=CHECK-O2 %s

; Reject invalid optimization levels.
; RUN: not ld.lld -o %t3 -e main --lto-O6 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALID %s
; INVALID: invalid optimization level for LTO: 6

; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --lto-O-1 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALIDNEGATIVE %s
; INVALIDNEGATIVE: invalid optimization level for LTO: 4294967295

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown-wasm"

; CHECK-O0: Name: foo
; CHECK-O2-NOT: Name: foo
define internal void @foo() {
  ret void
}

define void @main() {
  call void @foo()
  ret void
}
