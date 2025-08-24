/*	$NetBSD: cgtworeg.h,v 1.5 2003/05/20 13:38:00 nakayama Exp $ */

/*
 * Copyright (c) 1994 Dennis Ferguson
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

/* cgtworeg.h - CG2 colour frame buffer definitions
 *
 * The mapped memory looks like:
 *
 *  offset     contents
 * 0x000000  bit plane map - 1st (of 8) plane used by the X server in -mono mode
 * 0x100000  pixel map - used by the X server in color mode
 * 0x200000  raster op mode memory map - unused by X server
 * 0x300000  random control registers (lots of spaces in between)
 * 0x310000  shadow colour map
 */

/* Frame buffer memory size and depth */
#define	CG2_FBSIZE	(1024 * 1024)
#define	CG2_N_PLANE	8

/* Screen dimensions */
#define	CG2_WIDTH	1152
#define	CG2_HEIGHT	900

/* Colourmap size */
#define CG2_CMSIZE	256

#define CG2_BITPLANE_OFF	0
#define CG2_BITPLANE_SIZE	0x100000
#define CG2_PIXMAP_OFF		(CG2_BITPLANE_OFF + CG2_BITPLANE_SIZE)
#define CG2_PIXMAP_SIZE		0x100000
#define CG2_ROPMEM_OFF		(CG2_PIXMAP_OFF + CG2_PIXMAP_SIZE)
#define CG2_ROPMEM_SIZE		0x100000
#define CG2_CTLREG_OFF		(CG2_ROPMEM_OFF + CG2_ROPMEM_SIZE)
#define CG2_CTLREG_SIZE		0x010600
#define CG2_MAPPED_SIZE		(CG2_CTLREG_OFF + CG2_CTLREG_SIZE)


/* arrangement of bit plane mode memory */
union bitplane {
	u_short word[CG2_HEIGHT][CG2_WIDTH/(CG2_N_PLANE * sizeof(u_short))];
	u_short plane[CG2_FBSIZE/(CG2_N_PLANE * sizeof(u_short))];
};

/* arrangement of pixel mode memory */
union byteplane {
	u_char pixel[CG2_HEIGHT][CG2_WIDTH];
	u_char frame[CG2_FBSIZE];
};


/*
 * Structure describing the first two megabytes of the frame buffer.
 * Normal memory maps in bit plane and pixel modes
 */
struct cg2memfb {
	union bitplane memplane[CG2_N_PLANE];	/* bit plane map */
	union byteplane pixplane;		/* pixel map */
};


/*
 * Control/status register.  The X server only appears to use update_cmap
 * and video_enab.
 */
struct cg2statusreg {
	u_int reserved : 2;	/* not used */
        u_int fastread : 1;	/* r/o: has some feature I don't understand */
        u_int id : 1;		/* r/o: ext status and ID registers exist */
        u_int resolution : 4;	/* screen resolution, 0 means 1152x900 */
        u_int retrace : 1;	/* r/o: retrace in progress */
        u_int inpend : 1;	/* r/o: interrupt request */
        u_int ropmode : 3;	/* ?? */
        u_int inten : 1;	/* interrupt enable (for end of retrace) */
        u_int update_cmap : 1;	/* copy/use shadow colour map */
        u_int video_enab : 1;	/* enable video */
};


/*
 * Extended status register.  Unused by X server
 */
struct cg2_extstatus {
	u_int gpintreq : 1;	/* interrupt request */
	u_int gpintdis : 1;	/* interrupt disable */
	u_int reserved : 13;	/* unused */
	u_int gpbus : 1;	/* bus enabled */
};


/*
 * Double buffer control register.  It appears that (some of?) the
 * cg2 cards support a pair of memory sets, referred to as `A' and
 * `B', which can be swapped to allow atomic screen updates.  This
 * controls them.
 */
