# REQUIRES: mips
# Check R_MIPS_GOT16 relocation against weak symbols.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t1.so
# RUN: llvm-readobj -r -dt -dynamic-table -mips-plt-got %t1.so \
# RUN:   | FileCheck -check-prefixes=CHECK,NOSYM %s
# RUN: ld.lld %t.o -shared -Bsymbolic -o %t2.so
# RUN: llvm-readobj -r -dt -dynamic-table -mips-plt-got %t2.so \
# RUN:   | FileCheck -check-prefixes=CHECK,SYM %s

# CHECK:      Relocations [
# CHECK-NEXT: ]

# NOSYM:        Symbol {
# NOSYM:          Name: foo
# NOSYM-NEXT:     Value: 0x20000
# NOSYM-NEXT:     Size: 0
# NOSYM-NEXT:     Binding: Weak
# NOSYM-NEXT:     Type: None
# NOSYM-NEXT:     Other: 0
# NOSYM-NEXT:     Section: .data
# NOSYM-NEXT:   }

# CHECK:        Symbol {
# CHECK:          Name: bar
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Weak
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }

# NOSYM:        Symbol {
# NOSYM:          Name: sym
# NOSYM-NEXT:     Value: 0x20004
# NOSYM-NEXT:     Size: 0
# NOSYM-NEXT:     Binding: Global
# NOSYM-NEXT:     Type: None
# NOSYM-NEXT:     Other: 0
# NOSYM-NEXT:     Section: .data
# NOSYM-NEXT:   }

# CHECK:      0x70000011 MIPS_SYMTABNO        4

# SYM:        0x7000000A MIPS_LOCAL_GOTNO     4
# SYM:        0x70000013 MIPS_GOTSYM          0x3

# NOSYM:      0x7000000A MIPS_LOCAL_GOTNO     2
# NOSYM:      0x70000013 MIPS_GOTSYM          0x1

# CHECK:      Primary GOT {
# CHECK-NEXT:   Canonical gp value:
# CHECK-NEXT:   Reserved entries [
# CHECK:        ]

# SYM:         Local entries [
# SYM-NEXT:       Entry {
# SYM-NEXT:         Address:
# SYM-NEXT:         Access: -32744
# SYM-NEXT:         Initial: 0x20000
# SYM-NEXT:       }
# SYM-NEXT:       Entry {
# SYM-NEXT:         Address:
# SYM-NEXT:         Access: -32740
# SYM-NEXT:         Initial: 0x20004
# SYM-NEXT:       }
# SYM-NEXT:     ]

# NOSYM:        Local entries [
# NOSYM-NEXT:   ]

# SYM-NEXT:     Global entries [
# SYM-NEXT:       Entry {
# SYM-NEXT:         Address:
# SYM-NEXT:         Access: -32736
# SYM-NEXT:         Initial: 0x0
# SYM-NEXT:         Value: 0x0
# SYM-NEXT:         Type: None
# SYM-NEXT:         Section: Undefined
# SYM-NEXT:         Name: bar
# SYM-NEXT:       }
# SYM-NEXT:     ]

# NOSYM-NEXT:   Global entries [
# NOSYM-NEXT:     Entry {
# NOSYM-NEXT:       Address:
# NOSYM-NEXT:       Access: -32744
# NOSYM-NEXT:       Initial: 0x20000
# NOSYM-NEXT:       Value: 0x20000
# NOSYM-NEXT:       Type: None
# NOSYM-NEXT:       Section: .data
# NOSYM-NEXT:       Name: foo
# NOSYM-NEXT:     }
# NOSYM-NEXT:     Entry {
# NOSYM-NEXT:       Address:
# NOSYM-NEXT:       Access: -32740
# NOSYM-NEXT:       Initial: 0x0
# NOSYM-NEXT:       Value: 0x0
# NOSYM-NEXT:       Type: None
# NOSYM-NEXT:       Section: Undefined
# NOSYM-NEXT:       Name: bar
# NOSYM-NEXT:     }
# NOSYM-NEXT:     Entry {
# NOSYM-NEXT:       Address:
# NOSYM-NEXT:       Access: -32736
# NOSYM-NEXT:       Initial: 0x20004
# NOSYM-NEXT:       Value: 0x20004
# NOSYM-NEXT:       Type: None
# NOSYM-NEXT:       Section: .data
# NOSYM-NEXT:       Name: sym
# NOSYM-NEXT:     }
# NOSYM-NEXT:   ]

# CHECK:        Number of TLS and multi-GOT entries: 0
# CHECK-NEXT: }

  .text
  .global  sym
  .weak    foo,bar
func:
  lw      $t0,%got(foo)($gp)
  lw      $t0,%got(bar)($gp)
  lw      $t0,%got(sym)($gp)

  .data
  .weak foo
foo:
  .word 0
sym:
  .word 0
