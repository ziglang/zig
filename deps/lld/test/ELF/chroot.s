# REQUIRES: x86
# RUN: rm -rf %t.dir
# RUN: mkdir %t.dir
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.dir/chroot.o
# RUN: ld.lld --chroot %t.dir -o %t.exe /chroot.o

# RUN: echo 'INPUT(/chroot.o)' > %t.dir/scr
# RUN: ld.lld --chroot %t.dir -o %t.exe /scr

.globl _start
_start:
  ret
