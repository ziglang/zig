/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1995-1996 Søren Schmidt
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
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

#ifndef _SYS_IMGACT_ELF_H_
#define	_SYS_IMGACT_ELF_H_

#include <machine/elf.h>

#ifdef _KERNEL

#define	AUXARGS_ENTRY(pos, id, val) \
    {(pos)->a_type = (id); (pos)->a_un.a_val = (val); (pos)++;}
#if (defined(__LP64__) && __ELF_WORD_SIZE == 32)
#define	AUXARGS_ENTRY_PTR(pos, id, ptr) \
    {(pos)->a_type = (id); (pos)->a_un.a_val = (uintptr_t)(ptr); (pos)++;}
#else
#define	AUXARGS_ENTRY_PTR(pos, id, ptr) \
    {(pos)->a_type = (id); (pos)->a_un.a_ptr = (ptr); (pos)++;}
#endif

struct image_params;
struct thread;
struct vnode;
struct note_info_list;
struct sbuf;

/*
 * Structure used to pass information from the loader to the
 * stack fixup routine.
 */
typedef struct {
	Elf_Ssize	execfd;
	Elf_Size	phdr;
	Elf_Size	phent;
	Elf_Size	phnum;
	Elf_Size	pagesz;
	Elf_Size	base;
	Elf_Size	flags;
	Elf_Size	entry;
	Elf_Word	hdr_eflags;		/* e_flags field from ehdr */
} __ElfN(Auxargs);

typedef struct {
	Elf_Note	hdr;
	const char *	vendor;
	int		flags;
	bool		(*trans_osrel)(const Elf_Note *, int32_t *);
#define	BN_CAN_FETCH_OSREL	0x0001	/* Deprecated. */
#define	BN_TRANSLATE_OSREL	0x0002	/* Use trans_osrel to fetch osrel */
		/* after checking the image ABI specification, if needed. */
} Elf_Brandnote;

typedef struct {
	int brand;
	int machine;
	const char *compat_3_brand;	/* pre Binutils 2.10 method (FBSD 3) */
	const char *interp_path;
	struct sysentvec *sysvec;
	const char *interp_newpath;
	int flags;
	Elf_Brandnote *brand_note;
	bool		(*header_supported)(struct image_params *,
	    int32_t *, uint32_t *);
		/* High 8 bits of flags is private to the ABI */
#define	BI_CAN_EXEC_DYN		0x0001
#define	BI_BRAND_NOTE		0x0002	/* May have note.ABI-tag section. */
#define	BI_BRAND_NOTE_MANDATORY	0x0004	/* Must have note.ABI-tag section. */
#define	BI_BRAND_ONLY_STATIC	0x0008	/* Match only interp-less binaries. */
} __ElfN(Brandinfo);

__ElfType(Auxargs);
__ElfType(Brandinfo);

#define	MAX_BRANDS		8
#define	FREEBSD_ABI_VENDOR	"FreeBSD"
#define	GNU_ABI_VENDOR		"GNU"

typedef void (*outfunc_t)(void *, struct sbuf *, size_t *);

/* Closure for __elfN(size_segments)(). */
struct sseg_closure {
	int count;              /* Count of writable segments. */
	size_t size;            /* Total size of all writable segments. */
};

bool	__elfN(brand_inuse)(Elf_Brandinfo *entry);
int	__elfN(insert_brand_entry)(Elf_Brandinfo *entry);
int	__elfN(remove_brand_entry)(Elf_Brandinfo *entry);
int	__elfN(freebsd_fixup)(uintptr_t *, struct image_params *);
int	__elfN(coredump)(struct thread *, struct vnode *, off_t, int);
size_t	__elfN(populate_note)(int, void *, void *, size_t, void **);
int	__elfN(freebsd_copyout_auxargs)(struct image_params *, uintptr_t);
void	__elfN(puthdr)(struct thread *, void *, size_t, int, size_t, int);
void	__elfN(prepare_notes)(struct thread *, struct note_info_list *,
	    size_t *);
void	__elfN(size_segments)(struct thread *, struct sseg_closure *, int);
size_t	__elfN(register_note)(struct thread *, struct note_info_list *,
	    int, outfunc_t, void *);
bool	__elfN(parse_notes)(struct image_params *, Elf_Note *, const char *,
	    const Elf_Phdr *, bool (*)(const Elf_Note *, void *, bool *),
	    void *);

/* Machine specific function to dump per-thread information. */
void	__elfN(dump_thread)(struct thread *, void *, size_t *);

extern int __elfN(fallback_brand);
extern Elf_Brandnote __elfN(freebsd_brandnote);
extern Elf_Brandnote __elfN(kfreebsd_brandnote);
#endif /* _KERNEL */

#endif /* !_SYS_IMGACT_ELF_H_ */