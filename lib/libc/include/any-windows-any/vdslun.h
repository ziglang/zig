/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VDSLUN
#define _INC_VDSLUN

typedef struct _VDS_INTERCONNECT {
  VDS_INTERCONNECT_ADDRESS_TYPE m_addressType;
  ULONG m_cbPort;  BYTE* m_pbPort;
  ULONG m_cbAddress;
  BYTE *m_pbAddress;
} VDS_INTERCONNECT;

typedef struct _VDS_LUN_INFORMATION {
  ULONG m_version;
  BYTE m_DeviceType;
  BYTE m_DeviceTypeModifier;
  WINBOOL m_bCommandQueueing;
  VDS_STORAGE_BUS_TYPE m_BusType;
  char* m_szVendorId;
  char* m_szProductId;
  char* m_szProductRevision;
  char* m_szSerialNumber;
  GUID m_diskSignature;
  VDS_STORAGE_DEVICE_ID_DESCRIPTOR m_deviceIdDescriptor;
  ULONG m_cInterconnects;
  VDS_INTERCONNECT *m_rgInterconnects;
} VDS_LUN_INFORMATION;

#endif /*_INC_VDSLUN*/
