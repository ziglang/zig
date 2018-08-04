# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1

# RUN: ld.lld -e foobar %t1 -o %t2 2>&1 | FileCheck -check-prefix=WARN1 %s
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=TEXT %s

# WARN1: warning: cannot find entry symbol foobar; defaulting to 0x201000
# TEXT: Entry: 0x201000

# RUN: ld.lld %t1 -o %t2 2>&1 | FileCheck -check-prefix=WARN2 %s
# WARN2: warning: cannot find entry symbol _start; defaulting to 0x201000

# RUN: ld.lld -shared -e foobar %t1 -o %t2 2>&1 | FileCheck -check-prefix=WARN3 %s
# WARN3: warning: cannot find entry symbol foobar; defaulting to 0x1000

# RUN: ld.lld -shared --fatal-warnings -e entry %t1 -o %t2
# RUN: ld.lld -shared --fatal-warnings %t1 -o %t2

# RUN: echo .data > %t.s
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -n %t.s -o %t3
# RUN: ld.lld %t3 -o %t4 2>&1 | FileCheck -check-prefix=WARN4 %s
# RUN: llvm-readobj -file-headers %t4 | FileCheck -check-prefix=NOENTRY %s

# WARN4: cannot find entry symbol _start; not setting start address
# NOENTRY: Entry: 0x0

# RUN: ld.lld -v -r %t1 -o %t2 2>&1 | FileCheck -check-prefix=WARN5 %s
# WARN5-NOT: warning: cannot find entry symbol

# RUN: ld.lld %t1 -o %t2 -e entry
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=SYM %s
# SYM: Entry: 0x201008

# RUN: ld.lld %t1 --fatal-warnings -shared -o %t2 -e entry
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=DSO %s
# DSO: Entry: 0x1008

# RUN: ld.lld %t1 -o %t2 --entry=4096
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=DEC %s
# DEC: Entry: 0x1000

# RUN: ld.lld %t1 -o %t2 --entry 0xcafe
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=HEX %s
# HEX: Entry: 0xCAFE

# RUN: ld.lld %t1 -o %t2 -e 0777
# RUN: llvm-readobj -file-headers %t2 | FileCheck -check-prefix=OCT %s
# OCT: Entry: 0x1FF

.globl entry
.text
	.quad 0
entry:
	ret
