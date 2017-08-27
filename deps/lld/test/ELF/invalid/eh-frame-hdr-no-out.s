// REQUIRES: x86
// RUN: not ld.lld --eh-frame-hdr %p/Inputs/cie-version2.elf -o %t >& %t.log
// RUN: FileCheck %s < %t.log

// cie-version2.elf contains unsupported version of CIE = 2.
// CHECK: FDE version 1 or 3 expected, but got 2
