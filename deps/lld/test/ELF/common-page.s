# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# exits with return code 42 on linux
.globl _start
_start:
  nop

# Increase max-page-size to 64k while using the default x86_64 common page size
# of 4k. If the last loadable segment is executable then lld aligns the next
# section using the common page size.

# RUN: ld.lld -z max-page-size=0x10000 -z common-page-size=0x1000 %t -o %t2
# RUN: llvm-readobj --sections -l %t2 | FileCheck --check-prefix=CHECK-MAX %s

# CHECK-MAX:      Sections [
# CHECK-MAX-NEXT:   Section {
# CHECK-MAX-NEXT:     Index: 0
# CHECK-MAX-NEXT:     Name:  (0)
# CHECK-MAX-NEXT:     Type: SHT_NULL (0x0)
# CHECK-MAX-NEXT:     Flags [ (0x0)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Address: 0x0
# CHECK-MAX-NEXT:     Offset: 0x0
# CHECK-MAX-NEXT:     Size: 0
# CHECK-MAX-NEXT:     Link: 0
# CHECK-MAX-NEXT:     Info: 0
# CHECK-MAX-NEXT:     AddressAlignment: 0
# CHECK-MAX-NEXT:     EntrySize: 0
# CHECK-MAX-NEXT:   }
# CHECK-MAX-NEXT:   Section {
# CHECK-MAX-NEXT:     Index: 1
# CHECK-MAX-NEXT:     Name: .text (1)
# CHECK-MAX-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-MAX-NEXT:     Flags [ (0x6)
# CHECK-MAX-NEXT:       SHF_ALLOC (0x2)
# CHECK-MAX-NEXT:       SHF_EXECINSTR (0x4)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Address: 0x210000
# CHECK-MAX-NEXT:     Offset: 0x10000
# CHECK-MAX-NEXT:     Size: 1
# CHECK-MAX-NEXT:     Link: 0
# CHECK-MAX-NEXT:     Info: 0
# CHECK-MAX-NEXT:     AddressAlignment: 4
# CHECK-MAX-NEXT:     EntrySize: 0
# CHECK-MAX-NEXT:   }
# CHECK-MAX-NEXT:   Section {
# CHECK-MAX-NEXT:     Index: 2
# CHECK-MAX-NEXT:     Name: .comment (7)
# CHECK-MAX-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-MAX-NEXT:     Flags [ (0x30)
# CHECK-MAX-NEXT:       SHF_MERGE (0x10)
# CHECK-MAX-NEXT:       SHF_STRINGS (0x20)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Address: 0x0
# CHECK-MAX-NEXT:     Offset: 0x11000
# CHECK-MAX-NEXT:     Size: 8
# CHECK-MAX-NEXT:     Link: 0
# CHECK-MAX-NEXT:     Info: 0
# CHECK-MAX-NEXT:     AddressAlignment: 1
# CHECK-MAX-NEXT:     EntrySize: 1

