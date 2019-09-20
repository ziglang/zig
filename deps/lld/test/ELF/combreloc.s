# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: echo 'mov aaa@gotpcrel(%rip), %rax' | llvm-mc -filetype=obj -triple=x86_64 - -o %t1.o

# RUN: ld.lld -shared %t.o %t1.o -o %t.so
# RUN: llvm-readobj -r --dynamic-table %t.so | FileCheck %s
# RUN: ld.lld -shared %t.o %t1.o -o %t.so -z combreloc
# RUN: llvm-readobj -r --dynamic-table %t.so | FileCheck %s

# -z combreloc is the default: sort relocations by (!IsRelative,SymIndex,r_offset),
# and emit DT_RELACOUNT (except on MIPS) to indicate the number of relative
# relocations.

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     0x3020 R_X86_64_RELATIVE - 0x3028
# CHECK-NEXT:     0x20B0 R_X86_64_GLOB_DAT aaa 0x0
# CHECK-NEXT:     0x3000 R_X86_64_64 aaa 0x0
# CHECK-NEXT:     0x3018 R_X86_64_64 aaa 0x0
# CHECK-NEXT:     0x3010 R_X86_64_64 bbb 0x0
# CHECK-NEXT:     0x3008 R_X86_64_64 ccc 0x0
# CHECK-NEXT:   }
# CHECK:      DynamicSection [
# CHECK:        RELACOUNT 1

# RUN: ld.lld -z nocombreloc -shared %t.o %t1.o -o %t.so
# RUN: llvm-readobj -r --dynamic-table %t.so | FileCheck --check-prefix=NOCOMB %s

# NOCOMB:      Relocations [
# NOCOMB-NEXT:   Section ({{.*}}) .rela.dyn {
# NOCOMB-NEXT:     0x3000 R_X86_64_64 aaa 0x0
# NOCOMB-NEXT:     0x3008 R_X86_64_64 ccc 0x0
# NOCOMB-NEXT:     0x3010 R_X86_64_64 bbb 0x0
# NOCOMB-NEXT:     0x3018 R_X86_64_64 aaa 0x0
# NOCOMB-NEXT:     0x3020 R_X86_64_RELATIVE - 0x3028
# NOCOMB-NEXT:     0x20A0 R_X86_64_GLOB_DAT aaa 0x0
# NOCOMB-NEXT:   }
# NOCOMB:      DynamicSection [
# NOCOMB-NOT:    RELACOUNT

.data
 .quad aaa
 .quad ccc
 .quad bbb
 .quad aaa
 .quad relative
relative:
