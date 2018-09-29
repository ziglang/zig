# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/symbol-ordering-file-warnings1.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/symbol-ordering-file-warnings2.s -o %t3.o
# RUN: ld.lld -shared %t2.o -o %t.so

# Check that a warning is emitted for entries in the file that are not present in any used input.
# RUN: echo "missing" > %t-order-missing.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-missing.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,MISSING

# Check that the warning can be disabled.
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-missing.txt \
# RUN:   --unresolved-symbols=ignore-all --no-warn-symbol-ordering 2>&1 | \
# RUN:   FileCheck %s --check-prefixes=WARN --allow-empty

# Check that the warning can be re-enabled
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-missing.txt \
# RUN:   --unresolved-symbols=ignore-all --no-warn-symbol-ordering --warn-symbol-ordering 2>&1 | \
# RUN:   FileCheck %s --check-prefixes=WARN,MISSING

# Check that a warning is emitted for undefined symbols.
# RUN: echo "undefined" > %t-order-undef.txt
# RUN: ld.lld %t1.o %t3.o -o %t --symbol-ordering-file %t-order-undef.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,UNDEFINED

# Check that a warning is emitted for imported shared symbols.
# RUN: echo "shared" > %t-order-shared.txt
# RUN: ld.lld %t1.o %t.so -o %t --symbol-ordering-file %t-order-shared.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,SHARED

# Check that a warning is emitted for absolute symbols.
# RUN: echo "absolute" > %t-order-absolute.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-absolute.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,ABSOLUTE

# Check that a warning is emitted for symbols discarded due to --gc-sections.
# RUN: echo "gc" > %t-order-gc.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-gc.txt --gc-sections \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,GC

# Check that a warning is not emitted for the symbol removed due to --icf.
# RUN: echo "icf1" > %t-order-icf.txt
# RUN: echo "icf2" >> %t-order-icf.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-icf.txt --icf=all \
# RUN:   --unresolved-symbols=ignore-all --fatal-warnings

# RUN: echo "_GLOBAL_OFFSET_TABLE_" > %t-order-synthetic.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-synthetic.txt --icf=all \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,SYNTHETIC

# Check that a warning is emitted for symbols discarded due to a linker script /DISCARD/ section.
# RUN: echo "discard" > %t-order-discard.txt
# RUN: echo "SECTIONS { /DISCARD/ : { *(.text.discard) } }" > %t.script
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-discard.txt -T %t.script \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,DISCARD

# Check that LLD does not warn for discarded COMDAT symbols, if they are present in the kept instance.
# RUN: echo "comdat" > %t-order-comdat.txt
# RUN: ld.lld %t1.o %t2.o -o %t --symbol-ordering-file %t-order-comdat.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN --allow-empty

# Check that if a COMDAT was unused and discarded via --gc-sections, warn for each instance.
# RUN: ld.lld %t1.o %t2.o -o %t --symbol-ordering-file %t-order-comdat.txt --gc-sections \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,COMDAT

# Check that if a weak symbol is not kept, because of an equivalent global symbol, no warning is emitted.
# RUN: echo "glob_or_wk" > %t-order-weak.txt
# RUN: ld.lld %t1.o %t2.o -o %t --symbol-ordering-file %t-order-weak.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN --allow-empty

# Check that symbols only in unused archive members result in a warning.
# RUN: rm -f %t.a
# RUN: llvm-ar rc %t.a %t3.o
# RUN: ld.lld %t1.o %t.a -o %t --symbol-ordering-file %t-order-missing.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,MISSING --allow-empty

# Check that a warning for each same-named symbol with an issue.
# RUN: echo "multi" > %t-order-same-name.txt
# RUN: ld.lld %t1.o %t2.o %t3.o -o %t --symbol-ordering-file %t-order-same-name.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,MULTI

# Check that a warning is emitted if the same symbol is mentioned multiple times in the ordering file.
# RUN: echo "_start" > %t-order-multiple-same.txt
# RUN: echo "_start" >> %t-order-multiple-same.txt
# RUN: ld.lld %t1.o -o %t --symbol-ordering-file %t-order-multiple-same.txt \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,SAMESYM

# Check that all warnings can be emitted from the same input.
# RUN: echo "missing_sym" > %t-order-multi.txt
# RUN: echo "undefined" >> %t-order-multi.txt
# RUN: echo "_start" >> %t-order-multi.txt
# RUN: echo "shared" >> %t-order-multi.txt
# RUN: echo "absolute" >> %t-order-multi.txt
# RUN: echo "gc" >> %t-order-multi.txt
# RUN: echo "discard" >> %t-order-multi.txt
# RUN: echo "_GLOBAL_OFFSET_TABLE_" >> %t-order-multi.txt
# RUN: echo "_start" >> %t-order-multi.txt
# RUN: ld.lld %t1.o %t3.o %t.so -o %t --symbol-ordering-file %t-order-multi.txt --gc-sections -T %t.script \
# RUN:   --unresolved-symbols=ignore-all 2>&1 | FileCheck %s --check-prefixes=WARN,SAMESYM,ABSOLUTE,SHARED,UNDEFINED,GC,DISCARD,MISSING2,SYNTHETIC

# WARN-NOT:    warning:
# SAMESYM:     warning: {{.*}}.txt: duplicate ordered symbol: _start
# WARN-NOT:    warning:
# SYNTHETIC:   warning: <internal>: unable to order synthetic symbol: _GLOBAL_OFFSET_TABLE_
# WARN-NOT:    warning:
# DISCARD:     warning: {{.*}}1.o: unable to order discarded symbol: discard
# WARN-NOT:    warning:
# GC:          warning: {{.*}}1.o: unable to order discarded symbol: gc
# WARN-NOT:    warning:
# SHARED:      warning: {{.*}}.so: unable to order shared symbol: shared
# WARN-NOT:    warning:
# UNDEFINED:   warning: {{.*}}3.o: unable to order undefined symbol: undefined
# WARN-NOT:    warning:
# ABSOLUTE:    warning: {{.*}}1.o: unable to order absolute symbol: absolute
# WARN-NOT:    warning:
# MISSING:     warning: symbol ordering file: no such symbol: missing
# MISSING2:    warning: symbol ordering file: no such symbol: missing_sym
# COMDAT:      warning: {{.*}}1.o: unable to order discarded symbol: comdat
# MULTI:       warning: {{.*}}3.o: unable to order undefined symbol: multi
# MULTI-NEXT:  warning: {{.*}}2.o: unable to order absolute symbol: multi
# WARN-NOT:    warning:

absolute = 0x1234

.section .text.gc,"ax",@progbits
.global gc
gc:
  nop

.section .text.discard,"ax",@progbits
.global discard
discard:
  nop

.section .text.comdat,"axG",@progbits,comdat,comdat
.weak comdat
comdat:
  nop

.section .text.glob_or_wk,"ax",@progbits
.weak glob_or_wk
glob_or_wk:
  nop

.section .text._start,"ax",@progbits
.global _start
_start:
  movq  %rax, absolute
  callq shared

.section .text.icf1,"ax",@progbits
.global icf1
icf1:
    ret

.section .text.icf2,"ax",@progbits
.global icf2
icf2:
    ret

# This is a "good" instance of the symbol
.section .text.multi,"ax",@progbits
multi:
  .quad _GLOBAL_OFFSET_TABLE_
