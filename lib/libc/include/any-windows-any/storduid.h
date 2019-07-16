/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STORDUID
#define _INC_STORDUID

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _STORAGE_DEVICE_UNIQUE_IDENTIFIER {
  ULONG Version;
  ULONG Size;
  ULONG StorageDeviceIdOffset;
  ULONG StorageDeviceOffset;
  ULONG DriveLayoutSignatureOffset;
} STORAGE_DEVICE_UNIQUE_IDENTIFIER, *PSTORAGE_DEVICE_UNIQUE_IDENTIFIER;

typedef struct _STORAGE_DEVICE_LAYOUT_SIGNATURE {
  ULONG   Version;
  ULONG   Size;
  BOOLEAN Mbr;
  union {
    ULONG MbrSignature;
    GUID  GptDiskId;
  } DeviceSpecific;
} STORAGE_DEVICE_LAYOUT_SIGNATURE, *PSTORAGE_DEVICE_LAYOUT_SIGNATURE;

#ifdef __cplusplus
}
#endif
#endif /*_INC_STORDUID*/
