/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2009, 2013 The FreeBSD Foundation
 *
 * This software was developed by Ed Schouten under sponsorship from the
 * FreeBSD Foundation.
 *
 * Portions of this software were developed by Oleksandr Rybalko
 * under sponsorship from the FreeBSD Foundation.
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

#ifndef _SYS_FONT_H_
#define	_SYS_FONT_H_

#include <sys/queue.h>

/*
 * Fonts.
 *
 * Fonts support normal and bold weights, and single and double width glyphs.
 * Mapping tables are used to map Unicode points to glyphs.  They are sorted by
 * code point, and vtfont_lookup() uses this to perform a binary search.  Each
 * font has four mapping tables: two weights times two halves (left/single,
 * right).  When a character is not present in a bold map the glyph from the
 * normal map is used.  When no glyph is available, it uses glyph 0, which is
 * normally equal to U+FFFD.
 */

enum vfnt_map_type {
	VFNT_MAP_NORMAL = 0,	/* Normal font. */
	VFNT_MAP_NORMAL_RIGHT,	/* Normal font right hand. */
	VFNT_MAP_BOLD,		/* Bold font. */
	VFNT_MAP_BOLD_RIGHT,	/* Bold font right hand. */
	VFNT_MAPS		/* Number of maps. */
};

struct font_info {
	int32_t fi_checksum;
	uint32_t fi_width;
	uint32_t fi_height;
	uint32_t fi_bitmap_size;
	uint32_t fi_map_count[VFNT_MAPS];
};

struct vfnt_map {
	uint32_t	 vfm_src;
	uint16_t	 vfm_dst;
	uint16_t	 vfm_len;
} __packed;
typedef struct vfnt_map vfnt_map_t;

struct vt_font {
	vfnt_map_t	*vf_map[VFNT_MAPS];
	uint8_t		*vf_bytes;
	uint32_t	 vf_height;
	uint32_t	 vf_width;
	uint32_t	 vf_map_count[VFNT_MAPS];
	uint32_t	 vf_refcount;
};

typedef struct vt_font_bitmap_data {
        uint32_t	vfbd_width;
        uint32_t	vfbd_height;
        uint32_t	vfbd_compressed_size;
        uint32_t	vfbd_uncompressed_size;
        uint8_t		*vfbd_compressed_data;
        struct vt_font	*vfbd_font;
} vt_font_bitmap_data_t;

typedef enum {
	FONT_AUTO,	/* This font is loaded by software */
	FONT_MANUAL,	/* This font is loaded manually by user */
	FONT_BUILTIN,	/* This font was built in at compile time */
	FONT_RELOAD	/* This font is marked to be re-read from file */
} FONT_FLAGS;

struct fontlist {
	char			*font_name;
	FONT_FLAGS		font_flags;
	vt_font_bitmap_data_t	*font_data;
	vt_font_bitmap_data_t	*(*font_load)(char *);
	STAILQ_ENTRY(fontlist)	font_next;
};

typedef STAILQ_HEAD(font_list, fontlist) font_list_t;

#define	FONT_HEADER_MAGIC	"VFNT0002"
struct font_header {
	uint8_t		fh_magic[8];
	uint8_t		fh_width;
	uint8_t		fh_height;
	uint16_t	fh_pad;
	uint32_t	fh_glyph_count;
	uint32_t	fh_map_count[VFNT_MAPS];
} __packed;

#endif /* !_SYS_FONT_H_ */