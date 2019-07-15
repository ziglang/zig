/*
 * ntddstor.h
 *
 * Storage class IOCTL interface.
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
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

#ifndef _NTDDSTOR_H_
#define _NTDDSTOR_H_

#ifdef __cplusplus
extern "C" {
#endif

#if defined(DEFINE_GUID)

DEFINE_GUID(GUID_DEVINTERFACE_DISK,
  0x53f56307, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_CDROM,
  0x53f56308, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_PARTITION,
  0x53f5630a, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_TAPE,
  0x53f5630b, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_WRITEONCEDISK,
  0x53f5630c, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_VOLUME,
  0x53f5630d, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_MEDIUMCHANGER,
  0x53f56310, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_FLOPPY,
  0x53f56311, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_CDCHANGER,
  0x53f56312, 0xb6bf, 0x11d0, 0x94, 0xf2, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_STORAGEPORT,
  0x2accfe60, 0xc130, 0x11d2, 0xb0, 0x82, 0x00, 0xa0, 0xc9, 0x1e, 0xfb, 0x8b);

DEFINE_GUID(GUID_DEVINTERFACE_HIDDEN_VOLUME,
  0x7f108a28, 0x9833, 0x4b3b, 0xb7, 0x80, 0x2c, 0x6b, 0x5f, 0xa5, 0xc0, 0x62);

#define WDI_STORAGE_PREDICT_FAILURE_DPS_GUID \
  {0xe9f2d03a, 0x747c, 0x41c2, {0xbb, 0x9a, 0x02, 0xc6, 0x2b, 0x6d, 0x5f, 0xcb}};

/* Aliases for storage guids */
#define DiskClassGuid               GUID_DEVINTERFACE_DISK
#define CdRomClassGuid              GUID_DEVINTERFACE_CDROM
#define PartitionClassGuid          GUID_DEVINTERFACE_PARTITION
#define TapeClassGuid               GUID_DEVINTERFACE_TAPE
#define WriteOnceDiskClassGuid      GUID_DEVINTERFACE_WRITEONCEDISK
#define VolumeClassGuid             GUID_DEVINTERFACE_VOLUME
#define MediumChangerClassGuid      GUID_DEVINTERFACE_MEDIUMCHANGER
#define FloppyClassGuid             GUID_DEVINTERFACE_FLOPPY
#define CdChangerClassGuid          GUID_DEVINTERFACE_CDCHANGER
#define StoragePortClassGuid        GUID_DEVINTERFACE_STORAGEPORT
#define HiddenVolumeClassGuid       GUID_DEVINTERFACE_HIDDEN_VOLUME

#endif /* defined(DEFINE_GUID) */

#ifndef _WINIOCTL_

#define IOCTL_STORAGE_BASE                FILE_DEVICE_MASS_STORAGE

#define IOCTL_STORAGE_CHECK_VERIFY \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0200, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_CHECK_VERIFY2 \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0200, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_MEDIA_REMOVAL \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0201, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_EJECT_MEDIA \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0202, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_LOAD_MEDIA \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0203, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_LOAD_MEDIA2 \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0203, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_RESERVE \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0204, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_RELEASE \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0205, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_FIND_NEW_DEVICES \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0206, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_EJECTION_CONTROL \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0250, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_MCN_CONTROL \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0251, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_GET_MEDIA_TYPES \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0300, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_GET_MEDIA_TYPES_EX \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0301, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_RESET_BUS \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0400, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_RESET_DEVICE \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0401, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_GET_DEVICE_NUMBER \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0420, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_PREDICT_FAILURE \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0440, METHOD_BUFFERED, FILE_ANY_ACCESS)

#endif /* _WINIOCTL_ */

