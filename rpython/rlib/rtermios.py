# This are here only because it's always better safe than sorry.
# The issue is that from-time-to-time CPython's termios.tcgetattr
# returns list of mostly-strings of length one, but with few ints
# inside, so we make sure it works

import sys
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo

from rpython.rlib import rposix
from rpython.rlib.rarithmetic import intmask

eci = ExternalCompilationInfo(
    includes = ['termios.h', 'unistd.h', 'sys/ioctl.h']
)

class CConfig:
    _compilation_info_ = eci
    _HAVE_STRUCT_TERMIOS_C_ISPEED = rffi_platform.Defined(
            '_HAVE_STRUCT_TERMIOS_C_ISPEED')
    _HAVE_STRUCT_TERMIOS_C_OSPEED = rffi_platform.Defined(
            '_HAVE_STRUCT_TERMIOS_C_OSPEED')

CONSTANT_NAMES = (
    # cfgetospeed(), cfsetospeed() constants
    """B0 B50 B75 B110 B134 B150 B200 B300 B600 B1200 B1800 B2400 B4800 B9600
       B19200 B38400 B57600 B115200 B230400 B460800 CBAUDEX
    """
    # tcsetattr() constants
    """TCSANOW TCSADRAIN TCSAFLUSH TCSASOFT
    """
    # tcflush() constants
    """TCIFLUSH TCOFLUSH TCIOFLUSH
    """
    # tcflow() constants
    """TCOOFF TCOON TCIOFF TCION
    """
    # struct termios.c_iflag constants
    """IGNBRK BRKINT IGNPAR PARMRK INPCK ISTRIP INLCR IGNCR ICRNL IUCLC 
       IXON IXANY IXOFF IMAXBEL
    """
    # struct termios.c_oflag constants
    """OPOST OLCUC ONLCR OCRNL ONOCR ONLRET OFILL OFDEL
       NLDLY CRDLY TABDLY BSDLY VTDLY FFDLY
    """
    # struct termios.c_oflag-related values (delay mask)
    """NL0 NL1 CR0 CR1 CR2 CR3 TAB0 TAB1 TAB2 TAB3 XTABS
       BS0 BS1 VT0 VT1 FF0 FF1
    """
    # struct termios.c_cflag constants
    """CSIZE CSTOPB CREAD PARENB PARODD HUPCL CLOCAL CIBAUD CRTSCTS
    """
    # struct termios.c_cflag-related values (character size)
    """CS5 CS6 CS7 CS8
    """
    # struct termios.c_lflag constants
    """ISIG ICANON XCASE ECHO ECHOE ECHOK ECHONL ECHOCTL ECHOPRT ECHOKE
       FLUSHO NOFLSH TOSTOP PENDIN IEXTEN
    """
    # indexes into the control chars array returned by tcgetattr()
    """VINTR VQUIT VERASE VKILL VEOF VTIME VMIN VSWTC VSWTCH VSTART VSTOP
       VSUSP VEOL VREPRINT VDISCARD VWERASE VLNEXT VEOL2
    """
    # Others?
    """CBAUD CDEL CDSUSP CEOF CEOL CEOL2 CEOT CERASE CESC CFLUSH CINTR CKILL
       CLNEXT CNUL COMMON CQUIT CRPRNT CSTART CSTOP CSUSP CSWTCH CWERASE
       EXTA EXTB
       FIOASYNC FIOCLEX FIONBIO FIONCLEX FIONREAD
       IBSHIFT INIT_C_CC IOCSIZE_MASK IOCSIZE_SHIFT
       NCC NCCS NSWTCH N_MOUSE N_PPP N_SLIP N_STRIP N_TTY
       TCFLSH TCGETA TCGETS TCSBRK TCSBRKP TCSETA TCSETAF TCSETAW TCSETS
       TCSETSF TCSETSW TCXONC
       TIOCCONS TIOCEXCL TIOCGETD TIOCGICOUNT TIOCGLCKTRMIOS TIOCGPGRP
       TIOCGSERIAL TIOCGSOFTCAR TIOCGWINSZ TIOCINQ TIOCLINUX TIOCMBIC
       TIOCMBIS TIOCMGET TIOCMIWAIT TIOCMSET TIOCM_CAR TIOCM_CD TIOCM_CTS 
       TIOCM_DSR TIOCM_DTR TIOCM_LE TIOCM_RI TIOCM_RNG TIOCM_RTS TIOCM_SR
       TIOCM_ST TIOCNOTTY TIOCNXCL TIOCOUTQ TIOCPKT TIOCPKT_DATA
       TIOCPKT_DOSTOP TIOCPKT_FLUSHREAD TIOCPKT_FLUSHWRITE TIOCPKT_NOSTOP
       TIOCPKT_START TIOCPKT_STOP TIOCSCTTY TIOCSERCONFIG TIOCSERGETLSR 
       TIOCSERGETMULTI TIOCSERGSTRUCT TIOCSERGWILD TIOCSERSETMULTI
       TIOCSERSWILD TIOCSER_TEMT TIOCSETD TIOCSLCKTRMIOS TIOCSPGRP
       TIOCSSERIAL TIOCSSOFTCAR TIOCSTI TIOCSWINSZ TIOCTTYGSTRUCT
    """).split()
    
for name in CONSTANT_NAMES:
    setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))

