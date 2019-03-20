# REQUIRES: hexagon
# RUN: llvm-mc -filetype=obj -triple=hexagon-unknown-elf %s -o %t
# RUN: llvm-mc -filetype=obj -triple=hexagon-unknown-elf %S/Inputs/hexagon.s -o %t2
# RUN: ld.lld %t2 %t  -o %t3
# RUN: llvm-objdump -d  %t3 | FileCheck %s

# Note: 131072 == 0x20000
# R_HEX_32_6_X
# R_HEX_12_X
if (p0) r0 = ##_start
# CHECK: immext(#131072)
# CHECK: if (p0) r0 = ##131072

# R_HEX_B15_PCREL
if (p0) jump:nt #_start
# CHECK: if (p0) jump:nt 0x20000

# R_HEX_B32_PCREL_X
# R_HEX_B15_PCREL_X
if (p0) jump:nt ##_start
# CHECK: if (p0) jump:nt 0x20000

# R_HEX_B22_PCREL
call #_start
# CHECK: call 0x20000

# R_HEX_B32_PCREL_X
# R_HEX_B22_PCREL_X
call ##_start
# CHECK: immext(#4294967232)
# CHECK: call 0x20000

# R_HEX_6_X tests:
# One test for each mask in the lookup table.

#0x38000000
if (!P0) memw(r0+#8)=##_start
# CHECK: 38c0c100   	if (!p0) memw(r0+#8) = ##131072 }

#0x39000000
{ p0 = p1
  if (!P0.new) memw(r0+#0)=##_start }
# CHECK: 39c0c000   	if (!p0.new) memw(r0+#0) = ##131072 }

#0x3e000000
memw(r0+##_start)+=r1
# CHECK: 3e40c001   	memw(r0+##131072) += r1 }

#0x3f000000
memw(r0+##_start)+=#4
# CHECK: 3f40c004   	memw(r0+##131072) += #4 }

#0x40000000
{ r0 = r1
  if (p0) memb(r0+##_start)=r0.new }
# CHECK: 40a0c200   	if (p0) memb(r0+##131072) = r0.new }

#0x41000000
if (p0) r0=memb(r1+##_start)
# CHECK: 4101c000   	if (p0) r0 = memb(r1+##131072) }

#0x42000000
{ r0 = r1
  p0 = p1
  if (p0.new) memb(r0+##_start)=r0.new }
# CHECK: 42a0c200   	if (p0.new) memb(r0+##131072) = r0.new }

#0x43000000
{ p0 = p1
 if (P0.new) r0=memb(r0+##_start) }
# CHECK: 4300c000   	if (p0.new) r0 = memb(r0+##131072) }

#0x44000000
if (!p0) memb(r0+##_start)=r1
# CHECK: 4400c100   	if (!p0) memb(r0+##131072) = r1 }

#0x45000000
if (!p0) r0=memb(r1+##_start)
# CHECK: 4501c000   	if (!p0) r0 = memb(r1+##131072) }

#0x46000000
{ p0 = p1
  if (!p0.new) memb(r0+##_start)=r1 }
# CHECK: 4600c100   	if (!p0.new) memb(r0+##131072) = r1 }

#0x47000000
{ p0 = p1
  if (!p0.new) r0=memb(r1+##_start) }
# CHECK: 4701c000   	if (!p0.new) r0 = memb(r1+##131072) }

#0x6a000000 -- Note 4294967132 == -0xa4 the distance between
#              here and _start, so this will change if
#              tests are added between here and _start
r0=add(pc,##_start@pcrel)
# CHECK: 6a49ce00  	r0 = add(pc,##4294967132) }

#0x7c000000
r1:0=combine(#8,##_start)
# CHECK: 7c80c100   	r1:0 = combine(#8,##131072) }

#0x9a000000
r1:0=memb_fifo(r2=##_start)
# CHECK: 9a82d000   	r1:0 = memb_fifo(r2=##131072) }

#0x9b000000
r0=memb(r1=##_start)
# CHECK: 9b01d000   	r0 = memb(r1=##131072) }

#0x9c000000
r1:0=memb_fifo(r2<<#2+##_start)
# CHECK: 9c82f000   	r1:0 = memb_fifo(r2<<#2+##131072) }

#0x9d000000
r0=memb(r1<<#2+##_start)
# CHECK: 9d01f000   	r0 = memb(r1<<#2+##131072) }

#0x9f000000
if (!p0) r0=memb(##_start)
# CHECK: 9f00e880   	if (!p0) r0 = memb(##131072) }

#0xab000000
memb(r0=##_start)=r1
# CHECK: ab00c180   	memb(r0=##131072) = r1 }

#0xad000000
memb(r0<<#2+##_start)=r1
# CHECK: ad00e180   	memb(r0<<#2+##131072) = r1 }

#0xaf000000
if (!p0) memb(##_start)=r1
# CHECK: af00c184   	if (!p0) memb(##131072) = r1 }

#0xd7000000
r0=add(##_start,mpyi(r1,r2))
# CHECK: d701c200   	r0 = add(##131072,mpyi(r1,r2)) }

#0xd8000000
R0=add(##_start,mpyi(r0,#2))
# CHECK: d800c002   	r0 = add(##131072,mpyi(r0,#2)) }

#0xdb000000
r0=add(r1,add(r2,##_start))
# CHECK: db01c002   	r0 = add(r1,add(r2,##131072)) }

#0xdf000000
r0=add(r1,mpyi(r2,##_start))
# CHECK: df82c001   	r0 = add(r1,mpyi(r2,##131072)) }

# Duplex form of R_HEX_6_X
# R_HEX_32_6_X
# R_HEX_6_X
{ r0 = ##_start; r2 = r16 }
# CHECK: 28003082   	r0 = ##131072; 	r2 = r16 }

# R_HEX_HI16
r0.h = #HI(_start)
# CHECK: r0.h = #2

# R_HEX_LO16
r0.l = #LO(_start)
# CHECK: r0.l = #0

# R_HEX_8_X has 3 relocation mask variations
#0xde000000
r0=sub(##_start, asl(r0, #1))
# CHECK: de00c106      r0 = sub(##131072,asl(r0,#1)) }

#0x3c000000
memw(r0+#0) = ##_start
# CHECK: 3c40c000   	memw(r0+#0) = ##131072 }

# The rest:
r1:0=combine(r2,##_start);
# CHECK: 7302e000   	r1:0 = combine(r2,##131072) }

# R_HEX_32:
r_hex_32:
.word _start
# CHECK: 00020000

# R_HEX_16_X has 4 relocation mask variations
# 0x48000000
memw(##_start) = r0
# CHECK: 4880c000   memw(##131072) = r0 }

# 0x49000000
r0 = memw(##_start)
# CHECK: 4980c000   r0 = memw(##131072)

# 0x78000000
r0 = ##_start
# CHECK: 7800c000   r0 = ##131072 }

# 0xb0000000
r0 = add(r1, ##_start)
# CHECK: b001c000   r0 = add(r1,##131072) }

# R_HEX_B9_PCREL:
{r0=#1 ; jump #_start}
# CHECK: jump 0x20000

# R_HEX_B9_PCREL_X:
{r0=#1 ; jump ##_start}
# CHECK: jump 0x20000

# R_HEX_B13_PCREL
if (r0 == #0) jump:t #_start
# CHECK: if (r0==#0) jump:t 0x20000

# R_HEX_9_X
p0 = !cmp.gtu(r0, ##_start)
# CHECK: p0 = !cmp.gtu(r0,##131072)

# R_HEX_10_X
p0 = !cmp.gt(r0, ##_start)
# CHECK: p0 = !cmp.gt(r0,##131072)

# R_HEX_11_X
r0 = memw(r1+##_start)
# CHECK: r0 = memw(r1+##131072)

memw(r0+##_start) = r1
# CHECK: memw(r0+##131072) = r1