#define IOCTL_STORAGE_GET_MEDIA_SERIAL_NUMBER \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0304, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_GET_HOTPLUG_INFO \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0305, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_SET_HOTPLUG_INFO \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0306, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define OBSOLETE_IOCTL_STORAGE_RESET_BUS \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0400, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define OBSOLETE_IOCTL_STORAGE_RESET_DEVICE \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0401, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_STORAGE_BREAK_RESERVATION \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0405, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_PERSISTENT_RESERVE_IN \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0406, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_PERSISTENT_RESERVE_OUT \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0407, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_STORAGE_READ_CAPACITY \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0450, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_QUERY_PROPERTY \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0500, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_STORAGE_MANAGE_DATA_SET_ATTRIBUTES \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0501, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_STORAGE_GET_BC_PROPERTIES \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0600, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_STORAGE_ALLOCATE_BC_STREAM \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0601, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_STORAGE_FREE_BC_STREAM \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0602, METHOD_BUFFERED, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define IOCTL_STORAGE_CHECK_PRIORITY_HINT_SUPPORT \
  CTL_CODE(IOCTL_STORAGE_BASE, 0x0620, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define RECOVERED_WRITES_VALID         0x00000001
#define UNRECOVERED_WRITES_VALID       0x00000002
#define RECOVERED_READS_VALID          0x00000004
#define UNRECOVERED_READS_VALID        0x00000008
#define WRITE_COMPRESSION_INFO_VALID   0x00000010
#define READ_COMPRESSION_INFO_VALID    0x00000020

#define TAPE_RETURN_STATISTICS         __MSABI_LONG(0)
#define TAPE_RETURN_ENV_INFO           __MSABI_LONG(1)
#define TAPE_RESET_STATISTICS          __MSABI_LONG(2)

/* DEVICE_MEDIA_INFO.DeviceSpecific.DiskInfo.MediaCharacteristics constants */
#define MEDIA_ERASEABLE                   0x00000001
#define MEDIA_WRITE_ONCE                  0x00000002
#define MEDIA_READ_ONLY                   0x00000004
#define MEDIA_READ_WRITE                  0x00000008
#define MEDIA_WRITE_PROTECTED             0x00000100
#define MEDIA_CURRENTLY_MOUNTED           0x80000000

#define StorageIdTypeNAA StorageIdTypeFCPHName

#define DeviceDsmActionFlag_NonDestructive  0x80000000

#define IsDsmActionNonDestructive(_Action) ((BOOLEAN)((_Action & DeviceDsmActionFlag_NonDestructive) != 0))

#define DeviceDsmAction_None            0
#define DeviceDsmAction_Trim            1
#define DeviceDsmAction_Notification   (2 | DeviceDsmActionFlag_NonDestructive)

#define DEVICE_DSM_FLAG_ENTIRE_DATA_SET_RANGE    0x00000001

#define DEVICE_DSM_NOTIFY_FLAG_BEGIN             0x00000001
#define DEVICE_DSM_NOTIFY_FLAG_END               0x00000002

#define IOCTL_STORAGE_BC_VERSION                 1

#define STORAGE_PRIORITY_HINT_SUPPORTED          0x0001

typedef struct _STORAGE_HOTPLUG_INFO {
  ULONG Size;
  BOOLEAN MediaRemovable;
  BOOLEAN MediaHotplug;
  BOOLEAN DeviceHotplug;
  BOOLEAN WriteCacheEnableOverride;
} STORAGE_HOTPLUG_INFO, *PSTORAGE_HOTPLUG_INFO;

typedef struct _STORAGE_DEVICE_NUMBER {
  DEVICE_TYPE DeviceType;
  ULONG DeviceNumber;
  ULONG PartitionNumber;
} STORAGE_DEVICE_NUMBER, *PSTORAGE_DEVICE_NUMBER;

typedef struct _STORAGE_BUS_RESET_REQUEST {
  UCHAR PathId;
} STORAGE_BUS_RESET_REQUEST, *PSTORAGE_BUS_RESET_REQUEST;

typedef struct _STORAGE_BREAK_RESERVATION_REQUEST {
  ULONG Length;
  UCHAR _unused;
  UCHAR PathId;
  UCHAR TargetId;
  UCHAR Lun;
} STORAGE_BREAK_RESERVATION_REQUEST, *PSTORAGE_BREAK_RESERVATION_REQUEST;

#ifndef _WINIOCTL_
typedef struct _PREVENT_MEDIA_REMOVAL {
  BOOLEAN PreventMediaRemoval;
} PREVENT_MEDIA_REMOVAL, *PPREVENT_MEDIA_REMOVAL;
#endif

typedef struct _CLASS_MEDIA_CHANGE_CONTEXT {
  ULONG MediaChangeCount;
  ULONG NewState;
} CLASS_MEDIA_CHANGE_CONTEXT, *PCLASS_MEDIA_CHANGE_CONTEXT;

typedef struct _TAPE_STATISTICS {
  ULONG Version;
  ULONG Flags;
  LARGE_INTEGER RecoveredWrites;
  LARGE_INTEGER UnrecoveredWrites;
  LARGE_INTEGER RecoveredReads;
  LARGE_INTEGER UnrecoveredReads;
  UCHAR CompressionRatioReads;
  UCHAR CompressionRatioWrites;
} TAPE_STATISTICS, *PTAPE_STATISTICS;

typedef struct _TAPE_GET_STATISTICS {
  ULONG Operation;
} TAPE_GET_STATISTICS, *PTAPE_GET_STATISTICS;

typedef enum _STORAGE_MEDIA_TYPE {
  DDS_4mm = 0x20,
  MiniQic,
  Travan,
  QIC,
  MP_8mm,
  AME_8mm,
  AIT1_8mm,
  DLT,
  NCTP,
  IBM_3480,
  IBM_3490E,
  IBM_Magstar_3590,
  IBM_Magstar_MP,
  STK_DATA_D3,
  SONY_DTF,
  DV_6mm,
  DMI,
  SONY_D2,
  CLEANER_CARTRIDGE,
  CD_ROM,
  CD_R,
  CD_RW,
  DVD_ROM,
  DVD_R,
  DVD_RW,
  MO_3_RW,
  MO_5_WO,
  MO_5_RW,
  MO_5_LIMDOW,
  PC_5_WO,
  PC_5_RW,
  PD_5_RW,
  ABL_5_WO,
  PINNACLE_APEX_5_RW,
  SONY_12_WO,
  PHILIPS_12_WO,
  HITACHI_12_WO,
  CYGNET_12_WO,
  KODAK_14_WO,
  MO_NFR_525,
  NIKON_12_RW,
  IOMEGA_ZIP,
  IOMEGA_JAZ,
  SYQUEST_EZ135,
  SYQUEST_EZFLYER,
  SYQUEST_SYJET,
  AVATAR_F2,
  MP2_8mm,
  DST_S,
  DST_M,
  DST_L,
  VXATape_1,
  VXATape_2,
#if (NTDDI_VERSION < NTDDI_WINXP)
  STK_EAGLE,
#else
  STK_9840,
#endif
  LTO_Ultrium,
  LTO_Accelis,
  DVD_RAM,
  AIT_8mm,
  ADR_1,
  ADR_2,
  STK_9940,
  SAIT,
  VXATape
} STORAGE_MEDIA_TYPE, *PSTORAGE_MEDIA_TYPE;

typedef enum _STORAGE_BUS_TYPE {
  BusTypeUnknown = 0x00,
  BusTypeScsi,
  BusTypeAtapi,
  BusTypeAta,
  BusType1394,
  BusTypeSsa,
  BusTypeFibre,
  BusTypeUsb,
  BusTypeRAID,
  BusTypeiScsi,
  BusTypeSas,
  BusTypeSata,
  BusTypeSd,
  BusTypeMmc,
  BusTypeVirtual,
  BusTypeFileBackedVirtual,
  BusTypeMax,
  BusTypeMaxReserved = 0x7F
} STORAGE_BUS_TYPE, *PSTORAGE_BUS_TYPE;

typedef struct _DEVICE_MEDIA_INFO {
  union {
    struct {
      LARGE_INTEGER Cylinders;
      STORAGE_MEDIA_TYPE MediaType;
      ULONG TracksPerCylinder;
      ULONG SectorsPerTrack;
      ULONG BytesPerSector;
      ULONG NumberMediaSides;
      ULONG MediaCharacteristics;
    } DiskInfo;
    struct {
      LARGE_INTEGER Cylinders;
      STORAGE_MEDIA_TYPE MediaType;
      ULONG TracksPerCylinder;
      ULONG SectorsPerTrack;
      ULONG BytesPerSector;
      ULONG NumberMediaSides;
      ULONG MediaCharacteristics;
    } RemovableDiskInfo;
    struct {
      STORAGE_MEDIA_TYPE MediaType;
      ULONG MediaCharacteristics;
      ULONG CurrentBlockSize;
      STORAGE_BUS_TYPE BusType;
      union {
        struct {
          UCHAR MediumType;
          UCHAR DensityCode;
        } ScsiInformation;
      } BusSpecificData;
    } TapeInfo;
  } DeviceSpecific;
} DEVICE_MEDIA_INFO, *PDEVICE_MEDIA_INFO;

typedef struct _GET_MEDIA_TYPES {
  ULONG DeviceType;
  ULONG MediaInfoCount;
  DEVICE_MEDIA_INFO MediaInfo[1];
} GET_MEDIA_TYPES, *PGET_MEDIA_TYPES;

typedef struct _STORAGE_PREDICT_FAILURE {
  ULONG PredictFailure;
  UCHAR VendorSpecific[512];
} STORAGE_PREDICT_FAILURE, *PSTORAGE_PREDICT_FAILURE;

typedef enum _STORAGE_QUERY_TYPE {
  PropertyStandardQuery = 0,
  PropertyExistsQuery,
  PropertyMaskQuery,
  PropertyQueryMaxDefined
} STORAGE_QUERY_TYPE, *PSTORAGE_QUERY_TYPE;

typedef enum _STORAGE_PROPERTY_ID {
  StorageDeviceProperty = 0,
  StorageAdapterProperty,
  StorageDeviceIdProperty,
  StorageDeviceUniqueIdProperty,
  StorageDeviceWriteCacheProperty,
  StorageMiniportProperty,
  StorageAccessAlignmentProperty,
  StorageDeviceSeekPenaltyProperty,
  StorageDeviceTrimProperty,
  StorageDeviceWriteAggregationProperty
} STORAGE_PROPERTY_ID, *PSTORAGE_PROPERTY_ID;

typedef struct _STORAGE_PROPERTY_QUERY {
  STORAGE_PROPERTY_ID PropertyId;
  STORAGE_QUERY_TYPE QueryType;
  UCHAR AdditionalParameters[1];
} STORAGE_PROPERTY_QUERY, *PSTORAGE_PROPERTY_QUERY;

typedef struct _STORAGE_DESCRIPTOR_HEADER {
  ULONG Version;
  ULONG Size;
} STORAGE_DESCRIPTOR_HEADER, *PSTORAGE_DESCRIPTOR_HEADER;

typedef struct _STORAGE_DEVICE_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  UCHAR DeviceType;
  UCHAR DeviceTypeModifier;
  BOOLEAN RemovableMedia;
  BOOLEAN CommandQueueing;
  ULONG VendorIdOffset;
  ULONG ProductIdOffset;
  ULONG ProductRevisionOffset;
  ULONG SerialNumberOffset;
  STORAGE_BUS_TYPE BusType;
  ULONG RawPropertiesLength;
  UCHAR RawDeviceProperties[1];
} STORAGE_DEVICE_DESCRIPTOR, *PSTORAGE_DEVICE_DESCRIPTOR;

