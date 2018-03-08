# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY { name : ORIGIN = DATA_SEGMENT_RELRO_END; }" > %t.script
# RUN: not ld.lld -shared -o %t2 --script %t.script %t 2>&1 | FileCheck %s
# CHECK: error: {{.*}}.script:1: unable to calculate page size

# RUN: echo "MEMORY { name : ORIGIN = CONSTANT(COMMONPAGESIZE); }" > %t.script
# RUN: not ld.lld -shared -o %t2 --script %t.script %t 2>&1 |\
# RUN:   FileCheck %s --check-prefix=ERR2
# ERR2: error: {{.*}}.script:1: unable to calculate page size

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY { name : ORIGIN = .; }" > %t.script
# RUN: not ld.lld -shared -o %t2 --script %t.script %t 2>&1 |\
# RUN:   FileCheck %s --check-prefix=ERR3
# ERR3: error: {{.*}}.script:1: unable to get location counter value
