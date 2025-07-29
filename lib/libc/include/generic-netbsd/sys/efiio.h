/* $NetBSD: efiio.h,v 1.2.4.1 2023/08/01 16:05:12 martin Exp $ */

/*-
 * Copyright (c) 2021 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jared McNeill <jmcneill@invisible.ca>.
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

#ifndef _SYS_EFIIO_H
#define _SYS_EFIIO_H

#include <sys/types.h>
#include <sys/ioccom.h>
#include <sys/uuid.h>

/*
 * Variable attributes
 */
#define	EFI_VARIABLE_NON_VOLATILE				0x00000001
#define	EFI_VARIABLE_BOOTSERVICE_ACCESS				0x00000002
#define	EFI_VARIABLE_RUNTIME_ACCESS				0x00000004
#define	EFI_VARIABLE_HARDWARE_ERROR_RECORD			0x00000008
#define	EFI_VARIABLE_AUTHENTICATED_WRITE_ACCESS			0x00000010
#define	EFI_VARIABLE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS	0x00000020
#define	EFI_VARIABLE_APPEND_WRITE				0x00000040
#define	EFI_VARIABLE_ENHANCED_AUTHENTICATED_ACCESS		0x00000080

struct efi_get_table_ioc {
	void *		buf;
	struct uuid	uuid;
	size_t		table_len;
	size_t		buf_len;
};

struct efi_var_ioc {
	uint16_t *	name;		/* vendor's variable name */
	size_t		namesize;	/* size in bytes of the name buffer */
	struct uuid	vendor;		/* unique identifier for vendor */
	uint32_t	attrib;		/* variable attribute bitmask */
	void *		data;		/* buffer containing variable data */
	size_t		datasize;	/* size in bytes of the data buffer */
};

#define	EFIIOC_GET_TABLE	_IOWR('e', 1, struct efi_get_table_ioc)
#define	EFIIOC_VAR_GET		_IOWR('e', 4, struct efi_var_ioc)
#define	EFIIOC_VAR_NEXT		_IOWR('e', 5, struct efi_var_ioc)
#define	EFIIOC_VAR_SET		_IOWR('e', 7, struct efi_var_ioc)

#endif /* _SYS_EFIIO_H */