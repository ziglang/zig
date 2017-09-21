# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/libsearch-st.s -o %t2.o

# RUN: echo "EXTERN( undef undef2 )" > %t.script
# RUN: ld.lld %t -o %t2 %t.script
# RUN: llvm-readobj %t2 > /dev/null

# RUN: echo "OUTPUT_FORMAT(elf64-x86-64) /*/*/ GROUP(\"%t\" )" > %t.script
# RUN: ld.lld -o %t2 %t.script
# RUN: llvm-readobj %t2 > /dev/null

# RUN: rm -f %t.out
# RUN: echo "OUTPUT(\"%t.out\")" > %t.script
# RUN: ld.lld %t.script %t
# RUN: llvm-readobj %t.out > /dev/null

# RUN: echo "SEARCH_DIR(/lib/foo/blah)" > %t.script
# RUN: ld.lld %t.script %t
# RUN: llvm-readobj %t.out > /dev/null

# RUN: echo ";SEARCH_DIR(x);SEARCH_DIR(y);" > %t.script
# RUN: ld.lld %t.script %t
# RUN: llvm-readobj %t.out > /dev/null

# RUN: echo ";" > %t.script
# RUN: ld.lld %t.script %t
# RUN: llvm-readobj %t.out > /dev/null

# RUN: echo "INCLUDE \"%t.script2\" OUTPUT(\"%t.out\")" > %t.script1
# RUN: echo "GROUP(\"%t\")" > %t.script2
# RUN: ld.lld %t.script1
# RUN: llvm-readobj %t2 > /dev/null

# RUN: echo "INCLUDE \"foo.script\"" > %t.script
# RUN: echo "OUTPUT(\"%t.out\")" > %T/foo.script
# RUN: not ld.lld %t.script > %t.log 2>&1
# RUN: FileCheck -check-prefix=INCLUDE_ERR %s < %t.log
# INCLUDE_ERR: error: {{.+}}.script:1: cannot open foo.script
# INCLUDE_ERR-NEXT: error: {{.+}}.script:1: INCLUDE "foo.script"
# RUN: ld.lld -L %T %t.script %t

# RUN: echo "FOO(BAR)" > %t.script
# RUN: not ld.lld -o foo %t.script > %t.log 2>&1
# RUN: FileCheck -check-prefix=ERR1 %s < %t.log

# ERR1: unknown directive: FOO

.globl _start, _label
_start:
  ret
_label:
  ret
