/*	$NetBSD: extattr.h,v 1.11 2021/06/19 13:56:34 christos Exp $	*/

/*-
 * Copyright (c) 1999-2001 Robert N. M. Watson
 * All rights reserved.
 *
 * This software was developed by Robert Watson for the TrustedBSD Project.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * FreeBSD: src/sys/sys/extattr.h,v 1.12 2003/06/04 04:04:24 rwatson Exp
 */

/*
 * Support for file system extended attributes.  Originally developed by
 * the TrustedBSD Project.  For a Linux-compatible interface to the same
 * subsystem, see <sys/xattr.h>.
 */

#ifndef _SYS_EXTATTR_H_
#define	_SYS_EXTATTR_H_

#include <sys/types.h>

#define	EXTATTR_NAMESPACE_EMPTY		0x00000000
#define	EXTATTR_NAMESPACE_EMPTY_STRING	"empty"
#define	EXTATTR_NAMESPACE_USER		0x00000001
#define	EXTATTR_NAMESPACE_USER_STRING	"user"
#define	EXTATTR_NAMESPACE_SYSTEM	0x00000002
#define	EXTATTR_NAMESPACE_SYSTEM_STRING	"system"

/*    
 * The following macro is designed to initialize an array that maps
 * extended-attribute namespace values to their names, e.g.:
 * 
 * char *extattr_namespace_names[] = EXTATTR_NAMESPACE_NAMES;
 */
#define	EXTATTR_NAMESPACE_NAMES { \
    EXTATTR_NAMESPACE_EMPTY_STRING, \
    EXTATTR_NAMESPACE_USER_STRING, \
    EXTATTR_NAMESPACE_SYSTEM_STRING, \
}

#define	EXTATTR_MAXNAMELEN	KERNEL_NAME_MAX

/* for sys_extattrctl */
#define EXTATTR_CMD_START		0x00000001
#define EXTATTR_CMD_STOP		0x00000002

#ifdef _KERNEL

#include <sys/param.h>

/* VOP_LISTEXTATTR flags */
#define EXTATTR_LIST_LENPREFIX	1	/* names with length prefix */

struct lwp;
struct vnode;
int	extattr_check_cred(struct vnode *, int, kauth_cred_t, int);

#else

#include <sys/cdefs.h>
__BEGIN_DECLS
int	extattrctl(const char *_path, int _cmd, const char *_filename,
	    int _attrnamespace, const char *_attrname);

int	extattr_delete_fd(int _fd, int _attrnamespace, const char *_attrname);
int	extattr_delete_file(const char *_path, int _attrnamespace,
	    const char *_attrname);
int	extattr_delete_link(const char *_path, int _attrnamespace,
	    const char *_attrname);
ssize_t	extattr_get_fd(int _fd, int _attrnamespace, const char *_attrname,
	    void *_data, size_t _nbytes);
ssize_t	extattr_get_file(const char *_path, int _attrnamespace,
	    const char *_attrname, void *_data, size_t _nbytes);
ssize_t	extattr_get_link(const char *_path, int _attrnamespace,
	    const char *_attrname, void *_data, size_t _nbytes);
ssize_t	extattr_list_fd(int _fd, int _attrnamespace, void *_data,
	    size_t _nbytes);
ssize_t	extattr_list_file(const char *_path, int _attrnamespace, void *_data,
	    size_t _nbytes);
ssize_t	extattr_list_link(const char *_path, int _attrnamespace, void *_data,
	    size_t _nbytes);
int	extattr_set_fd(int _fd, int _attrnamespace, const char *_attrname,
	    const void *_data, size_t _nbytes);
int	extattr_set_file(const char *_path, int _attrnamespace,
	    const char *_attrname, const void *_data, size_t _nbytes);
int	extattr_set_link(const char *_path, int _attrnamespace,
	    const char *_attrname, const void *_data, size_t _nbytes);

extern const int extattr_namespaces[];

int	extattr_namespace_to_string(int, char **);
int	extattr_string_to_namespace(const char *, int *);
int	extattr_copy_fd(int _from_fd, int _to_fd, int _namespace);
int	extattr_copy_file(const char *_from, const char *_to, int _namespace);
int	extattr_copy_link(const char *_from, const char *_to, int _namespace);

int	fcpxattr(int _from_fd, int _to_fd);
int	cpxattr(const char *_from, const char *_to);
int	lcpxattr(const char *_from, const char *_to);
__END_DECLS

#endif /* !_KERNEL */
#endif /* !_SYS_EXTATTR_H_ */