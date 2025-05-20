/* $NetBSD: hd44780var.h,v 1.8 2015/09/06 06:01:00 dholland Exp $ */

/*
 * Copyright (c) 2002 Dennis I. Chernoivanov
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
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

#ifndef _DEV_IC_HD44780VAR_H_
#define _DEV_IC_HD44780VAR_H_

#include <sys/ioccom.h>

/* IOCTL definitions */
#define HLCD_DISPCTL		_IOW('h',   1, struct hd44780_dispctl)
#define	HLCD_RESET		_IO('h',    2)
#define	HLCD_CLEAR		_IO('h',    3)
#define	HLCD_CURSOR_LEFT	_IO('h',    4)
#define	HLCD_CURSOR_RIGHT	_IO('h',    5)
#define	HLCD_GET_CURSOR_POS	_IOR('h',   6, struct hd44780_io)
#define	HLCD_SET_CURSOR_POS	_IOW('h',   7, struct hd44780_io)
#define	HLCD_GETC		_IOR('h',   8, struct hd44780_io)
#define	HLCD_PUTC		_IOW('h',   9, struct hd44780_io)
#define	HLCD_SHIFT_LEFT		_IO('h',   10)
#define	HLCD_SHIFT_RIGHT	_IO('h',   11)
#define	HLCD_HOME		_IO('h',   12)
#define	HLCD_WRITE		_IOWR('h', 13, struct hd44780_io)
#define	HLCD_READ		_IOWR('h', 14, struct hd44780_io)
#define	HLCD_REDRAW		_IOW('h',  15, struct hd44780_io)
#define	HLCD_WRITE_INST		_IOW('h',  16, struct hd44780_io)
#define	HLCD_WRITE_DATA		_IOW('h',  17, struct hd44780_io)
#define HLCD_GET_INFO		_IOR('h',  18, struct hd44780_info)
#define HLCD_GET_CHIPNO		_IOR('h',  19, uint8_t)
#define HLCD_SET_CHIPNO		_IOW('h',  20, uint8_t)

struct hd44780_dispctl {
	uint8_t chip;
	uint8_t	display_on:1,
		blink_on:1,
		cursor_on:1;
};

struct hd44780_io {
	uint8_t chip;
	uint8_t dat;
	uint8_t len;
	uint8_t buf[HD_MAX_CHARS];
};

struct hd44780_info {
	uint8_t	lines;
	uint8_t	phys_rows;
	uint8_t	virt_rows;

	uint8_t	is_wide:1,
		is_bigfont:1,
		kp_present:1;
};

#ifdef _KERNEL

struct  hlcd_screen {
	int hlcd_curon;
	int hlcd_curx;
	int hlcd_cury;
	uint8_t *image;			/* characters of screen */
	struct hd44780_chip *hlcd_sc;
};

/* HLCD driver structure */
struct hd44780_chip {
#define HD_8BIT			0x01	/* 8-bit if set, 4-bit otherwise */
#define HD_MULTILINE		0x02	/* 2 lines if set, 1 otherwise */
#define HD_BIGFONT		0x04	/* 5x10 if set, 5x8 otherwise */
#define HD_KEYPAD		0x08	/* if set, keypad is connected */
#define HD_UP			0x10	/* if set, lcd has been initialized */
#define HD_TIMEDOUT		0x20	/* lcd has recently stopped talking */
#define HD_MULTICHIP		0x40	/* two HD44780 controllers (4-line) */
	uint8_t sc_flags;

	uint8_t sc_cols;		/* visible columns */
	uint8_t sc_vcols;		/* virtual columns (normally 40) */
	uint8_t sc_dev_ok;
	uint8_t sc_curchip;

	bus_space_tag_t sc_iot;

	bus_space_handle_t sc_ioir;	/* instruction register */
	bus_space_handle_t sc_iodr;	/* data register */

	device_t sc_dev;		/* Pointer to parent device */
	struct hlcd_screen sc_screen;	/* currently displayed screen copy */
	struct hlcd_screen *sc_curscr;	/* active screen */
	struct callout redraw;		/* wsdisplay refresh/redraw timer */

	/* Generic write/read byte entries. */
	void     (* sc_writereg)(struct hd44780_chip *, uint32_t, uint32_t,
	  uint8_t);
	uint8_t (* sc_readreg)(struct hd44780_chip *, uint32_t, uint32_t);
};

#define hd44780_ir_write(sc, en, dat) \
	do {								\
		hd44780_busy_wait(sc, (en));					\
		(sc)->sc_writereg((sc), (en), 0, (dat));		\
	} while(0)

#define hd44780_ir_read(sc, en) \
	(sc)->sc_readreg((sc), (en), 0)

#define hd44780_dr_write(sc, en, dat) \
	(sc)->sc_writereg((sc), (en), 1, (dat))

#define hd44780_dr_read(sc, en) \
	(sc)->sc_readreg((sc), (en), 1)

void hd44780_attach_subr(struct hd44780_chip *);
void hd44780_busy_wait(struct hd44780_chip *, uint32_t);
int  hd44780_init(struct hd44780_chip *);
int  hd44780_chipinit(struct hd44780_chip *, uint32_t);
int  hd44780_ioctl_subr(struct hd44780_chip *, u_long, void *);
void hd44780_ddram_redraw(struct hd44780_chip *, uint32_t, struct hd44780_io *);

#define HD_DDRAM_READ	0x0
#define HD_DDRAM_WRITE	0x1
int  hd44780_ddram_io(struct hd44780_chip *, uint32_t, struct hd44780_io *,
    uint8_t);

#if defined(HD44780_STD_WIDE) || defined(HD44780_STD_SHORT)
void     hd44780_writereg(struct hd44780_chip *, uint32_t, uint32_t, uint8_t);
uint8_t hd44780_readreg(struct hd44780_chip *, uint32_t, uint32_t);
#endif

#endif /* _KERNEL */

#endif /* _DEV_IC_HD44780VAR_H_ */