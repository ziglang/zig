/*	$NetBSD: multiboot.h,v 1.11 2019/10/18 01:38:28 manu Exp $	*/

/*-
 * Copyright (c) 2005, 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Julio M. Merino Vidal.
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

/* --------------------------------------------------------------------- */

/*
 * Multiboot header structure.
 */
#define MULTIBOOT_HEADER_MAGIC		0x1BADB002
#define MULTIBOOT_HEADER_MODS_ALIGNED	0x00000001
#define MULTIBOOT_HEADER_WANT_MEMORY	0x00000002
#define MULTIBOOT_HEADER_HAS_VBE	0x00000004
#define MULTIBOOT_HEADER_HAS_ADDR	0x00010000

#if defined(_LOCORE)
#define MULTIBOOT2_HEADER_MAGIC		0xe85250d6
#define MULTIBOOT2_BOOTLOADER_MAGIC	0x36d76289
#define MULTIBOOT2_ARCHITECTURE_I386	0
#endif

#if !defined(_LOCORE)
struct multiboot_header {
	uint32_t	mh_magic;
	uint32_t	mh_flags;
	uint32_t	mh_checksum;

	/* Valid if mh_flags sets MULTIBOOT_HEADER_HAS_ADDR. */
	paddr_t		mh_header_addr;
	paddr_t		mh_load_addr;
	paddr_t		mh_load_end_addr;
	paddr_t		mh_bss_end_addr;
	paddr_t		mh_entry_addr;

	/* Valid if mh_flags sets MULTIBOOT_HEADER_HAS_VBE. */
	uint32_t	mh_mode_type;
	uint32_t	mh_width;
	uint32_t	mh_height;
	uint32_t	mh_depth;
};
#endif /* !defined(_LOCORE) */

/*
 * Symbols defined in locore.S.
 */
#if !defined(_LOCORE) && defined(_KERNEL)
extern struct multiboot_header *Multiboot_Header;
#endif /* !defined(_LOCORE) && defined(_KERNEL) */

/* --------------------------------------------------------------------- */

/*
 * Multiboot information structure.
 */
#define MULTIBOOT_INFO_MAGIC		0x2BADB002
#define MULTIBOOT_INFO_HAS_MEMORY	0x00000001
#define MULTIBOOT_INFO_HAS_BOOT_DEVICE	0x00000002
#define MULTIBOOT_INFO_HAS_CMDLINE	0x00000004
#define MULTIBOOT_INFO_HAS_MODS		0x00000008
#define MULTIBOOT_INFO_HAS_AOUT_SYMS	0x00000010
#define MULTIBOOT_INFO_HAS_ELF_SYMS	0x00000020
#define MULTIBOOT_INFO_HAS_MMAP		0x00000040
#define MULTIBOOT_INFO_HAS_DRIVES	0x00000080
#define MULTIBOOT_INFO_HAS_CONFIG_TABLE	0x00000100
#define MULTIBOOT_INFO_HAS_LOADER_NAME	0x00000200
#define MULTIBOOT_INFO_HAS_APM_TABLE	0x00000400
#define MULTIBOOT_INFO_HAS_VBE		0x00000800
#define MULTIBOOT_INFO_HAS_FRAMEBUFFER	0x00001000

#if !defined(_LOCORE)
struct multiboot_info {
	uint32_t	mi_flags;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_MEMORY. */
	uint32_t	mi_mem_lower;
	uint32_t	mi_mem_upper;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_BOOT_DEVICE. */
	uint8_t		mi_boot_device_part3;
	uint8_t		mi_boot_device_part2;
	uint8_t		mi_boot_device_part1;
	uint8_t		mi_boot_device_drive;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_CMDLINE. */
	char *		mi_cmdline;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_MODS. */
	uint32_t	mi_mods_count;
	vaddr_t		mi_mods_addr;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_{AOUT,ELF}_SYMS. */
	uint32_t	mi_elfshdr_num;
	uint32_t	mi_elfshdr_size;
	vaddr_t		mi_elfshdr_addr;
	uint32_t	mi_elfshdr_shndx;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_MMAP. */
	uint32_t	mi_mmap_length;
	vaddr_t		mi_mmap_addr;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_DRIVES. */
	uint32_t	mi_drives_length;
	vaddr_t		mi_drives_addr;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_CONFIG_TABLE. */
	void *		unused_mi_config_table;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_LOADER_NAME. */
	char *		mi_loader_name;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_APM. */
	void *		unused_mi_apm_table;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_VBE. */
	void *		unused_mi_vbe_control_info;
	void *		unused_mi_vbe_mode_info;
	uint16_t	unused_mi_vbe_mode;
	uint16_t	unused_mi_vbe_interface_seg;
	uint16_t	unused_mi_vbe_interface_off;
	uint16_t	unused_mi_vbe_interface_len;

	/* Valid if mi_flags sets MULTIBOOT_INFO_HAS_FRAMEBUFFER. */
	uint64_t	framebuffer_addr;
	uint32_t	framebuffer_pitch;
	uint32_t	framebuffer_width;
	uint32_t	framebuffer_height;
	uint8_t		framebuffer_bpp;
#define MULTIBOOT_FRAMEBUFFER_TYPE_INDEXED 	0
#define MULTIBOOT_FRAMEBUFFER_TYPE_RGB     	1
#define MULTIBOOT_FRAMEBUFFER_TYPE_EGA_TEXT     2
	uint8_t framebuffer_type;
	union {
		struct {
			uint32_t framebuffer_palette_addr;
			uint16_t framebuffer_palette_num_colors;
		};
		struct {
			uint8_t framebuffer_red_field_position;
			uint8_t framebuffer_red_mask_size;
			uint8_t framebuffer_green_field_position;
			uint8_t framebuffer_green_mask_size;
			uint8_t framebuffer_blue_field_position;
			uint8_t framebuffer_blue_mask_size;
		};
	};

};

/* --------------------------------------------------------------------- */

/*
 * Drive information.  This describes an entry in the drives table as
 * pointed to by mi_drives_addr.
 */
struct multiboot_drive {
	uint32_t	md_length;
	uint8_t		md_number;
	uint8_t		md_mode;
	uint16_t	md_cylinders;
	uint8_t		md_heads;
	uint8_t		md_sectors;

	/* The variable-sized 'ports' field comes here, so this structure
	 * can be longer. */
};

/* --------------------------------------------------------------------- */

/*
 * Memory mapping.  This describes an entry in the memory mappings table
 * as pointed to by mi_mmap_addr.
 *
 * Be aware that mm_size specifies the size of all other fields *except*
 * for mm_size.  In order to jump between two different entries, you
 * have to count mm_size + 4 bytes.
 */
struct multiboot_mmap {
	uint32_t	mm_size;
	uint64_t	mm_base_addr;
	uint64_t	mm_length;
	uint32_t	mm_type;
};

/*
 * Modules. This describes an entry in the modules table as pointed
 * to by mi_mods_addr.
 */

struct multiboot_module {
	uint32_t	mmo_start;
	uint32_t	mmo_end;
	char *		mmo_string;
	uint32_t	mmo_reserved;
};

#endif /* !defined(_LOCORE) */

/* --------------------------------------------------------------------- */

/*
 * Prototypes for public functions defined in multiboot.c and multiboot2.c
 */
#if !defined(_LOCORE) && defined(_KERNEL)
void		multiboot1_pre_reloc(struct multiboot_info *);
void		multiboot1_post_reloc(void);
void		multiboot1_print_info(void);
bool		multiboot1_ksyms_addsyms_elf(void);

void		multiboot2_pre_reloc(struct multiboot_info *);
void		multiboot2_post_reloc(void);
void		multiboot2_print_info(void);
bool		multiboot2_ksyms_addsyms_elf(void);
#endif /* !defined(_LOCORE) */

/* --------------------------------------------------------------------- */