/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __FLT_USER_STRUCTURES_H__
#define __FLT_USER_STRUCTURES_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#if ((OSVER(NTDDI_VERSION) == NTDDI_WIN2K && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WIN2KSP4)) \
     || (OSVER(NTDDI_VERSION) == NTDDI_WINXP && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WINXPSP2)) \
     || (OSVER(NTDDI_VERSION) == NTDDI_WS03 && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WS03SP1)) \
     || NTDDI_VERSION >= NTDDI_VISTA)

#define FLTAPI NTAPI

#define FILTER_NAME_MAX_CHARS     255
#define INSTANCE_NAME_MAX_CHARS   255
#define VOLUME_NAME_MAX_CHARS     1024

#define FILTER_NAME_MAX_BYTES     (FILTER_NAME_MAX_CHARS * sizeof (WCHAR))
#define INSTANCE_NAME_MAX_BYTES   (INSTANCE_NAME_MAX_CHARS * sizeof (WCHAR))
#define VOLUME_NAME_MAX_BYTES     (VOLUME_NAME_MAX_CHARS * sizeof (WCHAR))

#define FLTFL_AGGREGATE_INFO_IS_MINIFILTER   1
#define FLTFL_AGGREGATE_INFO_IS_LEGACYFILTER 2

#if NTDDI_VERSION >= NTDDI_VISTA
#define FLTFL_ASI_IS_MINIFILTER   1
#define FLTFL_ASI_IS_LEGACYFILTER 2

#define FLTFL_IASIL_DETACHED_VOLUME 1
#endif

#define FLTFL_IASIM_DETACHED_VOLUME 1

#define FLTFL_IASI_IS_MINIFILTER   1
#define FLTFL_IASI_IS_LEGACYFILTER 2

#if NTDDI_VERSION >= NTDDI_VISTA
#define FLTFL_VSI_DETACHED_VOLUME 1
#endif

typedef HANDLE HFILTER;
typedef HANDLE HFILTER_INSTANCE;
typedef HANDLE HFILTER_VOLUME;

#if !defined (_NTDEF_) && !defined (_NTSTATUS_PSDK)
#define _NTSTATUS_PSDK
typedef LONG NTSTATUS, *PNTSTATUS;
#endif

typedef enum _FLT_FILESYSTEM_TYPE {
  FLT_FSTYPE_UNKNOWN, FLT_FSTYPE_RAW, FLT_FSTYPE_NTFS, FLT_FSTYPE_FAT,
  FLT_FSTYPE_CDFS, FLT_FSTYPE_UDFS, FLT_FSTYPE_LANMAN, FLT_FSTYPE_WEBDAV,
  FLT_FSTYPE_RDPDR, FLT_FSTYPE_NFS, FLT_FSTYPE_MS_NETWARE, FLT_FSTYPE_NETWARE,
  FLT_FSTYPE_BSUDF, FLT_FSTYPE_MUP, FLT_FSTYPE_RSFX, FLT_FSTYPE_ROXIO_UDF1,
  FLT_FSTYPE_ROXIO_UDF2, FLT_FSTYPE_ROXIO_UDF3, FLT_FSTYPE_TACIT, FLT_FSTYPE_FS_REC,
  FLT_FSTYPE_INCD, FLT_FSTYPE_INCD_FAT, FLT_FSTYPE_EXFAT, FLT_FSTYPE_PSFS,
  FLT_FSTYPE_GPFS, FLT_FSTYPE_NPFS, FLT_FSTYPE_MSFS, FLT_FSTYPE_CSVFS,
  FLT_FSTYPE_REFS, FLT_FSTYPE_OPENAFS
} FLT_FILESYSTEM_TYPE, *PFLT_FILESYSTEM_TYPE;

typedef enum _FILTER_INFORMATION_CLASS {
  FilterFullInformation, FilterAggregateBasicInformation, FilterAggregateStandardInformation
} FILTER_INFORMATION_CLASS, *PFILTER_INFORMATION_CLASS;

typedef enum _INSTANCE_INFORMATION_CLASS {
  InstanceBasicInformation, InstancePartialInformation,
  InstanceFullInformation, InstanceAggregateStandardInformation
} INSTANCE_INFORMATION_CLASS, *PINSTANCE_INFORMATION_CLASS;

typedef enum _FILTER_VOLUME_INFORMATION_CLASS {
  FilterVolumeBasicInformation, FilterVolumeStandardInformation
} FILTER_VOLUME_INFORMATION_CLASS, *PFILTER_VOLUME_INFORMATION_CLASS;

typedef struct _FILTER_FULL_INFORMATION {
  ULONG NextEntryOffset;
  ULONG FrameID;
  ULONG NumberOfInstances;
  USHORT FilterNameLength;
  WCHAR FilterNameBuffer[1];
} FILTER_FULL_INFORMATION, *PFILTER_FULL_INFORMATION;

