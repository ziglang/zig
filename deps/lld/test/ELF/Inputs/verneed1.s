.globl f1_v1
f1_v1:
ret

.globl f1_v2
f1_v2:
ret

.globl f1_v3
f1_v3:
ret

.symver f1_v1, f1@v1
.symver f1_v2, f1@v2
.symver f1_v3, f1@@v3

.globl f2_v1
f2_v1:
ret

.globl f2_v2
f2_v2:
ret

.symver f2_v1, f2@v1
.symver f2_v2, f2@@v2

.globl f3_v1
f3_v1:
ret

.symver f3_v1, f3@v1
