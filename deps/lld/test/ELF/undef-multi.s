# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/undef.s -o %t2.o
# RUN: not ld.lld %t.o %t2.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: zed2
# CHECK-NEXT: >>> referenced by undef-multi.s
# CHECK-NEXT: >>>               {{.*}}:(.text+0x1)
# CHECK-NEXT: >>> referenced by undef-multi.s
# CHECK-NEXT: >>>               {{.*}}:(.text+0x6)
# CHECK-NEXT: >>> referenced by undef-multi.s
# CHECK-NEXT: >>>               {{.*}}:(.text+0xB)
# CHECK-NEXT: >>> referenced by undef-multi.s
# CHECK-NEXT: >>>               {{.*}}:(.text+0x10)
# CHECK-NEXT: >>> referenced by {{.*}}tmp2.o:(.text+0x0)

# All references to a single undefined symbol count as a single error -- but
# at most 10 references are printed.
# RUN: echo ".globl _bar" > %t.moreref.s
# RUN: echo "_bar:" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: echo "  call zed2" >> %t.moreref.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t.moreref.s -o %t3.o
# RUN: not ld.lld %t.o %t2.o %t3.o -o /dev/null -error-limit=2 2>&1 | \
# RUN:     FileCheck --check-prefix=LIMIT %s

# LIMIT: error: undefined symbol: zed2
# LIMIT-NEXT: >>> referenced by undef-multi.s
# LIMIT-NEXT: >>>               {{.*}}:(.text+0x1)
# LIMIT-NEXT: >>> referenced by undef-multi.s
# LIMIT-NEXT: >>>               {{.*}}:(.text+0x6)
# LIMIT-NEXT: >>> referenced by undef-multi.s
# LIMIT-NEXT: >>>               {{.*}}:(.text+0xB)
# LIMIT-NEXT: >>> referenced by undef-multi.s
# LIMIT-NEXT: >>>               {{.*}}:(.text+0x10)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp2.o:(.text+0x0)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp3.o:(.text+0x1)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp3.o:(.text+0x6)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp3.o:(.text+0xB)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp3.o:(.text+0x10)
# LIMIT-NEXT: >>> referenced by {{.*}}tmp3.o:(.text+0x15)
# LIMIT-NEXT: >>> referenced 2 more times

.file "undef-multi.s"

  .globl _start
_start:
  call zed2

  .globl _f
_f:
  call zed2

  .globl _g
_g:
  call zed2

  .globl _h
_h:
  call zed2
