/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __netmon_h__
#define __netmon_h__

#ifndef __IDelaydC_FWD_DEFINED__
#define __IDelaydC_FWD_DEFINED__
typedef struct IDelaydC IDelaydC;
#endif

#ifndef __IRTC_FWD_DEFINED__
#define __IRTC_FWD_DEFINED__
typedef struct IRTC IRTC;
#endif

#ifndef __IStats_FWD_DEFINED__
#define __IStats_FWD_DEFINED__
typedef struct IStats IStats;
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include <winerror.h>
#include <winerror.h>

#pragma pack(1)

#ifdef _X86_
#pragma pack(1)
#else
#pragma pack()
#endif

  typedef BYTE *LPBYTE;
  typedef const void *HBLOB;

#define MAC_TYPE_UNKNOWN (0)
#define MAC_TYPE_ETHERNET (1)
#define MAC_TYPE_TOKENRING (2)
#define MAC_TYPE_FDDI (3)
#define MAC_TYPE_ATM (4)
#define MAC_TYPE_1394 (5)
#define MACHINE_NAME_LENGTH (16)
#define USER_NAME_LENGTH (32)
#define ADAPTER_COMMENT_LENGTH (32)
#define CONNECTION_FLAGS_WANT_CONVERSATION_STATS (0x1)

  typedef struct _TRANSMITSTATS {
    DWORD TotalFramesSent;
    DWORD TotalBytesSent;
    DWORD TotalTransmitErrors;
  } TRANSMITSTATS;

  typedef TRANSMITSTATS *LPTRANSMITSTATS;

#define TRANSMITSTATS_SIZE (sizeof(TRANSMITSTATS))

  typedef struct _STATISTICS {
    __MINGW_EXTENSION __int64 TimeElapsed;
    DWORD TotalFramesCaptured;
    DWORD TotalBytesCaptured;
    DWORD TotalFramesFiltered;
    DWORD TotalBytesFiltered;
    DWORD TotalMulticastsFiltered;
    DWORD TotalBroadcastsFiltered;
    DWORD TotalFramesSeen;
    DWORD TotalBytesSeen;
    DWORD TotalMulticastsReceived;
    DWORD TotalBroadcastsReceived;
    DWORD TotalFramesDropped;
    DWORD TotalFramesDroppedFromBuffer;
    DWORD MacFramesReceived;
    DWORD MacCRCErrors;
    __MINGW_EXTENSION __int64 MacBytesReceivedEx;
    DWORD MacFramesDropped_NoBuffers;
    DWORD MacMulticastsReceived;
    DWORD MacBroadcastsReceived;
    DWORD MacFramesDropped_HwError;
  } STATISTICS;

  typedef STATISTICS *LPSTATISTICS;

#define STATISTICS_SIZE (sizeof(STATISTICS))

#pragma pack(push,1)

#define MAX_NAME_SIZE (32)
#define IP_ADDRESS_SIZE (4)
#define MAC_ADDRESS_SIZE (6)
#define IP6_ADDRESS_SIZE (16)
#define MAX_ADDRESS_SIZE (16)

#define ADDRESS_TYPE_ETHERNET (0)
#define ADDRESS_TYPE_IP (1)
#define ADDRESS_TYPE_IPX (2)
#define ADDRESS_TYPE_TOKENRING (3)
#define ADDRESS_TYPE_FDDI (4)
#define ADDRESS_TYPE_XNS (5)
#define ADDRESS_TYPE_ANY (6)
#define ADDRESS_TYPE_ANY_GROUP (7)
#define ADDRESS_TYPE_FIND_HIGHEST (8)
#define ADDRESS_TYPE_VINES_IP (9)
#define ADDRESS_TYPE_LOCAL_ONLY (10)
#define ADDRESS_TYPE_ATM (11)
#define ADDRESS_TYPE_1394 (12)
#define ADDRESS_TYPE_IP6 (13)

#define ADDRESSTYPE_FLAGS_NORMALIZE (0x1)
#define ADDRESSTYPE_FLAGS_BIT_REVERSE (0x2)

  typedef struct _VINES_IP_ADDRESS {
    DWORD NetID;
    WORD SubnetID;
  } VINES_IP_ADDRESS;

  typedef VINES_IP_ADDRESS *LPVINES_IP_ADDRESS;

#define VINES_IP_ADDRESS_SIZE (sizeof(VINES_IP_ADDRESS))

  typedef struct _IPX_ADDR {
    BYTE Subnet[4];
    BYTE Address[6];
  } IPX_ADDR;

  typedef IPX_ADDR *LPIPX_ADDR;

#define IPX_ADDR_SIZE (sizeof(IPX_ADDR))

  typedef IPX_ADDR XNS_ADDRESS;
  typedef IPX_ADDR *LPXNS_ADDRESS;

  typedef struct _ETHERNET_SRC_ADDRESS {
    BYTE RoutingBit: 1;
    BYTE LocalBit: 1;
    BYTE Byte0: 6;
    BYTE Reserved[5];
  } ETHERNET_SRC_ADDRESS;

  typedef ETHERNET_SRC_ADDRESS *LPETHERNET_SRC_ADDRESS;

  typedef struct _ETHERNET_DST_ADDRESS {
    BYTE GroupBit: 1;
    BYTE AdminBit: 1;
    BYTE Byte0: 6;
    BYTE Reserved[5];
  } ETHERNET_DST_ADDRESS;

  typedef ETHERNET_DST_ADDRESS *LPETHERNET_DST_ADDRESS;
  typedef ETHERNET_SRC_ADDRESS FDDI_SRC_ADDRESS;
  typedef ETHERNET_DST_ADDRESS FDDI_DST_ADDRESS;
  typedef FDDI_SRC_ADDRESS *LPFDDI_SRC_ADDRESS;
  typedef FDDI_DST_ADDRESS *LPFDDI_DST_ADDRESS;

  typedef struct _TOKENRING_SRC_ADDRESS {
    BYTE Byte0: 6;
    BYTE LocalBit: 1;
    BYTE RoutingBit: 1;
    BYTE Byte1;
    BYTE Byte2: 7;
    BYTE Functional: 1;
    BYTE Reserved[3];
  } TOKENRING_SRC_ADDRESS;

  typedef TOKENRING_SRC_ADDRESS *LPTOKENRING_SRC_ADDRESS;

  typedef struct _TOKENRING_DST_ADDRESS {
    BYTE Byte0: 6;
    BYTE AdminBit: 1;
    BYTE GroupBit: 1;
    BYTE Reserved[5];
  } TOKENRING_DST_ADDRESS;

  typedef TOKENRING_DST_ADDRESS *LPTOKENRING_DST_ADDRESS;

  typedef struct _ADDRESS2 {
    DWORD Type;
    __C89_NAMELESS union {
      BYTE MACAddress[MAC_ADDRESS_SIZE];
      BYTE IPAddress[IP_ADDRESS_SIZE];
      BYTE IP6Address[IP6_ADDRESS_SIZE];
      BYTE IPXRawAddress[IPX_ADDR_SIZE];
      IPX_ADDR IPXAddress;
      BYTE VinesIPRawAddress[VINES_IP_ADDRESS_SIZE];
      VINES_IP_ADDRESS VinesIPAddress;
      ETHERNET_SRC_ADDRESS EthernetSrcAddress;
      ETHERNET_DST_ADDRESS EthernetDstAddress;
      TOKENRING_SRC_ADDRESS TokenringSrcAddress;
      TOKENRING_DST_ADDRESS TokenringDstAddress;
      FDDI_SRC_ADDRESS FddiSrcAddress;
      FDDI_DST_ADDRESS FddiDstAddress;
    };
    WORD Flags;
  } ADDRESS2;

  typedef ADDRESS2 *LPADDRESS2;

#define ADDRESS2_SIZE sizeof(ADDRESS2)

#pragma pack(pop)

#define ADDRESS_FLAGS_MATCH_DST (0x1)
#define ADDRESS_FLAGS_MATCH_SRC (0x2)
#define ADDRESS_FLAGS_EXCLUDE (0x4)
#define ADDRESS_FLAGS_DST_GROUP_ADDR (0x8)
#define ADDRESS_FLAGS_MATCH_BOTH (0x3)

  typedef struct _ADDRESSPAIR2 {
    WORD AddressFlags;
    WORD NalReserved;
    ADDRESS2 DstAddress;
    ADDRESS2 SrcAddress;
  } ADDRESSPAIR2;

  typedef ADDRESSPAIR2 *LPADDRESSPAIR2;

#define ADDRESSPAIR2_SIZE sizeof(ADDRESSPAIR2)

#define MAX_ADDRESS_PAIRS (8)

  typedef struct _ADDRESSTABLE2 {
    DWORD nAddressPairs;
    DWORD nNonMacAddressPairs;
    ADDRESSPAIR2 AddressPair[MAX_ADDRESS_PAIRS];
  } ADDRESSTABLE2;

  typedef ADDRESSTABLE2 *LPADDRESSTABLE2;

#define ADDRESSTABLE2_SIZE sizeof(ADDRESSTABLE2)

#define NETWORKINFO_FLAGS_PMODE_NOT_SUPPORTED (0x1)
#define NETWORKINFO_FLAGS_REMOTE_NAL (0x4)
#define NETWORKINFO_FLAGS_REMOTE_NAL_CONNECTED (0x8)
#define NETWORKINFO_FLAGS_REMOTE_CARD (0x10)
#define NETWORKINFO_FLAGS_RAS (0x20)
#define NETWORKINFO_RESERVED_FIELD_SIZE (FIELD_OFFSET(ADDRESS2,IPXAddress) + sizeof(IPX_ADDR))

  typedef struct _NETWORKINFO {
    BYTE PermanentAddr[6];
    BYTE CurrentAddr[6];
    BYTE Reserved[NETWORKINFO_RESERVED_FIELD_SIZE];
    DWORD LinkSpeed;
    DWORD MacType;
    DWORD MaxFrameSize;
    DWORD Flags;
    DWORD TimestampScaleFactor;
    BYTE NodeName[32];
    WINBOOL PModeSupported;
    BYTE Comment[ADAPTER_COMMENT_LENGTH];
  } NETWORKINFO;

  typedef NETWORKINFO *LPNETWORKINFO;

#define NETWORKINFO_SIZE sizeof(NETWORKINFO)
#define MINIMUM_FRAME_SIZE (32)
#define MAX_PATTERN_LENGTH (16)

#define PATTERN_MATCH_FLAGS_NOT (0x1)
#define PATTERN_MATCH_FLAGS_RESERVED_1 (0x2)
#define PATTERN_MATCH_FLAGS_PORT_SPECIFIED (0x8)

#define OFFSET_BASIS_RELATIVE_TO_FRAME (0)
#define OFFSET_BASIS_RELATIVE_TO_EFFECTIVE_PROTOCOL (1)
#define OFFSET_BASIS_RELATIVE_TO_IPX (2)
#define OFFSET_BASIS_RELATIVE_TO_IP (3)
#define OFFSET_BASIS_RELATIVE_TO_IP6 (4)

  typedef union __MIDL___MIDL_itf_netmon_0000_0001 {
    BYTE NextHeader;
    BYTE IPPort;
    WORD ByteSwappedIPXPort;
  } GENERIC_PORT;

  typedef struct _PATTERNMATCH {
    DWORD Flags;
    BYTE OffsetBasis;
    GENERIC_PORT Port;
    WORD Offset;
    WORD Length;
    BYTE PatternToMatch[16];
  } PATTERNMATCH;

  typedef PATTERNMATCH *LPPATTERNMATCH;

#define PATTERNMATCH_SIZE (sizeof(PATTERNMATCH))

#define MAX_PATTERNS (4)

  typedef struct _ANDEXP {
    DWORD nPatternMatches;
    PATTERNMATCH PatternMatch[4];
  } ANDEXP;

  typedef ANDEXP *LPANDEXP;

#define ANDEXP_SIZE (sizeof(ANDEXP))

  typedef struct _EXPRESSION {
    DWORD nAndExps;
    ANDEXP AndExp[4];
  } EXPRESSION;

  typedef EXPRESSION *LPEXPRESSION;

#define EXPRESSION_SIZE (sizeof(EXPRESSION))

#define TRIGGER_TYPE_PATTERN_MATCH (1)
#define TRIGGER_TYPE_BUFFER_CONTENT (2)
#define TRIGGER_TYPE_PATTERN_MATCH_THEN_BUFFER_CONTENT (3)
#define TRIGGER_TYPE_BUFFER_CONTENT_THEN_PATTERN_MATCH (4)

#define TRIGGER_FLAGS_FRAME_RELATIVE (0)
#define TRIGGER_FLAGS_DATA_RELATIVE (0x1)

#define TRIGGER_ACTION_NOTIFY (0)
#define TRIGGER_ACTION_STOP (0x2)
#define TRIGGER_ACTION_PAUSE (0x3)

#define TRIGGER_BUFFER_FULL_25_PERCENT (0)
#define TRIGGER_BUFFER_FULL_50_PERCENT (1)
#define TRIGGER_BUFFER_FULL_75_PERCENT (2)
#define TRIGGER_BUFFER_FULL_100_PERCENT (3)

  typedef struct _TRIGGER {
    WINBOOL TriggerActive;
    BYTE TriggerType;
    BYTE TriggerAction;
    DWORD TriggerFlags;
    PATTERNMATCH TriggerPatternMatch;
    DWORD TriggerBufferSize;
    DWORD TriggerReserved;
    char TriggerCommandLine[260];
  } TRIGGER;

  typedef TRIGGER *LPTRIGGER;

#define TRIGGER_SIZE (sizeof(TRIGGER))

#define CAPTUREFILTER_FLAGS_INCLUDE_ALL_SAPS (0x1)
#define CAPTUREFILTER_FLAGS_INCLUDE_ALL_ETYPES (0x2)
#define CAPTUREFILTER_FLAGS_TRIGGER (0x4)
#define CAPTUREFILTER_FLAGS_LOCAL_ONLY (0x8)
#define CAPTUREFILTER_FLAGS_DISCARD_COMMENTS (0x10)
#define CAPTUREFILTER_FLAGS_KEEP_RAW (0x20)
#define CAPTUREFILTER_FLAGS_INCLUDE_ALL (0x3)

#define BUFFER_FULL_25_PERCENT (0)
#define BUFFER_FULL_50_PERCENT (1)
#define BUFFER_FULL_75_PERCENT (2)
#define BUFFER_FULL_100_PERCENT (3)

  typedef struct _CAPTUREFILTER {
    DWORD FilterFlags;
    LPBYTE lpSapTable;
    LPWORD lpEtypeTable;
    WORD nSaps;
    WORD nEtypes;
    LPADDRESSTABLE2 AddressTable;
    EXPRESSION FilterExpression;
    TRIGGER Trigger;
    DWORD nFrameBytesToCopy;
    DWORD Reserved;

  } CAPTUREFILTER;

  typedef CAPTUREFILTER *LPCAPTUREFILTER;

#define CAPTUREFILTER_SIZE sizeof(CAPTUREFILTER)

  typedef struct _FRAME {
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    BYTE MacFrame[1];
  } FRAME;

  typedef FRAME *LPFRAME;

  typedef FRAME UNALIGNED *ULPFRAME;
#define FRAME_SIZE (sizeof(FRAME))

#define LOW_PROTOCOL_IPX (OFFSET_BASIS_RELATIVE_TO_IPX)

#define LOW_PROTOCOL_IP (OFFSET_BASIS_RELATIVE_TO_IP)
#define LOW_PROTOCOL_IP6 (OFFSET_BASIS_RELATIVE_TO_IP6)
#define LOW_PROTOCOL_UNKNOWN ((BYTE)-1)

  typedef struct _FRAME_DESCRIPTOR {
    LPBYTE FramePointer;
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    WORD Etype;
    BYTE Sap;
    BYTE LowProtocol;
    WORD LowProtocolOffset;
    union {
      WORD Reserved;
      BYTE IPPort;
      WORD ByteSwappedIPXPort;
    } HighPort;
    WORD HighProtocolOffset;
  } FRAME_DESCRIPTOR;

  typedef FRAME_DESCRIPTOR *LPFRAME_DESCRIPTOR;

#define FRAME_DESCRIPTOR_SIZE (sizeof(FRAME_DESCRIPTOR))

  typedef struct _FRAMETABLE {
    DWORD FrameTableLength;
    DWORD StartIndex;
    DWORD EndIndex;
    DWORD FrameCount;
    FRAME_DESCRIPTOR Frames[1];
  } FRAMETABLE;

  typedef FRAMETABLE *LPFRAMETABLE;

#define STATIONSTATS_FLAGS_INITIALIZED (0x1)
#define STATIONSTATS_FLAGS_EVENTPOSTED (0x2)

#define STATIONSTATS_POOL_SIZE (100)

  typedef struct _STATIONSTATS {
    DWORD NextStationStats;
    DWORD SessionPartnerList;
    DWORD Flags;
    BYTE StationAddress[6];
    WORD Pad;
    DWORD TotalPacketsReceived;
    DWORD TotalDirectedPacketsSent;
    DWORD TotalBroadcastPacketsSent;
    DWORD TotalMulticastPacketsSent;
    DWORD TotalBytesReceived;
    DWORD TotalBytesSent;
  } STATIONSTATS;

  typedef STATIONSTATS *LPSTATIONSTATS;

#define STATIONSTATS_SIZE (sizeof(STATIONSTATS))

#define SESSION_FLAGS_INITIALIZED (0x1)
#define SESSION_FLAGS_EVENTPOSTED (0x2)

#define SESSION_POOL_SIZE (100)

  typedef struct _SESSIONSTATS {
    DWORD NextSession;
    DWORD StationOwner;
    DWORD StationPartner;
    DWORD Flags;
    DWORD TotalPacketsSent;
  } SESSIONSTATS;

  typedef SESSIONSTATS *LPSESSIONSTATS;

#define SESSIONSTATS_SIZE (sizeof(SESSIONSTATS))

#pragma pack(push,1)
  typedef struct _STATIONQUERY {
    DWORD Flags;
    BYTE BCDVerMinor;
    BYTE BCDVerMajor;
    DWORD LicenseNumber;
    BYTE MachineName[16];
    BYTE UserName[32];
    BYTE Reserved[32];
    BYTE AdapterAddress[6];
    WCHAR WMachineName[16];
    WCHAR WUserName[32];
  } STATIONQUERY;

  typedef STATIONQUERY *LPSTATIONQUERY;

#define STATIONQUERY_SIZE (sizeof(STATIONQUERY))

#pragma pack(pop)

  typedef struct _QUERYTABLE {
    DWORD nStationQueries;
    STATIONQUERY StationQuery[1];
  } QUERYTABLE;

  typedef QUERYTABLE *LPQUERYTABLE;

#define QUERYTABLE_SIZE (sizeof(QUERYTABLE))

  typedef struct _LINK *LPLINK;

  typedef struct _LINK {
    LPLINK PrevLink;
    LPLINK NextLink;
  } LINK;

#pragma pack(push,1)
#define MAX_SECURITY_BREACH_REASON_SIZE (100)

#define MAX_SIGNATURE_LENGTH (128)
#define MAX_USER_NAME_LENGTH (256)

  typedef struct _SECURITY_PERMISSION_RESPONSE {
    UINT Version;
    DWORD RandomNumber;
    BYTE MachineName[16];
    BYTE Address[6];
    BYTE UserName[256];
    BYTE Reason[100];
    DWORD SignatureLength;
    BYTE Signature[128];
  } SECURITY_PERMISSION_RESPONSE;

  typedef SECURITY_PERMISSION_RESPONSE *LPSECURITY_PERMISSION_RESPONSE;
  typedef SECURITY_PERMISSION_RESPONSE UNALIGNED *ULPSECURITY_PERMISSION_RESPONSE;

#define SECURITY_PERMISSION_RESPONSE_SIZE (sizeof(SECURITY_PERMISSION_RESPONSE))

#pragma pack(pop)

#define UPDATE_EVENT_TERMINATE_THREAD (0)
#define UPDATE_EVENT_NETWORK_STATUS (0x1)
#define UPDATE_EVENT_RTC_INTERVAL_ELAPSED (0x2)
#define UPDATE_EVENT_RTC_FRAME_TABLE_FULL (0x3)
#define UPDATE_EVENT_RTC_BUFFER_FULL (0x4)
#define UPDATE_EVENT_TRIGGER_BUFFER_CONTENT (0x5)
#define UPDATE_EVENT_TRIGGER_PATTERN_MATCH (0x6)
#define UPDATE_EVENT_TRIGGER_BUFFER_PATTERN (0x7)
#define UPDATE_EVENT_TRIGGER_PATTERN_BUFFER (0x8)
#define UPDATE_EVENT_TRANSMIT_STATUS (0x9)
#define UPDATE_EVENT_SECURITY_BREACH (0xa)
#define UPDATE_EVENT_REMOTE_FAILURE (0xb)

#define UPDATE_ACTION_TERMINATE_THREAD (0)
#define UPDATE_ACTION_NOTIFY (0x1)
#define UPDATE_ACTION_STOP_CAPTURE (0x2)
#define UPDATE_ACTION_PAUSE_CAPTURE (0x3)
#define UPDATE_ACTION_RTC_BUFFER_SWITCH (0x4)

  __C89_NAMELESS typedef struct _UPDATE_EVENT {
    USHORT Event;
    DWORD Action;
    DWORD Status;
    DWORD Value;
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD_PTR lpUserContext;
    DWORD_PTR lpReserved;
    UINT FramesDropped;
    __C89_NAMELESS union {
      DWORD Reserved;
      LPFRAMETABLE lpFrameTable;
      DWORD_PTR lpPacketQueue;
      SECURITY_PERMISSION_RESPONSE SecurityResponse;
    };
    LPSTATISTICS lpFinalStats;
  } UPDATE_EVENT;

  typedef UPDATE_EVENT *PUPDATE_EVENT;
  typedef DWORD (WINAPI *LPNETWORKCALLBACKPROC)(UPDATE_EVENT);

  typedef struct _NETWORKSTATUS {
    DWORD State;
    DWORD Flags;
  } NETWORKSTATUS;

  typedef NETWORKSTATUS *LPNETWORKSTATUS;

#define NETWORKSTATUS_SIZE (sizeof(NETWORKSTATUS))

#define NETWORKSTATUS_STATE_VOID (0)
#define NETWORKSTATUS_STATE_INIT (1)
#define NETWORKSTATUS_STATE_CAPTURING (2)
#define NETWORKSTATUS_STATE_PAUSED (3)

#define NETWORKSTATUS_FLAGS_TRIGGER_PENDING (0x1)

#define MAKE_WORD(l,h) (((WORD) (l)) | (((WORD) (h)) << 8))
#define MAKE_LONG(l,h) (((DWORD) (l)) | (((DWORD) (h)) << 16))
#define MAKE_SIG(a,b,c,d) MAKE_LONG(MAKE_WORD(a,b),MAKE_WORD(c,d))

#define MAX_SESSIONS (100)
#define MAX_STATIONS (100)

  typedef struct _STATISTICSPARAM {
    DWORD StatisticsSize;
    STATISTICS Statistics;
    DWORD StatisticsTableEntries;
    STATIONSTATS StatisticsTable[100];
    DWORD SessionTableEntries;
    SESSIONSTATS SessionTable[100];
  } STATISTICSPARAM;

  typedef STATISTICSPARAM *LPSTATISTICSPARAM;

#define STATISTICSPARAM_SIZE (sizeof(STATISTICSPARAM))

#pragma pack(push,1)
#define CAPTUREFILE_VERSION_MAJOR (2)

#define CAPTUREFILE_VERSION_MINOR (0)

#define MakeVersion(Major,Minor) ((DWORD) MAKEWORD(Minor,Major))
#define GetCurrentVersion() MakeVersion(CAPTUREFILE_VERSION_MAJOR,CAPTUREFILE_VERSION_MINOR)
#define NETMON_1_0_CAPTUREFILE_SIGNATURE MAKE_IDENTIFIER('R','T','S','S')
#define NETMON_2_0_CAPTUREFILE_SIGNATURE MAKE_IDENTIFIER('G','M','B','U')

  typedef struct _CAPTUREFILE_HEADER_VALUES {
    DWORD Signature;
    BYTE BCDVerMinor;
    BYTE BCDVerMajor;
    WORD MacType;
    SYSTEMTIME TimeStamp;
    DWORD FrameTableOffset;
    DWORD FrameTableLength;
    DWORD UserDataOffset;
    DWORD UserDataLength;
    DWORD CommentDataOffset;
    DWORD CommentDataLength;
    DWORD StatisticsOffset;
    DWORD StatisticsLength;
    DWORD NetworkInfoOffset;
    DWORD NetworkInfoLength;
    DWORD ConversationStatsOffset;
    DWORD ConversationStatsLength;
  } CAPTUREFILE_HEADER_VALUES;

  typedef CAPTUREFILE_HEADER_VALUES *LPCAPTUREFILE_HEADER_VALUES;

#define CAPTUREFILE_HEADER_VALUES_SIZE (sizeof(CAPTUREFILE_HEADER_VALUES))

#pragma pack(pop)

#pragma pack(push,1)
  typedef struct _CAPTUREFILE_HEADER {
    __C89_NAMELESS union {
      CAPTUREFILE_HEADER_VALUES ActualHeader;
      BYTE Buffer[72];
    };
    BYTE Reserved[56];
  } CAPTUREFILE_HEADER;

  typedef CAPTUREFILE_HEADER *LPCAPTUREFILE_HEADER;

#define CAPTUREFILE_HEADER_SIZE (sizeof(CAPTUREFILE_HEADER))

#pragma pack(pop)

#pragma pack(push,1)
  typedef struct _EFRAMEHDR {
    BYTE SrcAddress[6];
    BYTE DstAddress[6];
    WORD Length;
    BYTE DSAP;
    BYTE SSAP;
    BYTE Control;
    BYTE ProtocolID[3];
    WORD EtherType;
  } EFRAMEHDR;

  typedef struct _TRFRAMEHDR {
    BYTE AC;
    BYTE FC;
    BYTE SrcAddress[6];
    BYTE DstAddress[6];
    BYTE DSAP;
    BYTE SSAP;
    BYTE Control;
    BYTE ProtocolID[3];
    WORD EtherType;
  } TRFRAMEHDR;

#define DEFAULT_TR_AC (0)

#define DEFAULT_TR_FC (0x40)
#define DEFAULT_SAP (0xaa)

#define DEFAULT_CONTROL (0x3)

#define DEFAULT_ETHERTYPE (0x8419)

  typedef struct _FDDIFRAMEHDR {
    BYTE FC;
    BYTE SrcAddress[6];
    BYTE DstAddress[6];
    BYTE DSAP;
    BYTE SSAP;
    BYTE Control;
    BYTE ProtocolID[3];
    WORD EtherType;
  } FDDIFRAMEHDR;

#define DEFAULT_FDDI_FC (0x10)

  typedef struct _FDDISTATFRAME {
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    FDDIFRAMEHDR FrameHeader;
    BYTE FrameID[4];
    DWORD Flags;
    DWORD FrameType;
    WORD StatsDataLen;
    DWORD StatsVersion;
    STATISTICS Statistics;
  } FDDISTATFRAME;

  typedef FDDISTATFRAME *LPFDDISTATFRAME;

  typedef FDDISTATFRAME UNALIGNED *ULPFDDISTATFRAME;
#define FDDISTATFRAME_SIZE (sizeof(FDDISTATFRAME))

  typedef struct _ATMFRAMEHDR {
    BYTE SrcAddress[6];
    BYTE DstAddress[6];
    WORD Vpi;
    WORD Vci;
  } ATMFRAMEHDR;

  typedef struct _ATMSTATFRAME {
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    ATMFRAMEHDR FrameHeader;
    BYTE FrameID[4];
    DWORD Flags;
    DWORD FrameType;
    WORD StatsDataLen;
    DWORD StatsVersion;
    STATISTICS Statistics;
  } ATMSTATFRAME;

  typedef ATMSTATFRAME *LPATMSTATFRAME;
  typedef ATMSTATFRAME UNALIGNED *ULPATMSTATFRAME;

#define ATMSTATFRAME_SIZE (sizeof(ATMSTATFRAME))

  typedef struct _TRSTATFRAME {
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    TRFRAMEHDR FrameHeader;
    BYTE FrameID[4];
    DWORD Flags;
    DWORD FrameType;
    WORD StatsDataLen;
    DWORD StatsVersion;
    STATISTICS Statistics;
  } TRSTATFRAME;

  typedef TRSTATFRAME *LPTRSTATFRAME;
  typedef TRSTATFRAME UNALIGNED *ULPTRSTATFRAME;

#define TRSTATFRAME_SIZE (sizeof(TRSTATFRAME))

  typedef struct _ESTATFRAME {
    __MINGW_EXTENSION __int64 TimeStamp;
    DWORD FrameLength;
    DWORD nBytesAvail;
    EFRAMEHDR FrameHeader;
    BYTE FrameID[4];
    DWORD Flags;
    DWORD FrameType;
    WORD StatsDataLen;
    DWORD StatsVersion;
    STATISTICS Statistics;
  } ESTATFRAME;

  typedef ESTATFRAME *LPESTATFRAME;
  typedef ESTATFRAME UNALIGNED *ULPESTATFRAME;

#define ESTATFRAME_SIZE (sizeof(ESTATFRAME))

#define STATISTICS_VERSION_1_0 (0)
#define STATISTICS_VERSION_2_0 (0x20)
#define MAX_STATSFRAME_SIZE (sizeof(TRSTATFRAME))
#define STATS_FRAME_TYPE (103)

#pragma pack(pop)
#pragma pack(push,1)

  typedef struct _ADDRESS {
    DWORD Type;
    __C89_NAMELESS union {
      BYTE MACAddress[MAC_ADDRESS_SIZE];
      BYTE IPAddress[IP_ADDRESS_SIZE];
      BYTE IPXRawAddress[IPX_ADDR_SIZE];
      IPX_ADDR IPXAddress;
      BYTE VinesIPRawAddress[VINES_IP_ADDRESS_SIZE];
      VINES_IP_ADDRESS VinesIPAddress;
      ETHERNET_SRC_ADDRESS EthernetSrcAddress;
      ETHERNET_DST_ADDRESS EthernetDstAddress;
      TOKENRING_SRC_ADDRESS TokenringSrcAddress;
      TOKENRING_DST_ADDRESS TokenringDstAddress;
      FDDI_SRC_ADDRESS FddiSrcAddress;
      FDDI_DST_ADDRESS FddiDstAddress;
    };
    WORD Flags;
  } ADDRESS;

  typedef ADDRESS *LPADDRESS;
#define ADDRESS_SIZE sizeof(ADDRESS)

#pragma pack(pop)

  typedef struct _ADDRESSPAIR {
    WORD AddressFlags;
    WORD NalReserved;
    ADDRESS DstAddress;
    ADDRESS SrcAddress;

  } ADDRESSPAIR;

  typedef ADDRESSPAIR *LPADDRESSPAIR;

#define ADDRESSPAIR_SIZE sizeof(ADDRESSPAIR)

  typedef struct _ADDRESSTABLE {
    DWORD nAddressPairs;
    DWORD nNonMacAddressPairs;
    ADDRESSPAIR AddressPair[MAX_ADDRESS_PAIRS];

  } ADDRESSTABLE;

  typedef ADDRESSTABLE *LPADDRESSTABLE;

#define ADDRESSTABLE_SIZE sizeof(ADDRESSTABLE)

  typedef struct _ADDRESSINFO {
    ADDRESS Address;
    WCHAR Name[MAX_NAME_SIZE];
    DWORD Flags;
    LPVOID lpAddressInstData;
  } ADDRESSINFO;

  typedef struct _ADDRESSINFO *LPADDRESSINFO;

#define ADDRESSINFO_SIZE sizeof(ADDRESSINFO)

  typedef struct _ADDRESSINFOTABLE {
    DWORD nAddressInfos;
    LPADDRESSINFO lpAddressInfo[0];
  } ADDRESSINFOTABLE;

  typedef ADDRESSINFOTABLE *LPADDRESSINFOTABLE;

#define ADDRESSINFOTABLE_SIZE sizeof(ADDRESSINFOTABLE)

  DWORD __cdecl SetNPPAddressFilterInBlob(HBLOB hBlob,LPADDRESSTABLE pAddressTable);
  DWORD __cdecl GetNPPAddressFilterFromBlob(HBLOB hBlob,LPADDRESSTABLE pAddressTable,HBLOB hErrorBlob);

#pragma pack(push,8)

  typedef enum __MIDL___MIDL_itf_netmon_0000_0005 {
    NMCOLUMNTYPE_UINT8 = 0,
    NMCOLUMNTYPE_SINT8,NMCOLUMNTYPE_UINT16,NMCOLUMNTYPE_SINT16,NMCOLUMNTYPE_UINT32,NMCOLUMNTYPE_SINT32,
    NMCOLUMNTYPE_FLOAT64,NMCOLUMNTYPE_FRAME,NMCOLUMNTYPE_YESNO,NMCOLUMNTYPE_ONOFF,NMCOLUMNTYPE_TRUEFALSE,
    NMCOLUMNTYPE_MACADDR,NMCOLUMNTYPE_IPXADDR,NMCOLUMNTYPE_IPADDR,NMCOLUMNTYPE_VARTIME,NMCOLUMNTYPE_STRING
  } NMCOLUMNTYPE;

  typedef struct _NMCOLUMNVARIANT {
    NMCOLUMNTYPE Type;
    union {
      BYTE Uint8Val;
      char Sint8Val;
      WORD Uint16Val;
      short Sint16Val;
      DWORD Uint32Val;
      __LONG32 Sint32Val;
      DOUBLE Float64Val;
      DWORD FrameVal;
      WINBOOL YesNoVal;
      WINBOOL OnOffVal;
      WINBOOL TrueFalseVal;
      BYTE MACAddrVal[6];
      IPX_ADDR IPXAddrVal;
      DWORD IPAddrVal;
      DOUBLE VarTimeVal;
      LPCSTR pStringVal;
    } Value;
  } NMCOLUMNVARIANT;

  typedef struct _NMCOLUMNINFO {
    LPSTR szColumnName;
    NMCOLUMNVARIANT VariantData;
  } NMCOLUMNINFO;

  typedef NMCOLUMNINFO *PNMCOLUMNINFO;
  typedef LPSTR JTYPE;

  typedef struct _NMEVENTDATA {
    LPSTR pszReserved;
    BYTE Version;
    DWORD EventIdent;
    DWORD Flags;
    DWORD Severity;
    BYTE NumColumns;
    LPSTR szSourceName;
    LPSTR szEventName;
    LPSTR szDescription;
    LPSTR szMachine;
    JTYPE Justification;
    PVOID pvReserved;
    SYSTEMTIME SysTime;
    NMCOLUMNINFO Column[0];
  } NMEVENTDATA;

  typedef NMEVENTDATA *PNMEVENTDATA;

#pragma pack(pop)

#define NMEVENTFLAG_EXPERT (0x1)
#define NMEVENTFLAG_DO_NOT_DISPLAY_SEVERITY (0x80000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_SOURCE (0x40000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_EVENT_NAME (0x20000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_DESCRIPTION (0x10000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_MACHINE (0x8000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_TIME (0x4000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_DATE (0x2000000)
#define NMEVENTFLAG_DO_NOT_DISPLAY_FIXED_COLUMNS (0xfe000000)

  enum _NMEVENT_SEVERITIES {
    NMEVENT_SEVERITY_INFORMATIONAL = 0,NMEVENT_SEVERITY_WARNING,
    NMEVENT_SEVERITY_STRONG_WARNING,NMEVENT_SEVERITY_ERROR,
    NMEVENT_SEVERITY_SEVERE_ERROR,NMEVENT_SEVERITY_CRITICAL_ERROR
  };

  typedef struct __MIDL___MIDL_itf_netmon_0000_0007 {
    DWORD dwNumBlobs;
    HBLOB hBlobs[1];
  } BLOB_TABLE;

  typedef BLOB_TABLE *PBLOB_TABLE;

  typedef struct __MIDL___MIDL_itf_netmon_0000_0008 {
    DWORD size;
    BYTE *pBytes;
  } MBLOB;

  typedef struct __MIDL___MIDL_itf_netmon_0000_0009 {
    DWORD dwNumBlobs;
    MBLOB mBlobs[1];
  } MBLOB_TABLE;

  typedef MBLOB_TABLE *PMBLOB_TABLE;

  DWORD __cdecl GetNPPBlobTable(HBLOB hFilterBlob,PBLOB_TABLE *ppBlobTable);
  DWORD __cdecl GetNPPBlobFromUI(HWND hwnd,HBLOB hFilterBlob,HBLOB *phBlob);
  DWORD __cdecl GetNPPBlobFromUIExU(HWND hwnd,HBLOB hFilterBlob,HBLOB *phBlob,char *szHelpFileName);
  DWORD __cdecl SelectNPPBlobFromTable(HWND hwnd,PBLOB_TABLE pBlobTable,HBLOB *hBlob);
  DWORD __cdecl SelectNPPBlobFromTableExU(HWND hwnd,PBLOB_TABLE pBlobTable,HBLOB *hBlob,char *szHelpFileName);

  static __inline DWORD BLOB_TABLE_SIZE(DWORD dwNumBlobs) { return (DWORD) (sizeof(BLOB_TABLE)+dwNumBlobs*sizeof(HBLOB)); }
  static __inline PBLOB_TABLE AllocBlobTable(DWORD dwNumBlobs) {
    DWORD size = BLOB_TABLE_SIZE(dwNumBlobs);
    return (PBLOB_TABLE)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,size);
  }
  static __inline DWORD MBLOB_TABLE_SIZE(DWORD dwNumBlobs) { return (DWORD) (sizeof(MBLOB_TABLE)+dwNumBlobs*sizeof(MBLOB)); }
  static __inline PMBLOB_TABLE AllocMBlobTable(DWORD dwNumBlobs) {
    DWORD size = MBLOB_TABLE_SIZE(dwNumBlobs);
    return (PMBLOB_TABLE)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,size);
  }
  DWORD __cdecl GetNPPBlobs(PBLOB_TABLE *ppBlobTable);

  typedef DWORD (_cdecl *BLOBSPROC) (PBLOB_TABLE *ppBlobTable);

  DWORD __cdecl GetConfigBlob(HBLOB *phBlob);

  typedef DWORD (_cdecl *GETCFGBLOB)(HBLOB,HBLOB*);
  typedef DWORD (_cdecl *CFGPROC)(HWND hwnd,HBLOB SpecialBlob,PBLOB_TABLE *ppBlobTable);

  WINBOOL __cdecl FilterNPPBlob(HBLOB hBlob,HBLOB FilterBlob);
  WINBOOL __cdecl RaiseNMEvent(HINSTANCE hInstance,WORD EventType,DWORD EventID,WORD nStrings,const char **aInsertStrs,LPVOID lpvData,DWORD dwDataSize);

#ifndef __cplusplus
#ifndef try
#define try __try
#endif

#ifndef except
#define except __except
#endif
#endif

#define WINDOWS_VERSION_UNKNOWN (0)
#define WINDOWS_VERSION_WIN32S (1)
#define WINDOWS_VERSION_WIN32C (2)
#define WINDOWS_VERSION_WIN32 (3)

#define FRAME_MASK_ETHERNET ((BYTE)~0x1)
#define FRAME_MASK_TOKENRING ((BYTE)~0x80)
#define FRAME_MASK_FDDI ((BYTE)~0x1)

  typedef LPVOID HOBJECTHEAP;
  typedef VOID (WINAPI *OBJECTPROC)(HOBJECTHEAP,LPVOID);
  typedef struct _TIMER *HTIMER;
  typedef VOID (WINAPI *BHTIMERPROC)(LPVOID);

  HTIMER WINAPI BhSetTimer(BHTIMERPROC TimerProc,LPVOID InstData,DWORD TimeOut);
  VOID WINAPI BhKillTimer(HTIMER hTimer);
  DWORD WINAPI BhGetLastError(VOID);
  DWORD WINAPI BhSetLastError(DWORD Error);
  HOBJECTHEAP WINAPI CreateObjectHeap(DWORD ObjectSize,OBJECTPROC ObjectProc);
  HOBJECTHEAP WINAPI DestroyObjectHeap(HOBJECTHEAP hObjectHeap);
  LPVOID WINAPI AllocObject(HOBJECTHEAP hObjectHeap);
  LPVOID WINAPI FreeObject(HOBJECTHEAP hObjectHeap,LPVOID ObjectMemory);
  DWORD WINAPI GrowObjectHeap(HOBJECTHEAP hObjectHeap,DWORD nObjects);
  DWORD WINAPI GetObjectHeapSize(HOBJECTHEAP hObjectHeap);
  VOID WINAPI PurgeObjectHeap(HOBJECTHEAP hObjectHeap);
  LPVOID WINAPI AllocMemory(SIZE_T size);
  LPVOID WINAPI ReallocMemory(LPVOID ptr,SIZE_T NewSize);
  VOID WINAPI FreeMemory(LPVOID ptr);
  VOID WINAPI TestMemory(LPVOID ptr);
  SIZE_T WINAPI MemorySize(LPVOID ptr);
  HANDLE WINAPI MemoryHandle(LPBYTE ptr);
  LPEXPRESSION WINAPI InitializeExpression(LPEXPRESSION Expression);
  LPPATTERNMATCH WINAPI InitializePattern(LPPATTERNMATCH Pattern,LPVOID ptr,DWORD offset,DWORD length);
  LPEXPRESSION WINAPI AndExpression(LPEXPRESSION Expression,LPPATTERNMATCH Pattern);
  LPEXPRESSION WINAPI OrExpression(LPEXPRESSION Expression,LPPATTERNMATCH Pattern);
  LPPATTERNMATCH WINAPI NegatePattern(LPPATTERNMATCH Pattern);
  LPADDRESSTABLE2 WINAPI AdjustOperatorPrecedence(LPADDRESSTABLE2 AddressTable);
  LPADDRESS2 WINAPI NormalizeAddress(LPADDRESS2 Address);
  LPADDRESSTABLE2 WINAPI NormalizeAddressTable(LPADDRESSTABLE2 AddressTable);
  DWORD WINAPI BhGetWindowsVersion(VOID);
  WINBOOL WINAPI IsDaytona(VOID);
  VOID __cdecl dprintf(LPSTR format,...);

  typedef VOID UNALIGNED *ULPVOID;
  typedef BYTE UNALIGNED *ULPBYTE;
  typedef WORD UNALIGNED *ULPWORD;
  typedef DWORD UNALIGNED *ULPDWORD;
  typedef CHAR UNALIGNED *ULPSTR;
  typedef SYSTEMTIME UNALIGNED *ULPSYSTEMTIME;
  typedef struct _PARSER *HPARSER;
  typedef struct _CAPFRAMEDESC *HFRAME;
  typedef struct _CAPTURE *HCAPTURE;
  typedef struct _FILTER *HFILTER;
  typedef struct _ADDRESSDB *HADDRESSDB;
  typedef struct _PROTOCOL *HPROTOCOL;
  typedef DWORD_PTR HPROPERTY;
  typedef HPROTOCOL *LPHPROTOCOL;

#define GetTableSize(TableBaseSize,nElements,ElementSize) ((TableBaseSize) + ((nElements) *(ElementSize)))

  typedef DWORD OBJECTTYPE;

#ifndef MAKE_IDENTIFIER
#define MAKE_IDENTIFIER(a,b,c,d) ((DWORD) MAKELONG(MAKEWORD(a,b),MAKEWORD(c,d)))
#endif
#define HANDLE_TYPE_INVALID MAKE_IDENTIFIER(-1,-1,-1,-1)
#define HANDLE_TYPE_CAPTURE MAKE_IDENTIFIER('C','A','P','$')
#define HANDLE_TYPE_PARSER MAKE_IDENTIFIER('P','S','R','$')
#define HANDLE_TYPE_ADDRESSDB MAKE_IDENTIFIER('A','D','R','$')
#define HANDLE_TYPE_PROTOCOL MAKE_IDENTIFIER('P','R','T','$')
#define HANDLE_TYPE_BUFFER MAKE_IDENTIFIER('B','U','F','$')

#define INLINE __inline
#define BHAPI WINAPI
#define MAX_NAME_LENGTH (16)

#define MAX_ADDR_LENGTH (6)

#define ETYPE_LOOP (0x9000)
#define ETYPE_3COM_NETMAP1 (0x9001)
#define ETYPE_3COM_NETMAP2 (0x9002)
#define ETYPE_IBM_RT (0x80d5)
#define ETYPE_NETWARE (0x8137)
#define ETYPE_XNS1 (0x600)
#define ETYPE_XNS2 (0x807)
#define ETYPE_3COM_NBP0 (0x3c00)
#define ETYPE_3COM_NBP1 (0x3c01)
#define ETYPE_3COM_NBP2 (0x3c02)
#define ETYPE_3COM_NBP3 (0x3c03)
#define ETYPE_3COM_NBP4 (0x3c04)
#define ETYPE_3COM_NBP5 (0x3c05)
#define ETYPE_3COM_NBP6 (0x3c06)
#define ETYPE_3COM_NBP7 (0x3c07)
#define ETYPE_3COM_NBP8 (0x3c08)
#define ETYPE_3COM_NBP9 (0x3c09)
#define ETYPE_3COM_NBP10 (0x3c0a)
#define ETYPE_IP (0x800)
#define ETYPE_ARP1 (0x806)
#define ETYPE_ARP2 (0x807)
#define ETYPE_RARP (0x8035)
#define ETYPE_TRLR0 (0x1000)
#define ETYPE_TRLR1 (0x1001)
#define ETYPE_TRLR2 (0x1002)
#define ETYPE_TRLR3 (0x1003)
#define ETYPE_TRLR4 (0x1004)
#define ETYPE_TRLR5 (0x1005)
#define ETYPE_PUP (0x200)
#define ETYPE_PUP_ARP (0x201)
#define ETYPE_APPLETALK_ARP (0x80f3)
#define ETYPE_APPLETALK_LAP (0x809b)
#define ETYPE_SNMP (0x814c)

#define SAP_SNAP (0xaa)
#define SAP_BPDU (0x42)
#define SAP_IBM_NM (0xf4)
#define SAP_IBM_NETBIOS (0xf0)
#define SAP_SNA1 (0x4)
#define SAP_SNA2 (0x5)
#define SAP_SNA3 (0x8)
#define SAP_SNA4 (0xc)
#define SAP_NETWARE1 (0x10)
#define SAP_NETWARE2 (0xe0)
#define SAP_NETWARE3 (0xfe)
#define SAP_IP (0x6)
#define SAP_X25 (0x7e)
#define SAP_RPL1 (0xf8)
#define SAP_RPL2 (0xfc)
#define SAP_UB (0xfa)
#define SAP_XNS (0x80)

#define PROP_TYPE_VOID (0)
#define PROP_TYPE_SUMMARY (0x1)
#define PROP_TYPE_BYTE (0x2)
#define PROP_TYPE_WORD (0x3)
#define PROP_TYPE_DWORD (0x4)
#define PROP_TYPE_LARGEINT (0x5)
#define PROP_TYPE_ADDR (0x6)
#define PROP_TYPE_TIME (0x7)
#define PROP_TYPE_STRING (0x8)
#define PROP_TYPE_IP_ADDRESS (0x9)
#define PROP_TYPE_IPX_ADDRESS (0xa)
#define PROP_TYPE_BYTESWAPPED_WORD (0xb)
#define PROP_TYPE_BYTESWAPPED_DWORD (0xc)
#define PROP_TYPE_TYPED_STRING (0xd)
#define PROP_TYPE_RAW_DATA (0xe)
#define PROP_TYPE_COMMENT (0xf)
#define PROP_TYPE_SRCFRIENDLYNAME (0x10)
#define PROP_TYPE_DSTFRIENDLYNAME (0x11)
#define PROP_TYPE_TOKENRING_ADDRESS (0x12)
#define PROP_TYPE_FDDI_ADDRESS (0x13)
#define PROP_TYPE_ETHERNET_ADDRESS (0x14)
#define PROP_TYPE_OBJECT_IDENTIFIER (0x15)
#define PROP_TYPE_VINES_IP_ADDRESS (0x16)
#define PROP_TYPE_VAR_LEN_SMALL_INT (0x17)
#define PROP_TYPE_ATM_ADDRESS (0x18)
#define PROP_TYPE_1394_ADDRESS (0x19)
#define PROP_TYPE_IP6_ADDRESS (0x1a)

#define PROP_QUAL_NONE (0)
#define PROP_QUAL_RANGE (0x1)
#define PROP_QUAL_SET (0x2)
#define PROP_QUAL_BITFIELD (0x3)
#define PROP_QUAL_LABELED_SET (0x4)
#define PROP_QUAL_LABELED_BITFIELD (0x8)
#define PROP_QUAL_CONST (0x9)
#define PROP_QUAL_FLAGS (0xa)
#define PROP_QUAL_ARRAY (0xb)

  typedef LARGE_INTEGER *LPLARGEINT;
  typedef LARGE_INTEGER UNALIGNED *ULPLARGEINT;

  typedef struct _RANGE {
    DWORD MinValue;
    DWORD MaxValue;
  } RANGE;

  typedef RANGE *LPRANGE;

  typedef struct _LABELED_BYTE {
    BYTE Value;
    LPSTR Label;
  } LABELED_BYTE;

  typedef LABELED_BYTE *LPLABELED_BYTE;

  typedef struct _LABELED_WORD {
    WORD Value;
    LPSTR Label;
  } LABELED_WORD;

  typedef LABELED_WORD *LPLABELED_WORD;

  typedef struct _LABELED_DWORD {
    DWORD Value;
    LPSTR Label;
  } LABELED_DWORD;

  typedef LABELED_DWORD *LPLABELED_DWORD;

  typedef struct _LABELED_LARGEINT {
    LARGE_INTEGER Value;
    LPSTR Label;
  } LABELED_LARGEINT;

  typedef LABELED_LARGEINT *LPLABELED_LARGEINT;

  typedef struct _LABELED_SYSTEMTIME {
    SYSTEMTIME Value;
    LPSTR Label;
  } LABELED_SYSTEMTIME;

  typedef LABELED_SYSTEMTIME *LPLABELED_SYSTEMTIME;

  typedef struct _LABELED_BIT {
    BYTE BitNumber;
    LPSTR LabelOff;
    LPSTR LabelOn;
  } LABELED_BIT;

  typedef LABELED_BIT *LPLABELED_BIT;

#define TYPED_STRING_NORMAL (1)
#define TYPED_STRING_UNICODE (2)

#define TYPED_STRING_EXFLAG (1)

  typedef struct _TYPED_STRING {
    BYTE StringType:7;
    BYTE fStringEx:1;
    LPSTR lpString;
    BYTE Byte[0];
  } TYPED_STRING;

  typedef TYPED_STRING *LPTYPED_STRING;

  typedef struct _OBJECT_IDENTIFIER {
    DWORD Length;
    LPDWORD lpIdentifier;
  } OBJECT_IDENTIFIER;

  typedef OBJECT_IDENTIFIER *LPOBJECT_IDENTIFIER;

  typedef struct _SET {
    DWORD nEntries;
    __C89_NAMELESS union {
      LPVOID lpVoidTable;
      LPBYTE lpByteTable;
      LPWORD lpWordTable;
      LPDWORD lpDwordTable;
      LPLARGEINT lpLargeIntTable;
      LPSYSTEMTIME lpSystemTimeTable;
      LPLABELED_BYTE lpLabeledByteTable;
      LPLABELED_WORD lpLabeledWordTable;
      LPLABELED_DWORD lpLabeledDwordTable;
      LPLABELED_LARGEINT lpLabeledLargeIntTable;
      LPLABELED_SYSTEMTIME lpLabeledSystemTimeTable;
      LPLABELED_BIT lpLabeledBit;
    };
  } SET;

  typedef SET *LPSET;

  typedef struct _STRINGTABLE {
    DWORD nStrings;
    LPSTR String[0];
  } STRINGTABLE;

  typedef STRINGTABLE *LPSTRINGTABLE;
#define STRINGTABLE_SIZE sizeof(STRINGTABLE)

  typedef struct _RECOGNIZEDATA {
    WORD ProtocolID;
    WORD nProtocolOffset;
    LPVOID InstData;
  } RECOGNIZEDATA;

  typedef RECOGNIZEDATA *LPRECOGNIZEDATA;

  typedef struct _RECOGNIZEDATATABLE {
    WORD nRecognizeDatas;
    RECOGNIZEDATA RecognizeData[0];
  } RECOGNIZEDATATABLE;

  typedef RECOGNIZEDATATABLE *LPRECOGNIZEDATATABLE;

  typedef struct _PROPERTYINFO {
    HPROPERTY hProperty;
    DWORD Version;
    LPSTR Label;
    LPSTR Comment;
    BYTE DataType;
    BYTE DataQualifier;
    __C89_NAMELESS union {
      LPVOID lpExtendedInfo;
      LPRANGE lpRange;
      LPSET lpSet;
      DWORD Bitmask;
      DWORD Value;
    };
    WORD FormatStringSize;
    LPVOID InstanceData;
  } PROPERTYINFO;

  typedef PROPERTYINFO *LPPROPERTYINFO;

#define PROPERTYINFO_SIZE (sizeof(PROPERTYINFO))

  typedef struct _PROPERTYINSTEX {
    WORD Length;
    WORD LengthEx;
    ULPVOID lpData;
    __C89_NAMELESS union {
      BYTE Byte[1];
      WORD Word[1];
      DWORD Dword[1];
      LARGE_INTEGER LargeInt[1];
      SYSTEMTIME SysTime[1];
      TYPED_STRING TypedString;
    };
  } PROPERTYINSTEX;
  typedef PROPERTYINSTEX *LPPROPERTYINSTEX;
  typedef PROPERTYINSTEX UNALIGNED *ULPPROPERTYINSTEX;

#define PROPERTYINSTEX_SIZE sizeof(PROPERTYINSTEX)

  typedef struct _PROPERTYINST {
    LPPROPERTYINFO lpPropertyInfo;
    LPSTR szPropertyText;
    __C89_NAMELESS union {
      LPVOID lpData;
      ULPBYTE lpByte;
      ULPWORD lpWord;
      ULPDWORD lpDword;
      ULPLARGEINT lpLargeInt;
      ULPSYSTEMTIME lpSysTime;
      LPPROPERTYINSTEX lpPropertyInstEx;
    };
    WORD DataLength;
    WORD Level : 4;
    WORD HelpID : 12;
    DWORD IFlags;
  } PROPERTYINST;

  typedef PROPERTYINST *LPPROPERTYINST;

#define PROPERTYINST_SIZE sizeof(PROPERTYINST)

#define IFLAG_ERROR (0x1)
#define IFLAG_SWAPPED (0x2)
#define IFLAG_UNICODE (0x4)

  typedef struct _PROPERTYINSTTABLE {
    WORD nPropertyInsts;
    WORD nPropertyInstIndex;
  } PROPERTYINSTTABLE;

  typedef PROPERTYINSTTABLE *LPPROPERTYINSTTABLE;

#define PROPERTYINSTTABLE_SIZE (sizeof(PROPERTYINSTTABLE))

  typedef struct _PROPERTYTABLE {
    LPVOID lpFormatBuffer;
    DWORD FormatBufferLength;
    DWORD nTotalPropertyInsts;
    LPPROPERTYINST lpFirstPropertyInst;
    BYTE nPropertyInstTables;
    PROPERTYINSTTABLE PropertyInstTable[0];
  } PROPERTYTABLE;

  typedef PROPERTYTABLE *LPPROPERTYTABLE;

#define PROPERTYTABLE_SIZE sizeof(PROPERTYTABLE)

  typedef VOID (WINAPI *REGISTER)(HPROTOCOL);
  typedef VOID (WINAPI *DEREGISTER)(HPROTOCOL);
  typedef LPBYTE (WINAPI *RECOGNIZEFRAME)(HFRAME,ULPBYTE,ULPBYTE,DWORD,DWORD,HPROTOCOL,DWORD,LPDWORD,LPHPROTOCOL,PDWORD_PTR);
  typedef LPBYTE (WINAPI *ATTACHPROPERTIES)(HFRAME,ULPBYTE,ULPBYTE,DWORD,DWORD,HPROTOCOL,DWORD,DWORD_PTR);
  typedef DWORD (WINAPI *FORMATPROPERTIES)(HFRAME,ULPBYTE,ULPBYTE,DWORD,LPPROPERTYINST);

  typedef struct _ENTRYPOINTS {
    REGISTER Register;
    DEREGISTER Deregister;
    RECOGNIZEFRAME RecognizeFrame;
    ATTACHPROPERTIES AttachProperties;
    FORMATPROPERTIES FormatProperties;
  } ENTRYPOINTS;

  typedef ENTRYPOINTS *LPENTRYPOINTS;

