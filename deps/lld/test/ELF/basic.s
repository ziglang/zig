# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-readobj --file-headers --sections -l --symbols %t2 \
# RUN:   | FileCheck %s
# RUN: ld.lld %t -o /dev/null

# exits with return code 42 on linux
.globl _start
_start:
  mov $60, %rax
  mov $42, %rdi
  syscall

# CHECK:      ElfHeader {
# CHECK-NEXT:   Ident {
# CHECK-NEXT:     Magic: (7F 45 4C 46)
# CHECK-NEXT:     Class: 64-bit (0x2)
# CHECK-NEXT:     DataEncoding: LittleEndian (0x1)
# CHECK-NEXT:     FileVersion: 1
# CHECK-NEXT:     OS/ABI: SystemV (0x0)
# CHECK-NEXT:     ABIVersion: 0
# CHECK-NEXT:     Unused: (00 00 00 00 00 00 00)
# CHECK-NEXT:   }
# CHECK-NEXT:   Type: Executable (0x2)
# CHECK-NEXT:   Machine: EM_X86_64 (0x3E)
# CHECK-NEXT:   Version: 1
# CHECK-NEXT:   Entry: [[ENTRY:0x[0-9A-F]+]]
# CHECK-NEXT:   ProgramHeaderOffset: 0x40
# CHECK-NEXT:   SectionHeaderOffset: 0x2070
# CHECK-NEXT:   Flags [ (0x0)
# CHECK-NEXT:   ]
# CHECK-NEXT:   HeaderSize: 64
# CHECK-NEXT:   ProgramHeaderEntrySize: 56
# CHECK-NEXT:   ProgramHeaderCount: 4
# CHECK-NEXT:   SectionHeaderEntrySize: 64
# CHECK-NEXT:   SectionHeaderCount: 6
# CHECK-NEXT:   StringTableSectionIndex: 4
# CHECK-NEXT: }
# CHECK-NEXT: Sections [
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 0
# CHECK-NEXT:     Name:  (0)
# CHECK-NEXT:     Type: SHT_NULL (0x0)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 0
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 1
# CHECK-NEXT:     Name: .text
# CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-NEXT:     Flags [ (0x6)
# CHECK-NEXT:       SHF_ALLOC (0x2)
# CHECK-NEXT:       SHF_EXECINSTR (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x201000
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     Size: 16
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 4
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 2
# CHECK-NEXT:     Name: .comment
# CHECK-NEXT:     Type: SHT_PROGBITS (0x1)
# CHECK-NEXT:     Flags [ (0x30)
# CHECK-NEXT:       SHF_MERGE (0x10)
# CHECK-NEXT:       SHF_STRINGS (0x20)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x2000
# CHECK-NEXT:     Size: 8
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 1
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 3
# CHECK-NEXT:     Name: .symtab
# CHECK-NEXT:     Type: SHT_SYMTAB (0x2)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x2008
# CHECK-NEXT:     Size: 48
# CHECK-NEXT:     Link: 5
# CHECK-NEXT:     Info: 1
# CHECK-NEXT:     AddressAlignment: 8
# CHECK-NEXT:     EntrySize: 24
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 4
# CHECK-NEXT:     Name: .shstrtab
# CHECK-NEXT:     Type: SHT_STRTAB (0x3)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x2038
# CHECK-NEXT:     Size: 42
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section {
# CHECK-NEXT:     Index: 5
# CHECK-NEXT:     Name: .strtab
# CHECK-NEXT:     Type: SHT_STRTAB (0x3)
# CHECK-NEXT:     Flags [ (0x0)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Address: 0x0
# CHECK-NEXT:     Offset: 0x2062
# CHECK-NEXT:     Size: 8
# CHECK-NEXT:     Link: 0
# CHECK-NEXT:     Info: 0
# CHECK-NEXT:     AddressAlignment: 1
# CHECK-NEXT:     EntrySize: 0
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:  (0)
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local (0x0)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: _start
# CHECK-NEXT:     Value: [[ENTRY]]
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global (0x1)
# CHECK-NEXT:     Type: None (0x0)
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_PHDR (0x6)
# CHECK-NEXT:     Offset: 0x40
# CHECK-NEXT:     VirtualAddress: 0x200040
# CHECK-NEXT:     PhysicalAddress: 0x200040
# CHECK-NEXT:     FileSize: 224
# CHECK-NEXT:     MemSize: 224
# CHECK-NEXT:     Flags [ (0x4)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 8
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x200000
# CHECK-NEXT:     PhysicalAddress: 0x200000
# CHECK-NEXT:     FileSize: 288
# CHECK-NEXT:     MemSize: 288
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x201000
# CHECK-NEXT:     PhysicalAddress: 0x201000
# CHECK-NEXT:     FileSize: 4096
# CHECK-NEXT:     MemSize: 4096
# CHECK-NEXT:     Flags [ (0x5)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:       PF_X (0x1)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_GNU_STACK
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x0
# CHECK-NEXT:     PhysicalAddress: 0x0
# CHECK-NEXT:     FileSize: 0
# CHECK-NEXT:     MemSize: 0
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_W
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# Test for the response file (POSIX quoting style)
# RUN: echo " -o %t2" > %t.responsefile
# RUN: ld.lld %t --rsp-quoting=posix @%t.responsefile
# RUN: llvm-readobj --file-headers --sections -l --symbols %t2 \
# RUN:   | FileCheck %s

# Test for the response file (Windows quoting style)
# RUN: echo " c:\blah\foo" > %t.responsefile
# RUN: not ld.lld --rsp-quoting=windows %t @%t.responsefile 2>&1 | FileCheck \
# RUN:   %s --check-prefix=WINRSP
# WINRSP: cannot open c:\blah\foo

# Test for the response file (invalid quoting style)
# RUN: not ld.lld --rsp-quoting=patatino %t 2>&1 | FileCheck %s \
# RUN:   --check-prefix=INVRSP
# INVRSP: invalid response file quoting: patatino

# RUN: not ld.lld %t.foo -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=MISSING %s
# MISSING: cannot open {{.*}}.foo: {{[Nn]}}o such file or directory

# RUN: not ld.lld -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=NO_INPUT %s
# NO_INPUT: ld.lld{{.*}}: no input files

# RUN: not ld.lld %t.no.such.file -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=CANNOT_OPEN %s
# CANNOT_OPEN: cannot open {{.*}}.no.such.file: {{[Nn]}}o such file or directory

# RUN: not ld.lld %t -o 2>&1 | FileCheck --check-prefix=NO_O_VAL %s
# NO_O_VAL: -o: missing argument

# RUN: not ld.lld --foo 2>&1 | FileCheck --check-prefix=UNKNOWN %s
# UNKNOWN: unknown argument '--foo'

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld %t %t -o %t2 2>&1 | FileCheck --check-prefix=DUP %s
# DUP:      duplicate symbol: _start
# DUP-NEXT: >>> defined at {{.*}}:(.text+0x0)
# DUP-NEXT: >>> defined at {{.*}}:(.text+0x0)

# RUN: not ld.lld %t -o %t -m wrong_emul_fbsd 2>&1 | FileCheck --check-prefix=UNKNOWN_EMUL %s
# UNKNOWN_EMUL: unknown emulation: wrong_emul_fbsd

# RUN: not ld.lld %t --lto-partitions=0 2>&1 | FileCheck --check-prefix=NOTHREADS %s
# RUN: not ld.lld %t --plugin-opt=lto-partitions=0 2>&1 | FileCheck --check-prefix=NOTHREADS %s
# NOTHREADS: --lto-partitions: number of threads must be > 0

# RUN: not ld.lld %t --thinlto-jobs=0 2>&1 | FileCheck --check-prefix=NOTHREADSTHIN %s
# RUN: not ld.lld %t --plugin-opt=jobs=0 2>&1 | FileCheck --check-prefix=NOTHREADSTHIN %s
# NOTHREADSTHIN: --thinlto-jobs: number of threads must be > 0

# RUN: not ld.lld %t -z ifunc-noplt -z text 2>&1 | FileCheck --check-prefix=NOIFUNCPLTNOTEXTREL %s
# NOIFUNCPLTNOTEXTREL: -z text and -z ifunc-noplt may not be used together
