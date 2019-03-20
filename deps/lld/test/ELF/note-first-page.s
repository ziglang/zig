# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --build-id=md5 --shared -o %t.so
# RUN: llvm-readelf -S %t.so | FileCheck %s

# Check .note.gnu.build-id is placed before other potentially large sections
# (.dynsym .dynstr (and .rela.dyn in PIE)). This ensures the note information
# available in core files because various core dumpers ensure the first page is
# available.

# CHECK: [ 1] .note.gnu.build-id
# CHECK: [ 2] .dynsym
