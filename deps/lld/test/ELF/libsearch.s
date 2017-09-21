// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/libsearch-dyn.s -o %tdyn.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/libsearch-st.s -o %tst.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/use-bar.s -o %tbar.o
// RUN: mkdir -p %t.dir
// RUN: ld.lld -shared %tdyn.o -o %t.dir/libls.so
// RUN: cp -f %t.dir/libls.so %t.dir/libls2.so
// RUN: rm -f %t.dir/libls.a
// RUN: llvm-ar rcs %t.dir/libls.a %tst.o
// REQUIRES: x86

// Should fail if no library specified
// RUN: not ld.lld -l 2>&1 \
// RUN:   | FileCheck --check-prefix=NOLIBRARY %s
// NOLIBRARY: -l: missing argument

// Should link normally, because _bar is not used
// RUN: ld.lld -o %t3 %t.o
// Should not link because of undefined symbol _bar
// RUN: not ld.lld -o %t3 %t.o %tbar.o 2>&1 \
// RUN:   | FileCheck --check-prefix=UNDEFINED %s
// UNDEFINED: error: undefined symbol: _bar
// UNDEFINED: >>> referenced by {{.*}}:(.bar+0x0)

// Should fail if cannot find specified library (without -L switch)
// RUN: not ld.lld -o %t3 %t.o -lls 2>&1 \
// RUN:   | FileCheck --check-prefix=NOLIB %s
// NOLIB: unable to find library -lls

// Should use explicitly specified static library
// Also ensure that we accept -L <arg>
// RUN: ld.lld -o %t3 %t.o -L %t.dir -l:libls.a
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s
// STATIC: Symbols [
// STATIC: Name: _static
// STATIC: ]

// Should use explicitly specified dynamic library
// RUN: ld.lld -o %t3 %t.o -L%t.dir -l:libls.so
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s
// DYNAMIC: Symbols [
// DYNAMIC-NOT: Name: _static
// DYNAMIC: ]

// Should prefer dynamic to static
// RUN: ld.lld -o %t3 %t.o -L%t.dir -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s

// Check for library search order
// RUN: mkdir -p %t.dir2
// RUN: cp %t.dir/libls.a %t.dir2
// RUN: ld.lld -o %t3 %t.o -L%t.dir2 -L%t.dir -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s

// -L can be placed after -l
// RUN: ld.lld -o %t3 %t.o -lls -L%t.dir

// Check long forms as well
// RUN: ld.lld -o %t3 %t.o --library-path=%t.dir --library=ls

// Should not search for dynamic libraries if -Bstatic is specified
// RUN: ld.lld -o %t3 %t.o -L%t.dir -Bstatic -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s
// RUN: not ld.lld -o %t3 %t.o -L%t.dir -Bstatic -lls2 2>&1 \
// RUN:   | FileCheck --check-prefix=NOLIB2 %s
// NOLIB2: unable to find library -lls2

// -Bdynamic should restore default behaviour
// RUN: ld.lld -o %t3 %t.o -L%t.dir -Bstatic -Bdynamic -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s

// -Bstatic and -Bdynamic should affect only libraries which follow them
// RUN: ld.lld -o %t3 %t.o -L%t.dir -lls -Bstatic -Bdynamic
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s
// RUN: ld.lld -o %t3 %t.o -L%t.dir -Bstatic -lls -Bdynamic
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s

// Check aliases as well
// RUN: ld.lld -o %t3 %t.o -L%t.dir -dn -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s
// RUN: ld.lld -o %t3 %t.o -L%t.dir -non_shared -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s
// RUN: ld.lld -o %t3 %t.o -L%t.dir -static -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=STATIC %s
// RUN: ld.lld -o %t3 %t.o -L%t.dir -Bstatic -dy -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s
// RUN: ld.lld -o %t3 %t.o -L%t.dir -Bstatic -call_shared -lls
// RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=DYNAMIC %s

// -nostdlib
// RUN: echo 'SEARCH_DIR("'%t.dir'")' > %t.script
// RUN: ld.lld -o %t3 %t.o -script %t.script -lls
// RUN: not ld.lld -o %t3 %t.o -script %t.script -lls -nostdlib \
// RUN:   2>&1 | FileCheck --check-prefix=NOSTDLIB %s
// NOSTDLIB: unable to find library -lls

.globl _start,_bar
_start:
