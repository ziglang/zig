# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/verdef-defaultver.s -o %t1
# RUN: echo "V1 { global: a; local: *; };" > %t.script
# RUN: echo "V2 { global: b; c; } V1;" >> %t.script
# RUN: ld.lld -shared -soname shared %t1 --version-script %t.script -o %t.so
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
# DSO-NEXT:      Name: a@@V1
# DSO-NEXT:      Value: 0x1000
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: b@@V2
# DSO-NEXT:      Value: 0x1002
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: b@V1
# DSO-NEXT:      Value: 0x1001
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:    Symbol {
# DSO-NEXT:      Name: c@@V2
# DSO-NEXT:      Value: 0x1003
# DSO-NEXT:      Size: 0
# DSO-NEXT:      Binding: Global
# DSO-NEXT:      Type: Function
# DSO-NEXT:      Other: 0
# DSO-NEXT:      Section: .text
# DSO-NEXT:    }
# DSO-NEXT:  ]
# DSO-NEXT:  Version symbols {
# DSO-NEXT:    Section Name: .gnu.version
# DSO-NEXT:    Address: 0x240
# DSO-NEXT:    Offset: 0x240
# DSO-NEXT:    Link: 1
# DSO-NEXT:    Symbols [
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 0
# DSO-NEXT:        Name: @
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: a@@V1
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 3
# DSO-NEXT:        Name: b@@V2
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 2
# DSO-NEXT:        Name: b@V1
# DSO-NEXT:      }
# DSO-NEXT:      Symbol {
# DSO-NEXT:        Version: 3
# DSO-NEXT:        Name: c@@V2
# DSO-NEXT:      }
# DSO-NEXT:    ]
# DSO-NEXT:  }
# DSO-NEXT:  SHT_GNU_verdef {
# DSO-NEXT:    Definition {
# DSO-NEXT:      Version: 1
# DSO-NEXT:      Flags: Base
# DSO-NEXT:      Index: 1
# DSO-NEXT:      Hash: 127830196
# DSO-NEXT:      Name: shared
# DSO-NEXT:    }
# DSO-NEXT:    Definition {
# DSO-NEXT:      Version: 1
# DSO-NEXT:      Flags: 0x0
# DSO-NEXT:      Index: 2
# DSO-NEXT:      Hash: 1425
# DSO-NEXT:      Name: V1
# DSO-NEXT:    }
# DSO-NEXT:    Definition {
# DSO-NEXT:      Version: 1
# DSO-NEXT:      Flags: 0x0
# DSO-NEXT:      Index: 3
# DSO-NEXT:      Hash: 1426
# DSO-NEXT:      Name: V2
# DSO-NEXT:    }
# DSO-NEXT:  }

## Check that we can link against DSO produced.
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2
# RUN: ld.lld %t2 %t.so -o %t3
# RUN: llvm-readobj -V -dyn-symbols %t3 | FileCheck --check-prefix=EXE %s

# EXE:      DynamicSymbols [
# EXE-NEXT:    Symbol {
# EXE-NEXT:      Name: @
# EXE-NEXT:      Value: 0x0
# EXE-NEXT:      Size: 0
# EXE-NEXT:      Binding: Local
# EXE-NEXT:      Type: None
# EXE-NEXT:      Other: 0
# EXE-NEXT:      Section: Undefined
# EXE-NEXT:    }
# EXE-NEXT:    Symbol {
# EXE-NEXT:      Name: a@V1
# EXE-NEXT:      Value: 0x201020
# EXE-NEXT:      Size: 0
# EXE-NEXT:      Binding: Global
# EXE-NEXT:      Type: Function
# EXE-NEXT:      Other: 0
# EXE-NEXT:      Section: Undefined
# EXE-NEXT:    }
# EXE-NEXT:    Symbol {
# EXE-NEXT:      Name: b@V2
# EXE-NEXT:      Value: 0x201030
# EXE-NEXT:      Size: 0
# EXE-NEXT:      Binding: Global
# EXE-NEXT:      Type: Function
# EXE-NEXT:      Other: 0
# EXE-NEXT:      Section: Undefined
# EXE-NEXT:    }
# EXE-NEXT:    Symbol {
# EXE-NEXT:      Name: c@V2
# EXE-NEXT:      Value: 0x201040
# EXE-NEXT:      Size: 0
# EXE-NEXT:      Binding: Global
# EXE-NEXT:      Type: Function
# EXE-NEXT:      Other: 0
# EXE-NEXT:      Section: Undefined
# EXE-NEXT:    }
# EXE-NEXT:  ]
# EXE-NEXT:  Version symbols {
# EXE-NEXT:    Section Name: .gnu.version
# EXE-NEXT:    Address: 0x200228
# EXE-NEXT:    Offset: 0x228
# EXE-NEXT:    Link: 1
# EXE-NEXT:    Symbols [
# EXE-NEXT:      Symbol {
# EXE-NEXT:        Version: 0
# EXE-NEXT:        Name: @
# EXE-NEXT:      }
# EXE-NEXT:      Symbol {
# EXE-NEXT:        Version: 2
# EXE-NEXT:        Name: a@V1
# EXE-NEXT:      }
# EXE-NEXT:      Symbol {
# EXE-NEXT:        Version: 3
# EXE-NEXT:        Name: b@V2
# EXE-NEXT:      }
# EXE-NEXT:      Symbol {
# EXE-NEXT:        Version: 3
# EXE-NEXT:        Name: c@V2
# EXE-NEXT:      }
# EXE-NEXT:    ]
# EXE-NEXT:  }
# EXE-NEXT:  SHT_GNU_verdef {
# EXE-NEXT:  }
# EXE-NEXT:  SHT_GNU_verneed {
# EXE-NEXT:    Dependency {
# EXE-NEXT:      Version: 1
# EXE-NEXT:      Count: 2
# EXE-NEXT:      FileName: shared
# EXE-NEXT:      Entry {
# EXE-NEXT:        Hash: 1425
# EXE-NEXT:        Flags: 0x0
# EXE-NEXT:        Index: 2
# EXE-NEXT:        Name: V1
# EXE-NEXT:      }
# EXE-NEXT:      Entry {
# EXE-NEXT:        Hash: 1426
# EXE-NEXT:        Flags: 0x0
# EXE-NEXT:        Index: 3
# EXE-NEXT:        Name: V2
# EXE-NEXT:      }
# EXE-NEXT:    }
# EXE-NEXT:  }

.globl _start
_start:
  callq a
  callq b
  callq c
