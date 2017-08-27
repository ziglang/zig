// Input that generates an object with a populated SHT_ARM_ATTRIBUTES section
 .text
 .syntax unified
 .eabi_attribute        67, "2.09"      @ Tag_conformance
 .cpu    cortex-a8
 .eabi_attribute 6, 10   @ Tag_CPU_arch
 .eabi_attribute 7, 65   @ Tag_CPU_arch_profile
 .eabi_attribute 8, 1    @ Tag_ARM_ISA_use
 .eabi_attribute 9, 2    @ Tag_THUMB_ISA_use
 .fpu    neon
 .eabi_attribute 15, 1   @ Tag_ABI_PCS_RW_data
 .eabi_attribute 16, 1   @ Tag_ABI_PCS_RO_data
 .eabi_attribute 17, 2   @ Tag_ABI_PCS_GOT_use
 .eabi_attribute 20, 1   @ Tag_ABI_FP_denormal
 .eabi_attribute 21, 1   @ Tag_ABI_FP_exceptions
 .eabi_attribute 23, 3   @ Tag_ABI_FP_number_model
 .eabi_attribute 34, 1   @ Tag_CPU_unaligned_access
 .eabi_attribute 24, 1   @ Tag_ABI_align_needed
 .eabi_attribute 25, 1   @ Tag_ABI_align_preserved
 .eabi_attribute 38, 1   @ Tag_ABI_FP_16bit_format
 .eabi_attribute 18, 4   @ Tag_ABI_PCS_wchar_t
 .eabi_attribute 26, 2   @ Tag_ABI_enum_size
 .eabi_attribute 14, 0   @ Tag_ABI_PCS_R9_use
 .eabi_attribute 68, 1   @ Tag_Virtualization_use
 .globl  func
 .p2align        2
 .type   func,%function
func:
 bx lr
