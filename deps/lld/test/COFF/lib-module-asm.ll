; REQUIRES: x86
; PR41803: llvm-link /lib on object with module asm crashes
; RUN: rm -f %t.lib
; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /lib /out:%t.lib %t.obj
; RUN: llvm-nm -M %t.lib | FileCheck %s

target datalayout = "e-m:x-p:32:32-i64:64-f80:32-n8:16:32-a:0:32-S32"
target triple = "i386-pc-windows-msvc19.11.0"

module asm ".global global_asm_sym"
module asm "global_asm_sym:"
module asm "local_asm_sym:"
module asm ".long undef_asm_sym"

; CHECK: Archive map
; CHECK-NEXT: global_asm_sym in {{.*}}lib-module-asm.ll.tmp.obj

; CHECK: lib-module-asm.ll.tmp.obj:{{$}}
; CHECK-NEXT:         T global_asm_sym
; CHECK-NEXT:         t local_asm_sym
; CHECK-NEXT:         U undef_asm_sym
