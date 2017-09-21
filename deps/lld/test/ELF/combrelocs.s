# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.out
# RUN: llvm-readobj -r --expand-relocs --dynamic-table %t.out | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x1000
# CHECK-NEXT:       Type: R_X86_64_64
# CHECK-NEXT:       Symbol: aaa (1)
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x1018
# CHECK-NEXT:       Type: R_X86_64_64
# CHECK-NEXT:       Symbol: aaa (1)
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x1010
# CHECK-NEXT:       Type: R_X86_64_64
# CHECK-NEXT:       Symbol: bbb (2)
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x1008
# CHECK-NEXT:       Type: R_X86_64_64
# CHECK-NEXT:       Symbol: ccc (3)
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x1020
# CHECK-NEXT:       Type: R_X86_64_64
# CHECK-NEXT:       Symbol: ddd (4)
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK:      DynamicSection [
# CHECK-NEXT:   Tag
# CHECK-NOT:    RELACOUNT

# RUN: ld.lld -z nocombreloc -shared %t.o -o %t.out
# RUN: llvm-readobj -r --expand-relocs --dynamic-table %t.out | \
# RUN:    FileCheck --check-prefix=NOCOMB %s

# NOCOMB:      Relocations [
# NOCOMB-NEXT:    Section ({{.*}}) .rela.dyn {
# NOCOMB-NEXT:     Relocation {
# NOCOMB-NEXT:       Offset: 0x1000
# NOCOMB-NEXT:       Type: R_X86_64_64
# NOCOMB-NEXT:       Symbol: aaa (1)
# NOCOMB-NEXT:       Addend: 0x0
# NOCOMB-NEXT:     }
# NOCOMB-NEXT:     Relocation {
# NOCOMB-NEXT:       Offset: 0x1008
# NOCOMB-NEXT:       Type: R_X86_64_64
# NOCOMB-NEXT:       Symbol: ccc (3)
# NOCOMB-NEXT:       Addend: 0x0
# NOCOMB-NEXT:     }
# NOCOMB-NEXT:     Relocation {
# NOCOMB-NEXT:       Offset: 0x1010
# NOCOMB-NEXT:       Type: R_X86_64_64
# NOCOMB-NEXT:       Symbol: bbb (2)
# NOCOMB-NEXT:       Addend: 0x0
# NOCOMB-NEXT:     }
# NOCOMB-NEXT:     Relocation {
# NOCOMB-NEXT:       Offset: 0x1018
# NOCOMB-NEXT:       Type: R_X86_64_64
# NOCOMB-NEXT:       Symbol: aaa (1)
# NOCOMB-NEXT:       Addend: 0x0
# NOCOMB-NEXT:     }
# NOCOMB-NEXT:     Relocation {
# NOCOMB-NEXT:       Offset: 0x1020
# NOCOMB-NEXT:       Type: R_X86_64_64
# NOCOMB-NEXT:       Symbol: ddd (4)
# NOCOMB-NEXT:       Addend: 0x0
# NOCOMB-NEXT:     }
# NOCOMB-NEXT:   }
# NOCOMB-NEXT:  ]
# NOCOMB:      DynamicSection [
# NOCOMB-NEXT:   Tag
# NOCOMB-NOT:    RELACOUNT

.data
 .quad aaa
 .quad ccc
 .quad bbb
 .quad aaa
 .quad ddd
