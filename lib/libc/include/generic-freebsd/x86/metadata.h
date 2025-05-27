/*-
 * Copyright (c) 2003 Peter Wemm <peter@FreeBSD.org>
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

#ifndef _MACHINE_METADATA_H_
#define	_MACHINE_METADATA_H_

#define	MODINFOMD_SMAP		0x1001
#define	MODINFOMD_SMAP_XATTR	0x1002
#define	MODINFOMD_DTBP		0x1003
#define	MODINFOMD_EFI_MAP	0x1004
#define	MODINFOMD_EFI_FB	0x1005
#define	MODINFOMD_MODULEP	0x1006
#define	MODINFOMD_VBE_FB	0x1007

struct efi_map_header {
	uint64_t	memory_size;
	uint64_t	descriptor_size;
	uint32_t	descriptor_version;
};

struct efi_fb {
	uint64_t	fb_addr;
	uint64_t	fb_size;
	uint32_t	fb_height;
	uint32_t	fb_width;
	uint32_t	fb_stride;
	uint32_t	fb_mask_red;
	uint32_t	fb_mask_green;
	uint32_t	fb_mask_blue;
	uint32_t	fb_mask_reserved;
};

struct vbe_fb {
	uint64_t	fb_addr;
	uint64_t	fb_size;
	uint32_t	fb_height;
	uint32_t	fb_width;
	uint32_t	fb_stride;
	uint32_t	fb_mask_red;
	uint32_t	fb_mask_green;
	uint32_t	fb_mask_blue;
	uint32_t	fb_mask_reserved;
	uint32_t	fb_bpp;
};

/*
 * The structure below is used when FreeBSD kernel is booted as a dom0 kernel
 * from Xen. In such scenario we need to accommodate the modules and the
 * metadata as a contiguous memory region, so it can be passed as a multiboot
 * module, and some extra information is required which is conveyed from the
 * loader to the kernel using the xen_header structure below.
 *
 * See the comment in multiboot.c about how the structure below is packaged
 * together with the rest of the kernel payload data.
 */
struct xen_header {
	uint64_t	flags;
#define XENHEADER_HAS_MODULEP_OFFSET (1ull << 0)

	/*
	 * Offset of the modulep location from the start of the multiboot
	 * module blob.
	 */
	uint64_t	modulep_offset;
};

#endif /* !_MACHINE_METADATA_H_ */