// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
// RUN:   %p/Inputs/exclude-libs.s -o %t2.o
// RUN: llvm-as --data-layout=elf %p/Inputs/exclude-libs.ll -o %t3.o
// RUN: mkdir -p %t.dir
// RUN: rm -f %t.dir/exc.a
// RUN: llvm-ar rcs %t.dir/exc.a %t2.o %t3.o

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=DEFAULT %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs=foo,bar
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=DEFAULT %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs foo,bar,exc.a
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs foo:bar:exc.a
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared %t.o %t.dir/exc.a -o %t.exe --exclude-libs=ALL
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared %t.o %t2.o %t3.o %t.dir/exc.a -o %t.exe --exclude-libs=ALL
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=DEFAULT %s

// RUN: ld.lld -shared --whole-archive %t.o %t.dir/exc.a -o %t.exe --exclude-libs foo,bar,exc.a
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=EXCLUDE %s

// RUN: ld.lld -shared --whole-archive %t.o %t.dir/exc.a -o %t.exe --exclude-libs=ALL
// RUN: llvm-readobj --dyn-syms %t.exe | FileCheck --check-prefix=EXCLUDE %s

// DEFAULT: Name: fn
// DEFAULT: Name: fn2
// DEFAULT: Name: foo
// EXCLUDE-NOT: Name: fn
// EXCLUDE-NOT: Name: fn2
// EXCLUDE: Name: foo

.globl fn, fn2, foo
foo:
  call fn@PLT
  call fn2@PLT
