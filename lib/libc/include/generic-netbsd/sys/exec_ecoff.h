/*	$NetBSD: exec_ecoff.h,v 1.21 2017/02/23 18:54:30 christos Exp $	*/

/*
 * Copyright (c) 1994 Adam Glass
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Adam Glass.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_SYS_EXEC_ECOFF_H_
#define	_SYS_EXEC_ECOFF_H_

#include <machine/ecoff_machdep.h>

#ifdef ECOFF32_PAD

typedef uint32_t ecoff32_addr;
typedef uint32_t ecoff32_off;
typedef uint32_t ecoff32_ulong;
typedef int32_t ecoff32_long;
typedef uint32_t ecoff32_uint;
typedef int32_t ecoff32_int;
typedef uint16_t ecoff32_ushort;
typedef int16_t ecoff32_short;
typedef uint8_t ecoff32_ubyte;
typedef int8_t ecoff32_byte;

struct ecoff32_filehdr {
	ecoff32_ushort  f_magic;	/* magic number */
	ecoff32_ushort  f_nscns;	/* # of sections */
	ecoff32_uint	f_timdat;	/* time and date stamp */
	ecoff32_ulong	f_symptr;	/* file offset of symbol table */
	ecoff32_uint	f_nsyms;	/* # of symbol table entries */
	ecoff32_ushort	f_opthdr;	/* sizeof the optional header */
	ecoff32_ushort	f_flags;	/* flags??? */
};

struct ecoff32_aouthdr {
	ecoff32_ushort	magic;
	ecoff32_ushort	vstamp;
	ECOFF32_PAD
	ecoff32_ulong	tsize;
	ecoff32_ulong	dsize;
	ecoff32_ulong	bsize;
	ecoff32_ulong	entry;
	ecoff32_ulong	text_start;
	ecoff32_ulong	data_start;
	ecoff32_ulong	bss_start;
	ECOFF32_MACHDEP;
};

struct ecoff32_scnhdr {			/* needed for size info */
	char		s_name[8];	/* name */
	ecoff32_ulong	s_paddr;	/* physical addr? for ROMing?*/
	ecoff32_ulong	s_vaddr;	/* virtual addr? */
	ecoff32_ulong	s_size;		/* size */
	ecoff32_ulong	s_scnptr;	/* file offset of raw data */
	ecoff32_ulong	s_relptr;	/* file offset of reloc data */
	ecoff32_ulong	s_lnnoptr;	/* file offset of line data */
	ecoff32_ushort	s_nreloc;	/* # of relocation entries */
	ecoff32_ushort	s_nlnno;	/* # of line entries */
	ecoff32_uint	s_flags;	/* flags */
};

struct ecoff32_exechdr {
	struct ecoff32_filehdr f;
	struct ecoff32_aouthdr a;
};

#define ECOFF32_HDR_SIZE (sizeof(struct ecoff32_exechdr))

#define ECOFF32_TXTOFF(ep) \
        ((ep)->a.magic == ECOFF_ZMAGIC ? 0 : \
	 ECOFF_ROUND(ECOFF32_HDR_SIZE + (ep)->f.f_nscns * \
		     sizeof(struct ecoff32_scnhdr), ECOFF32_SEGMENT_ALIGNMENT(ep)))

#define ECOFF32_DATOFF(ep) \
        (ECOFF_BLOCK_ALIGN((ep), ECOFF32_TXTOFF(ep) + (ep)->a.tsize))

#define ECOFF32_SEGMENT_ALIGN(ep, value) \
        (ECOFF_ROUND((value), ((ep)->a.magic == ECOFF_ZMAGIC ? ECOFF_LDPGSZ : \
         ECOFF32_SEGMENT_ALIGNMENT(ep))))
#endif

struct ecoff_filehdr {
	u_short f_magic;	/* magic number */
	u_short f_nscns;	/* # of sections */
	u_int   f_timdat;	/* time and date stamp */
	u_long  f_symptr;	/* file offset of symbol table */
	u_int   f_nsyms;	/* # of symbol table entries */
	u_short f_opthdr;	/* sizeof the optional header */
	u_short f_flags;	/* flags??? */
};

struct ecoff_aouthdr {
	u_short magic;
	u_short vstamp;
	ECOFF_PAD
	u_long  tsize;
	u_long  dsize;
	u_long  bsize;
	u_long  entry;
	u_long  text_start;
	u_long  data_start;
	u_long  bss_start;
	ECOFF_MACHDEP;
};

struct ecoff_scnhdr {		/* needed for size info */
	char	s_name[8];	/* name */
	u_long  s_paddr;	/* physical addr? for ROMing?*/
	u_long  s_vaddr;	/* virtual addr? */
	u_long  s_size;		/* size */
	u_long  s_scnptr;	/* file offset of raw data */
	u_long  s_relptr;	/* file offset of reloc data */
	u_long  s_lnnoptr;	/* file offset of line data */
	u_short s_nreloc;	/* # of relocation entries */
	u_short s_nlnno;	/* # of line entries */
	u_int   s_flags;	/* flags */
};

struct ecoff_exechdr {
	struct ecoff_filehdr f;
	struct ecoff_aouthdr a;
};

#define ECOFF_HDR_SIZE (sizeof(struct ecoff_exechdr))

#define ECOFF_OMAGIC 0407
#define ECOFF_NMAGIC 0410
#define ECOFF_ZMAGIC 0413

#define ECOFF_ROUND(value, by) \
        (((value) + (by) - 1) & ~((by) - 1))

#define ECOFF_BLOCK_ALIGN(ep, value) \
        ((ep)->a.magic == ECOFF_ZMAGIC ? ECOFF_ROUND((value), ECOFF_LDPGSZ) : \
	 (value))

#define ECOFF_TXTOFF(ep) \
        ((ep)->a.magic == ECOFF_ZMAGIC ? 0 : \
	 ECOFF_ROUND(ECOFF_HDR_SIZE + (ep)->f.f_nscns * \
		     sizeof(struct ecoff_scnhdr), ECOFF_SEGMENT_ALIGNMENT(ep)))

#define ECOFF_DATOFF(ep) \
        (ECOFF_BLOCK_ALIGN((ep), ECOFF_TXTOFF(ep) + (ep)->a.tsize))

#define ECOFF_SEGMENT_ALIGN(ep, value) \
        (ECOFF_ROUND((value), ((ep)->a.magic == ECOFF_ZMAGIC ? ECOFF_LDPGSZ : \
         ECOFF_SEGMENT_ALIGNMENT(ep))))

#ifdef _KERNEL
int	exec_ecoff_makecmds(struct lwp *, struct exec_package *);
int	cpu_exec_ecoff_probe(struct lwp *, struct exec_package *);
void	cpu_exec_ecoff_setregs(struct lwp *, struct exec_package *, vaddr_t);

int	exec_ecoff_prep_omagic(struct lwp *, struct exec_package *,
	    struct ecoff_exechdr *, struct vnode *);
int	exec_ecoff_prep_nmagic(struct lwp *, struct exec_package *,
	    struct ecoff_exechdr *, struct vnode *);
int	exec_ecoff_prep_zmagic(struct lwp *, struct exec_package *,
	    struct ecoff_exechdr *, struct vnode *);

#endif /* _KERNEL */
#endif /* !_SYS_EXEC_ECOFF_H_ */