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
#ifndef _UAPI__A_OUT_GNU_H__
#define _UAPI__A_OUT_GNU_H__
#define __GNU_EXEC_MACROS__
#ifndef __STRUCT_EXEC_OVERRIDE__
#include <asm/a.out.h>
#endif
#ifndef __ASSEMBLY__
enum machine_type {
#ifdef M_OLDSUN2
  M__OLDSUN2 = M_OLDSUN2,
#else
  M_OLDSUN2 = 0,
#endif
#ifdef M_68010
  M__68010 = M_68010,
#else
  M_68010 = 1,
#endif
#ifdef M_68020
  M__68020 = M_68020,
#else
  M_68020 = 2,
#endif
#ifdef M_SPARC
  M__SPARC = M_SPARC,
#else
  M_SPARC = 3,
#endif
  M_386 = 100,
  M_MIPS1 = 151,
  M_MIPS2 = 152
};
#ifndef N_MAGIC
#define N_MAGIC(exec) ((exec).a_info & 0xffff)
#endif
#define N_MACHTYPE(exec) ((enum machine_type) (((exec).a_info >> 16) & 0xff))
#define N_FLAGS(exec) (((exec).a_info >> 24) & 0xff)
#define N_SET_INFO(exec,magic,type,flags) ((exec).a_info = ((magic) & 0xffff) | (((int) (type) & 0xff) << 16) | (((flags) & 0xff) << 24))
#define N_SET_MAGIC(exec,magic) ((exec).a_info = (((exec).a_info & 0xffff0000) | ((magic) & 0xffff)))
#define N_SET_MACHTYPE(exec,machtype) ((exec).a_info = ((exec).a_info & 0xff00ffff) | ((((int) (machtype)) & 0xff) << 16))
#define N_SET_FLAGS(exec,flags) ((exec).a_info = ((exec).a_info & 0x00ffffff) | (((flags) & 0xff) << 24))
#define OMAGIC 0407
#define NMAGIC 0410
#define ZMAGIC 0413
#define QMAGIC 0314
#define CMAGIC 0421
#ifndef N_BADMAG
#define N_BADMAG(x) (N_MAGIC(x) != OMAGIC && N_MAGIC(x) != NMAGIC && N_MAGIC(x) != ZMAGIC && N_MAGIC(x) != QMAGIC)
#endif
#define _N_HDROFF(x) (1024 - sizeof(struct exec))
#ifndef N_TXTOFF
#define N_TXTOFF(x) (N_MAGIC(x) == ZMAGIC ? _N_HDROFF((x)) + sizeof(struct exec) : (N_MAGIC(x) == QMAGIC ? 0 : sizeof(struct exec)))
#endif
#ifndef N_DATOFF
#define N_DATOFF(x) (N_TXTOFF(x) + (x).a_text)
#endif
#ifndef N_TRELOFF
#define N_TRELOFF(x) (N_DATOFF(x) + (x).a_data)
#endif
#ifndef N_DRELOFF
#define N_DRELOFF(x) (N_TRELOFF(x) + N_TRSIZE(x))
#endif
#ifndef N_SYMOFF
#define N_SYMOFF(x) (N_DRELOFF(x) + N_DRSIZE(x))
#endif
#ifndef N_STROFF
#define N_STROFF(x) (N_SYMOFF(x) + N_SYMSIZE(x))
#endif
#ifndef N_TXTADDR
#define N_TXTADDR(x) (N_MAGIC(x) == QMAGIC ? PAGE_SIZE : 0)
#endif
#include <unistd.h>
#if defined(__i386__) || defined(__mc68000__)
#define SEGMENT_SIZE 1024
#else
#ifndef SEGMENT_SIZE
#define SEGMENT_SIZE getpagesize()
#endif
#endif
#define _N_SEGMENT_ROUND(x) ALIGN(x, SEGMENT_SIZE)
#define _N_TXTENDADDR(x) (N_TXTADDR(x) + (x).a_text)
#ifndef N_DATADDR
#define N_DATADDR(x) (N_MAGIC(x) == OMAGIC ? (_N_TXTENDADDR(x)) : (_N_SEGMENT_ROUND(_N_TXTENDADDR(x))))
#endif
#ifndef N_BSSADDR
#define N_BSSADDR(x) (N_DATADDR(x) + (x).a_data)
#endif
#ifndef N_NLIST_DECLARED
struct nlist {
  union {
    char * n_name;
    struct nlist * n_next;
    long n_strx;
  } n_un;
  unsigned char n_type;
  char n_other;
  short n_desc;
  unsigned long n_value;
};
#endif
#ifndef N_UNDF
#define N_UNDF 0
#endif
#ifndef N_ABS
#define N_ABS 2
#endif
#ifndef N_TEXT
#define N_TEXT 4
#endif
#ifndef N_DATA
#define N_DATA 6
#endif
#ifndef N_BSS
#define N_BSS 8
#endif
#ifndef N_FN
#define N_FN 15
#endif
#ifndef N_EXT
#define N_EXT 1
#endif
#ifndef N_TYPE
#define N_TYPE 036
#endif
#ifndef N_STAB
#define N_STAB 0340
#endif
#define N_INDR 0xa
#define N_SETA 0x14
#define N_SETT 0x16
#define N_SETD 0x18
#define N_SETB 0x1A
#define N_SETV 0x1C
#ifndef N_RELOCATION_INFO_DECLARED
struct relocation_info {
  int r_address;
  unsigned int r_symbolnum : 24;
  unsigned int r_pcrel : 1;
  unsigned int r_length : 2;
  unsigned int r_extern : 1;
  unsigned int r_pad : 4;
};
#endif
#endif
#endif