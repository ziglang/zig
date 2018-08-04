// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %S/Inputs/arm-attributes1.s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t2.o

// RUN: ld.lld %t1.o %t2.o -o %t
// RUN: llvm-readobj -arm-attributes %t | FileCheck %s
// RUN: ld.lld %t1.o %t2.o -shared -o %t2
// RUN: llvm-readobj -arm-attributes %t2 | FileCheck %s
// RUN: ld.lld %t1.o %t2.o -r -o %t3
// RUN: llvm-readobj -arm-attributes %t3 | FileCheck %s

// Check that we retain only 1 SHT_ARM_ATTRIBUTES section. At present we do not
// try and merge or use the contents of SHT_ARM_ATTRIBUTES sections. We just
// pass the first one through.
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
 .globl  _start
 .p2align        2
 .type   _start,%function
_start:
 .globl func
 bl func
 bx lr

// CHECK: BuildAttributes {
// CHECK-NEXT:   FormatVersion: 0x41
// CHECK-NEXT:   Section 1 {
// CHECK-NEXT:     SectionLength: 72
// CHECK-NEXT:     Vendor: aeabi
// CHECK-NEXT:     Tag: Tag_File (0x1)
// CHECK-NEXT:     Size: 62
// CHECK-NEXT:     FileAttributes {
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 67
// CHECK-NEXT:         TagName: conformance
// CHECK-NEXT:         Value: 2.09
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 5
// CHECK-NEXT:         TagName: CPU_name
// CHECK-NEXT:         Value: cortex-a8
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 6
// CHECK-NEXT:         Value: 10
// CHECK-NEXT:         TagName: CPU_arch
// CHECK-NEXT:         Description: ARM v7
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 7
// CHECK-NEXT:         Value: 65
// CHECK-NEXT:         TagName: CPU_arch_profile
// CHECK-NEXT:         Description: Application
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 8
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ARM_ISA_use
// CHECK-NEXT:         Description: Permitted
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 9
// CHECK-NEXT:         Value: 2
// CHECK-NEXT:         TagName: THUMB_ISA_use
// CHECK-NEXT:         Description: Thumb-2
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 10
// CHECK-NEXT:         Value: 3
// CHECK-NEXT:         TagName: FP_arch
// CHECK-NEXT:         Description: VFPv3
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 12
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: Advanced_SIMD_arch
// CHECK-NEXT:         Description: NEONv1
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 14
// CHECK-NEXT:         Value: 0
// CHECK-NEXT:         TagName: ABI_PCS_R9_use
// CHECK-NEXT:         Description: v6
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 15
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_PCS_RW_data
// CHECK-NEXT:         Description: PC-relative
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 16
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_PCS_RO_data
// CHECK-NEXT:         Description: PC-relative
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 17
// CHECK-NEXT:         Value: 2
// CHECK-NEXT:         TagName: ABI_PCS_GOT_use
// CHECK-NEXT:         Description: GOT-Indirect
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 18
// CHECK-NEXT:         Value: 4
// CHECK-NEXT:         TagName: ABI_PCS_wchar_t
// CHECK-NEXT:         Description: 4-byte
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 20
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_FP_denormal
// CHECK-NEXT:         Description: IEEE-754
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 21
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_FP_exceptions
// CHECK-NEXT:         Description: IEEE-754
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 23
// CHECK-NEXT:         Value: 3
// CHECK-NEXT:         TagName: ABI_FP_number_model
// CHECK-NEXT:         Description: IEEE-754
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 24
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_align_needed
// CHECK-NEXT:         Description: 8-byte alignment
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 25
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_align_preserved
// CHECK-NEXT:         Description: 8-byte data alignment
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 26
// CHECK-NEXT:         Value: 2
// CHECK-NEXT:         TagName: ABI_enum_size
// CHECK-NEXT:         Description: Int32
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 34
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: CPU_unaligned_access
// CHECK-NEXT:         Description: v6-style
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 38
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: ABI_FP_16bit_format
// CHECK-NEXT:         Description: IEEE-754
// CHECK-NEXT:       }
// CHECK-NEXT:       Attribute {
// CHECK-NEXT:         Tag: 68
// CHECK-NEXT:         Value: 1
// CHECK-NEXT:         TagName: Virtualization_use
// CHECK-NEXT:         Description: TrustZone
// CHECK-NEXT:       }