struct dblbufreg {
	u_int display_b : 1;	/* display memory B (set) or A (reset) */
	u_int read_b : 1;	/* accesss memory B (set) or A (reset) */
	u_int nowrite_b : 1;	/* when set, writes don't update memory B */
	u_int nowrite_a : 1;	/* when set, writes don't update memory A */
	u_int read_ecmap : 1;	/* copy from(clear)/to(set) shadow colour map */
	u_int fast_read : 1;	/* fast reads, but wrong data */
	u_int wait : 1;		/* when set, remains so to end up v. retrace */
	u_int update_ecmap : 1;	/* copy/use shadow colour map */
        u_int reserved : 8;
};


/*
 * Zoom register, apparently present on Sun-2 colour boards only.  See
 * the Sun documentation, I don't know anyone who still has a Sun-2.
 */
struct cg2_zoom {
	union {
		u_short reg;
		u_char reg_pad[4096];
	} wordpan;
	union {
		struct {
			u_int unused  : 8;
			u_int lineoff : 4;
			u_int pixzoom : 4;
		} reg;
		u_short word;
		u_char reg_pad[4096];
	} zoom;
        union {
		struct {
			u_int unused   : 8;
			u_int lorigin  : 4;
			u_int pixeloff : 4;
		} reg;
		u_short word;
		u_char reg_pad[4096];
	} pixpan;
	union {
		u_short reg;
		u_char reg_pad[4096];
	} varzoom;
};


/*
 * Miscellany.  On the Sun-3 these registers exist in place of the above.
 */
struct cg2_nozoom {
	union {				/* double buffer register (see above) */
		struct dblbufreg reg;
		u_short word;
		u_char reg_pad[4096];
	} dblbuf;
	union {				/* start of DMA window */
		u_short reg;
		u_char reg_pad[4096];
	} dmabase;
	union {				/* DMA window size */
		u_short reg;		/* actually 8 bits.  reg*16 == size */
		u_char reg_pad[4096];
	} dmawidth;
	union {				/* frame count */
		u_short reg;		/* actually 8 bits only. r/o */
		u_char reg_pad[4096];
	} framecnt;
};


/*
 * Raster op control registers.  X doesn't use this, but documented here
 * for future reference.
 */
struct memropc {
	u_short mrc_dest;
	u_short mrc_source1;
	u_short mrc_source2;
	u_short mrc_pattern;
	u_short mrc_mask1;
	u_short mrc_mask2;
	u_short mrc_shift;
	u_short mrc_op;
	u_short mrc_width;
	u_short mrc_opcount;
	u_short mrc_decoderout;
	u_short mrc_x11;
	u_short mrc_x12;
	u_short mrc_x13;
	u_short mrc_x14;
	u_short mrc_x15;
};


/*
 * Last chunk of the frame buffer (i.e. from offset 0x200000 and above).
 * Exists separately from struct cg2memfb apparently because Sun software
 * avoids mapping the latter, though X uses it.
 */
struct cg2fb {
	union {			/* raster op mode frame memory */
		union bitplane ropplane[CG2_N_PLANE];
		union byteplane roppixel;
	} ropio;
	union {			/* raster op control unit (1 per plane) */
		struct memropc ropregs;
		struct {
			u_char pad[2048];
			struct memropc ropregs;
		} prime;
		u_char reg_pad[4096];
	} ropcontrol[9];
	union {			/* status register */
		struct cg2statusreg reg;
		u_short word;
		u_char reg_pad[4096];
	} status;
	union {			/* per-plane mask register */
		u_short reg;	/* 8 bit mask register - set means plane r/w */
		u_char reg_pad[4096];
	} ppmask;
	union {			/* miscellaneous registers */
		struct cg2_zoom zoom;
		struct cg2_nozoom nozoom;
	} misc;
	union {			/* interrupt vector */
		u_short reg;
		u_char reg_pad[32];
	} intrptvec;
	union {			 /* board ID */
		u_short reg;
		u_char reg_pad[16];
	} id;
	union {			 /* extended status */
		struct cg2_extstatus reg;
		u_short word;
		u_char reg_pad[16];
	} extstatus;
	union {			 /* auxiliary raster op mode register (?)*/
		u_short reg;
		u_char reg_pad[4032];
	} ropmode;
	u_short redmap[CG2_CMSIZE];	/* shadow colour maps */
	u_short greenmap[CG2_CMSIZE];
	u_short bluemap[CG2_CMSIZE];
};