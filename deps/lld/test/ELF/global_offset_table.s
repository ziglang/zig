// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld %t -o /dev/null
.global _start
_start:
.long _GLOBAL_OFFSET_TABLE_
