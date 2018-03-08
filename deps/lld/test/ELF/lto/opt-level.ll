; REQUIRES: x86
; RUN: llvm-as -o %t.o %s
; RUN: ld.lld -o %t0 -m elf_x86_64 -e main --lto-O0 %t.o
; RUN: llvm-nm %t0 | FileCheck --check-prefix=CHECK-O0 %s
; RUN: ld.lld -o %t0 -m elf_x86_64 -e main --plugin-opt=O0 %t.o
; RUN: llvm-nm %t0 | FileCheck --check-prefix=CHECK-O0 %s
; RUN: ld.lld -o %t2 -m elf_x86_64 -e main --lto-O2 %t.o
; RUN: llvm-nm %t2 | FileCheck --check-prefix=CHECK-O2 %s
; RUN: ld.lld -o %t2a -m elf_x86_64 -e main %t.o
; RUN: llvm-nm %t2a | FileCheck --check-prefix=CHECK-O2 %s
; RUN: ld.lld -o %t2 -m elf_x86_64 -e main --plugin-opt=O2 %t.o
; RUN: llvm-nm %t2 | FileCheck --check-prefix=CHECK-O2 %s

; Reject invalid optimization levels.
; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --lto-O6 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALID1 %s
; INVALID1: invalid optimization level for LTO: 6
; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --plugin-opt=O6 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALID1 %s
; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --plugin-opt=Ofoo %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALID2 %s
; INVALID2: --plugin-opt: number expected, but got 'foo'

; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --lto-O-1 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALIDNEGATIVE1 %s
; INVALIDNEGATIVE1: invalid optimization level for LTO: 4294967295
; RUN: not ld.lld -o %t3 -m elf_x86_64 -e main --plugin-opt=O-1 %t.o 2>&1 | \
; RUN:   FileCheck --check-prefix=INVALIDNEGATIVE2 %s
; INVALIDNEGATIVE2: invalid optimization level for LTO: 4294967295

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; CHECK-O0: foo
; CHECK-O2-NOT: foo
define internal void @foo() {
  ret void
}

define void @main() {
  call void @foo()
  ret void
}
