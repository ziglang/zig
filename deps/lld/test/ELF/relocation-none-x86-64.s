# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-musl %s -o %t.o
# RUN: ld.lld --gc-sections %t.o -o %t
# RUN: llvm-readelf -S -r %t | FileCheck %s

# Test that we discard R_X86_64_NONE, but respect the
# references it creates among sections.

# CHECK: .data
# CHECK: There are no relocations in this file.

# RUN: ld.lld -r %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s

# RELOC:      Section ({{.*}}) .rela.text {
# RELOC-NEXT:   0x0 R_X86_64_NONE .data 0x0
# RELOC-NEXT: }

.globl _start
_start:
  ret
  .reloc 0, R_X86_64_NONE, .data

.data
  .long 0