#define ENTRYPOINTS_SIZE sizeof(ENTRYPOINTS)

  typedef struct _PROPERTYDATABASE {
    DWORD nProperties;
    LPPROPERTYINFO PropertyInfo[0];
  } PROPERTYDATABASE;

#define PROPERTYDATABASE_SIZE sizeof(PROPERTYDATABASE)

  typedef PROPERTYDATABASE *LPPROPERTYDATABASE;

  typedef struct _PROTOCOLINFO {
    DWORD ProtocolID;
    LPPROPERTYDATABASE PropertyDatabase;
    BYTE ProtocolName[16];
    BYTE HelpFile[16];
    BYTE Comment[128];
  } PROTOCOLINFO;

  typedef PROTOCOLINFO *LPPROTOCOLINFO;

#define PROTOCOLINFO_SIZE sizeof(PROTOCOLINFO)

  typedef struct _PROTOCOLTABLE {
    DWORD nProtocols;
    HPROTOCOL hProtocol[1];
  } PROTOCOLTABLE;

  typedef PROTOCOLTABLE *LPPROTOCOLTABLE;

#define PROTOCOLTABLE_SIZE (sizeof(PROTOCOLTABLE) - sizeof(HPROTOCOL))
#define PROTOCOLTABLE_ACTUAL_SIZE(p) GetTableSize(PROTOCOLTABLE_SIZE,(p)->nProtocols,sizeof(HPROTOCOL))

#define SORT_BYADDRESS (0)
#define SORT_BYNAME (1)
#define PERMANENT_NAME (0x100)

  typedef struct _ADDRESSINFO2 {
    ADDRESS2 Address;
    WCHAR Name[MAX_NAME_SIZE];
    DWORD Flags;
    LPVOID lpAddressInstData;
  } ADDRESSINFO2;

  typedef struct _ADDRESSINFO2 *LPADDRESSINFO2;

#define ADDRESSINFO2_SIZE sizeof(ADDRESSINFO2)

  typedef struct _ADDRESSINFOTABLE2 {
    DWORD nAddressInfos;
    LPADDRESSINFO2 lpAddressInfo[0];
  } ADDRESSINFOTABLE2;

  typedef ADDRESSINFOTABLE2 *LPADDRESSINFOTABLE2;

#define ADDRESSINFOTABLE2_SIZE sizeof(ADDRESSINFOTABLE2)

  typedef DWORD (WINAPI *FILTERPROC)(HCAPTURE,HFRAME,LPVOID);

#define NMERR_SUCCESS (0)
#define NMERR_MEMORY_MAPPED_FILE_ERROR (1)
#define NMERR_INVALID_HFILTER (2)
#define NMERR_CAPTURING (3)
#define NMERR_NOT_CAPTURING (4)
#define NMERR_NO_MORE_FRAMES (5)
#define NMERR_BUFFER_TOO_SMALL (6)
#define NMERR_FRAME_NOT_RECOGNIZED (7)
#define NMERR_FILE_ALREADY_EXISTS (8)
#define NMERR_DRIVER_NOT_FOUND (9)
#define NMERR_ADDRESS_ALREADY_EXISTS (10)
#define NMERR_INVALID_HFRAME (11)
#define NMERR_INVALID_HPROTOCOL (12)
#define NMERR_INVALID_HPROPERTY (13)
#define NMERR_LOCKED (14)
#define NMERR_STACK_EMPTY (15)
#define NMERR_STACK_OVERFLOW (16)
#define NMERR_TOO_MANY_PROTOCOLS (17)
#define NMERR_FILE_NOT_FOUND (18)
#define NMERR_OUT_OF_MEMORY (19)
#define NMERR_CAPTURE_PAUSED (20)
#define NMERR_NO_BUFFERS (21)
#define NMERR_BUFFERS_ALREADY_EXIST (22)
#define NMERR_NOT_LOCKED (23)
#define NMERR_OUT_OF_RANGE (24)
#define NMERR_LOCK_NESTING_TOO_DEEP (25)
#define NMERR_LOAD_PARSER_FAILED (26)
#define NMERR_UNLOAD_PARSER_FAILED (27)
#define NMERR_INVALID_HADDRESSDB (28)
#define NMERR_ADDRESS_NOT_FOUND (29)
#define NMERR_NETWORK_NOT_PRESENT (30)
#define NMERR_NO_PROPERTY_DATABASE (31)
#define NMERR_PROPERTY_NOT_FOUND (32)
#define NMERR_INVALID_HPROPERTYDB (33)
#define NMERR_PROTOCOL_NOT_ENABLED (34)
#define NMERR_PROTOCOL_NOT_FOUND (35)
#define NMERR_INVALID_PARSER_DLL (36)
#define NMERR_NO_ATTACHED_PROPERTIES (37)
#define NMERR_NO_FRAMES (38)
#define NMERR_INVALID_FILE_FORMAT (39)
#define NMERR_COULD_NOT_CREATE_TEMPFILE (40)
#define NMERR_OUT_OF_DOS_MEMORY (41)
#define NMERR_NO_PROTOCOLS_ENABLED (42)
#define NMERR_UNKNOWN_MACTYPE (46)
#define NMERR_ROUTING_INFO_NOT_PRESENT (47)
#define NMERR_INVALID_HNETWORK (48)
#define NMERR_NETWORK_ALREADY_OPENED (49)
#define NMERR_NETWORK_NOT_OPENED (50)
#define NMERR_FRAME_NOT_FOUND (51)
#define NMERR_NO_HANDLES (53)
#define NMERR_INVALID_NETWORK_ID (54)
#define NMERR_INVALID_HCAPTURE (55)
#define NMERR_PROTOCOL_ALREADY_ENABLED (56)
#define NMERR_FILTER_INVALID_EXPRESSION (57)
#define NMERR_TRANSMIT_ERROR (58)
#define NMERR_INVALID_HBUFFER (59)
#define NMERR_INVALID_DATA (60)
#define NMERR_MSDOS_DRIVER_NOT_LOADED (61)
#define NMERR_WINDOWS_DRIVER_NOT_LOADED (62)
#define NMERR_MSDOS_DRIVER_INIT_FAILURE (63)
#define NMERR_WINDOWS_DRIVER_INIT_FAILURE (64)
#define NMERR_NETWORK_BUSY (65)
#define NMERR_CAPTURE_NOT_PAUSED (66)
#define NMERR_INVALID_PACKET_LENGTH (67)
#define NMERR_INTERNAL_EXCEPTION (69)
#define NMERR_PROMISCUOUS_MODE_NOT_SUPPORTED (70)
#define NMERR_MAC_DRIVER_OPEN_FAILURE (71)
#define NMERR_RUNAWAY_PROTOCOL (72)
#define NMERR_PENDING (73)
#define NMERR_ACCESS_DENIED (74)
#define NMERR_INVALID_HPASSWORD (75)
#define NMERR_INVALID_PARAMETER (76)
#define NMERR_FILE_READ_ERROR (77)
#define NMERR_FILE_WRITE_ERROR (78)
#define NMERR_PROTOCOL_NOT_REGISTERED (79)
#define NMERR_IP_ADDRESS_NOT_FOUND (80)
#define NMERR_TRANSMIT_CANCELLED (81)
#define NMERR_LOCKED_FRAMES (82)
#define NMERR_NO_TRANSMITS_PENDING (83)
#define NMERR_PATH_NOT_FOUND (84)
#define NMERR_WINDOWS_ERROR (85)
#define NMERR_NO_FRAME_NUMBER (86)
#define NMERR_FRAME_HAS_NO_CAPTURE (87)
#define NMERR_FRAME_ALREADY_HAS_CAPTURE (88)
#define NMERR_NAL_IS_NOT_REMOTE (89)
#define NMERR_NOT_SUPPORTED (90)
#define NMERR_DISCARD_FRAME (91)
#define NMERR_CANCEL_SAVE_CAPTURE (92)
#define NMERR_LOST_CONNECTION (93)
#define NMERR_INVALID_MEDIA_TYPE (94)
#define NMERR_AGENT_IN_USE (95)
#define NMERR_TIMEOUT (96)
#define NMERR_DISCONNECTED (97)
#define NMERR_SETTIMER_FAILED (98)
#define NMERR_NETWORK_ERROR (99)
#define NMERR_INVALID_FRAMESPROC (100)
#define NMERR_UNKNOWN_CAPTURETYPE (101)
#define NMERR_NOT_CONNECTED (102)
#define NMERR_ALREADY_CONNECTED (103)
#define NMERR_INVALID_REGISTRY_CONFIGURATION (104)
#define NMERR_DELAYED (105)
#define NMERR_NOT_DELAYED (106)
#define NMERR_REALTIME (107)
#define NMERR_NOT_REALTIME (108)
#define NMERR_STATS_ONLY (109)
#define NMERR_NOT_STATS_ONLY (110)
#define NMERR_TRANSMIT (111)
#define NMERR_NOT_TRANSMIT (112)
#define NMERR_TRANSMITTING (113)
#define NMERR_DISK_NOT_LOCAL_FIXED (114)
#define NMERR_COULD_NOT_CREATE_DIRECTORY (115)
#define NMERR_NO_DEFAULT_CAPTURE_DIRECTORY (116)
#define NMERR_UPLEVEL_CAPTURE_FILE (117)
#define NMERR_LOAD_EXPERT_FAILED (118)
#define NMERR_EXPERT_REPORT_FAILED (119)
#define NMERR_REG_OPERATION_FAILED (120)
#define NMERR_NO_DLLS_FOUND (121)
#define NMERR_NO_CONVERSATION_STATS (122)
#define NMERR_SECURITY_BREACH_CAPTURE_DELETED (123)
#define NMERR_FRAME_FAILED_FILTER (124)
#define NMERR_EXPERT_TERMINATE (125)
#define NMERR_REMOTE_NOT_A_SERVER (126)
#define NMERR_REMOTE_VERSION_OUTOFSYNC (127)
#define NMERR_INVALID_EXPERT_GROUP (128)
#define NMERR_INVALID_EXPERT_NAME (129)
#define NMERR_INVALID_EXPERT_HANDLE (130)
#define NMERR_GROUP_NAME_ALREADY_EXISTS (131)
#define NMERR_INVALID_GROUP_NAME (132)
#define NMERR_EXPERT_ALREADY_IN_GROUP (133)
#define NMERR_EXPERT_NOT_IN_GROUP (134)
#define NMERR_NOT_INITIALIZED (135)
#define NMERR_INVALID_GROUP_ROOT (136)
#define NMERR_BAD_VERSION (137)
#define NMERR_ESP (138)
#define NMERR_NOT_ESP (139)
#define NMERR_BLOB_NOT_INITIALIZED (1000)
#define NMERR_INVALID_BLOB (1001)
#define NMERR_UPLEVEL_BLOB (1002)
#define NMERR_BLOB_ENTRY_ALREADY_EXISTS (1003)
#define NMERR_BLOB_ENTRY_DOES_NOT_EXIST (1004)
#define NMERR_AMBIGUOUS_SPECIFIER (1005)
#define NMERR_BLOB_OWNER_NOT_FOUND (1006)
#define NMERR_BLOB_CATEGORY_NOT_FOUND (1007)
#define NMERR_UNKNOWN_CATEGORY (1008)
#define NMERR_UNKNOWN_TAG (1009)
#define NMERR_BLOB_CONVERSION_ERROR (1010)
#define NMERR_ILLEGAL_TRIGGER (1011)
#define NMERR_BLOB_STRING_INVALID (1012)
#define NMERR_UNABLE_TO_LOAD_LIBRARY (1013)
#define NMERR_UNABLE_TO_GET_PROCADDR (1014)
#define NMERR_CLASS_NOT_REGISTERED (1015)
#define NMERR_INVALID_REMOTE_COMPUTERNAME (1016)
#define NMERR_RPC_REMOTE_FAILURE (1017)
#define NMERR_NO_NPPS (3016)
#define NMERR_NO_MATCHING_NPPS (3017)
#define NMERR_NO_NPP_SELECTED (3018)
#define NMERR_NO_INPUT_BLOBS (3019)
#define NMERR_NO_NPP_DLLS (3020)
#define NMERR_NO_VALID_NPP_DLLS (3021)

#ifndef INLINE
#define INLINE __CRT_INLINE
#endif
  typedef LONG HRESULT;

  INLINE HRESULT NMERR_TO_HRESULT(DWORD nmerror) {
    HRESULT hResult;
    if(nmerror==NMERR_SUCCESS) hResult = NOERROR;
    else hResult = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_ITF,(WORD)nmerror);
    return hResult;
  }

  INLINE DWORD HRESULT_TO_NMERR(HRESULT hResult) { return HRESULT_CODE(hResult); }

  typedef HFILTER *LPHFILTER;
  typedef DWORD FILTERACTIONTYPE;
  typedef DWORD VALUETYPE;

#define PROTOCOL_NUM_ANY (-1)

  typedef PROTOCOLTABLE PROTOCOLTABLETYPE;
  typedef PROTOCOLTABLETYPE *LPPROTOCOLTABLETYPE;
  typedef DWORD FILTERBITS;
  typedef FILTERBITS *LPFILTERBITS;
  typedef SYSTEMTIME *LPTIME;
  typedef SYSTEMTIME UNALIGNED *ULPTIME;

  typedef struct _FILTEROBJECT2 {
    FILTERACTIONTYPE Action;
    HPROPERTY hProperty;
    __C89_NAMELESS union {
      VALUETYPE Value;
      HPROTOCOL hProtocol;
      LPVOID lpArray;
      LPPROTOCOLTABLETYPE lpProtocolTable;
      LPADDRESS2 lpAddress;
      ULPLARGEINT lpLargeInt;
      ULPTIME lpTime;
      LPOBJECT_IDENTIFIER lpOID;
    };
    __C89_NAMELESS union {
      WORD ByteCount;
      WORD ByteOffset;
    };
    struct _FILTEROBJECT2 *pNext;
  } FILTEROBJECT2;

  typedef FILTEROBJECT2 *LPFILTEROBJECT2;

#define FILTERINFO_SIZE (sizeof(FILTEROBJECT2))

  typedef struct _FILTERDESC2 {
    WORD NumEntries;
    WORD Flags;
    LPFILTEROBJECT2 lpStack;
    LPFILTEROBJECT2 lpKeepLast;
    LPVOID UIInstanceData;
    LPFILTERBITS lpFilterBits;
    LPFILTERBITS lpCheckBits;
  } FILTERDESC2;

  typedef FILTERDESC2 *LPFILTERDESC2;

#define FILTERDESC2_SIZE sizeof(FILTERDESC2)

  typedef struct _FILTEROBJECT {
    FILTERACTIONTYPE Action;
    HPROPERTY hProperty;
    __C89_NAMELESS union {
      VALUETYPE Value;
      HPROTOCOL hProtocol;
      LPVOID lpArray;
      LPPROTOCOLTABLETYPE lpProtocolTable;
      LPADDRESS lpAddress;
      ULPLARGEINT lpLargeInt;
      ULPTIME lpTime;
      LPOBJECT_IDENTIFIER lpOID;
    };
    __C89_NAMELESS union {
      WORD ByteCount;
      WORD ByteOffset;
    };
    struct _FILTEROBJECT *pNext;
  } FILTEROBJECT;
  typedef FILTEROBJECT *LPFILTEROBJECT;

  typedef struct _FILTERDESC {
    WORD NumEntries;
    WORD Flags;
    LPFILTEROBJECT lpStack;
    LPFILTEROBJECT lpKeepLast;
    LPVOID UIInstanceData;
    LPFILTERBITS lpFilterBits;
    LPFILTERBITS lpCheckBits;
  } FILTERDESC;

  typedef FILTERDESC *LPFILTERDESC;

#define FILTERDESC_SIZE sizeof(FILTERDESC)

#define FilterGetUIInstanceData(hfilt) (((LPFILTERDESC2)hfilt)->UIInstanceData)
#define FilterSetUIInstanceData(hfilt,inst) (((LPFILTERDESC2)hfilt)->UIInstanceData = (LPVOID)inst)

#define FILTERFREEPOOLSTART (20)

#define INVALIDELEMENT (-1)
#define INVALIDVALUE ((VALUETYPE)-9999)
#define FILTER_FAIL_WITH_ERROR (-1)
#define FILTER_PASSED (TRUE)
#define FILTER_FAILED (FALSE)

