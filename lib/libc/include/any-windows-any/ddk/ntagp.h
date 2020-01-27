/*
 * ntagp.h
 *
 * NT AGP bus driver interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Gregor Anich <blight@blight.eu.org>
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

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

DEFINE_GUID(GUID_AGP_BUS_INTERFACE_STANDARD, 0x2ef74803, 0xd8d3, 0x11d1, 0x9c, 0xaa, 0x00, 0xc0, 0xf0, 0x16, 0x56, 0x36);

#define AGP_BUS_INTERFACE_V1                     1
#define AGP_BUS_INTERFACE_V2                     2
#define AGP_BUS_INTERFACE_V3                     3
#define AGP_BUS_INTERFACE_V4                     4
#define AGP_BUS_INTERFACE_V5                     5

/* Indicates wether the GART supports mapping of physical memory for the CPU */
#define AGP_CAPABILITIES_MAP_PHYSICAL            0x00000001
#define AGP_CAPABILITIES_CACHE_COHERENT          0x00000002
#define AGP_CAPABILITIES_REQUIRES_GPU_FLUSH      0x00000004

#define AGP_SET_RATE_DISABLE_SBA                 0x00010000
#define AGP_SET_RATE_DISABLE_FW                  0x00020000

#define AGP_GUARD_PAGE_CHECK_FIRST_ULONG         0x00000001
#define AGP_GUARD_PAGE_CHECK_USE_SAME_OFFSET     0x00000002
#define AGP_GUARD_PAGE_CHECK_DO_NOT_BUGCHECK     0x00000004

#define AGP_BUS_INTERFACE_V1_SIZE (FIELD_OFFSET(AGP_BUS_INTERFACE_STANDARD,SetRate))
#define AGP_BUS_INTERFACE_V2_SIZE (FIELD_OFFSET(AGP_BUS_INTERFACE_STANDARD, AgpSize))
#define AGP_BUS_INTERFACE_V3_SIZE (FIELD_OFFSET(AGP_BUS_INTERFACE_STANDARD, FlushChipsetCaches))
#define AGP_BUS_INTERFACE_V4_SIZE (FIELD_OFFSET(AGP_BUS_INTERFACE_STANDARD, MapMemoryEx))

typedef NTSTATUS
(NTAPI *PAGP_BUS_SET_RATE)(
  IN PVOID AgpContext,
  IN ULONG AgpRate);

typedef NTSTATUS
(NTAPI *PAGP_BUS_RESERVE_MEMORY)(
  IN PVOID AgpContext,
  IN ULONG NumberOfPages,
  IN MEMORY_CACHING_TYPE MemoryType,
  OUT PVOID *MapHandle,
  OUT PHYSICAL_ADDRESS *PhysicalAddress OPTIONAL);

typedef NTSTATUS
(NTAPI *PAGP_BUS_RELEASE_MEMORY)(
  IN PVOID AgpContext,
  IN PVOID MapHandle);

typedef NTSTATUS
(NTAPI *PAGP_BUS_COMMIT_MEMORY)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  IN OUT PMDL Mdl OPTIONAL,
  OUT PHYSICAL_ADDRESS *MemoryBase);

typedef NTSTATUS
(NTAPI *PAGP_BUS_FREE_MEMORY)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages);

typedef NTSTATUS
(NTAPI *PAGP_GET_MAPPED_PAGES)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  OUT PMDL Mdl);

typedef NTSTATUS
(NTAPI *PAGP_MAP_MEMORY)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  IN PMDL Mdl,
  OUT PHYSICAL_ADDRESS *MemoryBase);

typedef NTSTATUS
(NTAPI *PAGP_UNMAP_MEMORY)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  IN PMDL Mdl);

typedef NTSTATUS
(NTAPI *PAGP_FLUSH_CHIPSET_CACHES)(
  IN PVOID AgpContext);

typedef NTSTATUS
(NTAPI *PAGP_CHECK_INTEGRITY)(
  IN PVOID AgpContext);

typedef NTSTATUS
(NTAPI *PAGP_MAP_MEMORY_EX)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  IN PMDL Mdl,
  IN MEMORY_CACHING_TYPE *CacheTypeOverride OPTIONAL,
  OUT PHYSICAL_ADDRESS *MemoryBase);

typedef NTSTATUS
(NTAPI *PAGP_UNMAP_MEMORY_EX)(
  IN PVOID AgpContext,
  IN PVOID MapHandle,
  IN ULONG NumberOfPages,
  IN ULONG OffsetInPages,
  IN PMDL Mdl);

typedef NTSTATUS
(NTAPI *PAGP_FLUSH_GART_TLB)(
  IN PVOID AgpContext);

typedef NTSTATUS
(NTAPI *PAGP_CHECK_GUARD_PAGE)(
  IN PVOID AgpContext,
  IN ULONG Flags,
  IN ULONG ULongsToCheck);

typedef struct _AGP_INFO_COMMON {
  PCI_AGP_CAPABILITY MasterCap;
  PCI_AGP_CAPABILITY TargetCap;
  USHORT DeviceId;
  USHORT VendorId;
  USHORT SubVendorId;
  USHORT SubSystemId;
  UCHAR HwRevisionId;
  ULONG VerifierFlags;
  BOOLEAN GuardPageCorruption;
} AGP_INFO_COMMON, *PAGP_INFO_COMMON;

typedef struct _AGP_INFO_DRIVER {
  ULONG AGPReg1;
  ULONG AGPReg2;
  PHYSICAL_ADDRESS ApertureStart;
  PHYSICAL_ADDRESS GartTranslationTable;
  ULONG ApertureLength;
} AGP_INFO_DRIVER, *PAGP_INFO_DRIVER;

typedef struct _AGP_INFO {
  AGP_INFO_COMMON CommonInfo;
  AGP_INFO_DRIVER DriverInfo;
} AGP_INFO, *PAGP_INFO;

typedef VOID
(NTAPI *PAGP_GET_INFO)(
  IN PVOID AgpContext,
  OUT PAGP_INFO AgpInfo);

typedef struct _AGP_BUS_INTERFACE_STANDARD {
  USHORT Size;
  USHORT Version;
  PVOID AgpContext;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  ULONG Capabilities;
  PAGP_BUS_RESERVE_MEMORY ReserveMemory;
  PAGP_BUS_RELEASE_MEMORY ReleaseMemory;
  PAGP_BUS_COMMIT_MEMORY CommitMemory;
  PAGP_BUS_FREE_MEMORY FreeMemory;
  PAGP_GET_MAPPED_PAGES GetMappedPages;
  PAGP_BUS_SET_RATE SetRate;
  SIZE_T AgpSize;
  PHYSICAL_ADDRESS AgpBase;
  PHYSICAL_ADDRESS MaxPhysicalAddress;
  PAGP_MAP_MEMORY MapMemory;
  PAGP_UNMAP_MEMORY UnMapMemory;
  PAGP_FLUSH_CHIPSET_CACHES FlushChipsetCaches;
  PAGP_CHECK_INTEGRITY CheckIntegrity;
  PAGP_MAP_MEMORY_EX  MapMemoryEx;
  PAGP_UNMAP_MEMORY_EX UnMapMemoryEx;
  PAGP_FLUSH_GART_TLB FlushGartTLB;
  PAGP_CHECK_GUARD_PAGE CheckGuardPage;
  PAGP_GET_INFO GetAgpInfo;
} AGP_BUS_INTERFACE_STANDARD, *PAGP_BUS_INTERFACE_STANDARD;

#ifdef __cplusplus
}
#endif
