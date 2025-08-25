/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __IPHLPAPI_H__
#define __IPHLPAPI_H__

#include <winapifamily.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <iprtrmib.h>
#include <ipexport.h>
#include <iptypes.h>
#include <tcpestats.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= 0x0A00

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

  DWORD WINAPI GetNumberOfInterfaces (PDWORD pdwNumIf);
  DWORD WINAPI GetIfEntry (PMIB_IFROW pIfRow);
  DWORD WINAPI GetIfTable (PMIB_IFTABLE pIfTable, PULONG pdwSize, WINBOOL bOrder);
  DWORD WINAPI GetIpAddrTable (PMIB_IPADDRTABLE pIpAddrTable, PULONG pdwSize, WINBOOL bOrder);
  ULONG WINAPI GetIpNetTable (PMIB_IPNETTABLE IpNetTable, PULONG SizePointer, WINBOOL Order);
  DWORD WINAPI GetIpForwardTable (PMIB_IPFORWARDTABLE pIpForwardTable, PULONG pdwSize, WINBOOL bOrder);
  ULONG WINAPI GetTcpTable (PMIB_TCPTABLE TcpTable, PULONG SizePointer, WINBOOL Order);
  DWORD WINAPI GetExtendedTcpTable (PVOID pTcpTable, PDWORD pdwSize, WINBOOL bOrder, ULONG ulAf, TCP_TABLE_CLASS TableClass, ULONG Reserved);
  DWORD WINAPI GetOwnerModuleFromTcpEntry (PMIB_TCPROW_OWNER_MODULE pTcpEntry, TCPIP_OWNER_MODULE_INFO_CLASS Class, PVOID pBuffer, PDWORD pdwSize);
  ULONG WINAPI GetUdpTable (PMIB_UDPTABLE UdpTable, PULONG SizePointer, WINBOOL Order);
  DWORD WINAPI GetExtendedUdpTable (PVOID pUdpTable, PDWORD pdwSize, WINBOOL bOrder, ULONG ulAf, UDP_TABLE_CLASS TableClass, ULONG Reserved);
  DWORD WINAPI GetOwnerModuleFromUdpEntry (PMIB_UDPROW_OWNER_MODULE pUdpEntry, TCPIP_OWNER_MODULE_INFO_CLASS Class, PVOID pBuffer, PDWORD pdwSize);
#if NTDDI_VERSION < 0x06000000
  DWORD AllocateAndGetTcpExTableFromStack (PVOID *ppTcpTable, WINBOOL bOrder, HANDLE hHeap, DWORD dwFlags, DWORD dwFamily);
  DWORD AllocateAndGetUdpExTableFromStack (PVOID *ppUdpTable, WINBOOL bOrder, HANDLE hHeap, DWORD dwFlags, DWORD dwFamily);
#else
  ULONG WINAPI GetTcpTable2 (PMIB_TCPTABLE2 TcpTable, PULONG SizePointer, WINBOOL Order);
#endif

#ifdef _WS2IPDEF_

#if NTDDI_VERSION >= 0x06000000
  ULONG WINAPI GetTcp6Table (PMIB_TCP6TABLE TcpTable, PULONG SizePointer, WINBOOL Order);
  ULONG WINAPI GetTcp6Table2 (PMIB_TCP6TABLE2 TcpTable, PULONG SizePointer, WINBOOL Order);
  ULONG WINAPI GetPerTcpConnectionEStats (PMIB_TCPROW Row, TCP_ESTATS_TYPE EstatsType, PUCHAR Rw, ULONG RwVersion, ULONG RwSize, PUCHAR Ros, ULONG RosVersion, ULONG RosSize, PUCHAR Rod, ULONG RodVersion, ULONG RodSize);
  ULONG WINAPI SetPerTcpConnectionEStats (PMIB_TCPROW Row, TCP_ESTATS_TYPE EstatsType, PUCHAR Rw, ULONG RwVersion, ULONG RwSize, ULONG Offset);
  ULONG WINAPI GetPerTcp6ConnectionEStats (PMIB_TCP6ROW Row, TCP_ESTATS_TYPE EstatsType, PUCHAR Rw, ULONG RwVersion, ULONG RwSize, PUCHAR Ros, ULONG RosVersion, ULONG RosSize, PUCHAR Rod, ULONG RodVersion, ULONG RodSize);
  ULONG WINAPI SetPerTcp6ConnectionEStats (PMIB_TCP6ROW Row, TCP_ESTATS_TYPE EstatsType, PUCHAR Rw, ULONG RwVersion, ULONG RwSize, ULONG Offset);
  ULONG WINAPI GetUdp6Table (PMIB_UDP6TABLE Udp6Table, PULONG SizePointer, WINBOOL Order);
