// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/whole-archive.s -o %t2.o
// RUN: rm -f %t.a
// RUN: llvm-ar rcs %t.a %t2.o

// RUN: ld.lld -o %t.exe -push-state -whole-archive %t.a %t1.o -M | \
// RUN:   FileCheck -check-prefix=WHOLE %s
// WHOLE: _bar

// RUN: ld.lld -o %t.exe -push-state -whole-archive -pop-state %t.a %t1.o -M | \
// RUN:   FileCheck -check-prefix=NO-WHOLE %s
// NO-WHOLE-NOT: _bar


// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t3.o
// RUN: ld.lld -shared %t3.o -soname libfoo -o %t.so

// RUN: ld.lld -o %t.exe -push-state -as-needed %t.so %t1.o
// RUN: llvm-readobj -dynamic-table %t.exe | FileCheck -check-prefix=AS-NEEDED %s
// AS-NEEDED-NOT: NEEDED Shared library: [libfoo]

// RUN: ld.lld -o %t.exe -push-state -as-needed -pop-state %t.so %t1.o
// RUN: llvm-readobj -dynamic-table %t.exe | FileCheck -check-prefix=NO-AS-NEEDED %s
// NO-AS-NEEDED: NEEDED Shared library: [libfoo]


// RUN: mkdir -p %t.dir
// RUN: cp %t.so %t.dir/libfoo.so
// RUN: ld.lld -o %t.exe -L%t.dir -push-state -static -pop-state  %t1.o -lfoo
// RUN: not ld.lld -o %t.exe -L%t.dir -push-state -static %t1.o -lfoo

// RUN: not ld.lld -o %t.exe -pop-state %t.a %t1.o -M 2>&1 | FileCheck -check-prefix=ERR %s
// ERR: error: unbalanced --push-state/--pop-state

.globl _start
_start:
