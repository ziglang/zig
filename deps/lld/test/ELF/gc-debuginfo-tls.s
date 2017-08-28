# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --gc-sections -shared -o %t1
# RUN: ld.lld %t.o -shared -o %t2
# RUN: llvm-readobj -symbols %t1 | FileCheck %s --check-prefix=GC
# RUN: llvm-readobj -symbols %t2 | FileCheck %s --check-prefix=NOGC

# NOGC:      Symbol {
# NOGC:        Name: patatino
# NOGC-NEXT:   Value: 0x0
# NOGC-NEXT:   Size: 0
# NOGC-NEXT:   Binding: Local
# NOGC-NEXT:   Type: TLS
# NOGC-NEXT:   Other: 0
# NOGC-NEXT:   Section: .tbss
# NOGC-NEXT: }

# GC-NOT: tbss

.section .tbss,"awT",@nobits
patatino:
  .long 0
  .section .noalloc,""
  .quad patatino
