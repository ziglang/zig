/*
 * afilter.h
 *
 * Address filtering for NDIS MACs
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Filip Navara <xnavara@volny.cz>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _ARC_FILTER_DEFS_
#define _ARC_FILTER_DEFS_

#ifdef __cplusplus
extern "C" {
#endif

#define ARC_RECEIVE_BUFFERS            64
#define ARCNET_ADDRESS_LEN             1
#define ARC_PROTOCOL_HEADER_SIZE       (sizeof(ARC_PROTOCOL_HEADER))
#define ARC_MAX_FRAME_SIZE             504
#define ARC_MAX_ADDRESS_IDS            256
#define ARC_MAX_FRAME_HEADER_SIZE      6
#define ARC_MAX_PACKET_SIZE            576
#define ARC_FILTER_MAX_OPENS           (sizeof(ULONG) * 8)

#define ARC_IS_BROADCAST(Address) (BOOLEAN)(!(Address))

#define ARC_QUERY_FILTER_CLASSES(Filter) ((Filter)->CombinedPacketFilter)
#define ARC_QUERY_PACKET_FILTER(Filter, NdisFilterHandle) \
        (((PARC_BINDING_INFO)(NdisFilterHandle))->PacketFilters)

typedef ULONG MASK, *PMASK;

typedef struct _ARC_BUFFER_LIST
{
  PVOID  Buffer;
  UINT  Size;
  UINT  BytesLeft;
  struct _ARC_BUFFER_LIST  *Next;
} ARC_BUFFER_LIST, *PARC_BUFFER_LIST;

typedef struct _ARC_PROTOCOL_HEADER
{
  UCHAR  SourceId[ARCNET_ADDRESS_LEN];
  UCHAR  DestId[ARCNET_ADDRESS_LEN];
  UCHAR  ProtId;
} ARC_PROTOCOL_HEADER, *PARC_PROTOCOL_HEADER;

typedef struct _ARC_PACKET_HEADER
{
  ARC_PROTOCOL_HEADER  ProtHeader;
  USHORT  FrameSequence;
  UCHAR  SplitFlag;
  UCHAR  LastSplitFlag;
  UCHAR  FramesReceived;
} ARC_PACKET_HEADER, *PARC_PACKET_HEADER;

typedef struct _ARC_PACKET
{
  ARC_PACKET_HEADER  Header;
  struct _ARC_PACKET  *Next;
  ULONG  TotalLength;
  BOOLEAN  LastFrame;
  PARC_BUFFER_LIST  FirstBuffer;
  PARC_BUFFER_LIST  LastBuffer;
  NDIS_PACKET  TmpNdisPacket;
} ARC_PACKET, *PARC_PACKET;

typedef struct _ARC_BINDING_INFO
{
  PNDIS_OPEN_BLOCK  NdisBindingHandle;
  PVOID  Reserved;
  UINT  PacketFilters;
  ULONG  References;
  struct _ARC_BINDING_INFO  *NextOpen;
  BOOLEAN  ReceivedAPacket;
  UINT  OldPacketFilters;
} ARC_BINDING_INFO,*PARC_BINDING_INFO;

typedef struct _ARC_FILTER
{
  struct _NDIS_MINIPORT_BLOCK  *Miniport;
  UINT  CombinedPacketFilter;
  PARC_BINDING_INFO  OpenList;
  NDIS_HANDLE  ReceiveBufferPool;
  PARC_BUFFER_LIST  FreeBufferList;
  PARC_PACKET  FreePackets;
  PARC_PACKET  OutstandingPackets;
  UCHAR  AdapterAddress;
  UINT  OldCombinedPacketFilter;
} ARC_FILTER,*PARC_FILTER;

BOOLEAN
NTAPI
ArcCreateFilter(
  IN struct _NDIS_MINIPORT_BLOCK  *Miniport,
  IN UCHAR  AdapterAddress,
  OUT PARC_FILTER  *Filter);

VOID
NTAPI
ArcDeleteFilter(
  IN PARC_FILTER Filter);

BOOLEAN
NTAPI
ArcNoteFilterOpenAdapter(
  IN PARC_FILTER  Filter,
  IN NDIS_HANDLE  NdisBindingHandle,
  OUT PNDIS_HANDLE  NdisFilterHandle);

NDIS_STATUS
NTAPI
ArcDeleteFilterOpenAdapter(
  IN PARC_FILTER  Filter,
  IN NDIS_HANDLE  NdisFilterHandle,
  IN PNDIS_REQUEST  NdisRequest);

NDIS_STATUS
NTAPI
ArcFilterAdjust(
  IN PARC_FILTER  Filter,
  IN NDIS_HANDLE  NdisFilterHandle,
  IN PNDIS_REQUEST  NdisRequest,
  IN UINT  FilterClasses,
  IN BOOLEAN  Set);

VOID
NTAPI
ArcFilterDprIndicateReceiveComplete(
  IN PARC_FILTER  Filter);

VOID
NTAPI
ArcFilterDprIndicateReceive(
  IN PARC_FILTER  Filter,
  IN PUCHAR  pRawHeader,
  IN PUCHAR  pData,
  IN UINT  Length);

NDIS_STATUS
NTAPI
ArcFilterTransferData(
  IN PARC_FILTER  Filter,
  IN NDIS_HANDLE  MacReceiveContext,
  IN UINT  ByteOffset,
  IN UINT  BytesToTransfer,
  OUT PNDIS_PACKET  Packet,
  OUT PUINT  BytesTransfered);

VOID
NTAPI
ArcFreeNdisPacket(
  IN PARC_PACKET  Packet);

VOID
NTAPI
ArcFilterDoIndication(
  IN PARC_FILTER  Filter,
  IN PARC_PACKET  Packet);

VOID
NTAPI
ArcDestroyPacket(
  IN PARC_FILTER  Filter,
  IN PARC_PACKET  Packet);

#ifdef __cplusplus
}
#endif

#endif /* _ARC_FILTER_DEFS_ */