typedef struct _STORAGE_ADAPTER_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  ULONG MaximumTransferLength;
  ULONG MaximumPhysicalPages;
  ULONG AlignmentMask;
  BOOLEAN AdapterUsesPio;
  BOOLEAN AdapterScansDown;
  BOOLEAN CommandQueueing;
  BOOLEAN AcceleratedTransfer;
#if (NTDDI_VERSION < NTDDI_WINXP)
  BOOLEAN BusType;
#else
  UCHAR BusType;
#endif
  USHORT BusMajorVersion;
  USHORT BusMinorVersion;
} STORAGE_ADAPTER_DESCRIPTOR, *PSTORAGE_ADAPTER_DESCRIPTOR;

typedef struct _STORAGE_ACCESS_ALIGNMENT_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  ULONG BytesPerCacheLine;
  ULONG BytesOffsetForCacheAlignment;
  ULONG BytesPerLogicalSector;
  ULONG BytesPerPhysicalSector;
  ULONG BytesOffsetForSectorAlignment;
} STORAGE_ACCESS_ALIGNMENT_DESCRIPTOR, *PSTORAGE_ACCESS_ALIGNMENT_DESCRIPTOR;

typedef enum _STORAGE_PORT_CODE_SET {
  StoragePortCodeSetReserved = 0,
  StoragePortCodeSetStorport = 1,
  StoragePortCodeSetSCSIport = 2
} STORAGE_PORT_CODE_SET, *PSTORAGE_PORT_CODE_SET;

