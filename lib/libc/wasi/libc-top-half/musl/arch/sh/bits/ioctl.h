#define _IOC(a,b,c,d) ( ((a)<<30) | ((b)<<8) | (c) | ((d)<<16) )
#define _IOC_NONE  0U
#define _IOC_WRITE 1U
#define _IOC_READ  2U

#define _IO(a,b) _IOC(_IOC_NONE,(a),(b),0)
#define _IOW(a,b,c) _IOC(_IOC_WRITE,(a),(b),sizeof(c))
#define _IOR(a,b,c) _IOC(_IOC_READ,(a),(b),sizeof(c))
#define _IOWR(a,b,c) _IOC(_IOC_READ|_IOC_WRITE,(a),(b),sizeof(c))

#define FIOCLEX             _IO('f',  1)
#define FIONCLEX            _IO('f',  2)
#define FIOASYNC            _IOW('f', 125, int)
#define FIONBIO             _IOW('f', 126, int)
#define FIONREAD            _IOR('f', 127, int)
#define TIOCINQ             FIONREAD
#define FIOQSIZE            _IOR('f', 128, char[8])

#define TCGETA              _IOR('t', 23, char[18])
#define TCSETA              _IOW('t', 24, char[18])
#define TCSETAW             _IOW('t', 25, char[18])
#define TCSETAF             _IOW('t', 28, char[18])

#define TCSBRK              _IO('t', 29)
#define TCXONC              _IO('t', 30)
#define TCFLSH              _IO('t', 31)

#define TIOCSWINSZ          _IOW('t', 103, char[8])
#define TIOCGWINSZ          _IOR('t', 104, char[8])
#define TIOCSTART           _IO('t',  110)
#define TIOCSTOP            _IO('t',  111)
#define TIOCOUTQ            _IOR('t', 115, int)

#define TIOCSPGRP           _IOW('t', 118, int)
#define TIOCGPGRP           _IOR('t', 119, int)

#define TIOCEXCL            _IO('T', 12)
#define TIOCNXCL            _IO('T', 13)
#define TIOCSCTTY           _IO('T', 14)

#define TIOCSTI             _IOW('T', 18, char)
#define TIOCMGET            _IOR('T', 21, unsigned int)
#define TIOCMBIS            _IOW('T', 22, unsigned int)
#define TIOCMBIC            _IOW('T', 23, unsigned int)
#define TIOCMSET            _IOW('T', 24, unsigned int)
#define TIOCM_LE            0x001
#define TIOCM_DTR           0x002
#define TIOCM_RTS           0x004
#define TIOCM_ST            0x008
#define TIOCM_SR            0x010
#define TIOCM_CTS           0x020
#define TIOCM_CAR           0x040
#define TIOCM_RNG           0x080
#define TIOCM_DSR           0x100
#define TIOCM_CD            TIOCM_CAR
#define TIOCM_RI            TIOCM_RNG
#define TIOCM_OUT1          0x2000
#define TIOCM_OUT2          0x4000
#define TIOCM_LOOP          0x8000

#define TIOCGSOFTCAR        _IOR('T', 25, unsigned int)
#define TIOCSSOFTCAR        _IOW('T', 26, unsigned int)
#define TIOCLINUX           _IOW('T', 28, char)
#define TIOCCONS            _IO('T',  29)
#define TIOCGSERIAL         _IOR('T', 30, char[60])
#define TIOCSSERIAL         _IOW('T', 31, char[60])
#define TIOCPKT             _IOW('T', 32, int)

#define TIOCNOTTY           _IO('T',  34)
#define TIOCSETD            _IOW('T', 35, int)
#define TIOCGETD            _IOR('T', 36, int)
#define TCSBRKP             _IOW('T', 37, int)
#define TIOCSBRK            _IO('T',  39)
#define TIOCCBRK            _IO('T',  40)
#define TIOCGSID            _IOR('T', 41, int)
#define TCGETS              _IO('T', 1)
#define TCSETS              _IO('T', 2)
#define TCSETSW             _IO('T', 3)
#define TCSETSF             _IO('T', 4)
#define TIOCGRS485          _IOR('T', 46, char[32])
#define TIOCSRS485          _IOWR('T', 47, char[32])
#define TIOCGPTN            _IOR('T', 48, unsigned int)
#define TIOCSPTLCK          _IOW('T', 49, int)
#define TIOCGDEV            _IOR('T', 50, unsigned int)
#define TIOCSIG             _IOW('T', 54, int)
#define TIOCVHANGUP         _IO('T',  55)
#define TIOCGPKT            _IOR('T', 56, int)
#define TIOCGPTLCK          _IOR('T', 57, int)
#define TIOCGEXCL           _IOR('T', 64, int)
#define TIOCGPTPEER         _IO('T', 0x41)

#define TIOCSERCONFIG       _IO('T',  83)
#define TIOCSERGWILD        _IOR('T', 84, int)
#define TIOCSERSWILD        _IOW('T', 85, int)
#define TIOCGLCKTRMIOS      _IO('T',  86)
#define TIOCSLCKTRMIOS      _IO('T',  87)
#define TIOCSERGSTRUCT      _IOR('T', 88, char[216])
#define TIOCSERGETLSR       _IOR('T', 89, unsigned int)
#define TIOCSERGETMULTI     _IOR('T', 90, char[168])
#define TIOCSERSETMULTI     _IOW('T', 91, char[168])

#define TIOCMIWAIT          _IO('T', 92)
#define TIOCGICOUNT         _IO('T', 93)

#define FIOGETOWN       _IOR('f', 123, int)
#define FIOSETOWN       _IOW('f', 124, int)

#define SIOCATMARK      _IOR('s', 7, int)
#define SIOCSPGRP       _IOW('s', 8, int)
#define SIOCGPGRP       _IOW('s', 9, int)
#define SIOCGSTAMP      _IOR(0x89, 6, char[16])
#define SIOCGSTAMPNS    _IOR(0x89, 7, char[16])
