/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSNWLINK_
#define _WSNWLINK_

#define IPX_PTYPE 0x4000

#define IPX_FILTERPTYPE 0x4001
#define IPX_STOPFILTERPTYPE 0x4003
#define IPX_DSTYPE 0x4002
#define IPX_EXTENDED_ADDRESS 0x4004
#define IPX_RECVHDR 0x4005
#define IPX_MAXSIZE 0x4006
#define IPX_ADDRESS 0x4007

typedef struct _IPX_ADDRESS_DATA {
  INT adapternum;
  UCHAR netnum[4];
  UCHAR nodenum[6];
  BOOLEAN wan;
  BOOLEAN status;
  INT maxpkt;
  ULONG linkspeed;
} IPX_ADDRESS_DATA,*PIPX_ADDRESS_DATA;

#define IPX_GETNETINFO 0x4008

typedef struct _IPX_NETNUM_DATA {
  UCHAR netnum[4];
  USHORT hopcount;
  USHORT netdelay;
  INT cardnum;
  UCHAR router[6];
} IPX_NETNUM_DATA,*PIPX_NETNUM_DATA;

#define IPX_GETNETINFO_NORIP 0x4009
#define IPX_SPXGETCONNECTIONSTATUS 0x400B

typedef struct _IPX_SPXCONNSTATUS_DATA {
  UCHAR ConnectionState;
  UCHAR WatchDogActive;
  USHORT LocalConnectionId;
  USHORT RemoteConnectionId;
  USHORT LocalSequenceNumber;
  USHORT LocalAckNumber;
  USHORT LocalAllocNumber;
  USHORT RemoteAckNumber;
  USHORT RemoteAllocNumber;
  USHORT LocalSocket;
  UCHAR ImmediateAddress[6];
  UCHAR RemoteNetwork[4];
  UCHAR RemoteNode[6];
  USHORT RemoteSocket;
  USHORT RetransmissionCount;
  USHORT EstimatedRoundTripDelay;
  USHORT RetransmittedPackets;
  USHORT SuppressedPacket;
} IPX_SPXCONNSTATUS_DATA,*PIPX_SPXCONNSTATUS_DATA;

#define IPX_ADDRESS_NOTIFY 0x400C
#define IPX_MAX_ADAPTER_NUM 0x400D
#define IPX_RERIPNETNUMBER 0x400E
#define IPX_RECEIVE_BROADCAST 0x400F
#define IPX_IMMEDIATESPXACK 0x4010
#endif
