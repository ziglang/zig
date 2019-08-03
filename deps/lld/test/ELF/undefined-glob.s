# REQUIRES: x86

# RUN: echo '.globl foo1; foo1:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t1.o
# RUN: echo '.globl foo2; foo2:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t2.o
# RUN: echo '.globl foo32; foo32:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t3.o
# RUN: echo '.globl bar; bar:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t4.o
# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %t1.o %t2.o %t3.o %t4.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: ld.lld -o %t.exe %t.o %t.a
# RUN: llvm-readobj --symbols %t.exe | FileCheck --check-prefix=NO-OPT %s

# NO-OPT-NOT: foo
# NO-OPT-NOT: bar

# RUN: ld.lld -o %t.exe %t.o %t.a --undefined-glob foo1
# RUN: llvm-readobj --symbols %t.exe | FileCheck --check-prefix=FOO1 %s

# FOO1: foo1
# FOO1-NOT: foo2

# RUN: ld.lld -o %t.exe %t.o %t.a --undefined-glob 'foo*'
# RUN: llvm-readobj --symbols %t.exe | FileCheck --check-prefix=FOO-STAR %s

# FOO-STAR: foo1
# FOO-STAR: foo2
# FOO-STAR: foo32
# FOO-STAR-NOT: bar

# RUN: ld.lld -o %t.exe %t.o %t.a --undefined-glob 'foo?'
# RUN: llvm-readobj --symbols %t.exe | FileCheck --check-prefix=FOO-Q %s

# FOO-Q: foo1
# FOO-Q: foo2
# FOO-Q-NOT: foo32
# FOO-Q-NOT: bar

# RUN: ld.lld -o %t.exe %t.o %t.a --undefined-glob 'foo[13]*'
# RUN: llvm-readobj --symbols %t.exe | FileCheck --check-prefix=FOO13 %s

# FOO13: foo1
# FOO13-NOT: foo2
# FOO13: foo32
# FOO13-NOT: bar

# RUN: not ld.lld -o %t.exe %t.o %t.a --undefined-glob '[' 2>&1 | \
# RUN:   FileCheck -check-prefix=BAD-PATTERN %s

# BAD-PATTERN: --undefined-glob: invalid glob pattern: [

.globl _start
_start:
