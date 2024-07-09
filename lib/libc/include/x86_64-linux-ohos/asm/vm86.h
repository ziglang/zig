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
#ifndef _UAPI_ASM_X86_VM86_H
#define _UAPI_ASM_X86_VM86_H
#include <asm/processor-flags.h>
#define BIOSSEG 0x0f000
#define CPU_086 0
#define CPU_186 1
#define CPU_286 2
#define CPU_386 3
#define CPU_486 4
#define CPU_586 5
#define VM86_TYPE(retval) ((retval) & 0xff)
#define VM86_ARG(retval) ((retval) >> 8)
#define VM86_SIGNAL 0
#define VM86_UNKNOWN 1
#define VM86_INTx 2
#define VM86_STI 3
#define VM86_PICRETURN 4
#define VM86_TRAP 6
#define VM86_PLUS_INSTALL_CHECK 0
#define VM86_ENTER 1
#define VM86_ENTER_NO_BYPASS 2
#define VM86_REQUEST_IRQ 3
#define VM86_FREE_IRQ 4
#define VM86_GET_IRQ_BITS 5
#define VM86_GET_AND_RESET_IRQ 6
struct vm86_regs {
  long ebx;
  long ecx;
  long edx;
  long esi;
  long edi;
  long ebp;
  long eax;
  long __null_ds;
  long __null_es;
  long __null_fs;
  long __null_gs;
  long orig_eax;
  long eip;
  unsigned short cs, __csh;
  long eflags;
  long esp;
  unsigned short ss, __ssh;
  unsigned short es, __esh;
  unsigned short ds, __dsh;
  unsigned short fs, __fsh;
  unsigned short gs, __gsh;
};
struct revectored_struct {
  unsigned long __map[8];
};
struct vm86_struct {
  struct vm86_regs regs;
  unsigned long flags;
  unsigned long screen_bitmap;
  unsigned long cpu_type;
  struct revectored_struct int_revectored;
  struct revectored_struct int21_revectored;
};
#define VM86_SCREEN_BITMAP 0x0001
struct vm86plus_info_struct {
  unsigned long force_return_for_pic : 1;
  unsigned long vm86dbg_active : 1;
  unsigned long vm86dbg_TFpendig : 1;
  unsigned long unused : 28;
  unsigned long is_vm86pus : 1;
  unsigned char vm86dbg_intxxtab[32];
};
struct vm86plus_struct {
  struct vm86_regs regs;
  unsigned long flags;
  unsigned long screen_bitmap;
  unsigned long cpu_type;
  struct revectored_struct int_revectored;
  struct revectored_struct int21_revectored;
  struct vm86plus_info_struct vm86plus;
};
#endif
