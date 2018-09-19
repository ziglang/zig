# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: not ld.lld %t1.o %t1.o -o %t2 2>&1 | FileCheck -check-prefix=DEMANGLE %s

# DEMANGLE:       duplicate symbol: mul(double, double)
# DEMANGLE-NEXT:  >>> defined at {{.*}}:(.text+0x0)
# DEMANGLE-NEXT:  >>> defined at {{.*}}:(.text+0x0)
# DEMANGLE:       duplicate symbol: foo
# DEMANGLE-NEXT:  >>> defined at {{.*}}:(.text+0x0)
# DEMANGLE-NEXT:  >>> defined at {{.*}}:(.text+0x0)

# RUN: not ld.lld %t1.o %t1.o -o %t2 --no-demangle 2>&1 | \
# RUN:   FileCheck -check-prefix=NO_DEMANGLE %s

# NO_DEMANGLE:      duplicate symbol: _Z3muldd
# NO_DEMANGLE-NEXT: >>> defined at {{.*}}:(.text+0x0)
# NO_DEMANGLE-NEXT: >>> defined at {{.*}}:(.text+0x0)
# NO_DEMANGLE:      duplicate symbol: foo
# NO_DEMANGLE-NEXT: >>> defined at {{.*}}:(.text+0x0)
# NO_DEMANGLE-NEXT: >>> defined at {{.*}}:(.text+0x0)

# RUN: not ld.lld %t1.o %t1.o -o %t2 --demangle --no-demangle 2>&1 | \
# RUN:   FileCheck -check-prefix=NO_DEMANGLE %s
# RUN: not ld.lld %t1.o %t1.o -o %t2 --no-demangle --demangle 2>&1 | \
# RUN:   FileCheck -check-prefix=DEMANGLE %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/conflict.s -o %t2.o
# RUN: llvm-ar rcs %t3.a %t2.o
# RUN: not ld.lld %t1.o %t3.a -u baz -o %t2 2>&1 | FileCheck -check-prefix=ARCHIVE %s

# ARCHIVE:      duplicate symbol: foo
# ARCHIVE-NEXT: >>> defined at {{.*}}:(.text+0x0)
# ARCHIVE-NEXT: >>> defined at {{.*}}:(.text+0x0) in archive {{.*}}.a

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/conflict-debug.s -o %t-dbg.o
# RUN: not ld.lld %t-dbg.o %t-dbg.o -o /dev/null 2>&1 | FileCheck -check-prefix=DBGINFO %s

# DBGINFO:      duplicate symbol: zed
# DBGINFO-NEXT: >>> defined at conflict-debug.s:4
# DBGINFO-NEXT: >>>            {{.*}}:(.text+0x0)
# DBGINFO-NEXT: >>> defined at conflict-debug.s:4
# DBGINFO-NEXT: >>>            {{.*}}:(.text+0x0)

.globl _Z3muldd, foo
_Z3muldd:
foo:
  mov $60, %rax
  mov $42, %rdi
  syscall
