#define _IOC(a,b,c,d) ( ((a)<<29) | ((b)<<8) | (c) | ((d)<<16) )
#define _IOC_NONE  1U
#define _IOC_WRITE 4U
#define _IOC_READ  2U

#define _IO(a,b) _IOC(_IOC_NONE,(a),(b),0)
#define _IOW(a,b,c) _IOC(_IOC_WRITE,(a),(b),sizeof(c))
#define _IOR(a,b,c) _IOC(_IOC_READ,(a),(b),sizeof(c))
#define _IOWR(a,b,c) _IOC(_IOC_READ|_IOC_WRITE,(a),(b),sizeof(c))

#define FIONCLEX	_IO('f', 2)
#define FIOCLEX		_IO('f', 1)
#define FIOASYNC	_IOW('f', 125, int)
#define FIONBIO		_IOW('f', 126, int)
#define FIONREAD	_IOR('f', 127, int)
#define TIOCINQ		FIONREAD
#define FIOQSIZE	_IOR('f', 128, char[8])
#define TIOCGETP	_IOR('t', 8, char[6])
#define TIOCSETP	_IOW('t', 9, char[6])
#define TIOCSETN	_IOW('t', 10, char[6])

#define TIOCSETC	_IOW('t', 17, char[6])
#define TIOCGETC	_IOR('t', 18, char[6])
#define TCGETS		_IOR('t', 19, char[44])
#define TCSETS		_IOW('t', 20, char[44])
#define TCSETSW		_IOW('t', 21, char[44])
#define TCSETSF		_IOW('t', 22, char[44])

#define TCGETA		_IOR('t', 23, char[20])
#define TCSETA		_IOW('t', 24, char[20])
#define TCSETAW		_IOW('t', 25, char[20])
#define TCSETAF		_IOW('t', 28, char[20])

#define TCSBRK		_IO('t', 29)
#define TCXONC		_IO('t', 30)
#define TCFLSH		_IO('t', 31)

#define TIOCSWINSZ	_IOW('t', 103, char[8])
#define TIOCGWINSZ	_IOR('t', 104, char[8])
#define TIOCSTART	_IO('t', 110)
#define TIOCSTOP	_IO('t', 111)

#define TIOCOUTQ	_IOR('t', 115, int)

#define TIOCGLTC	_IOR('t', 116, char[6])
#define TIOCSLTC	_IOW('t', 117, char[6])
#define TIOCSPGRP	_IOW('t', 118, int)
#define TIOCGPGRP	_IOR('t', 119, int)

#define TIOCEXCL	0x540C
#define TIOCNXCL	0x540D
#define TIOCSCTTY	0x540E

#define TIOCSTI		0x5412
#define TIOCMGET	0x5415
#define TIOCMBIS	0x5416
#define TIOCMBIC	0x5417
#define TIOCMSET	0x5418
#define TIOCM_LE	0x001
#define TIOCM_DTR	0x002
#define TIOCM_RTS	0x004
#define TIOCM_ST	0x008
#define TIOCM_SR	0x010
#define TIOCM_CTS	0x020
#define TIOCM_CAR	0x040
#define TIOCM_RNG	0x080
#define TIOCM_DSR	0x100
#define TIOCM_CD	TIOCM_CAR
#define TIOCM_RI	TIOCM_RNG
#define TIOCM_OUT1	0x2000
#define TIOCM_OUT2	0x4000
#define TIOCM_LOOP	0x8000

#define TIOCGSOFTCAR	0x5419
#define TIOCSSOFTCAR	0x541A
#define TIOCLINUX	0x541C
#define TIOCCONS	0x541D
#define TIOCGSERIAL	0x541E
#define TIOCSSERIAL	0x541F
#define TIOCPKT	0x5420

#define TIOCNOTTY	0x5422
#define TIOCSETD	0x5423
#define TIOCGETD	0x5424
#define TCSBRKP		0x5425
#define TIOCSBRK	0x5427
#define TIOCCBRK	0x5428
#define TIOCGSID	0x5429
#define TIOCGRS485	0x542e
#define TIOCSRS485	0x542f
#define TIOCGPTN	_IOR('T',0x30, unsigned int)
#define TIOCSPTLCK	_IOW('T',0x31, int)
#define TIOCGDEV	_IOR('T',0x32, unsigned int)
#define TIOCSIG		_IOW('T',0x36, int)
#define TIOCVHANGUP	0x5437
#define TIOCGPKT	_IOR('T', 0x38, int)
#define TIOCGPTLCK	_IOR('T', 0x39, int)
#define TIOCGEXCL	_IOR('T', 0x40, int)
#define TIOCGPTPEER	_IO('T', 0x41)

#define TIOCSERCONFIG	0x5453
#define TIOCSERGWILD	0x5454
#define TIOCSERSWILD	0x5455
#define TIOCGLCKTRMIOS	0x5456
#define TIOCSLCKTRMIOS	0x5457
#define TIOCSERGSTRUCT	0x5458
#define TIOCSERGETLSR	0x5459
#define TIOCSERGETMULTI	0x545A
#define TIOCSERSETMULTI	0x545B

#define TIOCMIWAIT	0x545C
#define TIOCGICOUNT	0x545D

#define FIOSETOWN       0x8901
#define SIOCSPGRP       0x8902
#define FIOGETOWN       0x8903
#define SIOCGPGRP       0x8904
#define SIOCATMARK      0x8905
#define SIOCGSTAMP      _IOR(0x89, 6, char[16])
#define SIOCGSTAMPNS    _IOR(0x89, 7, char[16])
