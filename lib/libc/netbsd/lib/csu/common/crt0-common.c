/* $NetBSD: crt0-common.c,v 1.27 2022/06/21 06:52:17 skrll Exp $ */

/*
 * Copyright (c) 1998 Christos Zoulas
 * Copyright (c) 1995 Christopher G. Demetriou
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
 *          This product includes software developed for the
 *          NetBSD Project.  See http://www.NetBSD.org/ for
 *          information about NetBSD.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
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
 *
 * <<Id: LICENSE,v 1.2 2000/06/14 15:57:33 cgd Exp>>
 */

#include <sys/cdefs.h>
__RCSID("$NetBSD: crt0-common.c,v 1.27 2022/06/21 06:52:17 skrll Exp $");

#include <sys/types.h>
#include <sys/exec.h>
#include <sys/exec_elf.h>
#include <sys/syscall.h>
#include <machine/profile.h>
#include <stdlib.h>
#include <unistd.h>

#include "csu-common.h"

extern int main(int, char **, char **);

typedef void (*fptr_t)(void);
#ifndef HAVE_INITFINI_ARRAY
extern void	_init(void);
extern void	_fini(void);
#endif
extern void	_libc_init(void);

/*
 * Arrange for _DYNAMIC to be weak and undefined (and therefore to show up
 * as being at address zero, unless something else defines it).  That way,
 * if we happen to be compiling without -static but with without any
 * shared libs present, things will still work.
 */

__weakref_visible int rtld_DYNAMIC __weak_reference(_DYNAMIC);

#ifdef MCRT0
extern void	monstartup(u_long, u_long);
extern void	_mcleanup(void);
extern unsigned char __etext, __eprol;
#endif /* MCRT0 */

static char	 empty_string[] = "";

char		**environ __common;
struct ps_strings *__ps_strings __common = 0;
char		*__progname __common = empty_string;

__dead __dso_hidden void ___start(void (*)(void), struct ps_strings *);

#define	write(fd, s, n)	__syscall(SYS_write, (fd), (s), (n))

#define	_FATAL(str)				\
do {						\
	write(2, str, sizeof(str)-1);		\
	_exit(1);				\
} while (0)

/*
 * If we are using INIT_ARRAY/FINI_ARRAY and we are linked statically,
 * we have to process these instead of relying on RTLD to do it for us.
 *
 * Since we don't need .init or .fini sections, just code them in C
 * to make life easier.
 */
extern const fptr_t __preinit_array_start[] __dso_hidden;
extern const fptr_t __preinit_array_end[] __dso_hidden __weak;
extern const fptr_t __init_array_start[] __dso_hidden;
extern const fptr_t __init_array_end[] __dso_hidden __weak;
extern const fptr_t __fini_array_start[] __dso_hidden;
extern const fptr_t __fini_array_end[] __dso_hidden __weak;

static inline void
_preinit(void)
{
	for (const fptr_t *f = __preinit_array_start; f < __preinit_array_end; f++) {
		(*f)();
	}
}

static inline void
_initarray(void)
{
	for (const fptr_t *f = __init_array_start; f < __init_array_end; f++) {
		(*f)();
	}
}

static void
_finiarray(void)
{
	for (const fptr_t *f = __fini_array_start; f < __fini_array_end; f++) {
		(*f)();
	}
}

#if \
    defined(__aarch64__) || \
    defined(__powerpc__) || \
    defined(__sparc__) || \
    defined(__x86_64__)
#define HAS_IPLTA
static void fix_iplta(void) __noinline;
#elif \
    defined(__arm__) || \
    defined(__i386__)
#define HAS_IPLT
static void fix_iplt(void) __noinline;
#endif


#ifdef HAS_IPLTA
#include <stdio.h>
extern const Elf_Rela __rela_iplt_start[] __dso_hidden __weak;
extern const Elf_Rela __rela_iplt_end[] __dso_hidden __weak;
#ifdef __sparc__
#define IFUNC_RELOCATION R_TYPE(JMP_IREL)
#include <machine/elf_support.h>
#define write_plt(where, value) sparc_write_branch((void *)where, (void *)value)
#else
#define IFUNC_RELOCATION R_TYPE(IRELATIVE)
#define write_plt(where, value) *where = value
#endif

static void
fix_iplta(void)
{
	const Elf_Rela *rela, *relalim;
	uintptr_t relocbase = 0;
	Elf_Addr *where, target;

	rela = __rela_iplt_start;
	relalim = __rela_iplt_end;
	for (; rela < relalim; ++rela) {
		if (ELF_R_TYPE(rela->r_info) != IFUNC_RELOCATION)
			abort();
		where = (Elf_Addr *)(relocbase + rela->r_offset);
		target = (Elf_Addr)(relocbase + rela->r_addend);
		target = ((Elf_Addr(*)(void))target)();
		write_plt(where, target);
	}
}
#endif
#ifdef HAS_IPLT
extern const Elf_Rel __rel_iplt_start[] __dso_hidden __weak;
extern const Elf_Rel __rel_iplt_end[] __dso_hidden __weak;
#define IFUNC_RELOCATION R_TYPE(IRELATIVE)