#endif
  DWORD WINAPI GetOwnerModuleFromTcp6Entry (PMIB_TCP6ROW_OWNER_MODULE pTcpEntry, TCPIP_OWNER_MODULE_INFO_CLASS Class, PVOID pBuffer, PDWORD pdwSize);
  DWORD WINAPI GetOwnerModuleFromUdp6Entry (PMIB_UDP6ROW_OWNER_MODULE pUdpEntry, TCPIP_OWNER_MODULE_INFO_CLASS Class, PVOID pBuffer, PDWORD pdwSize);
#endif
  DWORD GetOwnerModuleFromPidAndInfo (ULONG ulPid, ULONGLONG *pInfo, TCPIP_OWNER_MODULE_INFO_CLASS Class, PVOID pBuffer, PDWORD pdwSize);
  ULONG WINAPI GetIpStatistics (PMIB_IPSTATS Statistics);
  ULONG WINAPI GetIcmpStatistics (PMIB_ICMP Statistics);
  ULONG WINAPI GetTcpStatistics (PMIB_TCPSTATS Statistics);
  ULONG WINAPI GetUdpStatistics (PMIB_UDPSTATS Stats);
  ULONG WINAPI GetIpStatisticsEx (PMIB_IPSTATS Statistics, ULONG Family);
  ULONG WINAPI SetIpStatisticsEx (PMIB_IPSTATS Statistics, ULONG Family);
  ULONG WINAPI GetIcmpStatisticsEx (PMIB_ICMP_EX Statistics, ULONG Family);
  ULONG WINAPI GetTcpStatisticsEx (PMIB_TCPSTATS Statistics, ULONG Family);
  ULONG WINAPI GetUdpStatisticsEx (PMIB_UDPSTATS Statistics, ULONG Family);
  DWORD WINAPI SetIfEntry (PMIB_IFROW pIfRow);
  DWORD WINAPI CreateIpForwardEntry (PMIB_IPFORWARDROW pRoute);
  DWORD WINAPI SetIpForwardEntry (PMIB_IPFORWARDROW pRoute);
  DWORD WINAPI DeleteIpForwardEntry (PMIB_IPFORWARDROW pRoute);
  DWORD WINAPI SetIpStatistics (PMIB_IPSTATS pIpStats);
  DWORD WINAPI SetIpTTL (UINT nTTL);
  DWORD WINAPI CreateIpNetEntry (PMIB_IPNETROW pArpEntry);
  DWORD WINAPI SetIpNetEntry (PMIB_IPNETROW pArpEntry);
  DWORD WINAPI DeleteIpNetEntry (PMIB_IPNETROW pArpEntry);
  DWORD WINAPI FlushIpNetTable (DWORD dwIfIndex);
  DWORD WINAPI CreateProxyArpEntry (DWORD dwAddress, DWORD dwMask, DWORD dwIfIndex);
  DWORD WINAPI DeleteProxyArpEntry (DWORD dwAddress, DWORD dwMask, DWORD dwIfIndex);
  DWORD WINAPI SetTcpEntry (PMIB_TCPROW pTcpRow);
  DWORD WINAPI GetInterfaceInfo (PIP_INTERFACE_INFO pIfTable, PULONG dwOutBufLen);
  DWORD WINAPI GetUniDirectionalAdapterInfo (PIP_UNIDIRECTIONAL_ADAPTER_ADDRESS pIPIfInfo, PULONG dwOutBufLen);
