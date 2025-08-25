/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef __WS2BTH__H
#define __WS2BTH__H

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <bthdef.h>
#include <bthsdpdef.h>
#include <pshpack1.h>

#define BT_PORT_ANY ((ULONG)-1)
#define BT_PORT_MIN 0x1
#define BT_PORT_MAX 0xffff
#define BT_PORT_DYN_FIRST 0x1001

#ifndef AF_BTH
#define AF_BTH 32
#endif

#ifndef PF_BTH
#define PF_BTH AF_BTH
#endif

#ifndef NS_BTH
#define NS_BTH 16
#endif

typedef struct _SOCKADDR_BTH {
  USHORT addressFamily;
  BTH_ADDR btAddr;
  GUID serviceClassId;
  ULONG port;
} SOCKADDR_BTH,*PSOCKADDR_BTH;

DEFINE_GUID (SVCID_BTH_PROVIDER, 0x6aa63e0, 0x7d60, 0x41ff, 0xaf, 0xb2, 0x3e, 0xe6, 0xd2, 0xd9, 0x39, 0x2d);

#define BTH_ADDR_STRING_SIZE 12

#define BTHPROTO_RFCOMM 0x0003
#define BTHPROTO_L2CAP 0x0100

#define SOL_RFCOMM BTHPROTO_RFCOMM
#define SOL_L2CAP BTHPROTO_L2CAP
#define SOL_SDP 0x0101

#define SO_BTH_AUTHENTICATE 0x80000001
#define SO_BTH_ENCRYPT 0x00000002
#define SO_BTH_MTU 0x80000007
#define SO_BTH_MTU_MAX 0x80000008
#define SO_BTH_MTU_MIN 0x8000000a

#define RFCOMM_MAX_MTU 0x000003f3
#define RFCOMM_MIN_MTU 0x00000017

#define BTH_SDP_VERSION 1

typedef struct _BTH_SET_SERVICE {
  PULONG pSdpVersion;
  HANDLE *pRecordHandle;
  ULONG fCodService;
  ULONG Reserved[5];
  ULONG ulRecordLength;
  UCHAR pRecord[1];
} BTH_SET_SERVICE,*PBTH_SET_SERVICE;

#define SDP_DEFAULT_INQUIRY_SECONDS 6
#define SDP_MAX_INQUIRY_SECONDS 60

#define SDP_DEFAULT_INQUIRY_MAX_RESPONSES 255

#define SDP_SERVICE_SEARCH_REQUEST 1
#define SDP_SERVICE_ATTRIBUTE_REQUEST 2
#define SDP_SERVICE_SEARCH_ATTRIBUTE_REQUEST 3

typedef struct _BTH_QUERY_DEVICE {
  ULONG LAP;
  UCHAR length;
} BTH_QUERY_DEVICE,*PBTH_QUERY_DEVICE;
typedef struct _BTH_QUERY_SERVICE {
  ULONG type;
  ULONG serviceHandle;
  SdpQueryUuid uuids[MAX_UUIDS_IN_QUERY];
  ULONG numRange;
  SdpAttributeRange pRange[1];
} BTH_QUERY_SERVICE,*PBTH_QUERY_SERVICE;

#define BTHNS_RESULT_DEVICE_CONNECTED 0x00010000
#define BTHNS_RESULT_DEVICE_REMEMBERED 0x00020000
#define BTHNS_RESULT_DEVICE_AUTHENTICATED 0x00040000

#define SIO_RFCOMM_SEND_COMMAND _WSAIORW (IOC_VENDOR, 101)
#define SIO_RFCOMM_WAIT_COMMAND _WSAIORW (IOC_VENDOR, 102)

#define SIO_BTH_PING _WSAIORW (IOC_VENDOR, 8)
#define SIO_BTH_INFO _WSAIORW (IOC_VENDOR, 9)
#define SIO_RFCOMM_SESSION_FLOW_OFF _WSAIORW (IOC_VENDOR, 103)
#define SIO_RFCOMM_TEST _WSAIORW (IOC_VENDOR, 104)
#define SIO_RFCOMM_USECFC _WSAIORW (IOC_VENDOR, 105)

#ifndef BIT
#define BIT(b) (1 << (b))
#endif

#define MSC_EA_BIT EA_BIT
#define MSC_FC_BIT BIT (1)
#define MSC_RTC_BIT BIT (2)
#define MSC_RTR_BIT BIT (3)
#define MSC_RESERVED (BIT (4)|BIT (5))
#define MSC_IC_BIT BIT (6)
#define MSC_DV_BIT BIT (7)

#define MSC_BREAK_BIT BIT (1)
#define MSC_SET_BREAK_LENGTH (b, l) ((b) = ((b) &0x3) | (((l) &0xf) << 4))

#define RLS_ERROR 0x01
#define RLS_OVERRUN 0x02
#define RLS_PARITY 0x04
#define RLS_FRAMING 0x08

#define RPN_BAUD_2400 0
#define RPN_BAUD_4800 1
#define RPN_BAUD_7200 2
#define RPN_BAUD_9600 3
#define RPN_BAUD_19200 4
#define RPN_BAUD_38400 5
#define RPN_BAUD_57600 6
#define RPN_BAUD_115200 7
#define RPN_BAUD_230400 8

#define RPN_DATA_5 0x0
#define RPN_DATA_6 0x1
#define RPN_DATA_7 0x2
#define RPN_DATA_8 0x3

#define RPN_STOP_1 0x0
#define RPN_STOP_1_5 0x4

#define RPN_PARITY_NONE 0x00
#define RPN_PARITY_ODD 0x08
#define RPN_PARITY_EVEN 0x18
#define RPN_PARITY_MARK 0x28
#define RPN_PARITY_SPACE 0x38

#define RPN_FLOW_X_IN 0x01
#define RPN_FLOW_X_OUT 0x02
#define RPN_FLOW_RTR_IN 0x04
#define RPN_FLOW_RTR_OUT 0x08
#define RPN_FLOW_RTC_IN 0x10
#define RPN_FLOW_RTC_OUT 0x20

#define RPN_PARAM_BAUD 0x01
#define RPN_PARAM_DATA 0x02
#define RPN_PARAM_STOP 0x04
#define RPN_PARAM_PARITY 0x08
#define RPN_PARAM_P_TYPE 0x10
#define RPN_PARAM_XON 0x20
#define RPN_PARAM_XOFF 0x40

#define RPN_PARAM_X_IN 0x01
#define RPN_PARAM_X_OUT 0x02
#define RPN_PARAM_RTR_IN 0x04
#define RPN_PARAM_RTR_OUT 0x08
#define RPN_PARAM_RTC_IN 0x10
#define RPN_PARAM_RTC_OUT 0x20

#define RFCOMM_CMD_NONE 0
#define RFCOMM_CMD_MSC 1
#define RFCOMM_CMD_RLS 2
#define RFCOMM_CMD_RPN 3
#define RFCOMM_CMD_RPN_REQUEST 4
#define RFCOMM_CMD_RPN_RESPONSE 5

typedef struct _RFCOMM_MSC_DATA {
  UCHAR Signals;
  UCHAR Break;
} RFCOMM_MSC_DATA,*PRFCOMM_MSC_DATA;

typedef struct _RFCOMM_RLS_DATA {
  UCHAR LineStatus;
} RFCOMM_RLS_DATA,*PRFCOMM_RLS_DATA;

typedef struct _RFCOMM_RPN_DATA {
  UCHAR Baud;
  UCHAR Data;
  UCHAR FlowControl;
  UCHAR XonChar;
  UCHAR XoffChar;
  UCHAR ParameterMask1;
  UCHAR ParameterMask2;
} RFCOMM_RPN_DATA,*PRFCOMM_RPN_DATA;

typedef struct _RFCOMM_COMMAND {
  ULONG CmdType;
  union {
    RFCOMM_MSC_DATA MSC;
    RFCOMM_RLS_DATA RLS;
    RFCOMM_RPN_DATA RPN;
  } Data;
} RFCOMM_COMMAND,*PRFCOMM_COMMAND;

typedef struct _BTH_PING_REQ {
  BTH_ADDR btAddr;
  UCHAR dataLen;
  UCHAR data[MAX_L2CAP_PING_DATA_LENGTH];
} BTH_PING_REQ,*PBTH_PING_REQ;

typedef struct _BTH_PING_RSP {
  UCHAR dataLen;
  UCHAR data[MAX_L2CAP_PING_DATA_LENGTH];
} BTH_PING_RSP,*PBTH_PING_RSP;

typedef struct _BTH_INFO_REQ {
  BTH_ADDR btAddr;
  USHORT infoType;
} BTH_INFO_REQ,*PBTH_INFO_REQ;

typedef struct _BTH_INFO_RSP {
  USHORT result;
  UCHAR dataLen;
  __C89_NAMELESS union {
    USHORT connectionlessMTU;
    UCHAR data[MAX_L2CAP_INFO_DATA_LENGTH];
  };
} BTH_INFO_RSP,*PBTH_INFO_RSP;

typedef struct _BTH_SET_SERVICE BTHNS_SETBLOB,*PBTHNS_SETBLOB;
typedef struct _BTH_QUERY_DEVICE BTHNS_INQUIRYBLOB,*PBTHNS_INQUIRYBLOB;
typedef struct _BTH_QUERY_SERVICE BTHNS_RESTRICTIONBLOB,*PBTHNS_RESTRICTIONBLOB;

#include <poppack.h>

#endif

#endif
