; RUN: llvm-as -o %t %s
; RUN: lld-link /entry:main /subsystem:console /out:%t.exe %t
; RUN: llvm-objdump -d %t.exe | FileCheck %s

target datalayout = "e-m:x-p:32:32-i64:64-f80:32-n8:16:32-a:0:32-S32"
target triple = "i686-pc-windows-msvc"

@foo = thread_local global i8 0

module asm "__tls_index = 1"
module asm "__tls_array = 2"

define i8* @main() {
  ; CHECK: movl 1, %eax
  ; CHECK: movl %fs:2, %ecx
  ; CHECK: movl (%ecx,%eax,4), %eax
  ; CHECK: leal (%eax), %eax
  ret i8* @foo
}