#ifndef NHPALLOCATEANDGETINTERFACEINFOFROMSTACK_DEFINED
#define NHPALLOCATEANDGETINTERFACEINFOFROMSTACK_DEFINED
  DWORD WINAPI NhpAllocateAndGetInterfaceInfoFromStack (IP_INTERFACE_NAME_INFO **ppTable, PDWORD pdwCount, WINBOOL bOrder, HANDLE hHeap, DWORD dwFlags);
#endif
  DWORD WINAPI GetBestInterface (IPAddr dwDestAddr, PDWORD pdwBestIfIndex);
  DWORD WINAPI GetBestInterfaceEx (struct sockaddr *pDestAddr, PDWORD pdwBestIfIndex);
  DWORD WINAPI GetBestRoute (DWORD dwDestAddr, DWORD dwSourceAddr, PMIB_IPFORWARDROW pBestRoute);
  DWORD WINAPI NotifyAddrChange (PHANDLE Handle, LPOVERLAPPED overlapped);
  DWORD WINAPI NotifyRouteChange (PHANDLE Handle, LPOVERLAPPED overlapped);
  WINBOOL WINAPI CancelIPChangeNotify (LPOVERLAPPED notifyOverlapped);
  DWORD WINAPI GetAdapterIndex (LPWSTR AdapterName, PULONG IfIndex);
  DWORD WINAPI AddIPAddress (IPAddr Address, IPMask IpMask, DWORD IfIndex, PULONG NTEContext, PULONG NTEInstance);
  DWORD WINAPI DeleteIPAddress (ULONG NTEContext);
  DWORD WINAPI GetNetworkParams (PFIXED_INFO pFixedInfo, PULONG pOutBufLen);
  ULONG WINAPI GetAdaptersInfo (PIP_ADAPTER_INFO AdapterInfo, PULONG SizePointer);
  PIP_ADAPTER_ORDER_MAP WINAPI GetAdapterOrderMap (VOID);

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) */

#ifdef _WINSOCK2API_
  ULONG WINAPI GetAdaptersAddresses (ULONG Family, ULONG Flags, PVOID Reserved, PIP_ADAPTER_ADDRESSES AdapterAddresses, PULONG SizePointer);
#endif

  DWORD WINAPI GetPerAdapterInfo (ULONG IfIndex, PIP_PER_ADAPTER_INFO pPerAdapterInfo, PULONG pOutBufLen);
  DWORD WINAPI IpReleaseAddress (PIP_ADAPTER_INDEX_MAP AdapterInfo);
  DWORD WINAPI IpRenewAddress (PIP_ADAPTER_INDEX_MAP AdapterInfo);
  DWORD WINAPI SendARP (IPAddr DestIP, IPAddr SrcIP, PVOID pMacAddr, PULONG PhyAddrLen);
  WINBOOL WINAPI GetRTTAndHopCount (IPAddr DestIpAddress, PULONG HopCount, ULONG MaxHops, PULONG RTT);
  DWORD WINAPI GetFriendlyIfIndex (DWORD IfIndex);
  DWORD WINAPI EnableRouter (HANDLE *pHandle, OVERLAPPED *pOverlapped);
  DWORD WINAPI UnenableRouter (OVERLAPPED *pOverlapped, LPDWORD lpdwEnableCount);
  DWORD WINAPI DisableMediaSense (HANDLE *pHandle, OVERLAPPED *pOverLapped);
  DWORD WINAPI RestoreMediaSense (OVERLAPPED *pOverlapped, LPDWORD lpdwEnableCount);

#if NTDDI_VERSION >= 0x06000000
#define NET_STRING_IPV4_ADDRESS 0x00000001
#define NET_STRING_IPV4_SERVICE 0x00000002
#define NET_STRING_IPV4_NETWORK 0x00000004
#define NET_STRING_IPV6_ADDRESS 0x00000008
#define NET_STRING_IPV6_ADDRESS_NO_SCOPE 0x00000010
#define NET_STRING_IPV6_SERVICE 0x00000020
#define NET_STRING_IPV6_SERVICE_NO_SCOPE 0x00000040
#define NET_STRING_IPV6_NETWORK 0x00000080
#define NET_STRING_NAMED_ADDRESS 0x00000100
#define NET_STRING_NAMED_SERVICE 0x00000200

