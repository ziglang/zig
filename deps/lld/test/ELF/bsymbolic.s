// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld -shared %t.o -o %t0.so
// RUN: ld.lld -shared -Bsymbolic %t.o -o %t1.so
// RUN: ld.lld -shared -Bsymbolic-functions %t.o -o %t2.so
// RUN: llvm-readobj -s %t0.so | FileCheck -check-prefix=NOOPTION %s
// RUN: llvm-readobj -s %t1.so | FileCheck -check-prefix=SYMBOLIC %s
// RUN: llvm-readobj -s %t2.so | FileCheck -check-prefix=SYMBOLIC %s

// NOOPTION:     Section {
// NOOPTION:       Name: .plt

// SYMBOLIC: Section {
// SYMBOLIC-NOT: Name: .plt

.text
.globl foo
.type foo,@function
foo:
nop

.globl bar
.type bar,@function
bar:
nop

.globl do
.type do,@function
do:
callq foo@PLT
callq bar@PLT

.weak zed
.protected zed
.quad zed