#define FILTERACTION_INVALID (0)
#define FILTERACTION_PROPERTY (1)
#define FILTERACTION_VALUE (2)
#define FILTERACTION_STRING (3)
#define FILTERACTION_ARRAY (4)
#define FILTERACTION_AND (5)
#define FILTERACTION_OR (6)
#define FILTERACTION_XOR (7)
#define FILTERACTION_PROPERTYEXIST (8)
#define FILTERACTION_CONTAINSNC (9)
#define FILTERACTION_CONTAINS (10)
#define FILTERACTION_NOT (11)
#define FILTERACTION_EQUALNC (12)
#define FILTERACTION_EQUAL (13)
#define FILTERACTION_NOTEQUALNC (14)
#define FILTERACTION_NOTEQUAL (15)
#define FILTERACTION_GREATERNC (16)
#define FILTERACTION_GREATER (17)
#define FILTERACTION_LESSNC (18)
#define FILTERACTION_LESS (19)
#define FILTERACTION_GREATEREQUALNC (20)
#define FILTERACTION_GREATEREQUAL (21)
#define FILTERACTION_LESSEQUALNC (22)
#define FILTERACTION_LESSEQUAL (23)
#define FILTERACTION_PLUS (24)
#define FILTERACTION_MINUS (25)
#define FILTERACTION_ADDRESS (26)
#define FILTERACTION_ADDRESSANY (27)
#define FILTERACTION_FROM (28)
#define FILTERACTION_TO (29)
#define FILTERACTION_FROMTO (30)
#define FILTERACTION_AREBITSON (31)
#define FILTERACTION_AREBITSOFF (32)
#define FILTERACTION_PROTOCOLSEXIST (33)
#define FILTERACTION_PROTOCOLEXIST (34)
#define FILTERACTION_ARRAYEQUAL (35)
#define FILTERACTION_DEREFPROPERTY (36)
#define FILTERACTION_LARGEINT (37)
#define FILTERACTION_TIME (38)
#define FILTERACTION_ADDR_ETHER (39)
#define FILTERACTION_ADDR_TOKEN (40)
#define FILTERACTION_ADDR_FDDI (41)
#define FILTERACTION_ADDR_IPX (42)
#define FILTERACTION_ADDR_IP (43)
#define FILTERACTION_OID (44)
#define FILTERACTION_OID_CONTAINS (45)
#define FILTERACTION_OID_BEGINS_WITH (46)
#define FILTERACTION_OID_ENDS_WITH (47)
#define FILTERACTION_ADDR_VINES (48)
#define FILTERACTION_ADDR_IP6 (49)
#define FILTERACTION_EXPRESSION (97)
#define FILTERACTION_BOOL (98)
#define FILTERACTION_NOEVAL (99)
#define FILTER_NO_MORE_FRAMES (0xffffffff)
#define FILTER_CANCELED (0xfffffffe)
#define FILTER_DIRECTION_NEXT (TRUE)
#define FILTER_DIRECTION_PREV (FALSE)

  typedef WINBOOL (WINAPI *STATUSPROC)(DWORD,HCAPTURE,HFILTER,LPVOID);

  HFILTER WINAPI CreateFilter(VOID);
  DWORD WINAPI DestroyFilter(HFILTER hFilter);
  HFILTER WINAPI FilterDuplicate(HFILTER hFilter);
  DWORD WINAPI DisableParserFilter(HFILTER hFilter,HPARSER hParser);
  DWORD WINAPI EnableParserFilter(HFILTER hFilter,HPARSER hParser);
  DWORD WINAPI FilterAddObject(HFILTER hFilter,LPFILTEROBJECT2 lpFilterObject);
  VOID WINAPI FilterFlushBits(HFILTER hFilter);
  DWORD WINAPI FilterFrame(HFRAME hFrame,HFILTER hFilter,HCAPTURE hCapture);
  WINBOOL WINAPI FilterAttachesProperties(HFILTER hFilter);
  DWORD WINAPI FilterFindFrame (HFILTER hFilter,HCAPTURE hCapture,DWORD nFrame,STATUSPROC StatusProc,LPVOID UIInstance,DWORD TimeDelta,WINBOOL FilterDirection);
  HFRAME FilterFindPropertyInstance (HFRAME hFrame,HFILTER hMasterFilter,HCAPTURE hCapture,HFILTER hInstanceFilter,LPPROPERTYINST *lpPropRestartKey,STATUSPROC StatusProc,LPVOID UIInstance,DWORD TimeDelta,WINBOOL FilterForward);
  VOID WINAPI SetCurrentFilter(HFILTER);
  HFILTER WINAPI GetCurrentFilter(VOID);

  typedef struct _ETHERNET {
    BYTE DstAddr[MAX_ADDR_LENGTH];
    BYTE SrcAddr[MAX_ADDR_LENGTH];
    __C89_NAMELESS union {
      WORD Length;
      WORD Type;
    };
    BYTE Info[0];
  } ETHERNET;

  typedef ETHERNET *LPETHERNET;
  typedef ETHERNET UNALIGNED *ULPETHERNET;

#define ETHERNET_SIZE sizeof(ETHERNET)
#define ETHERNET_HEADER_LENGTH (14)

#define ETHERNET_DATA_LENGTH (0x5dc)
#define ETHERNET_FRAME_LENGTH (0x5ea)
#define ETHERNET_FRAME_TYPE (0x600)

  typedef struct _NM_ATM {
    UCHAR DstAddr[6];
    UCHAR SrcAddr[6];
    ULONG Vpi;
    ULONG Vci;
  } NM_ATM;

  typedef NM_ATM *PNM_ATM;
  typedef NM_ATM *UPNM_ATM;

#define NM_ATM_HEADER_LENGTH sizeof(NM_ATM)

#pragma pack(push,1)

  typedef struct _NM_1394 {
    UCHAR DstAddr[6];
    UCHAR SrcAddr[6];
    ULONGLONG VcId;
  } NM_1394;

  typedef NM_1394 *PNM_1394;
  typedef NM_1394 *UPNM_1394;

#define NM_1394_HEADER_LENGTH sizeof(NM_1394)

  typedef struct _TOKENRING {
    BYTE AccessCtrl;
    BYTE FrameCtrl;
    BYTE DstAddr[MAX_ADDR_LENGTH];
    BYTE SrcAddr[MAX_ADDR_LENGTH];
    __C89_NAMELESS union {
      BYTE Info[0];
      WORD RoutingInfo[0];
    };
  } TOKENRING;

  typedef TOKENRING *LPTOKENRING;
  typedef TOKENRING UNALIGNED *ULPTOKENRING;
#define TOKENRING_SIZE sizeof(TOKENRING)
#define TOKENRING_HEADER_LENGTH (14)

#define TOKENRING_SA_ROUTING_INFO (0x80)

#define TOKENRING_SA_LOCAL (0x40)
#define TOKENRING_DA_LOCAL (0x40)
#define TOKENRING_DA_GROUP (0x80)
#define TOKENRING_RC_LENGTHMASK (0x1f)
#define TOKENRING_BC_MASK (0xe0)
#define TOKENRING_TYPE_MAC (0)
#define TOKENRING_TYPE_LLC (0x40)

#pragma pack(pop)

#pragma pack(push,1)

  typedef struct _FDDI {
    BYTE FrameCtrl;
    BYTE DstAddr[MAX_ADDR_LENGTH];
    BYTE SrcAddr[MAX_ADDR_LENGTH];
    BYTE Info[0];
  } FDDI;

#define FDDI_SIZE sizeof(FDDI)

  typedef FDDI *LPFDDI;
  typedef FDDI UNALIGNED *ULPFDDI;

#define FDDI_HEADER_LENGTH (13)
#define FDDI_TYPE_MAC (0)
#define FDDI_TYPE_LLC (0x10)
#define FDDI_TYPE_LONG_ADDRESS (0x40)

#pragma pack(pop)

#pragma pack(push,1)

  typedef struct _LLC {
    BYTE dsap;
    BYTE ssap;
    struct {
      __C89_NAMELESS union {
	BYTE Command;
	BYTE NextSend;
      };
      __C89_NAMELESS union {
	BYTE NextRecv;
	BYTE Data[1];
      };
    } ControlField;
  } LLC;

  typedef LLC *LPLLC;
  typedef LLC UNALIGNED *ULPLLC;

#define LLC_SIZE (sizeof(LLC))

#pragma pack(pop)

#define IsRoutingInfoPresent(f) ((((ULPTOKENRING) (f))->SrcAddr[0] & TOKENRING_SA_ROUTING_INFO) ? TRUE : FALSE)
#define GetRoutingInfoLength(f) (IsRoutingInfoPresent(f) ? (((ULPTOKENRING) (f))->RoutingInfo[0] & TOKENRING_RC_LENGTHMASK) : 0)

  typedef VOID (WINAPIV *FORMAT)(LPPROPERTYINST,...);

#define PROTOCOL_STATUS_RECOGNIZED (0)
#define PROTOCOL_STATUS_NOT_RECOGNIZED (1)
#define PROTOCOL_STATUS_CLAIMED (2)
#define PROTOCOL_STATUS_NEXT_PROTOCOL (3)

  extern BYTE HexTable[];

#define XCHG(x) MAKEWORD(HIBYTE(x),LOBYTE(x))
#define DXCHG(x) MAKELONG(XCHG(HIWORD(x)),XCHG(LOWORD(x)))
#define LONIBBLE(b) ((BYTE) ((b) & 0x0F))
#define HINIBBLE(b) ((BYTE) ((b) >> 4))
#define HEX(b) (HexTable[LONIBBLE(b)])
#define SWAPBYTES(w) ((w) = XCHG(w))
#define SWAPWORDS(d) ((d) = DXCHG(d))

  typedef union _MACFRAME {
    LPBYTE MacHeader;
    LPETHERNET Ethernet;
    LPTOKENRING Tokenring;
    LPFDDI Fddi;
  } MACFRAME;

  typedef MACFRAME *LPMACFRAME;

#define HOT_SIGNATURE MAKE_IDENTIFIER('H','O','T','$')
#define HOE_SIGNATURE MAKE_IDENTIFIER('H','O','E','$')

  typedef struct _HANDOFFENTRY {
    DWORD hoe_sig;
    DWORD hoe_ProtIdentNumber;
    HPROTOCOL hoe_ProtocolHandle;
    DWORD hoe_ProtocolData;
  } HANDOFFENTRY;

  typedef HANDOFFENTRY *LPHANDOFFENTRY;

  typedef struct _HANDOFFTABLE {
    DWORD hot_sig;
    DWORD hot_NumEntries;
    LPHANDOFFENTRY hot_Entries;
  } HANDOFFTABLE;

  typedef struct _HANDOFFTABLE *LPHANDOFFTABLE;

  INLINE LPVOID GetPropertyInstanceData(LPPROPERTYINST PropertyInst) {
    if(PropertyInst->DataLength!=(WORD) -1) return PropertyInst->lpData;
    return (LPVOID) PropertyInst->lpPropertyInstEx->Byte;
  }

