from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.tool import rffi_platform as platform
from rpython.rtyper.lltypesystem.rffi import CCHARP, CONST_CCHARP
from rpython.rlib import jit
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import platform as target_platform

from rpython.rlib.rarithmetic import intmask, r_uint
import os,sys

_POSIX = os.name == "posix"
_WIN32 = sys.platform == "win32"
_MSVC  = target_platform.name == "msvc"
_MINGW = target_platform.name == "mingw32"
_SOLARIS = sys.platform == "sunos5"
_MACOSX = sys.platform == "darwin"
_HAS_AF_PACKET = sys.platform.startswith('linux')   # only Linux for now

if _POSIX:
    includes = ('sys/types.h',
                'sys/socket.h',
                'sys/un.h',
                'poll.h',
                'sys/select.h',
                'sys/types.h',
                'netinet/in.h',
                'netinet/tcp.h',
                'unistd.h',
                'fcntl.h',
                'stdio.h',
                'netdb.h',
                'arpa/inet.h',
                'stdint.h',
                'errno.h',
                'limits.h',
                )
    if _HAS_AF_PACKET:
        includes += ('netpacket/packet.h',
                     'sys/ioctl.h',
                     'net/if.h')

    cond_includes = [('AF_NETLINK', 'linux/netlink.h')]

    libraries = ()
    calling_conv = 'c'
    HEADER = ''.join(['#include <%s>\n' % filename for filename in includes])
    COND_HEADER = ''.join(['#ifdef %s\n#include <%s>\n#endif\n' % cond_include
                          for cond_include in cond_includes])

if _SOLARIS:
    libraries = libraries + ('socket', 'nsl')

if _WIN32:
    includes = ()
    libraries = ('ws2_32',)
    calling_conv = 'win'
    header_lines = [
        '#include <WinSock2.h>',
        '#include <WS2tcpip.h>',
        # winsock2 defines AF_UNIX, but not sockaddr_un
        '#undef AF_UNIX',
        ]
    if _MSVC:
        header_lines.extend([
            '#include <Mstcpip.h>',
            # these types do not exist on microsoft compilers
            '#ifdef _WIN64',
            'typedef long long ssize_t;',
            'typedef unsigned long long size_t;',
            '#else',
            'typedef int ssize_t;',
            'typedef unsigned int size_t;',
            '#endif',
            'typedef unsigned __int16 uint16_t;',
            'typedef unsigned __int32 uint32_t;',
            ])
    else: # MINGW
        includes = ('stdint.h',)
        header_lines.extend([
            '''\
            #ifndef _WIN32_WINNT
            #define _WIN32_WINNT 0x0501
            #endif''',
            '#define SIO_RCVALL             _WSAIOW(IOC_VENDOR,1)',
            '#define SIO_KEEPALIVE_VALS     _WSAIOW(IOC_VENDOR,4)',
            '#define RCVALL_OFF             0',
            '#define RCVALL_ON              1',
            '#define RCVALL_SOCKETLEVELONLY 2',
            '''\
            #ifndef __MINGW32__
            struct tcp_keepalive {
                u_long  onoff;
                u_long  keepalivetime;
                u_long  keepaliveinterval;
            };
            #endif
            '''
            ])
    HEADER = '\n'.join(header_lines)
    COND_HEADER = ''
constants = {}

eci = ExternalCompilationInfo(
    post_include_bits = [HEADER, COND_HEADER],
    includes = includes,
    libraries = libraries,
)

class CConfig:
    _compilation_info_ = eci
    # constants
    linux = platform.Defined('linux')
    WIN32 = platform.Defined('_WIN32')

    O_RDONLY = platform.DefinedConstantInteger('O_RDONLY')
    O_WRONLY = platform.DefinedConstantInteger('O_WRONLY')
    O_RDWR = platform.DefinedConstantInteger('O_RDWR')
    O_NONBLOCK = platform.DefinedConstantInteger('O_NONBLOCK')
    F_GETFL = platform.DefinedConstantInteger('F_GETFL')
    F_SETFL = platform.DefinedConstantInteger('F_SETFL')
    FIONBIO = platform.DefinedConstantInteger('FIONBIO')
    PIPE_BUF = platform.DefinedConstantInteger('PIPE_BUF')

    INVALID_SOCKET = platform.DefinedConstantInteger('INVALID_SOCKET')
    INET_ADDRSTRLEN = platform.DefinedConstantInteger('INET_ADDRSTRLEN')
    INET6_ADDRSTRLEN= platform.DefinedConstantInteger('INET6_ADDRSTRLEN')
    EINTR = platform.DefinedConstantInteger('EINTR')
    WSAEINTR = platform.DefinedConstantInteger('WSAEINTR')
    EINPROGRESS = platform.DefinedConstantInteger('EINPROGRESS')
    WSAEINPROGRESS = platform.DefinedConstantInteger('WSAEINPROGRESS')
    EWOULDBLOCK = platform.DefinedConstantInteger('EWOULDBLOCK')
    WSAEWOULDBLOCK = platform.DefinedConstantInteger('WSAEWOULDBLOCK')
    EAFNOSUPPORT = platform.DefinedConstantInteger('EAFNOSUPPORT')
    WSAEAFNOSUPPORT = platform.DefinedConstantInteger('WSAEAFNOSUPPORT')
    EISCONN = platform.DefinedConstantInteger('EISCONN')
    WSAEISCONN = platform.DefinedConstantInteger('WSAEISCONN')
constant_names = '''
AF_AAL5 AF_APPLETALK AF_ASH AF_ATMPVC AF_ATMSVC AF_AX25 AF_BLUETOOTH AF_BRIDGE
AD_DECnet AF_ECONET AF_INET AF_INET6 AF_IPX AF_IRDA AF_KEY AF_LLC AF_NETBEUI
AF_NETLINK AF_NETROM AF_PACKET AF_PPPOX AF_ROSE AF_ROUTE AF_SECURITY AF_SNA
AF_UNIX AF_WANPIPE AF_X25 AF_UNSPEC

AI_ADDRCONFIG AI_ALL AI_CANONNAME AI_DEFAULT AI_MASK AI_NUMERICHOST
AI_NUMERICSERV AI_PASSIVE AI_V4MAPPED AI_V4MAPPED_CFG

BTPROTO_L2CAP BTPROTO_SCO BTPROTO_RFCOMM

EAI_ADDRFAMILY EAI_AGAIN EAI_BADFLAGS EAI_BADHINTS EAI_FAIL EAI_FAMILY EAI_MAX
EAI_MEMORY EAI_NODATA EAI_NONAME EAI_OVERFLOW EAI_PROTOCOL EAI_SERVICE
EAI_SOCKTYPE EAI_SYSTEM

IPPROTO_AH IPPROTO_BIP IPPROTO_DSTOPTS IPPROTO_EGP IPPROTO_EON IPPROTO_ESP
IPPROTO_FRAGMENT IPPROTO_GGP IPPROTO_GRE IPPROTO_HELLO IPPROTO_HOPOPTS
IPPROTO_ICMPV6 IPPROTO_IDP IPPROTO_IGMP IPPROTO_IPCOMP IPPROTO_IPIP
IPPROTO_IPV4 IPPROTO_IPV6 IPPROTO_MAX IPPROTO_MOBILE IPPROTO_ND IPPROTO_NONE
IPPROTO_PIM IPPROTO_PUP IPPROTO_ROUTING IPPROTO_RSVP IPPROTO_TCP IPPROTO_TP
IPPROTO_VRRP IPPROTO_XTP IPPROTO_SCTP

IPV6_CHECKSUM IPV6_DONTFRAG IPV6_DSTOPTS IPV6_HOPLIMIT IPV6_HOPOPTS
IPV6_JOIN_GROUP IPV6_LEAVE_GROUP IPV6_MULTICAST_HOPS IPV6_MULTICAST_IF
IPV6_MULTICAST_LOOP IPV6_NEXTHOP IPV6_PATHMTU IPV6_PKTINFO IPV6_RECVDSTOPTS
IPV6_RECVHOPLIMIT IPV6_RECVHOPOPTS IPV6_RECVPATHMTU IPV6_RECVPKTINFO
IPV6_RECVRTHDR IPV6_RECVTCLASS IPV6_RTHDR IPV6_RTHDRDSTOPTS IPV6_RTHDR_TYPE_0
IPV6_TCLASS IPV6_UNICAST_HOPS IPV6_USE_MIN_MTU IPV6_V6ONLY

IP_ADD_MEMBERSHIP IP_DEFAULT_MULTICAST_LOOP IP_DEFAULT_MULTICAST_TTL
IP_DROP_MEMBERSHIP IP_HDRINCL IP_MAX_MEMBERSHIPS IP_MULTICAST_IF
IP_MULTICAST_LOOP IP_MULTICAST_TTL IP_OPTIONS IP_RECVDSTADDR IP_RECVOPTS
IP_RECVRETOPTS IP_RETOPTS IP_TOS IP_TTL

MSG_BTAG MSG_ETAG MSG_CTRUNC MSG_DONTROUTE MSG_DONTWAIT MSG_EOR MSG_OOB
MSG_PEEK MSG_TRUNC MSG_WAITALL MSG_ERRQUEUE

NI_DGRAM NI_MAXHOST NI_MAXSERV NI_NAMEREQD NI_NOFQDN NI_NUMERICHOST
NI_NUMERICSERV

NETLINK_ROUTE NETLINK_SKIP NETLINK_W1 NETLINK_USERSOCK NETLINK_FIREWALL
NETLINK_TCPDIAG NETLINK_NFLOG NETLINK_XFRM NETLINK_ARPD NETLINK_ROUTE6
NETLINK_IP6_FW NETLINK_DNRTMSG NETLINK_TAPBASE


PACKET_HOST PACKET_BROADCAST PACKET_MULTICAST PACKET_OTHERHOST PACKET_OUTGOING
PACKET_LOOPBACK PACKET_FASTROUTE


SOCK_DGRAM SOCK_RAW SOCK_RDM SOCK_SEQPACKET SOCK_STREAM
SOCK_CLOEXEC SOCK_NONBLOCK

SOL_SOCKET SOL_IPX SOL_AX25 SOL_ATALK SOL_NETROM SOL_ROSE

SO_ACCEPTCONN SO_BROADCAST SO_DEBUG SO_DONTROUTE SO_ERROR SO_EXCLUSIVEADDRUSE
SO_KEEPALIVE SO_LINGER SO_OOBINLINE SO_RCVBUF SO_RCVLOWAT SO_RCVTIMEO
SO_REUSEADDR SO_REUSEPORT SO_SNDBUF SO_SNDLOWAT SO_SNDTIMEO SO_TYPE
SO_USELOOPBACK

TCP_CORK TCP_DEFER_ACCEPT TCP_INFO TCP_KEEPCNT TCP_KEEPIDLE TCP_KEEPINTVL
TCP_LINGER2 TCP_MAXSEG TCP_NODELAY TCP_QUICKACK TCP_SYNCNT TCP_WINDOW_CLAMP

IPX_TYPE

SCM_RIGHTS

POLLIN POLLPRI POLLOUT POLLERR POLLHUP POLLNVAL
POLLRDNORM POLLRDBAND POLLWRNORM POLLWEBAND POLLMSG

FD_READ FD_WRITE FD_ACCEPT FD_CONNECT FD_CLOSE
WSA_WAIT_TIMEOUT WSA_WAIT_FAILED INFINITE
FD_CONNECT_BIT FD_CLOSE_BIT
WSA_IO_PENDING WSA_IO_INCOMPLETE WSA_INVALID_HANDLE
WSA_INVALID_PARAMETER WSA_NOT_ENOUGH_MEMORY WSA_OPERATION_ABORTED
WSA_FLAG_OVERLAPPED
SIO_RCVALL SIO_KEEPALIVE_VALS

SIOCGIFNAME SIOCGIFINDEX

SO_DOMAIN SO_PROTOCOL SO_PEERSEC SO_PASSSEC TCP_USER_TIMEOUT TCP_CONGESTION TCP_NOTSENT_LOWAT
'''.split()

for name in constant_names:
    setattr(CConfig, name, platform.DefinedConstantInteger(name))

if _WIN32:
    # some SDKs define these values with an enum, #ifdef won't work
    for name in ('RCVALL_ON', 'RCVALL_OFF', 'RCVALL_SOCKETLEVELONLY', 'TCP_FASTOPEN'):
        setattr(CConfig, name, platform.ConstantInteger(name))
        constant_names.append(name)

constants["BDADDR_ANY"] =  "00:00:00:00:00:00"
constants["BDADDR_LOCAL"] = "00:00:00:FF:FF:FF"

constants_w_defaults = [('SOL_IP', 0),
                        ('SOL_TCP', 6),
                        ('SOL_UDP', 17),
                        ('SOMAXCONN', 5),
                        ('IPPROTO_IP', 6),
                        ('IPPROTO_IPV6', 41),
                        ('IPPROTO_ICMP', 1),
                        ('IPPROTO_TCP', 6),
                        ('IPPROTO_UDP', 17),
                        ('IPPROTO_RAW', 255),
                        ('IPPORT_RESERVED', 1024),
                        ('IPPORT_USERRESERVED', 5000),
                        ('INADDR_ANY', 0x00000000),
                        ('INADDR_BROADCAST', 0xffffffff),
                        ('INADDR_LOOPBACK', 0x7F000001),
                        ('INADDR_UNSPEC_GROUP', 0xe0000000),
                        ('INADDR_ALLHOSTS_GROUP', 0xe0000001),
                        ('INADDR_MAX_LOCAL_GROUP', 0xe00000ff),
                        ('INADDR_NONE', 0xffffffff),
                        ('SHUT_RD', 0),
                        ('SHUT_WR', 1),
                        ('SHUT_RDWR', 2),
                        ('POLLIN', 1),
                        ('POLLPRI', 2),
                        ('POLLOUT', 4),
                        ('POLLERR', 8),
                        ('POLLHUP', 16),
                        ('FD_SETSIZE', 64),
                        ]
for name, default in constants_w_defaults:
    setattr(CConfig, name, platform.DefinedConstantInteger(name))

# types
if _MSVC:
    socketfd_type = lltype.Unsigned
else:
    socketfd_type = rffi.INT

CConfig.uint16_t = platform.SimpleType('uint16_t', rffi.USHORT)
CConfig.uint32_t = platform.SimpleType('uint32_t', rffi.UINT)
CConfig.size_t = platform.SimpleType('size_t', rffi.INT)
CConfig.ssize_t = platform.SimpleType('ssize_t', rffi.INT)
CConfig.socklen_t = platform.SimpleType('socklen_t', rffi.INT)
sockaddr_ptr = lltype.Ptr(lltype.ForwardReference())
addrinfo_ptr = lltype.Ptr(lltype.ForwardReference())


# struct types
CConfig.sockaddr = platform.Struct('struct sockaddr',
                                             [('sa_family', rffi.INT),
                                   ('sa_data', rffi.CFixedArray(rffi.CHAR, 1))])
CConfig.in_addr = platform.Struct('struct in_addr',
                                         [('s_addr', rffi.UINT)])
CConfig.in6_addr = platform.Struct('struct in6_addr',
                                          [('s6_addr', rffi.CFixedArray(rffi.CHAR, 16))])
CConfig.sockaddr_in = platform.Struct('struct sockaddr_in',
                                        [('sin_family', rffi.INT),
                                         ('sin_port',   rffi.USHORT),
                                         ('sin_addr',   CConfig.in_addr)])

CConfig.sockaddr_in6 = platform.Struct('struct sockaddr_in6',
                                              [('sin6_family', rffi.INT),
                                               ('sin6_port',   rffi.USHORT),
                                               ('sin6_flowinfo', rffi.INT),
                                               ('sin6_addr', CConfig.in6_addr),
                                               ('sin6_scope_id', rffi.INT)])

CConfig.sockaddr_un = platform.Struct('struct sockaddr_un',
                                             [('sun_family', rffi.INT),
                                   ('sun_path', rffi.CFixedArray(rffi.CHAR, 1))],
                                             ifdef='AF_UNIX')

CConfig.sockaddr_nl = platform.Struct('struct sockaddr_nl',
                                             [('nl_family', rffi.INT),
                                              ('nl_pid', rffi.INT),
                                              ('nl_groups', rffi.INT)],
                                             ifdef='AF_NETLINK')

CConfig.addrinfo = platform.Struct('struct addrinfo',
                                     [('ai_flags', rffi.INT),
                                      ('ai_family', rffi.INT),
                                      ('ai_socktype', rffi.INT),
                                      ('ai_protocol', rffi.INT),
                                      ('ai_addrlen', rffi.INT),
                                      ('ai_addr', sockaddr_ptr),
                                      ('ai_canonname', CCHARP),
                                      ('ai_next', addrinfo_ptr)])

CConfig.hostent = platform.Struct('struct hostent',
                                     [('h_name', CCHARP),
                                      ('h_aliases', rffi.CCHARPP),
                                      ('h_addrtype', rffi.INT),
                                      ('h_length', rffi.INT),
                                      ('h_addr_list', rffi.CCHARPP),
                                      ])


CConfig.servent = platform.Struct('struct servent',
                                         [('s_name', CCHARP),
                                          ('s_port', rffi.INT),
                                          ('s_proto', CCHARP),
                                          ])

CConfig.protoent = platform.Struct('struct protoent',
                                          [('p_proto', rffi.INT),
                                           ])

CConfig.HAVE_ACCEPT4 = platform.Has('accept4')

if _POSIX:
    CConfig.nfds_t = platform.SimpleType('nfds_t')
    CConfig.pollfd = platform.Struct('struct pollfd',
                                            [('fd', socketfd_type),
                                             ('events', rffi.SHORT),
                                             ('revents', rffi.SHORT)])

    if _HAS_AF_PACKET:
        CConfig.sockaddr_ll = platform.Struct('struct sockaddr_ll',
                              [('sll_family', rffi.INT),
                               ('sll_ifindex', rffi.INT),
                               ('sll_protocol', rffi.INT),
                               ('sll_pkttype', rffi.INT),
                               ('sll_hatype', rffi.INT),
                               ('sll_addr', rffi.CFixedArray(rffi.CHAR, 8)),
                               ('sll_halen', rffi.INT)])

        CConfig.ifreq = platform.Struct('struct ifreq',
                                [('ifr_ifindex', rffi.INT),
                                 ('ifr_name', rffi.CFixedArray(rffi.CHAR, 8))])

# insert handler for sendmsg / recvmsg here
HAVE_SENDMSG = bool(_POSIX)
if HAVE_SENDMSG:
    includes = ['stddef.h',
                'sys/socket.h',
                'unistd.h',
                'string.h',
                'stdlib.h',
                'errno.h',
                'limits.h',
                'stdio.h',
                'sys/types.h',
                'netinet/in.h',
                'arpa/inet.h']
    separate_module_sources = ['''

        // special defines for returning from recvmsg
        #define BAD_MSG_SIZE_GIVEN -10000
        #define BAD_ANC_SIZE_GIVEN -10001
        #define MAL_ANC -10002

        // special defines for returning from sendmsg
        #define MUL_MSGS_NOT_SUP -1000
        #define ANC_DATA_TOO_LARGE -1001
        #define ANC_DATA_TOO_LARGEX -1002

        #if INT_MAX > 0x7fffffff
            #define SOCKLEN_T_LIMIT 0x7fffffff
        #else
        #define SOCKLEN_T_LIMIT INT_MAX
        #endif

        // ################################################################################################
        // Recvmsg implementation and associated functions

        // Taken from CPython. Determines the minimum memory space required for the ancillary data.
        #ifdef CMSG_SPACE
        static int
        cmsg_min_space(struct msghdr *msg, struct cmsghdr *cmsgh, size_t space)
        {
            size_t cmsg_offset;
            static const size_t cmsg_len_end = (offsetof(struct cmsghdr, cmsg_len) +
                                                sizeof(cmsgh->cmsg_len));

            /* Note that POSIX allows msg_controllen to be of signed type. */
            if (cmsgh == NULL || msg->msg_control == NULL)
                return 0;
            /* Note that POSIX allows msg_controllen to be of a signed type. This is
               annoying under OS X as it's unsigned there and so it triggers a
               tautological comparison warning under Clang when compared against 0.
               Since the check is valid on other platforms, silence the warning under
               Clang. */
            #ifdef __clang__
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wtautological-compare"
            #endif
            #if defined(__GNUC__) && ((__GNUC__ > 4) || ((__GNUC__ == 4) && (__GNUC_MINOR__ > 5)))
            #pragma GCC diagnostic push
            #pragma GCC diagnostic ignored "-Wtype-limits"
            #endif
            if (msg->msg_controllen < 0)
                return 0;
            #if defined(__GNUC__) && ((__GNUC__ > 4) || ((__GNUC__ == 4) && (__GNUC_MINOR__ > 5)))
            #pragma GCC diagnostic pop
            #endif
            #ifdef __clang__
            #pragma clang diagnostic pop
            #endif
            if (space < cmsg_len_end)
                space = cmsg_len_end;
            cmsg_offset = (char *)cmsgh - (char *)msg->msg_control;
            return (cmsg_offset <= (size_t)-1 - space &&
                    cmsg_offset + space <= msg->msg_controllen);
        }
        #endif

        // Taken from CPython.
        #ifdef CMSG_LEN
        /* If pointer CMSG_DATA(cmsgh) is in buffer msg->msg_control, set
           *space to number of bytes following it in the buffer and return
           true; otherwise, return false.  Assumes cmsgh, msg->msg_control and
           msg->msg_controllen are valid. */
        static int
        get_cmsg_data_space(struct msghdr *msg, struct cmsghdr *cmsgh, size_t *space)
        {
            size_t data_offset;
            char *data_ptr;

            if ((data_ptr = (char *)CMSG_DATA(cmsgh)) == NULL)
                return 0;
            data_offset = data_ptr - (char *)msg->msg_control;
            if (data_offset > msg->msg_controllen)
                return 0;
            *space = msg->msg_controllen - data_offset;
            return 1;
        }

        // Taken from CPython.
        /* If cmsgh is invalid or not contained in the buffer pointed to by
           msg->msg_control, return -1.  If cmsgh is valid and its associated
           data is entirely contained in the buffer, set *data_len to the
           length of the associated data and return 0.  If only part of the
           associated data is contained in the buffer but cmsgh is otherwise
           valid, set *data_len to the length contained in the buffer and
           return 1. */
        static int
        get_cmsg_data_len(struct msghdr *msg, struct cmsghdr *cmsgh, size_t *data_len)
        {
            size_t space, cmsg_data_len;

            if (!cmsg_min_space(msg, cmsgh, CMSG_LEN(0)) ||
                cmsgh->cmsg_len < CMSG_LEN(0))
                return -1;
            cmsg_data_len = cmsgh->cmsg_len - CMSG_LEN(0);
            if (!get_cmsg_data_space(msg, cmsgh, &space))
                return -1;
            if (space >= cmsg_data_len) {
                *data_len = cmsg_data_len;
                return 0;
            }
            *data_len = space;
            return 1;
        }
        #endif    /* CMSG_LEN */

        /*
            Structure meant to hold the information received after a recvmsg is performed.
            Essentially it holds: the address, the message, the ancillary data and the return flags.
            I use this structure for 2 main reasons:
               - keep things ordered
               - some of the ancillary parameters need to be int not long (rffi SignedP is actually long*),
                 therefore I cannot use the parameters directly
        */
        struct recvmsg_info
        {
            struct sockaddr* address; // address fields
            socklen_t addrlen;
            int size_of_ancillary; // ancillary fields
            int* levels;
            int* types;
            char** file_descr;
            int* descr_per_ancillary;
            int retflag; // return flag field
        };

        /*
            Wrapper function over recvmsg. Since it returns a lot of data,
            in a structure that is hard to parse in rffi, it was implemented in C.
            All the parameters, save the socket fd, message_size, ancillary_size
            will be malloc'd and/or modified.
        */
        RPY_EXTERN
        int recvmsg_implementation(
                                  int socket_fd,
                                  int ancillary_size,
                                  int flags,
                                  struct sockaddr* address,
                                  socklen_t* addrlen,
                                  int* message_lengths,
                                  char** messages,
                                  int no_of_messages,
                                  long* size_of_ancillary,
                                  long** levels,
                                  long** types,
                                  char** file_descr,
                                  long** descr_per_ancillary,
                                  long* retflag)
        {

            struct sockaddr* recvd_address;
            socklen_t recvd_addrlen;
            struct msghdr msg = {0};
            void *controlbuf = NULL;
            struct cmsghdr *cmsgh;
            int cmsg_status;
            struct recvmsg_info* retinfo;
            int error_flag = 0;   // variable to be set in case of special errors.
            int cmsgdatalen = 0;
            size_t i;

            // variables that are set to 1, if the message charp has been allocated
            // and if the ancillary variables have been allocated. To be used in case of failure.
            int iov_alloc = 0;
            int anc_alloc = 0;

            retinfo = (struct recvmsg_info*) malloc(sizeof(struct recvmsg_info));

            if (ancillary_size > SOCKLEN_T_LIMIT){
                error_flag = BAD_ANC_SIZE_GIVEN;
                goto fail;
            }

            // Add the message
            struct iovec *iovs = NULL;
            if (no_of_messages > 0) {
                iovs = (struct iovec*) malloc(no_of_messages * sizeof(struct iovec));
                memset(iovs, 0, no_of_messages * sizeof(struct iovec));

                for (i=0; i < no_of_messages; i++) {
                    iovs[i].iov_base = messages[i];
                    iovs[i].iov_len = message_lengths[i];
                }
            }

            // Setup the ancillary buffer memory
            controlbuf = malloc(ancillary_size);

            // Setup the recv address memory
            recvd_addrlen = sizeof(struct sockaddr_storage);
            recvd_address = (struct sockaddr*) malloc(recvd_addrlen);

            memset(recvd_address, 0,recvd_addrlen);

            // Setup the msghdr struct
            msg.msg_name = recvd_address;
            msg.msg_namelen = recvd_addrlen;
            msg.msg_iov = iovs;
            msg.msg_iovlen = no_of_messages;
            msg.msg_control = controlbuf;
            msg.msg_controllen = ancillary_size;

            // Link my structure to the msghdr fields
            retinfo->address = msg.msg_name;

            iov_alloc = 1;
            ssize_t bytes_recvd = 0;

            bytes_recvd = recvmsg(socket_fd, &msg, flags);

            if (bytes_recvd < 0){
                 goto fail;
            }

            retinfo->addrlen = (socklen_t) msg.msg_namelen;

            // Count the ancillary items & allocate the memory
            int anc_counter = 0;
            for (cmsgh = ((msg.msg_controllen > 0) ? CMSG_FIRSTHDR(&msg) : NULL);
                 cmsgh != NULL; cmsgh = CMSG_NXTHDR(&msg, cmsgh)) {

                 anc_counter++;
            }
            retinfo->size_of_ancillary = anc_counter;
            retinfo->file_descr = (char**) malloc (anc_counter * sizeof(char*));
            retinfo->levels = (int*) malloc(anc_counter * sizeof(int));
            retinfo->types = (int*) malloc(anc_counter * sizeof(int));
            retinfo->descr_per_ancillary = (int*) malloc(anc_counter * sizeof(int));
            anc_alloc = 1;

            // Extract the ancillary items
            i=0;
            for (cmsgh = ((msg.msg_controllen > 0) ? CMSG_FIRSTHDR(&msg) : NULL);
                 cmsgh != NULL; cmsgh = CMSG_NXTHDR(&msg, cmsgh)) {
                 size_t local_size = 0;
                 cmsg_status = get_cmsg_data_len(&msg, cmsgh, &local_size);
                 if (cmsg_status !=0 ){
                    error_flag = MAL_ANC;
                    goto err_closefds;
                 }
                 retinfo->file_descr[i] = (char*) malloc(local_size);
                 memcpy(retinfo->file_descr[i], CMSG_DATA(cmsgh), local_size);
                 retinfo->levels[i] = cmsgh->cmsg_level;
                 retinfo->types[i] = cmsgh->cmsg_type;
                 retinfo->descr_per_ancillary[i] =local_size;
                 i++;

            }
            retinfo->retflag = msg.msg_flags;

            // Set the parameters of address
            memcpy(address,retinfo->address,retinfo->addrlen);
            *addrlen = retinfo->addrlen;

            // Set the parameters of message
            size_of_ancillary[0] = retinfo->size_of_ancillary;

            // Set the parameters of ancillary
            *levels = (long*) malloc (sizeof(long) * retinfo->size_of_ancillary);
            *types = (long*) malloc (sizeof(long) * retinfo->size_of_ancillary);
            *descr_per_ancillary = (long*) malloc (sizeof(long) * retinfo->size_of_ancillary);
            int counter = 0;
            for (i=0; i < retinfo->size_of_ancillary; i++){
                counter += retinfo->descr_per_ancillary[i];
                // Convert the int* to long*
                levels[0][i] = (long) retinfo->levels[i];
                types[0][i] = (long) retinfo->types[i];
                descr_per_ancillary[0][i] = (long) retinfo->descr_per_ancillary[i];
            }
            *file_descr = (char*) malloc (sizeof(char) * counter);
            memset(*file_descr, 0, sizeof(char) * counter);
            counter = 0;
            for (i=0; i<retinfo->size_of_ancillary; i++){
                memcpy(*file_descr+counter,retinfo->file_descr[i], retinfo->descr_per_ancillary[i]);
                counter += retinfo->descr_per_ancillary[i];
            }

            // Set the retflag
            retflag[0] = retinfo->retflag;

            // Free the memory
            free(retinfo->address);
            free(retinfo->levels);
            free(retinfo->types);
            free(retinfo->descr_per_ancillary);
            for (i = 0; i < retinfo->size_of_ancillary; i++)
                free(retinfo->file_descr[i]);
            free(retinfo->file_descr);
            free(retinfo);
            free(controlbuf);
            if (iovs != NULL)
                free(iovs);

            return bytes_recvd;

        fail:
            if (anc_alloc){
                free(retinfo->file_descr);
                free(retinfo->levels);
                free(retinfo->types);
                free(retinfo->descr_per_ancillary);
                free(retinfo->address);
                free(retinfo);
                free(controlbuf);

            }else{
                if (iov_alloc){
                    free(retinfo->address);
                    free(controlbuf);
                    free(retinfo);
                }
            }
            if (iovs != NULL)
                free(iovs);
            if (error_flag==0) error_flag = -1;
            return error_flag;

        err_closefds:
        // Special case for UNIX sockets. In case file descriptors are received, they need to be closed.
        // Taken from CPython
        #ifdef SCM_RIGHTS
            /* Close all descriptors coming from SCM_RIGHTS, so they don't leak. */
            for (cmsgh = ((msg.msg_controllen > 0) ? CMSG_FIRSTHDR(&msg) : NULL);
                 cmsgh != NULL; cmsgh = CMSG_NXTHDR(&msg, cmsgh)) {
                size_t dataleng;
                cmsg_status = get_cmsg_data_len(&msg, cmsgh, &dataleng);
                cmsgdatalen = (int) dataleng;
                if (cmsg_status < 0)
                    break;
                if (cmsgh->cmsg_level == SOL_SOCKET &&
                    cmsgh->cmsg_type == SCM_RIGHTS) {
                    size_t numfds;
                    int *fdp;

                    numfds = cmsgdatalen / sizeof(int);
                    fdp = (int *)CMSG_DATA(cmsgh);
                    while (numfds-- > 0)
                        close(*fdp++);
                }
                if (cmsg_status != 0)
                    break;
            }
        #endif /* SCM_RIGHTS */
            goto fail;
        }


        // ################################################################################################
        // Sendmsg implementation and associated functions

        #ifdef CMSG_LEN
        static int
        get_CMSG_LEN(size_t length, size_t *result)
        {
            size_t tmp;

            if (length > (SOCKLEN_T_LIMIT - CMSG_LEN(0)))
                return 0;
            tmp = CMSG_LEN(length);
            if ((tmp > SOCKLEN_T_LIMIT) || (tmp < length))
                return 0;
            *result = tmp;
            return 1;
        }
        #endif

        #ifdef CMSG_SPACE
        /* If length is in range, set *result to CMSG_SPACE(length) and return
           true; otherwise, return false. */
        static int
        get_CMSG_SPACE(size_t length, size_t *result)
        {
            size_t tmp;

            /* Use CMSG_SPACE(1) here in order to take account of the padding
               necessary before *and* after the data. */
            if (length > (SOCKLEN_T_LIMIT - CMSG_SPACE(1)))
                return 0;
            tmp = CMSG_SPACE(length);
            if ((tmp > SOCKLEN_T_LIMIT) || (tmp < length))
                return 0;
            *result = tmp;
            return 1;
        }
        #endif

        /*
            sendmsg_implementation is a wrapper over sendmsg of the API.
            It was inspired from the way CPython did their implementation of this.
            The main reason that it was written in C, is the struct msghdr,
            which contains the ancillary data in a linked list of cmsghdr structures.
            It was simpler to use it in C, and then push the simpler types of data via rffi.
        */
        RPY_EXTERN
        int sendmsg_implementation
                            (int socket,
                            struct sockaddr* address,
                            socklen_t addrlen,
                            long* length_of_messages,
                            char** messages,
                            int no_of_messages,
                            long* levels,
                            long* types,
                            char** file_descriptors,
                            long* no_of_fds,
                            int control_length,
                            int flag
                            )
        {

            struct msghdr        msg = {0};
            struct cmsghdr       *cmsg;
            void* controlbuf = NULL;
            int retval;
            size_t i;

            // Prepare the msghdr structure for the send:

            // Add the address
            if (address != NULL) {
                msg.msg_name = address;
                msg.msg_namelen = addrlen;
            }

            // Add the message
            struct iovec *iovs = NULL;
            if (no_of_messages > 0){

                iovs = (struct iovec*) malloc(no_of_messages * sizeof(struct iovec));
                memset(iovs, 0, no_of_messages * sizeof(struct iovec));
                msg.msg_iov = iovs;
                msg.msg_iovlen = no_of_messages;

                for (i=0; i < no_of_messages; i++){
                    iovs[i].iov_base = messages[i];
                    iovs[i].iov_len = length_of_messages[i];
                }
            }

            // Add the ancillary
            #ifndef CMSG_SPACE
                if (control_length > 1){
                    free(iovs);
                    return MUL_MSGS_NOT_SUP;
                }
            #endif
            if (control_length > 0){

                //compute the total size of the ancillary
                //getting the exact amount of space can be tricky and os dependent.
                size_t total_size_of_ancillary = 0;
                size_t space;
                size_t controllen = 0, controllen_last = 0;
                for (i = 0; i< control_length; i++){
                    total_size_of_ancillary = no_of_fds[i];
                    #ifdef CMSG_SPACE
                        if (!get_CMSG_SPACE(total_size_of_ancillary, &space)) {
                    #else
                        if (!get_CMSG_LEN(total_size_of_ancillary, &space)) {
                    #endif
                            if (iovs != NULL)
                                free(iovs);
                            return ANC_DATA_TOO_LARGE;
                        }
                    controllen +=space;
                    if ((controllen > SOCKLEN_T_LIMIT) || (controllen < controllen_last)) {
                        if (iovs != NULL)
                                free(iovs);
                        return ANC_DATA_TOO_LARGEX;
                    }
                    controllen_last = controllen;
                }

                controlbuf = malloc(controllen);
                msg.msg_control = controlbuf;
                msg.msg_controllen = controllen;

                // memset controlbuf to 0 to avoid trash in the ancillary
                memset(controlbuf, 0, controllen);
                cmsg = NULL;
                for (i = 0; i < control_length; i++) {
                    cmsg = (i == 0) ? CMSG_FIRSTHDR(&msg) : CMSG_NXTHDR(&msg, cmsg);

                    cmsg->cmsg_level = (int) levels[i];
                    cmsg->cmsg_type = (int) types[i];
                    cmsg->cmsg_len = CMSG_LEN(sizeof(char) * no_of_fds[i]);
                    memcpy(CMSG_DATA(cmsg), file_descriptors[i], sizeof(char) * no_of_fds[i]);
                }


            }
            // Add the flags
            msg.msg_flags = flag;

            // Send the data
            retval = sendmsg(socket, &msg, flag);

            // free everything that was allocated here, and we would not need in rsocket
            if (iovs != NULL)
                free(iovs);
            if (controlbuf !=NULL)
               free(controlbuf);

            return retval;
        }

        // ################################################################################################
        // Wrappers for CMSG_SPACE and CMSG_LEN

        /*
            These 2 functions are wrappers over sys/socket.h's CMSG_SPACE and CMSG_LEN.
            They are identical to CPython's.
        */
        #ifdef CMSG_SPACE
        RPY_EXTERN
        size_t CMSG_SPACE_wrapper(size_t desired_space){
            size_t result;
            if (!get_CMSG_SPACE(desired_space, &result)){
                return 0;
            }
            return result;
        }
        #endif

        #ifdef CMSG_LEN
        RPY_EXTERN
        size_t CMSG_LEN_wrapper(size_t desired_len){
            size_t result;
            if (!get_CMSG_LEN(desired_len, &result)){
                return 0;
            }
            return result;
        }
        #endif

        // ################################################################################################
        // Extra functions that I needed

        /*
           This function is used to memcpy from a char* at an offset.
           Could not get rffi.c_memcpy to do it at an offset, so I made my own.
        */
        RPY_EXTERN
        int memcpy_from_CCHARP_at_offset_and_size(char* stringfrom, char** stringto, int offset, int size){
            *stringto = memcpy(*stringto, stringfrom + offset, size);
            return 0;
        }

        /*
            These functions free memory that was allocated in C (sendmsg or recvmsg) was used in rsocket and now needs cleanup
        */
        RPY_EXTERN
        int free_pointer_to_signedp(long** ptrtofree){
            free(*ptrtofree);
            return 0;
        }

        RPY_EXTERN
        int free_ptr_to_charp(char** ptrtofree){
            free(*ptrtofree);
            return 0;
        }

    ''',]

    post_include_bits =[ "RPY_EXTERN "
                         "int sendmsg_implementation(int socket, struct sockaddr* address, socklen_t addrlen, long* length_of_messages, char** messages, int no_of_messages, long* levels, long* types, char** file_descriptors, long* no_of_fds, int control_length, int flag );\n"
                         "RPY_EXTERN "
                         "int recvmsg_implementation(int socket_fd, int ancillary_size, int flags, struct sockaddr* address, socklen_t* addrlen, int* message_lengths, char** messages, int no_of_messages, long* size_of_ancillary, long** levels, long** types, char** file_descr, long** descr_per_ancillary, long* flag);\n"
                         "static "
                         "int cmsg_min_space(struct msghdr *msg, struct cmsghdr *cmsgh, size_t space);\n"
                         "static "
                         "int get_cmsg_data_space(struct msghdr *msg, struct cmsghdr *cmsgh, size_t *space);\n"
                         "static "
                         "int get_cmsg_data_len(struct msghdr *msg, struct cmsghdr *cmsgh, size_t *data_len);\n"
                         "static "
                         "int get_CMSG_LEN(size_t length, size_t *result);\n"
                         "static "
                         "int get_CMSG_SPACE(size_t length, size_t *result);\n"
                         "RPY_EXTERN "
                         "size_t CMSG_LEN_wrapper(size_t desired_len);\n"
                         "RPY_EXTERN "
                         "size_t CMSG_SPACE_wrapper(size_t desired_space);\n"
                         "RPY_EXTERN "
                         "int memcpy_from_CCHARP_at_offset_and_size(char* stringfrom, char** stringto, int offset, int size);\n"
                         "RPY_EXTERN "
                         "int free_pointer_to_signedp(long** ptrtofree);\n"
                         "RPY_EXTERN "
                         "int free_ptr_to_charp(char** ptrtofree);\n"
                         ]


    compilation_info = eci.merge(ExternalCompilationInfo(
                                    includes=includes,
                                    separate_module_sources=separate_module_sources,
                                    post_include_bits=post_include_bits,
                               ))
else:
    compilation_info = eci


if _WIN32:
    CConfig.WSAEVENT = platform.SimpleType('WSAEVENT', rffi.VOIDP)
    CConfig.WSANETWORKEVENTS = platform.Struct(
        'struct _WSANETWORKEVENTS',
        [('lNetworkEvents', rffi.LONG),
         ('iErrorCode', rffi.CFixedArray(rffi.INT, 10)), #FD_MAX_EVENTS
         ])

    CConfig.WSAPROTOCOL_INFO = platform.Struct(
        'WSAPROTOCOL_INFOA',
        [])  # Struct is just passed between functions

    CConfig.FROM_PROTOCOL_INFO = platform.DefinedConstantInteger(
        'FROM_PROTOCOL_INFO')

CConfig.timeval = platform.Struct('struct timeval',
                                         [('tv_sec', rffi.LONG),
                                          ('tv_usec', rffi.LONG)])

fd_set = rffi.COpaquePtr('fd_set', compilation_info=eci)

if _WIN32:
    CConfig.WSAData = platform.Struct('struct WSAData',
                                     [('wVersion', rffi.USHORT),
                                      ('wHighVersion', rffi.USHORT),
                                      ('szDescription', rffi.CFixedArray(lltype.Char, 1)), # (WSADESCRIPTION_LEN+1)
                                      ('szSystemStatus', rffi.CFixedArray(lltype.Char, 1)), # (WSASYS_STATUS_LEN+1)
                                      ('iMaxSockets', rffi.USHORT),
                                      ('iMaxUdpDg', rffi.USHORT),
                                      ('lpVendorInfo', CCHARP)])

    CConfig.tcp_keepalive = platform.Struct(
        'struct tcp_keepalive',
        [('onoff', rffi.ULONG),
         ('keepalivetime', rffi.ULONG),
         ('keepaliveinterval', rffi.ULONG)])

    CConfig.GUID = platform.Struct(
             'struct _GUID',
             [('Data1', rffi.UINT),
             ('Data2', rffi.UINT),
             ('Data3', rffi.UINT),
             ('Data4', rffi.CFixedArray(rffi.UCHAR, 8))
         ])

    CConfig.WSAPROTOCOLCHAIN = platform.Struct(
        'struct _WSAPROTOCOLCHAIN',
        [('ChainLen', rffi.INT),
         ('ChainEntries', rffi.CFixedArray(rffi.UINT, 7))])

    WSAPROTOCOLCHAIN = CConfig.WSAPROTOCOLCHAIN
    GUID = CConfig.GUID

    CConfig.WSAPROTOCOL_INFOW = platform.Struct(
        'struct _WSAPROTOCOL_INFOW',
        [('dwServiceFlags1', rffi.UINT),
         ('dwServiceFlags2', rffi.UINT),
         ('dwServiceFlags3', rffi.UINT),
         ('dwServiceFlags4', rffi.UINT),
         ('dwProviderFlags', rffi.UINT),
         ('ProviderId', GUID),
         ('dwCatalogEntryId', rffi.UINT),
         ('ProtocolChain', WSAPROTOCOLCHAIN),
         ('iVersion', rffi.INT),
         ('iAddressFamily', rffi.INT),
         ('iMaxSockAddr', rffi.INT),
         ('iMinSockAddr', rffi.INT),
         ('iSocketType', rffi.INT),
         ('iProtocol', rffi.INT),
         ('iProtocolMaxOffset', rffi.INT),
         ('iNetworkByteOrder', rffi.INT),
         ('iSecurityScheme', rffi.INT),
         ('dwMessageSize', rffi.UINT),
         ('dwProviderReserved', rffi.UINT),
         ('szProtocol',  rffi.CFixedArray(rffi.UCHAR, 256))])


