#define _IOC(a,b,c,d) ( ((a)<<29) | ((b)<<8) | (c) | ((d)<<16) )
#define _IOC_NONE  1U
#define _IOC_READ  2U
#define _IOC_WRITE 4U

#define _IO(a,b) _IOC(_IOC_NONE,(a),(b),0)
#define _IOW(a,b,c) _IOC(_IOC_WRITE,(a),(b),sizeof(c))
#define _IOR(a,b,c) _IOC(_IOC_READ,(a),(b),sizeof(c))
#define _IOWR(a,b,c) _IOC(_IOC_READ|_IOC_WRITE,(a),(b),sizeof(c))

#define TCGETA		0x5401
#define TCSETA		0x5402
#define TCSETAW		0x5403
#define TCSETAF		0x5404
#define TCSBRK		0x5405
#define TCXONC		0x5406
#define TCFLSH		0x5407
#define TCGETS		0x540D
#define TCSETS		0x540E
#define TCSETSW		0x540F
#define TCSETSF		0x5410

#define TIOCEXCL	0x740D
#define TIOCNXCL	0x740E
#define TIOCOUTQ	0x7472
#define TIOCSTI		0x5472
#define TIOCMGET	0x741D
#define TIOCMBIS	0x741B
#define TIOCMBIC	0x741C
#define TIOCMSET	0x741A

#define TIOCPKT		0x5470
#define TIOCSWINSZ	_IOW('t', 103, struct winsize)
#define TIOCGWINSZ	_IOR('t', 104, struct winsize)
#define TIOCNOTTY	0x5471
#define TIOCSETD	0x7401
#define TIOCGETD	0x7400

#define FIOCLEX		0x6601
#define FIONCLEX	0x6602
#define FIOASYNC	0x667D
#define FIONBIO		0x667E
#define FIOQSIZE	0x667F

#define TIOCGLTC        0x7474
#define TIOCSLTC        0x7475
#define TIOCSPGRP	_IOW('t', 118, int)
#define TIOCGPGRP	_IOR('t', 119, int)
#define TIOCCONS	_IOW('t', 120, int)

#define FIONREAD	0x467F
#define TIOCINQ		FIONREAD

#define TIOCGETP        0x7408
#define TIOCSETP        0x7409
#define TIOCSETN        0x740A

#define TIOCSBRK	0x5427
#define TIOCCBRK	0x5428
#define TIOCGSID	0x7416
#define TIOCGRS485	_IOR('T', 0x2E, char[32])
#define TIOCSRS485	_IOWR('T', 0x2F, char[32])
#define TIOCGPTN	_IOR('T', 0x30, unsigned int)
#define TIOCSPTLCK	_IOW('T', 0x31, int)
#define TIOCGDEV	_IOR('T', 0x32, unsigned int)
#define TIOCSIG		_IOW('T', 0x36, int)
#define TIOCVHANGUP	0x5437
#define TIOCGPKT	_IOR('T', 0x38, int)
#define TIOCGPTLCK	_IOR('T', 0x39, int)
#define TIOCGEXCL	_IOR('T', 0x40, int)
#define TIOCGPTPEER	_IO('T', 0x41)

#define TIOCSCTTY	0x5480
#define TIOCGSOFTCAR	0x5481
#define TIOCSSOFTCAR	0x5482
#define TIOCLINUX	0x5483
#define TIOCGSERIAL	0x5484
#define TIOCSSERIAL	0x5485
#define TCSBRKP		0x5486

#define TIOCSERCONFIG	0x5488
#define TIOCSERGWILD	0x5489
#define TIOCSERSWILD	0x548A
#define TIOCGLCKTRMIOS	0x548B
#define TIOCSLCKTRMIOS	0x548C
#define TIOCSERGSTRUCT	0x548D
#define TIOCSERGETLSR   0x548E
#define TIOCSERGETMULTI 0x548F
#define TIOCSERSETMULTI 0x5490
#define TIOCMIWAIT	0x5491
#define TIOCGICOUNT	0x5492

#define TIOCM_LE	0x001
#define TIOCM_DTR	0x002
#define TIOCM_RTS	0x004
#define TIOCM_ST	0x010
#define TIOCM_SR	0x020
#define TIOCM_CTS	0x040
#define TIOCM_CAR	0x100
#define TIOCM_CD	TIOCM_CAR
#define TIOCM_RNG	0x200
#define TIOCM_RI	TIOCM_RNG
#define TIOCM_DSR	0x400
#define TIOCM_OUT1	0x2000
#define TIOCM_OUT2	0x4000
#define TIOCM_LOOP	0x8000

#define FIOGETOWN       _IOR('f', 123, int)
#define FIOSETOWN       _IOW('f', 124, int)
#define SIOCATMARK      _IOR('s', 7, int)
#define SIOCSPGRP       _IOW('s', 8, pid_t)
#define SIOCGPGRP       _IOR('s', 9, pid_t)
#define SIOCGSTAMP      0x8906
#define SIOCGSTAMPNS    0x8907
