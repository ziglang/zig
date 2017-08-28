// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %ta.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %tb.o
// RUN: ld.lld -shared %tb.o -o %ti686.so
// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-linux %s -o %tc.o

// RUN: not ld.lld %ta.o %tb.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=A-AND-B %s
// A-AND-B: b.o is incompatible with {{.*}}a.o

// RUN: not ld.lld %tb.o %tc.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=B-AND-C %s
// B-AND-C: c.o is incompatible with {{.*}}b.o

// RUN: not ld.lld %ta.o %ti686.so -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=A-AND-SO %s
// A-AND-SO: i686.so is incompatible with {{.*}}a.o

// RUN: not ld.lld %tc.o %ti686.so -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=C-AND-SO %s
// C-AND-SO: i686.so is incompatible with {{.*}}c.o

// RUN: not ld.lld %ti686.so %tc.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=SO-AND-C %s
// SO-AND-C: c.o is incompatible with {{.*}}i686.so

// RUN: not ld.lld -m elf64ppc %ta.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=A-ONLY %s
// A-ONLY: a.o is incompatible with elf64ppc

// RUN: not ld.lld -m elf64ppc %tb.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=B-ONLY %s
// B-ONLY: b.o is incompatible with elf64ppc

// RUN: not ld.lld -m elf64ppc %tc.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=C-ONLY %s
// C-ONLY: c.o is incompatible with elf64ppc

// RUN: not ld.lld -m elf_i386 %tc.o %ti686.so -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=C-AND-SO-I386 %s
// C-AND-SO-I386: c.o is incompatible with elf_i386

// RUN: not ld.lld -m elf_i386 %ti686.so %tc.o -o %t 2>&1 | \
// RUN:   FileCheck --check-prefix=SO-AND-C-I386 %s
// SO-AND-C-I386: c.o is incompatible with elf_i386


// We used to fail to identify this incompatibility and crash trying to
// read a 64 bit file as a 32 bit one.
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/archive2.s -o %ta.o
// RUN: llvm-ar rc %t.a %ta.o
// RUN: llvm-mc -filetype=obj -triple=i686-linux %s -o %tb.o
// RUN: not ld.lld %t.a %tb.o 2>&1 | FileCheck --check-prefix=ARCHIVE %s
// ARCHIVE: .a({{.*}}a.o) is incompatible with {{.*}}b.o
.global _start
_start:
.data
        .long foo

// REQUIRES: x86,aarch64
