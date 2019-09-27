# REQUIRES: x86
# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
# RUN: llvm-mc %p/Inputs/rodynamic.s -o %t.so.o -filetype=obj -triple=x86_64-pc-linux

# RUN: ld.lld -shared %t.so.o -o %t.so
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-readobj --dynamic-table %t.exe | FileCheck -check-prefix=DEFDEBUG %s
# RUN: llvm-readobj --sections %t.exe | FileCheck -check-prefix=DEFSEC %s

# RUN: ld.lld -shared -z rodynamic %t.so.o -o %t.so
# RUN: ld.lld -z rodynamic %t.o %t.so -o %t.exe
# RUN: llvm-readobj --dynamic-table %t.exe | FileCheck -check-prefix=RODEBUG %s
# RUN: llvm-readobj --sections %t.exe | FileCheck -check-prefix=ROSEC %s

.globl _start
_start:
  call foo

# DEFDEBUG: DEBUG

# DEFSEC:      Section {
# DEFSEC:        Name: .dynamic
# DEFSEC-NEXT:   Type: SHT_DYNAMIC
# DEFSEC-NEXT:   Flags [
# DEFSEC-NEXT:     SHF_ALLOC
# DEFSEC-NEXT:     SHF_WRITE
# DEFSEC-NEXT:   ]

# RODEBUG-NOT: DEBUG

# ROSEC:      Section {
# ROSEC:        Name: .dynamic
# ROSEC-NEXT:   Type: SHT_DYNAMIC
# ROSEC-NEXT:   Flags [
# ROSEC-NEXT:     SHF_ALLOC
# ROSEC-NEXT:   ]
