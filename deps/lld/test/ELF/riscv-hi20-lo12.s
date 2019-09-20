# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32-unknown-elf -mattr=-relax %s -o %t.rv32.o
# RUN: llvm-mc -filetype=obj -triple=riscv64-unknown-elf -mattr=-relax %s -o %t.rv64.o

# RUN: ld.lld %t.rv32.o --defsym foo=0 --defsym bar=42 -o %t.rv32
# RUN: ld.lld %t.rv64.o --defsym foo=0 --defsym bar=42 -o %t.rv64
# RUN: llvm-objdump -d %t.rv32 | FileCheck %s
# RUN: llvm-objdump -d %t.rv64 | FileCheck %s
# CHECK:      37 05 00 00     lui     a0, 0
# CHECK-NEXT: 13 05 05 00     mv      a0, a0
# CHECK-NEXT: 23 20 a5 00     sw      a0, 0(a0)
# CHECK-NEXT: b7 05 00 00     lui     a1, 0
# CHECK-NEXT: 93 85 a5 02     addi    a1, a1, 42
# CHECK-NEXT: 23 a5 b5 02     sw      a1, 42(a1)

# RUN: ld.lld %t.rv32.o --defsym foo=0x7ffff7ff --defsym bar=0x7ffff800 -o %t.rv32.limits
# RUN: ld.lld %t.rv64.o --defsym foo=0x7ffff7ff --defsym bar=0xffffffff7ffff800 -o %t.rv64.limits
# RUN: llvm-objdump -d %t.rv32.limits | FileCheck --check-prefix=LIMITS %s
# RUN: llvm-objdump -d %t.rv64.limits | FileCheck --check-prefix=LIMITS %s
# LIMITS:      37 f5 ff 7f     lui     a0, 524287
# LIMITS-NEXT: 13 05 f5 7f     addi    a0, a0, 2047
# LIMITS-NEXT: a3 2f a5 7e     sw      a0, 2047(a0)
# LIMITS-NEXT: b7 05 00 80     lui     a1, 524288
# LIMITS-NEXT: 93 85 05 80     addi    a1, a1, -2048
# LIMITS-NEXT: 23 a0 b5 80     sw      a1, -2048(a1)

# RUN: not ld.lld %t.rv64.o --defsym foo=0x7ffff800 --defsym bar=0xffffffff7ffff7ff -o %t 2>&1 | FileCheck --check-prefix ERROR %s
# ERROR:      relocation R_RISCV_HI20 out of range: 524288 is not in [-524288, 524287]
# ERROR-NEXT: relocation R_RISCV_HI20 out of range: -524289 is not in [-524288, 524287]

.global _start

_start:
    lui     a0, %hi(foo)
    addi    a0, a0, %lo(foo)
    sw      a0, %lo(foo)(a0)
    lui     a1, %hi(bar)
    addi    a1, a1, %lo(bar)
    sw      a1, %lo(bar)(a1)
