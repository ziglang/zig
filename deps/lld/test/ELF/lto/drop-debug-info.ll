; REQUIRES: x86
;
; drop-debug-info.bc was created from "void f(void) {}" with clang 3.5 and
; -gline-tables-only, so it contains old debug info.
;
; RUN: ld.lld -m elf_x86_64 -shared %p/Inputs/drop-debug-info.bc \
; RUN: -disable-verify 2>&1 | FileCheck %s
; CHECK: ignoring debug info with an invalid version (1) in {{.*}}drop-debug-info.bc

