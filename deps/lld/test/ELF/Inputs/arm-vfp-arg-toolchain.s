	.arch armv7-a
	.eabi_attribute 20, 1
	.eabi_attribute 21, 1
	.eabi_attribute 23, 3
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 2
	.eabi_attribute 30, 6
	.eabi_attribute 34, 1
	.eabi_attribute 18, 4
	.eabi_attribute 28, 2 // Tag_ABI_VFP_args = 2 (Toolchain specific)
        .syntax unified
        .global f2
        .type f1, %function
f2:     bx lr
