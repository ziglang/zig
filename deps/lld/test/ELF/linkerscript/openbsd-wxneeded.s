# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { text PT_LOAD FILEHDR PHDRS; wxneeded PT_OPENBSD_WXNEEDED; }" > %t.script
# RUN: ld.lld -z wxneeded --script %t.script %t.o -o %t
# RUN: llvm-readobj --program-headers %t | FileCheck %s

# CHECK:      ProgramHeader {
# CHECK:        Type: PT_OPENBSD_WXNEEDED (0x65A3DBE7)
# CHECK-NEXT:   Offset: 0x0
# CHECK-NEXT:   VirtualAddress: 0x0
# CHECK-NEXT:   PhysicalAddress: 0x0
# CHECK-NEXT:   FileSize: 0
# CHECK-NEXT:   MemSize: 0
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     PF_R
# CHECK-NEXT:   ]
# CHECK-NEXT:   Alignment: 0
# CHECK-NEXT: }
