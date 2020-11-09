/*
 * Copyright (c) 2004-2019 Apple, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
#ifndef _COPYFILE_H_ /* version 0.1 */
#define _COPYFILE_H_

/*
 * This API facilitates the copying of files and their associated
 * metadata.  There are several open source projects that need
 * modifications to support preserving extended attributes and ACLs
 * and this API collapses several hundred lines of modifications into
 * one or two calls.
 */

/* private */
#include <sys/cdefs.h>
#include <stdint.h>

__BEGIN_DECLS
struct _copyfile_state;
typedef struct _copyfile_state * copyfile_state_t;
typedef uint32_t copyfile_flags_t;

/* public */

/* receives:
 *   from	path to source file system object
 *   to		path to destination file system object
 *   state	opaque blob for future extensibility
 *		Must be NULL in current implementation
 *   flags	(described below)
 * returns:
 *   int	negative for error
 */

int copyfile(const char *from, const char *to, copyfile_state_t state, copyfile_flags_t flags);
int fcopyfile(int from_fd, int to_fd, copyfile_state_t, copyfile_flags_t flags);

int copyfile_state_free(copyfile_state_t);
copyfile_state_t copyfile_state_alloc(void);


int copyfile_state_get(copyfile_state_t s, uint32_t flag, void * dst);
int copyfile_state_set(copyfile_state_t s, uint32_t flag, const void * src);

typedef int (*copyfile_callback_t)(int, int, copyfile_state_t, const char *, const char *, void *);

#define COPYFILE_STATE_SRC_FD		1
#define COPYFILE_STATE_SRC_FILENAME	2
#define COPYFILE_STATE_DST_FD		3
#define COPYFILE_STATE_DST_FILENAME	4
#define COPYFILE_STATE_QUARANTINE	5
#define	COPYFILE_STATE_STATUS_CB	6
#define	COPYFILE_STATE_STATUS_CTX	7
#define	COPYFILE_STATE_COPIED		8
#define	COPYFILE_STATE_XATTRNAME	9
#define	COPYFILE_STATE_WAS_CLONED	10


#define	COPYFILE_DISABLE_VAR	"COPYFILE_DISABLE"

/* flags for copyfile */

#define COPYFILE_ACL	    (1<<0)
#define COPYFILE_STAT	    (1<<1)
#define COPYFILE_XATTR	    (1<<2)
#define COPYFILE_DATA	    (1<<3)

#define COPYFILE_SECURITY   (COPYFILE_STAT | COPYFILE_ACL)
#define COPYFILE_METADATA   (COPYFILE_SECURITY | COPYFILE_XATTR)
#define COPYFILE_ALL	    (COPYFILE_METADATA | COPYFILE_DATA)

#define	COPYFILE_RECURSIVE	(1<<15)	/* Descend into hierarchies */
#define COPYFILE_CHECK		(1<<16) /* return flags for xattr or acls if set */
#define COPYFILE_EXCL		(1<<17) /* fail if destination exists */
#define COPYFILE_NOFOLLOW_SRC	(1<<18) /* don't follow if source is a symlink */
#define COPYFILE_NOFOLLOW_DST	(1<<19) /* don't follow if dst is a symlink */
#define COPYFILE_MOVE		(1<<20) /* unlink src after copy */
#define COPYFILE_UNLINK		(1<<21) /* unlink dst before copy */
#define COPYFILE_NOFOLLOW	(COPYFILE_NOFOLLOW_SRC | COPYFILE_NOFOLLOW_DST)

#define COPYFILE_PACK		(1<<22)
#define COPYFILE_UNPACK		(1<<23)

#define COPYFILE_CLONE		(1<<24)
#define COPYFILE_CLONE_FORCE	(1<<25)

#define COPYFILE_RUN_IN_PLACE	(1<<26)

#define COPYFILE_DATA_SPARSE	(1<<27)

#define COPYFILE_PRESERVE_DST_TRACKED	(1<<28)

#define COPYFILE_VERBOSE	(1<<30)

#define	COPYFILE_RECURSE_ERROR	0
#define	COPYFILE_RECURSE_FILE	1
#define	COPYFILE_RECURSE_DIR	2
#define	COPYFILE_RECURSE_DIR_CLEANUP	3
#define	COPYFILE_COPY_DATA	4
#define	COPYFILE_COPY_XATTR	5

#define	COPYFILE_START		1
#define	COPYFILE_FINISH		2
#define	COPYFILE_ERR		3
#define	COPYFILE_PROGRESS	4

#define	COPYFILE_CONTINUE	0
#define	COPYFILE_SKIP	1
#define	COPYFILE_QUIT	2

__END_DECLS

#endif /* _COPYFILE_H_ */
