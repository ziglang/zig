# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unkown-linux %p/Inputs/ppc64-toc-relax-shared.s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-toc-relax.s -o %t2.o
# RUN: llvm-readobj -r %t1.o | FileCheck --check-prefix=RELOCS %s
# RUN: ld.lld %t1.o %t2.o %t.so -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SECTIONS %s
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-objdump -D %t | FileCheck %s

# In most cases, .toc contains exclusively addresses relocated by R_PPC64_ADDR16.
# Rarely .toc contain constants or variables.
# Test we can still perform toc-indirect to toc-relative relaxation.

# RELOCS:      .rela.text {
# RELOCS-NEXT:   0x0 R_PPC64_TOC16_HA .toc 0x0
# RELOCS-NEXT:   0x4 R_PPC64_TOC16_LO_DS .toc 0x0
# RELOCS-NEXT:   0x8 R_PPC64_TOC16_HA .toc 0x8
# RELOCS-NEXT:   0xC R_PPC64_TOC16_LO_DS .toc 0x8
# RELOCS-NEXT:   0x10 R_PPC64_TOC16_HA .toc 0x10
# RELOCS-NEXT:   0x14 R_PPC64_TOC16_LO_DS .toc 0x10
# RELOCS-NEXT: }

# SECTIONS: .got              PROGBITS        0000000010020090
# SECTIONS: .toc              PROGBITS        0000000010020090

# NM: 0000000010030000 D default

# .LCONST1 is .toc[0].
# .LCONST1 - (.got+0x8000) = 0x10020090 - (0x10020090+0x8000) = -32768
# CHECK: nop
# CHECK: lwa 3, -32768(2)
  addis 3, 2, .LCONST1@toc@ha
  lwa 3, .LCONST1@toc@l(3)

# .LCONST2 is .toc[1]
# .LCONST2 - (.got+0x8000) = 0x10020098 - (0x10020090+0x8000) = -32760
# CHECK: nop
# CHECK: ld 4, -32760(2)
  addis 4, 2, .LCONST2@toc@ha
  ld 4, .LCONST2@toc@l(4)

# .Ldefault is .toc[2]. `default` is not preemptable when producing an executable.
# After toc-indirection to toc-relative relaxation, it is loaded using an
# offset relative to r2.
# CHECK: nop
# CHECK: addi 5, 2, 32624
# CHECK: lwa 5, 0(5)
  addis 5, 2, .Ldefault@toc@ha
  ld    5, .Ldefault@toc@l(5)
  lwa   5, 0(5)

.section .toc,"aw",@progbits
.LCONST1:
  .quad 11
.LCONST2:
  .quad 22
.Ldefault:
  .tc default[TC],default
