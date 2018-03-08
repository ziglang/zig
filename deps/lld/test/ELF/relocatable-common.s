# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck %s
# RUN: ld.lld -r --no-define-common %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck %s
# RUN: ld.lld -r --define-common %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck -check-prefix=DEFCOMM %s
# RUN: ld.lld -r -d %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck -check-prefix=DEFCOMM %s
# RUN: ld.lld -r -dc %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck -check-prefix=DEFCOMM %s
# RUN: ld.lld -r -dp %t1.o -o %t
# RUN: llvm-readobj -symbols -r %t | FileCheck -check-prefix=DEFCOMM %s

# CHECK:        Symbol {
# CHECK:          Name: common
# CHECK-NEXT:     Value: 0x4
# CHECK-NEXT:     Size: 4
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Object
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Common (0xFFF2)
# CHECK-NEXT:   }

# DEFCOMM:      Symbol {
# DEFCOMM:        Name: common
# DEFCOMM-NEXT:   Value: 0x0
# DEFCOMM-NEXT:   Size: 4
# DEFCOMM-NEXT:   Binding: Global
# DEFCOMM-NEXT:   Type: Object
# DEFCOMM-NEXT:   Other: 0
# DEFCOMM-NEXT:   Section: COMMON
# DEFCOMM-NEXT: }

# RUN: not ld.lld -shared --no-define-common %t1.o -o %t 2>&1 | FileCheck --check-prefix=ERROR %s
# ERROR: error: -no-define-common not supported in non relocatable output

.comm common,4,4
