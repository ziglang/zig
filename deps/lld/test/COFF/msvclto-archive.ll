; REQUIRES: x86
;; Make sure we re-create archive files to strip bitcode files.

;; Do not create empty archives because the MSVC linker
;; doesn't support them.
; RUN: llvm-as -o %t.obj %s
; RUN: rm -f %t-main1.a
; RUN: llvm-ar cru %t-main1.a %t.obj
; RUN: mkdir -p %t.dir
; RUN: llvm-mc -triple=x86_64-pc-windows-msvc -filetype=obj -o %t.dir/bitcode.obj %p/Inputs/msvclto.s
; RUN: lld-link %t-main1.a %t.dir/bitcode.obj /msvclto /out:%t.exe /opt:lldlto=1 /opt:icf \
; RUN:   /entry:main /verbose 2> %t.log || true
; RUN: FileCheck -check-prefix=BC %s < %t.log
; BC-NOT: Creating a temporary archive for

; RUN: rm -f %t-main2.a
; RUN: llvm-ar cru %t-main2.a %t.dir/bitcode.obj
; RUN: lld-link %t.obj %t-main2.a /msvclto /out:%t.exe /opt:lldlto=1 /opt:icf \
; RUN:   /entry:main /verbose 2> %t.log || true
; RUN: FileCheck -check-prefix=OBJ %s < %t.log
; OBJ-NOT: Creating a temporary archive

;; Make sure that we always rebuild thin archives because
;; the MSVC linker doesn't support thin archives.
; RUN: rm -f %t-main3.a
; RUN: llvm-ar cruT %t-main3.a %t.dir/bitcode.obj
; RUN: lld-link %t.obj %t-main3.a /msvclto /out:%t.exe /opt:lldlto=1 /opt:icf \
; RUN:   /entry:main /verbose 2> %t.log || true
; RUN: FileCheck -check-prefix=THIN %s < %t.log
; THIN: Creating a temporary archive

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @foo()

define i32 @main() {
  call void @foo()
  ret i32 0
}
