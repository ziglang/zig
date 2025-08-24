/*	$NetBSD: module.h,v 1.48 2021/10/24 06:52:26 skrll Exp $	*/

/*-
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_MODULE_H_
#define _SYS_MODULE_H_

#include <sys/types.h>
#include <sys/param.h>
#include <sys/cdefs.h>
#include <sys/uio.h>

#define	MAXMODNAME	32
#define	MAXMODDEPS	10

/* Module classes, provided only for system boot and module validation. */
typedef enum modclass {
	MODULE_CLASS_ANY,
	MODULE_CLASS_MISC,
	MODULE_CLASS_VFS,
	MODULE_CLASS_DRIVER,
	MODULE_CLASS_EXEC,
	MODULE_CLASS_SECMODEL,
	MODULE_CLASS_BUFQ,
	MODULE_CLASS_MAX
} modclass_t;

/* Module sources: where did it come from? */
typedef enum modsrc {
	MODULE_SOURCE_KERNEL,
	MODULE_SOURCE_BOOT,
	MODULE_SOURCE_FILESYS
} modsrc_t;

/* Commands passed to module control routine. */
typedef enum modcmd {
	MODULE_CMD_INIT,		/* mandatory */
	MODULE_CMD_FINI,		/* mandatory */
	MODULE_CMD_STAT,		/* optional */
	MODULE_CMD_AUTOUNLOAD,		/* optional */
} modcmd_t;

#ifdef _KERNEL

#include <sys/kernel.h>
#include <sys/mutex.h>
#include <sys/queue.h>
#include <sys/specificdata.h>

#include <prop/proplib.h>

/* Module header structure. */
typedef struct modinfo {
	u_int			mi_version;
	modclass_t		mi_class;
	int			(*mi_modcmd)(modcmd_t, void *);
	const char		*mi_name;
	const char		*mi_required;
} const modinfo_t;

/* Per module information, maintained by kern_module.c */

struct sysctllog;

typedef struct module {
	u_int			mod_refcnt;
	int			mod_flags;
#define MODFLG_MUST_FORCE	0x01
#define MODFLG_AUTO_LOADED	0x02
	const modinfo_t		*mod_info;
	struct kobj		*mod_kobj;
	TAILQ_ENTRY(module)	mod_chain;
	struct module		*(*mod_required)[MAXMODDEPS];
	u_int			mod_nrequired;
	u_int			mod_arequired;
	modsrc_t		mod_source;
	time_t			mod_autotime;
	specificdata_reference	mod_sdref;
	struct sysctllog	*mod_sysctllog;
} module_t;

/*
 * Per-module linkage.  Loadable modules have a `link_set_modules' section
 * containing only one entry, pointing to the module's modinfo_t record.
 * For the kernel, `link_set_modules' can contain multiple entries and
 * records all modules built into the kernel at link time.
 *
 * Alternatively, in some environments rump kernels use
 * __attribute__((constructor)) due to link sets being
 * difficult (impossible?) to implement (e.g. GNU gold, OS X, etc.)
 * If we're cold (read: rump_init() has not been called), we lob the
 * module onto the list to be handled when rump_init() runs.
 * nb. it's not possible to use in-kernel locking mechanisms here since
 * the code runs before rump_init().  We solve the problem by decreeing
 * that thou shalt not call dlopen()/dlclose() for rump kernel components
 * from multiple threads before calling rump_init().
 */

#ifdef RUMP_USE_CTOR
struct modinfo_chain {
	const struct modinfo	*mc_info;
	LIST_ENTRY(modinfo_chain) mc_entries;
};
LIST_HEAD(modinfo_boot_chain, modinfo_chain);
#define _MODULE_REGISTER(name)						\
static struct modinfo_chain __CONCAT(mc,name) = {			\
	.mc_info = &__CONCAT(name,_modinfo),				\
};									\
static void __CONCAT(modctor_,name)(void) __attribute__((__constructor__));\
static void __CONCAT(modctor_,name)(void)				\
{									\
	extern struct modinfo_boot_chain modinfo_boot_chain;		\
	if (cold) {							\
		struct modinfo_chain *mc = &__CONCAT(mc,name);		\
		LIST_INSERT_HEAD(&modinfo_boot_chain, mc, mc_entries);	\
	}								\
}									\
									\
static void __CONCAT(moddtor_,name)(void) __attribute__((__destructor__));\
static void __CONCAT(moddtor_,name)(void)				\
{									\
	struct modinfo_chain *mc = &__CONCAT(mc,name);			\
	if (cold) {							\
		LIST_REMOVE(mc, mc_entries);				\
	}								\
}

