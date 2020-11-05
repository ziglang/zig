/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WDMSEC_H_
#define _WDMSEC_H_

#ifdef __cplusplus
extern "C" {
#endif

extern const UNICODE_STRING SDDL_DEVOBJ_KERNEL_ONLY;
#define SDDL_DEVOBJ_INF_SUPPLIED SDDL_DEVOBJ_KERNEL_ONLY

extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_ALL;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_RX;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_RWX_WORLD_R;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_RWX_WORLD_R_RES_R;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_RWX_WORLD_RW_RES_R;
extern const UNICODE_STRING SDDL_DEVOBJ_SYS_ALL_ADM_RWX_WORLD_RWX_RES_RWX;

#undef IoCreateDeviceSecure
#define IoCreateDeviceSecure WdmlibIoCreateDeviceSecure

NTSTATUS
WdmlibIoCreateDeviceSecure(
  PDRIVER_OBJECT DriverObject,
  ULONG DeviceExtensionSize,
  PUNICODE_STRING DeviceName,
  DEVICE_TYPE DeviceType,
  ULONG DeviceCharacteristics,
  BOOLEAN Exclusive,
  PCUNICODE_STRING DefaultSDDLString,
  LPCGUID DeviceClassGuid,
  PDEVICE_OBJECT *DeviceObject
);

#undef RtlInitUnicodeStringEx
#define RtlInitUnicodeStringEx WdmlibRtlInitUnicodeStringEx

NTSTATUS
WdmlibRtlInitUnicodeStringEx(
  PUNICODE_STRING DestinationString,
  PCWSTR SourceString
);

#undef IoValidateDeviceIoControlAccess
#define IoValidateDeviceIoControlAccess WdmlibIoValidateDeviceIoControlAccess

NTSTATUS
WdmlibIoValidateDeviceIoControlAccess(
  PIRP Irp,
  ULONG RequiredAccess
);

#ifdef __cplusplus
}
#endif

#endif /* _WDMSEC_H_ */
