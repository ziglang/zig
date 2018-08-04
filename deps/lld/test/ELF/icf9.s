# REQUIRES: x86

### Make sure that we do not merge data.
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s
# RUN: llvm-readelf -S -W %t2 | FileCheck --check-prefix=SEC %s

# SEC:  .rodata      PROGBITS  0000000000200120 000120 000002 00 A 0 0 1

# CHECK-NOT: selected section {{.*}}:(.rodata.d1)
# CHECK-NOT: selected section {{.*}}:(.rodata.d2)

# We do merge rodata if passed --icf-data
# RUN: ld.lld %t -o %t2 --icf=all --print-icf-sections --ignore-data-address-equality | \
# RUN:   FileCheck --check-prefix=DATA %s
# RUN: llvm-readelf -S -W %t2 | FileCheck --check-prefix=DATA-SEC %s

# DATA: selected section {{.*}}:(.rodata.d1)
# DATA:   removing identical section {{.*}}:(.rodata.d2)

# DATA-SEC:  .rodata      PROGBITS  0000000000200120 000120 000001 00 A 0 0 1

.globl _start, d1, d2
_start:
  ret

.section .rodata.d1, "a"
d1:
  .byte 1

.section .rodata.d2, "a"
d2:
  .byte 1