# CHECK-MAX: ProgramHeaders [
# CHECK-MAX-NEXT:   ProgramHeader {
# CHECK-MAX-NEXT:     Type: PT_PHDR (0x6)
# CHECK-MAX-NEXT:     Offset: 0x40
# CHECK-MAX-NEXT:     VirtualAddress: 0x200040
# CHECK-MAX-NEXT:     PhysicalAddress: 0x200040
# CHECK-MAX-NEXT:     FileSize: 224
# CHECK-MAX-NEXT:     MemSize: 224
# CHECK-MAX-NEXT:     Flags [ (0x4)
# CHECK-MAX-NEXT:       PF_R (0x4)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Alignment: 8
# CHECK-MAX-NEXT:   }
# CHECK-MAX-NEXT:   ProgramHeader {
# CHECK-MAX-NEXT:     Type: PT_LOAD (0x1)
# CHECK-MAX-NEXT:     Offset: 0x0
# CHECK-MAX-NEXT:     VirtualAddress: 0x200000
# CHECK-MAX-NEXT:     PhysicalAddress: 0x200000
# CHECK-MAX-NEXT:     FileSize: 288
# CHECK-MAX-NEXT:     MemSize: 288
# CHECK-MAX-NEXT:     Flags [ (0x4)
# CHECK-MAX-NEXT:       PF_R (0x4)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Alignment: 65536
# CHECK-MAX-NEXT:   }
# CHECK-MAX-NEXT:   ProgramHeader {
# CHECK-MAX-NEXT:     Type: PT_LOAD (0x1)
# CHECK-MAX-NEXT:     Offset: 0x10000
# CHECK-MAX-NEXT:     VirtualAddress: 0x210000
# CHECK-MAX-NEXT:     PhysicalAddress: 0x210000
# CHECK-MAX-NEXT:     FileSize: 4096
# CHECK-MAX-NEXT:     MemSize: 4096
# CHECK-MAX-NEXT:     Flags [ (0x5)
# CHECK-MAX-NEXT:       PF_R (0x4)
# CHECK-MAX-NEXT:       PF_X (0x1)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Alignment: 65536
# CHECK-MAX-NEXT:   }
# CHECK-MAX-NEXT:   ProgramHeader {
# CHECK-MAX-NEXT:     Type: PT_GNU_STACK (0x6474E551)
# CHECK-MAX-NEXT:     Offset: 0x0
# CHECK-MAX-NEXT:     VirtualAddress: 0x0
# CHECK-MAX-NEXT:     PhysicalAddress: 0x0
# CHECK-MAX-NEXT:     FileSize: 0
# CHECK-MAX-NEXT:     MemSize: 0
# CHECK-MAX-NEXT:     Flags [ (0x6)
# CHECK-MAX-NEXT:       PF_R (0x4)
# CHECK-MAX-NEXT:       PF_W (0x2)
# CHECK-MAX-NEXT:     ]
# CHECK-MAX-NEXT:     Alignment: 0

# Increase common-page-size to max-page-size. Expect to see a larger offset
# of the first Section after the executable loadable segment due to the higher
# alignment requirement.

# RUN: ld.lld -z max-page-size=0x10000 -z common-page-size=0x10000 %t -o %t3
# RUN: llvm-readobj --sections -l %t3 | FileCheck --check-prefix=CHECK-COMMON %s

# Check that we truncate common-page-size to max-page-size

# RUN: ld.lld -z max-page-size=0x10000 -z common-page-size=0x100000 %t -o %t4
# RUN: llvm-readobj --sections -l %t4 | FileCheck --check-prefix=CHECK-COMMON %s

# CHECK-COMMON: Sections [
# CHECK-COMMON-NEXT:   Section {
# CHECK-COMMON-NEXT:     Index: 0
# CHECK-COMMON-NEXT:     Name:  (0)
# CHECK-COMMON-NEXT:     Type: SHT_NULL (0x0)
# CHECK-COMMON-NEXT:     Flags [ (0x0)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Address: 0x0
# CHECK-COMMON-NEXT:     Offset: 0x0
# CHECK-COMMON-NEXT:     Size: 0
# CHECK-COMMON-NEXT:     Link: 0
# CHECK-COMMON-NEXT:     Info: 0
# CHECK-COMMON-NEXT:     AddressAlignment: 0
# CHECK-COMMON-NEXT:     EntrySize: 0
# CHECK-COMMON-NEXT:   }
# CHECK-COMMON-NEXT:   Section {
# CHECK-COMMON-NEXT:     Index: 1
# CHECK-COMMON-NEXT:     Name: .text (1)
# CHECK-COMMON-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-COMMON-NEXT:     Flags [ (0x6)
# CHECK-COMMON-NEXT:       SHF_ALLOC (0x2)
# CHECK-COMMON-NEXT:       SHF_EXECINSTR (0x4)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Address: 0x210000
# CHECK-COMMON-NEXT:     Offset: 0x10000
# CHECK-COMMON-NEXT:     Size: 1
# CHECK-COMMON-NEXT:     Link: 0
# CHECK-COMMON-NEXT:     Info: 0
# CHECK-COMMON-NEXT:     AddressAlignment: 4
# CHECK-COMMON-NEXT:     EntrySize: 0
# CHECK-COMMON-NEXT:   }
# CHECK-COMMON-NEXT:   Section {
# CHECK-COMMON-NEXT:     Index: 2
# CHECK-COMMON-NEXT:     Name: .comment (7)
# CHECK-COMMON-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-COMMON-NEXT:     Flags [ (0x30)
# CHECK-COMMON-NEXT:       SHF_MERGE (0x10)
# CHECK-COMMON-NEXT:       SHF_STRINGS (0x20)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Address: 0x0
# CHECK-COMMON-NEXT:     Offset: 0x20000
# CHECK-COMMON-NEXT:     Size: 8
# CHECK-COMMON-NEXT:     Link: 0
# CHECK-COMMON-NEXT:     Info: 0
# CHECK-COMMON-NEXT:     AddressAlignment: 1
# CHECK-COMMON-NEXT:     EntrySize: 1

