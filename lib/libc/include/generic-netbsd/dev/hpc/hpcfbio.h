/*	$NetBSD: hpcfbio.h,v 1.4 2022/04/08 10:27:04 andvar Exp $	*/

/*-
 * Copyright (c) 1999
 *         Shin Takemura and PocketBSD Project. All rights reserved.
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
 *	This product includes software developed by the PocketBSD project
 *	and its contributors.
 * 4. Neither the name of the project nor the names of its contributors
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
 */

#ifndef H_HPCFBIO
#define	H_HPCFBIO

#include <sys/types.h>
#include <sys/ioccom.h>

#define HPCFB_MAXNAMELEN	32
#define HPCFB_DEFAULT_CONFIG	0
#define HPCFB_CURRENT_CONFIG	-1
#define HPCFB_DEFAULT_UNIT	0
#define HPCFB_CURRENT_UNIT	-1

#define HPCFB_CLASS_UNKNOWN	0	/* unknown class		*/
#define HPCFB_CLASS_GRAYSCALE	1	/* gray scale (maybe monochrome)*/
#define HPCFB_CLASS_INDEXCOLOR	2	/* index color			*/
#define HPCFB_CLASS_RGBCOLOR	3	/* RGB color			*/

#define	HPCFB_ACCESS_CACHEABLE	(1<<0)	/* cacheable			*/
#define	HPCFB_ACCESS_BYTE      	(1<<1) 	/* permit 8 bit access		*/
#define	HPCFB_ACCESS_WORD      	(1<<2) 	/* permit 16 bit access		*/
#define	HPCFB_ACCESS_3BYTE     	(1<<3) 	/* permit 3 bytes access       	*/
#define	HPCFB_ACCESS_DWORD     	(1<<4) 	/* permit 32 bit access		*/
#define	HPCFB_ACCESS_5BYTE     	(1<<5) 	/* permit 5 bytes access       	*/
#define	HPCFB_ACCESS_6BYTE     	(1<<6) 	/* permit 6 bytes access       	*/
#define	HPCFB_ACCESS_7BYTE     	(1<<7) 	/* permit 7 bytes access	*/
#define	HPCFB_ACCESS_QWORD     	(1<<8) 	/* permit 64 bit access		*/
#define	HPCFB_ACCESS_9BYTE     	(1<<9) 	/* permit 9 bytes access	*/
#define	HPCFB_ACCESS_10BYTE    	(1<<10)	/* permit 10 bytes access	*/
#define	HPCFB_ACCESS_11BYTE    	(1<<11)	/* permit 11 bytes access	*/
#define	HPCFB_ACCESS_12BYTE    	(1<<12)	/* permit 12 bytes access	*/
#define	HPCFB_ACCESS_13BYTE    	(1<<13)	/* permit 13 bytes access	*/
#define	HPCFB_ACCESS_14BYTE    	(1<<14)	/* permit 14 bytes access	*/
#define	HPCFB_ACCESS_15BYTE    	(1<<15)	/* permit 15 bytes access	*/
#define	HPCFB_ACCESS_OWORD     	(1<<16)	/* permit 128 bit access	*/

#define	HPCFB_ACCESS_LSB_TO_MSB	(1<<17)	/* first pixel is at LSB side	*/
#define	HPCFB_ACCESS_R_TO_L	(1<<18)	/* pixel order is right to left	*/
#define	HPCFB_ACCESS_B_TO_T	(1<<19)	/* pixel order is bottom to top	*/
#define HPCFB_ACCESS_Y_TO_X	(1<<20)	/* pixel ordef is Y to X	*/
#define	HPCFB_ACCESS_STATIC	(1<<21)	/* no translation table		*/
#define	HPCFB_ACCESS_REVERSE	(1<<22)	/* value 0 means white		*/
#define	HPCFB_ACCESS_PACK_BLANK	(1<<23)	/* pack has a blank at MSB     	*/
#define	HPCFB_ACCESS_PIXEL_BLANK (1<<24)/* pixel has a blank at MSB	*/
#define	HPCFB_ACCESS_ALPHA_REVERSE (1<<25) /* alpha value 0 means thick	*/

/*
 * These bits mean that pack data should be stored in reverse order on
 * memory.
 *
 * HPCFB_REVORDER_BYTE:  0x00 0x01
 *                       +----+-----+
 *                       |7..0|15..8|
 *                       +----+-----+
 * HPCFB_REVORDER_WORD:  0x00       0x02
 *                       +----+-----+----+----+
 *                       |15..0     |31..15   |
 *                       +----+-----+----+----+
 * HPCFB_REVORDER_DWORD: 0x00                 0x04
 *                       +----+-----+----+----+----+----+----+----+
 *                       |31..0               |63..32             |
 *                       +----+-----+----+----+----+----+----+----+
 * HPCFB_REVORDER_QWORD: 0x00                      0x08
 *                       +----+-----+----+----~----+----+----+----~----+
 *                       |63..0                    |127..64            |
 *                       +----+-----+----+----~----+----+----+----~----+
 */
#define	HPCFB_REVORDER_BYTE	(1<<0)
#define	HPCFB_REVORDER_WORD	(1<<1)
#define	HPCFB_REVORDER_DWORD	(1<<2)
#define	HPCFB_REVORDER_QWORD	(1<<3)

struct hpcfb_fbconf {
	short	hf_conf_index;		/* configuration index		*/
	short	hf_nconfs;		/* how many configurations	*/

	short	hf_class;		/* HPCFB_CLASS_*		*/

	char	hf_name[HPCFB_MAXNAMELEN];
				      	/* frame buffer name, null terminated*/
	char	hf_conf_name[HPCFB_MAXNAMELEN];
					/* config name, null terminated	*/

	short	hf_height;		/* how many lines	       	*/
	short	hf_width;		/* how many pixels in a line   	*/

	u_long	hf_baseaddr;		/* frame buffer start address  	*/
	u_long	hf_offset;		/* frame buffer start offset for mmap*/
	short	hf_bytes_per_line;	/**/
	short	hf_nplanes;		/**/
	long	hf_bytes_per_plane;	/**/

	short	hf_pack_width;		/* how many bits in a pack     	*/
	short	hf_pixels_per_pack;	/* how many pixels in a pack   	*/
	short	hf_pixel_width;		/* effective bits width	       	*/

	u_long	hf_access_flags;	/* HPCFB_ACCESS_*		*/
	u_long	hf_order_flags;		/* HPCFB_REVORDER_*		*/
	u_long	hf_reg_offset;   	/* hardware register offset for mmap */
	u_long	hf_reserved[3];

	/*
	 * class dependent data
	 */
	short	hf_class_data_length;
	union {
		char	hf_place_holder[128];
		struct hf_gray_tag {
			u_long	hf_flags;	/* reserved for future use */
		} hf_gray;
		struct hf_indexed_tag {
			u_long	hf_flags;	/* reserved for future use */
		} hf_indexed;
		struct hf_rgb_tag {
			u_long	hf_flags;	/* reserved for future use */

			short	hf_red_width;
			short	hf_red_shift;
			short	hf_green_width;
			short	hf_green_shift;
			short	hf_blue_width;
			short	hf_blue_shift;
			short	hf_alpha_width;
			short	hf_alpha_shift;
		} hf_rgb;
	} hf_u;

	/*
	 * extended data for future use
	 */
	int	hf_ext_size;			/* this value is 0     	*/
	void	*hf_ext_data;       		/* this value is NULL  	*/
};

#define HPCFB_DSP_CLASS_UNKNOWN		0	/* unknown display type	*/
#define HPCFB_DSP_CLASS_COLORCRT	1	/* color CRT		*/
#define HPCFB_DSP_CLASS_COLORLCD	2	/* color LCD		*/
#define HPCFB_DSP_CLASS_GRAYCRT		3	/* gray or mono CRT	*/
#define HPCFB_DSP_CLASS_GRAYLCD		4	/* gray or mono LCD	*/
#define HPCFB_DSP_CLASS_EXTERNAL	5	/* external output	*/
#define HPCFB_DSP_CLASS_VIDEO		6	/* external video output*/

#define HPCFB_DSP_DPI_UNKNOWN		0

struct hpcfb_dspconf {
	short	hd_unit_index;		/* display unit index		*/
	short	hd_nunits;	     	/* how many display units	*/

	short	hd_class;		/* HPCFB_DSP_CLASS_*		*/
	char	hd_name[HPCFB_MAXNAMELEN];
				      	/* display name			*/

	unsigned long	hd_op_flags;
	unsigned long	hd_reserved[3];

	short	hd_conf_index;		/* configuration index		*/
	short	hd_nconfs;		/* how many configurations	*/
	char	hd_conf_name[HPCFB_MAXNAMELEN];
					/* configuration name		*/
	short	hd_width;
	short	hd_height;
	short	hd_xdpi;
	short	hd_ydpi;

};

struct hpcfb_dsp_op {
	short	op;
	long	args[4];
	short	ext_size;
	void	*ext_arg;
};

/*
 * view port position
 * arg0 is x_offset
 * arg1 is y_offset
 */
#define HPCFB_DSP_OP_VIEW	0

/*
 * display settings
 * arg0 is bright;
 * arg1 is contrast;
 */
#define HPCFB_DSP_OP_BRIGHT    	1

/*
 * power state
 * arg0 is power state
 */
#define HPCFB_DSP_OP_POWER     	2
#define HPCFB_DSP_PW_ON		0	/* full power 			*/
#define HPCFB_DSP_PW_SAVE	10	/* power save mode, but not blank */
#define HPCFB_DSP_PW_CUT	20	/* power save mode, screen is blank */
#define HPCFB_DSP_PW_OFF	30	/* power off			*/

/*
 * output signal settings
 * ext_arg is struct hpcfb_dsp_signal
 */
#define HPCFB_DSP_OP_SIGNAL    	3
#define HPCFB_DSP_SIG_H_SYNC_HIGH	(1<<0)
#define HPCFB_DSP_SIG_V_SYNC_HIGH	(1<<1)
#define HPCFB_DSP_SIG_C_SYNC_HIGH	(1<<2)
#define HPCFB_DSP_SIG_SYNC_EXT		(1<<3)
#define HPCFB_DSP_SIG_SYNC_GREEN	(1<<4)
struct hpcfb_dsp_signal {
	unsigned long	flags;
	long	pixclock;	/* pixel clock in pico seconds	*/
	long	left_margin;	/* time from H sync to picture	*/
	long	right_margin;	/* time from picture to H sync	*/
	long	upper_margin;	/* time from V sync to picture	*/
	long	lower_margin;	/* time from picture to V sync	*/
	long	hsync_len;	/* length of H sync		*/
	long	vsync_len;	/* length of V sync		*/
};

#define	HPCFBIO_GCONF		_IOWR('H', 0, struct hpcfb_fbconf)
#define	HPCFBIO_SCONF		_IOW('H', 1, struct hpcfb_fbconf)
#define	HPCFBIO_GDSPCONF	_IOWR('H', 2, struct hpcfb_dspconf)
#define	HPCFBIO_SDSPCONF	_IOW('H', 3, struct hpcfb_dspconf)
#define	HPCFBIO_GOP		_IOR('H', 4, struct hpcfb_dsp_op)
#define	HPCFBIO_SOP		_IOWR('H', 5, struct hpcfb_dsp_op)

#endif /* H_HPCFBIO */