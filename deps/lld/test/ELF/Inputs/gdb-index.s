.text
.Ltext0:
.globl main2
.type main2, @function
main2:
 nop
 nop
.Letext0:

.section .debug_info,"",@progbits
.long 0x30
.value 0x4
.long 0
.byte 0x8
.uleb128 0x1
.quad .Ltext0
.quad .Letext0-.Ltext0
.long 0
.long 0
.long 0
.long 0
.byte 0x63
.byte 0x88
.byte 0xb4
.byte 0x61
.byte 0xaa
.byte 0xb6
.byte 0xb0
.byte 0x67

.section .debug_abbrev,"",@progbits
.uleb128 0x1
.uleb128 0x11
.byte 0
.uleb128 0x11
.uleb128 0x1
.uleb128 0x12
.uleb128 0x7
.uleb128 0x10
.uleb128 0x17
.uleb128 0x2130
.uleb128 0xe
.uleb128 0x1b
.uleb128 0xe
.uleb128 0x2134
.uleb128 0x19
.uleb128 0x2133
.uleb128 0x17
.uleb128 0x2131
.uleb128 0x7
.byte 0
.byte 0
.byte 0

.section .debug_gnu_pubnames,"",@progbits
.long 0x18
.value 0x2
.long 0
.long 0x33
.long 0x18
.byte 0x30
.string "main2"
.long 0

.section .debug_gnu_pubtypes,"",@progbits
.long 0x17
.value 0x2
.long 0
.long 0x33
.long 0x2b
.byte 0x90
.string "int"
.long 0
