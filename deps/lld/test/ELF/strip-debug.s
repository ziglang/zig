# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -g %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-readobj -sections -symbols %t2 | FileCheck -check-prefix=DEFAULT %s
# RUN: ld.lld %t -o %t2 --strip-debug
# RUN: llvm-readobj -sections -symbols %t2 | FileCheck -check-prefix=STRIP %s
# RUN: ld.lld %t -o %t2 -S
# RUN: llvm-readobj -sections -symbols %t2 | FileCheck -check-prefix=STRIP %s
# RUN: ld.lld %t -o %t2 --strip-all
# RUN: llvm-readobj -sections -symbols %t2 | FileCheck -check-prefix=STRIP %s

# DEFAULT: Name: .debug_info
# DEFAULT: Name: .debug_abbrev
# DEFAULT: Name: .debug_aranges
# DEFAULT: Name: .debug_line

# STRIP-NOT: Name: .debug_info
# STRIP-NOT: Name: .debug_abbrev
# STRIP-NOT: Name: .debug_aranges
# STRIP-NOT: Name: .debug_line

.globl _start
_start:
  ret
