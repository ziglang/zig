# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -soname shared -o %t2.so

# RUN: echo "{ global: foo1; foo3; local: *; };" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --version-script %t.script -shared %t.o %t2.so -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=DSO %s

# RUN: echo "# comment" > %t3.script
# RUN: echo "{ local: *; # comment" >> %t3.script
# RUN: echo -n "}; # comment" >> %t3.script
# RUN: ld.lld --version-script %t3.script -shared %t.o %t2.so -o %t3.so
# RUN: llvm-readobj -dyn-symbols %t3.so | FileCheck --check-prefix=DSO2 %s

## Also check that both "global:" and "global :" forms are accepted
# RUN: echo "VERSION_1.0 { global : foo1; local : *; };" > %t4.script
# RUN: echo "VERSION_2.0 { global: foo3; local: *; };" >> %t4.script
# RUN: ld.lld --version-script %t4.script -shared %t.o %t2.so -o %t4.so
# RUN: llvm-readobj -dyn-symbols %t4.so | FileCheck --check-prefix=VERDSO %s

# RUN: echo "VERSION_1.0 { global: foo1; local: *; };" > %t5.script
# RUN: echo "{ global: foo3; local: *; };" >> %t5.script
# RUN: not ld.lld --version-script %t5.script -shared %t.o %t2.so -o %t5.so 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR1 %s
# ERR1: anonymous version definition is used in combination with other version definitions

# RUN: echo "{ global: foo1; local: *; };" > %t5.script
# RUN: echo "VERSION_2.0 { global: foo3; local: *; };" >> %t5.script
# RUN: not ld.lld --version-script %t5.script -shared %t.o %t2.so -o %t5.so 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR2 %s
# ERR2: EOF expected, but got VERSION_2.0

# RUN: echo "VERSION_1.0 { global: foo1; local: *; };" > %t6.script
# RUN: echo "VERSION_2.0 { global: foo1; local: *; };" >> %t6.script
# RUN: not ld.lld --version-script %t6.script -shared %t.o %t2.so -o /dev/null 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR3 %s
# ERR3: duplicate symbol 'foo1' in version script

# RUN: echo "{ foo1; foo2; };" > %t.list
# RUN: ld.lld --version-script %t.script --dynamic-list %t.list %t.o %t2.so -o %t2
# RUN: llvm-readobj %t2 > /dev/null

## Check that we can handle multiple "--version-script" options.
# RUN: echo "VERSION_1.0 { global : foo1; local : *; };" > %t7a.script
# RUN: echo "VERSION_2.0 { global: foo3; local: *; };" > %t7b.script
# RUN: ld.lld --version-script %t7a.script --version-script %t7b.script -shared %t.o %t2.so -o %t7.so
# RUN: llvm-readobj -dyn-symbols %t7.so | FileCheck --check-prefix=VERDSO %s

# DSO:      DynamicSymbols [
# DSO-NEXT:   Symbol {
# DSO-NEXT:     Name:
# DSO-NEXT:     Value: 0x0
# DSO-NEXT:     Size: 0
# DSO-NEXT:     Binding: Local (0x0)
# DSO-NEXT:     Type: None (0x0)
# DSO-NEXT:     Other: 0
# DSO-NEXT:     Section: Undefined (0x0)
# DSO-NEXT:   }
# DSO-NEXT:   Symbol {
# DSO-NEXT:     Name: bar
# DSO-NEXT:     Value: 0x0
# DSO-NEXT:     Size: 0
# DSO-NEXT:     Binding: Global (0x1)
# DSO-NEXT:     Type: Function (0x2)
# DSO-NEXT:     Other: 0
# DSO-NEXT:     Section: Undefined (0x0)
# DSO-NEXT:   }
# DSO-NEXT:   Symbol {
# DSO-NEXT:     Name: foo1
# DSO-NEXT:     Value: 0x1000
# DSO-NEXT:     Size: 0
# DSO-NEXT:     Binding: Global (0x1)
# DSO-NEXT:     Type: None (0x0)
# DSO-NEXT:     Other: 0
# DSO-NEXT:     Section: .text
# DSO-NEXT:   }
# DSO-NEXT:   Symbol {
# DSO-NEXT:     Name: foo3
# DSO-NEXT:     Value: 0x1007
# DSO-NEXT:     Size: 0
# DSO-NEXT:     Binding: Global (0x1)
# DSO-NEXT:     Type: None (0x0)
# DSO-NEXT:     Other: 0
# DSO-NEXT:     Section: .text
# DSO-NEXT:   }
# DSO-NEXT: ]

# DSO2:      DynamicSymbols [
# DSO2-NEXT:   Symbol {
# DSO2-NEXT:     Name:
# DSO2-NEXT:     Value: 0x0
# DSO2-NEXT:     Size: 0
# DSO2-NEXT:     Binding: Local (0x0)
# DSO2-NEXT:     Type: None (0x0)
# DSO2-NEXT:     Other: 0
# DSO2-NEXT:     Section: Undefined (0x0)
# DSO2-NEXT:   }
# DSO2-NEXT:   Symbol {
# DSO2-NEXT:     Name: bar
# DSO2-NEXT:     Value: 0x0
# DSO2-NEXT:     Size: 0
# DSO2-NEXT:     Binding: Global (0x1)
# DSO2-NEXT:     Type: Function (0x2)
# DSO2-NEXT:     Other: 0
# DSO2-NEXT:     Section: Undefined (0x0)
# DSO2-NEXT:   }
# DSO2-NEXT: ]

