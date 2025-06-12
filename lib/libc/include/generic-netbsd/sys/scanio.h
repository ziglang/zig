/*	$NetBSD: scanio.h,v 1.4 2016/01/22 23:42:14 dholland Exp $	*/

/*
 * Copyright (c) 1995 Kenneth Stailey.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Kenneth Stailey.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
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

/*
 * Definitions for PINT scanner drivers
 */

#ifndef _SYS_SCANIO_H_
#define _SYS_SCANIO_H_

#include <sys/ioccom.h>

/*
 * XXX scancap make this sort of obsolete:
 *
 * Some comments about the values in the scan_io struct:
 *
 * All user-changeable values have minimum and maximum values for
 * specific scanner types and are rejected by the special drivers if
 * they are not in range. For values in the range, the driver selects
 * the next physically possible setting for the particular scanner.
 * So it is good practice to issue a SCIOCGET after a SCIOCSET to see
 * what the driver has chosen.
 *
 * Brightness and contrast default to 100 (%) but scanners may support
 * higher and/or lower values, though the maximum value is 255.
 * velocity is the scan speed and defaults to 100 (%), only slower
 * values may be possible.
 */

struct scan_io {
	unsigned long	scan_width;	 /* width in 1/1200ths of an inch */
	unsigned long	scan_height;	 /* height in 1/1200ths of an inch */
#ifdef SCAN_BC
# define scan_window_width scan_width
# define scan_window_length scan_height
#endif
	unsigned short scan_x_resolution;/* horizontal resolution in dots-per-inch */
	unsigned short scan_y_resolution;/* vertical resolution in dots-per-inch */
	unsigned long scan_x_origin;	/* horizontal coordinate of upper left corner */
	unsigned long scan_y_origin;	/* vertical coordinate of upper left corner */
	unsigned char scan_image_mode;	/* type of image data sent by scanner */
	unsigned char scan_brightness;	/* brightness control for those to can do it */
	unsigned char scan_contrast;	/* contrast control for those to can do it */
	unsigned char scan_quality;	/* speed of scan for instance */
#ifdef SCAN_BC
# define scan_velocity scan_quality
#endif
	unsigned long scan_window_size;	/* size of window in bytes (ro) */
	unsigned long scan_lines;	/* number of pixels per column (ro) */
	unsigned long scan_pixels_per_line;	/* number of pixels per line (ro) */
	unsigned short scan_bits_per_pixel;	/* number of bits per pixel (ro) */
	unsigned char scan_scanner_type;	/* type of scanner (ro) */
};

/*
 * defines for different commands
 */

#define SCIOCGET	_IOR('S', 1, struct scan_io) /* retrieve parameters */
#define SCIOCSET	_IOW('S', 2, struct scan_io) /* set parameters */
#define SCIOCRESTART	_IO('S', 3) /* restart scan */
#define SCIOC_USE_ADF	_IO('S', 4) /* use ADF as paper source for next scan */
				    /* even after close() */
#ifdef SCAN_BC
# define SCAN_GET	SCIOCGET
# define SCAN_SET	SCIOCSET
# define SCAN_REWIND	SCIOCRESTART
# define SCAN_USE_ADF	SCIOC_USE_ADF
#endif

/*
 * defines for scan_image_mode field
 */

#define SIM_BINARY_MONOCHROME	0
#define SIM_DITHERED_MONOCHROME	1
#define SIM_GRAYSCALE		2
#define SIM_COLOR		5
#define SIM_RED			103
#define SIM_GREEN		104
#define SIM_BLUE		105

/*
 * defines for different types of scanners & product names as comments
 */

#define RICOH_IS410	1	/* Ricoh IS-410 */
#define FUJITSU_M3096G	2	/* Fujitsu M3096G */
#ifdef SCAN_BC
# define FUJITSU	2	/* Fujitsu M3096G (deprecated) */
#endif
#define HP_SCANJET_IIC	3	/* HP ScanJet IIc */
#define RICOH_FS1	4	/* Ricoh FS1 */
#define SHARP_JX600	5	/* Sharp JX600 */
#define RICOH_IS50	6	/* Ricoh IS-50 */
#define IBM_2456	7	/* IBM 2456 */
#define UMAX_UC630	8	/* UMAX UC630 */
#define UMAX_UG630	9	/* UMAX UG630 */
#define MUSTEK_06000CX	10	/* Mustek MFS06000CX */
#define MUSTEK_12000CX	11	/* Mustek MFS12000CX */
#define EPSON_ES300C	12	/* epson es300c */

#endif /* _SYS_SCANIO_H_ */