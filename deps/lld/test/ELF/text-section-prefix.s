# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -z keep-text-section-prefix %t -o %t2
# RUN: llvm-readelf -l %t2 | FileCheck %s
# RUN: ld.lld %t -o %t3
# RUN: llvm-readelf -l %t3 | FileCheck --check-prefix=CHECKNO %s
# RUN: ld.lld -z nokeep-text-section-prefix %t -o %t4
# RUN: llvm-readelf -l %t4 | FileCheck --check-prefix=CHECKNO %s

# CHECK: .text
# CHECK: .text.hot
# CHECK: .text.startup
# CHECK: .text.exit
# CHECK: .text.unlikely
# CHECKNO: .text
# CHECKNO-NOT: .text.hot

_start:
  ret

.section .text.f,"ax"
f:
  nop

.section .text.hot.f_hot,"ax"
f_hot:
  nop

.section .text.startup.f_startup,"ax"
f_startup:
  nop

.section .text.exit.f_exit,"ax"
f_exit:
  nop

.section .text.unlikely.f_unlikely,"ax"
f_unlikely:
  nop
