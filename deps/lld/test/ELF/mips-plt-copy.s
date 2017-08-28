# Check creating of R_MIPS_COPY and R_MIPS_JUMP_SLOT dynamic relocations
# and corresponding PLT entries.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t.so.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-readobj -r -mips-plt-got %t.exe | FileCheck %s

# REQUIRES: mips

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rel.dyn {
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_MIPS_COPY data0 0x0
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_MIPS_COPY data1 0x0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section ({{.*}}) .rel.plt {
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_MIPS_JUMP_SLOT foo0 0x0
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_MIPS_JUMP_SLOT foo1 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK:      Primary GOT {
# CHECK:        Local entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Global entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Number of TLS and multi-GOT entries: 0
# CHECK-NEXT: }

# CHECK:      PLT GOT {
# CHECK:        Entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Initial: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Value: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Type: Function
# CHECK-NEXT:       Section: Undefined
# CHECK-NEXT:       Name: foo0
# CHECK-NEXT:     }
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Initial: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Value: 0x{{[0-9A-F]+}}
# CHECK-NEXT:       Type: Function
# CHECK-NEXT:       Section: Undefined
# CHECK-NEXT:       Name: foo1
# CHECK-NEXT:     }
# CHECK-NEXT:   ]
# CHECK-NEXT: }

  .text
  .globl __start
__start:
  lui    $t0,%hi(foo0)     # R_MIPS_HI16 requires JUMP_SLOT/PLT entry
                           # for DSO defined func.
  addi   $t0,$t0,%lo(foo0)
  lui    $t0,%hi(bar)      # Does not require PLT for locally defined func.
  addi   $t0,$t0,%lo(bar)
  lui    $t0,%hi(loc)      # Does not require PLT for local func.
  addi   $t0,$t0,%lo(loc)

  lui    $t0,%hi(data0)    # R_MIPS_HI16 requires COPY rel for DSO defined data.
  addi   $t0,$t0,%lo(data0)
  lui    $t0,%hi(gd)       # Does not require COPY rel for locally defined data.
  addi   $t0,$t0,%lo(gd)
  lui    $t0,%hi(ld)       # Does not require COPY rel for local data.
  addi   $t0,$t0,%lo(ld)

  .globl bar
  .type  bar, @function
bar:
  nop
loc:
  nop

  .rodata
  .globl gd
gd:
  .word 0
ld:
  .word data1+8            # R_MIPS_32 requires REL32 dnamic relocation
                           # for DSO defined data. For now we generate COPY one.
  .word foo1+8             # R_MIPS_32 requires PLT entry for DSO defined func.