static void
fix_iplt(void)
{
	const Elf_Rel *rel, *rellim;
	uintptr_t relocbase = 0;
	Elf_Addr *where, target;

	rel = __rel_iplt_start;
	rellim = __rel_iplt_end;
	for (; rel < rellim; ++rel) {
		if (ELF_R_TYPE(rel->r_info) != IFUNC_RELOCATION)
			abort();
		where = (Elf_Addr *)(relocbase + rel->r_offset);
		target = ((Elf_Addr(*)(void))*where)();
		*where = target;
	}
}
#endif

#if defined(__x86_64__) || defined(__i386__)
#  define HAS_RELOCATE_SELF
#  if defined(__x86_64__)
#  define RELA
#  define REL_TAG DT_RELA
#  define RELSZ_TAG DT_RELASZ
#  define REL_TYPE Elf_Rela
#  else
#  define REL_TAG DT_REL
#  define RELSZ_TAG DT_RELSZ
#  define REL_TYPE Elf_Rel
#  endif

#include <elf.h>

static void relocate_self(struct ps_strings *) __noinline;

static void
relocate_self(struct ps_strings *ps_strings)
{
	AuxInfo *aux = (AuxInfo *)(ps_strings->ps_argvstr + ps_strings->ps_nargvstr +
	    ps_strings->ps_nenvstr + 2);
	uintptr_t relocbase = (uintptr_t)~0U;
	const Elf_Phdr *phdr = NULL;
	Elf_Half phnum = (Elf_Half)~0;

	for (; aux->a_type != AT_NULL; ++aux) {
		switch (aux->a_type) {
		case AT_BASE:
			if (aux->a_v)
				return;
			break;
		case AT_PHDR:
			phdr = (void *)aux->a_v;
			break;
		case AT_PHNUM:
			phnum = (Elf_Half)aux->a_v;
			break;
		}
	}

	if (phdr == NULL || phnum == (Elf_Half)~0)
		return;

	const Elf_Phdr *phlimit = phdr + phnum, *dynphdr = NULL;

	for (; phdr < phlimit; ++phdr) {
		if (phdr->p_type == PT_DYNAMIC)
			dynphdr = phdr;
		if (phdr->p_type == PT_PHDR)
			relocbase = (uintptr_t)phdr - phdr->p_vaddr;
	}
	if (dynphdr == NULL || relocbase == (uintptr_t)~0U)
		return;

	Elf_Dyn *dynp = (Elf_Dyn *)((uint8_t *)dynphdr->p_vaddr + relocbase);

	const REL_TYPE *relocs = 0, *relocslim;
	Elf_Addr relocssz = 0;

	for (; dynp->d_tag != DT_NULL; dynp++) {
		switch (dynp->d_tag) {
		case REL_TAG:
			relocs =
			    (const REL_TYPE *)(relocbase + dynp->d_un.d_ptr);
			break;
		case RELSZ_TAG:
			relocssz = dynp->d_un.d_val;
			break;
		}
	}
	relocslim = (const REL_TYPE *)((const uint8_t *)relocs + relocssz);
	for (; relocs < relocslim; ++relocs) {
		Elf_Addr *where;

		where = (Elf_Addr *)(relocbase + relocs->r_offset);

		switch (ELF_R_TYPE(relocs->r_info)) {
		case R_TYPE(RELATIVE):  /* word64 B + A */
#ifdef RELA
			*where = (Elf_Addr)(relocbase + relocs->r_addend);
#else
			*where += (Elf_Addr)relocbase;
#endif
			break;
#ifdef IFUNC_RELOCATION
		case IFUNC_RELOCATION:
			break;
#endif
		default:
			abort();
		}
	}
}
#endif

void
___start(void (*cleanup)(void),			/* from shared loader */
    struct ps_strings *ps_strings)
{
#if defined(HAS_RELOCATE_SELF)
	relocate_self(ps_strings);
#endif

	if (ps_strings == NULL)
		_FATAL("ps_strings missing\n");
	__ps_strings = ps_strings;

	environ = ps_strings->ps_envstr;

	if (ps_strings->ps_argvstr[0] != NULL) {
		char *c;
		__progname = ps_strings->ps_argvstr[0];
		for (c = ps_strings->ps_argvstr[0]; *c; ++c) {
			if (*c == '/')
				__progname = c + 1;
		}
	} else {
		__progname = empty_string;
	}

	if (cleanup != NULL)
		atexit(cleanup);

	_libc_init();

	if (&rtld_DYNAMIC == NULL) {
#ifdef HAS_IPLTA
		fix_iplta();
#endif
#ifdef HAS_IPLT
		fix_iplt();
#endif
	}

	_preinit();

#ifdef MCRT0
	atexit(_mcleanup);
	monstartup((u_long)&__eprol, (u_long)&__etext);
#endif

	atexit(_finiarray);
	_initarray();

#ifndef HAVE_INITFINI_ARRAY
	atexit(_fini);
	_init();
#endif

	exit(main(ps_strings->ps_nargvstr, ps_strings->ps_argvstr, environ));
}