typedef struct _STORAGE_MINIPORT_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  STORAGE_PORT_CODE_SET Portdriver;
  BOOLEAN LUNResetSupported;
  BOOLEAN TargetResetSupported;
} STORAGE_MINIPORT_DESCRIPTOR, *PSTORAGE_MINIPORT_DESCRIPTOR;

typedef enum _STORAGE_IDENTIFIER_CODE_SET {
  StorageIdCodeSetReserved = 0,
  StorageIdCodeSetBinary = 1,
  StorageIdCodeSetAscii = 2,
  StorageIdCodeSetUtf8 = 3
} STORAGE_IDENTIFIER_CODE_SET, *PSTORAGE_IDENTIFIER_CODE_SET;

typedef enum _STORAGE_IDENTIFIER_TYPE {
  StorageIdTypeVendorSpecific = 0,
  StorageIdTypeVendorId = 1,
  StorageIdTypeEUI64 = 2,
  StorageIdTypeFCPHName = 3,
  StorageIdTypePortRelative = 4,
  StorageIdTypeTargetPortGroup = 5,
  StorageIdTypeLogicalUnitGroup = 6,
  StorageIdTypeMD5LogicalUnitIdentifier = 7,
  StorageIdTypeScsiNameString = 8
} STORAGE_IDENTIFIER_TYPE, *PSTORAGE_IDENTIFIER_TYPE;

