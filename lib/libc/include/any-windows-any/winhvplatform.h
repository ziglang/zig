/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _WINHVAPI_H_
#define _WINHVAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <winhvplatformdefs.h>

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI WHvGetCapability(WHV_CAPABILITY_CODE CapabilityCode, VOID *CapabilityBuffer, UINT32 CapabilityBufferSizeInBytes, UINT32 *WrittenSizeInBytes);
HRESULT WINAPI WHvCreatePartition(WHV_PARTITION_HANDLE *Partition);
HRESULT WINAPI WHvSetupPartition(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvDeletePartition(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvGetPartitionProperty(WHV_PARTITION_HANDLE Partition, WHV_PARTITION_PROPERTY_CODE PropertyCode, VOID *PropertyBuffer, UINT32 PropertyBufferSizeInBytes, UINT32 *WrittenSizeInBytes);
HRESULT WINAPI WHvSetPartitionProperty(WHV_PARTITION_HANDLE Partition, WHV_PARTITION_PROPERTY_CODE PropertyCode, const VOID *PropertyBuffer, UINT32 PropertyBufferSizeInBytes);
HRESULT WINAPI WHvSuspendPartitionTime(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvResumePartitionTime(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvMapGpaRange(WHV_PARTITION_HANDLE Partition, VOID *SourceAddress, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 SizeInBytes, WHV_MAP_GPA_RANGE_FLAGS Flags);
HRESULT WINAPI WHvUnmapGpaRange(WHV_PARTITION_HANDLE Partition, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 SizeInBytes);
HRESULT WINAPI WHvTranslateGva(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_GUEST_VIRTUAL_ADDRESS Gva, WHV_TRANSLATE_GVA_FLAGS TranslateFlags, WHV_TRANSLATE_GVA_RESULT *TranslationResult, WHV_GUEST_PHYSICAL_ADDRESS *Gpa);
HRESULT WINAPI WHvCreateVirtualProcessor(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, UINT32 Flags);
HRESULT WINAPI WHvDeleteVirtualProcessor(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex);
HRESULT WINAPI WHvRunVirtualProcessor(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, VOID *ExitContext, UINT32 ExitContextSizeInBytes);
HRESULT WINAPI WHvCancelRunVirtualProcessor(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, UINT32 Flags);
HRESULT WINAPI WHvGetVirtualProcessorRegisters(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const WHV_REGISTER_NAME *RegisterNames, UINT32 RegisterCount, WHV_REGISTER_VALUE *RegisterValues);
HRESULT WINAPI WHvSetVirtualProcessorRegisters(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const WHV_REGISTER_NAME *RegisterNames, UINT32 RegisterCount, const WHV_REGISTER_VALUE *RegisterValues);
HRESULT WINAPI WHvGetVirtualProcessorInterruptControllerState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, VOID *State, UINT32 StateSize, UINT32 *WrittenSize);
HRESULT WINAPI WHvSetVirtualProcessorInterruptControllerState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const VOID *State, UINT32 StateSize);
HRESULT WINAPI WHvRequestInterrupt(WHV_PARTITION_HANDLE Partition, const WHV_INTERRUPT_CONTROL *Interrupt, UINT32 InterruptControlSize);
HRESULT WINAPI WHvGetVirtualProcessorXsaveState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, VOID *Buffer, UINT32 BufferSizeInBytes, UINT32 *BytesWritten);
HRESULT WINAPI WHvSetVirtualProcessorXsaveState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const VOID *Buffer, UINT32 BufferSizeInBytes);
HRESULT WINAPI WHvQueryGpaRangeDirtyBitmap(WHV_PARTITION_HANDLE Partition, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 RangeSizeInBytes, UINT64 *Bitmap, UINT32 BitmapSizeInBytes);
HRESULT WINAPI WHvGetPartitionCounters(WHV_PARTITION_HANDLE Partition, WHV_PARTITION_COUNTER_SET CounterSet, VOID *Buffer, UINT32 BufferSizeInBytes, UINT32 *BytesWritten);
HRESULT WINAPI WHvGetVirtualProcessorCounters(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_PROCESSOR_COUNTER_SET CounterSet, VOID *Buffer, UINT32 BufferSizeInBytes, UINT32 *BytesWritten);
HRESULT WINAPI WHvGetVirtualProcessorInterruptControllerState2(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, VOID *State, UINT32 StateSize, UINT32 *WrittenSize);
HRESULT WINAPI WHvSetVirtualProcessorInterruptControllerState2(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const VOID *State, UINT32 StateSize);
HRESULT WINAPI WHvRegisterPartitionDoorbellEvent(WHV_PARTITION_HANDLE Partition, const WHV_DOORBELL_MATCH_DATA *MatchData, HANDLE EventHandle);
HRESULT WINAPI WHvUnregisterPartitionDoorbellEvent(WHV_PARTITION_HANDLE Partition, const WHV_DOORBELL_MATCH_DATA *MatchData);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif /* _WINHVAPI_H_ */
