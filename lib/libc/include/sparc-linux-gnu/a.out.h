#ifndef __A_OUT_GNU_H__
#define __A_OUT_GNU_H__

#include <bits/a.out.h>

#define __GNU_EXEC_MACROS__

struct exec
{
  unsigned char a_dynamic:1;	/* A __DYNAMIC is in this image.  */
  unsigned char a_toolversion:7;
  unsigned char a_machtype;
  unsigned short a_info;
  unsigned int a_text;		/* Length of text, in bytes.  */
  unsigned int a_data;		/* Length of data, in bytes.  */
  unsigned int a_bss;		/* Length of bss, in bytes.  */
  unsigned int a_syms;		/* Length of symbol table, in bytes.  */
  unsigned int a_entry;		/* Where program begins.  */
  unsigned int a_trsize;
  unsigned int a_drsize;
};

enum machine_type
{
  M_OLDSUN2 = 0,
  M_68010 = 1,
  M_68020 = 2,
  M_SPARC = 3,
  M_386 = 100,
  M_MIPS1 = 151,
  M_MIPS2 = 152
};

#define N_MAGIC(exec)	((exec).a_info & 0xffff)
#define N_MACHTYPE(exec) ((enum machine_type)(((exec).a_info >> 16) & 0xff))
#define N_FLAGS(exec)	(((exec).a_info >> 24) & 0xff)
#define N_SET_INFO(exec, magic, type, flags) \
  ((exec).a_info = ((magic) & 0xffff)					\
   | (((int)(type) & 0xff) << 16)					\
   | (((flags) & 0xff) << 24))
#define N_SET_MAGIC(exec, magic) \
  ((exec).a_info = ((exec).a_info & 0xffff0000) | ((magic) & 0xffff))
#define N_SET_MACHTYPE(exec, machtype) \
  ((exec).a_info =							\
   ((exec).a_info&0xff00ffff) | ((((int)(machtype))&0xff) << 16))
#define N_SET_FLAGS(exec, flags) \
  ((exec).a_info =							\
   ((exec).a_info&0x00ffffff) | (((flags) & 0xff) << 24))

/* Code indicating object file or impure executable.  */
#define OMAGIC 0407
/* Code indicating pure executable.  */
#define NMAGIC 0410
/* Code indicating demand-paged executable.  */
#define ZMAGIC 0413
/* This indicates a demand-paged executable with the header in the text.
   The first page is unmapped to help trap NULL pointer references.  */
#define QMAGIC 0314
/* Code indicating core file.  */
#define CMAGIC 0421

#define N_TRSIZE(a)	((a).a_trsize)
#define N_DRSIZE(a)	((a).a_drsize)
#define N_SYMSIZE(a)	((a).a_syms)
#define N_BADMAG(x) \
  (N_MAGIC(x) != OMAGIC	&& N_MAGIC(x) != NMAGIC				\
   && N_MAGIC(x) != ZMAGIC && N_MAGIC(x) != QMAGIC)
#define _N_HDROFF(x)	(1024 - sizeof (struct exec))
#define N_TXTOFF(x) \
  (N_MAGIC(x) == ZMAGIC ? 0 : sizeof (struct exec))
#define N_DATOFF(x)	(N_TXTOFF(x) + (x).a_text)
#define N_TRELOFF(x)	(N_DATOFF(x) + (x).a_data)
#define N_DRELOFF(x)	(N_TRELOFF(x) + N_TRSIZE(x))
#define N_SYMOFF(x) \
  (N_TXTOFF(x) + (x).a_text + (x).a_data + (x).a_trsize + (x).a_drsize)
#define N_STROFF(x)	(N_SYMOFF(x) + N_SYMSIZE(x))

#define SPARC_PGSIZE	0x2000

/* Address of text segment in memory after it is loaded.  */
#define N_TXTADDR(x) \
 (unsigned long)(((N_MAGIC(x) == ZMAGIC) && ((x).a_entry < SPARC_PGSIZE)) \
		 ? 0 : SPARC_PGSIZE)

/* Address of data segment in memory after it is loaded.  */
#define SEGMENT_SIZE	SPARC_PGSIZE

#define _N_SEGMENT_ROUND(x) (((x) + SEGMENT_SIZE - 1) & ~(SEGMENT_SIZE - 1))
#define _N_TXTENDADDR(x) (N_TXTADDR(x)+(x).a_text)

#define N_DATADDR(x) \
  (N_MAGIC(x)==OMAGIC							\
   ? (N_TXTADDR(x) + (x).a_text)					\
   : (unsigned long)(_N_SEGMENT_ROUND (_N_TXTENDADDR(x))))
#define N_BSSADDR(x) (N_DATADDR(x) + (x).a_data)

#if !defined (N_NLIST_DECLARED)
struct nlist
{
  union
    {
      char *n_name;
      struct nlist *n_next;
      long n_strx;
    } n_un;
  unsigned char n_type;
  char n_other;
  short n_desc;
  unsigned long n_value;
};
#endif /* no N_NLIST_DECLARED.  */

#define N_UNDF	0
#define N_ABS	2
#define N_TEXT	4
#define N_DATA	6
#define N_BSS	8
#define N_FN	15
#define N_EXT	1
#define N_TYPE	036
#define N_STAB	0340
#define N_INDR	0xa
#define	N_SETA	0x14	/* Absolute set element symbol.  */
#define	N_SETT	0x16	/* Text set element symbol.  */
#define	N_SETD	0x18	/* Data set element symbol.  */
#define	N_SETB	0x1A	/* Bss set element symbol.  */
#define N_SETV	0x1C	/* Pointer to set vector in data area.  */

#if !defined (N_RELOCATION_INFO_DECLARED)
enum reloc_type
{
  RELOC_8,
  RELOC_16,
  RELOC_32,
  RELOC_DISP8,
  RELOC_DISP16,
  RELOC_DISP32,
  RELOC_WDISP30,
  RELOC_WDISP22,
  RELOC_HI22,
  RELOC_22,
  RELOC_13,
  RELOC_LO10,
  RELOC_SFA_BASE,
  RELOC_SFA_OFF13,
  RELOC_BASE10,
  RELOC_BASE13,
  RELOC_BASE22,
  RELOC_PC10,
  RELOC_PC22,
  RELOC_JMP_TBL,
  RELOC_SEGOFF16,
  RELOC_GLOB_DAT,
  RELOC_JMP_SLOT,
  RELOC_RELATIVE
};

/* This structure describes a single relocation to be performed.
   The text-relocation section of the file is a vector of these structures,
   all of which apply to the text section.
   Likewise, the data-relocation section applies to the data section.  */

struct relocation_info
{
  unsigned int r_address;
  unsigned int r_index:24;
  unsigned int r_extern:1;
  int r_pad:2;
  enum reloc_type r_type:5;
  int r_addend;
};
#endif /* no N_RELOCATION_INFO_DECLARED.  */

#endif /* __A_OUT_GNU_H__ */