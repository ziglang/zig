#!/bin/sh -eu

# This script was used to produce the verneed{1,2}.so files.

tmp=$(mktemp -d)

echo "v1 {}; v2 {}; v3 {}; { local: *; };" > $tmp/verneed.script

cat > $tmp/verneed1.s <<eof
.globl f1_v1
f1_v1:
ret

.globl f1_v2
f1_v2:
ret

.globl f1_v3
f1_v3:
ret

.symver f1_v1, f1@v1
.symver f1_v2, f1@v2
.symver f1_v3, f1@@v3

.globl f2_v1
f2_v1:
ret

.globl f2_v2
f2_v2:
ret

.symver f2_v1, f2@v1
.symver f2_v2, f2@@v2

.globl f3_v1
f3_v1:
ret

.symver f3_v1, f3@v1
eof

as -o $tmp/verneed1.o $tmp/verneed1.s
ld.gold -shared -o verneed1.so $tmp/verneed1.o --version-script $tmp/verneed.script -soname verneed1.so.0

cat > $tmp/verneed2.s <<eof
.globl g1_v1
g1_v1:
ret

.symver g1_v1, g1@@v1
eof

as -o $tmp/verneed2.o $tmp/verneed2.s
ld.gold -shared -o verneed2.so $tmp/verneed2.o --version-script $tmp/verneed.script -soname verneed2.so.0

rm -rf $tmp
