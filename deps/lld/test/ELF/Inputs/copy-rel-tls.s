.bss
.global foo
.type foo, @object
.size foo, 4
foo:

.section .tbss,"awT",@nobits
.global tfoo
.skip 0x2000
.type tfoo,@object
.size tfoo, 4
tfoo:
