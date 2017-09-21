# Check MIPS specific .dynamic section entries.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %p/Inputs/mips-dynamic.s -o %td.o
# RUN: ld.lld -shared %td.o -o %td.so

# RUN: ld.lld %t.o %td.so -o %t.exe
# RUN: llvm-readobj -sections -dynamic-table %t.exe \
# RUN:   | FileCheck -check-prefix=EXE %s

# RUN: ld.lld %t.o --image-base=0x123000 %td.so -o %t.exe
# RUN: llvm-readobj -sections -dynamic-table %t.exe \
# RUN:   | FileCheck -check-prefix=IMAGE_BASE %s

# RUN: ld.lld -shared %t.o %td.so -o %t.so
# RUN: llvm-readobj -sections -dyn-symbols -dynamic-table %t.so \
# RUN:   | FileCheck -check-prefix=DSO %s

# REQUIRES: mips

# EXE:      Sections [
# EXE:          Name: .dynamic
# EXE-NEXT:     Type: SHT_DYNAMIC
# EXE-NEXT:     Flags [
# EXE-NEXT:       SHF_ALLOC
# EXE-NEXT:     ]
# EXE:          Name: .rld_map
# EXE-NEXT:     Type: SHT_PROGBITS
# EXE-NEXT:     Flags [
# EXE-NEXT:       SHF_ALLOC
# EXE-NEXT:       SHF_WRITE
# EXE-NEXT:     ]
# EXE-NEXT:     Address: [[RLDMAPADDR:0x[0-9a-f]+]]
# EXE-NEXT:     Offset:
# EXE-NEXT:     Size: 4
# EXE:          Name: .got
# EXE-NEXT:     Type: SHT_PROGBITS
# EXE-NEXT:     Flags [ (0x10000003)
# EXE-NEXT:       SHF_ALLOC
# EXE-NEXT:       SHF_MIPS_GPREL
# EXE-NEXT:       SHF_WRITE
# EXE-NEXT:     ]
# EXE-NEXT:     Address: [[GOTADDR:0x[0-9a-f]+]]
# EXE-NEXT:     Offset:
# EXE-NEXT:     Size: 8
# EXE:      ]
# EXE:      DynamicSection [
# EXE-NEXT:   Tag        Type                 Name/Value
# EXE-DAG:    0x00000003 PLTGOT               [[GOTADDR]]
# EXE-DAG:    0x70000001 MIPS_RLD_VERSION     1
# EXE-DAG:    0x70000005 MIPS_FLAGS           NOTPOT
# EXE-DAG:    0x70000006 MIPS_BASE_ADDRESS    0x10000
# EXE-DAG:    0x7000000A MIPS_LOCAL_GOTNO     2
# EXE-DAG:    0x70000011 MIPS_SYMTABNO        2
# EXE-DAG:    0x70000013 MIPS_GOTSYM          0x2
# EXE-DAG:    0x70000016 MIPS_RLD_MAP         [[RLDMAPADDR]]
# EXE:      ]

# IMAGE_BASE: 0x70000006 MIPS_BASE_ADDRESS    0x123000

# DSO:      Sections [
# DSO:          Name: .dynamic
# DSO-NEXT:     Type: SHT_DYNAMIC
# DSO-NEXT:     Flags [
# DSO-NEXT:       SHF_ALLOC
# DSO-NEXT:     ]
# DSO:          Name: .got
# DSO-NEXT:     Type: SHT_PROGBITS
# DSO-NEXT:     Flags [ (0x10000003)
# DSO-NEXT:       SHF_ALLOC
# DSO-NEXT:       SHF_MIPS_GPREL
# DSO-NEXT:       SHF_WRITE
# DSO-NEXT:     ]
# DSO-NEXT:     Address: [[GOTADDR:0x[0-9a-f]+]]
# DSO-NEXT:     Offset:
# DSO-NEXT:     Size: 8
# DSO:      ]
# DSO:      DynamicSymbols [
# DSO:          Name: @
# DSO:          Name: __start@
# DSO:          Name: _foo@
# DSO:      ]
# DSO:      DynamicSection [
# DSO-NEXT:   Tag        Type                 Name/Value
# DSO-DAG:    0x00000003 PLTGOT               [[GOTADDR]]
# DSO-DAG:    0x70000001 MIPS_RLD_VERSION     1
# DSO-DAG:    0x70000005 MIPS_FLAGS           NOTPOT
# DSO-DAG:    0x70000006 MIPS_BASE_ADDRESS    0x0
# DSO-DAG:    0x7000000A MIPS_LOCAL_GOTNO     2
# DSO-DAG:    0x70000011 MIPS_SYMTABNO        3
# DSO-DAG:    0x70000013 MIPS_GOTSYM          0x3
# DSO:      ]

  .text
  .globl  __start,_foo
  .type _foo,@function
__start:
  nop
