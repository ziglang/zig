# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32-unknown-elf -mattr=-relax %s -o %t.rv32.o
# RUN: llvm-mc -filetype=obj -triple=riscv64-unknown-elf -mattr=-relax %s -o %t.rv64.o

# RUN: ld.lld %t.rv32.o --defsym foo=_start+12 --defsym bar=_start -o %t.rv32
# RUN: ld.lld %t.rv64.o --defsym foo=_start+12 --defsym bar=_start -o %t.rv64
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv32 | FileCheck %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv64 | FileCheck %s
# RUN: ld.lld -pie %t.rv32.o --defsym foo=_start+12 --defsym bar=_start -o %t.rv32
# RUN: ld.lld -pie %t.rv64.o --defsym foo=_start+12 --defsym bar=_start -o %t.rv64
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv32 | FileCheck %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv64 | FileCheck %s
# CHECK:      auipc   a0, 0
# CHECK-NEXT: addi    a0, a0, 12
# CHECK-NEXT: sw      zero, 12(a0)
# CHECK:      auipc   a0, 0
# CHECK-NEXT: addi    a0, a0, -12
# CHECK-NEXT: sw      zero, -12(a0)

# RUN: ld.lld %t.rv32.o --defsym foo=_start+0x7ffff7ff --defsym bar=_start+12-0x80000800 -o %t.rv32.limits
# RUN: ld.lld %t.rv64.o --defsym foo=_start+0x7ffff7ff --defsym bar=_start+12-0x80000800 -o %t.rv64.limits
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv32.limits | FileCheck --check-prefix=LIMITS %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.rv64.limits | FileCheck --check-prefix=LIMITS %s
# LIMITS:      auipc   a0, 524287
# LIMITS-NEXT: addi    a0, a0, 2047
# LIMITS-NEXT: sw      zero, 2047(a0)
# LIMITS:      auipc   a0, 524288
# LIMITS-NEXT: addi    a0, a0, -2048
# LIMITS-NEXT: sw      zero, -2048(a0)

# RUN: ld.lld %t.rv32.o --defsym foo=_start+0x7ffff800 --defsym bar=_start+12-0x80000801 -o %t
# RUN: not ld.lld %t.rv64.o --defsym foo=_start+0x7ffff800 --defsym bar=_start+12-0x80000801 -o %t 2>&1 | FileCheck --check-prefix=ERROR %s
# ERROR:      relocation R_RISCV_PCREL_HI20 out of range: 524288 is not in [-524288, 524287]
# ERROR-NEXT: relocation R_RISCV_PCREL_HI20 out of range: -524289 is not in [-524288, 524287]

.global _start
_start:
    auipc   a0, %pcrel_hi(foo)
    addi    a0, a0, %pcrel_lo(_start)
    sw      x0, %pcrel_lo(_start)(a0)
.L1:
    auipc   a0, %pcrel_hi(bar)
    addi    a0, a0, %pcrel_lo(.L1)
    sw      x0, %pcrel_lo(.L1)(a0)
