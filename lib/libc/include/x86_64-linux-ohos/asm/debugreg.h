/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_ASM_X86_DEBUGREG_H
#define _UAPI_ASM_X86_DEBUGREG_H
#define DR_FIRSTADDR 0
#define DR_LASTADDR 3
#define DR_STATUS 6
#define DR_CONTROL 7
#define DR6_RESERVED (0xFFFF0FF0)
#define DR_TRAP0 (0x1)
#define DR_TRAP1 (0x2)
#define DR_TRAP2 (0x4)
#define DR_TRAP3 (0x8)
#define DR_TRAP_BITS (DR_TRAP0 | DR_TRAP1 | DR_TRAP2 | DR_TRAP3)
#define DR_STEP (0x4000)
#define DR_SWITCH (0x8000)
#define DR_CONTROL_SHIFT 16
#define DR_CONTROL_SIZE 4
#define DR_RW_EXECUTE (0x0)
#define DR_RW_WRITE (0x1)
#define DR_RW_READ (0x3)
#define DR_LEN_1 (0x0)
#define DR_LEN_2 (0x4)
#define DR_LEN_4 (0xC)
#define DR_LEN_8 (0x8)
#define DR_LOCAL_ENABLE_SHIFT 0
#define DR_GLOBAL_ENABLE_SHIFT 1
#define DR_LOCAL_ENABLE (0x1)
#define DR_GLOBAL_ENABLE (0x2)
#define DR_ENABLE_SIZE 2
#define DR_LOCAL_ENABLE_MASK (0x55)
#define DR_GLOBAL_ENABLE_MASK (0xAA)
#ifdef __i386__
#define DR_CONTROL_RESERVED (0xFC00)
#else
#define DR_CONTROL_RESERVED (0xFFFFFFFF0000FC00UL)
#endif
#define DR_LOCAL_SLOWDOWN (0x100)
#define DR_GLOBAL_SLOWDOWN (0x200)
#endif
