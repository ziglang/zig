/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2009 Rick Macklem, University of Guelph
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
 */

#ifndef _NFS_NFSV4ERRSTR_H_
#define	_NFS_NFSV4ERRSTR_H_

/*
 * Defines static storage in the C file, but I can't be bothered creating
 * a library of one function for this, since it is only currently used by
 * mount_newnfs.c.
 */
static const char *nfsv4_errstr[NFSERR_XATTR2BIG - 10000] = {
	"Illegal filehandle",
	"Undefined NFSv4 err",
	"READDIR cookie is stale",
	"operation not supported",
	"response limit exceeded",
	"undefined server error",
	"type invalid for CREATE",
	"file busy - retry",
	"nverify says attrs same",
	"lock unavailable",
	"lock lease expired",
	"I/O failed due to lock",
	"in grace period",
	"filehandle expired",
	"share reserve denied",
	"wrong security flavor",
	"clientid in use",
	"resource exhaustion",
	"filesystem relocated",
	"current FH is not set",
	"minor version not supported",
	"server has rebooted",
	"server has rebooted",
	"state is out of sync",
	"incorrect stateid",
	"request is out of seq",
	"verify - attrs not same",
	"lock range not supported",
	"should be file/directory",
	"no saved filehandle",
	"some filesystem moved",
	"recommended attr not sup",
	"reclaim outside of grace",
	"reclaim error at server",
	"conflict on reclaim",
	"XDR decode failed",
	"file locks held at CLOSE",
	"conflict in OPEN and I/O",
	"owner translation bad",
	"utf-8 char not supported",
	"name not supported",
	"lock range not supported",
	"no atomic up/downgrade",
	"undefined operation",
	"file locking deadlock",
	"open file blocks op",
	"lockowner state revoked",
	"callback path down",
	"bad IO mode",
	"bad layout",
	"bad session digest",
	"bad session",
	"bad slot",
	"complete already",
	"not bound to session",
	"delegation already wanted",
	"back channel busy",
	"layout try later",
	"layout unavailable",
	"no matching layout",
	"recall conflict",
	"unknown layout type",
	"sequence misordered",
	"sequence position",
	"request too big",
	"reply too big",
	"reply too big to cache",
	"retry uncached reply",
	"unsafe compound",
	"too many operations",
	"operation not in session",
	"hash algorithm unsupported",
	"unknown error",
	"clientID busy",
	"pNFS IO hole",
	"sequence false retry",
	"bad high slot",
	"dead session",
	"encrypt algorithm unsupported",
	"pNFS no layout",
	"not only operation",
	"wrong credential",
	"wrong type",
	"directory delegation unavailable",
	"reject delegation",
	"return conflict",
	"delegation revoked",
	"partner not supported",
	"partner no auth",
	"union not supported",
	"offload denied",
	"wrong LFS",
	"bad label",
	"offload no request",
	"no extended attribute",
	"extended attribute too big",
};

/*
 * Return the error string for the NFS4ERR_xxx. The pointers returned are
 * static and must not be free'd.
 */
static const char *
nfsv4_geterrstr(int errval)
{

	if (errval < NFSERR_BADHANDLE || errval > NFSERR_XATTR2BIG)
		return (NULL);
	return (nfsv4_errstr[errval - NFSERR_BADHANDLE]);
}

#endif	/* _NFS_NFSV4ERRSTR_H_ */