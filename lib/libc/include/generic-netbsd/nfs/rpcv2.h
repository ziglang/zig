/*	$NetBSD: rpcv2.h,v 1.12 2006/12/28 00:39:03 yamt Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Rick Macklem at The University of Guelph.
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
 *	@(#)rpcv2.h	8.2 (Berkeley) 3/30/95
 */


#ifndef _NFS_RPCV2_H_
#define _NFS_RPCV2_H_

/*
 * Definitions for Sun RPC Version 2, from
 * "RPC: Remote Procedure Call Protocol Specification" RFC1057
 */

/* Version # */
#define	RPC_VER2	2

/* Authentication */
#define	RPCAUTH_NULL	0
#define	RPCAUTH_UNIX	1
#define	RPCAUTH_SHORT	2
#define RPCAUTH_KERB4	4
#define	RPCAUTH_MAXSIZ	400
#define	RPCVERF_MAXSIZ	12	/* For Kerb, can actually be 400 */
#define	RPCAUTH_UNIXGIDS 16

/*
 * Constants associated with authentication flavours.
 */
#define RPCAKN_FULLNAME	0
#define RPCAKN_NICKNAME	1

/* Rpc Constants */
#define	RPC_CALL	0
#define	RPC_REPLY	1
#define	RPC_MSGACCEPTED	0
#define	RPC_MSGDENIED	1
#define	RPC_PROGUNAVAIL	1
#define	RPC_PROGMISMATCH	2
#define	RPC_PROCUNAVAIL	3
#define	RPC_GARBAGE	4		/* I like this one */
#define	RPC_MISMATCH	0
#define	RPC_AUTHERR	1

/* Authentication failures */
#define	AUTH_BADCRED	1
#define	AUTH_REJECTCRED	2
#define	AUTH_BADVERF	3
#define	AUTH_REJECTVERF	4
#define	AUTH_TOOWEAK	5		/* Give em wheaties */

/* Sizes of rpc header parts */
#define	RPC_SIZ		24
#define	RPC_REPLYSIZ	28

/* RPC Prog definitions */
#define	RPCPROG_MNT	100005
#define	RPCMNT_VER1	1
#define	RPCMNT_VER3	3
#define	RPCMNT_MOUNT	1
#define	RPCMNT_DUMP	2
#define	RPCMNT_UMOUNT	3
#define	RPCMNT_UMNTALL	4
#define	RPCMNT_EXPORT	5
#define	RPCMNT_NAMELEN	255
#define	RPCMNT_PATHLEN	1024
#define	RPCPROG_NFS	100003

/* Structs for common parts of the rpc's */
struct rpcv2_time {
	u_int32_t rpc_sec;
	u_int32_t rpc_usec;
};

/*
 * Structures used for RPCAUTH_KERB4.
 */
struct nfsrpc_fullverf {
	u_int32_t t1;
	u_int32_t t2;
	u_int32_t w2;
};

struct nfsrpc_fullblock {
	u_int32_t t1;
	u_int32_t t2;
	u_int32_t w1;
	u_int32_t w2;
};

struct nfsrpc_nickverf {
	u_int32_t kind;
	struct nfsrpc_fullverf	verf;
};

/*
 * and their sizes in bytes.. If sizeof (struct nfsrpc_xx) != these
 * constants, well then things will break in mount_nfs and nfsd.
 */
#define RPCX_FULLVERF	12
#define RPCX_FULLBLOCK	16
#define RPCX_NICKVERF	16

#ifdef NFSKERB
XXX
#else
typedef u_char			NFSKERBKEY_T[2];
typedef u_char			NFSKERBKEYSCHED_T[2];
#endif
#define NFS_KERBSRV	"rcmd"		/* Kerberos Service for NFS */
#define NFS_KERBTTL	(30 * 60)	/* Credential ttl (sec) */
#define NFS_KERBCLOCKSKEW (5 * 60)	/* Clock skew (sec) */
#define NFS_KERBW1(t)	(*((u_long *)(&((t).dat[((t).length + 3) & ~0x3]))))
#endif