c_config = rffi_platform.configure(CConfig)

# Copy VSWTCH to VSWTC and vice-versa
if c_config['VSWTC'] is None:
    c_config['VSWTC'] = c_config['VSWTCH']
if c_config['VSWTCH'] is None:
    c_config['VSWTCH'] = c_config['VSWTC']

all_constants = {}
for name in CONSTANT_NAMES:
    value = c_config[name]
    if value is not None:
        if value < -sys.maxsize-1 or value >= 2 * (sys.maxsize+1):
            raise AssertionError("termios: %r has value %r, too large" % (
                name, value))
        value = intmask(value)     # wrap unsigned long numbers to signed longs
        globals()[name] = value
        all_constants[name] = value
            
TCFLAG_T = rffi.UINT
CC_T = rffi.UCHAR
SPEED_T = rffi.UINT

_add = []
if c_config['_HAVE_STRUCT_TERMIOS_C_ISPEED']:
    _add.append(('c_ispeed', SPEED_T))
if c_config['_HAVE_STRUCT_TERMIOS_C_OSPEED']:
    _add.append(('c_ospeed', SPEED_T))
TERMIOSP = rffi.CStructPtr('termios', ('c_iflag', TCFLAG_T), ('c_oflag', TCFLAG_T),
                           ('c_cflag', TCFLAG_T), ('c_lflag', TCFLAG_T),
                           ('c_line', CC_T),
                           ('c_cc', lltype.FixedSizeArray(CC_T, NCCS)), *_add)

def c_external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci, **kwds)

c_tcgetattr = c_external('tcgetattr', [rffi.INT, TERMIOSP], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
c_tcsetattr = c_external('tcsetattr', [rffi.INT, rffi.INT, TERMIOSP], rffi.INT,
                         save_err=rffi.RFFI_SAVE_ERRNO)
c_cfgetispeed = c_external('cfgetispeed', [TERMIOSP], SPEED_T)
c_cfgetospeed = c_external('cfgetospeed', [TERMIOSP], SPEED_T)
c_cfsetispeed = c_external('cfsetispeed', [TERMIOSP, SPEED_T], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
c_cfsetospeed = c_external('cfsetospeed', [TERMIOSP, SPEED_T], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)

c_tcsendbreak = c_external('tcsendbreak', [rffi.INT, rffi.INT], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
c_tcdrain = c_external('tcdrain', [rffi.INT], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)
c_tcflush = c_external('tcflush', [rffi.INT, rffi.INT], rffi.INT,
                       save_err=rffi.RFFI_SAVE_ERRNO)
c_tcflow = c_external('tcflow', [rffi.INT, rffi.INT], rffi.INT,
                      save_err=rffi.RFFI_SAVE_ERRNO)


def tcgetattr(fd):
    with lltype.scoped_alloc(TERMIOSP.TO) as c_struct:
        if c_tcgetattr(fd, c_struct) < 0:
            raise OSError(rposix.get_saved_errno(), 'tcgetattr failed')
        cc = [chr(c_struct.c_c_cc[i]) for i in range(NCCS)]
        ispeed = c_cfgetispeed(c_struct)
        ospeed = c_cfgetospeed(c_struct)
        result = (intmask(c_struct.c_c_iflag), intmask(c_struct.c_c_oflag),
                  intmask(c_struct.c_c_cflag), intmask(c_struct.c_c_lflag),
                  intmask(ispeed), intmask(ospeed), cc)
        return result


# This function is not an exact replacement of termios.tcsetattr:
# the last attribute must be a list of chars.
def tcsetattr(fd, when, attributes):
    with lltype.scoped_alloc(TERMIOSP.TO) as c_struct:
        rffi.setintfield(c_struct, 'c_c_iflag', attributes[0])
        rffi.setintfield(c_struct, 'c_c_oflag', attributes[1])
        rffi.setintfield(c_struct, 'c_c_cflag', attributes[2])
        rffi.setintfield(c_struct, 'c_c_lflag', attributes[3])
        ispeed = attributes[4]
        ospeed = attributes[5]
        cc = attributes[6]
        for i in range(NCCS):
            c_struct.c_c_cc[i] = rffi.r_uchar(ord(cc[i][0]))
        if c_cfsetispeed(c_struct, ispeed) < 0:
            raise OSError(rposix.get_saved_errno(), 'tcsetattr failed')
        if c_cfsetospeed(c_struct, ospeed) < 0:
            raise OSError(rposix.get_saved_errno(), 'tcsetattr failed')
        if c_tcsetattr(fd, when, c_struct) < 0:
            raise OSError(rposix.get_saved_errno(), 'tcsetattr failed')

def tcsendbreak(fd, duration):
    if c_tcsendbreak(fd, duration) < 0:
        raise OSError(rposix.get_saved_errno(), 'tcsendbreak failed')

def tcdrain(fd):
    if c_tcdrain(fd) < 0:
        raise OSError(rposix.get_saved_errno(), 'tcdrain failed')

def tcflush(fd, queue_selector):
    if c_tcflush(fd, queue_selector) < 0:
        raise OSError(rposix.get_saved_errno(), 'tcflush failed')

def tcflow(fd, action):
    if c_tcflow(fd, action) < 0:
        raise OSError(rposix.get_saved_errno(), 'tcflow failed')
