/*	$NetBSD: oldmon.h,v 1.17 2007/03/04 06:00:44 christos Exp $ */

/*
 * Copyright (C) 1985 Regents of the University of California
 * Copyright (c) 1993 Adam Glass
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Adam Glass.
 * 4. The name of the Author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Adam Glass ``AS IS'' AND
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
 *	from: Sprite /cdrom/src/kernel/Cvsroot/kernel/mach/sun3.md/machMon.h,v
 *	    9.1 90/10/03 13:52:34 mgbaker Exp SPRITE (Berkeley)
 */
#ifndef _MACHINE_OLDMON_H
#define _MACHINE_OLDMON_H

#if defined(_KERNEL_OPT)
#include "opt_sparc_arch.h"
#endif

/*
 *     Structures, constants and defines for access to the sun monitor.
 *     These are translated from the sun monitor header file "sunromvec.h".
 *
 * The memory addresses for the PROM, and the EEPROM.
 * On the sun2 these addresses are actually 0x00EF??00
 * but only the bottom 24 bits are looked at so these still
 * work ok.
 */
#define PROM_BASE       0xffe81000

enum maptypes { /* Page map entry types. */
	MAP_MAINMEM,
	MAP_OBIO,
	MAP_MBMEM,
	MAP_MBIO,
	MAP_VME16A16D,
	MAP_VME16A32D,
	MAP_VME24A16D,
	MAP_VME24A32D,
	MAP_VME32A16D,
	MAP_VME32A32D
};
/*
 * This table gives information about the resources needed by a device.
 */
struct devinfo {
	unsigned int	d_devbytes;  /* Bytes occupied by device in IO space.*/
	unsigned int	d_dmabytes;  /* Bytes needed by device in DMA memory.*/
	unsigned int	d_localbytes;/* Bytes needed by device for local info.*/
	unsigned int	d_stdcount;  /* How many standard addresses. */
	unsigned long	*d_stdaddrs; /* The vector of standard addresses. */
	enum maptypes	d_devtype;   /* What map space device is in. */
	unsigned int	d_maxiobytes;/* Size to break big I/O's into. */
};

/*
 * A "stand alone I/O request".
 * This is passed as the main argument to the PROM I/O routines
 * in the `om_boottable' structure.
 */
struct saioreq {
	char	si_flgs;
	struct om_boottable *si_boottab;/* Points to boottab entry if any */
	char	*si_devdata;		/* Device-specific data pointer */
	int	si_ctlr;		/* Controller number or address */
	int	si_unit;		/* Unit number within controller */
	long	si_boff;		/* Partition number within unit */
	long	si_cyloff;
	long	si_offset;
	long	si_bn;			/* Block number to R/W */
	char	*si_ma;			/* Memory address to R/W */
	int	si_cc;			/* Character count to R/W */
	struct	saif *si_sif;		/* net if. pointer (set by b_open) */
	char 	*si_devaddr;		/* Points to mapped in device */
	char	*si_dmaaddr;		/* Points to allocated DMA space */
};
#define SAIO_F_READ	0x01
#define SAIO_F_WRITE	0x02
#define SAIO_F_ALLOC	0x04
#define SAIO_F_FILE	0x08
#define	SAIO_F_EOF	0x10	/* EOF on device */
#define SAIO_F_AJAR	0x20	/* Descriptor "ajar" (stopped but not closed) */


/*
 * The table entry that describes a device.  It exists in the PROM; a
 * pointer to it is passed in MachMonBootParam.  It can be used to locate
 * PROM subroutines for opening, reading, and writing the device.
 *
 * When using this interface, only one device can be open at once.
 *
 * NOTE: I am not sure what arguments boot, open, close, and strategy take.
 * What is here is just translated verbatim from the sun monitor code.  We
 * should figure this out eventually if we need it.
 */
