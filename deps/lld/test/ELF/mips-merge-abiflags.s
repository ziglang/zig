# Test that lld handles input files with concatenated .MIPS.abiflags sections
# This happens e.g. with the FreeBSD BFD (BFD 2.17.50 [FreeBSD] 2007-07-03)

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-freebsd %s -o %t.o
# RUN: ld.lld %t.o %p/Inputs/mips-concatenated-abiflags.o -o %t.exe
# RUN: llvm-readobj -sections -mips-abi-flags %t.exe | FileCheck %s
# RUN: llvm-readobj -sections -mips-abi-flags \
# RUN:     %p/Inputs/mips-concatenated-abiflags.o | \
# RUN:   FileCheck --check-prefix=INPUT-OBJECT %s

# REQUIRES: mips
        .globl  __start
__start:
        nop

# CHECK:      Section {
# CHECK:        Index: 1
# CHECK-NEXT:   Name: .MIPS.abiflags
# CHECK-NEXT:   Type: SHT_MIPS_ABIFLAGS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 24
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 8
# CHECK-NEXT:   EntrySize: 24
# CHECK-NEXT: }

# CHECK:      MIPS ABI Flags {
# CHECK-NEXT:   Version: 0
# CHECK-NEXT:   ISA: MIPS64
# CHECK-NEXT:   ISA Extension: None
# CHECK-NEXT:   ASEs [
# CHECK-NEXT:   ]
# CHECK-NEXT:   FP ABI: Hard float (double precision)
# CHECK-NEXT:   GPR size: 64
# CHECK-NEXT:   CPR1 size: 64
# CHECK-NEXT:   CPR2 size: 0
# CHECK-NEXT:   Flags 1 [
# CHECK-NEXT:     ODDSPREG
# CHECK-NEXT:   ]
# CHECK-NEXT:   Flags 2: 0x0
# CHECK-NEXT: }

# INPUT-OBJECT:       Section {
# INPUT-OBJECT:         Index: 3
# INPUT-OBJECT-NEXT:    Name: .MIPS.abiflags
# INPUT-OBJECT-NEXT:    Type: SHT_MIPS_ABIFLAGS
# INPUT-OBJECT-NEXT:    Flags [
# INPUT-OBJECT-NEXT:      SHF_ALLOC
# INPUT-OBJECT-NEXT:    ]
# INPUT-OBJECT-NEXT:    Address:
# INPUT-OBJECT-NEXT:    Offset:
# INPUT-OBJECT-NEXT:    Size: 48
# INPUT-OBJECT-NEXT:    Link: 0
# INPUT-OBJECT-NEXT:    Info: 0
# INPUT-OBJECT-NEXT:    AddressAlignment: 8
# INPUT-OBJECT-NEXT:    EntrySize: 0
# INPUT-OBJECT-NEXT:  }
# INPUT-OBJECT:       The .MIPS.abiflags section has a wrong size.
