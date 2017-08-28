// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: echo  "SECTIONS { \
// RUN:         .rel.dyn : {    } \
// RUN:         .zed     : { PROVIDE_HIDDEN (foobar = .); } \
// RUN:         }" > %t.script
// This is a test case for PR33029. Making sure that linker can digest
// the above script without dumping core.
// RUN: ld.lld -emit-relocs -T %t.script %t.o -shared -o %t.so
