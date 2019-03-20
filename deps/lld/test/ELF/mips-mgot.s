# REQUIRES: mips
# Check MIPS multi-GOT layout.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t0.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %p/Inputs/mips-mgot-1.s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %p/Inputs/mips-mgot-2.s -o %t2.o
# RUN: ld.lld -shared -mips-got-size 52 %t0.o %t1.o %t2.o -o %t.so
# RUN: llvm-objdump -s -section=.got -t %t.so | FileCheck %s
# RUN: llvm-readobj -r -dt -mips-plt-got %t.so | FileCheck -check-prefix=GOT %s

# CHECK:      Contents of section .got:
# CHECK-NEXT:  60000 00000000 80000000 00010000 00010030
# CHECK-NEXT:  60010 00000000 00000004 00020000 00030000
# CHECK-NEXT:  60020 00040000 00050000 00060000 00070000
# CHECK-NEXT:  60030 00000000 00000000 00000000 00000000
# CHECK-NEXT:  60040 00000000 00000000 00000000

# CHECK: SYMBOL TABLE:
# CHECK: 00000000 l    O .tdata          00000000 loc0
# CHECK: 00010000        .text           00000000 foo0
# CHECK: 00000000 g    O .tdata          00000000 tls0
# CHECK: 00010020        .text           00000000 foo1
# CHECK: 00000004 g    O .tdata          00000000 tls1
# CHECK: 00010030        .text           00000000 foo2
# CHECK: 00000008 g    O .tdata          00000000 tls2

# GOT:      Relocations [
# GOT-NEXT:   Section (7) .rel.dyn {
# GOT-NEXT:     0x60018 R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x6001C R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x60020 R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x60024 R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x60028 R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x6002C R_MIPS_REL32 - 0x0
# GOT-NEXT:     0x60030 R_MIPS_REL32 foo0 0x0
# GOT-NEXT:     0x60034 R_MIPS_REL32 foo2 0x0
# GOT-NEXT:     0x60044 R_MIPS_TLS_DTPMOD32 - 0x0
# GOT-NEXT:     0x60010 R_MIPS_TLS_TPREL32 tls0 0x0
# GOT-NEXT:     0x60038 R_MIPS_TLS_TPREL32 tls0 0x0
# GOT-NEXT:     0x6003C R_MIPS_TLS_DTPMOD32 tls0 0x0
# GOT-NEXT:     0x60040 R_MIPS_TLS_DTPREL32 tls0 0x0
# GOT-NEXT:     0x60014 R_MIPS_TLS_TPREL32 tls1 0x0
# GOT-NEXT:   }
# GOT-NEXT: ]

# GOT:      DynamicSymbols [
# GOT:        Symbol {
# GOT:          Name: foo0
# GOT-NEXT:     Value: 0x10000
# GOT:        }
# GOT-NEXT:   Symbol {
# GOT-NEXT:     Name: foo2
# GOT-NEXT:     Value: 0x10030
# GOT:        }
# GOT-NEXT: ]

# GOT:      Primary GOT {
# GOT-NEXT:   Canonical gp value: 0x67FF0
# GOT-NEXT:   Reserved entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32752
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Purpose: Lazy resolver
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32748
# GOT-NEXT:       Initial: 0x80000000
# GOT-NEXT:       Purpose: Module pointer (GNU extension)
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Local entries [
# GOT-NEXT:   ]
# GOT-NEXT:   Global entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32744
# GOT-NEXT:       Initial: 0x10000
# GOT-NEXT:       Value: 0x10000
# GOT-NEXT:       Type: None
# GOT-NEXT:       Section: .text
# GOT-NEXT:       Name: foo0
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32740
# GOT-NEXT:       Initial: 0x10030
# GOT-NEXT:       Value: 0x10030
# GOT-NEXT:       Type: None
# GOT-NEXT:       Section: .text
# GOT-NEXT:       Name: foo2
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Number of TLS and multi-GOT entries: 15
# GOT-NEXT: }

  .text
  .global foo0
foo0:
  lw     $2, %got(.data)($gp)     # page entry
  addi   $2, $2, %lo(.data)
  lw     $2, %call16(foo0)($gp)   # global entry
  addiu  $2, $2, %tlsgd(tls0)     # tls gd entry
  addiu  $2, $2, %gottprel(tls0)  # tls got entry
  addiu  $2, $2, %tlsldm(loc0)    # tls ld entry

  .data
  .space 0x20000

  .section .tdata,"awT",%progbits
  .global tls0
tls0:
loc0:
  .word 0
