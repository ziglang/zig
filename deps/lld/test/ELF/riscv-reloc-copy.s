# REQUIRES: riscv
# RUN: llvm-mc -filetype=obj -triple=riscv32 %p/Inputs/relocation-copy.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t1.so
# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.o
# RUN: ld.lld %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s
# RUN: llvm-nm -S %t | FileCheck --check-prefix=NM32 %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %p/Inputs/relocation-copy.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t1.so
# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.o
# RUN: ld.lld %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC %s
# RUN: llvm-nm -S %t | FileCheck --check-prefix=NM64 %s

# RELOC:      .rela.dyn {
# RELOC-NEXT:   0x13000 R_RISCV_COPY x 0x0
# RELOC-NEXT: }

# NM32: 00013000 00000004 B x
# NM64: 0000000000013000 0000000000000004 B x

la a0, x
