# REQUIRES: x86,ppc

# RUN: echo ".globl foo; .data; .dc.a foo" > %te.s
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux      %te.s -o %te-i386.o
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux      %s    -o %t-i386.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux    %s    -o %t-x86_64.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s    -o %t-ppc64le.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s    -o %t-ppc64.o

# RUN: echo ".global zed; zed:" > %t2.s
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux      %t2.s -o %t2-i386.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux    %t2.s -o %t2-x86_64.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %t2.s -o %t2-ppc64le.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %t2.s -o %t2-ppc64.o

# RUN: rm -f %t2-i386.a %t2-x86_64.a %t2-ppc64.a %t2-ppc64le.a
# RUN: llvm-ar rc %t2-i386.a %t2-i386.o
# RUN: llvm-ar rc %t2-x86_64.a %t2-x86_64.o
# RUN: llvm-ar rc %t2-ppc64le.a %t2-ppc64le.o
# RUN: llvm-ar rc %t2-ppc64.a %t2-ppc64.o

# RUN: echo ".global xyz; xyz:" > %t3.s
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux      %t3.s -o %t3-i386.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux    %t3.s -o %t3-x86_64.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %t3.s -o %t3-ppc64le.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %t3.s -o %t3-ppc64.o

# RUN: ld.lld -shared %t3-i386.o   -o %t3-i386.so
# RUN: ld.lld -shared %t3-x86_64.o -o %t3-x86_64.so
# RUN: ld.lld -shared %t3-ppc64le.o  -o %t3-ppc64le.so
# RUN: ld.lld -shared %t3-ppc64.o  -o %t3-ppc64.so

# RUN: ld.lld -shared --hash-style=gnu  -o %te-i386.so  %te-i386.o
# RUN: ld.lld -shared  -hash-style=gnu  -o %t-i386.so   %t-i386.o   %t2-i386.a   %t3-i386.so
# RUN: ld.lld -shared  -hash-style=gnu  -o %t-x86_64.so %t-x86_64.o %t2-x86_64.a %t3-x86_64.so
# RUN: ld.lld -shared --hash-style both -o %t-ppc64le.so  %t-ppc64le.o  %t2-ppc64le.a  %t3-ppc64le.so
# RUN: ld.lld -shared --hash-style both -o %t-ppc64.so  %t-ppc64.o  %t2-ppc64.a  %t3-ppc64.so

# RUN: llvm-readobj -dyn-symbols -gnu-hash-table %te-i386.so \
# RUN:   | FileCheck %s -check-prefix=EMPTY
# RUN: llvm-readobj -sections -dyn-symbols -gnu-hash-table %t-i386.so \
# RUN:   | FileCheck %s -check-prefix=I386
# RUN: llvm-readobj -sections -dyn-symbols -gnu-hash-table %t-x86_64.so \
# RUN:   | FileCheck %s -check-prefix=X86_64
# RUN: llvm-readobj -sections -dyn-symbols -gnu-hash-table %t-ppc64le.so \
# RUN:   | FileCheck %s -check-prefix=PPC64
# RUN: llvm-readobj -sections -dyn-symbols -gnu-hash-table %t-ppc64.so \
# RUN:   | FileCheck %s -check-prefix=PPC64

# EMPTY:      DynamicSymbols [
# EMPTY:        Symbol {
# EMPTY:          Name: foo
# EMPTY-NEXT:     Value: 0x0
# EMPTY-NEXT:     Size: 0
# EMPTY-NEXT:     Binding: Global
# EMPTY-NEXT:     Type: None
# EMPTY-NEXT:     Other: 0
# EMPTY-NEXT:     Section: Undefined
# EMPTY-NEXT:   }
# EMPTY-NEXT: ]
# EMPTY:      GnuHashTable {
# EMPTY-NEXT:   Num Buckets: 1
# EMPTY-NEXT:   First Hashed Symbol Index: 2
# EMPTY-NEXT:   Num Mask Words: 1
# EMPTY-NEXT:   Shift Count: 26
# EMPTY-NEXT:   Bloom Filter: [0x0]
# EMPTY-NEXT:   Buckets: [0]
# EMPTY-NEXT:   Values: []
# EMPTY-NEXT: }

# I386:      Format: ELF32-i386
# I386:      Arch: i386
# I386:      AddressSize: 32bit
# I386:      Sections [
# I386:          Name: .gnu.hash
# I386-NEXT:     Type: SHT_GNU_HASH
# I386-NEXT:     Flags [
# I386-NEXT:       SHF_ALLOC
# I386-NEXT:     ]
# I386-NEXT:     Address:
# I386-NEXT:     Offset:
# I386-NEXT:     Size: 32
# I386-NEXT:     Link:
# I386-NEXT:     Info: 0
# I386-NEXT:     AddressAlignment: 4
# I386-NEXT:     EntrySize: 0
# I386:      ]
# I386:      DynamicSymbols [
# I386:        Symbol {
# I386:          Name:
# I386:          Binding: Local
# I386:          Section: Undefined
# I386:        }
# I386:        Symbol {
# I386:          Name: baz
# I386:          Binding: Global
# I386:          Section: Undefined
# I386:        }
# I386:        Symbol {
# I386:          Name: xyz
# I386:          Binding: Global
# I386:          Section: Undefined
# I386:        }
# I386:        Symbol {
# I386:          Name: zed
# I386:          Binding: Weak
# I386:          Section: Undefined
# I386:        }
# I386:        Symbol {
# I386:          Name: bar
# I386:          Binding: Global
# I386:          Section: .text
# I386:        }
# I386:        Symbol {
# I386:          Name: foo
# I386:          Binding: Global
# I386:          Section: .text
# I386:        }
# I386:      ]
# I386:      GnuHashTable {
# I386-NEXT:   Num Buckets: 1
# I386-NEXT:   First Hashed Symbol Index: 4
# I386-NEXT:   Num Mask Words: 1
# I386-NEXT:   Shift Count: 26
# I386-NEXT:   Bloom Filter: [0x4000204]
# I386-NEXT:   Buckets: [4]
# I386-NEXT:   Values: [0xB8860BA, 0xB887389]
# I386-NEXT: }

