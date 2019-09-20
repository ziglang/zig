; REQUIRES: shell
; RUN: rm -rf %t.dir
; RUN: mkdir -p %t.dir
; RUN: llc -filetype=obj %s -o %t.dir/foo.o
; RUN: wasm-ld --reproduce=%t.dir/repro.tar -o %t.dir/out.wasm %t.dir/foo.o

; RUN: cd %t.dir
; RUN: tar tf repro.tar | FileCheck --check-prefix=TAR %s

; TAR: repro/response.txt
; TAR: repro/version.txt
; TAR: repro/{{.*}}/foo.o

; RUN: tar xf repro.tar
; RUN: FileCheck --check-prefix=RSP %s < repro/response.txt

; RSP: -o {{.*}}out.wasm
; RSP: {{.*}}/foo.o

; RUN: FileCheck %s --check-prefix=VERSION < repro/version.txt
; VERSION: LLD

target triple = "wasm32-unknown-unknown"

define void @_start() {
  ret void
}