#else /* RUMP_USE_CTOR */

#define _MODULE_REGISTER(name) __link_set_add_rodata(modules, __CONCAT(name,_modinfo));

#endif /* RUMP_USE_CTOR */

#define	MODULE(class, name, required)				\
static int __CONCAT(name,_modcmd)(modcmd_t, void *);		\
static const modinfo_t __CONCAT(name,_modinfo) = {		\
	.mi_version = __NetBSD_Version__,			\
	.mi_class = (class),					\
	.mi_modcmd = __CONCAT(name,_modcmd),			\
	.mi_name = __STRING(name),				\
	.mi_required = (required)				\
}; 								\
_MODULE_REGISTER(name)

TAILQ_HEAD(modlist, module);

extern struct vm_map	*module_map;
extern u_int		module_count;
extern u_int		module_builtinlist;
extern struct modlist	module_list;
extern struct modlist	module_builtins;
extern u_int		module_gen;

void	module_init(void);
void	module_start_unload_thread(void);
void	module_builtin_require_force(void);
void	module_init_md(void);
void	module_init_class(modclass_t);
int	module_prime(const char *, void *, size_t);

module_t *module_kernel(void);
const char *module_name(struct module *);
modsrc_t module_source(struct module *);
bool	module_compatible(int, int);
int	module_load(const char *, int, prop_dictionary_t, modclass_t);
int	module_builtin_add(modinfo_t * const *, size_t, bool);
int	module_builtin_remove(modinfo_t *, bool);
int	module_autoload(const char *, modclass_t);
int	module_unload(const char *);
void	module_hold(module_t *);
void	module_rele(module_t *);
int	module_find_section(const char *, void **, size_t *);
void	module_thread_kick(void);
void	module_load_vfs_init(void);

specificdata_key_t module_specific_key_create(specificdata_key_t *, specificdata_dtor_t);
void	module_specific_key_delete(specificdata_key_t);
void	*module_getspecific(module_t *, specificdata_key_t);
void	module_setspecific(module_t *, specificdata_key_t, void *);
void	*module_register_callbacks(void (*)(struct module *),
				  void (*)(struct module *));
void	module_unregister_callbacks(void *);

void	module_whatis(uintptr_t, void (*)(const char *, ...)
    __printflike(1, 2));
void	module_print_list(void (*)(const char *, ...) __printflike(1, 2));

#ifdef _MODULE_INTERNAL
extern
int	(*module_load_vfs_vec)(const char *, int, bool, module_t *,
			       prop_dictionary_t *);
int	module_load_vfs(const char *, int, bool, module_t *,
			prop_dictionary_t *);
void	module_error(const char *, ...) __printflike(1, 2);
void	module_print(const char *, ...) __printflike(1, 2);
#endif /* _MODULE_INTERNAL */

#define MODULE_BASE_SIZE 64
extern char	module_base[MODULE_BASE_SIZE];
extern const char	*module_machine;

struct netbsd32_modctl_args;
extern int compat32_80_modctl_compat_stub(struct lwp *,
    const struct netbsd32_modctl_args *, register_t *);

#else	/* _KERNEL */

#include <stdint.h>

#endif	/* _KERNEL */

typedef struct modctl_load {
	const char *ml_filename;

#define MODCTL_NO_PROP		0x2
#define MODCTL_LOAD_FORCE	0x1
	int ml_flags;

	const char *ml_props;
	size_t ml_propslen;
} modctl_load_t;

enum modctl {
	MODCTL_LOAD,		/* modctl_load_t *ml */
	MODCTL_UNLOAD,		/* char *name */
	MODCTL_OSTAT,		/* struct iovec *buffer */
	MODCTL_EXISTS,		/* enum: 0: load, 1: autoload */
	MODCTL_STAT		/* struct iovec *buffer */
};

/*
 * This structure is used with the newer version of MODCTL_STAT, which
 * exports strings of arbitrary length for the list of required modules.
 */
typedef struct modstat {
	char		ms_name[MAXMODNAME];
	uint64_t	ms_addr;
	modsrc_t	ms_source;
	modclass_t	ms_class;
	u_int		ms_size;
	u_int		ms_refcnt;
	u_int		ms_flags;
	u_int		ms_reqoffset;	/* offset to module's required list
					   from beginning of iovec buffer! */
} modstat_t;

int	modctl(int, void *);

#ifdef _KERNEL
/* attention: pointers passed are userland pointers!,
   see modctl_load_t */
int	handle_modctl_load(const char *, int, const char *, size_t);
#endif

#endif	/* !_SYS_MODULE_H_ */