struct om_boottable {
	char	b_devname[2];		/* The name of the device */
	int	(*b_probe)(void);	/* probe() --> -1 or found controller
					   number */
	int	(*b_boot)(void);	/* boot(bp) --> -1 or start address */
	int	(*b_open)(struct saioreq *);
					/* open(iobp) --> -1 or 0 */
	int	(*b_close)(struct saioreq *);
					/* close(iobp) --> -1 or 0 */
	int	(*b_strategy)(struct saioreq *, int);
					/* strategy(iobp,rw) --> -1 or 0 */
	char	*b_desc;		/* Printable string describing dev */
	struct devinfo *b_devinfo;      /* info to configure device. */
};

/*
 * Structure set up by the boot command to pass arguments to the program that
 * is booted.
 */
struct om_bootparam {
	char	*argPtr[8];		/* String arguments */
	char	strings[100];		/* String table for string arguments */
	char	devName[2];		/* Device name */
	int	ctlrNum;		/* Controller number */
	int	unitNum;		/* Unit number */
	int	partNum;		/* Partition/file number */
	char	*fileName;		/* File name, points into strings */
	struct om_boottable *bootTable;	/* Points to table entry for device */
};

/*
 * Here is the structure of the vector table which is at the front of the boot
 * rom.  The functions defined in here are explained below.
 *
 * NOTE: This struct has references to the structures keybuf and globram which
 *       I have not translated.  If anyone needs to use these they should
 *       translate these structs into Sprite format.
 */
struct om_vector {
	char	*initSp;		/* Initial system stack ptr for hardware */
	int	(*startMon)(void);	/* Initial PC for hardware */
	int	*diagberr;		/* Bus err handler for diags */

	/* Monitor and hardware revision and identification */
	struct om_bootparam **bootParam;	/* Info for bootstrapped pgm */
 	u_long	*memorySize;		/* Usable memory in bytes */

	/* Single-character input and output */
	int	(*getChar)(void);	/* Get char from input source */
	void	(*putChar)(int);	/* Put char to output sink */
	int	(*mayGet)(void);	/* Maybe get char, or -1 */
	int	(*mayPut)(int);		/* Maybe put char, or -1 */
	u_char	*echo;			/* Should getchar echo? */
	u_char	*inSource;		/* Input source selector */
	u_char	*outSink;		/* Output sink selector */
#define	PROMDEV_KBD	0		/* input from keyboard */
#define	PROMDEV_SCREEN	0		/* output to screen */
#define	PROMDEV_TTYA	1		/* in/out to ttya */
#define	PROMDEV_TTYB	2		/* in/out to ttyb */

	/* Keyboard input (scanned by monitor nmi routine) */
	int	(*getKey)(void);	/* Get next key if one exists */
	int	(*initGetKey)(void);	/* Initialize get key */
	u_int	*translation;		/* Kbd translation selector */
	u_char	*keyBid;		/* Keyboard ID byte */
	int	*screen_x;		/* V2: Screen x pos (R/O) */
	int	*screen_y;		/* V2: Screen y pos (R/O) */
	struct keybuf	*keyBuf;	/* Up/down keycode buffer */

	/* Monitor revision level. */
	char	*monId;

	/* Frame buffer output and terminal emulation */
	int	(*fbWriteChar)(void);	/* Write a character to FB */
	int	*fbAddr;		/* Address of frame buffer */
	char	**font;			/* Font table for FB */
	void	(*fbWriteStr)(const char *, int);
					/* Quickly write string to FB */

	/* Reboot interface routine -- resets and reboots system. */
	void	(*reBoot)(const char *)	/* e.g. reBoot("xy()vmunix") */
				__attribute__((__noreturn__));

	/* Line input and parsing */
	u_char	*lineBuf;		/* The line input buffer */
	u_char	**linePtr;		/* Cur pointer into linebuf */
	int	*lineSize;		/* length of line in linebuf */
	int	(*getLine)(void);	/* Get line from user */
	u_char	(*getNextChar)(void);	/* Get next char from linebuf */
	u_char	(*peekNextChar)(void);	/* Peek at next char */
	int	*fbThere;		/* =1 if frame buffer there */
	int	(*getNum)(void);	/* Grab hex num from line */

	/* Print formatted output to current output sink */
	int	(*printf)(void);	/* Similar to "Kernel printf" */
	int	(*printHex)(void);	/* Format N digits in hex */