typedef enum _STORAGE_ID_NAA_FORMAT {
  StorageIdNAAFormatIEEEExtended = 2,
  StorageIdNAAFormatIEEERegistered = 3,
  StorageIdNAAFormatIEEEERegisteredExtended = 5
} STORAGE_ID_NAA_FORMAT, *PSTORAGE_ID_NAA_FORMAT;

typedef enum _STORAGE_ASSOCIATION_TYPE {
  StorageIdAssocDevice = 0,
  StorageIdAssocPort = 1,
  StorageIdAssocTarget = 2
} STORAGE_ASSOCIATION_TYPE, *PSTORAGE_ASSOCIATION_TYPE;

typedef struct _STORAGE_IDENTIFIER {
  STORAGE_IDENTIFIER_CODE_SET CodeSet;
  STORAGE_IDENTIFIER_TYPE Type;
  USHORT IdentifierSize;
  USHORT NextOffset;
  STORAGE_ASSOCIATION_TYPE Association;
  UCHAR Identifier[1];
} STORAGE_IDENTIFIER, *PSTORAGE_IDENTIFIER;

typedef struct _STORAGE_DEVICE_ID_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  ULONG NumberOfIdentifiers;
  UCHAR Identifiers[1];
} STORAGE_DEVICE_ID_DESCRIPTOR, *PSTORAGE_DEVICE_ID_DESCRIPTOR;

typedef struct _DEVICE_SEEK_PENALTY_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  BOOLEAN IncursSeekPenalty;
} DEVICE_SEEK_PENALTY_DESCRIPTOR, *PDEVICE_SEEK_PENALTY_DESCRIPTOR;

typedef struct _DEVICE_WRITE_AGGREGATION_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  BOOLEAN BenefitsFromWriteAggregation;
} DEVICE_WRITE_AGGREGATION_DESCRIPTOR, *PDEVICE_WRITE_AGGREGATION_DESCRIPTOR;

typedef struct _DEVICE_TRIM_DESCRIPTOR {
  ULONG Version;
  ULONG Size;
  BOOLEAN TrimEnabled;
} DEVICE_TRIM_DESCRIPTOR, *PDEVICE_TRIM_DESCRIPTOR;

typedef ULONG DEVICE_DATA_MANAGEMENT_SET_ACTION;

typedef struct _DEVICE_DATA_SET_RANGE {
  LONGLONG StartingOffset;
  ULONGLONG LengthInBytes;
} DEVICE_DATA_SET_RANGE, *PDEVICE_DATA_SET_RANGE;

typedef struct _DEVICE_MANAGE_DATA_SET_ATTRIBUTES {
  ULONG Size;
  DEVICE_DATA_MANAGEMENT_SET_ACTION Action;
  ULONG Flags;
  ULONG ParameterBlockOffset;
  ULONG ParameterBlockLength;
  ULONG DataSetRangesOffset;
  ULONG DataSetRangesLength;
} DEVICE_MANAGE_DATA_SET_ATTRIBUTES, *PDEVICE_MANAGE_DATA_SET_ATTRIBUTES;

typedef struct _DEVICE_DSM_NOTIFICATION_PARAMETERS {
  ULONG Size;
  ULONG Flags;
  ULONG NumFileTypeIDs;
  GUID FileTypeID[1];
} DEVICE_DSM_NOTIFICATION_PARAMETERS, *PDEVICE_DSM_NOTIFICATION_PARAMETERS;