class cConfig:
    pass
cConfig.__dict__.update(platform.configure(CConfig))

sockaddr_ptr.TO.become(cConfig.sockaddr)
addrinfo_ptr.TO.become(cConfig.addrinfo)


# fill in missing constants with reasonable defaults
cConfig.NI_MAXHOST = cConfig.NI_MAXHOST or 1025
cConfig.NI_MAXSERV = cConfig.NI_MAXSERV or 32
cConfig.INET_ADDRSTRLEN = cConfig.INET_ADDRSTRLEN or 16

for name in constant_names:
    value = getattr(cConfig, name)
    if value is not None:
        constants[name] = value
for name, default in constants_w_defaults:
    value = getattr(cConfig, name)
    if value is not None:
        constants[name] = value
    else:
        constants[name] = default
if not _HAS_AF_PACKET and 'AF_PACKET' in constants:
    del constants['AF_PACKET']

constants['has_ipv6'] = True # This is a configuration option in CPython
for name, value in constants.items():
    if isinstance(value, long):
        if r_uint(value) == value:
            constants[name] = intmask(value)

locals().update(constants)

O_RDONLY = cConfig.O_RDONLY
O_WRONLY = cConfig.O_WRONLY
O_RDWR = cConfig.O_RDWR
O_NONBLOCK = cConfig.O_NONBLOCK
F_GETFL = cConfig.F_GETFL
F_SETFL = cConfig.F_SETFL
FIONBIO = cConfig.FIONBIO
INET_ADDRSTRLEN = cConfig.INET_ADDRSTRLEN
INET6_ADDRSTRLEN = cConfig.INET6_ADDRSTRLEN
EINTR = cConfig.EINTR or cConfig.WSAEINTR
EINPROGRESS = cConfig.EINPROGRESS or cConfig.WSAEINPROGRESS
EWOULDBLOCK = cConfig.EWOULDBLOCK or cConfig.WSAEWOULDBLOCK
EAFNOSUPPORT = cConfig.EAFNOSUPPORT or cConfig.WSAEAFNOSUPPORT
# vs 2010 and above define both the constansts
WSAEINPROGRESS = cConfig.WSAEINPROGRESS or cConfig.EINPROGRESS
WSAEWOULDBLOCK = cConfig.WSAEWOULDBLOCK or cConfig.EWOULDBLOCK
WSAEAFNOSUPPORT = cConfig.WSAEAFNOSUPPORT or cConfig.EAFNOSUPPORT
EISCONN = cConfig.EISCONN or cConfig.WSAEISCONN
PIPE_BUF = cConfig.PIPE_BUF    # may be None

linux = cConfig.linux
WIN32 = cConfig.WIN32
assert WIN32 == _WIN32

if _MSVC:
    def invalid_socket(fd):
        return fd == INVALID_SOCKET
    INVALID_SOCKET = r_uint(cConfig.INVALID_SOCKET)
else:
    def invalid_socket(fd):
        return fd < 0
    INVALID_SOCKET = -1

uint16_t = cConfig.uint16_t
uint32_t = cConfig.uint32_t
size_t = cConfig.size_t
ssize_t = cConfig.ssize_t
socklen_t = cConfig.socklen_t
sockaddr = cConfig.sockaddr
#sockaddr_size = sizeof(sockaddr)
sockaddr_in = cConfig.sockaddr_in
sockaddr_in6 = cConfig.sockaddr_in6
sockaddr_un = cConfig.sockaddr_un
if cConfig.sockaddr_nl is not None:
    sockaddr_nl = cConfig.sockaddr_nl
in_addr = cConfig.in_addr
#in_addr_size = sizeof(in_addr)
in6_addr = cConfig.in6_addr
addrinfo = cConfig.addrinfo
if _POSIX:
    nfds_t = cConfig.nfds_t
    pollfd = cConfig.pollfd
    if _HAS_AF_PACKET:
        sockaddr_ll = cConfig.sockaddr_ll
        ifreq = cConfig.ifreq
