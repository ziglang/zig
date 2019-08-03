# REQUIRES: x86

# Tests handling of the comdat selection type.
# (Except associative which is tested in associative-comdat.s and
# comdat-selection-associate-largest.s instead.)

# Create obj files with each selection type.
# RUN: sed -e s/SEL/discard/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.discard.obj
# RUN: sed -e s/SEL/discard/ -e s/.long/.short/ -e s/1/2/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.discard.short.2.obj
# RUN: sed -e s/SEL/one_only/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.one_only.obj
# RUN: sed -e s/SEL/same_size/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.same_size.obj
# RUN: sed -e s/SEL/same_size/ -e s/.long/.short/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.same_size.short.obj
# RUN: sed -e s/SEL/same_contents/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.same_contents.obj
# RUN: sed -e s/SEL/same_contents/ -e s/.long/.short/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.same_contents.short.obj
# RUN: sed -e s/SEL/same_contents/ -e s/1/2/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.same_contents.2.obj
# RUN: sed -e s/SEL/largest/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.largest.obj
# RUN: sed -e s/SEL/largest/ -e s/.long/.short/ -e s/1/2/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.largest.short.2.obj
# RUN: sed -e s/SEL/newest/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.newest.obj

        .section .text$nm, "", SEL, symbol
        .globl symbol
symbol:
        .long 1

# First, pass each selection type twice. All should link fine except for
# one_only which should report a duplicate symbol error and newest which
# link.exe (and hence lld-link) doesn't understand.

# RUN: cp %t.discard.obj %t.obj && lld-link /dll /noentry /nodefaultlib %t.discard.obj %t.obj
# RUN: cp %t.one_only.obj %t.obj && not lld-link /dll /noentry /nodefaultlib %t.one_only.obj %t.obj 2>&1 | FileCheck --check-prefix=ONEONE %s
# ONEONE: lld-link: error: duplicate symbol: symbol
# RUN: cp %t.same_size.obj %t.obj && lld-link /dll /noentry /nodefaultlib %t.same_size.obj %t.obj
# RUN: cp %t.same_contents.obj %t.obj && lld-link /dll /noentry /nodefaultlib %t.same_contents.obj %t.obj
# RUN: cp %t.largest.obj %t.obj && lld-link /dll /noentry /nodefaultlib %t.largest.obj %t.obj
# RUN: cp %t.newest.obj %t.obj && not lld-link /dll /noentry /nodefaultlib %t.newest.obj %t.obj 2>&1 | FileCheck --check-prefix=NEWNEW %s
# NEWNEW: lld-link: error: unknown comdat type 7 for symbol

# /force doesn't affect errors about unknown comdat types.
# RUN: cp %t.newest.obj %t.obj && not lld-link /force /dll /noentry /nodefaultlib %t.newest.obj %t.obj 2>&1 | FileCheck --check-prefix=NEWNEWFORCE %s
# NEWNEWFORCE: lld-link: error: unknown comdat type 7 for symbol

# Check that same_size, same_contents, largest do what they're supposed to.

# Check that the "same_size" selection produces an error if passed two symbols
# with different size.
# RUN: not lld-link /dll /noentry /nodefaultlib %t.same_size.obj %t.same_size.short.obj 2>&1 | FileCheck --check-prefix=SAMESIZEDUPE %s
# SAMESIZEDUPE: lld-link: error: duplicate symbol: symbol

# Check that the "same_contents" selection produces an error if passed two
# symbols with different contents.
# RUN: not lld-link /dll /noentry /nodefaultlib %t.same_contents.obj %t.same_contents.2.obj 2>&1 | FileCheck --check-prefix=SAMECONTENTSDUPE1 %s
# SAMECONTENTSDUPE1: lld-link: error: duplicate symbol: symbol
# RUN: not lld-link /dll /noentry /nodefaultlib %t.same_contents.obj %t.same_contents.2.obj 2>&1 | FileCheck --check-prefix=SAMECONTENTSDUPE2 %s
# SAMECONTENTSDUPE2: lld-link: error: duplicate symbol: symbol

# Check that the "largest" selection picks the larger comdat (independent of
# the order the .obj files are passed on the commandline).
# RUN: lld-link /opt:noref /include:symbol /dll /noentry /nodefaultlib %t.largest.obj %t.largest.short.2.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=LARGEST1 %s
# LARGEST1: Contents of section .text:
# LARGEST1:   180001000 01000000 ....

# FIXME: Make this pass when /opt:noref is passed.
# RUN: lld-link /include:symbol /dll /noentry /nodefaultlib %t.largest.short.2.obj %t.largest.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=LARGEST2 %s
# LARGEST2: Contents of section .text:
# LARGEST2:   180001000 01000000 ....


# Test linking the same symbol with different comdat selection types.
# link.exe generally rejects this, except for "largest" which is allowed to
# combine with everything (https://bugs.llvm.org/show_bug.cgi?id=40094#c7).
# lld-link rejects all comdat selection type mismatches. Spot-test just a few
# combinations.

# RUN: not lld-link /verbose /dll /noentry /nodefaultlib %t.discard.obj %t.one_only.obj 2>&1 | FileCheck --check-prefix=DISCARDONE %s
# DISCARDONE: lld-link: conflicting comdat type for symbol: 2 in
# DISCARDONE: lld-link: error: duplicate symbol: symbol
# RUN: lld-link /verbose /force /dll /noentry /nodefaultlib %t.discard.obj %t.one_only.obj 2>&1 | FileCheck --check-prefix=DISCARDONEFORCE %s
# DISCARDONEFORCE: lld-link: conflicting comdat type for symbol: 2 in
# DISCARDONEFORCE: lld-link: warning: duplicate symbol: symbol

# Make sure the error isn't depending on the order of .obj files.
# RUN: not lld-link /verbose /dll /noentry /nodefaultlib %t.one_only.obj %t.discard.obj 2>&1 | FileCheck --check-prefix=ONEDISCARD %s
# ONEDISCARD: lld-link: conflicting comdat type for symbol: 1 in
# ONEDISCARD: lld-link: error: duplicate symbol: symbol

# RUN: not lld-link /verbose /dll /noentry /nodefaultlib %t.same_contents.obj %t.same_size.obj 2>&1 | FileCheck --check-prefix=CONTENTSSIZE %s
# CONTENTSSIZE: lld-link: conflicting comdat type for symbol: 4 in
# CONTENTSSIZE: lld-link: error: duplicate symbol: symbol

# Check that linking one 'discard' and one 'largest' has the effect of
# 'largest'.
# RUN: lld-link /dll /noentry /nodefaultlib %t.discard.short.2.obj %t.largest.obj
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=DISCARDLARGEST %s
# DISCARDLARGEST: Contents of section .text:
# DISCARDLARGEST:   180001000 01000000 ....
# RUN: lld-link /dll /noentry /nodefaultlib %t.largest.obj %t.discard.short.2.obj
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=LARGESTDISCARD %s
# LARGESTDISCARD: Contents of section .text:
# LARGESTDISCARD:   180001000 01000000 ....


# These cases are accepted by link.exe but not by lld-link.
# RUN: not lld-link /verbose /dll /noentry /nodefaultlib %t.largest.obj %t.one_only.obj 2>&1 | FileCheck --check-prefix=LARGESTONE %s
# LARGESTONE: lld-link: conflicting comdat type for symbol: 6 in
# LARGESTONE: lld-link: error: duplicate symbol: symbol