# CHECK-COMMON: ProgramHeaders [
# CHECK-COMMON-NEXT:   ProgramHeader {
# CHECK-COMMON-NEXT:     Type: PT_PHDR (0x6)
# CHECK-COMMON-NEXT:     Offset: 0x40
# CHECK-COMMON-NEXT:     VirtualAddress: 0x200040
# CHECK-COMMON-NEXT:     PhysicalAddress: 0x200040
# CHECK-COMMON-NEXT:     FileSize: 224
# CHECK-COMMON-NEXT:     MemSize: 224
# CHECK-COMMON-NEXT:     Flags [ (0x4)
# CHECK-COMMON-NEXT:       PF_R (0x4)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Alignment: 8
# CHECK-COMMON-NEXT:   }
# CHECK-COMMON-NEXT:   ProgramHeader {
# CHECK-COMMON-NEXT:     Type: PT_LOAD (0x1)
# CHECK-COMMON-NEXT:     Offset: 0x0
# CHECK-COMMON-NEXT:     VirtualAddress: 0x200000
# CHECK-COMMON-NEXT:     PhysicalAddress: 0x200000
# CHECK-COMMON-NEXT:     FileSize: 288
# CHECK-COMMON-NEXT:     MemSize: 288
# CHECK-COMMON-NEXT:     Flags [ (0x4)
# CHECK-COMMON-NEXT:       PF_R (0x4)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Alignment: 65536
# CHECK-COMMON-NEXT:   }
# CHECK-COMMON-NEXT:   ProgramHeader {
# CHECK-COMMON-NEXT:     Type: PT_LOAD (0x1)
# CHECK-COMMON-NEXT:     Offset: 0x10000
# CHECK-COMMON-NEXT:     VirtualAddress: 0x210000
# CHECK-COMMON-NEXT:     PhysicalAddress: 0x210000
# CHECK-COMMON-NEXT:     FileSize: 65536
# CHECK-COMMON-NEXT:     MemSize: 65536
# CHECK-COMMON-NEXT:     Flags [ (0x5)
# CHECK-COMMON-NEXT:       PF_R (0x4)
# CHECK-COMMON-NEXT:       PF_X (0x1)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Alignment: 65536
# CHECK-COMMON-NEXT:   }
# CHECK-COMMON-NEXT:   ProgramHeader {
# CHECK-COMMON-NEXT:     Type: PT_GNU_STACK (0x6474E551)
# CHECK-COMMON-NEXT:     Offset: 0x0
# CHECK-COMMON-NEXT:     VirtualAddress: 0x0
# CHECK-COMMON-NEXT:     PhysicalAddress: 0x0
# CHECK-COMMON-NEXT:     FileSize: 0
# CHECK-COMMON-NEXT:     MemSize: 0
# CHECK-COMMON-NEXT:     Flags [ (0x6)
# CHECK-COMMON-NEXT:       PF_R (0x4)
# CHECK-COMMON-NEXT:       PF_W (0x2)
# CHECK-COMMON-NEXT:     ]
# CHECK-COMMON-NEXT:     Alignment: 0
