/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef __BLUETOOTHLEAPIS_H__
#define __BLUETOOTHLEAPIS_H__

#include <winapifamily.h>
#include <bthledef.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C"{
#endif

#if NTDDI_VERSION >= NTDDI_WIN8

HRESULT WINAPI BluetoothGATTGetServices(HANDLE hDevice, USHORT ServicesBufferCount, PBTH_LE_GATT_SERVICE ServicesBuffer, USHORT *ServicesBufferActual, ULONG Flags);
HRESULT WINAPI BluetoothGATTGetIncludedServices(HANDLE hDevice, PBTH_LE_GATT_SERVICE ParentService, USHORT IncludedServicesBufferCount, PBTH_LE_GATT_SERVICE IncludedServicesBuffer, USHORT *IncludedServicesBufferActual, ULONG Flags);
HRESULT WINAPI BluetoothGATTGetCharacteristics(HANDLE hDevice, PBTH_LE_GATT_SERVICE Service, USHORT CharacteristicsBufferCount, PBTH_LE_GATT_CHARACTERISTIC CharacteristicsBuffer, USHORT *CharacteristicsBufferActual, ULONG Flags);
HRESULT WINAPI BluetoothGATTGetDescriptors(HANDLE hDevice, PBTH_LE_GATT_CHARACTERISTIC Characteristic, USHORT DescriptorsBufferCount, PBTH_LE_GATT_DESCRIPTOR DescriptorsBuffer, USHORT *DescriptorsBufferActual, ULONG Flags);
HRESULT WINAPI BluetoothGATTGetCharacteristicValue(HANDLE hDevice, PBTH_LE_GATT_CHARACTERISTIC Characteristic, ULONG CharacteristicValueDataSize, PBTH_LE_GATT_CHARACTERISTIC_VALUE CharacteristicValue, USHORT *CharacteristicValueSizeRequired, ULONG Flags);
HRESULT WINAPI BluetoothGATTGetDescriptorValue(HANDLE hDevice, PBTH_LE_GATT_DESCRIPTOR Descriptor, ULONG DescriptorValueDataSize, PBTH_LE_GATT_DESCRIPTOR_VALUE DescriptorValue, USHORT *DescriptorValueSizeRequired, ULONG Flags);
HRESULT WINAPI BluetoothGATTBeginReliableWrite(HANDLE hDevice, PBTH_LE_GATT_RELIABLE_WRITE_CONTEXT ReliableWriteContext, ULONG Flags);
HRESULT WINAPI BluetoothGATTSetCharacteristicValue(HANDLE hDevice, PBTH_LE_GATT_CHARACTERISTIC Characteristic, PBTH_LE_GATT_CHARACTERISTIC_VALUE CharacteristicValue, BTH_LE_GATT_RELIABLE_WRITE_CONTEXT ReliableWriteContext, ULONG Flags);
HRESULT WINAPI BluetoothGATTEndReliableWrite(HANDLE hDevice, BTH_LE_GATT_RELIABLE_WRITE_CONTEXT ReliableWriteContext, ULONG Flags);
HRESULT WINAPI BluetoothGATTAbortReliableWrite(HANDLE hDevice, BTH_LE_GATT_RELIABLE_WRITE_CONTEXT ReliableWriteContext, ULONG Flags);
HRESULT WINAPI BluetoothGATTSetDescriptorValue(HANDLE hDevice, PBTH_LE_GATT_DESCRIPTOR Descriptor, PBTH_LE_GATT_DESCRIPTOR_VALUE DescriptorValue, ULONG Flags);
HRESULT WINAPI BluetoothGATTRegisterEvent(HANDLE hService, BTH_LE_GATT_EVENT_TYPE EventType, PVOID EventParameterIn, PFNBLUETOOTH_GATT_EVENT_CALLBACK Callback, PVOID CallbackContext, BLUETOOTH_GATT_EVENT_HANDLE *pEventHandle, ULONG Flags);
HRESULT WINAPI BluetoothGATTUnregisterEvent(BLUETOOTH_GATT_EVENT_HANDLE EventHandle, ULONG Flags);

#endif /* NTDDI_WIN8 */

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif /* __BLUETOOTHLEAPIS_H__ */
