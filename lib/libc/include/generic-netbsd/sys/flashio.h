/*	$NetBSD: flashio.h,v 1.5 2021/09/16 20:17:48 andvar Exp $	*/

/*-
 * Copyright (c) 2011 Department of Software Engineering,
 *		      University of Szeged, Hungary
 * Copyright (c) 2011 Adam Hoka <ahoka@NetBSD.org>
 * Copyright (c) 2010 David Tengeri <dtengeri@inf.u-szeged.hu>
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by the Department of Software Engineering, University of Szeged, Hungary
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
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _FLASHIO_H_
#define _FLASHIO_H_

#include <sys/ioctl.h>

/* this header may be used from the kernel */
#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/types.h>
#else
#include <stdint.h>
#include <stdbool.h>
#endif

enum {
	FLASH_ERASE_DONE 	= 0x0,
	FLASH_ERASE_FAILED	= 0x1
};

enum {
	FLASH_TYPE_UNKNOWN	= 0x0,
	FLASH_TYPE_NOR		= 0x1,
	FLASH_TYPE_NAND		= 0x2
};

/* public userspace API */

/* common integer type to address flash */
typedef int64_t flash_off_t;
typedef uint64_t flash_size_t;
typedef uint64_t flash_addr_t;

/**
 * struct erase_params - for ioctl erase call
 * @addr: start address of the erase
 * @len: length of the erase
 */
struct flash_erase_params {
	flash_off_t ep_addr;
	flash_off_t ep_len;
};

struct flash_badblock_params {
	flash_off_t bbp_addr;
	bool bbp_isbad;
};

struct flash_info_params {
	flash_off_t ip_flash_size;
	flash_size_t ip_page_size;
	flash_size_t ip_erase_size;
	uint8_t ip_flash_type;
};

struct flash_dump_params {
	flash_off_t dp_block;
	flash_off_t dp_len;
	uint8_t *dp_buf;
};

enum {
	FLASH_IOCTL_ERASE_BLOCK,
	FLASH_IOCTL_DUMP,
	FLASH_IOCTL_GET_INFO,
	FLASH_IOCTL_BLOCK_ISBAD,
	FLASH_IOCTL_BLOCK_MARKBAD
};

#define FLASH_ERASE_BLOCK 	\
	_IOW('&', FLASH_IOCTL_ERASE_BLOCK, struct flash_erase_params)

#define FLASH_DUMP		\
	_IOWR('&', FLASH_IOCTL_DUMP, struct flash_dump_params)

#define FLASH_GET_INFO		\
	_IOWR('&', FLASH_IOCTL_GET_INFO, struct flash_info_params)

#define FLASH_BLOCK_ISBAD 	\
	_IOWR('&', FLASH_IOCTL_BLOCK_ISBAD, struct flash_badblock_params)

#define FLASH_BLOCK_MARKBAD	\
	_IOW('&', FLASH_IOCTL_BLOCK_MARKBAD, struct flash_badblock_params)

#endif