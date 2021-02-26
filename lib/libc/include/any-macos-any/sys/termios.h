/*
 * Copyright (c) 2000-2006 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1997 Apple Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1988, 1989, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
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
 *      This product includes software developed by the University of
 *      California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)termios.h	8.3 (Berkeley) 3/28/94
 */

#ifndef _SYS_TERMIOS_H_
#define _SYS_TERMIOS_H_

#include <sys/cdefs.h>

/*
 * Special Control Characters
 *
 * Index into c_cc[] character array.
 *
 *	Name	     Subscript	Enabled by
 */
#define VEOF            0       /* ICANON */
#define VEOL            1       /* ICANON */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VEOL2           2       /* ICANON together with IEXTEN */
#endif
#define VERASE          3       /* ICANON */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VWERASE         4       /* ICANON together with IEXTEN */
#endif
#define VKILL           5       /* ICANON */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VREPRINT        6       /* ICANON together with IEXTEN */
#endif
/*			7	   spare 1 */
#define VINTR           8       /* ISIG */
#define VQUIT           9       /* ISIG */
#define VSUSP           10      /* ISIG */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VDSUSP          11      /* ISIG together with IEXTEN */
#endif
#define VSTART          12      /* IXON, IXOFF */
#define VSTOP           13      /* IXON, IXOFF */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VLNEXT          14      /* IEXTEN */
#define VDISCARD        15      /* IEXTEN */
#endif
#define VMIN            16      /* !ICANON */
#define VTIME           17      /* !ICANON */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define VSTATUS         18      /* ICANON together with IEXTEN */
/*			19	   spare 2 */
#endif
#define NCCS            20

#include <sys/_types/_posix_vdisable.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define CCEQ(val, c)    ((c) == (val) ? (val) != _POSIX_VDISABLE : 0)
#endif

/*
 * Input flags - software input processing
 */
#define IGNBRK          0x00000001      /* ignore BREAK condition */
#define BRKINT          0x00000002      /* map BREAK to SIGINTR */
#define IGNPAR          0x00000004      /* ignore (discard) parity errors */
#define PARMRK          0x00000008      /* mark parity and framing errors */
#define INPCK           0x00000010      /* enable checking of parity errors */
#define ISTRIP          0x00000020      /* strip 8th bit off chars */
#define INLCR           0x00000040      /* map NL into CR */
#define IGNCR           0x00000080      /* ignore CR */
#define ICRNL           0x00000100      /* map CR to NL (ala CRMOD) */
#define IXON            0x00000200      /* enable output flow control */
#define IXOFF           0x00000400      /* enable input flow control */
#define IXANY           0x00000800      /* any char will restart after stop */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define IMAXBEL         0x00002000      /* ring bell on input queue full */
#define IUTF8           0x00004000      /* maintain state for UTF-8 VERASE */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */

/*
 * Output flags - software output processing
 */
#define OPOST           0x00000001      /* enable following output processing */
#define ONLCR           0x00000002      /* map NL to CR-NL (ala CRMOD) */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define OXTABS          0x00000004      /* expand tabs to spaces */
#define ONOEOT          0x00000008      /* discard EOT's (^D) on output) */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
/*
 * The following block of features is unimplemented.  Use of these flags in
 * programs will currently result in unexpected behaviour.
 *
 * - Begin unimplemented features
 */
#define OCRNL           0x00000010      /* map CR to NL on output */
#define ONOCR           0x00000020      /* no CR output at column 0 */
#define ONLRET          0x00000040      /* NL performs CR function */
#define OFILL           0x00000080      /* use fill characters for delay */
#define NLDLY           0x00000300      /* \n delay */
#define TABDLY          0x00000c04      /* horizontal tab delay */
#define CRDLY           0x00003000      /* \r delay */
#define FFDLY           0x00004000      /* form feed delay */
#define BSDLY           0x00008000      /* \b delay */
#define VTDLY           0x00010000      /* vertical tab delay */
#define OFDEL           0x00020000      /* fill is DEL, else NUL */
#if !defined(_SYS_IOCTL_COMPAT_H_) || __DARWIN_UNIX03
/*
 * These manifest constants have the same names as those in the header
 * <sys/ioctl_compat.h>, so you are not permitted to have both definitions
 * in scope simultaneously in the same compilation unit.  Nevertheless,
 * they are required to be in scope when _POSIX_C_SOURCE is requested;
 * this means that including the <sys/ioctl_compat.h> header before this
 * one when _POSIX_C_SOURCE is in scope will result in redefintions.  We
 * attempt to maintain these as the same values so as to avoid this being
 * an outright error in most compilers.
 */
#define         NL0     0x00000000
#define         NL1     0x00000100
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define         NL2     0x00000200
#define         NL3     0x00000300
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define         TAB0    0x00000000
#define         TAB1    0x00000400
#define         TAB2    0x00000800
/* not in sys/ioctl_compat.h, use OXTABS value */
#define         TAB3    0x00000004
#define         CR0     0x00000000
#define         CR1     0x00001000
#define         CR2     0x00002000
#define         CR3     0x00003000
#define         FF0     0x00000000
#define         FF1     0x00004000
#define         BS0     0x00000000
#define         BS1     0x00008000
#define         VT0     0x00000000
#define         VT1     0x00010000
#endif  /* !_SYS_IOCTL_COMPAT_H_ */
/*
 * + End unimplemented features
 */

