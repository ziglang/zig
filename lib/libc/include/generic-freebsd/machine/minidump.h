/*-
 * Copyright (c) 2006 Peter Wemm
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
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
 * From i386: FreeBSD:  157909 2006-04-21 04:28:43Z peter
 */

#ifndef	_MACHINE_MINIDUMP_H_
#define	_MACHINE_MINIDUMP_H_ 1

#define	MINIDUMP_MAGIC		"minidump FreeBSD/powerpc64"
#define	MINIDUMP_VERSION	2

struct minidumphdr {
	char magic[32];
	char mmu_name[32];
	uint32_t version;
	uint32_t msgbufsize;
	uint32_t bitmapsize;
	uint32_t pmapsize;
	uint64_t kernbase;
	uint64_t kernend;
	uint64_t dmapbase;
	uint64_t dmapend;
	int hw_direct_map;
	uint64_t startkernel;
	uint64_t endkernel;
	uint32_t dumpavailsize;
};

#endif /* _MACHINE_MINIDUMP_H_ */