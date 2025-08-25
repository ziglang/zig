/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _NDKINFO_H_
#define _NDKINFO_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define NDK_ADAPTER_FLAG_IN_ORDER_DMA_SUPPORTED 0x1
#define NDK_ADAPTER_FLAG_RDMA_READ_SINK_NOT_REQUIRED 0x2
#define NDK_ADAPTER_FLAG_CQ_INTERRUPT_MODERATION_SUPPORTED 0x4
#define NDK_ADAPTER_FLAG_MULTI_ENGINE_SUPPORTED 0x8
#define NDK_ADAPTER_FLAG_CQ_RESIZE_SUPPORTED 0x100
#define NDK_ADAPTER_FLAG_LOOPBACK_CONNECTIONS_SUPPORTED 0x10000

typedef struct {
  USHORT Major;
  USHORT Minor;
} NDK_VERSION;

typedef struct _NDK_ADAPTER_INFO {
  NDK_VERSION Version;
  UINT32 VendorId;
  UINT32 DeviceId;
  SIZE_T MaxRegistrationSize;
  SIZE_T MaxWindowSize;
  ULONG FRMRPageCount;
  ULONG MaxInitiatorRequestSge;
  ULONG MaxReceiveRequestSge;
  ULONG MaxReadRequestSge;
  ULONG MaxTransferLength;
  ULONG MaxInlineDataSize;
  ULONG MaxInboundReadLimit;
  ULONG MaxOutboundReadLimit;
  ULONG MaxReceiveQueueDepth;
  ULONG MaxInitiatorQueueDepth;
  ULONG MaxSrqDepth;
  ULONG MaxCqDepth;
  ULONG LargeRequestThreshold;
  ULONG MaxCallerData;
  ULONG MaxCalleeData;
  ULONG AdapterFlags;
} NDK_ADAPTER_INFO;

#endif
#endif
