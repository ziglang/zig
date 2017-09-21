# Check R_MIPS_GOT16 relocation against weak symbols.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t1.so
# RUN: llvm-readobj -r -dt -dynamic-table -mips-plt-got %t1.so \
# RUN:   | FileCheck -check-prefix=NOSYM %s
# RUN: ld.lld %t.o -shared -Bsymbolic -o %t2.so
# RUN: llvm-readobj -r -dt -dynamic-table -mips-plt-got %t2.so \
# RUN:   | FileCheck -check-prefix=SYM %s

# REQUIRES: mips

# NOSYM:      Relocations [
# NOSYM-NEXT: ]

# NOSYM:        Symbol {
# NOSYM:          Name: foo
# NOSYM-NEXT:     Value: 0x20000
# NOSYM-NEXT:     Size: 0
# NOSYM-NEXT:     Binding: Weak
# NOSYM-NEXT:     Type: None
# NOSYM-NEXT:     Other: 0
# NOSYM-NEXT:     Section: .data
# NOSYM-NEXT:   }
# NOSYM-NEXT:   Symbol {
# NOSYM-NEXT:     Name: bar
# NOSYM-NEXT:     Value: 0x0
# NOSYM-NEXT:     Size: 0
# NOSYM-NEXT:     Binding: Weak
# NOSYM-NEXT:     Type: None
# NOSYM-NEXT:     Other: 0
# NOSYM-NEXT:     Section: Undefined
# NOSYM-NEXT:   }
# NOSYM-NEXT:   Symbol {
# NOSYM-NEXT:     Name: sym
# NOSYM-NEXT:     Value: 0x20004
# NOSYM-NEXT:     Size: 0
# NOSYM-NEXT:     Binding: Global
# NOSYM-NEXT:     Type: None
# NOSYM-NEXT:     Other: 0
# NOSYM-NEXT:     Section: .data
# NOSYM-NEXT:   }
# NOSYM-NEXT: ]

# NOSYM:      0x70000011 MIPS_SYMTABNO        4
# NOSYM-NEXT: 0x7000000A MIPS_LOCAL_GOTNO     2
# NOSYM-NEXT: 0x70000013 MIPS_GOTSYM          0x1

# NOSYM:      Primary GOT {
# NOSYM-NEXT:   Canonical gp value:
# NOSYM-NEXT:   Reserved entries [
# NOSYM-NEXT:     Entry {
# NOSYM-NEXT:       Address:
# NOSYM-NEXT:       Access: -32752
# NOSYM-NEXT:       Initial: 0x0
# NOSYM-NEXT:       Purpose: Lazy resolver
# NOSYM-NEXT:     }
# NOSYM-NEXT:     Entry {
# NOSYM-NEXT:       Address:
# NOSYM-NEXT:       Access: -32748
# NOSYM-NEXT:       Initial: 0x80000000
# NOSYM-NEXT:       Purpose: Module pointer (GNU extension)
# NOSYM-NEXT:     }
# NOSYM-NEXT:   ]
# NOSYM-NEXT:   Local entries [
# NOSYM-NEXT:   ]
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
# NOSYM-NEXT:   Number of TLS and multi-GOT entries: 0
# NOSYM-NEXT: }

# SYM:      Relocations [
# SYM-NEXT: ]

# SYM:        Symbol {
# SYM:          Name: bar
# SYM-NEXT:     Value: 0x0
# SYM-NEXT:     Size: 0
# SYM-NEXT:     Binding: Weak
# SYM-NEXT:     Type: None
# SYM-NEXT:     Other: 0
# SYM-NEXT:     Section: Undefined
# SYM-NEXT:   }
# SYM-NEXT: ]

# SYM:      0x70000011 MIPS_SYMTABNO        4
# SYM-NEXT: 0x7000000A MIPS_LOCAL_GOTNO     4
# SYM-NEXT: 0x70000013 MIPS_GOTSYM          0x3

# SYM:      Primary GOT {
# SYM-NEXT:   Canonical gp value:
# SYM-NEXT:   Reserved entries [
# SYM-NEXT:     Entry {
# SYM-NEXT:       Address:
# SYM-NEXT:       Access: -32752
# SYM-NEXT:       Initial: 0x0
# SYM-NEXT:       Purpose: Lazy resolver
# SYM-NEXT:     }
# SYM-NEXT:     Entry {
# SYM-NEXT:       Address:
# SYM-NEXT:       Access: -32748
# SYM-NEXT:       Initial: 0x80000000
# SYM-NEXT:       Purpose: Module pointer (GNU extension)
# SYM-NEXT:     }
# SYM-NEXT:   ]
# SYM-NEXT:   Local entries [
# SYM-NEXT:     Entry {
# SYM-NEXT:       Address:
# SYM-NEXT:       Access: -32744
# SYM-NEXT:       Initial: 0x20000
# SYM-NEXT:     }
# SYM-NEXT:     Entry {
# SYM-NEXT:       Address:
# SYM-NEXT:       Access: -32740
# SYM-NEXT:       Initial: 0x20004
# SYM-NEXT:     }
# SYM-NEXT:   ]
# SYM-NEXT:   Global entries [
# SYM-NEXT:     Entry {
# SYM-NEXT:       Address:
# SYM-NEXT:       Access: -32736
# SYM-NEXT:       Initial: 0x0
# SYM-NEXT:       Value: 0x0
# SYM-NEXT:       Type: None
# SYM-NEXT:       Section: Undefined
# SYM-NEXT:       Name: bar
# SYM-NEXT:     }
# SYM-NEXT:   ]
# SYM-NEXT:   Number of TLS and multi-GOT entries: 0
# SYM-NEXT: }

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