# VERDSO:      DynamicSymbols [
# VERDSO-NEXT:   Symbol {
# VERDSO-NEXT:     Name:
# VERDSO-NEXT:     Value: 0x0
# VERDSO-NEXT:     Size: 0
# VERDSO-NEXT:     Binding: Local
# VERDSO-NEXT:     Type: None
# VERDSO-NEXT:     Other: 0
# VERDSO-NEXT:     Section: Undefined
# VERDSO-NEXT:   }
# VERDSO-NEXT:   Symbol {
# VERDSO-NEXT:     Name: bar
# VERDSO-NEXT:     Value: 0x0
# VERDSO-NEXT:     Size: 0
# VERDSO-NEXT:     Binding: Global
# VERDSO-NEXT:     Type: Function
# VERDSO-NEXT:     Other: 0
# VERDSO-NEXT:     Section: Undefined
# VERDSO-NEXT:   }
# VERDSO-NEXT:   Symbol {
# VERDSO-NEXT:     Name: foo1@@VERSION_1.0
# VERDSO-NEXT:     Value: 0x1000
# VERDSO-NEXT:     Size: 0
# VERDSO-NEXT:     Binding: Global
# VERDSO-NEXT:     Type: None
# VERDSO-NEXT:     Other: 0
# VERDSO-NEXT:     Section: .text
# VERDSO-NEXT:   }
# VERDSO-NEXT:   Symbol {
# VERDSO-NEXT:     Name: foo3@@VERSION_2.0
# VERDSO-NEXT:     Value: 0x1007
# VERDSO-NEXT:     Size: 0
# VERDSO-NEXT:     Binding: Global
# VERDSO-NEXT:     Type: None
# VERDSO-NEXT:     Other: 0
# VERDSO-NEXT:     Section: .text
# VERDSO-NEXT:   }
# VERDSO-NEXT: ]

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv -shared %t.o %t2.so -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=ALL %s

# RUN: echo "{ global: foo1; foo3; };" > %t2.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv --version-script %t2.script -shared %t.o %t2.so -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck --check-prefix=ALL %s

# ALL:      DynamicSymbols [
# ALL-NEXT:   Symbol {
# ALL-NEXT:     Name:
# ALL-NEXT:     Value: 0x0
# ALL-NEXT:     Size: 0
# ALL-NEXT:     Binding: Local
# ALL-NEXT:     Type: None
# ALL-NEXT:     Other: 0
# ALL-NEXT:     Section: Undefined
# ALL-NEXT:   }
# ALL-NEXT:  Symbol {
# ALL-NEXT:    Name: _start
# ALL-NEXT:    Value:
# ALL-NEXT:    Size: 0
# ALL-NEXT:    Binding: Global
# ALL-NEXT:    Type: None
# ALL-NEXT:    Other: 0
# ALL-NEXT:    Section: .text
# ALL-NEXT:  }
# ALL-NEXT:  Symbol {
# ALL-NEXT:    Name: bar
# ALL-NEXT:    Value:
# ALL-NEXT:    Size: 0
# ALL-NEXT:    Binding: Global
# ALL-NEXT:    Type: Function
# ALL-NEXT:    Other: 0
# ALL-NEXT:    Section: Undefined
# ALL-NEXT:  }
# ALL-NEXT:  Symbol {
# ALL-NEXT:    Name: foo1
# ALL-NEXT:    Value:
# ALL-NEXT:    Size: 0
# ALL-NEXT:    Binding: Global
# ALL-NEXT:    Type: None
# ALL-NEXT:    Other: 0
# ALL-NEXT:    Section: .text
# ALL-NEXT:  }
# ALL-NEXT:  Symbol {
# ALL-NEXT:    Name: foo2
# ALL-NEXT:    Value:
# ALL-NEXT:    Size: 0
# ALL-NEXT:    Binding: Global
# ALL-NEXT:    Type: None
# ALL-NEXT:    Other: 0
# ALL-NEXT:    Section: .text
# ALL-NEXT:  }
# ALL-NEXT:  Symbol {
# ALL-NEXT:    Name: foo3
# ALL-NEXT:    Value:
# ALL-NEXT:    Size: 0
# ALL-NEXT:    Binding: Global
# ALL-NEXT:    Type: None
# ALL-NEXT:    Other: 0
# ALL-NEXT:    Section: .text
# ALL-NEXT:  }
# ALL-NEXT: ]

# RUN: echo "VERSION_1.0 { global: foo1; foo1; local: *; };" > %t8.script
# RUN: ld.lld --version-script %t8.script -shared %t.o -o /dev/null --fatal-warnings

.globl foo1
foo1:
  call bar@PLT
  ret

.globl foo2
foo2:
  ret

.globl foo3
foo3:
  call foo2@PLT
  ret

.globl _start
_start:
  ret
