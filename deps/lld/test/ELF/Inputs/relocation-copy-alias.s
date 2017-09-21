.data

.globl a1
.type a1, @object
.size a1, 1
a1:
.weak a2
.type a2, @object
.size a2, 1
a2:
.byte 1

.weak b1
.type b1, @object
.size b1, 1
b1:
.weak b2
.type b2, @object
.size b2, 1
b2:
.globl b3
.type b3, @object
.size b3, 1
b3:
.byte 1
