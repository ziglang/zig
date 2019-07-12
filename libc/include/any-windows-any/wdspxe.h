/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WDSPXE
#define _INC_WDSPXE
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

#define PXE_ADDR_BROADCAST 0x0001
#define PXE_ADDR_USE_PORT 0x0002
#define PXE_ADDR_USE_ADDR 0x0004
#define PXE_ADDR_USE_DHCP_RULES 0x0008

#ifndef PXEAPI
#define PXEAPI WINAPI
#endif

typedef ULONG PXE_BOOT_ACTION;
typedef ULONG PXE_REG_INDEX;
typedef ULONG PXE_PROVIDER_ATTRIBUTE;

typedef struct tagPXE_ADDRESS {
  ULONG  uFlags;
  __C89_NAMELESS union {
    BYTE  bAddress[PXE_MAX_ADDRESS];
    ULONG uIpAddress;
  } DUMMYUNIONNAME;
  ULONG  uAddrLen;
  USHORT uPort;
} PXE_ADDRESS, *PPXE_ADDRESS;

typedef struct _PXE_DHCP_MESSAGE {
  BYTE  Operation;
  BYTE  HardwareAddressType;
  BYTE  HardwareAddressLength;
  BYTE  HopCount;
  DWORD TransactionID;
  WORD  SecondsSinceBoot;
  WORD  Reserved;
  ULONG ClientIpAddress;
  ULONG YourIPAddress;
  ULONG BootstrapServerAddress;
  ULONG RelayAgentIpAddress;
  BYTE  HardwareAddress[PXE_DHCP_HWAADR_SIZE];
  BYTE  HostName[PXE_DHCP_SERVER_SIZE];
  BYTE  BootFileName;
  __C89_NAMELESS union {
    BYTE  bMagicCookie[PXE_DHCP_MAGIC_COOKIE_SIZE];
    ULONG uMagicCookie;
  } DUMMYUNIONNAME;
} PXE_DHCP_MESSAGE, *PPXE_DHCP_MESSAGE;

typedef struct _PXE_DHCP_OPTION {
  BYTE OptionType;
  BYTE OptionLength;
  BYTE OptionValue[1];
} PXE_DHCP_OPTION, *PPXE_DHCP_OPTION;

#define PXE_BA_NBP 1
#define PXE_BA_CUSTOM 2
#define PXE_BA_IGNORE 3
#define PXE_BA_REJECTED 4

typedef struct tagPXE_PROVIDER {
  ULONG  uSizeOfStruct;
  LPWSTR pwszName;
  LPWSTR pwszFilePath;
  WINBOOL   bIsCritical;
  ULONG  uIndex;
} PXE_PROVIDER, *PPXE_PROVIDER;

DWORD PXEAPI PxeDhcpAppendOption(PVOID pReplyPacket,ULONG uMaxReplyPacketLen,PULONG puReplyPacketLen,BYTE bOption,BYTE bOptionLen,PVOID pValue);
DWORD PXEAPI PxeDhcpGetOptionValue(PVOID pPacket,ULONG uPacketLen,ULONG uInstance,BYTE bOption,PBYTE pbOptionLen,PVOID *ppOptionValue);
DWORD PXEAPI PxeDhcpGetVendorOptionValue(PVOID pPacket,ULONG uPacketLen,BYTE bOption,ULONG uInstance,PBYTE pbOptionLen,PVOID *ppOptionValue);
DWORD PXEAPI PxeDhcpInitialize(PVOID pRecvPacket,ULONG uRecvPacketLen,PVOID pReplyPacket,ULONG uMaxReplyPacketLen,PULONG puReplyPacketLen);
DWORD PXEAPI PxeDhcpIsValid(PVOID pPacket,ULONG uPacketLen,WINBOOL bRequestPacket,PBOOL pbPxeOptionPresent);

typedef enum _PXE_GSI_TYPE {
  PXE_GSI_TRACE_ENABLED = 1
} PXE_GSI_TYPE;

