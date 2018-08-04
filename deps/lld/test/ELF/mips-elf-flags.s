# REQUIRES: mips
# Check generation of MIPS specific ELF header flags.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t-so.o
# RUN: ld.lld %t-so.o --gc-sections -shared -o %t.so
# RUN: llvm-readobj -h -mips-abi-flags %t.so | FileCheck -check-prefix=SO %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-readobj -h -mips-abi-flags %t.exe | FileCheck -check-prefix=EXE %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r2 %s -o %t-r2.o
# RUN: ld.lld %t-r2.o -o %t-r2.exe
# RUN: llvm-readobj -h -mips-abi-flags %t-r2.exe \
# RUN:   | FileCheck -check-prefix=EXE-R2 %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r2 %s -o %t-r2.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r5 %S/Inputs/mips-dynamic.s -o %t-r5.o
# RUN: ld.lld %t-r2.o %t-r5.o -o %t-r5.exe
# RUN: llvm-readobj -h -mips-abi-flags %t-r5.exe \
# RUN:   | FileCheck -check-prefix=EXE-R5 %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r6 %s -o %t-r6.o
# RUN: ld.lld %t-r6.o -o %t-r6.exe
# RUN: llvm-readobj -h -mips-abi-flags %t-r6.exe \
# RUN:   | FileCheck -check-prefix=EXE-R6 %s

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         -position-independent -mcpu=octeon %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-readobj -h -mips-abi-flags %t.exe \
# RUN:   | FileCheck -check-prefix=OCTEON %s

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-fpic.s -o %t-mm.o
# RUN: ld.lld %t.o %t-mm.o -o %t.exe
# RUN: llvm-readobj -h -mips-abi-flags %t.exe | FileCheck -check-prefix=MICRO %s

  .text
  .globl  __start
__start:
  nop

# SO:      Flags [
# SO-NEXT:   EF_MIPS_ABI_O32
# SO-NEXT:   EF_MIPS_ARCH_32
# SO-NEXT:   EF_MIPS_CPIC
# SO-NEXT:   EF_MIPS_PIC
# SO-NEXT: ]
# SO:      MIPS ABI Flags {
# SO-NEXT:   Version: 0
# SO-NEXT:   ISA: MIPS32
# SO-NEXT:   ISA Extension: None
# SO-NEXT:   ASEs [
# SO-NEXT:   ]
# SO-NEXT:   FP ABI: Hard float (double precision)
# SO-NEXT:   GPR size: 32
# SO-NEXT:   CPR1 size: 32
# SO-NEXT:   CPR2 size: 0
# SO-NEXT:   Flags 1 [
# SO-NEXT:     ODDSPREG
# SO-NEXT:   ]
# SO-NEXT:   Flags 2: 0x0
# SO-NEXT: }

# EXE:      Flags [
# EXE-NEXT:   EF_MIPS_ABI_O32
# EXE-NEXT:   EF_MIPS_ARCH_32
# EXE-NEXT:   EF_MIPS_CPIC
# EXE-NEXT: ]
# EXE:      MIPS ABI Flags {
# EXE-NEXT:   Version: 0
# EXE-NEXT:   ISA: MIPS32
# EXE-NEXT:   ISA Extension: None
# EXE-NEXT:   ASEs [
# EXE-NEXT:   ]
# EXE-NEXT:   FP ABI: Hard float (double precision)
# EXE-NEXT:   GPR size: 32
# EXE-NEXT:   CPR1 size: 32
# EXE-NEXT:   CPR2 size: 0
# EXE-NEXT:   Flags 1 [
# EXE-NEXT:     ODDSPREG
# EXE-NEXT:   ]
# EXE-NEXT:   Flags 2: 0x0
# EXE-NEXT: }

# EXE-R2:      Flags [
# EXE-R2-NEXT:   EF_MIPS_ABI_O32
# EXE-R2-NEXT:   EF_MIPS_ARCH_32R2
# EXE-R2-NEXT:   EF_MIPS_CPIC
# EXE-R2-NEXT: ]
# EXE-R2:      MIPS ABI Flags {
# EXE-R2-NEXT:   Version: 0
# EXE-R2-NEXT:   ISA: MIPS32r2
# EXE-R2-NEXT:   ISA Extension: None
# EXE-R2-NEXT:   ASEs [
# EXE-R2-NEXT:   ]
# EXE-R2-NEXT:   FP ABI: Hard float (double precision)
# EXE-R2-NEXT:   GPR size: 32
# EXE-R2-NEXT:   CPR1 size: 32
# EXE-R2-NEXT:   CPR2 size: 0
# EXE-R2-NEXT:   Flags 1 [
# EXE-R2-NEXT:     ODDSPREG
# EXE-R2-NEXT:   ]
# EXE-R2-NEXT:   Flags 2: 0x0
# EXE-R2-NEXT: }

