// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %t -o %t2
.global _start
_start:
.long _GLOBAL_OFFSET_TABLE_
