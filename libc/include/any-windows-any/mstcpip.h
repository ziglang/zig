/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSTCPIP_
#define _MSTCPIP_

#include <_mingw_unicode.h>
#include <winapifamily.h>

#ifdef __LP64__
#pragma push_macro("u_long")
#undef u_long
#define u_long __ms_u_long
#endif

struct tcp_keepalive {
  u_long onoff;
  u_long keepalivetime;
  u_long keepaliveinterval;
};

#define SIO_RCVALL _WSAIOW(IOC_VENDOR,1)
#define SIO_RCVALL_MCAST _WSAIOW(IOC_VENDOR,2)
#define SIO_RCVALL_IGMPMCAST _WSAIOW(IOC_VENDOR,3)
#define SIO_KEEPALIVE_VALS _WSAIOW(IOC_VENDOR,4)
#define SIO_ABSORB_RTRALERT _WSAIOW(IOC_VENDOR,5)
#define SIO_UCAST_IF _WSAIOW(IOC_VENDOR,6)
#define SIO_LIMIT_BROADCASTS _WSAIOW(IOC_VENDOR,7)
#define SIO_INDEX_BIND _WSAIOW(IOC_VENDOR,8)
#define SIO_INDEX_MCASTIF _WSAIOW(IOC_VENDOR,9)
#define SIO_INDEX_ADD_MCAST _WSAIOW(IOC_VENDOR,10)
#define SIO_INDEX_DEL_MCAST _WSAIOW(IOC_VENDOR,11)

#define RCVALL_OFF 0
#define RCVALL_ON 1
#define RCVALL_SOCKETLEVELONLY 2
#define RCVALL_IPLEVEL 3

#if (_WIN32_WINNT >= 0x0502)
typedef enum _SOCKET_SECURITY_PROTOCOL {
  SOCKET_SECURITY_PROTOCOL_DEFAULT,
  SOCKET_SECURITY_PROTOCOL_IPSEC,
#if NTDDI_VERSION >= NTDDI_WIN7
  SOCKET_SECURITY_PROTOCOL_IPSEC2,
#endif
  SOCKET_SECURITY_PROTOCOL_INVALID 
} SOCKET_SECURITY_PROTOCOL;

#define SOCKET_SETTINGS_GUARANTEE_ENCRYPTION  0x1
#define SOCKET_SETTINGS_ALLOW_INSECURE  0x2

typedef enum _SOCKET_USAGE_TYPE {
  SYSTEM_CRITICAL_SOCKET   = 1 
} SOCKET_USAGE_TYPE;

typedef struct _SOCKET_PEER_TARGET_NAME {
  SOCKET_SECURITY_PROTOCOL SecurityProtocol;
  SOCKADDR_STORAGE         PeerAddress;
  ULONG                    PeerTargetNameStringLen;
  wchar_t                  AllStrings[];
} SOCKET_PEER_TARGET_NAME;

#define SOCKET_INFO_CONNECTION_SECURED		0x00000001
#define SOCKET_INFO_CONNECTION_ENCRYPTED	0x00000002
#define SOCKET_INFO_CONNECTION_IMPERSONATED	0x00000004

typedef struct _SOCKET_SECURITY_QUERY_INFO {
  SOCKET_SECURITY_PROTOCOL SecurityProtocol;
  ULONG                    Flags;
  UINT64                   PeerApplicationAccessTokenHandle;
  UINT64                   PeerMachineAccessTokenHandle;
} SOCKET_SECURITY_QUERY_INFO;

typedef struct _SOCKET_SECURITY_QUERY_TEMPLATE {
  SOCKET_SECURITY_PROTOCOL SecurityProtocol;
  SOCKADDR_STORAGE         PeerAddress;
  ULONG                    PeerTokenAccessMask;
} SOCKET_SECURITY_QUERY_TEMPLATE;

typedef struct _SOCKET_SECURITY_SETTINGS {
  SOCKET_SECURITY_PROTOCOL SecurityProtocol;
  ULONG                    SecurityFlags;
} SOCKET_SECURITY_SETTINGS;

