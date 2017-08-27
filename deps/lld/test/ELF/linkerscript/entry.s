# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "ENTRY(_label)" > %t.script
# RUN: ld.lld -o %t2 %t.script %t
# RUN: llvm-readobj %t2 > /dev/null

# The entry symbol should not cause an undefined error.
# RUN: echo "ENTRY(_wrong_label)" > %t.script
# RUN: ld.lld -o %t2 %t.script %t
# RUN: ld.lld --entry=abc -o %t2 %t

# -e has precedence over linker script's ENTRY.
# RUN: echo "ENTRY(_label)" > %t.script
# RUN: ld.lld -e _start -o %t2 %t.script %t
# RUN: llvm-readobj -file-headers -symbols %t2 | \
# RUN:   FileCheck -check-prefix=OVERLOAD %s

# OVERLOAD: Entry: [[ENTRY:0x[0-9A-F]+]]
# OVERLOAD: Name: _start
# OVERLOAD-NEXT: Value: [[ENTRY]]

# The entry symbol can be a linker-script-defined symbol.
# RUN: echo "ENTRY(foo); foo = 1;" > %t.script
# RUN: ld.lld -o %t2 %t.script %t
# RUN: llvm-readobj -file-headers -symbols %t2 | \
# RUN:   FileCheck -check-prefix=SCRIPT %s

# SCRIPT: Entry: 0x1

# RUN: echo "ENTRY(no_such_symbol);" > %t.script
# RUN: ld.lld -o %t2 %t.script %t 2>&1 | \
# RUN:   FileCheck -check-prefix=MISSING %s

# MISSING: warning: cannot find entry symbol no_such_symbol

.globl _start, _label
_start:
  ret
_label:
  ret