	/* Led stuff */
	u_char	*leds;			/* RAM copy of LED register */
	int	(*setLeds)(void);	/* Sets LED's and RAM copy */

	/* Non-maskable interrupt  (nmi) information */
	int	(*nmiAddr)(void);	/* Addr for level 7 vector */
	void	(*abortEntry)(void);	/* Entry for keyboard abort */
	int	*nmiClock;		/* Counts up in msec */

	/* Frame buffer type: see <machine/fbio.h> */
	int	*fbType;

	/* Assorted other things */
	u_long	romvecVersion;		/* Version # of Romvec */
	struct globram *globRam;	/* monitor global variables */
	void *	kbdZscc;		/* Addr of keyboard in use */

	int	*keyrInit;		/* ms before kbd repeat */
	u_char	*keyrTick; 		/* ms between repetitions */
	u_long	*memoryAvail;		/* V1: Main mem usable size */
	long	*resetAddr;		/* where to jump on a reset */
	long	*resetMap;		/* pgmap entry for resetaddr */
					/* Really struct pgmapent *  */

	__dead void (*exitToMon)(void)	/* Exit from user program */
				__attribute__((noreturn));
	u_char	**memorybitmap;		/* V1: &{0 or &bits} */
	void	(*setcxsegmap)		/* Set seg in any context */
		    (int, void *, int);
	void	(**vector_cmd)(u_long, char *);
					/* V2: Handler for 'v' cmd */
  	u_long	*ExpectedTrapSig;
  	u_long	*TrapVectorTable;
	int	dummy1z;
	int	dummy2z;
	int	dummy3z;
	int	dummy4z;
};

#define	romVectorPtr	((struct om_vector *)PROM_BASE)

#define mon_printf (romVectorPtr->printf)
#define mon_putchar (romVectorPtr->putChar)
#define mon_may_getchar (romVectorPtr->mayGet)
#define mon_exit_to_mon (romVectorPtr->exitToMon)
#define mon_reboot (romVectorPtr->exitToMon)
#define mon_panic(x) { mon_printf(x); mon_exit_to_mon();}

#define mon_setcxsegmap(context, va, sme) \
    romVectorPtr->setcxsegmap(context, va, sme)

/*
 * OLDMON_STARTVADDR and OLDMON_ENDVADDR denote the range of the damn monitor.
 *
 * supposedly you can steal pmegs within this range that do not contain
 * valid pages.
 */
#define OLDMON_STARTVADDR	0xFFD00000
#define OLDMON_ENDVADDR		0xFFF00000

/*
 * These describe the monitor's short segment which it basically uses to map
 * one stupid page that it uses for storage.  MONSHORTPAGE is the page,
 * and MONSHORTSEG is the segment that it is in.  If this sounds dumb to
 * you, it is.  I can change the pmeg, but not the virtual address.
 * Sun defines these with the high nibble set to 0xF.  I believe this was
 * for the monitor source which accesses this piece of memory with addressing
 * limitations or some such crud.  I haven't replicated this here, because
 * it is confusing, and serves no obvious purpose if you aren't the monitor.
 *
 */
#define MONSHORTPAGE	0x0FFFE000
#define MONSHORTSEG	0x0FFE0000



/*
 * Ethernet interface descriptor
 * First, set: saiop->si_devaddr, saiop->si_dmaaddr, etc.
 * Then:  saiop->si_boottab->b_open()  will set:
 *   saiop->si_sif;
 *   saiop->si_devdata;
 * The latter is the first arg to the following functions.
 * Note that the buffer must be in DVMA space...
 */
struct saif {
	/* transmit packet, returns zero on success. */
	int	(*sif_xmit)(void *devdata, char *buf, int len);
	/* wait for packet, zero if none arrived */
	int	(*sif_poll)(void *devdata, char *buf);
	/* reset interface, set addresses, etc. */
	int	(*sif_reset)(void *devdata, struct saioreq *sip);
	/* Later (sun4 only) proms have more stuff here. */
};


#if defined(SUN4)
void	oldmon_w_trace(u_long);
void	oldmon_w_cmd(u_long, char *);
#endif

#endif /* _MACHINE_OLDMON_H */