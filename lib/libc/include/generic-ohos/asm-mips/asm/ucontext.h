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
#ifndef __MIPS_UAPI_ASM_UCONTEXT_H
#define __MIPS_UAPI_ASM_UCONTEXT_H
struct extcontext {
  unsigned int magic;
  unsigned int size;
};
struct msa_extcontext {
  struct extcontext ext;
#define MSA_EXTCONTEXT_MAGIC 0x784d5341
  unsigned long long wr[32];
  unsigned int csr;
};
#define END_EXTCONTEXT_MAGIC 0x78454e44
struct ucontext {
  unsigned long uc_flags;
  struct ucontext * uc_link;
  stack_t uc_stack;
  struct sigcontext uc_mcontext;
  sigset_t uc_sigmask;
  unsigned long long uc_extcontext[0];
};
#endif