if WIN32:
    WSAEVENT = cConfig.WSAEVENT
    WSANETWORKEVENTS = cConfig.WSANETWORKEVENTS
    SAVE_ERR = rffi.RFFI_SAVE_WSALASTERROR
else:
    SAVE_ERR = rffi.RFFI_SAVE_ERRNO
timeval = cConfig.timeval


def external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           calling_conv=calling_conv, **kwds)

def external_c(name, args, result, **kwargs):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           calling_conv='c', **kwargs)

if _POSIX:
    dup = external('dup', [socketfd_type], socketfd_type, save_err=SAVE_ERR)
    gai_strerror = external('gai_strerror', [rffi.INT], CONST_CCHARP)

#h_errno = c_int.in_dll(socketdll, 'h_errno')
#
#hstrerror = socketdll.hstrerror
#hstrerror.argtypes = [c_int]
#hstrerror.restype = c_char_p

socket = external('socket', [rffi.INT, rffi.INT, rffi.INT], socketfd_type,
                  save_err=SAVE_ERR)


if WIN32:
    socketclosename = 'closesocket'
else:
    socketclosename = 'close'
socketclose = external(socketclosename, [socketfd_type], rffi.INT,
                       releasegil=False, save_err=SAVE_ERR)
socketclose_no_errno = external(socketclosename, [socketfd_type], rffi.INT,
                                releasegil=False)

socketconnect = external('connect', [socketfd_type, sockaddr_ptr, socklen_t],
                         rffi.INT, save_err=SAVE_ERR)

getaddrinfo = external('getaddrinfo', [CCHARP, CCHARP,
                        addrinfo_ptr,
                        lltype.Ptr(rffi.CArray(addrinfo_ptr))], rffi.INT)
freeaddrinfo = external('freeaddrinfo', [addrinfo_ptr], lltype.Void)
getnameinfo = external('getnameinfo', [sockaddr_ptr, socklen_t, CCHARP,
                       size_t, CCHARP, size_t, rffi.INT], rffi.INT)

if sys.platform.startswith("openbsd") or sys.platform.startswith("darwin"):
    htonl = external('htonl', [rffi.UINT], rffi.UINT, releasegil=False, macro=True)
    htons = external('htons', [rffi.USHORT], rffi.USHORT, releasegil=False, macro=True)
    ntohl = external('ntohl', [rffi.UINT], rffi.UINT, releasegil=False, macro=True)
    ntohs = external('ntohs', [rffi.USHORT], rffi.USHORT, releasegil=False, macro=True)
else:
    htonl = external('htonl', [rffi.UINT], rffi.UINT, releasegil=False)
    htons = external('htons', [rffi.USHORT], rffi.USHORT, releasegil=False)
    ntohl = external('ntohl', [rffi.UINT], rffi.UINT, releasegil=False)
    ntohs = external('ntohs', [rffi.USHORT], rffi.USHORT, releasegil=False)

if _POSIX:
    inet_aton = external('inet_aton', [CCHARP, lltype.Ptr(in_addr)],
                                rffi.INT)

inet_ntoa = external('inet_ntoa', [in_addr], rffi.CCHARP)


inet_pton = external('inet_pton', [rffi.INT, rffi.CCHARP,
                                   rffi.VOIDP], rffi.INT,
                     save_err=SAVE_ERR)

inet_ntop = external('inet_ntop', [rffi.INT, rffi.VOIDP, CCHARP,
                                   socklen_t], CCHARP,
                     save_err=SAVE_ERR)

inet_addr = external('inet_addr', [rffi.CCHARP], rffi.UINT)
socklen_t_ptr = lltype.Ptr(rffi.CFixedArray(socklen_t, 1))
socketaccept = external('accept', [socketfd_type, sockaddr_ptr,
                                   socklen_t_ptr], socketfd_type,
                        save_err=SAVE_ERR)
HAVE_ACCEPT4 = cConfig.HAVE_ACCEPT4
if HAVE_ACCEPT4:
    socketaccept4 = external('accept4', [socketfd_type, sockaddr_ptr,
                                         socklen_t_ptr, rffi.INT],
                                        socketfd_type,
                             save_err=SAVE_ERR)
socketbind = external('bind', [socketfd_type, sockaddr_ptr, socklen_t],
                              rffi.INT, save_err=SAVE_ERR)
socketlisten = external('listen', [socketfd_type, rffi.INT], rffi.INT,
                        save_err=SAVE_ERR)
socketgetpeername = external('getpeername', [socketfd_type,
                                    sockaddr_ptr, socklen_t_ptr], rffi.INT,
                             save_err=SAVE_ERR)
socketgetsockname = external('getsockname', [socketfd_type,
                                   sockaddr_ptr, socklen_t_ptr], rffi.INT,
                             save_err=SAVE_ERR)
socketgetsockopt = external('getsockopt', [socketfd_type, rffi.INT,
                               rffi.INT, rffi.VOIDP, socklen_t_ptr], rffi.INT,
                            save_err=SAVE_ERR)
socketsetsockopt = external('setsockopt', [socketfd_type, rffi.INT,
                                   rffi.INT, rffi.VOIDP, socklen_t], rffi.INT,
                            save_err=SAVE_ERR)
if WIN32:
    socketrecv = external('recv', [socketfd_type, rffi.VOIDP, rffi.INT,
                                   rffi.INT], rffi.INT, save_err=SAVE_ERR)
else:
    socketrecv = external('recv', [socketfd_type, rffi.VOIDP, rffi.INT,
                                   rffi.INT], ssize_t, save_err=SAVE_ERR)
recvfrom = external('recvfrom', [socketfd_type, rffi.VOIDP, size_t,
                           rffi.INT, sockaddr_ptr, socklen_t_ptr], rffi.INT,
                    save_err=SAVE_ERR)
recvmsg = jit.dont_look_inside(rffi.llexternal(
    "recvmsg_implementation",
    [rffi.INT, rffi.INT, rffi.INT, sockaddr_ptr, socklen_t_ptr,
        rffi.INTP, rffi.CCHARPP, rffi.INT, rffi.SIGNEDP, rffi.SIGNEDPP, rffi.SIGNEDPP,
        rffi.CCHARPP, rffi.SIGNEDPP, rffi.SIGNEDP], rffi.INT,
    save_err=SAVE_ERR, compilation_info=compilation_info))

memcpy_from_CCHARP_at_offset = jit.dont_look_inside(rffi.llexternal("memcpy_from_CCHARP_at_offset_and_size",
                                    [rffi.CCHARP, rffi.CCHARPP,rffi.INT,rffi.INT],rffi.INT,save_err=SAVE_ERR,compilation_info=compilation_info))
freeccharp = jit.dont_look_inside(rffi.llexternal("free_ptr_to_charp",
                                    [rffi.CCHARPP],rffi.INT,save_err=SAVE_ERR,compilation_info=compilation_info))
freesignedp = jit.dont_look_inside(rffi.llexternal("free_pointer_to_signedp",
                                    [rffi.SIGNEDPP],rffi.INT,save_err=SAVE_ERR,compilation_info=compilation_info))

send = external('send', [socketfd_type, rffi.CCHARP, size_t, rffi.INT],
                       ssize_t, save_err=SAVE_ERR)
sendto = external('sendto', [socketfd_type, rffi.VOIDP, size_t, rffi.INT,
                                    sockaddr_ptr, socklen_t], ssize_t,
                  save_err=SAVE_ERR)
sendmsg = jit.dont_look_inside(rffi.llexternal("sendmsg_implementation",
                               [rffi.INT, sockaddr_ptr, socklen_t, rffi.SIGNEDP, rffi.CCHARPP, rffi.INT,
                                rffi.SIGNEDP, rffi.SIGNEDP, rffi.CCHARPP, rffi.SIGNEDP, rffi.INT, rffi.INT],
                               rffi.INT, save_err=SAVE_ERR,
                               compilation_info=compilation_info))