typedef struct _FILTER_AGGREGATE_BASIC_INFORMATION {
  ULONG NextEntryOffset;
  ULONG Flags;
  union {
    struct {
      ULONG FrameID;
      ULONG NumberOfInstances;
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
      USHORT FilterAltitudeLength;
      USHORT FilterAltitudeBufferOffset;
    } MiniFilter;
    struct {
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
    } LegacyFilter;
  } Type;
} FILTER_AGGREGATE_BASIC_INFORMATION, *PFILTER_AGGREGATE_BASIC_INFORMATION;

#if NTDDI_VERSION >= NTDDI_VISTA
typedef struct _FILTER_AGGREGATE_STANDARD_INFORMATION {
  ULONG NextEntryOffset;
  ULONG Flags;
  union {
    struct {
      ULONG Flags;
      ULONG FrameID;
      ULONG NumberOfInstances;
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
      USHORT FilterAltitudeLength;
      USHORT FilterAltitudeBufferOffset;
    } MiniFilter;
    struct {
      ULONG Flags;
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
      USHORT FilterAltitudeLength;
      USHORT FilterAltitudeBufferOffset;
    } LegacyFilter;
  } Type;
} FILTER_AGGREGATE_STANDARD_INFORMATION, *PFILTER_AGGREGATE_STANDARD_INFORMATION;
#endif

typedef struct _FILTER_VOLUME_BASIC_INFORMATION {
  USHORT FilterVolumeNameLength;
  WCHAR FilterVolumeName[1];
} FILTER_VOLUME_BASIC_INFORMATION, *PFILTER_VOLUME_BASIC_INFORMATION;

#if NTDDI_VERSION >= NTDDI_VISTA
typedef struct _FILTER_VOLUME_STANDARD_INFORMATION {
  ULONG NextEntryOffset;
  ULONG Flags;
  ULONG FrameID;
  FLT_FILESYSTEM_TYPE FileSystemType;
  USHORT FilterVolumeNameLength;
  WCHAR FilterVolumeName[1];
} FILTER_VOLUME_STANDARD_INFORMATION, *PFILTER_VOLUME_STANDARD_INFORMATION;
#endif

typedef struct _INSTANCE_BASIC_INFORMATION {
  ULONG NextEntryOffset;
  USHORT InstanceNameLength;
  USHORT InstanceNameBufferOffset;
} INSTANCE_BASIC_INFORMATION, *PINSTANCE_BASIC_INFORMATION;

typedef struct _INSTANCE_PARTIAL_INFORMATION {
  ULONG NextEntryOffset;
  USHORT InstanceNameLength;
  USHORT InstanceNameBufferOffset;
  USHORT AltitudeLength;
  USHORT AltitudeBufferOffset;
} INSTANCE_PARTIAL_INFORMATION, *PINSTANCE_PARTIAL_INFORMATION;

typedef struct _INSTANCE_FULL_INFORMATION {
  ULONG NextEntryOffset;
  USHORT InstanceNameLength;
  USHORT InstanceNameBufferOffset;
  USHORT AltitudeLength;
  USHORT AltitudeBufferOffset;
  USHORT VolumeNameLength;
  USHORT VolumeNameBufferOffset;
  USHORT FilterNameLength;
  USHORT FilterNameBufferOffset;
} INSTANCE_FULL_INFORMATION, *PINSTANCE_FULL_INFORMATION;

#if NTDDI_VERSION >= NTDDI_VISTA
typedef struct _INSTANCE_AGGREGATE_STANDARD_INFORMATION {
  ULONG NextEntryOffset;
  ULONG Flags;
  union {
    struct {
      ULONG Flags;
      ULONG FrameID;
      FLT_FILESYSTEM_TYPE VolumeFileSystemType;
      USHORT InstanceNameLength;
      USHORT InstanceNameBufferOffset;
      USHORT AltitudeLength;
      USHORT AltitudeBufferOffset;
      USHORT VolumeNameLength;
      USHORT VolumeNameBufferOffset;
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
#if NTDDI_VERSION >= NTDDI_WIN8
      ULONG SupportedFeatures;
#endif
    } MiniFilter;
    struct {
      ULONG Flags;
      USHORT AltitudeLength;
      USHORT AltitudeBufferOffset;
      USHORT VolumeNameLength;
      USHORT VolumeNameBufferOffset;
      USHORT FilterNameLength;
      USHORT FilterNameBufferOffset;
#if NTDDI_VERSION >= NTDDI_WIN8
      ULONG SupportedFeatures;
#endif
    } LegacyFilter;
  } Type;
} INSTANCE_AGGREGATE_STANDARD_INFORMATION, *PINSTANCE_AGGREGATE_STANDARD_INFORMATION;
#endif

typedef struct _FILTER_MESSAGE_HEADER {
  ULONG ReplyLength;
  ULONGLONG MessageId;
} FILTER_MESSAGE_HEADER, *PFILTER_MESSAGE_HEADER;

typedef struct _FILTER_REPLY_HEADER {
  NTSTATUS Status;
  ULONGLONG MessageId;
} FILTER_REPLY_HEADER, *PFILTER_REPLY_HEADER;
#endif

#endif /* WINAPI_PARTITION_DESKTOP.  */

#endif /* __FLT_USER_STRUCTURES_H__ */
