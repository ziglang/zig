// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %tout
// RUN: llvm-readobj --symbols --sections -l %tout | FileCheck %s
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DIS

.global _start
_start:
  movl %fs:a@tpoff, %eax
  movl %fs:b@tpoff, %eax
  movl %fs:c@tpoff, %eax
  movl %fs:d@tpoff, %eax

  .global a
	.section	.tbss,"awT",@nobits
a:
	.long	0

  .global b
	.section	.tdata,"awT",@progbits
b:
	.long	1

  .global c
	.section	.thread_bss,"awT",@nobits
c:
	.long	0

  .global d
	.section	.thread_data,"awT",@progbits
d:
	.long	2

// CHECK:          Name: .tdata
// CHECK-NEXT:     Type: SHT_PROGBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_TLS
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: [[TDATA_ADDR:0x.*]]
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment:
// CHECK-NEXT:     EntrySize:
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index:
// CHECK-NEXT:     Name: .thread_data
// CHECK-NEXT:     Type: SHT_PROGBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_TLS
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address:
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment:
// CHECK-NEXT:     EntrySize:
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index:
// CHECK-NEXT:     Name: .tbss
// CHECK-NEXT:     Type: SHT_NOBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_TLS
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: [[TBSS_ADDR:0x.*]]
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment:
// CHECK-NEXT:     EntrySize:
// CHECK-NEXT:   }
// CHECK-NEXT:   Section {
// CHECK-NEXT:     Index:
// CHECK-NEXT:     Name: .thread_bss
// CHECK-NEXT:     Type: SHT_NOBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_TLS
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]

// 0x20200C = TBSS_ADDR + 4

// CHECK-NEXT:     Address: 0x20200C
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment:
// CHECK-NEXT:     EntrySize:
// CHECK-NEXT:   }

// CHECK:      Symbols [
// CHECK:          Name: a
// CHECK-NEXT:     Value: 0x8
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: TLS
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .tbss
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: b
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: TLS
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .tdata
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: c
// CHECK-NEXT:     Value: 0xC
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: TLS
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .thread_bss
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: d
// CHECK-NEXT:     Value: 0x4
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: TLS
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .thread_data
// CHECK-NEXT:   }

// Check that the TLS NOBITS sections weren't added to the R/W PT_LOAD's size.

// CHECK:      ProgramHeaders [
// CHECK:          Type: PT_LOAD
// CHECK:          Type: PT_LOAD
// CHECK:          Type: PT_LOAD
// CHECK:          FileSize: 8
// CHECK-NEXT:     MemSize: 8
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       PF_R
// CHECK-NEXT:       PF_W
// CHECK-NEXT:     ]
// CHECK:          Type: PT_TLS
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     VirtualAddress: [[TDATA_ADDR]]
// CHECK-NEXT:     PhysicalAddress: [[TDATA_ADDR]]
// CHECK-NEXT:     FileSize: 8
// CHECK-NEXT:     MemSize: 16
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       PF_R
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment:
// CHECK-NEXT:   }

// DIS:      Disassembly of section .text:
// DIS-EMPTY:
// DIS-NEXT: _start:
// DIS-NEXT:    201000: {{.+}} movl    %fs:-8, %eax
// DIS-NEXT:    201008: {{.+}} movl    %fs:-16, %eax
// DIS-NEXT:    201010: {{.+}} movl    %fs:-4, %eax
// DIS-NEXT:    201018: {{.+}} movl    %fs:-12, %eax