# EXE-R5:      Flags [
# EXE-R5-NEXT:   EF_MIPS_ABI_O32
# EXE-R5-NEXT:   EF_MIPS_ARCH_32R2
# EXE-R5-NEXT:   EF_MIPS_CPIC
# EXE-R5-NEXT: ]
# EXE-R5:      MIPS ABI Flags {
# EXE-R5-NEXT:   Version: 0
# EXE-R5-NEXT:   ISA: MIPS32r5
# EXE-R5-NEXT:   ISA Extension: None
# EXE-R5-NEXT:   ASEs [
# EXE-R5-NEXT:   ]
# EXE-R5-NEXT:   FP ABI: Hard float (double precision)
# EXE-R5-NEXT:   GPR size: 32
# EXE-R5-NEXT:   CPR1 size: 32
# EXE-R5-NEXT:   CPR2 size: 0
# EXE-R5-NEXT:   Flags 1 [
# EXE-R5-NEXT:     ODDSPREG
# EXE-R5-NEXT:   ]
# EXE-R5-NEXT:   Flags 2: 0x0
# EXE-R5-NEXT: }

# EXE-R6:      Flags [
# EXE-R6-NEXT:   EF_MIPS_ABI_O32
# EXE-R6-NEXT:   EF_MIPS_ARCH_32R6
# EXE-R6-NEXT:   EF_MIPS_CPIC
# EXE-R6-NEXT:   EF_MIPS_NAN2008
# EXE-R6-NEXT: ]
# EXE-R6:      MIPS ABI Flags {
# EXE-R6-NEXT:   Version: 0
# EXE-R6-NEXT:   ISA: MIPS32
# EXE-R6-NEXT:   ISA Extension: None
# EXE-R6-NEXT:   ASEs [
# EXE-R6-NEXT:   ]
# EXE-R6-NEXT:   FP ABI: Hard float (32-bit CPU, 64-bit FPU)
# EXE-R6-NEXT:   GPR size: 32
# EXE-R6-NEXT:   CPR1 size: 64
# EXE-R6-NEXT:   CPR2 size: 0
# EXE-R6-NEXT:   Flags 1 [
# EXE-R6-NEXT:     ODDSPREG
# EXE-R6-NEXT:   ]
# EXE-R6-NEXT:   Flags 2: 0x0
# EXE-R6-NEXT: }

# OCTEON:      Flags [
# OCTEON-NEXT:   EF_MIPS_ARCH_64R2
# OCTEON-NEXT:   EF_MIPS_CPIC
# OCTEON-NEXT:   EF_MIPS_MACH_OCTEON
# OCTEON-NEXT:   EF_MIPS_PIC
# OCTEON-NEXT: ]
# OCTEON:      MIPS ABI Flags {
# OCTEON-NEXT:   Version: 0
# OCTEON-NEXT:   ISA: MIPS64r2
# OCTEON-NEXT:   ISA Extension: Cavium Networks Octeon
# OCTEON-NEXT:   ASEs [
# OCTEON-NEXT:   ]
# OCTEON-NEXT:   FP ABI: Hard float (double precision)
# OCTEON-NEXT:   GPR size: 64
# OCTEON-NEXT:   CPR1 size: 64
# OCTEON-NEXT:   CPR2 size: 0
# OCTEON-NEXT:   Flags 1 [
# OCTEON-NEXT:     ODDSPREG
# OCTEON-NEXT:   ]
# OCTEON-NEXT:   Flags 2: 0x0
# OCTEON-NEXT: }

# MICRO:      Flags [
# MICRO-NEXT:   EF_MIPS_ABI_O32
# MICRO-NEXT:   EF_MIPS_ARCH_32
# MICRO-NEXT:   EF_MIPS_CPIC
# MICRO-NEXT:   EF_MIPS_MICROMIPS
# MICRO-NEXT: ]
# MICRO:      MIPS ABI Flags {
# MICRO-NEXT:   Version: 0
# MICRO-NEXT:   ISA: MIPS32
# MICRO-NEXT:   ISA Extension: None
# MICRO-NEXT:   ASEs [
# MICRO-NEXT:     microMIPS
# MICRO-NEXT:   ]
# MICRO-NEXT:   FP ABI: Hard float (double precision)
# MICRO-NEXT:   GPR size: 32
# MICRO-NEXT:   CPR1 size: 32
# MICRO-NEXT:   CPR2 size: 0
# MICRO-NEXT:   Flags 1 [
# MICRO-NEXT:     ODDSPREG
# MICRO-NEXT:   ]
# MICRO-NEXT:   Flags 2: 0x0
# MICRO-NEXT: }
