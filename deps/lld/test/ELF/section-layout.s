# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %tout
# RUN: llvm-readobj -sections %tout | FileCheck %s
# REQUIRES: x86

# Check that sections are laid out in the correct order.

.global _start
.text
_start:

.section t,"x",@nobits
.section s,"x"
.section r,"w",@nobits
.section q,"w"
.section p,"wx",@nobits
.section o,"wx"
.section n,"",@nobits
.section m,""

.section l,"awx",@nobits
.section k,"awx"
.section j,"aw",@nobits
.section i,"aw"
.section g,"awT",@nobits
.section e,"awT"
.section d,"ax",@nobits
.section c,"ax"
.section b,"a",@nobits
.section a,"a"

// CHECK: Name: a
// CHECK: Name: b
// CHECK: Name: c
// CHECK: Name: d

// Sections that are both writable and executable appear before
// sections that are only writable.
// CHECK: Name: k
// CHECK: Name: l

// Writable sections appear before TLS and other relro sections.
// CHECK: Name: i

// TLS sections are only sorted on NOBITS.
// CHECK: Name: e
// CHECK: Name: g

// CHECK: Name: j

// Non allocated sections are in input order.
// CHECK: Name: t
// CHECK: Name: s
// CHECK: Name: r
// CHECK: Name: q
// CHECK: Name: p
// CHECK: Name: o
// CHECK: Name: n
// CHECK: Name: m