#define GetPropertyInstanceDataValue(p,type) ((type *) GetPropertyInstanceData(p))[0]

  INLINE DWORD GetPropertyInstanceFrameDataLength(LPPROPERTYINST PropertyInst) {
    if(PropertyInst->DataLength!=(WORD) -1) return PropertyInst->DataLength;
    return PropertyInst->lpPropertyInstEx->Length;
  }

  INLINE DWORD GetPropertyInstanceExDataLength(LPPROPERTYINST PropertyInst) {
    if(PropertyInst->DataLength==(WORD) -1) {
      PropertyInst->lpPropertyInstEx->Length;
    }
    return (WORD) -1;
  }

  LPLABELED_WORD WINAPI GetProtocolDescriptionTable(LPDWORD TableSize);
  LPLABELED_WORD WINAPI GetProtocolDescription(DWORD ProtocolID);
  DWORD WINAPI GetMacHeaderLength(LPVOID MacHeader,DWORD MacType);
  DWORD WINAPI GetLLCHeaderLength(LPLLC Frame);
  DWORD WINAPI GetEtype(LPVOID MacHeader,DWORD MacType);
  DWORD WINAPI GetSaps(LPVOID MacHeader,DWORD MacType);
  WINBOOL WINAPI IsLLCPresent(LPVOID MacHeader,DWORD MacType);
  VOID WINAPI CanonicalizeHexString(LPSTR hex,LPSTR dest,DWORD len);
  void WINAPI CanonHex(UCHAR *pDest,UCHAR *pSource,int iLen,WINBOOL fOx);
  DWORD WINAPI ByteToBinary(LPSTR string,DWORD ByteValue);
  DWORD WINAPI WordToBinary(LPSTR string,DWORD WordValue);
  DWORD WINAPI DwordToBinary(LPSTR string,DWORD DwordValue);
  LPSTR WINAPI AddressToString(LPSTR string,BYTE *lpAddress);
  LPBYTE WINAPI StringToAddress(BYTE *lpAddress,LPSTR string);
  LPDWORD WINAPI VarLenSmallIntToDword(LPBYTE pValue,WORD ValueLen,WINBOOL fIsByteswapped,LPDWORD lpDword);
  LPBYTE WINAPI LookupByteSetString (LPSET lpSet,BYTE Value);
  LPBYTE WINAPI LookupWordSetString (LPSET lpSet,WORD Value);
  LPBYTE WINAPI LookupDwordSetString (LPSET lpSet,DWORD Value);
  DWORD WINAPIV FormatByteFlags(LPSTR string,DWORD ByteValue,DWORD BitMask);
  DWORD WINAPIV FormatWordFlags(LPSTR string,DWORD WordValue,DWORD BitMask);
  DWORD WINAPIV FormatDwordFlags(LPSTR string,DWORD DwordValue,DWORD BitMask);
  LPSTR WINAPIV FormatTimeAsString(SYSTEMTIME *time,LPSTR string);
  VOID WINAPIV FormatLabeledByteSetAsFlags(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatLabeledWordSetAsFlags(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatLabeledDwordSetAsFlags(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatPropertyDataAsByte(LPPROPERTYINST lpPropertyInst,DWORD Base);
  VOID WINAPIV FormatPropertyDataAsWord(LPPROPERTYINST lpPropertyInst,DWORD Base);
  VOID WINAPIV FormatPropertyDataAsDword(LPPROPERTYINST lpPropertyInst,DWORD Base);
  VOID WINAPIV FormatLabeledByteSet(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatLabeledWordSet(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatLabeledDwordSet(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatPropertyDataAsInt64(LPPROPERTYINST lpPropertyInst,DWORD Base);
  VOID WINAPIV FormatPropertyDataAsTime(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatPropertyDataAsString(LPPROPERTYINST lpPropertyInst);
  VOID WINAPIV FormatPropertyDataAsHexString(LPPROPERTYINST lpPropertyInst);
  ULPBYTE WINAPI ParserTemporaryLockFrame(HFRAME hFrame);
  LPVOID WINAPI GetCCInstPtr(VOID);
  VOID WINAPI SetCCInstPtr(LPVOID lpCurCaptureInst);
  LPVOID WINAPI CCHeapAlloc(DWORD dwBytes,WINBOOL bZeroInit);
  LPVOID WINAPI CCHeapReAlloc(LPVOID lpMem,DWORD dwBytes,WINBOOL bZeroInit);
  WINBOOL WINAPI CCHeapFree(LPVOID lpMem);
  SIZE_T WINAPI CCHeapSize(LPVOID lpMem);
  WINBOOL __cdecl BERGetInteger(ULPBYTE pCurrentPointer,ULPBYTE *ppValuePointer,LPDWORD pHeaderLength,LPDWORD pDataLength,ULPBYTE *ppNext);
  WINBOOL __cdecl BERGetString(ULPBYTE pCurrentPointer,ULPBYTE *ppValuePointer,LPDWORD pHeaderLength,LPDWORD pDataLength,ULPBYTE *ppNext);
  WINBOOL __cdecl BERGetHeader(ULPBYTE pCurrentPointer,ULPBYTE pTag,LPDWORD pHeaderLength,LPDWORD pDataLength,ULPBYTE *ppNext);

#define MAX_PROTOCOL_COMMENT_LEN (256)

#define NETMON_MAX_PROTOCOL_NAME_LEN (16)

#ifndef MAX_PROTOCOL_NAME_LEN
#define MAX_PROTOCOL_NAME_LEN (NETMON_MAX_PROTOCOL_NAME_LEN)
#else
#undef MAX_PROTOCOL_NAME_LEN
#endif

  typedef enum __MIDL___MIDL_itf_netmon_0000_0015 {
    HANDOFF_VALUE_FORMAT_BASE_UNKNOWN = 0,HANDOFF_VALUE_FORMAT_BASE_DECIMAL = 10,HANDOFF_VALUE_FORMAT_BASE_HEX = 16
  } PF_HANDOFFVALUEFORMATBASE;

  typedef struct _PF_HANDOFFENTRY {
    char szIniFile[260];
    char szIniSection[260];
    char szProtocol[16];
    DWORD dwHandOffValue;
    PF_HANDOFFVALUEFORMATBASE ValueFormatBase;
  } PF_HANDOFFENTRY;

  typedef PF_HANDOFFENTRY *PPF_HANDOFFENTRY;

  typedef struct _PF_HANDOFFSET {
    DWORD nEntries;
    PF_HANDOFFENTRY Entry[0];
  } PF_HANDOFFSET;

  typedef PF_HANDOFFSET *PPF_HANDOFFSET;

  typedef struct _PF_FOLLOWENTRY {
    char szProtocol[16];
  } PF_FOLLOWENTRY;

  typedef PF_FOLLOWENTRY *PPF_FOLLOWENTRY;

  typedef struct _PF_FOLLOWSET {
    DWORD nEntries;
    PF_FOLLOWENTRY Entry[0];
  } PF_FOLLOWSET;

  typedef PF_FOLLOWSET *PPF_FOLLOWSET;

  typedef struct _PF_PARSERINFO {
    char szProtocolName[NETMON_MAX_PROTOCOL_NAME_LEN];
    char szComment[MAX_PROTOCOL_COMMENT_LEN];
    char szHelpFile[MAX_PATH];
    PPF_FOLLOWSET pWhoCanPrecedeMe;
    PPF_FOLLOWSET pWhoCanFollowMe;
    PPF_HANDOFFSET pWhoHandsOffToMe;
    PPF_HANDOFFSET pWhoDoIHandOffTo;
  } PF_PARSERINFO;

  typedef PF_PARSERINFO *PPF_PARSERINFO;

  typedef struct _PF_PARSERDLLINFO {
    DWORD nParsers;
    PF_PARSERINFO ParserInfo[0];
  } PF_PARSERDLLINFO;

  typedef PF_PARSERDLLINFO *PPF_PARSERDLLINFO;

#define INI_PATH_LENGTH (256)

#define MAX_HANDOFF_ENTRY_LENGTH (80)
#define MAX_PROTOCOL_NAME (40)
#define NUMALLOCENTRIES (10)
#define RAW_INI_STR_LEN (200)

#define PARSERS_SUBDIR "PARSERS"
#define INI_EXTENSION "INI"
#define BASE10_FORMAT_STR "%ld=%s %ld"
#define BASE16_FORMAT_STR "%lx=%s %lx"

  LPSTR __cdecl BuildINIPath(char *FullPath,char *IniFileName);
  DWORD WINAPI CreateHandoffTable(LPSTR secName,LPSTR iniFile,LPHANDOFFTABLE *hTable,DWORD nMaxProtocolEntries,DWORD base);
  HPROTOCOL WINAPI GetProtocolFromTable(LPHANDOFFTABLE hTable,DWORD ItemToFind,PDWORD_PTR lpInstData);
  VOID WINAPI DestroyHandoffTable(LPHANDOFFTABLE hTable);
  BOOLEAN WINAPI IsRawIPXEnabled(LPSTR secName,LPSTR iniFile,LPSTR CurProtocol);

#define EXPERTSTRINGLENGTH (260)
#define EXPERTGROUPNAMELENGTH (25)

  typedef LPVOID HEXPERTKEY;
  typedef HEXPERTKEY *PHEXPERTKEY;
  typedef LPVOID HEXPERT;
  typedef HEXPERT *PHEXPERT;
  typedef LPVOID HRUNNINGEXPERT;
  typedef HRUNNINGEXPERT *PHRUNNINGEXPERT;
  typedef struct _EXPERTENUMINFO *PEXPERTENUMINFO;
  typedef struct _EXPERTCONFIG *PEXPERTCONFIG;
  typedef struct _EXPERTSTARTUPINFO *PEXPERTSTARTUPINFO;

#define EXPERTENTRY_REGISTER "Register"
#define EXPERTENTRY_CONFIGURE "Configure"
#define EXPERTENTRY_RUN "Run"
  typedef WINBOOL (WINAPI *PEXPERTREGISTERPROC)(PEXPERTENUMINFO);
  typedef WINBOOL (WINAPI *PEXPERTCONFIGPROC) (HEXPERTKEY,PEXPERTCONFIG*,PEXPERTSTARTUPINFO,DWORD,HWND);
  typedef WINBOOL (WINAPI *PEXPERTRUNPROC) (HEXPERTKEY,PEXPERTCONFIG,PEXPERTSTARTUPINFO,DWORD,HWND);

  typedef struct _EXPERTENUMINFO {
    char szName[EXPERTSTRINGLENGTH];
    char szVendor[EXPERTSTRINGLENGTH];
    char szDescription[EXPERTSTRINGLENGTH];
    DWORD Version;
    DWORD Flags;
    char szDllName[MAX_PATH];
    HEXPERT hExpert;
    HINSTANCE hModule;
    PEXPERTREGISTERPROC pRegisterProc;
    PEXPERTCONFIGPROC pConfigProc;
    PEXPERTRUNPROC pRunProc;
  } EXPERTENUMINFO;

  typedef EXPERTENUMINFO *PEXPERTENUMINFO;

#define EXPERT_ENUM_FLAG_CONFIGURABLE (0x1)
#define EXPERT_ENUM_FLAG_VIEWER_PRIVATE (0x2)
#define EXPERT_ENUM_FLAG_NO_VIEWER (0x4)
#define EXPERT_ENUM_FLAG_ADD_ME_TO_RMC_IN_SUMMARY (0x10)
#define EXPERT_ENUM_FLAG_ADD_ME_TO_RMC_IN_DETAIL (0x20)

  typedef struct _EXPERTSTARTUPINFO {
    DWORD Flags;
    HCAPTURE hCapture;
    char szCaptureFile[MAX_PATH];
    DWORD dwFrameNumber;
    HPROTOCOL hProtocol;
    LPPROPERTYINST lpPropertyInst;
    struct {
      BYTE BitNumber;
      WINBOOL bOn;
    } sBitfield;
  } EXPERTSTARTUPINFO;

  typedef struct _EXPERTCONFIG {
    DWORD RawConfigLength;
    BYTE RawConfigData[0];
  } EXPERTCONFIG;

  typedef EXPERTCONFIG *PEXPERTCONFIG;

  typedef struct {
    HEXPERT hExpert;
    DWORD StartupFlags;
    PEXPERTCONFIG pConfig;
  } CONFIGUREDEXPERT;

  typedef CONFIGUREDEXPERT *PCONFIGUREDEXPERT;

  typedef struct {
    DWORD FrameNumber;
    HFRAME hFrame;
    ULPFRAME pFrame;
    LPRECOGNIZEDATATABLE lpRecognizeDataTable;
    LPPROPERTYTABLE lpPropertyTable;
  } EXPERTFRAMEDESCRIPTOR;

  typedef EXPERTFRAMEDESCRIPTOR *LPEXPERTFRAMEDESCRIPTOR;

#define GET_SPECIFIED_FRAME (0)
#define GET_FRAME_NEXT_FORWARD (1)
#define GET_FRAME_NEXT_BACKWARD (2)
#define FLAGS_DEFER_TO_UI_FILTER (0x1)
#define FLAGS_ATTACH_PROPERTIES (0x2)

  typedef enum __MIDL___MIDL_itf_netmon_0000_0016 {
    EXPERTSTATUS_INACTIVE = 0,EXPERTSTATUS_STARTING,EXPERTSTATUS_RUNNING,
    EXPERTSTATUS_PROBLEM,EXPERTSTATUS_ABORTED,EXPERTSTATUS_DONE
  } EXPERTSTATUSENUMERATION;

#define EXPERTSUBSTATUS_ABORTED_USER (0x1)
#define EXPERTSUBSTATUS_ABORTED_LOAD_FAIL (0x2)
#define EXPERTSUBSTATUS_ABORTED_THREAD_FAIL (0x4)
#define EXPERTSUBSTATUS_ABORTED_BAD_ENTRY (0x8)

  typedef struct __MIDL___MIDL_itf_netmon_0000_0017 {
    EXPERTSTATUSENUMERATION Status;
    DWORD SubStatus;
    DWORD PercentDone;
    DWORD Frame;
    char szStatusText[260];
  } EXPERTSTATUS;

  typedef EXPERTSTATUS *PEXPERTSTATUS;

#define EXPERT_STARTUP_FLAG_USE_STARTUP_DATA_OVER_CONFIG_DATA (0x1)
#define INVALID_FRAME_NUMBER ((DWORD)-1)
#define CAPTUREFILE_OPEN OPEN_EXISTING
#define CAPTUREFILE_CREATE CREATE_NEW

  LPSYSTEMTIME WINAPI GetCaptureTimeStamp(HCAPTURE hCapture);
  DWORD WINAPI GetCaptureMacType(HCAPTURE hCapture);
  DWORD WINAPI GetCaptureTotalFrames(HCAPTURE hCapture);
  LPSTR WINAPI GetCaptureComment(HCAPTURE hCapture);
  DWORD WINAPI MacTypeToAddressType(DWORD MacType);
  DWORD WINAPI AddressTypeToMacType(DWORD AddressType);
  DWORD WINAPI GetFrameDstAddressOffset(HFRAME hFrame,DWORD AddressType,LPDWORD AddressLength);
  DWORD WINAPI GetFrameSrcAddressOffset(HFRAME hFrame,DWORD AddressType,LPDWORD AddressLength);
  HCAPTURE WINAPI GetFrameCaptureHandle(HFRAME hFrame);
  DWORD WINAPI GetFrameDestAddress(HFRAME hFrame,LPADDRESS2 lpAddress,DWORD AddressType,DWORD Flags);
  DWORD WINAPI GetFrameSourceAddress(HFRAME hFrame,LPADDRESS2 lpAddress,DWORD AddressType,DWORD Flags);
  DWORD WINAPI GetFrameMacHeaderLength(HFRAME hFrame);
  WINBOOL WINAPI CompareFrameDestAddress(HFRAME hFrame,LPADDRESS2 lpAddress);
  WINBOOL WINAPI CompareFrameSourceAddress(HFRAME hFrame,LPADDRESS2 lpAddress);
  DWORD WINAPI GetFrameLength(HFRAME hFrame);
  DWORD WINAPI GetFrameStoredLength(HFRAME hFrame);
  DWORD WINAPI GetFrameMacType(HFRAME hFrame);
  DWORD WINAPI GetFrameMacHeaderLength(HFRAME hFrame);
  DWORD WINAPI GetFrameNumber(HFRAME hFrame);
  __MINGW_EXTENSION __int64 WINAPI GetFrameTimeStamp(HFRAME hFrame);
  ULPFRAME WINAPI GetFrameFromFrameHandle(HFRAME hFrame);
  __MINGW_EXTENSION HFRAME WINAPI ModifyFrame(HCAPTURE hCapture,DWORD FrameNumber,LPBYTE FrameData,DWORD FrameLength,__int64 TimeStamp);
  HFRAME WINAPI FindNextFrame(HFRAME hCurrentFrame,LPSTR ProtocolName,LPADDRESS2 lpDestAddress,LPADDRESS2 lpSrcAddress,LPWORD ProtocolOffset,DWORD OriginalFrameNumber,DWORD nHighestFrame);
  HFRAME WINAPI FindPreviousFrame(HFRAME hCurrentFrame,LPSTR ProtocolName,LPADDRESS2 lpDstAddress,LPADDRESS2 lpSrcAddress,LPWORD ProtocolOffset,DWORD OriginalFrameNumber,DWORD nLowestFrame);
  HCAPTURE WINAPI GetFrameCaptureHandle(HFRAME);
  HFRAME WINAPI GetFrame(HCAPTURE hCapture,DWORD FrameNumber);
  LPRECOGNIZEDATATABLE WINAPI GetFrameRecognizeData(HFRAME hFrame);
  HPROTOCOL WINAPI CreateProtocol(LPSTR ProtocolName,LPENTRYPOINTS lpEntryPoints,DWORD cbEntryPoints);
  VOID WINAPI DestroyProtocol(HPROTOCOL hProtocol);
  LPPROTOCOLINFO WINAPI GetProtocolInfo(HPROTOCOL hProtocol);
  HPROPERTY WINAPI GetProperty(HPROTOCOL hProtocol,LPSTR PropertyName);
  HPROTOCOL WINAPI GetProtocolFromName(LPSTR ProtocolName);
  DWORD WINAPI GetProtocolStartOffset(HFRAME hFrame,LPSTR ProtocolName);
  DWORD WINAPI GetProtocolStartOffsetHandle(HFRAME hFrame,HPROTOCOL hProtocol);
  DWORD WINAPI GetPreviousProtocolOffsetByName(HFRAME hFrame,DWORD dwStartOffset,LPSTR szProtocolName,DWORD *pdwPreviousOffset);
  LPPROTOCOLTABLE WINAPI GetEnabledProtocols(HCAPTURE hCapture);
  DWORD WINAPI CreatePropertyDatabase(HPROTOCOL hProtocol,DWORD nProperties);
  DWORD WINAPI DestroyPropertyDatabase(HPROTOCOL hProtocol);
  HPROPERTY WINAPI AddProperty(HPROTOCOL hProtocol,LPPROPERTYINFO PropertyInfo);
  WINBOOL WINAPI AttachPropertyInstance(HFRAME hFrame,HPROPERTY hProperty,DWORD Length,ULPVOID lpData,DWORD HelpID,DWORD Level,DWORD IFlags);
  WINBOOL WINAPI AttachPropertyInstanceEx(HFRAME hFrame,HPROPERTY hProperty,DWORD Length,ULPVOID lpData,DWORD ExLength,ULPVOID lpExData,DWORD HelpID,DWORD Level,DWORD IFlags);
  LPPROPERTYINST WINAPI FindPropertyInstance(HFRAME hFrame,HPROPERTY hProperty);
  LPPROPERTYINST WINAPI FindPropertyInstanceRestart (HFRAME hFrame,HPROPERTY hProperty,LPPROPERTYINST *lpRestartKey,WINBOOL DirForward);
  LPPROPERTYINFO WINAPI GetPropertyInfo(HPROPERTY hProperty);
  LPSTR WINAPI GetPropertyText(HFRAME hFrame,LPPROPERTYINST lpPI,LPSTR szBuffer,DWORD BufferSize);
  DWORD WINAPI ResetPropertyInstanceLength(LPPROPERTYINST lpProp,WORD nOrgLen,WORD nNewLen);
  DWORD WINAPI GetCaptureCommentFromFilename(LPSTR lpFilename,LPSTR lpComment,DWORD BufferSize);
  int WINAPI CompareAddresses(LPADDRESS2 lpAddress1,LPADDRESS2 lpAddress2);
  DWORD WINAPIV FormatPropertyInstance(LPPROPERTYINST lpPropertyInst,...);
  __MINGW_EXTENSION SYSTEMTIME *WINAPI AdjustSystemTime(SYSTEMTIME *SystemTime,__int64 TimeDelta);
  LPSTR WINAPI NMRtlIpv6AddressToStringA(const BYTE IP6Addr[],LPSTR S);
  LPWSTR WINAPI NMRtlIpv6AddressToStringW(const BYTE IP6Addr[],LPWSTR S);
  ULONG WINAPI NMRtlIpv6StringToAddressA(LPCSTR S,LPCSTR *Terminator,BYTE IP6Addr[]);
  ULONG WINAPI NMRtlIpv6StringToAddressW(LPCWSTR S,LPCWSTR *Terminator,BYTE IP6Addr[]);
  DWORD WINAPI ExpertGetFrame(HEXPERTKEY hExpertKey,DWORD Direction,DWORD RequestFlags,DWORD RequestedFrameNumber,HFILTER hFilter,LPEXPERTFRAMEDESCRIPTOR pEFrameDescriptor);
  LPVOID WINAPI ExpertAllocMemory(HEXPERTKEY hExpertKey,SIZE_T nBytes,DWORD *pError);
  LPVOID WINAPI ExpertReallocMemory(HEXPERTKEY hExpertKey,LPVOID pOriginalMemory,SIZE_T nBytes,DWORD *pError);
  DWORD WINAPI ExpertFreeMemory(HEXPERTKEY hExpertKey,LPVOID pOriginalMemory);
  SIZE_T WINAPI ExpertMemorySize(HEXPERTKEY hExpertKey,LPVOID pOriginalMemory);
  DWORD WINAPI ExpertIndicateStatus(HEXPERTKEY hExpertKey,EXPERTSTATUSENUMERATION Status,DWORD SubStatus,const char *szText,LONG PercentDone);
  DWORD WINAPI ExpertSubmitEvent(HEXPERTKEY hExpertKey,PNMEVENTDATA pExpertEvent);
  DWORD WINAPI ExpertGetStartupInfo(HEXPERTKEY hExpertKey,PEXPERTSTARTUPINFO pExpertStartupInfo);

#define INITIAL_RESTART_KEY (0xffffffff)

  DWORD __cdecl CreateBlob(HBLOB *phBlob);
  DWORD __cdecl DestroyBlob(HBLOB hBlob);
  DWORD __cdecl SetStringInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,const char *pString);
  DWORD __cdecl SetWStringInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,const WCHAR *pwString);
  DWORD __cdecl ConvertWStringToHexString(const WCHAR *pwsz,char **ppsz);
  DWORD __cdecl GetStringFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,const char **ppString);
  DWORD __cdecl ConvertHexStringToWString(CHAR *psz,WCHAR **ppwsz);
  DWORD __cdecl GetWStringFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,WCHAR **ppwString);
  DWORD __cdecl GetStringsFromBlob(HBLOB hBlob,const char *pRequestedOwnerName,const char *pRequestedCategoryName,const char *pRequestedTagName,const char **ppReturnedOwnerName,const char **ppReturnedCategoryName,const char **ppReturnedTagName,const char **ppReturnedString,DWORD *pRestartKey);
  DWORD __cdecl RemoveFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName);
  DWORD __cdecl LockBlob(HBLOB hBlob);
  DWORD __cdecl UnlockBlob(HBLOB hBlob);
  DWORD __cdecl FindUnknownBlobCategories(HBLOB hBlob,const char *pOwnerName,const char *pKnownCategoriesTable[],HBLOB hUnknownCategoriesBlob);
  DWORD __cdecl MergeBlob(HBLOB hDstBlob,HBLOB hSrcBlob);
  DWORD __cdecl DuplicateBlob (HBLOB hSrcBlob,HBLOB *hBlobThatWillBeCreated);
  DWORD __cdecl WriteBlobToFile(HBLOB hBlob,const char *pFileName);
  DWORD __cdecl ReadBlobFromFile(HBLOB *phBlob,const char *pFileName);
  DWORD __cdecl RegCreateBlobKey(HKEY hkey,const char *szBlobName,HBLOB hBlob);
  DWORD __cdecl RegOpenBlobKey(HKEY hkey,const char *szBlobName,HBLOB *phBlob);
  DWORD __cdecl MarshalBlob(HBLOB hBlob,DWORD *pSize,BYTE **ppBytes);
  DWORD __cdecl UnMarshalBlob(HBLOB *phBlob,DWORD Size,BYTE *pBytes);
  DWORD __cdecl SetDwordInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,DWORD Dword);
  DWORD __cdecl GetDwordFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,DWORD *pDword);
  DWORD __cdecl SetBoolInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,WINBOOL Bool);
  DWORD __cdecl GetBoolFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,WINBOOL *pBool);
  DWORD __cdecl GetMacAddressFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,BYTE *pMacAddress);
  DWORD __cdecl SetMacAddressInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,const BYTE *pMacAddress);
  DWORD __cdecl FindUnknownBlobTags(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pKnownTagsTable[],HBLOB hUnknownTagsBlob);
  DWORD __cdecl SetNetworkInfoInBlob(HBLOB hBlob,LPNETWORKINFO lpNetworkInfo);
  DWORD __cdecl GetNetworkInfoFromBlob(HBLOB hBlob,LPNETWORKINFO lpNetworkInfo);
  DWORD __cdecl CreateNPPInterface (HBLOB hBlob,REFIID iid,void **ppvObject);
  DWORD __cdecl SetClassIDInBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,const CLSID *pClsID);
  DWORD __cdecl GetClassIDFromBlob(HBLOB hBlob,const char *pOwnerName,const char *pCategoryName,const char *pTagName,CLSID *pClsID);
  DWORD __cdecl SetNPPPatternFilterInBlob(HBLOB hBlob,LPEXPRESSION pExpression,HBLOB hErrorBlob);
  DWORD __cdecl GetNPPPatternFilterFromBlob(HBLOB hBlob,LPEXPRESSION pExpression,HBLOB hErrorBlob);
  DWORD __cdecl SetNPPAddress2FilterInBlob(HBLOB hBlob,LPADDRESSTABLE2 pAddressTable);
  DWORD __cdecl GetNPPAddress2FilterFromBlob(HBLOB hBlob,LPADDRESSTABLE2 pAddressTable,HBLOB hErrorBlob);
  DWORD __cdecl SetNPPTriggerInBlob(HBLOB hBlob,LPTRIGGER pTrigger,HBLOB hErrorBlob);
  DWORD __cdecl GetNPPTriggerFromBlob(HBLOB hBlob,LPTRIGGER pTrigger,HBLOB hErrorBlob);
  DWORD __cdecl SetNPPEtypeSapFilter(HBLOB hBlob,WORD nSaps,WORD nEtypes,LPBYTE lpSapTable,LPWORD lpEtypeTable,DWORD FilterFlags,HBLOB hErrorBlob);
  DWORD __cdecl GetNPPEtypeSapFilter(HBLOB hBlob,WORD *pnSaps,WORD *pnEtypes,LPBYTE *ppSapTable,LPWORD *ppEtypeTable,DWORD *pFilterFlags,HBLOB hErrorBlob);
  DWORD __cdecl GetNPPMacTypeAsNumber(HBLOB hBlob,LPDWORD lpMacType);
  WINBOOL __cdecl IsRemoteNPP (HBLOB hBLOB);

#define OWNER_NPP "NPP"

#define CATEGORY_NETWORKINFO "NetworkInfo"
#define TAG_MACTYPE "MacType"
#define TAG_CURRENTADDRESS "CurrentAddress"
#define TAG_LINKSPEED "LinkSpeed"
#define TAG_MAXFRAMESIZE "MaxFrameSize"
#define TAG_FLAGS "Flags"
#define TAG_TIMESTAMPSCALEFACTOR "TimeStampScaleFactor"
#define TAG_COMMENT "Comment"
#define TAG_NODENAME "NodeName"
#define TAG_NAME "Name"
#define TAG_FAKENPP "Fake"
#define TAG_PROMISCUOUS_MODE "PMode"

#define CATEGORY_LOCATION "Location"
#define TAG_RAS "Dial-up Connection"
#define TAG_MACADDRESS "MacAddress"
#define TAG_CLASSID "ClassID"
#define TAG_NAME "Name"
#define TAG_CONNECTIONNAME "Connection Name"
#define TAG_FRIENDLYNAME "Friendly Name"

#define CATEGORY_CONFIG "Config"
#define TAG_FRAME_SIZE "FrameSize"
#define TAG_UPDATE_FREQUENCY "UpdateFreq"
#define TAG_BUFFER_SIZE "BufferSize"
#define TAG_PATTERN_DESIGNATOR "PatternMatch"
#define TAG_PATTERN "Pattern"
#define TAG_ADDRESS_PAIR "AddressPair"
#define TAG_CONNECTIONFLAGS "ConnectionFlags"
#define TAG_ETYPES "Etypes"
#define TAG_SAPS "Saps"
#define TAG_NO_CONVERSATION_STATS "NoConversationStats"
#define TAG_NO_STATS_FRAME "NoStatsFrame"
#define TAG_DONT_DELETE_EMPTY_CAPTURE "DontDeleteEmptyCapture"
#define TAG_WANT_PROTOCOL_INFO "WantProtocolInfo"
#define TAG_INTERFACE_DELAYED_CAPTURE "IDdC"
#define TAG_INTERFACE_REALTIME_CAPTURE "IRTC"
#define TAG_INTERFACE_STATS "ISts"
#define TAG_INTERFACE_TRANSMIT "IXmt"
#define TAG_LOCAL_ONLY "LocalOnly"

#define TAG_IS_REMOTE "IsRemote"

#define CATEGORY_TRIGGER "Trigger"
#define TAG_TRIGGER "Trigger"

#define CATEGORY_FINDER "Finder"
#define TAG_ROOT "Root"
#define TAG_PROCNAME "ProcName"
#define TAG_DISP_STRING "Display"
#define TAG_DLL_FILENAME "DLLName"
#define TAG_GET_SPECIAL_BLOBS "Specials"

#define CATEGORY_REMOTE "Remote"
#define TAG_REMOTECOMPUTER "RemoteComputer"
#define TAG_REMOTECLASSID "ClassID"

#define PROTOCOL_STRING_ETHERNET_TXT "ETHERNET"
#define PROTOCOL_STRING_TOKENRING_TXT "TOKENRING"
#define PROTOCOL_STRING_FDDI_TXT "FDDI"
#define PROTOCOL_STRING_ATM_TXT "ATM"
#define PROTOCOL_STRING_1394_TXT "IP/1394"

#define PROTOCOL_STRING_IP_TXT "IP"
#define PROTOCOL_STRING_IP6_TXT "IP6"
#define PROTOCOL_STRING_IPX_TXT "IPX"
#define PROTOCOL_STRING_XNS_TXT "XNS"
#define PROTOCOL_STRING_VINES_IP_TXT "VINES IP"

#define PROTOCOL_STRING_ICMP_TXT "ICMP"
#define PROTOCOL_STRING_TCP_TXT "TCP"
#define PROTOCOL_STRING_UDP_TXT "UDP"
#define PROTOCOL_STRING_SPX_TXT "SPX"
#define PROTOCOL_STRING_NCP_TXT "NCP"

#define PROTOCOL_STRING_ANY_TXT "ANY"
#define PROTOCOL_STRING_ANY_GROUP_TXT "ANY GROUP"
#define PROTOCOL_STRING_HIGHEST_TXT "HIGHEST"
#define PROTOCOL_STRING_LOCAL_ONLY_TXT "LOCAL ONLY"
#define PROTOCOL_STRING_UNKNOWN_TXT "UNKNOWN"
#define PROTOCOL_STRING_DATA_TXT "DATA"
#define PROTOCOL_STRING_FRAME_TXT "FRAME"
#define PROTOCOL_STRING_NONE_TXT "NONE"
#define PROTOCOL_STRING_EFFECTIVE_TXT "EFFECTIVE"

#define ADDRESS_PAIR_INCLUDE_TXT "INCLUDE"
#define ADDRESS_PAIR_EXCLUDE_TXT "EXCLUDE"

#define INCLUDE_ALL_EXCEPT_TXT "INCLUDE ALL EXCEPT"
#define EXCLUDE_ALL_EXCEPT_TXT "EXCLUDE ALL EXCEPT"

#define PATTERN_MATCH_OR_TXT "OR("
#define PATTERN_MATCH_AND_TXT "AND("

#define TRIGGER_PATTERN_TXT "PATTERN MATCH"
#define TRIGGER_BUFFER_TXT "BUFFER CONTENT"

#define TRIGGER_NOTIFY_TXT "NOTIFY"
#define TRIGGER_STOP_TXT "STOP"
#define TRIGGER_PAUSE_TXT "PAUSE"

#define TRIGGER_25_PERCENT_TXT "25 PERCENT"
#define TRIGGER_50_PERCENT_TXT "50 PERCENT"
#define TRIGGER_75_PERCENT_TXT "75 PERCENT"
#define TRIGGER_100_PERCENT_TXT "100 PERCENT"

#define PATTERN_MATCH_NOT_TXT "NOT"

  LPCSTR __cdecl FindOneOf(LPCSTR p1,LPCSTR p2);
  LONG __cdecl recursiveDeleteKey(HKEY hKeyParent,const char *lpszKeyChild);
  WINBOOL __cdecl SubkeyExists(const char *pszPath,const char *szSubkey);
  WINBOOL __cdecl setKeyAndValue(const char *szKey,const char *szSubkey,const char *szValue,const char *szName);

#pragma pack(push,1)

  typedef struct _IP {
    __C89_NAMELESS union {
      BYTE Version;
      BYTE HdrLen;
    };
    BYTE ServiceType;
    WORD TotalLen;
    WORD ID;
    __C89_NAMELESS union {
      WORD Flags;
      WORD FragOff;
    };
    BYTE TimeToLive;
    BYTE Protocol;
    WORD HdrChksum;
    DWORD SrcAddr;
    DWORD DstAddr;
    BYTE Options[0];
  } IP;

  typedef IP *LPIP;
  typedef IP UNALIGNED *ULPIP;

  typedef struct _PSUHDR {
    DWORD ph_SrcIP;
    DWORD ph_DstIP;
    UCHAR ph_Zero;
    UCHAR ph_Proto;
    WORD ph_ProtLen;
  } PSUHDR;

  typedef PSUHDR UNALIGNED *LPPSUHDR;

#define IP_VERSION_MASK ((BYTE) 0xf0)
#define IP_VERSION_SHIFT (4)
#define IP_HDRLEN_MASK ((BYTE) 0x0f)
#define IP_HDRLEN_SHIFT (0)
#define IP_PRECEDENCE_MASK ((BYTE) 0xE0)
#define IP_PRECEDENCE_SHIFT (5)
#define IP_TOS_MASK ((BYTE) 0x1E)
#define IP_TOS_SHIFT (1)
#define IP_DELAY_MASK ((BYTE) 0x10)
#define IP_THROUGHPUT_MASK ((BYTE) 0x08)
#define IP_RELIABILITY_MASK ((BYTE) 0x04)
#define IP_FLAGS_MASK ((BYTE) 0xE0)
#define IP_FLAGS_SHIFT (13)
#define IP_DF_MASK ((BYTE) 0x40)
#define IP_MF_MASK ((BYTE) 0x20)
#define IP_MF_SHIFT (5)
#define IP_FRAGOFF_MASK ((WORD) 0x1FFF)
#define IP_FRAGOFF_SHIFT (3)
#define IP_TCC_MASK ((DWORD) 0xFFFFFF00)
#define IP_TIME_OPTS_MASK ((BYTE) 0x0F)
#define IP_MISS_STNS_MASK ((BYTE) 0xF0)

#define IP_TIME_OPTS_SHIFT (0)
#define IP_MISS_STNS_SHIFT (4)

#define IP_CHKSUM_OFF 10

#ifndef __CRT__NO_INLINE
  INLINE BYTE IP_Version(ULPIP pIP) { return (pIP->Version & IP_VERSION_MASK) >> IP_VERSION_SHIFT; }
  INLINE DWORD IP_HdrLen(ULPIP pIP) { return ((pIP->HdrLen & IP_HDRLEN_MASK) >> IP_HDRLEN_SHIFT) << 2; }
  INLINE WORD IP_FragOff(ULPIP pIP) { return (XCHG(pIP->FragOff) & IP_FRAGOFF_MASK) << IP_FRAGOFF_SHIFT; }
  INLINE DWORD IP_TotalLen(ULPIP pIP) { return XCHG(pIP->TotalLen); }
  INLINE DWORD IP_MoreFragments(ULPIP pIP) { return (pIP->Flags & IP_MF_MASK) >> IP_MF_SHIFT; }
#endif

#define PORT_TCPMUX 1
#define PORT_RJE 5
#define PORT_ECHO 7
#define PORT_DISCARD 9
#define PORT_USERS 11
#define PORT_DAYTIME 13
#define PORT_NETSTAT 15
#define PORT_QUOTE 17
#define PORT_CHARGEN 19
#define PORT_FTPDATA 20
#define PORT_FTP 21
#define PORT_TELNET 23
#define PORT_SMTP 25
#define PORT_NSWFE 27
#define PORT_MSGICP 29
#define PORT_MSGAUTH 31
#define PORT_DSP 33
#define PORT_PRTSERVER 35
#define PORT_TIME 37
#define PORT_RLP 39
#define PORT_GRAPHICS 41
#define PORT_NAMESERVER 42
#define PORT_NICNAME 43
#define PORT_MPMFLAGS 44
#define PORT_MPM 45
#define PORT_MPMSND 46
#define PORT_NIFTP 47
#define PORT_LOGIN 49
#define PORT_LAMAINT 51
#define PORT_DOMAIN 53
#define PORT_ISIGL 55
#define PORT_ANYTERMACC 57
#define PORT_ANYFILESYS 59
#define PORT_NIMAIL 61
#define PORT_VIAFTP 63
#define PORT_TACACSDS 65
#define PORT_BOOTPS 67
#define PORT_BOOTPC 68
#define PORT_TFTP 69
#define PORT_NETRJS1 71
#define PORT_NETRJS2 72
#define PORT_NETRJS3 73
#define PORT_NETRJS4 74
#define PORT_ANYDIALOUT 75
#define PORT_ANYRJE 77
#define PORT_FINGER 79
#define PORT_HTTP 80
#define PORT_HOSTS2NS 81
#define PORT_MITMLDEV1 83
#define PORT_MITMLDEV2 85
#define PORT_ANYTERMLINK 87
#define PORT_SUMITTG 89
#define PORT_MITDOV 91
#define PORT_DCP 93
#define PORT_SUPDUP 95
#define PORT_SWIFTRVF 97
#define PORT_TACNEWS 98
#define PORT_METAGRAM 99
#define PORT_NEWACCT 100
#define PORT_HOSTNAME 101
#define PORT_ISOTSAP 102
#define PORT_X400 103
#define PORT_X400SND 104
#define PORT_CSNETNS 105
#define PORT_RTELNET 107
#define PORT_POP2 109
#define PORT_POP3 110
#define PORT_SUNRPC 111
#define PORT_AUTH 113
#define PORT_SFTP 115
#define PORT_UUCPPATH 117
#define PORT_NNTP 119
#define PORT_ERPC 121
#define PORT_NTP 123
#define PORT_LOCUSMAP 125
#define PORT_LOCUSCON 127
#define PORT_PWDGEN 129
#define PORT_CISCOFNA 130
#define PORT_CISCOTNA 131
#define PORT_CISCOSYS 132
#define PORT_STATSRV 133
#define PORT_INGRESNET 134
#define PORT_LOCSRV 135
#define PORT_PROFILE 136
#define PORT_NETBIOSNS 137
#define PORT_NETBIOSDGM 138
#define PORT_NETBIOSSSN 139
#define PORT_EMFISDATA 140
#define PORT_EMFISCNTL 141
#define PORT_BLIDM 142
#define PORT_IMAP2 143
#define PORT_NEWS 144
#define PORT_UAAC 145
#define PORT_ISOTP0 146
#define PORT_ISOIP 147
#define PORT_CRONUS 148
#define PORT_AED512 149
#define PORT_SQLNET 150
#define PORT_HEMS 151
#define PORT_BFTP 152
#define PORT_SGMP 153
#define PORT_NETSCPROD 154
#define PORT_NETSCDEV 155
#define PORT_SQLSRV 156
#define PORT_KNETCMP 157
#define PORT_PCMAILSRV 158
#define PORT_NSSROUTING 159
#define PORT_SGMPTRAPS 160
#define PORT_SNMP 161
#define PORT_SNMPTRAP 162
#define PORT_CMIPMANAGE 163
#define PORT_CMIPAGENT 164
#define PORT_XNSCOURIER 165
#define PORT_SNET 166
#define PORT_NAMP 167
#define PORT_RSVD 168
#define PORT_SEND 169
#define PORT_PRINTSRV 170
#define PORT_MULTIPLEX 171
#define PORT_CL1 172
#define PORT_XYPLEXMUX 173
#define PORT_MAILQ 174
#define PORT_VMNET 175
#define PORT_GENRADMUX 176
#define PORT_XDMCP 177
#define PORT_NEXTSTEP 178
#define PORT_BGP 179
#define PORT_RIS 180
#define PORT_UNIFY 181
#define PORT_UNISYSCAM 182
#define PORT_OCBINDER 183
#define PORT_OCSERVER 184
#define PORT_REMOTEKIS 185
#define PORT_KIS 186
#define PORT_ACI 187
#define PORT_MUMPS 188
#define PORT_QFT 189
#define PORT_GACP 190
#define PORT_PROSPERO 191
#define PORT_OSUNMS 192
#define PORT_SRMP 193
#define PORT_IRC 194
#define PORT_DN6NLMAUD 195
#define PORT_DN6SMMRED 196
#define PORT_DLS 197
#define PORT_DLSMON 198
#define PORT_ATRMTP 201
#define PORT_ATNBP 202
#define PORT_AT3 203
#define PORT_ATECHO 204
#define PORT_AT5 205
#define PORT_ATZIS 206
#define PORT_AT7 207
#define PORT_AT8 208
#define PORT_SURMEAS 243
#define PORT_LINK 245
#define PORT_DSP3270 246
#define PORT_LDAP1 389
#define PORT_ISAKMP 500
#define PORT_REXEC 512
#define PORT_RLOGIN 513
#define PORT_RSH 514
#define PORT_LPD 515
#define PORT_RIP 520
#define PORT_TEMPO 526
#define PORT_COURIER 530
#define PORT_NETNEWS 532
#define PORT_UUCPD 540
#define PORT_KLOGIN 543
#define PORT_KSHELL 544
#define PORT_DSF 555
#define PORT_REMOTEEFS 556
#define PORT_CHSHELL 562
#define PORT_METER 570
#define PORT_PCSERVER 600
#define PORT_NQS 607
#define PORT_HMMP_INDICATION 612
#define PORT_HMMP_OPERATION 613
#define PORT_MDQS 666
#define PORT_LPD721 721
#define PORT_LPD722 722
#define PORT_LPD723 723
#define PORT_LPD724 724
#define PORT_LPD725 725
#define PORT_LPD726 726
#define PORT_LPD727 727
#define PORT_LPD728 728
#define PORT_LPD729 729
#define PORT_LPD730 730
#define PORT_LPD731 731
#define PORT_RFILE 750
#define PORT_PUMP 751
#define PORT_QRH 752
#define PORT_RRH 753
#define PORT_TELL 754
#define PORT_NLOGIN 758
#define PORT_CON 759
#define PORT_NS 760
#define PORT_RXE 761
#define PORT_QUOTAD 762
#define PORT_CYCLESERV 763
#define PORT_OMSERV 764
#define PORT_WEBSTER 765
#define PORT_PHONEBOOK 767
#define PORT_VID 769
#define PORT_RTIP 771
#define PORT_CYCLESERV2 772
#define PORT_SUBMIT 773
#define PORT_RPASSWD 774
#define PORT_ENTOMB 775
#define PORT_WPAGES 776
#define PORT_WPGS 780
#define PORT_MDBSDAEMON 800
#define PORT_DEVICE 801
#define PORT_MAITRD 997
#define PORT_BUSBOY 998
#define PORT_GARCON 999
#define PORT_NFS 2049
#define PORT_LDAP2 3268
#define PORT_PPTP 5678

  typedef struct _RequestReplyFields {
    WORD ID;
    WORD SeqNo;
  } ReqReply;

  typedef struct _ParameterProblemFields {
    BYTE Pointer;
    BYTE junk[3];
  } ParmProb;

  typedef struct _TimestampFields {
    DWORD tsOrig;
    DWORD tsRecv;
    DWORD tsXmit;
  } TS;

  typedef struct _RouterAnnounceHeaderFields {
    BYTE NumAddrs;
    BYTE AddrEntrySize;
    WORD Lifetime;
  } RouterAH;

  typedef struct _RouterAnnounceEntry {
    DWORD Address;
    DWORD PreferenceLevel;
  } RouterAE;

  typedef struct _ICMP {
    BYTE Type;
    BYTE Code;
    WORD Checksum;
    __C89_NAMELESS union {
      DWORD Unused;
      DWORD Address;
      ReqReply RR;
      ParmProb PP;
      RouterAH RAH;
    };
    __C89_NAMELESS union {
      TS Time;
      IP IP;
      RouterAE RAE[0];
    };
  } ICMP;

  typedef ICMP *LPICMP;
  typedef ICMP UNALIGNED *ULPICMP;
#define ICMP_HEADER_LENGTH (8)

#define ICMP_IP_DATA_LENGTH (8)

#define ECHO_REPLY (0)
#define DESTINATION_UNREACHABLE (3)
#define SOURCE_QUENCH (4)
#define REDIRECT (5)
#define ECHO (8)
#define ROUTER_ADVERTISEMENT (9)
#define ROUTER_SOLICITATION (10)
#define TIME_EXCEEDED (11)
#define PARAMETER_PROBLEM (12)
#define TIMESTAMP (13)
#define TIMESTAMP_REPLY (14)
#define INFORMATION_REQUEST (15)
#define INFORMATION_REPLY (16)
#define ADDRESS_MASK_REQUEST (17)
#define ADDRESS_MASK_REPLY (18)

  typedef struct __MIDL___MIDL_itf_netmon_0000_0018 {
    UCHAR ha_address[6];
  } HOST_ADDRESS;

  typedef struct _IPXADDRESS {
    ULONG ipx_NetNumber;
    HOST_ADDRESS ipx_HostAddr;
  } IPXADDRESS;

  typedef IPXADDRESS UNALIGNED *PIPXADDRESS;

  typedef struct _NET_ADDRESS {
    IPXADDRESS na_IPXAddr;
    USHORT na_socket;
  } NET_ADDRESS;

  typedef NET_ADDRESS UNALIGNED *UPNET_ADDRESS;

  typedef struct __MIDL___MIDL_itf_netmon_0000_0019 {
    USHORT ipx_checksum;
    USHORT ipx_length;
    UCHAR ipx_xport_control;
    UCHAR ipx_packet_type;
    NET_ADDRESS ipx_dest;
    NET_ADDRESS ipx_source;
  } IPX_HDR;

  typedef IPX_HDR UNALIGNED *ULPIPX_HDR;

  typedef struct _SPX_HDR {
    IPX_HDR spx_idp_hdr;
    UCHAR spx_conn_ctrl;
    UCHAR spx_data_type;
    USHORT spx_src_conn_id;
    USHORT spx_dest_conn_id;
    USHORT spx_sequence_num;
    USHORT spx_ack_num;
    USHORT spx_alloc_num;
  } SPX_HDR;

  typedef SPX_HDR UNALIGNED *PSPX_HDR;

  typedef struct _TCP {
    WORD SrcPort;
    WORD DstPort;
    DWORD SeqNum;
    DWORD AckNum;
    BYTE DataOff;
    BYTE Flags;
    WORD Window;
    WORD Chksum;
    WORD UrgPtr;
  } TCP;

  typedef TCP *LPTCP;

  typedef TCP UNALIGNED *ULPTCP;

