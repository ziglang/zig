#include <stddef.h>
#include "dynlink.h"
#include "libc.h"

#ifndef START
#define START "_dlstart"
#endif

#define SHARED

#include "crt_arch.h"

#ifndef GETFUNCSYM
#define GETFUNCSYM(fp, sym, got) do { \
	hidden void sym(); \
	static void (*static_func_ptr)() = sym; \
	__asm__ __volatile__ ( "" : "+m"(static_func_ptr) : : "memory"); \
	*(fp) = static_func_ptr; } while(0)
#endif

hidden void _dlstart_c(size_t *sp, size_t *dynv)
{
	size_t i, aux[AUX_CNT], dyn[DYN_CNT];
	size_t *rel, rel_size, base;

	int argc = *sp;
	char **argv = (void *)(sp+1);

	for (i=argc+1; argv[i]; i++);
	size_t *auxv = (void *)(argv+i+1);

	for (i=0; i<AUX_CNT; i++) aux[i] = 0;
	for (i=0; auxv[i]; i+=2) if (auxv[i]<AUX_CNT)
		aux[auxv[i]] = auxv[i+1];

#if DL_FDPIC
	struct fdpic_loadseg *segs, fakeseg;
	size_t j;
	if (dynv) {
		/* crt_arch.h entry point asm is responsible for reserving
		 * space and moving the extra fdpic arguments to the stack
		 * vector where they are easily accessible from C. */
		segs = ((struct fdpic_loadmap *)(sp[-1] ? sp[-1] : sp[-2]))->segs;
	} else {
		/* If dynv is null, the entry point was started from loader
		 * that is not fdpic-aware. We can assume normal fixed-
		 * displacement ELF loading was performed, but when ldso was
		 * run as a command, finding the Ehdr is a heursitic: we
		 * have to assume Phdrs start in the first 4k of the file. */
		base = aux[AT_BASE];
		if (!base) base = aux[AT_PHDR] & -4096;
		segs = &fakeseg;
		segs[0].addr = base;
		segs[0].p_vaddr = 0;
		segs[0].p_memsz = -1;
		Ehdr *eh = (void *)base;
		Phdr *ph = (void *)(base + eh->e_phoff);
		size_t phnum = eh->e_phnum;
		size_t phent = eh->e_phentsize;
		while (phnum-- && ph->p_type != PT_DYNAMIC)
			ph = (void *)((size_t)ph + phent);
		dynv = (void *)(base + ph->p_vaddr);
	}
#endif

	for (i=0; i<DYN_CNT; i++) dyn[i] = 0;
	for (i=0; dynv[i]; i+=2) if (dynv[i]<DYN_CNT)
		dyn[dynv[i]] = dynv[i+1];

#if DL_FDPIC
	for (i=0; i<DYN_CNT; i++) {
		if (i==DT_RELASZ || i==DT_RELSZ) continue;
		if (!dyn[i]) continue;
		for (j=0; dyn[i]-segs[j].p_vaddr >= segs[j].p_memsz; j++);
		dyn[i] += segs[j].addr - segs[j].p_vaddr;
	}
	base = 0;

	const Sym *syms = (void *)dyn[DT_SYMTAB];

	rel = (void *)dyn[DT_RELA];
	rel_size = dyn[DT_RELASZ];
	for (; rel_size; rel+=3, rel_size-=3*sizeof(size_t)) {
		if (!IS_RELATIVE(rel[1], syms)) continue;
		for (j=0; rel[0]-segs[j].p_vaddr >= segs[j].p_memsz; j++);
		size_t *rel_addr = (void *)
			(rel[0] + segs[j].addr - segs[j].p_vaddr);
		if (R_TYPE(rel[1]) == REL_FUNCDESC_VAL) {
			*rel_addr += segs[rel_addr[1]].addr
				- segs[rel_addr[1]].p_vaddr
				+ syms[R_SYM(rel[1])].st_value;
			rel_addr[1] = dyn[DT_PLTGOT];
		} else {
			size_t val = syms[R_SYM(rel[1])].st_value;
			for (j=0; val-segs[j].p_vaddr >= segs[j].p_memsz; j++);
			*rel_addr = rel[2] + segs[j].addr - segs[j].p_vaddr + val;
		}
	}
#else
	/* If the dynamic linker is invoked as a command, its load
	 * address is not available in the aux vector. Instead, compute
	 * the load address as the difference between &_DYNAMIC and the
	 * virtual address in the PT_DYNAMIC program header. */
	base = aux[AT_BASE];
	if (!base) {
		size_t phnum = aux[AT_PHNUM];
		size_t phentsize = aux[AT_PHENT];
		Phdr *ph = (void *)aux[AT_PHDR];
		for (i=phnum; i--; ph = (void *)((char *)ph + phentsize)) {
			if (ph->p_type == PT_DYNAMIC) {
				base = (size_t)dynv - ph->p_vaddr;
				break;
			}
		}
	}

	/* MIPS uses an ugly packed form for GOT relocations. Since we
	 * can't make function calls yet and the code is tiny anyway,
	 * it's simply inlined here. */
	if (NEED_MIPS_GOT_RELOCS) {
		size_t local_cnt = 0;
		size_t *got = (void *)(base + dyn[DT_PLTGOT]);
		for (i=0; dynv[i]; i+=2) if (dynv[i]==DT_MIPS_LOCAL_GOTNO)
			local_cnt = dynv[i+1];
		for (i=0; i<local_cnt; i++) got[i] += base;
	}

	rel = (void *)(base+dyn[DT_REL]);
	rel_size = dyn[DT_RELSZ];
	for (; rel_size; rel+=2, rel_size-=2*sizeof(size_t)) {
		if (!IS_RELATIVE(rel[1], 0)) continue;
		size_t *rel_addr = (void *)(base + rel[0]);
		*rel_addr += base;
	}

	rel = (void *)(base+dyn[DT_RELA]);
	rel_size = dyn[DT_RELASZ];
	for (; rel_size; rel+=3, rel_size-=3*sizeof(size_t)) {
		if (!IS_RELATIVE(rel[1], 0)) continue;
		size_t *rel_addr = (void *)(base + rel[0]);
		*rel_addr = base + rel[2];
	}
#endif

	stage2_func dls2;
	GETFUNCSYM(&dls2, __dls2, base+dyn[DT_PLTGOT]);
	dls2((void *)base, sp);
}