# X86_64:      Format: ELF64-x86-64
# X86_64:      Arch: x86_64
# X86_64:      AddressSize: 64bit
# X86_64:      Sections [
# X86_64:          Name: .gnu.hash
# X86_64-NEXT:     Type: SHT_GNU_HASH
# X86_64-NEXT:     Flags [
# X86_64-NEXT:       SHF_ALLOC
# X86_64-NEXT:     ]
# X86_64-NEXT:     Address:
# X86_64-NEXT:     Offset:
# X86_64-NEXT:     Size: 36
# X86_64-NEXT:     Link:
# X86_64-NEXT:     Info: 0
# X86_64-NEXT:     AddressAlignment: 8
# X86_64-NEXT:     EntrySize: 0
# X86_64-NEXT:   }
# X86_64:      ]
# X86_64:      DynamicSymbols [
# X86_64:        Symbol {
# X86_64:          Name:
# X86_64:          Binding: Local
# X86_64:          Section: Undefined
# X86_64:        }
# X86_64:        Symbol {
# X86_64:          Name: baz
# X86_64:          Binding: Global
# X86_64:          Section: Undefined
# X86_64:        }
# X86_64:        Symbol {
# X86_64:          Name: xyz
# X86_64:          Binding: Global
# X86_64:          Section: Undefined
# X86_64:        }
# X86_64:        Symbol {
# X86_64:          Name: zed
# X86_64:          Binding: Weak
# X86_64:          Section: Undefined
# X86_64:        }
# X86_64:        Symbol {
# X86_64:          Name: bar
# X86_64:          Binding: Global
# X86_64:          Section: .text
# X86_64:        }
# X86_64:        Symbol {
# X86_64:          Name: foo
# X86_64:          Binding: Global
# X86_64:          Section: .text
# X86_64:        }
# X86_64:      ]
# X86_64:      GnuHashTable {
# X86_64-NEXT:   Num Buckets: 1
# X86_64-NEXT:   First Hashed Symbol Index: 4
# X86_64-NEXT:   Num Mask Words: 1
# X86_64-NEXT:   Shift Count: 26
# X86_64-NEXT:   Bloom Filter: [0x400000000000204]
# X86_64-NEXT:   Buckets: [4]
# X86_64-NEXT:   Values: [0xB8860BA, 0xB887389]
# X86_64-NEXT: }

# PPC64:      Format: ELF64-ppc64
# PPC64:      Arch: powerpc64
# PPC64:      AddressSize: 64bit
# PPC64:      Sections [
# PPC64:          Name: .gnu.hash
# PPC64-NEXT:     Type: SHT_GNU_HASH
# PPC64-NEXT:     Flags [
# PPC64-NEXT:       SHF_ALLOC
# PPC64-NEXT:     ]
# PPC64-NEXT:     Address:
# PPC64-NEXT:     Offset:
# PPC64-NEXT:     Size: 36
# PPC64-NEXT:     Link:
# PPC64-NEXT:     Info: 0
# PPC64-NEXT:     AddressAlignment: 8
# PPC64-NEXT:     EntrySize: 0
# PPC64-NEXT:   }
# PPC64:      ]
# PPC64:      DynamicSymbols [
# PPC64:        Symbol {
# PPC64:          Name:
# PPC64:          Binding: Local
# PPC64:          Section: Undefined
# PPC64:        }
# PPC64:        Symbol {
# PPC64:          Name: baz
# PPC64:          Binding: Global
# PPC64:          Section: Undefined
# PPC64:        }
# PPC64:        Symbol {
# PPC64:          Name: xyz
# PPC64:          Binding: Global
# PPC64:          Section: Undefined
# PPC64:        }
# PPC64:        Symbol {
# PPC64:          Name: zed
# PPC64:          Binding: Weak
# PPC64:          Section: Undefined
# PPC64:        }
# PPC64:        Symbol {
# PPC64:          Name: bar
# PPC64:          Binding: Global
# PPC64:          Section: .text
# PPC64:        }
# PPC64:        Symbol {
# PPC64:          Name: foo
# PPC64:          Binding: Global
# PPC64:          Section: .text
# PPC64:        }
# PPC64:      ]
# PPC64:      GnuHashTable {
# PPC64-NEXT:   Num Buckets: 1
# PPC64-NEXT:   First Hashed Symbol Index: 4
# PPC64-NEXT:   Num Mask Words: 1
# PPC64-NEXT:   Shift Count: 26
# PPC64-NEXT:   Bloom Filter: [0x400000000000204]
# PPC64-NEXT:   Buckets: [4]
# PPC64-NEXT:   Values: [0xB8860BA, 0xB887389]
# PPC64-NEXT: }

.globl foo,bar,baz
foo:
bar:
.weak zed
.global xyz
.data
  .dc.a baz
