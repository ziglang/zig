/* $NetBSD: udf_mount.h,v 1.4 2019/10/16 21:52:22 maya Exp $ */

/*
 * Copyright (c) 2006 Reinoud Zandijk
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
 */


#ifndef _FS_UDF_UDF_MOUNT_H_
#define _FS_UDF_UDF_MOUNT_H_

/*
 * Arguments to mount UDF filingsystem.
 */

#define UDFMNT_VERSION	1
struct udf_args {
	uint32_t	 version;	/* version of this structure         */
	char		*fspec;		/* mount specifier                   */
	int32_t		 sessionnr;	/* session specifier, rel of abs     */
	uint32_t	 udfmflags;	/* mount options                     */
	int32_t		 gmtoff;	/* offset from UTC in seconds        */

	uid_t		 anon_uid;	/* mapping of anonymous files uid    */
	gid_t		 anon_gid;	/* mapping of anonymous files gid    */
	uid_t		 nobody_uid;	/* nobody:nobody will map to -1:-1   */
	gid_t		 nobody_gid;	/* nobody:nobody will map to -1:-1   */

	uint32_t	 sector_size;	/* for mounting dumps/files          */

	/* extendable */
	uint8_t	 reserved[32];
};


/* udf mount options */

#define UDFMNT_CLOSESESSION	0x00000001	/* close session on dismount */
#define UDFMNT_BITS "\20\1CLOSESESSION"

#endif /* !_FS_UDF_UDF_MOUNT_H_ */