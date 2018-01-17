# Test -y symbol and -trace-symbol=symbol

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN: %p/Inputs/trace-symbols-foo-weak.s -o %t1
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN: %p/Inputs/trace-symbols-foo-strong.s -o %t2
# RUN: ld.lld -shared %t1 -o %t1.so
# RUN: ld.lld -shared %t2 -o %t2.so
# RUN: llvm-ar rcs %t1.a %t1
# RUN: llvm-ar rcs %t2.a %t2

# RUN: ld.lld -y foo -trace-symbol common -trace-symbol=hsymbol \
# RUN:   %t %t1 %t2 -o %t3 2>&1 | FileCheck -check-prefix=OBJECTRFOO %s
# OBJECTRFOO: trace-symbols.s.tmp: reference to foo

# RUN: ld.lld -y foo -trace-symbol=common -trace-symbol=hsymbol \
# RUN:   %t %t1 %t2 -o %t3 2>&1 | FileCheck -check-prefix=OBJECTDCOMMON %s
# OBJECTDCOMMON: trace-symbols.s.tmp1: common definition of common

# RUN: ld.lld -y foo -trace-symbol=common -trace-symbol=hsymbol \
# RUN:   %t %t1 %t2 -o %t3 2>&1 | FileCheck -check-prefix=OBJECTD1FOO %s
# OBJECTD1FOO: trace-symbols.s.tmp: reference to foo
# OBJECTD1FOO: trace-symbols.s.tmp1: common definition of common
# OBJECTD1FOO: trace-symbols.s.tmp1: definition of foo
# OBJECTD1FOO: trace-symbols.s.tmp2: definition of foo

# RUN: ld.lld -y foo -trace-symbol=common -trace-symbol=hsymbol \
# RUN:   %t %t1 %t2 -o %t3 2>&1 | FileCheck -check-prefix=OBJECTD2FOO %s
# RUN: ld.lld -y foo -y common --trace-symbol=hsymbol \
# RUN:   %t %t2 %t1 -o %t4 2>&1 | FileCheck -check-prefix=OBJECTD2FOO %s
# RUN: ld.lld -y foo -y common %t %t1.so %t2 -o %t3 2>&1 | \
# RUN:   FileCheck -check-prefix=OBJECTD2FOO %s
# OBJECTD2FOO: trace-symbols.s.tmp2: definition of foo

# RUN: ld.lld -y foo -y common %t %t2 %t1.a -o %t3 2>&1 | \
# RUN:   FileCheck -check-prefix=FOO_AND_COMMON %s
# FOO_AND_COMMON: trace-symbols.s.tmp: reference to foo
# FOO_AND_COMMON: trace-symbols.s.tmp2: definition of foo
# FOO_AND_COMMON: trace-symbols.s.tmp1.a: lazy definition of common

# RUN: ld.lld -y foo -y common %t %t1.so %t2 -o %t3 2>&1 | \
# RUN:   FileCheck -check-prefix=SHLIBDCOMMON %s
# SHLIBDCOMMON: trace-symbols.s.tmp1.so: shared definition of common

# RUN: ld.lld -y foo -y common %t %t2.so %t1.so -o %t3 2>&1 | \
# RUN:   FileCheck -check-prefix=SHLIBD2FOO %s
# RUN: ld.lld -y foo %t %t1.a %t2.so -o %t3 | \
# RUN:   FileCheck -check-prefix=NO-SHLIBD2FOO %s
# SHLIBD2FOO:        trace-symbols.s.tmp2.so: shared definition of foo
# NO-SHLIBD2FOO-NOT: trace-symbols.s.tmp2.so: definition of foo

# RUN: ld.lld -y foo -y common %t %t2 %t1.a -o %t3 2>&1 | \
# RUN:   FileCheck -check-prefix=ARCHIVEDCOMMON %s
# ARCHIVEDCOMMON-NOT: trace-symbols.s.tmp1.a(trace-symbols.s.tmp1): definition of \
# common

# RUN: ld.lld -y foo %t %t1.a %t2.so -o %t3 | \
# RUN:   FileCheck -check-prefix=ARCHIVED1FOO %s
# ARCHIVED1FOO: trace-symbols.s.tmp1.a(trace-symbols.s.tmp1): definition of foo

# RUN: ld.lld -y foo %t %t1.a %t2.a -o %t3 | \
# RUN:   FileCheck -check-prefix=ARCHIVED2FOO %s
# ARCHIVED2FOO: trace-symbols.s.tmp2.a(trace-symbols.s.tmp2): definition of foo

# RUN: ld.lld -y bar %t %t1.so %t2.so -o %t3 | \
# RUN:   FileCheck -check-prefix=SHLIBDBAR %s
# SHLIBDBAR: trace-symbols.s.tmp2.so: shared definition of bar

# RUN: ld.lld -y foo -y bar %t %t1.so %t2.so -o %t3 | \
# RUN:   FileCheck -check-prefix=SHLIBRBAR %s
# SHLIBRBAR-NOT: trace-symbols.s.tmp1.so: reference to bar

# RUN: ld.lld -y foo -y bar %t -u bar --start-lib %t1 %t2 --end-lib -o %t3 | \
# RUN:   FileCheck -check-prefix=STARTLIB %s
# STARTLIB: trace-symbols.s.tmp1: reference to bar

.hidden hsymbol
.globl	_start
.type	_start, @function
_start:
call foo