CMSG_SPACE = jit.dont_look_inside(rffi.llexternal("CMSG_SPACE_wrapper",[size_t], size_t, save_err=SAVE_ERR,compilation_info=compilation_info))
CMSG_LEN = jit.dont_look_inside(rffi.llexternal("CMSG_LEN_wrapper",[size_t], size_t, save_err=SAVE_ERR,compilation_info=compilation_info))

socketshutdown = external('shutdown', [socketfd_type, rffi.INT], rffi.INT,
                          save_err=SAVE_ERR)
gethostname = external('gethostname', [rffi.CCHARP, rffi.INT], rffi.INT,
                       save_err=SAVE_ERR)
gethostbyname = external('gethostbyname', [rffi.CCHARP],
                                lltype.Ptr(cConfig.hostent))
gethostbyaddr = external('gethostbyaddr', [rffi.VOIDP, rffi.INT, rffi.INT], lltype.Ptr(cConfig.hostent))
getservbyname = external('getservbyname', [rffi.CCHARP, rffi.CCHARP], lltype.Ptr(cConfig.servent))
getservbyport = external('getservbyport', [rffi.INT, rffi.CCHARP], lltype.Ptr(cConfig.servent))
getprotobyname = external('getprotobyname', [rffi.CCHARP], lltype.Ptr(cConfig.protoent))

if _POSIX:
    fcntl = external('fcntl', [socketfd_type, rffi.INT, rffi.INT], rffi.INT,
                     save_err=SAVE_ERR)
    socketpair_t = rffi.CArray(socketfd_type)
    socketpair = external('socketpair', [rffi.INT, rffi.INT, rffi.INT,
                          lltype.Ptr(socketpair_t)], rffi.INT,
                          save_err=SAVE_ERR)
    sethostname = external('sethostname', [rffi.CCHARP, rffi.INT], rffi.INT,
                           save_err=SAVE_ERR)
    if _HAS_AF_PACKET:
        ioctl = external('ioctl', [socketfd_type, rffi.INT, lltype.Ptr(ifreq)],
                         rffi.INT)

if _WIN32:
    ioctlsocket = external('ioctlsocket',
                           [socketfd_type, rffi.LONG, rffi.ULONGP],
                           rffi.INT, save_err=SAVE_ERR)

select = external('select',
                  [rffi.INT, fd_set, fd_set,
                   fd_set, lltype.Ptr(timeval)],
                  rffi.INT,
                  save_err=SAVE_ERR)

FD_CLR = external_c('FD_CLR', [rffi.INT, fd_set], lltype.Void, macro=True)
FD_ISSET = external_c('FD_ISSET', [rffi.INT, fd_set], rffi.INT, macro=True)
FD_SET = external_c('FD_SET', [rffi.INT, fd_set], lltype.Void, macro=True)
FD_ZERO = external_c('FD_ZERO', [fd_set], lltype.Void, macro=True)

if _POSIX:
    pollfdarray = rffi.CArray(pollfd)
    poll = external('poll', [lltype.Ptr(pollfdarray), nfds_t, rffi.INT],
                    rffi.INT, save_err=SAVE_ERR)
    # workaround for Mac OS/X on which poll() seems to behave a bit strangely
    # (see test_recv_send_timeout in pypy.module._socket.test.test_sock_app)
    # https://issues.apache.org/bugzilla/show_bug.cgi?id=34332
    poll_may_be_broken = _MACOSX

elif WIN32:
    from rpython.rlib import rwin32
    #
    # The following is for rpython.rlib.rpoll
    #
    WSAEVENT_ARRAY = rffi.CArray(WSAEVENT)

    WSACreateEvent = external('WSACreateEvent', [], WSAEVENT)

    WSACloseEvent = external('WSACloseEvent', [WSAEVENT], rffi.INT)

    WSAEventSelect = external('WSAEventSelect',
                              [socketfd_type, WSAEVENT, rffi.LONG],
                              rffi.INT)

    WSAWaitForMultipleEvents = external('WSAWaitForMultipleEvents',
                                        [rffi.LONG, lltype.Ptr(WSAEVENT_ARRAY),
                                         rffi.INT, rffi.LONG, rffi.INT],
                                        rffi.ULONG)

    WSAEnumNetworkEvents = external('WSAEnumNetworkEvents',
                                    [socketfd_type, WSAEVENT,
                                     lltype.Ptr(WSANETWORKEVENTS)],
                                    rffi.INT)

    WSAIoctl = external('WSAIoctl',
                        [socketfd_type, rwin32.DWORD,
                         rffi.VOIDP, rwin32.DWORD,
                         rffi.VOIDP, rwin32.DWORD,
                         rwin32.LPDWORD, rffi.VOIDP, rffi.VOIDP],
                        rffi.INT, save_err=SAVE_ERR)

    WSAPROTOCOL_INFOW = cConfig.WSAPROTOCOL_INFOW

    WSADuplicateSocketW = external('WSADuplicateSocketW',
                                 [socketfd_type, rwin32.DWORD,
                                  lltype.Ptr(WSAPROTOCOL_INFOW)],
                                  rffi.INT, save_err=SAVE_ERR)

    WSASocketW = external('WSASocketW',
                         [rffi.INT, rffi.INT, rffi.INT,
                          lltype.Ptr(WSAPROTOCOL_INFOW),
                          rwin32.DWORD, rwin32.DWORD],
                         socketfd_type, save_err=SAVE_ERR)

    tcp_keepalive = cConfig.tcp_keepalive

    WSAPROTOCOL_INFO = cConfig.WSAPROTOCOL_INFO
    FROM_PROTOCOL_INFO = cConfig.FROM_PROTOCOL_INFO
    WSADuplicateSocket = external('WSADuplicateSocketA',
                                  [socketfd_type, rwin32.DWORD,
                                   lltype.Ptr(WSAPROTOCOL_INFO)],
                                  rffi.INT, save_err=SAVE_ERR)
    WSASocket = external('WSASocketA',
                         [rffi.INT, rffi.INT, rffi.INT,
                          lltype.Ptr(WSAPROTOCOL_INFO),
                          rwin32.DWORD, rwin32.DWORD],
                         socketfd_type, save_err=SAVE_ERR)

if WIN32:
    WSAData = cConfig.WSAData
    WSAStartup = external('WSAStartup', [rwin32.WORD, lltype.Ptr(WSAData)],
                          rffi.INT)

    _WSAGetLastError = external('WSAGetLastError', [], rwin32.DWORD,
                                _nowrapper=True, sandboxsafe=True)

    geterrno = rwin32.GetLastError_saved

    # In tests, the first call to GetLastError is always wrong, because error
    # is hidden by operations in ll2ctypes.  Call it now.
    _WSAGetLastError()

    def socket_strerror_str(errno):
        return rwin32.FormatError(errno)
    def gai_strerror_str(errno):
        return rwin32.FormatError(errno)

    def socket_strerror_unicode(errno):
        return rwin32.FormatErrorW(errno)[0].decode('utf-8')

    def gai_strerror_unicode(errno):
        return rwin32.FormatErrorW(errno)[0].decode('utf-8')

    def socket_strerror_utf8(errno):
        return rwin32.FormatErrorW(errno)

    def gai_strerror_utf8(errno):
        return rwin32.FormatErrorW(errno)

    # WinSock does not use a bitmask in select, and uses
    # socket handles greater than FD_SETSIZE
    MAX_FD_SIZE = None

else:
    from rpython.rlib.rposix import get_saved_errno as geterrno

    socket_strerror_str = os.strerror
    def gai_strerror_str(errno):
        return rffi.constcharp2str(gai_strerror(errno))

    def socket_strerror_unicode(errno):
        return socket_strerror_str(errno).decode('latin-1')

    def gai_strerror_unicode(errno):
        return gai_strerror_str(errno).decode('latin-1')

    def socket_strerror_utf8(errno):
        msg = socket_strerror_str(errno)
        return msg, len(msg)

    def gai_strerror_utf8(errno):
        msg = gai_strerror_str(errno)
        return msg, len(msg)

    MAX_FD_SIZE = FD_SETSIZE
