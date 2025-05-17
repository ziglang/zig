/* $NetBSD: wsdisplay_usl_io.h,v 1.5 2019/02/26 10:30:28 msaitoh Exp $ */

#ifndef _DEV_WSCONS_WSDISPLAY_USL_IO_H_
#define _DEV_WSCONS_WSDISPLAY_USL_IO_H_

#include <sys/ioccom.h>

#define VT_OPENQRY	_IOR('v', 1, int)
#define VT_SETMODE	_IOW('v', 2, vtmode_t)
#define VT_GETMODE	_IOR('v', 3, vtmode_t)

struct vt_mode {
	char	mode;
#define VT_AUTO		0		/* switching controlled by drvr	*/
#define VT_PROCESS	1		/* switching controlled by prog */

	char	waitv;			/* not implemented yet 	SOS	*/
	short	relsig;
	short	acqsig;
	short	frsig;			/* not implemented yet	SOS	*/
};

typedef struct vt_mode vtmode_t;

#define VT_RELDISP	_IO('v', 4)
#define VT_FALSE	0		/* release of VT refused */
#define VT_TRUE		1		/* VT released */
#define VT_ACKACQ	2		/* acknowledging VT acquiration */

#define VT_ACTIVATE	_IO('v', 5)
#define VT_WAITACTIVE	_IO('v', 6)
#define VT_GETACTIVE	_IOR('v', 7, int)

#define VT_GETSTATE	_IOR('v', 100, struct vt_stat)
struct vt_stat {
	unsigned short v_active;	/* active vt */
	unsigned short v_signal;	/* signal to send */
	unsigned short v_state;		/* vt bitmask */
};

#define KDGETKBENT	_IOWR('K', 4, struct kbentry)
struct kbentry {
	unchar	kb_table;	/* which table to use */
	unchar	kb_index;	/* which entry in table */
	ushort	kb_value;	/* value to get/set in table */
};

#define KDGKBMODE 	_IOR('K', 6, int)	/* get keyboard mode */

#define KDSKBMODE 	_IO('K', 7)		/* set keyboard mode */
#define K_RAW		0		/* kbd switched to raw mode */
#define K_XLATE		1		/* kbd switched to "normal" mode */

#define KDMKTONE	_IO('K', 8)

#define KDSETMODE	_IO('K', 10)
#define KD_TEXT		0		/* set text mode restore fonts  */
#define KD_GRAPHICS	1		/* set graphics mode 		*/

#define KDENABIO	_IO('K', 60) /* only allowed if euid == 0 */
#define KDDISABIO	_IO('K', 61)

#define KDGKBTYPE	_IOR('K', 64, char)
#define KB_84		1
#define KB_101		2
#define KB_OTHER	3

#define KDGETLED	_IOR('K', 65, int)
#define KDSETLED	_IO('K', 66)
#define LED_CAP		1
#define LED_NUM		2
#define LED_SCR		4

#define KDSETRAD	_IO('K', 67)

/* pcvt compatibility */
#define VGAPCVTID	_IOWR('V', 113, struct pcvtid)	/* get driver id */

struct pcvtid {
#define PCVTIDNAMELN  16		/* driver id - string length	*/
	char name[PCVTIDNAMELN];	/* driver name			*/
	int rmajor;			/* revision number, major	*/
	int rminor;			/* revision number, minor	*/
};

/* syscons compatibility */
#define CONS_GETVERS	_IOR('c', 74, int)

#endif /* _DEV_WSCONS_WSDISPLAY_USL_IO_H_ */