.global a
a = 0x11

.global b
b = 0x1122

.global c
c = 0x11223344

.global d
d = 0x1122334455667788

.section .foo.1, "a"
 .byte 0xFF

.section .foo.2, "a"
 .byte 0xFF

.section .foo.3, "a"
 .byte 0xFF

.section .foo.4, "a"
 .byte 0xFF

.section .bar.1, "a"
 .byte 0xFF

.section .bar.2, "a"
 .byte 0xFF

.section .bar.3, "a"
 .byte 0xFF

.section .bar.4, "a"
 .byte 0xFF
