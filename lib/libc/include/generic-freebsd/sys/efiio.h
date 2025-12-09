/*-
 * Copyright (c) 2016 Netflix, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
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
 */

#ifndef	_SYS_EFIIO_H_
#define	_SYS_EFIIO_H_

#include <sys/ioccom.h>
#include <sys/uuid.h>
#include <sys/efi.h>

/*
 * The EFI world chose not to use the typical uuid_t defines for its global
 * universal identifiers. But the textual representation is the same, and we can
 * use the uuid_* routines to parse and print them. However, all EFI interfaces
 * for this need to be efi_guid_t so we can share code with EDK2, so the *_ioc
 * structures in this file are converted to _ioctl structure to transition to
 * this new requirement. This library is little used outside of FreeBSD and they
 * will be dropped in 16.
 */
_Static_assert(sizeof(struct uuid) == sizeof(efi_guid_t),
    "uuid_t and efi_guid_t are same bytes, but different elements");
#if __FreeBSD_version < 1600000 && !defined(_KERNEL)
#define _WANT_EFI_IOC
#endif

struct efi_get_table_ioctl
{
	void *buf;		/* Pointer to userspace buffer */
	efi_guid_t guid;	/* GUID to look up */
	size_t table_len;	/* Table size */
	size_t buf_len;		/* Size of the buffer */
};

struct efi_var_ioctl
{
	efi_char *name;		/* User pointer to name, in wide chars */
	size_t namesize;	/* Number of wide characters in name */
	efi_guid_t vendor;	/* Vendor's GUID for variable */
	uint32_t attrib;	/* Attributes */
	void *data;		/* User pointer to the data */
	size_t datasize;	/* Number of *bytes* in the data */
};

struct efi_waketime_ioctl
{
	struct efi_tm	waketime;
	uint8_t		enabled;
	uint8_t		pending;
};

#define EFIIOC_GET_TABLE	_IOWR('E',  1, struct efi_get_table_ioctl)
#define EFIIOC_GET_TIME		_IOR('E',   2, struct efi_tm)
#define EFIIOC_SET_TIME		_IOW('E',   3, struct efi_tm)
#define EFIIOC_VAR_GET		_IOWR('E',  4, struct efi_var_ioctl)
#define EFIIOC_VAR_NEXT		_IOWR('E',  5, struct efi_var_ioctl)
#define EFIIOC_VAR_SET		_IOWR('E',  6, struct efi_var_ioctl)
#define EFIIOC_GET_WAKETIME	_IOR('E',   7, struct efi_waketime_ioctl)
#define EFIIOC_SET_WAKETIME	_IOW('E',   8, struct efi_waketime_ioctl)

#ifdef _WANT_EFI_IOC
struct efi_get_table_ioc
{
	void *buf;		/* Pointer to userspace buffer */
	struct uuid uuid;	/* GUID to look up */
	size_t table_len;	/* Table size */
	size_t buf_len;		/* Size of the buffer */
};

struct efi_var_ioc
{
	efi_char *name;		/* User pointer to name, in wide chars */
	size_t namesize;	/* Number of wide characters in name */
	struct uuid vendor;	/* Vendor's GUID for variable */
	uint32_t attrib;	/* Attributes */
	void *data;		/* User pointer to the data */
	size_t datasize;	/* Number of *bytes* in the data */
};

_Static_assert(sizeof(struct efi_get_table_ioc) == sizeof(struct efi_get_table_ioctl),
    "Old and new struct table defines must be the same size");
_Static_assert(sizeof(struct efi_var_ioc) == sizeof(struct efi_var_ioctl),
    "Old and new struct var defines must be the same size");
#define efi_waketime_ioc efi_waketime_ioctl
#endif

#endif /* _SYS_EFIIO_H_ */