#ifndef __CRT__NO_INLINE
  INLINE DWORD TCP_HdrLen(ULPTCP pTCP) { return (pTCP->DataOff & 0xf0) >> 2; }
  INLINE DWORD TCP_SrcPort(ULPTCP pTCP) { return XCHG(pTCP->SrcPort); }
  INLINE DWORD TCP_DstPort(ULPTCP pTCP) { return XCHG(pTCP->DstPort); }
#endif

#define TCP_OPTION_ENDOFOPTIONS (0)
#define TCP_OPTION_NOP (1)
#define TCP_OPTION_MAXSEGSIZE (2)
#define TCP_OPTION_WSCALE (3)
#define TCP_OPTION_SACK_PERMITTED (4)
#define TCP_OPTION_SACK (5)
#define TCP_OPTION_TIMESTAMPS (8)

#define TCP_FLAG_URGENT (0x20)
#define TCP_FLAG_ACK (0x10)
#define TCP_FLAG_PUSH (0x8)
#define TCP_FLAG_RESET (0x4)
#define TCP_FLAG_SYN (0x2)
#define TCP_FLAG_FIN (0x1)
#define TCP_RESERVED_MASK (0xfc0)

#pragma pack(pop)

#define DEFAULT_DELAYED_BUFFER_SIZE (1)
#define USE_DEFAULT_DRIVE_LETTER (0)
#define RTC_FRAME_SIZE_FULL (0)

  extern RPC_IF_HANDLE __MIDL_itf_netmon_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netmon_0000_v0_0_s_ifspec;

#ifndef __IDelaydC_INTERFACE_DEFINED__
#define __IDelaydC_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDelaydC;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDelaydC : public IUnknown {
  public:
    virtual HRESULT WINAPI Connect(HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Disconnect(void) = 0;
    virtual HRESULT WINAPI QueryStatus(NETWORKSTATUS *pNetworkStatus) = 0;
    virtual HRESULT WINAPI Configure(HBLOB hConfigurationBlob,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Start(char *pFileName) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI Resume(void) = 0;
    virtual HRESULT WINAPI Stop(LPSTATISTICS lpStats) = 0;
    virtual HRESULT WINAPI GetControlState(WINBOOL *IsRunnning,WINBOOL *IsPaused) = 0;
    virtual HRESULT WINAPI GetTotalStatistics(LPSTATISTICS lpStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI GetConversationStatistics(DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI InsertSpecialFrame(DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength) = 0;
    virtual HRESULT WINAPI QueryStations(QUERYTABLE *lpQueryTable) = 0;
  };
#else
  typedef struct IDelaydCVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDelaydC *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDelaydC *This);
      ULONG (WINAPI *Release)(IDelaydC *This);
      HRESULT (WINAPI *Connect)(IDelaydC *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
      HRESULT (WINAPI *Disconnect)(IDelaydC *This);
      HRESULT (WINAPI *QueryStatus)(IDelaydC *This,NETWORKSTATUS *pNetworkStatus);
      HRESULT (WINAPI *Configure)(IDelaydC *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
      HRESULT (WINAPI *Start)(IDelaydC *This,char *pFileName);
      HRESULT (WINAPI *Pause)(IDelaydC *This);
      HRESULT (WINAPI *Resume)(IDelaydC *This);
      HRESULT (WINAPI *Stop)(IDelaydC *This,LPSTATISTICS lpStats);
      HRESULT (WINAPI *GetControlState)(IDelaydC *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
      HRESULT (WINAPI *GetTotalStatistics)(IDelaydC *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *GetConversationStatistics)(IDelaydC *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *InsertSpecialFrame)(IDelaydC *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
      HRESULT (WINAPI *QueryStations)(IDelaydC *This,QUERYTABLE *lpQueryTable);
    END_INTERFACE
  } IDelaydCVtbl;
  struct IDelaydC {
    CONST_VTBL struct IDelaydCVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDelaydC_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDelaydC_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDelaydC_Release(This) (This)->lpVtbl->Release(This)
#define IDelaydC_Connect(This,hInputBlob,StatusCallbackProc,UserContext,hErrorBlob) (This)->lpVtbl->Connect(This,hInputBlob,StatusCallbackProc,UserContext,hErrorBlob)
#define IDelaydC_Disconnect(This) (This)->lpVtbl->Disconnect(This)
#define IDelaydC_QueryStatus(This,pNetworkStatus) (This)->lpVtbl->QueryStatus(This,pNetworkStatus)
#define IDelaydC_Configure(This,hConfigurationBlob,hErrorBlob) (This)->lpVtbl->Configure(This,hConfigurationBlob,hErrorBlob)
#define IDelaydC_Start(This,pFileName) (This)->lpVtbl->Start(This,pFileName)
#define IDelaydC_Pause(This) (This)->lpVtbl->Pause(This)
#define IDelaydC_Resume(This) (This)->lpVtbl->Resume(This)
#define IDelaydC_Stop(This,lpStats) (This)->lpVtbl->Stop(This,lpStats)
#define IDelaydC_GetControlState(This,IsRunnning,IsPaused) (This)->lpVtbl->GetControlState(This,IsRunnning,IsPaused)
#define IDelaydC_GetTotalStatistics(This,lpStats,fClearAfterReading) (This)->lpVtbl->GetTotalStatistics(This,lpStats,fClearAfterReading)
#define IDelaydC_GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading) (This)->lpVtbl->GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading)
#define IDelaydC_InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength) (This)->lpVtbl->InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength)
#define IDelaydC_QueryStations(This,lpQueryTable) (This)->lpVtbl->QueryStations(This,lpQueryTable)
#endif
#endif
  HRESULT WINAPI IDelaydC_Connect_Proxy(IDelaydC *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
  void __RPC_STUB IDelaydC_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Disconnect_Proxy(IDelaydC *This);
  void __RPC_STUB IDelaydC_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_QueryStatus_Proxy(IDelaydC *This,NETWORKSTATUS *pNetworkStatus);
  void __RPC_STUB IDelaydC_QueryStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Configure_Proxy(IDelaydC *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
  void __RPC_STUB IDelaydC_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Start_Proxy(IDelaydC *This,char *pFileName);
  void __RPC_STUB IDelaydC_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Pause_Proxy(IDelaydC *This);
  void __RPC_STUB IDelaydC_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Resume_Proxy(IDelaydC *This);
  void __RPC_STUB IDelaydC_Resume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_Stop_Proxy(IDelaydC *This,LPSTATISTICS lpStats);
  void __RPC_STUB IDelaydC_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_GetControlState_Proxy(IDelaydC *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
  void __RPC_STUB IDelaydC_GetControlState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_GetTotalStatistics_Proxy(IDelaydC *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IDelaydC_GetTotalStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_GetConversationStatistics_Proxy(IDelaydC *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IDelaydC_GetConversationStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_InsertSpecialFrame_Proxy(IDelaydC *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
  void __RPC_STUB IDelaydC_InsertSpecialFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDelaydC_QueryStations_Proxy(IDelaydC *This,QUERYTABLE *lpQueryTable);
  void __RPC_STUB IDelaydC_QueryStations_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define DEFAULT_RTC_BUFFER_SIZE (0x100000)

  extern RPC_IF_HANDLE __MIDL_itf_netmon_0010_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netmon_0010_v0_0_s_ifspec;

#ifndef __IRTC_INTERFACE_DEFINED__
#define __IRTC_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRTC;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRTC : public IUnknown {
  public:
    virtual HRESULT WINAPI Connect(HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID FramesCallbackProc,LPVOID UserContext,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Disconnect(void) = 0;
    virtual HRESULT WINAPI QueryStatus(NETWORKSTATUS *pNetworkStatus) = 0;
    virtual HRESULT WINAPI Configure(HBLOB hConfigurationBlob,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Start(void) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI Resume(void) = 0;
    virtual HRESULT WINAPI Stop(void) = 0;
    virtual HRESULT WINAPI GetControlState(WINBOOL *IsRunnning,WINBOOL *IsPaused) = 0;
    virtual HRESULT WINAPI GetTotalStatistics(LPSTATISTICS lpStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI GetConversationStatistics(DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI InsertSpecialFrame(DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength) = 0;
    virtual HRESULT WINAPI QueryStations(QUERYTABLE *lpQueryTable) = 0;
  };
#else
  typedef struct IRTCVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRTC *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRTC *This);
      ULONG (WINAPI *Release)(IRTC *This);
      HRESULT (WINAPI *Connect)(IRTC *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID FramesCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
      HRESULT (WINAPI *Disconnect)(IRTC *This);
      HRESULT (WINAPI *QueryStatus)(IRTC *This,NETWORKSTATUS *pNetworkStatus);
      HRESULT (WINAPI *Configure)(IRTC *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
      HRESULT (WINAPI *Start)(IRTC *This);
      HRESULT (WINAPI *Pause)(IRTC *This);
      HRESULT (WINAPI *Resume)(IRTC *This);
      HRESULT (WINAPI *Stop)(IRTC *This);
      HRESULT (WINAPI *GetControlState)(IRTC *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
      HRESULT (WINAPI *GetTotalStatistics)(IRTC *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *GetConversationStatistics)(IRTC *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *InsertSpecialFrame)(IRTC *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
      HRESULT (WINAPI *QueryStations)(IRTC *This,QUERYTABLE *lpQueryTable);
    END_INTERFACE
  } IRTCVtbl;
  struct IRTC {
    CONST_VTBL struct IRTCVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRTC_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRTC_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRTC_Release(This) (This)->lpVtbl->Release(This)
#define IRTC_Connect(This,hInputBlob,StatusCallbackProc,FramesCallbackProc,UserContext,hErrorBlob) (This)->lpVtbl->Connect(This,hInputBlob,StatusCallbackProc,FramesCallbackProc,UserContext,hErrorBlob)
#define IRTC_Disconnect(This) (This)->lpVtbl->Disconnect(This)
#define IRTC_QueryStatus(This,pNetworkStatus) (This)->lpVtbl->QueryStatus(This,pNetworkStatus)
#define IRTC_Configure(This,hConfigurationBlob,hErrorBlob) (This)->lpVtbl->Configure(This,hConfigurationBlob,hErrorBlob)
#define IRTC_Start(This) (This)->lpVtbl->Start(This)
#define IRTC_Pause(This) (This)->lpVtbl->Pause(This)
#define IRTC_Resume(This) (This)->lpVtbl->Resume(This)
#define IRTC_Stop(This) (This)->lpVtbl->Stop(This)
#define IRTC_GetControlState(This,IsRunnning,IsPaused) (This)->lpVtbl->GetControlState(This,IsRunnning,IsPaused)
#define IRTC_GetTotalStatistics(This,lpStats,fClearAfterReading) (This)->lpVtbl->GetTotalStatistics(This,lpStats,fClearAfterReading)
#define IRTC_GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading) (This)->lpVtbl->GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading)
#define IRTC_InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength) (This)->lpVtbl->InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength)
#define IRTC_QueryStations(This,lpQueryTable) (This)->lpVtbl->QueryStations(This,lpQueryTable)
#endif
#endif
  HRESULT WINAPI IRTC_Connect_Proxy(IRTC *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID FramesCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
  void __RPC_STUB IRTC_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Disconnect_Proxy(IRTC *This);
  void __RPC_STUB IRTC_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_QueryStatus_Proxy(IRTC *This,NETWORKSTATUS *pNetworkStatus);
  void __RPC_STUB IRTC_QueryStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Configure_Proxy(IRTC *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
  void __RPC_STUB IRTC_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Start_Proxy(IRTC *This);
  void __RPC_STUB IRTC_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Pause_Proxy(IRTC *This);
  void __RPC_STUB IRTC_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Resume_Proxy(IRTC *This);
  void __RPC_STUB IRTC_Resume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_Stop_Proxy(IRTC *This);
  void __RPC_STUB IRTC_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_GetControlState_Proxy(IRTC *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
  void __RPC_STUB IRTC_GetControlState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_GetTotalStatistics_Proxy(IRTC *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IRTC_GetTotalStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_GetConversationStatistics_Proxy(IRTC *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IRTC_GetConversationStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_InsertSpecialFrame_Proxy(IRTC *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
  void __RPC_STUB IRTC_InsertSpecialFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRTC_QueryStations_Proxy(IRTC *This,QUERYTABLE *lpQueryTable);
  void __RPC_STUB IRTC_QueryStations_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_netmon_0012_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netmon_0012_v0_0_s_ifspec;

#ifndef __IStats_INTERFACE_DEFINED__
#define __IStats_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IStats;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IStats : public IUnknown {
  public:
    virtual HRESULT WINAPI Connect(HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Disconnect(void) = 0;
    virtual HRESULT WINAPI QueryStatus(NETWORKSTATUS *pNetworkStatus) = 0;
    virtual HRESULT WINAPI Configure(HBLOB hConfigurationBlob,HBLOB hErrorBlob) = 0;
    virtual HRESULT WINAPI Start(void) = 0;
    virtual HRESULT WINAPI Pause(void) = 0;
    virtual HRESULT WINAPI Resume(void) = 0;
    virtual HRESULT WINAPI Stop(void) = 0;
    virtual HRESULT WINAPI GetControlState(WINBOOL *IsRunnning,WINBOOL *IsPaused) = 0;
    virtual HRESULT WINAPI GetTotalStatistics(LPSTATISTICS lpStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI GetConversationStatistics(DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading) = 0;
    virtual HRESULT WINAPI InsertSpecialFrame(DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength) = 0;
    virtual HRESULT WINAPI QueryStations(QUERYTABLE *lpQueryTable) = 0;
  };
#else
  typedef struct IStatsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IStats *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IStats *This);
      ULONG (WINAPI *Release)(IStats *This);
      HRESULT (WINAPI *Connect)(IStats *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
      HRESULT (WINAPI *Disconnect)(IStats *This);
      HRESULT (WINAPI *QueryStatus)(IStats *This,NETWORKSTATUS *pNetworkStatus);
      HRESULT (WINAPI *Configure)(IStats *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
      HRESULT (WINAPI *Start)(IStats *This);
      HRESULT (WINAPI *Pause)(IStats *This);
      HRESULT (WINAPI *Resume)(IStats *This);
      HRESULT (WINAPI *Stop)(IStats *This);
      HRESULT (WINAPI *GetControlState)(IStats *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
      HRESULT (WINAPI *GetTotalStatistics)(IStats *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *GetConversationStatistics)(IStats *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
      HRESULT (WINAPI *InsertSpecialFrame)(IStats *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
      HRESULT (WINAPI *QueryStations)(IStats *This,QUERYTABLE *lpQueryTable);
    END_INTERFACE
  } IStatsVtbl;
  struct IStats {
    CONST_VTBL struct IStatsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IStats_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IStats_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IStats_Release(This) (This)->lpVtbl->Release(This)
#define IStats_Connect(This,hInputBlob,StatusCallbackProc,UserContext,hErrorBlob) (This)->lpVtbl->Connect(This,hInputBlob,StatusCallbackProc,UserContext,hErrorBlob)
#define IStats_Disconnect(This) (This)->lpVtbl->Disconnect(This)
#define IStats_QueryStatus(This,pNetworkStatus) (This)->lpVtbl->QueryStatus(This,pNetworkStatus)
#define IStats_Configure(This,hConfigurationBlob,hErrorBlob) (This)->lpVtbl->Configure(This,hConfigurationBlob,hErrorBlob)
#define IStats_Start(This) (This)->lpVtbl->Start(This)
#define IStats_Pause(This) (This)->lpVtbl->Pause(This)
#define IStats_Resume(This) (This)->lpVtbl->Resume(This)
#define IStats_Stop(This) (This)->lpVtbl->Stop(This)
#define IStats_GetControlState(This,IsRunnning,IsPaused) (This)->lpVtbl->GetControlState(This,IsRunnning,IsPaused)
#define IStats_GetTotalStatistics(This,lpStats,fClearAfterReading) (This)->lpVtbl->GetTotalStatistics(This,lpStats,fClearAfterReading)
#define IStats_GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading) (This)->lpVtbl->GetConversationStatistics(This,nSessions,lpSessionStats,nStations,lpStationStats,fClearAfterReading)
#define IStats_InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength) (This)->lpVtbl->InsertSpecialFrame(This,FrameType,Flags,pUserData,UserDataLength)
#define IStats_QueryStations(This,lpQueryTable) (This)->lpVtbl->QueryStations(This,lpQueryTable)
#endif
#endif
  HRESULT WINAPI IStats_Connect_Proxy(IStats *This,HBLOB hInputBlob,LPVOID StatusCallbackProc,LPVOID UserContext,HBLOB hErrorBlob);
  void __RPC_STUB IStats_Connect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Disconnect_Proxy(IStats *This);
  void __RPC_STUB IStats_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_QueryStatus_Proxy(IStats *This,NETWORKSTATUS *pNetworkStatus);
  void __RPC_STUB IStats_QueryStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Configure_Proxy(IStats *This,HBLOB hConfigurationBlob,HBLOB hErrorBlob);
  void __RPC_STUB IStats_Configure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Start_Proxy(IStats *This);
  void __RPC_STUB IStats_Start_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Pause_Proxy(IStats *This);
  void __RPC_STUB IStats_Pause_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Resume_Proxy(IStats *This);
  void __RPC_STUB IStats_Resume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_Stop_Proxy(IStats *This);
  void __RPC_STUB IStats_Stop_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_GetControlState_Proxy(IStats *This,WINBOOL *IsRunnning,WINBOOL *IsPaused);
  void __RPC_STUB IStats_GetControlState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_GetTotalStatistics_Proxy(IStats *This,LPSTATISTICS lpStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IStats_GetTotalStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_GetConversationStatistics_Proxy(IStats *This,DWORD *nSessions,LPSESSIONSTATS lpSessionStats,DWORD *nStations,LPSTATIONSTATS lpStationStats,WINBOOL fClearAfterReading);
  void __RPC_STUB IStats_GetConversationStatistics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_InsertSpecialFrame_Proxy(IStats *This,DWORD FrameType,DWORD Flags,BYTE *pUserData,DWORD UserDataLength);
  void __RPC_STUB IStats_InsertSpecialFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStats_QueryStations_Proxy(IStats *This,QUERYTABLE *lpQueryTable);
  void __RPC_STUB IStats_QueryStations_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#pragma pack()

  extern RPC_IF_HANDLE __MIDL_itf_netmon_0014_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_netmon_0014_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
