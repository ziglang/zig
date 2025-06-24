/* $NetBSD: device.h,v 1.185 2022/08/24 11:19:25 riastradh Exp $ */

/*
 * Copyright (c) 2021 The NetBSD Foundation, Inc.
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

/*
 * Copyright (c) 1996, 2000 Christopher G. Demetriou
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
 * --(license Id: LICENSE.proto,v 1.1 2000/06/13 21:40:26 cgd Exp )--
 */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratories.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)device.h	8.2 (Berkeley) 2/17/94
 */

#ifndef _SYS_DEVICE_H_
#define	_SYS_DEVICE_H_

#include <sys/device_if.h>
#include <sys/evcnt.h>
#include <sys/queue.h>

#if defined(_KERNEL) || defined(_KMEMUSER)
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/pmf.h>
#endif

#include <prop/proplib.h>

/*
 * Minimal device structures.
 * Note that all ``system'' device types are listed here.
 */
typedef enum devclass {
	DV_DULL,		/* generic, no special info */
	DV_CPU,			/* CPU (carries resource utilization) */
	DV_DISK,		/* disk drive (label, etc) */
	DV_IFNET,		/* network interface */
	DV_TAPE,		/* tape device */
	DV_TTY,			/* serial line interface (?) */
	DV_AUDIODEV,		/* audio device */
	DV_DISPLAYDEV,		/* display device */
	DV_BUS,			/* bus device */
	DV_VIRTUAL,		/* unbacked virtual device */
} devclass_t;

/*
 * Actions for ca_activate.
 */
typedef enum devact {
	DVACT_DEACTIVATE	/* deactivate the device */
} devact_t;

typedef enum {
	DVA_SYSTEM,
	DVA_HARDWARE
} devactive_t;

typedef struct cfdata *cfdata_t;
typedef struct cfdriver *cfdriver_t;
typedef struct cfattach *cfattach_t;

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_STANDALONE)
/*
 * devhandle_t --
 *
 *	This is an abstraction of the device handles used by ACPI,
 *	OpenFirmware, and others, to support device enumeration and
 *	device tree linkage.  A devhandle_t can be safely passed
 *	by value.
 */
struct devhandle {
	const struct devhandle_impl *	impl;
	union {
		/*
		 * Storage for the device handle.  Which storage field
		 * is used is at the sole discretion of the type
		 * implementation.
		 */
		void *			pointer;
		const void *		const_pointer;
		uintptr_t		uintptr;
		intptr_t		integer;
	};
};
typedef struct devhandle devhandle_t;
#endif

#if defined(_KERNEL) || defined(_KMEMUSER) 
struct device_compatible_entry {
	union {
		const char *compat;
		uintptr_t id;
	};
	union {
		const void *data;
		uintptr_t value;
	};
};

#define	DEVICE_COMPAT_EOL	{ .compat = NULL }

struct device_suspensor {
	const device_suspensor_t	*ds_delegator;
	char				ds_name[32];
};

struct device_garbage {
	device_t	*dg_devs;
	int		dg_ndevs;
};


typedef enum {
	/* Used to represent invalid states. */
	DEVHANDLE_TYPE_INVALID		=	0,

	/* ACPI */
	DEVHANDLE_TYPE_ACPI		=	0x41435049,	/* 'ACPI' */

	/* OpenFirmware, FDT */
	DEVHANDLE_TYPE_OF		=	0x4f504657,	/* 'OPFW' */

	/* Sun OpenBoot */
	DEVHANDLE_TYPE_OPENBOOT		=	0x4f504254,	/* 'OPBT' */

	/* Private (opaque data) */
	DEVHANDLE_TYPE_PRIVATE		=	0x50525654,	/* 'PRVT' */

	/* Max value. */
	DEVHANDLE_TYPE_MAX		=	0xffffffff
} devhandle_type_t;

/* Device method call function signature. */
typedef int (*device_call_t)(device_t, devhandle_t, void *);

struct device_call_descriptor {
	const char *name;
	device_call_t call;
};

#define	_DEVICE_CALL_REGISTER(_g_, _c_)					\
	__link_set_add_rodata(_g_, __CONCAT(_c_,_descriptor));
#define	DEVICE_CALL_REGISTER(_g_, _n_, _c_)				\
static const struct device_call_descriptor __CONCAT(_c_,_descriptor) = {\
	.name = (_n_), .call = (_c_)					\
};									\
_DEVICE_CALL_REGISTER(_g_, _c_)

struct devhandle_impl {
	devhandle_type_t		type;
	const struct devhandle_impl *	super;
	device_call_t			(*lookup_device_call)(devhandle_t,
					    const char *, devhandle_t *);
};

/* Max size of a device external name (including terminating NUL) */
#define	DEVICE_XNAME_SIZE	16

struct device;

/*
 * struct cfattach::ca_flags (must not overlap with device_impl.h
 * struct device::dv_flags for now)
 */
#define	DVF_PRIV_ALLOC		0x0002	/* device private storage != device */
#define	DVF_DETACH_SHUTDOWN	0x0080	/* device detaches safely at shutdown */

#ifdef _KERNEL
TAILQ_HEAD(devicelist, device);
#endif

enum deviter_flags {
	  DEVITER_F_RW =		0x1
	, DEVITER_F_SHUTDOWN =		0x2
	, DEVITER_F_LEAVES_FIRST =	0x4
	, DEVITER_F_ROOT_FIRST =	0x8
};

typedef enum deviter_flags deviter_flags_t;

struct deviter {
	device_t	di_prev;
	deviter_flags_t	di_flags;
	int		di_curdepth;
	int		di_maxdepth;
	devgen_t	di_gen;
};

typedef struct deviter deviter_t;

struct shutdown_state {
	bool initialized;
	deviter_t di;
};
#endif

/*
 * Description of a locator, as part of interface attribute definitions.
 */
struct cflocdesc {
	const char *cld_name;
	const char *cld_defaultstr; /* NULL if no default */
	int cld_default;
};

/*
 * Description of an interface attribute, provided by potential
 * parent device drivers, referred to by child device configuration data.
 */
struct cfiattrdata {
	const char *ci_name;
	int ci_loclen;
	const struct cflocdesc ci_locdesc[
#if defined(__GNUC__) && __GNUC__ <= 2
		0
#endif
	];
};

/*
 * Description of a configuration parent.  Each device attachment attaches
 * to an "interface attribute", which is given in this structure.  The parent
 * *must* carry this attribute.  Optionally, an individual device instance
 * may also specify a specific parent device instance.
 */
struct cfparent {
	const char *cfp_iattr;		/* interface attribute */
	const char *cfp_parent;		/* optional specific parent */
	int cfp_unit;			/* optional specific unit
					   (DVUNIT_ANY to wildcard) */
};

/*
 * Configuration data (i.e., data placed in ioconf.c).
 */
struct cfdata {
	const char *cf_name;		/* driver name */
	const char *cf_atname;		/* attachment name */
	unsigned int cf_unit:24;	/* unit number */
	unsigned char cf_fstate;	/* finding state (below) */
	int	*cf_loc;		/* locators (machine dependent) */
	int	cf_flags;		/* flags from config */
	const struct cfparent *cf_pspec;/* parent specification */
};
#define FSTATE_NOTFOUND		0	/* has not been found */
#define	FSTATE_FOUND		1	/* has been found */
#define	FSTATE_STAR		2	/* duplicable */
#define FSTATE_DSTAR		3	/* has not been found, and disabled */
#define FSTATE_DNOTFOUND	4	/* duplicate, and disabled */

/*
 * Multiple configuration data tables may be maintained.  This structure
 * provides the linkage.
 */
struct cftable {
	cfdata_t	ct_cfdata;	/* pointer to cfdata table */
	TAILQ_ENTRY(cftable) ct_list;	/* list linkage */
};
#ifdef _KERNEL
TAILQ_HEAD(cftablelist, cftable);
#endif

typedef int (*cfsubmatch_t)(device_t, cfdata_t, const int *, void *);
typedef int (*cfsearch_t)(device_t, cfdata_t, const int *, void *);

/*
 * `configuration' attachment and driver (what the machine-independent
 * autoconf uses).  As devices are found, they are applied against all
 * the potential matches.  The one with the best match is taken, and a
 * device structure (plus any other data desired) is allocated.  Pointers
 * to these are placed into an array of pointers.  The array itself must
 * be dynamic since devices can be found long after the machine is up
 * and running.
 *
 * Devices can have multiple configuration attachments if they attach
 * to different attributes (busses, or whatever), to allow specification
 * of multiple match and attach functions.  There is only one configuration
 * driver per driver, so that things like unit numbers and the device
 * structure array will be shared.
 */
struct cfattach {
	const char *ca_name;		/* name of attachment */
	LIST_ENTRY(cfattach) ca_list;	/* link on cfdriver's list */
	size_t	  ca_devsize;		/* size of dev data (for alloc) */
	int	  ca_flags;		/* flags for driver allocation etc */
	int	(*ca_match)(device_t, cfdata_t, void *);
	void	(*ca_attach)(device_t, device_t, void *);
	int	(*ca_detach)(device_t, int);
	int	(*ca_activate)(device_t, devact_t);
	/* technically, the next 2 belong into "struct cfdriver" */
	int	(*ca_rescan)(device_t, const char *,
			     const int *); /* scan for new children */
	void	(*ca_childdetached)(device_t, device_t);
};
LIST_HEAD(cfattachlist, cfattach);

#define	CFATTACH_DECL3_NEW(name, ddsize, matfn, attfn, detfn, actfn, \
	rescanfn, chdetfn, __flags) \
struct cfattach __CONCAT(name,_ca) = {					\
	.ca_name		= ___STRING(name),			\
	.ca_devsize		= ddsize,				\
	.ca_flags		= (__flags) | DVF_PRIV_ALLOC,		\
	.ca_match 		= matfn,				\
	.ca_attach		= attfn,				\
	.ca_detach		= detfn,				\
	.ca_activate		= actfn,				\
	.ca_rescan		= rescanfn,				\
	.ca_childdetached	= chdetfn,				\
}

#define	CFATTACH_DECL2_NEW(name, ddsize, matfn, attfn, detfn, actfn,	\
	rescanfn, chdetfn)						\
	CFATTACH_DECL3_NEW(name, ddsize, matfn, attfn, detfn, actfn,	\
	    rescanfn, chdetfn, 0)

#define	CFATTACH_DECL_NEW(name, ddsize, matfn, attfn, detfn, actfn)	\
	CFATTACH_DECL2_NEW(name, ddsize, matfn, attfn, detfn, actfn, NULL, NULL)

/* Flags given to config_detach(), and the ca_detach function. */
#define	DETACH_FORCE	0x01		/* force detachment; hardware gone */
#define	DETACH_QUIET	0x02		/* don't print a notice */
#define	DETACH_SHUTDOWN	0x04		/* detach because of system shutdown */
#define	DETACH_POWEROFF	0x08		/* going to power off; power down devices */

struct cfdriver {
	LIST_ENTRY(cfdriver) cd_list;	/* link on allcfdrivers */
	struct cfattachlist cd_attach;	/* list of all attachments */
	device_t *cd_devs;		/* devices found */
	const char *cd_name;		/* device name */
	enum	devclass cd_class;	/* device classification */
	int	cd_ndevs;		/* size of cd_devs array */
	const struct cfiattrdata * const *cd_attrs; /* attributes provided */
};
LIST_HEAD(cfdriverlist, cfdriver);

#define	CFDRIVER_DECL(name, class, attrs)				\
struct cfdriver __CONCAT(name,_cd) = {					\
	.cd_name		= ___STRING(name),			\
	.cd_class		= class,				\
	.cd_attrs		= attrs,				\
}

/*
 * The cfattachinit is a data structure used to associate a list of
 * cfattach's with cfdrivers as found in the static kernel configuration.
 */
struct cfattachinit {
	const char *cfai_name;		 /* driver name */
	struct cfattach * const *cfai_list;/* list of attachments */
};
/*
 * the same, but with a non-constant list so it can be modified
 * for module bookkeeping
 */
struct cfattachlkminit {
	const char *cfai_name;		/* driver name */
	struct cfattach **cfai_list;	/* list of attachments */
};

/*
 * Configuration printing functions, and their return codes.  The second
 * argument is NULL if the device was configured; otherwise it is the name
 * of the parent device.  The return value is ignored if the device was
 * configured, so most functions can return UNCONF unconditionally.
 */
typedef int (*cfprint_t)(void *, const char *);		/* XXX const char * */
#define	QUIET	0		/* print nothing */
#define	UNCONF	1		/* print " not configured\n" */
#define	UNSUPP	2		/* print " not supported\n" */

/*
 * Pseudo-device attach information (function + number of pseudo-devs).
 */
struct pdevinit {
	void	(*pdev_attach)(int);
	int	pdev_count;
};

/* This allows us to wildcard a device unit. */
#define	DVUNIT_ANY	-1

#if defined(_KERNEL) || defined(_KMEMUSER) || defined(_STANDALONE)
/*
 * Arguments passed to config_search() and config_found().
 */
struct cfargs {
	uintptr_t	cfargs_version;	/* version field */

	/* version 1 fields */
	cfsubmatch_t	submatch;	/* submatch function (direct config) */
	cfsearch_t	search;		/* search function (indirect config) */
	const char *	iattr;		/* interface attribute */
	const int *	locators;	/* locators array */
	devhandle_t	devhandle;	/* devhandle_t (by value) */

	/* version 2 fields below here */
};

#define	CFARGS_VERSION		1	/* current cfargs version */

#define	CFARGS_NONE		NULL	/* no cfargs to pass */

/*
 * Construct a cfargs with this macro, like so:
 *
 *	CFARGS(.submatch = config_stdsubmatch,
 *	       .devhandle = my_devhandle)
 *
 * You must supply at least one field.  If you don't need any, use the
 * CFARGS_NONE macro.
 */
#define	CFARGS(...)							\
	&((const struct cfargs){					\
		.cfargs_version = CFARGS_VERSION,			\
		__VA_ARGS__						\
	})
#endif /* _KERNEL || _KMEMUSER || _STANDALONE */

#ifdef _KERNEL

extern struct cfdriverlist allcfdrivers;/* list of all cfdrivers */
extern struct cftablelist allcftables;	/* list of all cfdata tables */
extern device_t booted_device;		/* the device we booted from */
extern const char *booted_method;	/* the method the device was found */
extern int booted_partition;		/* the partition on that device */
extern daddr_t booted_startblk;		/* or the start of a wedge */
extern uint64_t booted_nblks;		/* and the size of that wedge */
extern char *bootspec;			/* and the device/wedge name */
extern bool root_is_mounted;		/* true if root is mounted */

struct vnode *opendisk(device_t);
int getdisksize(struct vnode *, uint64_t *, unsigned int *);
struct dkwedge_info;
int getdiskinfo(struct vnode *, struct dkwedge_info *);

void	config_init(void);
int	config_init_component(struct cfdriver *const*,
			      const struct cfattachinit *, struct cfdata *);
int	config_fini_component(struct cfdriver *const*,
			      const struct cfattachinit *, struct cfdata *);
void	config_init_mi(void);
void	drvctl_init(void);
void	drvctl_fini(void);
extern	int (*devmon_insert_vec)(const char *, prop_dictionary_t);

int	config_cfdriver_attach(struct cfdriver *);
int	config_cfdriver_detach(struct cfdriver *);

int	config_cfattach_attach(const char *, struct cfattach *);
int	config_cfattach_detach(const char *, struct cfattach *);

int	config_cfdata_attach(cfdata_t, int);
int	config_cfdata_detach(cfdata_t);

struct cfdriver *config_cfdriver_lookup(const char *);
struct cfattach *config_cfattach_lookup(const char *, const char *);
const struct cfiattrdata *cfiattr_lookup(const char *, const struct cfdriver *);

const char *cfdata_ifattr(const struct cfdata *);

int	config_stdsubmatch(device_t, cfdata_t, const int *, void *);
cfdata_t config_search(device_t, void *, const struct cfargs *);
cfdata_t config_rootsearch(cfsubmatch_t, const char *, void *);
device_t config_found(device_t, void *, cfprint_t, const struct cfargs *);
device_t config_rootfound(const char *, void *);
device_t config_attach(device_t, cfdata_t, void *, cfprint_t,
	    const struct cfargs *);
int	config_match(device_t, cfdata_t, void *);
int	config_probe(device_t, cfdata_t, void *);

bool	ifattr_match(const char *, const char *);

device_t config_attach_pseudo(cfdata_t);

int	config_detach(device_t, int);
int	config_detach_children(device_t, int flags);
void	config_detach_commit(device_t);
bool	config_detach_all(int);
int	config_deactivate(device_t);
void	config_defer(device_t, void (*)(device_t));
void	config_deferred(device_t);
void	config_interrupts(device_t, void (*)(device_t));
void	config_mountroot(device_t, void (*)(device_t));
void	config_pending_incr(device_t);
void	config_pending_decr(device_t);
void	config_create_interruptthreads(void);
void	config_create_mountrootthreads(void);

int	config_finalize_register(device_t, int (*)(device_t));
void	config_finalize(void);
void	config_finalize_mountroot(void);

void	config_twiddle_init(void);
void	config_twiddle_fn(void *);

void	null_childdetached(device_t, device_t);

device_t	device_lookup(cfdriver_t, int);
void		*device_lookup_private(cfdriver_t, int);

device_t	device_lookup_acquire(cfdriver_t, int);
void		device_release(device_t);

void		device_register(device_t, void *);
void		device_register_post_config(device_t, void *);

devclass_t	device_class(device_t);
cfdata_t	device_cfdata(device_t);
cfdriver_t	device_cfdriver(device_t);
cfattach_t	device_cfattach(device_t);
int		device_unit(device_t);
const char	*device_xname(device_t);
device_t	device_parent(device_t);
bool		device_is_active(device_t);
bool		device_activation(device_t, devact_level_t);
bool		device_is_enabled(device_t);
bool		device_has_power(device_t);
int		device_locator(device_t, u_int);
void		*device_private(device_t);
void		device_set_private(device_t, void *);
prop_dictionary_t device_properties(device_t);
void		device_set_handle(device_t, devhandle_t);
devhandle_t	device_handle(device_t);

bool		devhandle_is_valid(devhandle_t);
devhandle_t	devhandle_invalid(void);
devhandle_type_t devhandle_type(devhandle_t);
int		devhandle_compare(devhandle_t, devhandle_t);

device_call_t	devhandle_lookup_device_call(devhandle_t, const char *,
		    devhandle_t *);
void		devhandle_impl_inherit(struct devhandle_impl *,
		    const struct devhandle_impl *);

device_t	deviter_first(deviter_t *, deviter_flags_t);
void		deviter_init(deviter_t *, deviter_flags_t);
device_t	deviter_next(deviter_t *);
void		deviter_release(deviter_t *);

bool		device_active(device_t, devactive_t);
bool		device_active_register(device_t,
				       void (*)(device_t, devactive_t));
void		device_active_deregister(device_t,
				         void (*)(device_t, devactive_t));

bool		device_is_a(device_t, const char *);
bool		device_attached_to_iattr(device_t, const char *);

device_t	device_find_by_xname(const char *);
device_t	device_find_by_driver_unit(const char *, int);

int		device_enumerate_children(device_t,
		    bool (*)(device_t, devhandle_t, void *), void *);

int		device_compatible_match(const char **, int,
				const struct device_compatible_entry *);
int		device_compatible_pmatch(const char **, int,
				const struct device_compatible_entry *);
const struct device_compatible_entry *
		device_compatible_lookup(const char **, int,
				const struct device_compatible_entry *);
const struct device_compatible_entry *
		device_compatible_plookup(const char **, int,
				const struct device_compatible_entry *);

int		device_compatible_match_strlist(const char *, size_t,
				const struct device_compatible_entry *);
int		device_compatible_pmatch_strlist(const char *, size_t,
				const struct device_compatible_entry *);
const struct device_compatible_entry *
		device_compatible_lookup_strlist(const char *, size_t,
				const struct device_compatible_entry *);
const struct device_compatible_entry *
		device_compatible_plookup_strlist(const char *, size_t,
				const struct device_compatible_entry *);

int		device_compatible_match_id(uintptr_t const, uintptr_t const,
				const struct device_compatible_entry *);
const struct device_compatible_entry *
		device_compatible_lookup_id(uintptr_t const, uintptr_t const,
				const struct device_compatible_entry *);

void		device_pmf_driver_child_register(device_t);
void		device_pmf_driver_set_child_register(device_t,
		    void (*)(device_t));

void		*device_pmf_bus_private(device_t);
bool		device_pmf_bus_suspend(device_t, const pmf_qual_t *);
bool		device_pmf_bus_resume(device_t, const pmf_qual_t *);
bool		device_pmf_bus_shutdown(device_t, int);

void		device_pmf_bus_register(device_t, void *,
		    bool (*)(device_t, const pmf_qual_t *),
		    bool (*)(device_t, const pmf_qual_t *),
		    bool (*)(device_t, int),
		    void (*)(device_t));
void		device_pmf_bus_deregister(device_t);

device_t	shutdown_first(struct shutdown_state *);
device_t	shutdown_next(struct shutdown_state *);

/*
 * device calls --
 *
 * This provides a generic mechanism for invoking special methods on
 * devices, often dependent on the device tree implementation used
 * by the platform.
 *
 * While individual subsystems may define their own device calls,
 * the ones prefixed with "device-" are reserved, and defined by
 * the device autoconfiguration subsystem.  It is the responsibility
 * of each device tree back end to implement these calls.
 *
 * We define a generic interface; individual device calls feature
 * type checking of the argument structure.  The argument structures
 * and the call binding data are automatically generated from device
 * call interface descriptions by gendevcalls.awk.
 */
struct device_call_generic {
	const char *name;
	void *args;
};

int	device_call_generic(device_t, const struct device_call_generic *);

#define	device_call(dev, call)						\
	device_call_generic((dev), &(call)->generic)

#endif /* _KERNEL */

#endif /* !_SYS_DEVICE_H_ */