/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WS2TCPIP_H_
#define _WS2TCPIP_H_

#include <_mingw_unicode.h>

#ifdef __LP64__
#pragma push_macro("u_long")
#undef u_long
#define u_long __ms_u_long
#endif

#include <winsock2.h>
#include <ws2ipdef.h>
#include <psdk_inc/_ip_mreq1.h>
#include <winapifamily.h>

struct ip_mreq_source {
  struct in_addr imr_multiaddr;
  struct in_addr imr_sourceaddr;
  struct in_addr imr_interface;
};

struct ip_msfilter {
  struct in_addr imsf_multiaddr;
  struct in_addr imsf_interface;
  u_long imsf_fmode;
  u_long imsf_numsrc;
  struct in_addr imsf_slist[1];
};

#define IP_MSFILTER_SIZE(numsrc) (sizeof(struct ip_msfilter)-sizeof(struct in_addr) + (numsrc)*sizeof(struct in_addr))

#define SIO_GET_INTERFACE_LIST _IOR('t',127,u_long)

#define SIO_GET_INTERFACE_LIST_EX _IOR('t',126,u_long)
#define SIO_SET_MULTICAST_FILTER _IOW('t',125,u_long)
#define SIO_GET_MULTICAST_FILTER _IOW('t',124 | IOC_IN,u_long)

#define IP_OPTIONS 1
#define IP_HDRINCL 2
#define IP_TOS 3
#define IP_TTL 4
#define IP_MULTICAST_IF 9
#define IP_MULTICAST_TTL 10
#define IP_MULTICAST_LOOP 11
#define IP_ADD_MEMBERSHIP 12
#define IP_DROP_MEMBERSHIP 13
#define IP_DONTFRAGMENT 14
#define IP_ADD_SOURCE_MEMBERSHIP 15
#define IP_DROP_SOURCE_MEMBERSHIP 16
#define IP_BLOCK_SOURCE 17
#define IP_UNBLOCK_SOURCE 18
#define IP_PKTINFO 19
#define IP_RECEIVE_BROADCAST 22

#define PROTECTION_LEVEL_UNRESTRICTED 10
#define PROTECTION_LEVEL_DEFAULT 20
#define PROTECTION_LEVEL_RESTRICTED 30

#define UDP_NOCHECKSUM 1
#define UDP_CHECKSUM_COVERAGE 20

#define TCP_EXPEDITED_1122 0x0002


#include <ws2ipdef.h>


#define SS_PORT(ssp) (((struct sockaddr_in*)(ssp))->sin_port)

#define IN6ADDR_ANY_INIT { { { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } } }
#define IN6ADDR_LOOPBACK_INIT { { { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1 } } }

#ifdef __cplusplus
extern "C" {
#endif

  extern const struct in6_addr in6addr_any;
  extern const struct in6_addr in6addr_loopback;

int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *);
int IN6_IS_ADDR_LOOPBACK(const struct in6_addr *);
int IN6_IS_ADDR_MULTICAST(const struct in6_addr *);
int IN6_IS_ADDR_LINKLOCAL(const struct in6_addr *);
int IN6_IS_ADDR_SITELOCAL(const struct in6_addr *);
int IN6_IS_ADDR_V4MAPPED(const struct in6_addr *);
int IN6_IS_ADDR_V4COMPAT(const struct in6_addr *);
int IN6_IS_ADDR_MC_NODELOCAL(const struct in6_addr *);
int IN6_IS_ADDR_MC_LINKLOCAL(const struct in6_addr *);
int IN6_IS_ADDR_MC_SITELOCAL(const struct in6_addr *);
int IN6_IS_ADDR_MC_ORGLOCAL(const struct in6_addr *);
int IN6_IS_ADDR_MC_GLOBAL(const struct in6_addr *);
int IN6ADDR_ISANY(const struct sockaddr_in6 *);
int IN6ADDR_ISLOOPBACK(const struct sockaddr_in6 *);
void IN6_SET_ADDR_UNSPECIFIED(struct in6_addr *);
void IN6_SET_ADDR_LOOPBACK(struct in6_addr *);
void IN6ADDR_SETANY(struct sockaddr_in6 *);
void IN6ADDR_SETLOOPBACK(struct sockaddr_in6 *);

WS2TCPIP_INLINE int IN6_IS_ADDR_UNSPECIFIED(const struct in6_addr *a) { return ((a->s6_words[0]==0) && (a->s6_words[1]==0) && (a->s6_words[2]==0) && (a->s6_words[3]==0) && (a->s6_words[4]==0) && (a->s6_words[5]==0) && (a->s6_words[6]==0) && (a->s6_words[7]==0)); }
WS2TCPIP_INLINE int IN6_IS_ADDR_LOOPBACK(const struct in6_addr *a) { return ((a->s6_words[0]==0) && (a->s6_words[1]==0) && (a->s6_words[2]==0) && (a->s6_words[3]==0) && (a->s6_words[4]==0) && (a->s6_words[5]==0) && (a->s6_words[6]==0) && (a->s6_words[7]==0x0100)); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MULTICAST(const struct in6_addr *a) { return (a->s6_bytes[0]==0xff); }
WS2TCPIP_INLINE int IN6_IS_ADDR_LINKLOCAL(const struct in6_addr *a) { return ((a->s6_bytes[0]==0xfe) && ((a->s6_bytes[1] & 0xc0)==0x80)); }
WS2TCPIP_INLINE int IN6_IS_ADDR_SITELOCAL(const struct in6_addr *a) { return ((a->s6_bytes[0]==0xfe) && ((a->s6_bytes[1] & 0xc0)==0xc0)); }
WS2TCPIP_INLINE int IN6_IS_ADDR_V4MAPPED(const struct in6_addr *a) { return ((a->s6_words[0]==0) && (a->s6_words[1]==0) && (a->s6_words[2]==0) && (a->s6_words[3]==0) && (a->s6_words[4]==0) && (a->s6_words[5]==0xffff)); }
WS2TCPIP_INLINE int IN6_IS_ADDR_V4COMPAT(const struct in6_addr *a) { return ((a->s6_words[0]==0) && (a->s6_words[1]==0) && (a->s6_words[2]==0) && (a->s6_words[3]==0) && (a->s6_words[4]==0) && (a->s6_words[5]==0) && !((a->s6_words[6]==0) && (a->s6_addr[14]==0) && ((a->s6_addr[15]==0) || (a->s6_addr[15]==1)))); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MC_NODELOCAL(const struct in6_addr *a) { return IN6_IS_ADDR_MULTICAST(a) && ((a->s6_bytes[1] & 0xf)==1); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MC_LINKLOCAL(const struct in6_addr *a) { return IN6_IS_ADDR_MULTICAST(a) && ((a->s6_bytes[1] & 0xf)==2); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MC_SITELOCAL(const struct in6_addr *a) { return IN6_IS_ADDR_MULTICAST(a) && ((a->s6_bytes[1] & 0xf)==5); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MC_ORGLOCAL(const struct in6_addr *a) { return IN6_IS_ADDR_MULTICAST(a) && ((a->s6_bytes[1] & 0xf)==8); }
WS2TCPIP_INLINE int IN6_IS_ADDR_MC_GLOBAL(const struct in6_addr *a) { return IN6_IS_ADDR_MULTICAST(a) && ((a->s6_bytes[1] & 0xf)==0xe); }
WS2TCPIP_INLINE int IN6ADDR_ISANY(const struct sockaddr_in6 *a) { return ((a->sin6_family==AF_INET6) && IN6_IS_ADDR_UNSPECIFIED(&a->sin6_addr)); }
WS2TCPIP_INLINE int IN6ADDR_ISLOOPBACK(const struct sockaddr_in6 *a) { return ((a->sin6_family==AF_INET6) && IN6_IS_ADDR_LOOPBACK(&a->sin6_addr)); }
WS2TCPIP_INLINE void IN6_SET_ADDR_UNSPECIFIED(struct in6_addr *a) { memset(a->s6_bytes,0,sizeof(struct in6_addr)); }
WS2TCPIP_INLINE void IN6_SET_ADDR_LOOPBACK(struct in6_addr *a) {
  memset(a->s6_bytes,0,sizeof(struct in6_addr));
  a->s6_bytes[15] = 1;
}
WS2TCPIP_INLINE void IN6ADDR_SETANY(struct sockaddr_in6 *a) {
  a->sin6_family = AF_INET6;
  a->sin6_port = 0;
  a->sin6_flowinfo = 0;
  IN6_SET_ADDR_UNSPECIFIED(&a->sin6_addr);
  a->sin6_scope_id = 0;
}
WS2TCPIP_INLINE void IN6ADDR_SETLOOPBACK(struct sockaddr_in6 *a) {
  a->sin6_family = AF_INET6;
  a->sin6_port = 0;
  a->sin6_flowinfo = 0;
  IN6_SET_ADDR_LOOPBACK(&a->sin6_addr);
  a->sin6_scope_id = 0;
}

/* Those declarations are mandatory for Open Group Base spec */
#define IN6_IS_ADDR_UNSPECIFIED IN6_IS_ADDR_UNSPECIFIED
#define IN6_IS_ADDR_LOOPBACK IN6_IS_ADDR_LOOPBACK
#define IN6_IS_ADDR_MULTICAST IN6_IS_ADDR_MULTICAST
#define IN6_IS_ADDR_LINKLOCAL IN6_IS_ADDR_LINKLOCAL
#define IN6_IS_ADDR_SITELOCAL IN6_IS_ADDR_SITELOCAL
#define IN6_IS_ADDR_V4MAPPED IN6_IS_ADDR_V4MAPPED
#define IN6_IS_ADDR_V4COMPAT IN6_IS_ADDR_V4COMPAT
#define IN6_IS_ADDR_MC_NODELOCAL IN6_IS_ADDR_MC_NODELOCAL
#define IN6_IS_ADDR_MC_LINKLOCAL IN6_IS_ADDR_MC_LINKLOCAL
#define IN6_IS_ADDR_MC_SITELOCAL IN6_IS_ADDR_MC_SITELOCAL
#define IN6_IS_ADDR_MC_ORGLOCAL IN6_IS_ADDR_MC_ORGLOCAL
#define IN6_IS_ADDR_MC_GLOBAL IN6_IS_ADDR_MC_GLOBAL

#ifdef __cplusplus
}
#endif

typedef struct _INTERFACE_INFO_EX {
  u_long iiFlags;
  SOCKET_ADDRESS iiAddress;
  SOCKET_ADDRESS iiBroadcastAddress;
  SOCKET_ADDRESS iiNetmask;
} INTERFACE_INFO_EX,*LPINTERFACE_INFO_EX;

#define IFF_UP 0x00000001
#define IFF_BROADCAST 0x00000002
#define IFF_LOOPBACK 0x00000004
#define IFF_POINTTOPOINT 0x00000008
#define IFF_MULTICAST 0x00000010

typedef struct in_pktinfo {
  IN_ADDR ipi_addr;
  UINT ipi_ifindex;
} IN_PKTINFO;

C_ASSERT(sizeof(IN_PKTINFO)==8);

typedef struct in6_pktinfo {
  IN6_ADDR ipi6_addr;
  UINT ipi6_ifindex;
} IN6_PKTINFO;

C_ASSERT(sizeof(IN6_PKTINFO)==20);

#define EAI_AGAIN WSATRY_AGAIN
#define EAI_BADFLAGS WSAEINVAL
#define EAI_FAIL WSANO_RECOVERY
#define EAI_FAMILY WSAEAFNOSUPPORT
#define EAI_MEMORY WSA_NOT_ENOUGH_MEMORY

#define EAI_NONAME WSAHOST_NOT_FOUND
#define EAI_SERVICE WSATYPE_NOT_FOUND
#define EAI_SOCKTYPE WSAESOCKTNOSUPPORT

#define EAI_NODATA 11004 /* WSANO_DATA */

typedef struct addrinfo {
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  size_t ai_addrlen;
  char *ai_canonname;
  struct sockaddr *ai_addr;
  struct addrinfo *ai_next;
} ADDRINFOA,*PADDRINFOA;

typedef struct addrinfoW {
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  size_t ai_addrlen;
  PWSTR ai_canonname;
  struct sockaddr *ai_addr;
  struct addrinfoW *ai_next;
} ADDRINFOW,*PADDRINFOW;

typedef __MINGW_NAME_AW(ADDRINFO) ADDRINFOT,*PADDRINFOT;

typedef ADDRINFOA ADDRINFO,*LPADDRINFO;

#define AI_PASSIVE                  0x00000001
#define AI_CANONNAME                0x00000002
#define AI_NUMERICHOST              0x00000004
#if (_WIN32_WINNT >= 0x0600)
#define AI_NUMERICSERV              0x00000008
#define AI_ALL                      0x00000100
#define AI_ADDRCONFIG               0x00000400
#define AI_V4MAPPED                 0x00000800
#define AI_NON_AUTHORITATIVE        0x00004000
#define AI_SECURE                   0x00008000
#define AI_RETURN_PREFERRED_NAMES   0x00010000
#endif
#if (_WIN32_WINNT >= 0x0601)
#define AI_FQDN                     0x00020000
#define AI_FILESERVER               0x00040000
#endif
#if (_WIN32_WINNT >= 0x0602)
#define AI_DISABLE_IDN_ENCODING     0x00080000
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define GetAddrInfo __MINGW_NAME_AW(GetAddrInfo)

  WINSOCK_API_LINKAGE int WSAAPI getaddrinfo(const char *nodename,const char *servname,const struct addrinfo *hints,struct addrinfo **res);
  WINSOCK_API_LINKAGE int WSAAPI GetAddrInfoW(PCWSTR pNodeName,PCWSTR pServiceName,const ADDRINFOW *pHints,PADDRINFOW *ppResult);

#define GetAddrInfoA getaddrinfo

#if INCL_WINSOCK_API_TYPEDEFS
  typedef int (WSAAPI *LPFN_GETADDRINFO)(const char *nodename,const char *servname,const struct addrinfo *hints,struct addrinfo **res);
  typedef int (WSAAPI *LPFN_GETADDRINFOW)(PCWSTR pNodeName,PCWSTR pServiceName,const ADDRINFOW *pHints,PADDRINFOW *ppResult);

#define LPFN_GETADDRINFOA LPFN_GETADDRINFO

#define LPFN_GETADDRINFOT __MINGW_NAME_AW(LPFN_GETADDRINFO)
#endif

#define FreeAddrInfo __MINGW_NAME_AW(FreeAddrInfo)

  WINSOCK_API_LINKAGE void WSAAPI freeaddrinfo(LPADDRINFO pAddrInfo);
  WINSOCK_API_LINKAGE void WSAAPI FreeAddrInfoW(PADDRINFOW pAddrInfo);

#define FreeAddrInfoA freeaddrinfo

#if INCL_WINSOCK_API_TYPEDEFS
  typedef void (WSAAPI *LPFN_FREEADDRINFO)(struct addrinfo *ai);
  typedef void (WSAAPI *LPFN_FREEADDRINFOW)(PADDRINFOW pAddrInfo);

#define LPFN_FREEADDRINFOA LPFN_FREEADDRINFO

#define LPFN_FREEADDRINFOT __MINGW_NAME_AW(LPFN_FREEADDRINFO)
#endif

  typedef int socklen_t;

#define GetNameInfo __MINGW_NAME_AW(GetNameInfo)

  WINSOCK_API_LINKAGE int WSAAPI getnameinfo(const struct sockaddr *sa,socklen_t salen,char *host,DWORD hostlen,char *serv,DWORD servlen,int flags);
  WINSOCK_API_LINKAGE INT WSAAPI GetNameInfoW(const SOCKADDR *pSockaddr,socklen_t SockaddrLength,PWCHAR pNodeBuffer,DWORD NodeBufferSize,PWCHAR pServiceBuffer,DWORD ServiceBufferSize,INT Flags);

#define GetNameInfoA getnameinfo

#if INCL_WINSOCK_API_TYPEDEFS
  typedef int (WSAAPI *LPFN_GETNAMEINFO)(const struct sockaddr *sa,socklen_t salen,char *host,DWORD hostlen,char *serv,DWORD servlen,int flags);
  typedef INT (WSAAPI *LPFN_GETNAMEINFOW)(const SOCKADDR *pSockaddr,socklen_t SockaddrLength,PWCHAR pNodeBuffer,DWORD NodeBufferSize,PWCHAR pServiceBuffer,DWORD ServiceBufferSize,INT Flags);

#define LPFN_GETNAMEINFOA LPFN_GETNAMEINFO

#define LPFN_GETNAMEINFOT __MINGW_NAME_AW(LPFN_GETNAMEINFO)
#endif

#define gai_strerror __MINGW_NAME_AW(gai_strerror)

#define GAI_STRERROR_BUFFER_SIZE 1024

char *gai_strerrorA (int);
WCHAR *gai_strerrorW(int);

#define NI_MAXHOST 1025
#define NI_MAXSERV 32

#define INET_ADDRSTRLEN 22
#define INET6_ADDRSTRLEN 65

#define NI_NOFQDN 0x01
#define NI_NUMERICHOST 0x02
#define NI_NAMEREQD 0x04
#define NI_NUMERICSERV 0x08
#define NI_DGRAM 0x10

#include <mstcpip.h>

#if (_WIN32_WINNT >= 0x0600)
#define addrinfoEx __MINGW_NAME_AW(addrinfoEx)
#define PADDRINFOEX __MINGW_NAME_AW(PADDRINFOEX)
#define GetAddrInfoEx __MINGW_NAME_AW(GetAddrInfoEx)
#define SetAddrInfoEx __MINGW_NAME_AW(SetAddrInfoEx)

  typedef struct addrinfoExA {
    int                ai_flags;
    int                ai_family;
    int                ai_socktype;
    int                ai_protocol;
    size_t             ai_addrlen;
    LPCSTR             ai_canonname;
    struct sockaddr    *ai_addr;
    void               *ai_blob;
    size_t             ai_bloblen;
    LPGUID             ai_provider;
    struct addrinfoexA *ai_next;
  } ADDRINFOEXA, *PADDRINFOEXA;

  typedef struct addrinfoExW {
    int                ai_flags;
    int                ai_family;
    int                ai_socktype;
    int                ai_protocol;
    size_t             ai_addrlen;
    LPCWSTR            ai_canonname;
    struct sockaddr    *ai_addr;
    void               *ai_blob;
    size_t             ai_bloblen;
    LPGUID             ai_provider;
    struct addrinfoexW *ai_next;
  } ADDRINFOEXW, *PADDRINFOEXW;

typedef PVOID LPLOOKUPSERVICE_COMPLETION_ROUTINE; /*reserved*/

WINSOCK_API_LINKAGE int WSAAPI GetAddrInfoExA(PCSTR pName, PCSTR pServiceName, DWORD dwNameSpace,
					      LPGUID lpNspId,const ADDRINFOEXA *pHints,PADDRINFOEXA *ppResult,
					      PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					      LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					      LPHANDLE lpNameHandle);
WINSOCK_API_LINKAGE int WSAAPI GetAddrInfoExW(PCWSTR pName,PCWSTR pServiceName,DWORD dwNameSpace,
					      LPGUID lpNspId,const ADDRINFOEXW *pHints,PADDRINFOEXW *ppResult,
					      PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					      LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					      LPHANDLE lpNameHandle);

WINSOCK_API_LINKAGE int WSAAPI SetAddrInfoExA(PCSTR pName, PCSTR pServiceName, SOCKET_ADDRESS *pAddresses,
					      DWORD dwAddressCount,LPBLOB lpBlob,DWORD dwFlags,DWORD dwNameSpace,
					      LPGUID lpNspId,PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					      LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					      LPHANDLE lpNameHandle);
WINSOCK_API_LINKAGE int WSAAPI SetAddrInfoExW(PCWSTR pName,PCWSTR pServiceName,SOCKET_ADDRESS *pAddresses,
					      DWORD dwAddressCount,LPBLOB lpBlob,DWORD dwFlags,DWORD dwNameSpace,
					      LPGUID lpNspId,PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					      LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					      LPHANDLE lpNameHandle);

WINSOCK_API_LINKAGE void WSAAPI FreeAddrInfoEx(PADDRINFOEXA pAddrInfo);
WINSOCK_API_LINKAGE void WSAAPI FreeAddrInfoExW(PADDRINFOEXW pAddrInfo);

#define FreeAddrInfoExA FreeAddrInfoEx
#ifdef UNICODE
#  define FreeAddrInfoEx FreeAddrInfoExW
#endif  /* UNICODE */

#if INCL_WINSOCK_API_TYPEDEFS
#define LPFN_GETADDRINFOEX __MINGW_NAME_AW(LPFN_GETADDRINFOEX)
  typedef int (WSAAPI *LPFN_GETADDRINFOEXA)(PCSTR pName, PCSTR pServiceName, DWORD dwNameSpace,
					    LPGUID lpNspId,const ADDRINFOEXA *pHints,PADDRINFOEXA *ppResult,
					    PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					    LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					    LPHANDLE lpNameHandle);
  typedef int (WSAAPI *LPFN_GETADDRINFOEXW)(PCWSTR pName,PCWSTR pServiceName,DWORD dwNameSpace,
					    LPGUID lpNspId,const ADDRINFOEXW *pHints,PADDRINFOEXW *ppResult,
					    PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					    LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					    LPHANDLE lpNameHandle);

#define LPFN_SETADDRINFOEX __MINGW_NAME_AW(LPFN_SETADDRINFOEX)
  typedef int (WSAAPI *LPFN_SETADDRINFOEXA)(PCSTR pName, PCSTR pServiceName, SOCKET_ADDRESS *pAddresses,
					    DWORD dwAddressCount,LPBLOB lpBlob,DWORD dwFlags,DWORD dwNameSpace,
					    LPGUID lpNspId,PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					    LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					    LPHANDLE lpNameHandle);
  typedef int (WSAAPI *LPFN_SETADDRINFOEXW)(PCWSTR pName,PCWSTR pServiceName,SOCKET_ADDRESS *pAddresses,
					    DWORD dwAddressCount,LPBLOB lpBlob,DWORD dwFlags,DWORD dwNameSpace,
					    LPGUID lpNspId,PTIMEVAL timeout,LPOVERLAPPED lpOverlapped,
					    LPLOOKUPSERVICE_COMPLETION_ROUTINE lpCompletionRoutine,
					    LPHANDLE lpNameHandle);

#define LPFN_FREEADDRINFOEX __MINGW_NAME_AW(LPFN_FREEADDRINFOEX)
  typedef void (WSAAPI *LPFN_FREEADDRINFOEXA)(PADDRINFOEXA pAddrInfo);
  typedef void (WSAAPI *LPFN_FREEADDRINFOEXW)(PADDRINFOEXW pAddrInfo);
#endif /* INCL_WINSOCK_API_TYPEDEFS */


WINSOCK_API_LINKAGE int WSAAPI WSAImpersonateSocketPeer(
  SOCKET Socket,
  const struct sockaddr *PeerAddress,
  ULONG peerAddressLen
);

WINSOCK_API_LINKAGE int WSAAPI WSAQuerySocketSecurity(
  SOCKET Socket,
  const SOCKET_SECURITY_QUERY_TEMPLATE *SecurityQueryTemplate,
  ULONG SecurityQueryTemplateLen,
  SOCKET_SECURITY_QUERY_INFO *SecurityQueryInfo,
  ULONG *SecurityQueryInfoLen,
  LPWSAOVERLAPPED Overlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine
);

WINSOCK_API_LINKAGE int WSAAPI WSARevertImpersonation(void);

WINSOCK_API_LINKAGE int WSAAPI WSASetSocketPeerTargetName(
  SOCKET Socket,
  const SOCKET_PEER_TARGET_NAME *PeerTargetName,
  ULONG PeerTargetNameLen,
  LPWSAOVERLAPPED Overlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine
);

WINSOCK_API_LINKAGE int WSAAPI WSASetSocketSecurity(
  SOCKET Socket,
  const SOCKET_SECURITY_SETTINGS *SecuritySettings,
  ULONG SecuritySettingsLen,
  LPWSAOVERLAPPED Overlapped,
  LPWSAOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine
);

#define InetNtopA inet_ntop

WINSOCK_API_LINKAGE LPCWSTR WSAAPI InetNtopW(INT Family, LPCVOID pAddr, LPWSTR pStringBuf, size_t StringBufSIze);
WINSOCK_API_LINKAGE LPCSTR WSAAPI InetNtopA(INT Family, LPCVOID pAddr, LPSTR pStringBuf, size_t StringBufSize);

#define InetNtop __MINGW_NAME_AW(InetNtop)

#define InetPtonA inet_pton

WINSOCK_API_LINKAGE INT WSAAPI InetPtonW(INT Family, LPCWSTR pStringBuf, PVOID pAddr);
WINSOCK_API_LINKAGE INT WSAAPI InetPtonA(INT Family, LPCSTR pStringBuf, PVOID pAddr);

#define InetPton __MINGW_NAME_AW(InetPton)

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif

#ifdef __LP64__
#pragma pop_macro("u_long")
#endif

#endif /* _WS2TCPIP_H_ */