DWORD PXEAPI PxeGetServerInfo(PXE_GSI_TYPE uInfoType,PVOID pBuffer,ULONG uBufferLen);
PVOID PXEAPI PxePacketAllocate(HANDLE hProvider,HANDLE hClientRequest,ULONG uSize);
DWORD PXEAPI PxePacketFree(HANDLE hProvider,HANDLE hClientRequest,PVOID pPacket);
DWORD PXEAPI PxeProviderEnumClose(HANDLE hEnum);
DWORD PXEAPI PxeProviderEnumFirst(HANDLE *phEnum);
DWORD PXEAPI PxeProviderEnumNext(HANDLE hEnum,PPXE_PROVIDER *ppProvider);
DWORD PXEAPI PxeProviderFreeInfo(PPXE_PROVIDER pProvider);
DWORD PXEAPI PxeProviderInitialize(HANDLE hProvider,HKEY hProviderKey);
DWORD PXEAPI PxeProviderQueryIndex(LPCWSTR pszProviderName,PULONG puIndex);
DWORD PXEAPI PxeProviderRecvRequest(HANDLE hClientRequest,PVOID pPacket,ULONG uPacketLen,PXE_ADDRESS *pLocalAddress,PXE_ADDRESS *pRemoteAddress,PXE_BOOT_ACTION pAction,PVOID pContext);

#define PXE_REG_INDEX_TOP	__MSABI_LONG(0U)
#define PXE_REG_INDEX_BOTTOM	__MSABI_LONG(0xFFFFFFFFU)

DWORD PXEAPI PxeProviderRegister(LPCWSTR pszProviderName,LPCWSTR pszModulePath,PXE_REG_INDEX Index,WINBOOL bIsCritical,PHKEY phProviderKey);
DWORD PXEAPI PxeProviderServiceControl(PVOID pContext,DWORD dwControl);
DWORD PXEAPI PxeProviderSetAttribute(HANDLE hProvider,PXE_PROVIDER_ATTRIBUTE Attribute,PVOID pParameterBuffer,ULONG uParamLen);

#define PXE_PROV_ATTR_FILTER 0

#define PXE_PROV_FILTER_ALL 0x0000
#define PXE_PROV_FILTER_DHCP_ONLY 0x0001
#define PXE_PROV_FILTER_PXE_ONLY 0x0002

DWORD PXEAPI PxeProviderSetAttribute(HANDLE hProvider,PXE_PROVIDER_ATTRIBUTE Attribute,PVOID pParameterBuffer,ULONG uParamLen);
DWORD PXEAPI PxeProviderShutdown(PVOID pContext);
DWORD PXEAPI PxeProviderUnRegister(LPCWSTR pszProviderName);

typedef enum _PXE_CALLBACK_TYPE {
  PXE_CALLBACK_RECV_REQUEST = 0,
  PXE_CALLBACK_SHUTDOWN,
  PXE_CALLBACK_SERVICE_CONTROL,
  PXE_CALLBACK_MAX
} PXE_CALLBACK_TYPE;

DWORD PXEAPI PxeSendReply(HANDLE hClientRequest,PVOID pPacket,ULONG uPacketLen,PXE_ADDRESS *pAddress);
DWORD PXEAPI PxeRegisterCallback(HANDLE hProvider,PXE_CALLBACK_TYPE CallbackType,PVOID pCallbackFunction,PVOID pContext);

typedef DWORD PXE_SEVERITY;

#define PXE_TRACE_VERBOSE 0x00010000
#define PXE_TRACE_INFO 0x00020000
#define PXE_TRACE_WARNING 0x00040000
#define PXE_TRACE_ERROR 0x00080000
#define PXE_TRACE_FATAL 0x00100000

DWORD WINAPIV PxeTrace(HANDLE hProvider,PXE_SEVERITY Severity,LPCWSTR pszFormat,...);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WDSPXE*/
