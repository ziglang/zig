# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "LIBSAMPLE_1.0 { global:" > %t.script
# RUN: echo '  extern "C++" { "foo(int)"; "zed(int)"; "abc::abc()"; };' >> %t.script
# RUN: echo "};" >> %t.script
# RUN: echo "LIBSAMPLE_2.0 { global:" >> %t.script
# RUN: echo '  extern "C" { _Z3bari; };' >> %t.script
# RUN: echo "};" >> %t.script
# RUN: ld.lld --hash-style=sysv --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V -dyn-symbols %t.so | FileCheck --check-prefix=DSO %s

# DSO:      DynamicSymbols [
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: @
# DSO-NEXT:      Value: 0x0
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Local
# DSO-NEXT:      Type: None
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: Undefined
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: _Z3bari@@LIBSAMPLE_2.0
# DSO-NEXT:      Value: 0x1001
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: _Z3fooi@@LIBSAMPLE_1.0
# DSO-NEXT:      Value: 0x1000
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: _Z3zedi@@LIBSAMPLE_1.0
# DSO-NEXT:      Value: 0x1002
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global (0x1)
# DSO-NEXT:      Type: Function (0x2)
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text (0x6)
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: _ZN3abcC1Ev@@LIBSAMPLE_1.0
# DSO-NEXT:      Value: 0x1003
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global (0x1)
# DSO-NEXT:      Type: Function (0x2)
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text (0x6)
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: _ZN3abcC2Ev@@LIBSAMPLE_1.0
# DSO-NEXT:      Value: 0x1004
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global (0x1)
# DSO-NEXT:      Type: Function (0x2)
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text (0x6)
# DSO-NEXT:    }
# DSO-NEXT:  ]
# DSO-NEXT:  Version symbols {
# DSO-NEXT:    Section Name: .gnu.version
# DSO-NEXT:    Address: 0x258
# DSO-NEXT:    Offset: 0x258
# DSO-NEXT:    Link: 1
# DSO-NEXT:    Symbols [
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 0
# DSO-NEXT:        Name: @
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 3
# DSO-NEXT:        Name: _Z3bari@@LIBSAMPLE_2.0
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: _Z3fooi@@LIBSAMPLE_1.0
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: _Z3zedi@@LIBSAMPLE_1.0
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: _ZN3abcC1Ev@@LIBSAMPLE_1.0
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: _ZN3abcC2Ev@@LIBSAMPLE_1.0
# DSO-NEXT:      }
# DSO-NEXT:    ]
# DSO-NEXT:  }

.text
.globl _Z3fooi
.type _Z3fooi,@function
_Z3fooi:
retq

.globl _Z3bari
.type _Z3bari,@function
_Z3bari:
retq

.globl _Z3zedi
.type _Z3zedi,@function
_Z3zedi:
retq

.globl _ZN3abcC1Ev
.type _ZN3abcC1Ev,@function
_ZN3abcC1Ev:
retq

.globl _ZN3abcC2Ev
.type _ZN3abcC2Ev,@function
_ZN3abcC2Ev:
retq