typedef struct _STORAGE_GET_BC_PROPERTIES_OUTPUT {
  ULONG MaximumRequestsPerPeriod;
  ULONG MinimumPeriod;
  ULONGLONG MaximumRequestSize;
  ULONG EstimatedTimePerRequest;
  ULONG NumOutStandingRequests;
  ULONGLONG RequestSize;
} STORAGE_GET_BC_PROPERTIES_OUTPUT, *PSTORAGE_GET_BC_PROPERTIES_OUTPUT;

typedef struct _STORAGE_ALLOCATE_BC_STREAM_INPUT {
  ULONG Version;
  ULONG RequestsPerPeriod;
  ULONG Period;
  BOOLEAN RetryFailures;
  BOOLEAN Discardable;
  BOOLEAN Reserved1[2];
  ULONG AccessType;
  ULONG AccessMode;
} STORAGE_ALLOCATE_BC_STREAM_INPUT, *PSTORAGE_ALLOCATE_BC_STREAM_INPUT;

typedef struct _STORAGE_ALLOCATE_BC_STREAM_OUTPUT {
  ULONGLONG RequestSize;
  ULONG NumOutStandingRequests;
} STORAGE_ALLOCATE_BC_STREAM_OUTPUT, *PSTORAGE_ALLOCATE_BC_STREAM_OUTPUT;

typedef struct _STORAGE_PRIORITY_HINT_SUPPORT {
  ULONG SupportFlags;
} STORAGE_PRIORITY_HINT_SUPPORT, *PSTORAGE_PRIORITY_HINT_SUPPORT;

#if defined(_MSC_EXTENSIONS) || defined(__GNUC__)

typedef struct _STORAGE_MEDIA_SERIAL_NUMBER_DATA {
  USHORT Reserved;
  USHORT SerialNumberLength;
  UCHAR SerialNumber[0];
} STORAGE_MEDIA_SERIAL_NUMBER_DATA, *PSTORAGE_MEDIA_SERIAL_NUMBER_DATA;

typedef struct _PERSISTENT_RESERVE_COMMAND {
  ULONG Version;
  ULONG Size;
  __C89_NAMELESS union {
    struct {
      UCHAR ServiceAction:5;
      UCHAR Reserved1:3;
      USHORT AllocationLength;
    } PR_IN;
    struct {
      UCHAR ServiceAction:5;
      UCHAR Reserved1:3;
      UCHAR Type:4;
      UCHAR Scope:4;
      UCHAR ParameterList[0];
    } PR_OUT;
  } DUMMYUNIONNAME;
} PERSISTENT_RESERVE_COMMAND, *PPERSISTENT_RESERVE_COMMAND;

#endif /* defined(_MSC_EXTENSIONS) */

typedef struct _STORAGE_READ_CAPACITY {
  ULONG Version;
  ULONG Size;
  ULONG BlockLength;
  LARGE_INTEGER NumberOfBlocks;
  LARGE_INTEGER DiskLength;
} STORAGE_READ_CAPACITY, *PSTORAGE_READ_CAPACITY;

typedef enum _WRITE_CACHE_TYPE {
  WriteCacheTypeUnknown,
  WriteCacheTypeNone,
  WriteCacheTypeWriteBack,
  WriteCacheTypeWriteThrough
} WRITE_CACHE_TYPE;

typedef enum _WRITE_CACHE_ENABLE {
  WriteCacheEnableUnknown,
  WriteCacheDisabled,
  WriteCacheEnabled
} WRITE_CACHE_ENABLE;

typedef enum _WRITE_CACHE_CHANGE {
  WriteCacheChangeUnknown,
  WriteCacheNotChangeable,
  WriteCacheChangeable
} WRITE_CACHE_CHANGE;

typedef enum _WRITE_THROUGH {
  WriteThroughUnknown,
  WriteThroughNotSupported,
  WriteThroughSupported
} WRITE_THROUGH;

typedef struct _STORAGE_WRITE_CACHE_PROPERTY {
  ULONG Version;
  ULONG Size;
  WRITE_CACHE_TYPE WriteCacheType;
  WRITE_CACHE_ENABLE WriteCacheEnabled;
  WRITE_CACHE_CHANGE WriteCacheChangeable;
  WRITE_THROUGH WriteThroughSupported;
  BOOLEAN FlushCacheSupported;
  BOOLEAN UserDefinedPowerProtection;
  BOOLEAN NVCacheEnabled;
} STORAGE_WRITE_CACHE_PROPERTY, *PSTORAGE_WRITE_CACHE_PROPERTY;

#ifdef __cplusplus
}
#endif

#endif /* _NTDDSTOR_H_ */
