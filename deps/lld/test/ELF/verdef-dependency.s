# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "LIBSAMPLE_1.0 { global: a; local: *; };" > %t.script
# RUN: echo "LIBSAMPLE_2.0 { global: b; local: *; } LIBSAMPLE_1.0;" >> %t.script
# RUN: echo "LIBSAMPLE_3.0 { global: c; } LIBSAMPLE_2.0;" >> %t.script
# RUN: ld.lld --version-script %t.script -shared -soname shared %t.o -o %t.so
# RUN: llvm-readobj -V -dyn-symbols %t.so | FileCheck --check-prefix=DSO %s

# DSO:      SHT_GNU_verdef {
# DSO-NEXT:   Definition {
# DSO-NEXT:     Version: 1
# DSO-NEXT:     Flags: Base
# DSO-NEXT:     Index: 1
# DSO-NEXT:     Hash: 127830196
# DSO-NEXT:     Name: shared
# DSO-NEXT:   }
# DSO-NEXT:   Definition {
# DSO-NEXT:     Version: 1
# DSO-NEXT:     Flags: 0x0
# DSO-NEXT:     Index: 2
# DSO-NEXT:     Hash: 98457184
# DSO-NEXT:     Name: LIBSAMPLE_1.0
# DSO-NEXT:   }
# DSO-NEXT:   Definition {
# DSO-NEXT:     Version: 1
# DSO-NEXT:     Flags: 0x0
# DSO-NEXT:     Index: 3
# DSO-NEXT:     Hash: 98456416
# DSO-NEXT:     Name: LIBSAMPLE_2.0
# DSO-NEXT:   }
# DSO-NEXT:   Definition {
# DSO-NEXT:     Version: 1
# DSO-NEXT:     Flags: 0x0
# DSO-NEXT:     Index: 4
# DSO-NEXT:     Hash: 98456672
# DSO-NEXT:     Name: LIBSAMPLE_3.0
# DSO-NEXT:   }
# DSO-NEXT: }
