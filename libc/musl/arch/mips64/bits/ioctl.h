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

#define TIOCPKT_DATA		 0
#define TIOCPKT_FLUSHREAD	 1
#define TIOCPKT_FLUSHWRITE	 2
#define TIOCPKT_STOP		 4
#define TIOCPKT_START		 8
#define TIOCPKT_NOSTOP		16
#define TIOCPKT_DOSTOP		32
#define TIOCPKT_IOCTL		64

#define TIOCSER_TEMT    0x01

struct winsize {
	unsigned short ws_row;
	unsigned short ws_col;
	unsigned short ws_xpixel;
	unsigned short ws_ypixel;
};

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

#define N_TTY           0
#define N_SLIP          1
#define N_MOUSE         2
#define N_PPP           3
#define N_STRIP         4
#define N_AX25          5
#define N_X25           6
#define N_6PACK         7
#define N_MASC          8
#define N_R3964         9
#define N_PROFIBUS_FDL  10
#define N_IRDA          11
#define N_SMSBLOCK      12
#define N_HDLC          13
#define N_SYNC_PPP      14
#define N_HCI           15

#define FIOGETOWN       _IOR('f', 123, int)
#define FIOSETOWN       _IOW('f', 124, int)
#define SIOCATMARK      _IOR('s', 7, int)
#define SIOCSPGRP       _IOW('s', 8, pid_t)
#define SIOCGPGRP       _IOR('s', 9, pid_t)
#define SIOCGSTAMP      0x8906
#define SIOCGSTAMPNS    0x8907

#define SIOCADDRT       0x890B
#define SIOCDELRT       0x890C
#define SIOCRTMSG       0x890D

#define SIOCGIFNAME     0x8910
#define SIOCSIFLINK     0x8911
#define SIOCGIFCONF     0x8912
#define SIOCGIFFLAGS    0x8913
#define SIOCSIFFLAGS    0x8914
#define SIOCGIFADDR     0x8915
#define SIOCSIFADDR     0x8916
#define SIOCGIFDSTADDR  0x8917
#define SIOCSIFDSTADDR  0x8918
#define SIOCGIFBRDADDR  0x8919
#define SIOCSIFBRDADDR  0x891a
#define SIOCGIFNETMASK  0x891b
#define SIOCSIFNETMASK  0x891c
#define SIOCGIFMETRIC   0x891d
#define SIOCSIFMETRIC   0x891e
#define SIOCGIFMEM      0x891f
#define SIOCSIFMEM      0x8920
#define SIOCGIFMTU      0x8921
#define SIOCSIFMTU      0x8922
#define SIOCSIFNAME     0x8923
#define SIOCSIFHWADDR   0x8924
#define SIOCGIFENCAP    0x8925
#define SIOCSIFENCAP    0x8926
#define SIOCGIFHWADDR   0x8927
#define SIOCGIFSLAVE    0x8929
#define SIOCSIFSLAVE    0x8930
#define SIOCADDMULTI    0x8931
#define SIOCDELMULTI    0x8932
#define SIOCGIFINDEX    0x8933
#define SIOGIFINDEX     SIOCGIFINDEX
#define SIOCSIFPFLAGS   0x8934
#define SIOCGIFPFLAGS   0x8935
#define SIOCDIFADDR     0x8936
#define SIOCSIFHWBROADCAST 0x8937
#define SIOCGIFCOUNT    0x8938

#define SIOCGIFBR       0x8940
#define SIOCSIFBR       0x8941

#define SIOCGIFTXQLEN   0x8942
#define SIOCSIFTXQLEN   0x8943

#define SIOCDARP        0x8953
#define SIOCGARP        0x8954
#define SIOCSARP        0x8955

#define SIOCDRARP       0x8960
#define SIOCGRARP       0x8961
#define SIOCSRARP       0x8962

#define SIOCGIFMAP      0x8970
#define SIOCSIFMAP      0x8971

#define SIOCADDDLCI     0x8980
#define SIOCDELDLCI     0x8981

#define SIOCDEVPRIVATE		0x89F0
#define SIOCPROTOPRIVATE	0x89E0
