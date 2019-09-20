# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32-unknown-elf -mattr=-relax %s -o %t.rv32.o
# RUN: llvm-mc -filetype=obj -triple=riscv64-unknown-elf -mattr=-relax %s -o %t.rv64.o

# RUN: ld.lld %t.rv32.o --defsym foo=_start+4 --defsym bar=_start -o %t.rv32
# RUN: ld.lld %t.rv64.o --defsym foo=_start+4 --defsym bar=_start -o %t.rv64
# RUN: llvm-objdump -d %t.rv32 | FileCheck %s
# RUN: llvm-objdump -d %t.rv64 | FileCheck %s
# CHECK: 6f 00 40 00    j   4
# CHECK: ef f0 df ff    jal -4

# RUN: ld.lld %t.rv32.o --defsym foo=_start+0xffffe --defsym bar=_start+4-0x100000 -o %t.rv32.limits
# RUN: ld.lld %t.rv64.o --defsym foo=_start+0xffffe --defsym bar=_start+4-0x100000 -o %t.rv64.limits
# RUN: llvm-objdump -d %t.rv32.limits | FileCheck --check-prefix=LIMITS %s
# RUN: llvm-objdump -d %t.rv64.limits | FileCheck --check-prefix=LIMITS %s
# LIMITS:      6f f0 ff 7f j   1048574
# LIMITS-NEXT: ef 00 00 80 jal -1048576

# RUN: not ld.lld %t.rv32.o --defsym foo=_start+0x100000 --defsym bar=_start+4-0x100002 -o %t 2>&1 | FileCheck --check-prefix=ERROR-RANGE %s
# RUN: not ld.lld %t.rv64.o --defsym foo=_start+0x100000 --defsym bar=_start+4-0x100002 -o %t 2>&1 | FileCheck --check-prefix=ERROR-RANGE %s
# ERROR-RANGE:      relocation R_RISCV_JAL out of range: 524288 is not in [-524288, 524287]
# ERROR-RANGE-NEXT: relocation R_RISCV_JAL out of range: -524289 is not in [-524288, 524287]

# RUN: not ld.lld %t.rv32.o --defsym foo=_start+1 --defsym bar=_start+4+3 -o %t 2>&1 | FileCheck --check-prefix=ERROR-ALIGN %s
# RUN: not ld.lld %t.rv64.o --defsym foo=_start+1 --defsym bar=_start+4+3 -o %t 2>&1 | FileCheck --check-prefix=ERROR-ALIGN %s
# ERROR-ALIGN:      improper alignment for relocation R_RISCV_JAL: 0x1 is not aligned to 2 bytes
# ERROR-ALIGN-NEXT: improper alignment for relocation R_RISCV_JAL: 0x3 is not aligned to 2 bytes

.global _start

_start:
    jal x0, foo
    jal x1, bar
