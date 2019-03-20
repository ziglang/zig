# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "FOO { local: extern \"C++\" { \"abb(int)\"; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s --check-prefix=ABB
# ABB:      Symbols [
# ABB-NEXT:   Symbol {
# ABB-NEXT:     Version: 0
# ABB-NEXT:     Name:
# ABB-NEXT:   }
# ABB-NEXT:   Symbol {
# ABB-NEXT:     Version: 1
# ABB-NEXT:     Name: _Z3abci
# ABB-NEXT:   }
# ABB-NEXT: ]

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "FOO { local: extern \"C++\" { abb*; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s --check-prefix=ABB

# RUN: echo "FOO { local: extern \"C++\" { abc*; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s --check-prefix=ABC
# ABC:      Symbols [
# ABC-NEXT:   Symbol {
# ABC-NEXT:     Version: 0
# ABC-NEXT:     Name:
# ABC-NEXT:   }
# ABC-NEXT:   Symbol {
# ABC-NEXT:     Version: 1
# ABC-NEXT:     Name: _Z3abbi
# ABC-NEXT:   }
# ABC-NEXT: ]

.globl _Z3abbi
.type _Z3abbi,@function
_Z3abbi:
retq

.globl _Z3abci
.type _Z3abci,@function
_Z3abci:
retq
