# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-win32 %s -filetype=obj -o %t.main.obj
# RUN: llvm-mc -triple=x86_64-win32 %p/Inputs/otherFunc.s -filetype=obj -o %t.other.obj
# RUN: llvm-ar rcs %t.other.lib %t.other.obj
# RUN: not lld-link -out:%t.exe -entry:main %t.main.obj %p/Inputs/std64.lib %t.other.lib -opt:noref 2>&1 | FileCheck %s
# CHECK: MessageBoxA was replaced

.global main
.text
main:
  callq MessageBoxA
  callq ExitProcess
  callq otherFunc
  ret