#define SOCKET_SETTINGS_IPSEC_SKIP_FILTER_INSTANTIATION 0x00000001

typedef struct _SOCKET_SECURITY_SETTINGS_IPSEC {
  SOCKET_SECURITY_PROTOCOL SecurityProtocol;
  ULONG                    SecurityFlags;
  ULONG                    IpsecFlags;
  GUID                     AuthipMMPolicyKey;
  GUID                     AuthipQMPolicyKey;
  GUID                     Reserved;
  UINT64                   Reserved2;
  ULONG                    UserNameStringLen;
  ULONG                    DomainNameStringLen;
  ULONG                    PasswordStringLen;
  wchar_t                  AllStrings[];
} SOCKET_SECURITY_SETTINGS_IPSEC;

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#define RtlIpv6AddressToString __MINGW_NAME_AW(RtlIpv6AddressToString)
#define RtlIpv6AddressToStringEx __MINGW_NAME_AW(RtlIpv6AddressToStringEx)

#ifdef _WS2IPDEF_

LPSTR NTAPI RtlIpv6AddressToStringA(const IN6_ADDR *Addr, LPSTR S);
LPWSTR NTAPI RtlIpv6AddressToStringW(const IN6_ADDR *Addr, LPWSTR S);

LONG NTAPI RtlIpv6AddressToStringExA(const IN6_ADDR *Address, ULONG ScopeId, USHORT Port, LPSTR AddressString, PULONG AddressStringLength);
LONG NTAPI RtlIpv6AddressToStringExW(const IN6_ADDR *Address, ULONG ScopeId, USHORT Port, LPWSTR AddressString, PULONG AddressStringLength);

#define RtlIpv4AddressToString __MINGW_NAME_AW(RtlIpv4AddressToString)
LPSTR NTAPI RtlIpv4AddressToStringA(const IN_ADDR *Addr, LPSTR S);
LPWSTR NTAPI RtlIpv4AddressToStringW(const IN_ADDR *Addr, LPWSTR S);

#define RtlIpv4AddressToStringEx __MINGW_NAME_AW(RtlIpv4AddressToStringEx)
LONG NTAPI RtlIpv4AddressToStringExA(const IN_ADDR *Address, USHORT Port, LPSTR AddressString, PULONG AddressStringLength);
LONG NTAPI RtlIpv4AddressToStringExW(const IN_ADDR *Address, USHORT Port, LPWSTR AddressString, PULONG AddressStringLength);

#define RtlIpv4StringToAddress __MINGW_NAME_AW(RtlIpv4StringToAddress)
LONG NTAPI RtlIpv4StringToAddressA(PCSTR S, BOOLEAN Strict, LPSTR *Terminator, IN_ADDR *Addr);
LONG NTAPI RtlIpv4StringToAddressW(PCWSTR S, BOOLEAN Strict, LPWSTR *Terminator, IN_ADDR *Addr);

#define RtlIpv4StringToAddressEx __MINGW_NAME_AW(RtlIpv4StringToAddressEx)
LONG NTAPI RtlIpv4StringToAddressExA(PCSTR AddressString, BOOLEAN Strict, IN_ADDR *Address, PUSHORT Port);
LONG NTAPI RtlIpv4StringToAddressExW(PCWSTR AddressString, BOOLEAN Strict, IN_ADDR *Address, PUSHORT Port);

#define RtlIpv6StringToAddressEx __MINGW_NAME_AW(RtlIpv6StringToAddressEx)
LONG NTAPI RtlIpv6StringToAddressExA(PCSTR AddressString, IN6_ADDR *Address, PULONG ScopeId, PUSHORT Port);
LONG NTAPI RtlIpv6StringToAddressExW(PCWSTR AddressString, IN6_ADDR *Address, PULONG ScopeId, PUSHORT Port);

#endif /* _WS2IPDEF_ */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */
#endif /*(_WIN32_WINNT >= 0x0502)*/

#ifdef __LP64__
#pragma pop_macro("u_long")
#endif

#endif /* _MSTCPIP_ */