#define NET_STRING_IP_ADDRESS (NET_STRING_IPV4_ADDRESS | NET_STRING_IPV6_ADDRESS)
#define NET_STRING_IP_ADDRESS_NO_SCOPE (NET_STRING_IPV4_ADDRESS | NET_STRING_IPV6_ADDRESS_NO_SCOPE)
#define NET_STRING_IP_SERVICE (NET_STRING_IPV4_SERVICE | NET_STRING_IPV6_SERVICE)
#define NET_STRING_IP_SERVICE_NO_SCOPE (NET_STRING_IPV4_SERVICE | NET_STRING_IPV6_SERVICE_NO_SCOPE)
#define NET_STRING_IP_NETWORK (NET_STRING_IPV4_NETWORK | NET_STRING_IPV6_NETWORK)
#define NET_STRING_ANY_ADDRESS (NET_STRING_NAMED_ADDRESS | NET_STRING_IP_ADDRESS)
#define NET_STRING_ANY_ADDRESS_NO_SCOPE (NET_STRING_NAMED_ADDRESS | NET_STRING_IP_ADDRESS_NO_SCOPE)
#define NET_STRING_ANY_SERVICE (NET_STRING_NAMED_SERVICE | NET_STRING_IP_SERVICE)
#define NET_STRING_ANY_SERVICE_NO_SCOPE (NET_STRING_NAMED_SERVICE | NET_STRING_IP_SERVICE_NO_SCOPE)

  typedef enum NET_ADDRESS_FORMAT_ {
    NET_ADDRESS_FORMAT_UNSPECIFIED = 0,
    NET_ADDRESS_DNS_NAME,
    NET_ADDRESS_IPV4,
    NET_ADDRESS_IPV6
  } NET_ADDRESS_FORMAT;

#if defined (_WS2DEF_) && defined (_WS2IPDEF_) && defined (_WINDNS_INCLUDED_)
  typedef struct NET_ADDRESS_INFO_ {
    NET_ADDRESS_FORMAT Format;
    __C89_NAMELESS union {
      struct {
	WCHAR Address[DNS_MAX_NAME_BUFFER_LENGTH];
	WCHAR Port[6];
      } NamedAddress;
      SOCKADDR_IN Ipv4Address;
      SOCKADDR_IN6 Ipv6Address;
      SOCKADDR IpAddress;
    };
  } NET_ADDRESS_INFO,*PNET_ADDRESS_INFO;

  DWORD WINAPI ParseNetworkString (CONST WCHAR *NetworkString, DWORD Types, PNET_ADDRESS_INFO AddressInfo, USHORT *PortNumber, BYTE *PrefixLength);
#endif
  DWORD WINAPI GetIpErrorString (IP_STATUS ErrorCode, PWSTR Buffer, PDWORD Size);
#ifdef _WS2DEF_
  ULONG WINAPI ResolveNeighbor (SOCKADDR *NetworkAddress, PVOID PhysicalAddress, PULONG PhysicalAddressLength);
#endif
  ULONG WINAPI CreatePersistentTcpPortReservation (USHORT StartPort, USHORT NumberOfPorts, PULONG64 Token);
  ULONG WINAPI CreatePersistentUdpPortReservation (USHORT StartPort, USHORT NumberOfPorts, PULONG64 Token);
  ULONG WINAPI DeletePersistentTcpPortReservation (USHORT StartPort, USHORT NumberOfPorts);
  ULONG WINAPI DeletePersistentUdpPortReservation (USHORT StartPort, USHORT NumberOfPorts);
  ULONG WINAPI LookupPersistentTcpPortReservation (USHORT StartPort, USHORT NumberOfPorts, PULONG64 Token);
  ULONG WINAPI LookupPersistentUdpPortReservation (USHORT StartPort, USHORT NumberOfPorts, PULONG64 Token);
#endif

#if NTDDI_VERSION >= 0x06000000
#include <netioapi.h>
#endif

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= 0x0A00 */

#ifdef __cplusplus
}
#endif

#endif
