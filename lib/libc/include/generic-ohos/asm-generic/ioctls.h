/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef __ASM_GENERIC_IOCTLS_H
#define __ASM_GENERIC_IOCTLS_H
#include <linux/ioctl.h>
#define TCGETS 0x5401
#define TCSETS 0x5402
#define TCSETSW 0x5403
#define TCSETSF 0x5404
#define TCGETA 0x5405
#define TCSETA 0x5406
#define TCSETAW 0x5407
#define TCSETAF 0x5408
#define TCSBRK 0x5409
#define TCXONC 0x540A
#define TCFLSH 0x540B
#define TIOCEXCL 0x540C
#define TIOCNXCL 0x540D
#define TIOCSCTTY 0x540E
#define TIOCGPGRP 0x540F
#define TIOCSPGRP 0x5410
#define TIOCOUTQ 0x5411
#define TIOCSTI 0x5412
#define TIOCGWINSZ 0x5413
#define TIOCSWINSZ 0x5414
#define TIOCMGET 0x5415
#define TIOCMBIS 0x5416
#define TIOCMBIC 0x5417
#define TIOCMSET 0x5418
#define TIOCGSOFTCAR 0x5419
#define TIOCSSOFTCAR 0x541A
#define FIONREAD 0x541B
#define TIOCINQ FIONREAD
#define TIOCLINUX 0x541C
#define TIOCCONS 0x541D
#define TIOCGSERIAL 0x541E
#define TIOCSSERIAL 0x541F
#define TIOCPKT 0x5420
#define FIONBIO 0x5421
#define TIOCNOTTY 0x5422
#define TIOCSETD 0x5423
#define TIOCGETD 0x5424
#define TCSBRKP 0x5425
#define TIOCSBRK 0x5427
#define TIOCCBRK 0x5428
#define TIOCGSID 0x5429
#define TCGETS2 _IOR('T', 0x2A, struct termios2)
#define TCSETS2 _IOW('T', 0x2B, struct termios2)
#define TCSETSW2 _IOW('T', 0x2C, struct termios2)
#define TCSETSF2 _IOW('T', 0x2D, struct termios2)
#define TIOCGRS485 0x542E
#ifndef TIOCSRS485
#define TIOCSRS485 0x542F
#endif
#define TIOCGPTN _IOR('T', 0x30, unsigned int)
#define TIOCSPTLCK _IOW('T', 0x31, int)
#define TIOCGDEV _IOR('T', 0x32, unsigned int)
#define TCGETX 0x5432
#define TCSETX 0x5433
#define TCSETXF 0x5434
#define TCSETXW 0x5435
#define TIOCSIG _IOW('T', 0x36, int)
#define TIOCVHANGUP 0x5437
#define TIOCGPKT _IOR('T', 0x38, int)
#define TIOCGPTLCK _IOR('T', 0x39, int)
#define TIOCGEXCL _IOR('T', 0x40, int)
#define TIOCGPTPEER _IO('T', 0x41)
#define TIOCGISO7816 _IOR('T', 0x42, struct serial_iso7816)
#define TIOCSISO7816 _IOWR('T', 0x43, struct serial_iso7816)
#define FIONCLEX 0x5450
#define FIOCLEX 0x5451
#define FIOASYNC 0x5452
#define TIOCSERCONFIG 0x5453
#define TIOCSERGWILD 0x5454
#define TIOCSERSWILD 0x5455
#define TIOCGLCKTRMIOS 0x5456
#define TIOCSLCKTRMIOS 0x5457
#define TIOCSERGSTRUCT 0x5458
#define TIOCSERGETLSR 0x5459
#define TIOCSERGETMULTI 0x545A
#define TIOCSERSETMULTI 0x545B
#define TIOCMIWAIT 0x545C
#define TIOCGICOUNT 0x545D
#ifndef FIOQSIZE
#define FIOQSIZE 0x5460
#endif
#define TIOCPKT_DATA 0
#define TIOCPKT_FLUSHREAD 1
#define TIOCPKT_FLUSHWRITE 2
#define TIOCPKT_STOP 4
#define TIOCPKT_START 8
#define TIOCPKT_NOSTOP 16
#define TIOCPKT_DOSTOP 32
#define TIOCPKT_IOCTL 64
#define TIOCSER_TEMT 0x01
#endif