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
HRESULT WINAPI WHvResetPartition(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvDeletePartition(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvGetPartitionProperty(WHV_PARTITION_HANDLE Partition, WHV_PARTITION_PROPERTY_CODE PropertyCode, VOID *PropertyBuffer, UINT32 PropertyBufferSizeInBytes, UINT32 *WrittenSizeInBytes);
HRESULT WINAPI WHvSetPartitionProperty(WHV_PARTITION_HANDLE Partition, WHV_PARTITION_PROPERTY_CODE PropertyCode, const VOID *PropertyBuffer, UINT32 PropertyBufferSizeInBytes);
HRESULT WINAPI WHvSuspendPartitionTime(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvResumePartitionTime(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvMapGpaRange(WHV_PARTITION_HANDLE Partition, VOID *SourceAddress, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 SizeInBytes, WHV_MAP_GPA_RANGE_FLAGS Flags);
HRESULT WINAPI WHvMapGpaRange2(WHV_PARTITION_HANDLE Partition, HANDLE Process, VOID *SourceAddress, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 SizeInBytes, WHV_MAP_GPA_RANGE_FLAGS Flags);
HRESULT WINAPI WHvUnmapGpaRange(WHV_PARTITION_HANDLE Partition, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, UINT64 SizeInBytes);
HRESULT WINAPI WHvTranslateGva(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_GUEST_VIRTUAL_ADDRESS Gva, WHV_TRANSLATE_GVA_FLAGS TranslateFlags, WHV_TRANSLATE_GVA_RESULT *TranslationResult, WHV_GUEST_PHYSICAL_ADDRESS *Gpa);
HRESULT WINAPI WHvCreateVirtualProcessor(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, UINT32 Flags);
HRESULT WINAPI WHvCreateVirtualProcessor2(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, const WHV_VIRTUAL_PROCESSOR_PROPERTY *Properties, UINT32 PropertyCount);
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
HRESULT WINAPI WHvAdviseGpaRange(WHV_PARTITION_HANDLE Partition, const WHV_MEMORY_RANGE_ENTRY *GpaRanges, UINT32 GpaRangesCount, WHV_ADVISE_GPA_RANGE_CODE Advice, const VOID *AdviceBuffer, UINT32 AdviceBufferSizeInBytes);
HRESULT WINAPI WHvReadGpaRange(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, WHV_ACCESS_GPA_CONTROLS Controls, PVOID Data, UINT32 DataSizeInBytes);
HRESULT WINAPI WHvWriteGpaRange(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_GUEST_PHYSICAL_ADDRESS GuestAddress, WHV_ACCESS_GPA_CONTROLS Controls, const VOID *Data, UINT32 DataSizeInBytes);
HRESULT WINAPI WHvSignalVirtualProcessorSynicEvent(WHV_PARTITION_HANDLE Partition, WHV_SYNIC_EVENT_PARAMETERS SynicEvent, WINBOOL *NewlySignaled);
HRESULT WINAPI WHvGetVirtualProcessorState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_VIRTUAL_PROCESSOR_STATE_TYPE StateType, VOID *Buffer, UINT32 BufferSizeInBytes, UINT32 *BytesWritten);
HRESULT WINAPI WHvSetVirtualProcessorState(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, WHV_VIRTUAL_PROCESSOR_STATE_TYPE StateType, const VOID *Buffer, UINT32 BufferSizeInBytes);
HRESULT WINAPI WHvAllocateVpciResource(const GUID *ProviderId, WHV_ALLOCATE_VPCI_RESOURCE_FLAGS Flags, const VOID *ResourceDescriptor, UINT32 ResourceDescriptorSizeInBytes, HANDLE *VpciResource);
HRESULT WINAPI WHvCreateVpciDevice(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, HANDLE VpciResource, WHV_CREATE_VPCI_DEVICE_FLAGS Flags, HANDLE NotificationEventHandle);
HRESULT WINAPI WHvDeleteVpciDevice(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId);
HRESULT WINAPI WHvGetVpciDeviceProperty(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, WHV_VPCI_DEVICE_PROPERTY_CODE PropertyCode, VOID *PropertyBuffer, UINT32 PropertyBufferSizeInBytes, UINT32 *WrittenSizeInBytes);
HRESULT WINAPI WHvGetVpciDeviceNotification(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, WHV_VPCI_DEVICE_NOTIFICATION *Notification, UINT32 NotificationSizeInBytes);
HRESULT WINAPI WHvMapVpciDeviceMmioRanges(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT32 *MappingCount, WHV_VPCI_MMIO_MAPPING **Mappings);
HRESULT WINAPI WHvUnmapVpciDeviceMmioRanges(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId);
HRESULT WINAPI WHvSetVpciDevicePowerState(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, DEVICE_POWER_STATE PowerState);
HRESULT WINAPI WHvReadVpciDeviceRegister(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, const WHV_VPCI_DEVICE_REGISTER *Register, VOID *Data);
HRESULT WINAPI WHvWriteVpciDeviceRegister(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, const WHV_VPCI_DEVICE_REGISTER *Register, const VOID *Data);
HRESULT WINAPI WHvMapVpciDeviceInterrupt(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT32 Index, UINT32 MessageCount, const WHV_VPCI_INTERRUPT_TARGET *Target, UINT64 *MsiAddress, UINT32 *MsiData);
HRESULT WINAPI WHvUnmapVpciDeviceInterrupt(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT32 Index);
HRESULT WINAPI WHvRetargetVpciDeviceInterrupt(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT64 MsiAddress, UINT32 MsiData, const WHV_VPCI_INTERRUPT_TARGET *Target);
HRESULT WINAPI WHvRequestVpciDeviceInterrupt(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT64 MsiAddress, UINT32 MsiData);
HRESULT WINAPI WHvGetVpciDeviceInterruptTarget(WHV_PARTITION_HANDLE Partition, UINT64 LogicalDeviceId, UINT32 Index, UINT32 MultiMessageNumber, WHV_VPCI_INTERRUPT_TARGET *Target, UINT32 TargetSizeInBytes, UINT32 *BytesWritten);
HRESULT WINAPI WHvCreateTrigger(WHV_PARTITION_HANDLE Partition, const WHV_TRIGGER_PARAMETERS *Parameters, WHV_TRIGGER_HANDLE *TriggerHandle, HANDLE *EventHandle);
HRESULT WINAPI WHvUpdateTriggerParameters(WHV_PARTITION_HANDLE Partition, const WHV_TRIGGER_PARAMETERS *Parameters, WHV_TRIGGER_HANDLE TriggerHandle);
HRESULT WINAPI WHvDeleteTrigger(WHV_PARTITION_HANDLE Partition, WHV_TRIGGER_HANDLE TriggerHandle);
HRESULT WINAPI WHvCreateNotificationPort(WHV_PARTITION_HANDLE Partition, const WHV_NOTIFICATION_PORT_PARAMETERS *Parameters, HANDLE EventHandle, WHV_NOTIFICATION_PORT_HANDLE *PortHandle);
HRESULT WINAPI WHvSetNotificationPortProperty(WHV_PARTITION_HANDLE Partition, WHV_NOTIFICATION_PORT_HANDLE PortHandle, WHV_NOTIFICATION_PORT_PROPERTY_CODE PropertyCode, WHV_NOTIFICATION_PORT_PROPERTY PropertyValue);
HRESULT WINAPI WHvDeleteNotificationPort(WHV_PARTITION_HANDLE Partition, WHV_NOTIFICATION_PORT_HANDLE PortHandle);
HRESULT WINAPI WHvPostVirtualProcessorSynicMessage(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, UINT32 SintIndex, const VOID *Message, UINT32 MessageSizeInBytes);
HRESULT WINAPI WHvGetVirtualProcessorCpuidOutput(WHV_PARTITION_HANDLE Partition, UINT32 VpIndex, UINT32 Eax, UINT32 Ecx, WHV_CPUID_OUTPUT *CpuidOutput);
HRESULT WINAPI WHvGetInterruptTargetVpSet(WHV_PARTITION_HANDLE Partition, UINT64 Destination, WHV_INTERRUPT_DESTINATION_MODE DestinationMode, UINT32 *TargetVps, UINT32 VpCount, UINT32 *TargetVpCount);
HRESULT WINAPI WHvStartPartitionMigration(WHV_PARTITION_HANDLE Partition, HANDLE *MigrationHandle);
HRESULT WHvCancelPartitionMigration(WHV_PARTITION_HANDLE Partition);
HRESULT WHvCompletePartitionMigration(WHV_PARTITION_HANDLE Partition);
HRESULT WINAPI WHvAcceptPartitionMigration(HANDLE MigrationHandle, WHV_PARTITION_HANDLE *Partition);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif /* _WINHVAPI_H_ */
