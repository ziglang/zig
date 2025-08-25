/*	$NetBSD: link_elf.h,v 1.13 2020/09/22 01:52:16 kamil Exp $	*/

#ifndef _LINK_ELF_H_
#define	_LINK_ELF_H_

#include <sys/types.h>
#include <sys/exec_elf.h>

#define R_DEBUG_VERSION	1 /* SVR4 Protocol version */

typedef struct link_map {
	caddr_t		 l_addr;	/* Base Address of library */
#ifdef __mips__
	caddr_t		 l_offs;	/* Load Offset of library */
#endif
	const char	*l_name;	/* Absolute Path to Library */
	void		*l_ld;		/* Pointer to .dynamic in memory */
	struct link_map	*l_next;	/* linked list of mapped libs */
	struct link_map *l_prev;
} Link_map;

/*
 * Debug rendezvous struct. Pointer to this is set up in the
 * target code pointed by the DT_DEBUG tag. If it is
 * defined.
 */
struct r_debug {
	int r_version;			/* protocol version */
	struct link_map *r_map;		/* list of loaded images */

	/*
	 * This is the address of a function internal to the run-time linker,
	 * that will always be called when the linker begins to map in a
	 * library or unmap it, and again when the mapping change is complete.
	 * The debugger can set a breakpoint at this address if it wants to
	 * notice shared object mapping changes.
	 */
	void (*r_brk)(void);		/* pointer to break point */
	enum {
		/*
		 * This state value describes the mapping change taking place
		 * when the `r_brk' address is called.
		 */
		RT_CONSISTENT,		/* things are stable */
		RT_ADD,			/* adding a shared library */
		RT_DELETE		/* removing a shared library */
	} r_state;
	void *r_ldbase;			/* base address of RTLD */
};

struct dl_phdr_info
{
	Elf_Addr dlpi_addr;			/* module relocation base */
	const char *dlpi_name;			/* module name */
	const Elf_Phdr *dlpi_phdr;		/* pointer to module's phdr */
	Elf_Half dlpi_phnum;			/* number of entries in phdr */
	unsigned long long int dlpi_adds;	/* total # of loads */
	unsigned long long int dlpi_subs;	/* total # of unloads */
	size_t dlpi_tls_modid;
	void *dlpi_tls_data;
};

__BEGIN_DECLS

int dl_iterate_phdr(int (*)(struct dl_phdr_info *, size_t, void *),
    void *);

__END_DECLS

#endif	/* _LINK_ELF_H_ */