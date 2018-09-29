// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/resolution.s -o %t2
// RUN: ld.lld -discard-all %t %t2 -o %t3
// RUN: llvm-readobj -t %t3 | FileCheck %s

// This is an exhaustive test for checking which symbol is kept when two
// have the same name. Each symbol has a different size which is used
// to see which one was chosen.

// CHECK:      Symbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:  (0)
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Local (0x0)
// CHECK-NEXT:     Type: None (0x0)
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined (0x0)
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 63
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 30
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_RegularStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 55
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 22
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_UndefStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 27
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonStrong_with_UndefWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 26
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 61
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 28
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_RegularStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 53
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 20
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_UndefStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 25
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: CommonWeak_with_UndefWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 24
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularStrong_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 10
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularStrong_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 9
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularStrong_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 2
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularStrong_with_UndefStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 6
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularStrong_with_UndefWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 5
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 40
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 7
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_RegularStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 33
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_UndefStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: RegularWeak_with_UndefWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 3
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefStrong_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 51
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefStrong_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 50
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefStrong_with_RegularStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 46
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefStrong_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 45
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefWeak_with_CommonStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 49
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefWeak_with_CommonWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 48
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefWeak_with_RegularStrong
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 44
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefWeak_with_RegularWeak
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size: 43
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: .text
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: UndefWeak_with_UndefWeak
// CHECK-NEXT:     Value: 0x0
// CHECK-NEXT:     Size: 0
// CHECK-NEXT:     Binding: Weak
// CHECK-NEXT:     Type: None
// CHECK-NEXT:     Other: 0
// CHECK-NEXT:     Section: Undefined
// CHECK-NEXT:   }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: _start
// CHECK-NEXT:    Value: 0x201000
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global (0x1)
// CHECK-NEXT:    Type: None (0x0)
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text (0x1)
// CHECK-NEXT:  }
// CHECK-NEXT: ]

.globl _start
_start:
        nop

local:

.weak RegularWeak_with_RegularWeak
.size RegularWeak_with_RegularWeak, 0
RegularWeak_with_RegularWeak:

.weak RegularWeak_with_RegularStrong
.size RegularWeak_with_RegularStrong, 1
RegularWeak_with_RegularStrong:

.global RegularStrong_with_RegularWeak
.size RegularStrong_with_RegularWeak, 2
RegularStrong_with_RegularWeak:

.weak RegularWeak_with_UndefWeak
.size RegularWeak_with_UndefWeak, 3
RegularWeak_with_UndefWeak:

.weak RegularWeak_with_UndefStrong
.size RegularWeak_with_UndefStrong, 4
RegularWeak_with_UndefStrong:

.global RegularStrong_with_UndefWeak
.size RegularStrong_with_UndefWeak, 5
RegularStrong_with_UndefWeak:

.global RegularStrong_with_UndefStrong
.size RegularStrong_with_UndefStrong, 6
RegularStrong_with_UndefStrong:

.weak RegularWeak_with_CommonWeak
.size RegularWeak_with_CommonWeak, 7
RegularWeak_with_CommonWeak:

.weak RegularWeak_with_CommonStrong
.size RegularWeak_with_CommonStrong, 8
RegularWeak_with_CommonStrong:

.global RegularStrong_with_CommonWeak
.size RegularStrong_with_CommonWeak, 9
RegularStrong_with_CommonWeak:

.global RegularStrong_with_CommonStrong
.size RegularStrong_with_CommonStrong, 10
RegularStrong_with_CommonStrong:

.weak UndefWeak_with_RegularWeak
.size UndefWeak_with_RegularWeak, 11
.quad UndefWeak_with_RegularWeak

.weak UndefWeak_with_RegularStrong
.size UndefWeak_with_RegularStrong, 12
.quad UndefWeak_with_RegularStrong

.size UndefStrong_with_RegularWeak, 13
.quad UndefStrong_with_RegularWeak

.size UndefStrong_with_RegularStrong, 14
.quad UndefStrong_with_RegularStrong

.weak UndefWeak_with_UndefWeak
.size UndefWeak_with_UndefWeak, 15
.quad UndefWeak_with_UndefWeak

.weak UndefWeak_with_CommonWeak
.size UndefWeak_with_CommonWeak, 16
.quad UndefWeak_with_CommonWeak

.weak UndefWeak_with_CommonStrong
.size UndefWeak_with_CommonStrong, 17
.quad UndefWeak_with_CommonStrong

.size UndefStrong_with_CommonWeak, 18
.quad UndefStrong_with_CommonWeak

.size UndefStrong_with_CommonStrong, 19
.quad UndefStrong_with_CommonStrong

.weak CommonWeak_with_RegularWeak
.comm CommonWeak_with_RegularWeak,20,4

.weak CommonWeak_with_RegularStrong
.comm CommonWeak_with_RegularStrong,21,4

.comm CommonStrong_with_RegularWeak,22,4

.comm CommonStrong_with_RegularStrong,23,4

.weak CommonWeak_with_UndefWeak
.comm CommonWeak_with_UndefWeak,24,4

.weak CommonWeak_with_UndefStrong
.comm CommonWeak_with_UndefStrong,25,4

.comm CommonStrong_with_UndefWeak,26,4

.comm CommonStrong_with_UndefStrong,27,4

.weak CommonWeak_with_CommonWeak
.comm CommonWeak_with_CommonWeak,28,4

.weak CommonWeak_with_CommonStrong
.comm CommonWeak_with_CommonStrong,29,4

.comm CommonStrong_with_CommonWeak,30,4

.comm CommonStrong_with_CommonStrong,31,4
