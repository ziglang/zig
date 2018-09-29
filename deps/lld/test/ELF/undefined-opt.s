# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:     %p/Inputs/abs.s -o %tabs.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:     %p/Inputs/shared.s -o %tshared.o
# RUN: rm -f %tar.a
# RUN: llvm-ar rcs %tar.a %tabs.o %tshared.o

# Symbols from the archive are not in if not needed
# RUN: ld.lld -o %t1 %t.o %tar.a
# RUN: llvm-readobj --symbols %t1 | FileCheck --check-prefix=NO-UNDEFINED %s
# NO-UNDEFINED: Symbols [
# NO-UNDEFINED-NOT: Name: abs
# NO-UNDEFINED-NOT: Name: big
# NO-UNDEFINED-NOT: Name: bar
# NO-UNDEFINED-NOT: Name: zed
# NO-UNDEFINED: ]

# Symbols from the archive are in if needed, but only from the
# containing object file
# RUN: ld.lld -o %t2 %t.o %tar.a -u bar
# RUN: llvm-readobj --symbols %t2 | FileCheck --check-prefix=ONE-UNDEFINED %s
# ONE-UNDEFINED: Symbols [
# ONE-UNDEFINED-NOT: Name: abs
# ONE-UNDEFINED-NOT: Name: big
# ONE-UNDEFINED: Name: bar
# ONE-UNDEFINED: Name: zed
# ONE-UNDEFINED: ]

# Use the option couple of times, both short and long forms
# RUN: ld.lld -o %t3 %t.o %tar.a -u bar --undefined=abs
# RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TWO-UNDEFINED %s
# RUN: ld.lld -o %t3 %t.o %tar.a -u bar --undefined abs
# RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TWO-UNDEFINED %s
# TWO-UNDEFINED: Symbols [
# TWO-UNDEFINED: Name: abs
# TWO-UNDEFINED: Name: big
# TWO-UNDEFINED: Name: bar
# TWO-UNDEFINED: Name: zed
# TWO-UNDEFINED: ]
# Now the same logic but linker script is used to set undefines
# RUN: echo "EXTERN( bar abs )" > %t.script
# RUN: ld.lld -o %t3 %t.o %tar.a %t.script
# RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TWO-UNDEFINED %s

# Added undefined symbol may be left undefined without error, but
# shouldn't show up in the dynamic table.
# RUN: ld.lld -shared -o %t4 %t.o %tar.a -u unknown
# RUN: llvm-readobj --dyn-symbols %t4 | \
# RUN:     FileCheck --check-prefix=UNK-UNDEFINED-SO %s
# UNK-UNDEFINED-SO: DynamicSymbols [
# UNK-UNDEFINED-SO-NOT:     Name: unknown
# UNK-UNDEFINED-SO: ]

# Added undefined symbols should appear in the dynamic table if necessary.
# RUN: ld.lld -shared -o %t5 %t.o -u export
# RUN: llvm-readobj --dyn-symbols %t5 | \
# RUN:     FileCheck --check-prefix=EXPORT-SO %s
# EXPORT-SO: DynamicSymbols [
# EXPORT-SO:   Name: export
# EXPORT-SO: ]

.globl _start
_start:

.globl export
export:
