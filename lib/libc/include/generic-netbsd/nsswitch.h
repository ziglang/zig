/*	$NetBSD: nsswitch.h,v 1.23 2016/01/23 01:26:14 dholland Exp $	*/

/*-
 * Copyright (c) 1997, 1998, 1999, 2004 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Luke Mewburn.
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

#ifndef _NSSWITCH_H
#define _NSSWITCH_H	1

#include <sys/types.h>
#include <stdarg.h>

#define	NSS_MODULE_INTERFACE_VERSION	0

#ifndef _PATH_NS_CONF
#define _PATH_NS_CONF	"/etc/nsswitch.conf"
#endif

#define	NS_CONTINUE	0
#define	NS_RETURN	1

/*
 * Layout of:
 *	uint32_t ns_src.flags
 */ 
	/* nsswitch.conf status codes and nsdispatch(3) return values */
#define	NS_SUCCESS	(1<<0)		/* entry was found */
#define	NS_UNAVAIL	(1<<1)		/* source not responding, or corrupt */
#define	NS_NOTFOUND	(1<<2)		/* source responded 'no such entry' */
#define	NS_TRYAGAIN	(1<<3)		/* source busy, may respond to retrys */
#define	NS_STATUSMASK	0x000000ff	/* bitmask to get the status flags */

	/* internal nsdispatch(3) flags; not settable in nsswitch.conf(5)  */
#define	NS_FORCEALL	(1<<8)		/* force all methods to be invoked; */

/*
 * Currently implemented sources.
 */
#define NSSRC_FILES	"files"		/* local files */
#define	NSSRC_DNS	"dns"		/* DNS; IN for hosts, HS for others */
#define	NSSRC_NIS	"nis"		/* YP/NIS */
#define	NSSRC_COMPAT	"compat"	/* passwd,group in YP compat mode */

/*
 * Currently implemented databases.
 */
#define NSDB_HOSTS		"hosts"
#define NSDB_GROUP		"group"
#define NSDB_GROUP_COMPAT	"group_compat"
#define NSDB_NETGROUP		"netgroup"
#define NSDB_NETWORKS		"networks"
#define NSDB_PASSWD		"passwd"
#define NSDB_PASSWD_COMPAT	"passwd_compat"
#define NSDB_SHELLS		"shells"

/*
 * Suggested databases to implement.
 */
#define NSDB_ALIASES		"aliases"
#define NSDB_AUTH		"auth"
#define NSDB_AUTOMOUNT		"automount"
#define NSDB_BOOTPARAMS		"bootparams"
#define NSDB_ETHERS		"ethers"
#define NSDB_EXPORTS		"exports"
#define NSDB_NETMASKS		"netmasks"
#define NSDB_PHONES		"phones"
#define NSDB_PRINTCAP		"printcap"
#define NSDB_PROTOCOLS		"protocols"
#define NSDB_REMOTE		"remote"
#define NSDB_RPC		"rpc"
#define NSDB_SENDMAILVARS	"sendmailvars"
#define NSDB_SERVICES		"services"
#define NSDB_TERMCAP		"termcap"
#define NSDB_TTYS		"ttys"

/*
 * ns_dtab `callback' function signature.
 */
typedef	int (*nss_method)(void *, void *, va_list);

/*
 * ns_dtab - `nsswitch dispatch table'
 * Contains an entry for each source and the appropriate function to call.
 */
typedef struct {
	const char	 *src;
	nss_method	 callback;
	void		 *cb_data;
} ns_dtab;

/*
 * Macros to help build an ns_dtab[]
 */
#define NS_FILES_CB(F,C)	{ NSSRC_FILES,	F,	__UNCONST(C) },
#define NS_COMPAT_CB(F,C)	{ NSSRC_COMPAT,	F,	__UNCONST(C) },
 
#ifdef HESIOD
#   define NS_DNS_CB(F,C)	{ NSSRC_DNS,	F,	__UNCONST(C) },
#else
#   define NS_DNS_CB(F,C)
#endif

#ifdef YP
#   define NS_NIS_CB(F,C)	{ NSSRC_NIS,	F,	__UNCONST(C) },
#else
#   define NS_NIS_CB(F,C)
#endif
#define	NS_NULL_CB		{ .src = NULL },

/*
 * ns_src - `nsswitch source'
 * Used by the nsparser routines to store a mapping between a source
 * and its dispatch control flags for a given database.
 */
typedef struct {
	const char	*name;
	uint32_t	 flags;
} ns_src;


/*
 * Default sourcelists (if nsswitch.conf is missing, corrupt,
 * or the requested database doesn't have an entry)
 */
extern const ns_src __nsdefaultsrc[];
extern const ns_src __nsdefaultcompat[];
extern const ns_src __nsdefaultcompat_forceall[];
extern const ns_src __nsdefaultfiles[];
extern const ns_src __nsdefaultfiles_forceall[];
extern const ns_src __nsdefaultnis[];
extern const ns_src __nsdefaultnis_forceall[];


/*
 * ns_mtab - `nsswitch method table'
 * An nsswitch module provides a mapping from (database name, method name)
 * tuples to the nss_method and associated callback data.  Effectively,
 * ns_dtab, but used for dynamically loaded modules.
 */
typedef struct {
	const char	*database;
	const char	*name;
	nss_method	 method;
	void		*mdata;
} ns_mtab;

/*
 * nss_module_register_fn - module registration function
 *	called at module load
 * nss_module_unregister_fn - module un-registration function
 *	called at module unload
 */
typedef	void (*nss_module_unregister_fn)(ns_mtab *, unsigned int);
typedef	ns_mtab *(*nss_module_register_fn)(const char *, unsigned int *,
					   nss_module_unregister_fn *);

#ifdef _NS_PRIVATE

/*
 * Private data structures for back-end nsswitch implementation.
 */

/*
 * ns_dbt - `nsswitch database thang'
 * For each database in /etc/nsswitch.conf there is a ns_dbt, with its
 * name and a list of ns_src's containing the source information.
 */
typedef struct {
	const char	*name;		/* name of database */
	ns_src		*srclist;	/* list of sources */
	unsigned int	 srclistsize;	/* size of srclist */
} ns_dbt;

/*
 * ns_mod - `nsswitch module'
 */
typedef struct {
	const char	*name;		/* module name */
	void		*handle;	/* handle from dlopen() */
	ns_mtab		*mtab;		/* method table */
	unsigned int	 mtabsize;	/* size of mtab */
					/* called to unload module */
	nss_module_unregister_fn unregister;
} ns_mod;

#endif /* _NS_PRIVATE */


#include <sys/cdefs.h>

__BEGIN_DECLS
int	nsdispatch(void *, const ns_dtab [], const char *,
			const char *, const ns_src [], ...);

#ifdef _NS_PRIVATE
int		 _nsdbtaddsrc(ns_dbt *, const ns_src *);
void		 _nsdbtdump(const ns_dbt *);
int		 _nsdbtput(const ns_dbt *);
void		 _nsyyerror(const char *);
int		 _nsyylex(void);
#endif /* _NS_PRIVATE */

__END_DECLS

#endif /* !_NSSWITCH_H */