/*
 * Control flags - hardware control of terminal
 */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define CIGNORE         0x00000001      /* ignore control flags */
#endif
#define CSIZE           0x00000300      /* character size mask */
#define     CS5             0x00000000      /* 5 bits (pseudo) */
#define     CS6             0x00000100      /* 6 bits */
#define     CS7             0x00000200      /* 7 bits */
#define     CS8             0x00000300      /* 8 bits */
#define CSTOPB          0x00000400      /* send 2 stop bits */
#define CREAD           0x00000800      /* enable receiver */
#define PARENB          0x00001000      /* parity enable */
#define PARODD          0x00002000      /* odd parity, else even */
#define HUPCL           0x00004000      /* hang up on last close */
#define CLOCAL          0x00008000      /* ignore modem status lines */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define CCTS_OFLOW      0x00010000      /* CTS flow control of output */
#define CRTSCTS         (CCTS_OFLOW | CRTS_IFLOW)
#define CRTS_IFLOW      0x00020000      /* RTS flow control of input */
#define CDTR_IFLOW      0x00040000      /* DTR flow control of input */
#define CDSR_OFLOW      0x00080000      /* DSR flow control of output */
#define CCAR_OFLOW      0x00100000      /* DCD flow control of output */
#define MDMBUF          0x00100000      /* old name for CCAR_OFLOW */
#endif


/*
 * "Local" flags - dumping ground for other state
 *
 * Warning: some flags in this structure begin with
 * the letter "I" and look like they belong in the
 * input flag.
 */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define ECHOKE          0x00000001      /* visual erase for line kill */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define ECHOE           0x00000002      /* visually erase chars */
#define ECHOK           0x00000004      /* echo NL after line kill */
#define ECHO            0x00000008      /* enable echoing */
#define ECHONL          0x00000010      /* echo NL even if ECHO is off */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define ECHOPRT         0x00000020      /* visual erase mode for hardcopy */
#define ECHOCTL         0x00000040      /* echo control chars as ^(Char) */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define ISIG            0x00000080      /* enable signals INTR, QUIT, [D]SUSP */
#define ICANON          0x00000100      /* canonicalize input lines */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define ALTWERASE       0x00000200      /* use alternate WERASE algorithm */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define IEXTEN          0x00000400      /* enable DISCARD and LNEXT */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define EXTPROC         0x00000800      /* external processing */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define TOSTOP          0x00400000      /* stop background jobs from output */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define FLUSHO          0x00800000      /* output being flushed (state) */
#define NOKERNINFO      0x02000000      /* no kernel output from VSTATUS */
#define PENDIN          0x20000000      /* XXX retype pending input (state) */
#endif  /*(_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define NOFLSH          0x80000000      /* don't flush after interrupt */

typedef unsigned long   tcflag_t;
typedef unsigned char   cc_t;
typedef unsigned long   speed_t;

struct termios {
	tcflag_t        c_iflag;        /* input flags */
	tcflag_t        c_oflag;        /* output flags */
	tcflag_t        c_cflag;        /* control flags */
	tcflag_t        c_lflag;        /* local flags */
	cc_t            c_cc[NCCS];     /* control chars */
	speed_t         c_ispeed;       /* input speed */
	speed_t         c_ospeed;       /* output speed */
};


/*
 * Commands passed to tcsetattr() for setting the termios structure.
 */
#define TCSANOW         0               /* make change immediate */
#define TCSADRAIN       1               /* drain output, then change */
#define TCSAFLUSH       2               /* drain output, flush input */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define TCSASOFT        0x10            /* flag - don't alter h.w. state */
#endif

/*
 * Standard speeds
 */
#define B0      0
#define B50     50
#define B75     75
#define B110    110
#define B134    134
#define B150    150
#define B200    200
#define B300    300
#define B600    600
#define B1200   1200
#define B1800   1800
#define B2400   2400
#define B4800   4800
#define B9600   9600
#define B19200  19200
#define B38400  38400
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define B7200   7200
#define B14400  14400
#define B28800  28800
#define B57600  57600
#define B76800  76800
#define B115200 115200
#define B230400 230400
#define EXTA    19200
#define EXTB    38400
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */


#define TCIFLUSH        1
#define TCOFLUSH        2
#define TCIOFLUSH       3
#define TCOOFF          1
#define TCOON           2
#define TCIOFF          3
#define TCION           4

#include <sys/cdefs.h>

__BEGIN_DECLS
speed_t cfgetispeed(const struct termios *);
speed_t cfgetospeed(const struct termios *);
int     cfsetispeed(struct termios *, speed_t);
int     cfsetospeed(struct termios *, speed_t);
int     tcgetattr(int, struct termios *);
int     tcsetattr(int, int, const struct termios *);
int     tcdrain(int) __DARWIN_ALIAS_C(tcdrain);
int     tcflow(int, int);
int     tcflush(int, int);
int     tcsendbreak(int, int);

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
void    cfmakeraw(struct termios *);
int     cfsetspeed(struct termios *, speed_t);
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
__END_DECLS


#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)

/*
 * Include tty ioctl's that aren't just for backwards compatibility
 * with the old tty driver.  These ioctl definitions were previously
 * in <sys/ioctl.h>.
 */
#include <sys/ttycom.h>
#endif

/*
 * END OF PROTECTED INCLUDE.
 */
#endif /* !_SYS_TERMIOS_H_ */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/ttydefaults.h>
#endif