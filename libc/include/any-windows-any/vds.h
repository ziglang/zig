/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VDS
#define _INC_VDS

#if (_WIN32_WINNT >= 0x0600)
#include <diskguid.h>
#include <winioctl.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GPT_PARTITION_NAME_LENGTH 36

  typedef GUID VDS_OBJECT_ID;
  typedef UINT64 VDS_PATH_ID;

  typedef enum _VDS_PARTITION_STYLE {
    VDS_PST_UNKNOWN   = 0,
    VDS_PST_MBR       = 1,
    VDS_PST_GPT       = 2 
  } VDS_PARTITION_STYLE;

  typedef enum tag_VDS_PARTITION_STYLE {
    VDS_PARTITION_STYLE_MBR,
    VDS_PARTITION_STYLE_GPT,
    VDS_PARTITION_STYLE_RAW 
  } __VDS_PARTITION_STYLE;

  typedef enum _VDS_ASYNC_OUTPUT_TYPE {
    VDS_ASYNCOUT_UNKNOWN             = 0,
    VDS_ASYNCOUT_CREATEVOLUME        = 1,
    VDS_ASYNCOUT_EXTENDVOLUME        = 2,
    VDS_ASYNCOUT_SHRINKVOLUME        = 3,
    VDS_ASYNCOUT_ADDVOLUMEPLEX       = 4,
    VDS_ASYNCOUT_BREAKVOLUMEPLEX     = 5,
    VDS_ASYNCOUT_REMOVEVOLUMEPLEX    = 6,
    VDS_ASYNCOUT_REPAIRVOLUMEPLEX    = 7,
    VDS_ASYNCOUT_RECOVERPACK         = 8,
    VDS_ASYNCOUT_REPLACEDISK         = 9,
    VDS_ASYNCOUT_CREATEPARTITION     = 10,
    VDS_ASYNCOUT_CLEAN               = 11,
    VDS_ASYNCOUT_CREATELUN           = 50,
    VDS_ASYNCOUT_ADDLUNPLEX          = 52,
    VDS_ASYNCOUT_REMOVELUNPLEX       = 53,
    VDS_ASYNCOUT_EXTENDLUN           = 54,
    VDS_ASYNCOUT_SHRINKLUN           = 55,
    VDS_ASYNCOUT_RECOVERLUN          = 56,
    VDS_ASYNCOUT_LOGINTOTARGET       = 60,
    VDS_ASYNCOUT_LOGOUTFROMTARGET    = 61,
    VDS_ASYNCOUT_CREATETARGET        = 62,
    VDS_ASYNCOUT_CREATEPORTALGROUP   = 63,
    VDS_ASYNCOUT_DELETETARGET        = 64,
    VDS_ASYNCOUT_ADDPORTAL           = 65,
    VDS_ASYNCOUT_REMOVEPORTAL        = 66,
    VDS_ASYNCOUT_DELETEPORTALGROUP   = 67,
    VDS_ASYNCOUT_FORMAT              = 101,
    VDS_ASYNCOUT_CREATE_VDISK        = 200,
    VDS_ASYNCOUT_ATTACH_VDISK        = 201,
    VDS_ASYNCOUT_COMPACT_VDISK       = 202,
    VDS_ASYNCOUT_MERGE_VDISK         = 203,
    VDS_ASYNCOUT_EXPAND_VDISK        = 204 
  } VDS_ASYNC_OUTPUT_TYPE;

  typedef enum _VDS_HEALTH {
    VDS_H_UNKNOWN                     = 0,
    VDS_H_HEALTHY                     = 1,
    VDS_H_REBUILDING                  = 2,
    VDS_H_STALE                       = 3,
    VDS_H_FAILING                     = 4,
    VDS_H_FAILING_REDUNDANCY          = 5,
    VDS_H_FAILED_REDUNDANCY           = 6,
    VDS_H_FAILED_REDUNDANCY_FAILING   = 7,
    VDS_H_FAILED                      = 8,
    VDS_H_REPLACED                    = 9,
    VDS_H_PENDING_FAILURE             = 10,
    VDS_H_DEGRADED                    = 11 
  } VDS_HEALTH;

  typedef enum _VDS_CONTROLLER_STATUS {
    VDS_CS_UNKNOWN     = 0,
    VDS_CS_ONLINE      = 1,
    VDS_CS_NOT_READY   = 2,
    VDS_CS_OFFLINE     = 4,
    VDS_CS_FAILED      = 5,
    VDS_CS_REMOVED     = 8 
  } VDS_CONTROLLER_STATUS;

  typedef enum _VDS_DISK_EXTENT_TYPE {
    VDS_DET_UNKNOWN    = 0,
    VDS_DET_FREE       = 1,
    VDS_DET_DATA       = 2,
    VDS_DET_OEM        = 3,
    VDS_DET_ESP        = 4,
    VDS_DET_MSR        = 5,
    VDS_DET_LDM        = 6,
    VDS_DET_CLUSTER    = 7,
    VDS_DET_UNUSABLE   = 0x7FFF 
  } VDS_DISK_EXTENT_TYPE;

  typedef enum _VDS_DISK_FLAG {
    VDS_DF_AUDIO_CD               = 0x1,
    VDS_DF_HOTSPARE               = 0x2,
    VDS_DF_RESERVE_CAPABLE        = 0x4,
    VDS_DF_MASKED                 = 0x8,
    VDS_DF_STYLE_CONVERTIBLE      = 0x10,
    VDS_DF_CLUSTERED              = 0x20,
    VDS_DF_READ_ONLY              = 0x40,
    VDS_DF_SYSTEM_DISK            = 0x80,
    VDS_DF_BOOT_DISK              = 0x100,
    VDS_DF_PAGEFILE_DISK          = 0x200,
    VDS_DF_HIBERNATIONFILE_DISK   = 0x400,
    VDS_DF_CRASHDUMP_DISK         = 0x800,
    VDS_DF_HAS_ARC_PATH           = 0x1000,
    VDS_DF_DYNAMIC                = 0x2000,
    VDS_DF_BOOT_FROM_DISK         = 0x4000,
    VDS_DF_CURRENT_READ_ONLY      = 0x8000 
  } VDS_DISK_FLAG;

  typedef enum _VDS_NOTIFICATION_TARGET_TYPE {
    VDS_NTT_UNKNOWN        = 0,
    VDS_NTT_PACK           = 10,
    VDS_NTT_VOLUME         = 11,
    VDS_NTT_DISK           = 13,
    VDS_NTT_PARTITION      = 60,
    VDS_NTT_DRIVE_LETTER   = 61,
    VDS_NTT_FILE_SYSTEM    = 62,
    VDS_NTT_MOUNT_POINT    = 63,
    VDS_NTT_SUB_SYSTEM     = 30,
    VDS_NTT_CONTROLLER     = 31,
    VDS_NTT_DRIVE          = 32,
    VDS_NTT_LUN            = 33,
    VDS_NTT_PORT           = 35,
    VDS_NTT_PORTAL         = 36,
    VDS_NTT_TARGET         = 37,
    VDS_NTT_PORTAL_GROUP   = 38,
    VDS_NTT_SERVICE        = 200 
  } VDS_NOTIFICATION_TARGET_TYPE;

  typedef enum _VDS_OBJECT_TYPE {
    VDS_OT_UNKNOWN        = 0,
    VDS_OT_PROVIDER       = 1,
    VDS_OT_PACK           = 10,
    VDS_OT_VOLUME         = 11,
    VDS_OT_VOLUME_PLEX    = 12,
    VDS_OT_DISK           = 13,
    VDS_OT_SUB_SYSTEM     = 30,
    VDS_OT_CONTROLLER     = 31,
    VDS_OT_DRIVE          = 32,
    VDS_OT_LUN            = 33,
    VDS_OT_LUN_PLEX       = 34,
    VDS_OT_PORT           = 35,
    VDS_OT_PORTAL         = 36,
    VDS_OT_TARGET         = 37,
    VDS_OT_PORTAL_GROUP   = 38,
    VDS_OT_STORAGE_POOL   = 39,
    VDS_OT_HBAPORT        = 90,
    VDS_OT_INIT_ADAPTER   = 91,
    VDS_OT_INIT_PORTAL    = 92,
    VDS_OT_ASYNC          = 100,
    VDS_OT_ENUM           = 101,
    VDS_OT_VDISK          = 200,
    VDS_OT_OPEN_VDISK     = 201 
  } VDS_OBJECT_TYPE;

  typedef enum _VDS_STORAGE_BUS_TYPE {
    VDSBusTypeUnknown = 0x00,
    VDSBusTypeScsi = 0x01,
    VDSBusTypeAtapi = 0x02,
    VDSBusTypeAta = 0x03,
    VDSBusType1394 = 0x04,
    VDSBusTypeSsa = 0x05,
    VDSBusTypeFibre = 0x06,
    VDSBusTypeUsb = 0x07,
    VDSBusTypeRAID = 0x08,
    VDSBusTypeiScsi = 0x09,
    VDSBusTypeMaxReserved = 0x7F
  } VDS_STORAGE_BUS_TYPE;

  typedef enum _VDS_DISK_STATUS {
    VDS_DS_UNKNOWN     = 0,
    VDS_DS_ONLINE      = 1,
    VDS_DS_NOT_READY   = 2,
    VDS_DS_NO_MEDIA    = 3,
    VDS_DS_OFFLINE     = 4,
    VDS_DS_FAILED      = 5,
    VDS_DS_MISSING     = 6 
  } VDS_DISK_STATUS;

  typedef enum _VDS_DRIVE_FLAG {
    VDS_DRF_HOTSPARE           = 0x1,
    VDS_DRF_ASSIGNED           = 0x2,
    VDS_DRF_UNASSIGNED         = 0x4,
    VDS_DRF_HOTSPARE_IN_USE    = 0x8,
    VDS_DRF_HOTSPARE_STANDBY   = 0x10 
  } VDS_DRIVE_FLAG;

  typedef enum _VDS_DRIVE_LETTER_FLAG {
    VDS_DLF_NON_PERSISTENT   = 0x1 
  } VDS_DRIVE_LETTER_FLAG;

  typedef enum _VDS_DRIVE_STATUS {
    VDS_DRS_UNKNOWN     = 0,
    VDS_DRS_ONLINE      = 1,
    VDS_DRS_NOT_READY   = 2,
    VDS_DRS_OFFLINE     = 4,
    VDS_DRS_FAILED      = 5,
    VDS_DRS_REMOVED     = 8 
  } VDS_DRIVE_STATUS;

  typedef enum _VDS_FILE_SYSTEM_FLAG {
    VDS_FSF_SUPPORT_FORMAT            = 0x1,
    VDS_FSF_SUPPORT_QUICK_FORMAT      = 0x2,
    VDS_FSF_SUPPORT_COMPRESS          = 0x4,
    VDS_FSF_SUPPORT_SPECIFY_LABEL     = 0x8,
    VDS_FSF_SUPPORT_MOUNT_POINT       = 0x10,
    VDS_FSF_SUPPORT_REMOVABLE_MEDIA   = 0x20,
    VDS_FSF_SUPPORT_EXTEND            = 0x40,
    VDS_FSF_ALLOCATION_UNIT_512       = 0x10000,
    VDS_FSF_ALLOCATION_UNIT_1K        = 0x20000,
    VDS_FSF_ALLOCATION_UNIT_2K        = 0x40000,
    VDS_FSF_ALLOCATION_UNIT_4K        = 0x80000,
    VDS_FSF_ALLOCATION_UNIT_8K        = 0x100000,
    VDS_FSF_ALLOCATION_UNIT_16K       = 0x200000,
    VDS_FSF_ALLOCATION_UNIT_32K       = 0x400000,
    VDS_FSF_ALLOCATION_UNIT_64K       = 0x800000,
    VDS_FSF_ALLOCATION_UNIT_128K      = 0x1000000,
    VDS_FSF_ALLOCATION_UNIT_256K      = 0x2000000 
  } VDS_FILE_SYSTEM_FLAG;

  typedef enum _VDS_FILE_SYSTEM_FORMAT_SUPPORT_FLAG {
    VDS_FSS_DEFAULT             = 0x00000001,
    VDS_FSS_PREVIOUS_REVISION   = 0x00000002,
    VDS_FSS_RECOMMENDED         = 0x00000004 
  } VDS_FILE_SYSTEM_FORMAT_SUPPORT_FLAG;

  typedef enum _VDS_FILE_SYSTEM_PROP_FLAG {
    VDS_FPF_COMPRESSED   = 0x1 
  } VDS_FILE_SYSTEM_PROP_FLAG;

  typedef enum _VDS_FILE_SYSTEM_TYPE {
    VDS_FST_UNKNOWN   = 0,
    VDS_FST_RAW       = 1,
    VDS_FST_FAT       = 2,
    VDS_FST_FAT32     = 3,
    VDS_FST_NTFS      = 4,
    VDS_FST_CDFS      = 5,
    VDS_FST_UDF       = 6,
    VDS_FST_EXFAT     = 7 
  } VDS_FILE_SYSTEM_TYPE;

  typedef enum _VDS_HBAPORT_SPEED_FLAG {
    VDS_HSF_UNKNOWN          = 0,
    VDS_HSF_1GBIT            = 0x1,
    VDS_HSF_2GBIT            = 0x2,
    VDS_HSF_10GBIT           = 0x4,
    VDS_HSF_4GBIT            = 0x8,
    VDS_HSF_NOT_NEGOTIATED   = 0x8000 
  } VDS_HBAPORT_SPEED_FLAG;

  typedef enum _VDS_HBAPORT_STATUS {
    VDS_HPS_UNKNOWN       = 1,
    VDS_HPS_ONLINE        = 2,
    VDS_HPS_OFFLINE       = 3,
    VDS_HPS_BYPASSED      = 4,
    VDS_HPS_DIAGNOSTICS   = 5,
    VDS_HPS_LINKDOWN      = 6,
    VDS_HPS_ERROR         = 7,
    VDS_HPS_LOOPBACK      = 8 
  } VDS_HBAPORT_STATUS;

  typedef enum _VDS_HBAPORT_TYPE {
    VDS_HPT_UNKNOWN      = 1,
    VDS_HPT_OTHER        = 2,
    VDS_HPT_NOTPRESENT   = 3,
    VDS_HPT_NPORT        = 5,
    VDS_HPT_NLPORT       = 6,
    VDS_HPT_FLPORT       = 7,
    VDS_HPT_FPORT        = 8,
    VDS_HPT_EPORT        = 9,
    VDS_HPT_GPORT        = 10,
    VDS_HPT_LPORT        = 20,
    VDS_HPT_PTP          = 21 
  } VDS_HBAPORT_TYPE;

  typedef enum _VDS_HWPROVIDER_TYPE {
    VDS_HWT_UNKNOWN         = 0,
    VDS_HWT_PCI_RAID        = 1,
    VDS_HWT_FIBRE_CHANNEL   = 2,
    VDS_HWT_ISCSI           = 3,
    VDS_HWT_SAS             = 4,
    VDS_HWT_HYBRID          = 5 
  } VDS_HWPROVIDER_TYPE;

  typedef enum _VDS_INTERCONNECT_ADDRESS_TYPE {
    VDS_IA_UNKNOWN = 0,
    VDS_IA_FCFS = 1,
    VDS_IA_FCPH = 2,
    VDS_IA_FCPH3 = 3,
    VDS_IA_MAC = 4,
    VDS_IA_SCSI = 5
  } VDS_INTERCONNECT_ADDRESS_TYPE;

  typedef enum VDS_IPADDRESS_TYPE {
    VDS_IPT_TEXT    = 0,
    VDS_IPT_IPV4    = 1,
    VDS_IPT_IPV6    = 2,
    VDS_IPT_EMPTY   = 3 
  } VDS_IPADDRESS_TYPE;

  typedef enum _VDS_ISCSI_AUTH_TYPE {
    VDS_IAT_NONE          = 0,
    VDS_IAT_CHAP          = 1,
    VDS_IAT_MUTUAL_CHAP   = 2 
  } VDS_ISCSI_AUTH_TYPE;

  typedef enum _VDS_ISCSI_LOGIN_FLAG {
    VDS_ILF_REQUIRE_IPSEC       = 0x1,
    VDS_ILF_MULTIPATH_ENABLED   = 0x2 
  } VDS_ISCSI_LOGIN_FLAG;

  typedef enum _VDS_ISCSI_LOGIN_TYPE {
    VDS_ILT_MANUAL       = 0,
    VDS_ILT_PERSISTENT   = 1,
    VDS_ILT_BOOT         = 2 
  } VDS_ISCSI_LOGIN_TYPE;

  typedef enum _VDS_ISCSI_PORTAL_STATUS {
    VDS_IPS_UNKNOWN     = 0,
    VDS_IPS_ONLINE      = 1,
    VDS_IPS_NOT_READY   = 2,
    VDS_IPS_OFFLINE     = 4,
    VDS_IPS_FAILED      = 5 
  } VDS_ISCSI_PORTAL_STATUS;

  typedef enum _VDS_LOADBALANCE_POLICY_ENUM {
    VDS_LBP_UNKNOWN                   = 0,
    VDS_LBP_FAILOVER                  = 1,
    VDS_LBP_ROUND_ROBIN               = 2,
    VDS_LBP_ROUND_ROBIN_WITH_SUBSET   = 3,
    VDS_LBP_DYN_LEAST_QUEUE_DEPTH     = 4,
    VDS_LBP_WEIGHTED_PATHS            = 5,
    VDS_LBP_LEAST_BLOCKS              = 6,
    VDS_LBP_VENDOR_SPECIFIC           = 7 
  } VDS_LOADBALANCE_POLICY_ENUM;

  typedef enum _VDS_LUN_FLAG {
    VDS_LF_LBN_REMAP_ENABLED               = 0x01,
    VDS_LF_READ_BACK_VERIFY_ENABLED        = 0x02,
    VDS_LF_WRITE_THROUGH_CACHING_ENABLED   = 0x04,
    VDS_LF_HARDWARE_CHECKSUM_ENABLED       = 0x08,
    VDS_LF_READ_CACHE_ENABLED              = 0x10,
    VDS_LF_WRITE_CACHE_ENABLED             = 0x20,
    VDS_LF_MEDIA_SCAN_ENABLED              = 0x40,
    VDS_LF_CONSISTENCY_CHECK_ENABLED       = 0x80,
    VDS_LF_SNAPSHOT                        = 0x100 
  } VDS_LUN_FLAG;

  typedef enum _VDS_LUN_PLEX_FLAG  {
    VDS_LPF_LBN_REMAP_ENABLED   = 0x1 
  } VDS_LUN_PLEX_FLAG;

  typedef enum _VDS_TRANSITION_STATE {
    VDS_TS_UNKNOWN       = 0,
    VDS_TS_STABLE        = 1,
    VDS_TS_EXTENDING     = 2,
    VDS_TS_SHRINKING     = 3,
    VDS_TS_RECONFIGING   = 4,
    VDS_TS_RESTRIPING    = 8 
  } VDS_TRANSITION_STATE;

  typedef enum _VDS_LUN_PLEX_STATUS {
    VDS_LPS_UNKNOWN     = 0,
    VDS_LPS_ONLINE      = 1,
    VDS_LPS_NOT_READY   = 2,
    VDS_LPS_OFFLINE     = 4,
    VDS_LPS_FAILED      = 5 
  } VDS_LUN_PLEX_STATUS;

  typedef enum _VDS_LUN_PLEX_TYPE {
    VDS_LPT_UNKNOWN   = 0,
    VDS_LPT_SIMPLE    = 10,
    VDS_LPT_SPAN      = 11,
    VDS_LPT_STRIPE    = 12,
    VDS_LPT_PARITY    = 14,
    VDS_LPT_RAID2     = 15,
    VDS_LPT_RAID3     = 16,
    VDS_LPT_RAID4     = 17,
    VDS_LPT_RAID5     = 18,
    VDS_LPT_RAID6     = 19,
    VDS_LPT_RAID03    = 21,
    VDS_LPT_RAID05    = 22,
    VDS_LPT_RAID10    = 23,
    VDS_LPT_RAID15    = 24,
    VDS_LPT_RAID30    = 25,
    VDS_LPT_RAID50    = 26,
    VDS_LPT_RAID53    = 28,
    VDS_LPT_RAID60    = 29 
  } VDS_LUN_PLEX_TYPE;

  typedef enum _VDS_LUN_STATUS {
    VDS_LS_UNKNOWN     = 0,
    VDS_LS_ONLINE      = 1,
    VDS_LS_NOT_READY   = 2,
    VDS_LS_OFFLINE     = 4,
    VDS_LS_FAILED      = 5 
  } VDS_LUN_STATUS;

  typedef enum _VDS_LUN_TYPE {
    VDS_LT_UNKNOWN              = 0,
    VDS_LT_DEFAULT              = 1,
    VDS_LT_FAULT_TOLERANT       = 2,
    VDS_LT_NON_FAULT_TOLERANT   = 3,
    VDS_LT_SIMPLE               = 10,
    VDS_LT_SPAN                 = 11,
    VDS_LT_STRIPE               = 12,
    VDS_LT_MIRROR               = 13,
    VDS_LT_PARITY               = 14,
    VDS_LT_RAID2                = 15,
    VDS_LT_RAID3                = 16,
    VDS_LT_RAID4                = 17,
    VDS_LT_RAID5                = 18,
    VDS_LT_RAID6                = 19,
    VDS_LT_RAID01               = 20,
    VDS_LT_RAID03               = 21,
    VDS_LT_RAID05               = 22,
    VDS_LT_RAID10               = 23,
    VDS_LT_RAID15               = 24,
    VDS_LT_RAID30               = 25,
    VDS_LT_RAID50               = 26,
    VDS_LT_RAID51               = 27,
    VDS_LT_RAID53               = 28,
    VDS_LT_RAID60               = 29,
    VDS_LT_RAID61               = 30 
  } VDS_LUN_TYPE;

  typedef enum _VDS_MAINTENANCE_OPERATION {
    BlinkLight   = 1,
    BeepAlarm    = 2,
    SpinDown     = 3,
    SpinUp       = 4,
    Ping         = 5 
  } VDS_MAINTENANCE_OPERATION;

  typedef enum _VDS_PACK_FLAG {
    VDS_PKF_FOREIGN        = 0x1,
    VDS_PKF_NOQUORUM       = 0x2,
    VDS_PKF_POLICY         = 0x4,
    VDS_PKF_CORRUPTED      = 0x8,
    VDS_PKF_ONLINE_ERROR   = 0x10 
  } VDS_PACK_FLAG;

  typedef enum _VDS_PACK_STATUS {
    VDS_PS_UNKNOWN   = 0,
    VDS_PS_ONLINE    = 1,
    VDS_PS_OFFLINE   = 4 
  } VDS_PACK_STATUS;

  typedef enum _VDS_PARTITION_FLAG {
    VDS_PTF_SYSTEM   = 0x1 
  } VDS_PARTITION_FLAG;

  typedef enum _VDS_PATH_STATUS {
    VDS_MPS_UNKNOWN   = 0,
    VDS_MPS_ONLINE    = 1,
    VDS_MPS_FAILED    = 5,
    VDS_MPS_STANDBY   = 7 
  } VDS_PATH_STATUS;

  typedef enum _VDS_PORT_STATUS {
    VDS_PRS_UNKNOWN     = 0,
    VDS_PRS_ONLINE      = 1,
    VDS_PRS_NOT_READY   = 2,
    VDS_PRS_OFFLINE     = 4,
    VDS_PRS_FAILED      = 5,
    VDS_PRS_REMOVED     = 8 
  } VDS_PORT_STATUS;

  typedef enum _VDS_PROVIDER_FLAG {
    VDS_PF_DYNAMIC                           = 0x00000001,
    VDS_PF_INTERNAL_HARDWARE_PROVIDER        = 0x00000002,
    VDS_PF_ONE_DISK_ONLY_PER_PACK            = 0x00000004,
    VDS_PF_ONE_PACK_ONLINE_ONLY              = 0x00000008,
    VDS_PF_VOLUME_SPACE_MUST_BE_CONTIGUOUS   = 0x00000010,
    VDS_PF_SUPPORT_DYNAMIC                   = 0x80000000,
    VDS_PF_SUPPORT_FAULT_TOLERANT            = 0x40000000,
    VDS_PF_SUPPORT_DYNAMIC_1394              = 0x20000000,
    VDS_PF_SUPPORT_MIRROR                    = 0x00000020,
    VDS_PF_SUPPORT_RAID5                     = 0x00000040 
  } VDS_PROVIDER_FLAG;

  typedef enum _VDS_PROVIDER_LBSUPPORT_FLAG {
    VDS_LBF_FAILOVER                  = 0x1,
    VDS_LBF_ROUND_ROBIN               = 0x2,
    VDS_LBF_ROUND_ROBIN_WITH_SUBSET   = 0x4,
    VDS_LBF_DYN_LEAST_QUEUE_DEPTH     = 0x8,
    VDS_LBF_WEIGHTED_PATHS            = 0x10,
    VDS_LBF_LEAST_BLOCKS              = 0x20,
    VDS_LBF_VENDOR_SPECIFIC           = 0x40 
  } VDS_PROVIDER_LBSUPPORT_FLAG;

  typedef enum _VDS_PROVIDER_TYPE {
    VDS_PT_UNKNOWN       = 0,
    VDS_PT_SOFTWARE      = 1,
    VDS_PT_HARDWARE      = 2,
    VDS_PT_VIRTUALDISK   = 3,
    VDS_PT_MAX           = 4 
  } VDS_PROVIDER_TYPE;

  typedef enum _VDS_QUERY_PROVIDER_FLAG {
    VDS_QUERY_SOFTWARE_PROVIDERS   = 0x1,
    VDS_QUERY_HARDWARE_PROVIDERS   = 0x2 
  } VDS_QUERY_PROVIDER_FLAG;

  typedef enum _VDS_SAN_POLICY {
    VDS_SP_UNKNOWN          = 0x0,
    VDS_SP_ONLINE           = 0x1,
    VDS_SP_OFFLINE_SHARED   = 0x2,
    VDS_SP_OFFLINE          = 0x3 
  } VDS_SAN_POLICY;

  typedef enum _VDS_SERVICE_FLAG {
    VDS_SVF_SUPPORT_DYNAMIC              = 0x1,
    VDS_SVF_SUPPORT_FAULT_TOLERANT       = 0x2,
    VDS_SVF_SUPPORT_GPT                  = 0x4,
    VDS_SVF_SUPPORT_DYNAMIC_1394         = 0x8,
    VDS_SVF_CLUSTER_SERVICE_CONFIGURED   = 0x10,
    VDS_SVF_AUTO_MOUNT_OFF               = 0x20,
    VDS_SVF_OS_UNINSTALL_VALID           = 0x40,
    VDS_SVF_EFI                          = 0x80,
    VDS_SVF_SUPPORT_MIRROR               = 0x100,
    VDS_SVF_SUPPORT_RAID5                = 0x200 
  } VDS_SERVICE_FLAG;

  typedef enum _VDS_STORAGE_IDENTIFIER_CODE_SET {
    VDSStorageIdCodeSetReserved = 0,
    VDSStorageIdCodeSetBinary = 1,
    VDSStorageIdCodeSetAscii = 2
  } VDS_STORAGE_IDENTIFIER_CODE_SET;

  typedef enum VDS_STORAGE_IDENTIFIER_TYPE {
    VDSStorageIdTypeVendorSpecific = 0,
    VDSStorageIdTypeVendorId = 1,
    VDSStorageIdTypeEUI64 = 2,
    VDSStorageIdTypeFCPHName = 3,
    VDSStorageIdTypeSCSINameString = 8
  } VDS_STORAGE_IDENTIFIER_TYPE;

  typedef enum _VDS_SUB_SYSTEM_FLAG {
    VDS_SF_LUN_MASKING_CAPABLE                = 0x1,
    VDS_SF_LUN_PLEXING_CAPABLE                = 0x2,
    VDS_SF_LUN_REMAPPING_CAPABLE              = 0x4,
    VDS_SF_DRIVE_EXTENT_CAPABLE               = 0x8,
    VDS_SF_HARDWARE_CHECKSUM_CAPABLE          = 0x10,
    VDS_SF_RADIUS_CAPABLE                     = 0x20,
    VDS_SF_READ_BACK_VERIFY_CAPABLE           = 0x40,
    VDS_SF_WRITE_THROUGH_CACHING_CAPABLE      = 0x80,
    VDS_SF_SUPPORTS_FAULT_TOLERANT_LUNS       = 0x200,
    VDS_SF_SUPPORTS_NON_FAULT_TOLERANT_LUNS   = 0x400,
    VDS_SF_SUPPORTS_SIMPLE_LUNS               = 0x800,
    VDS_SF_SUPPORTS_SPAN_LUNS                 = 0x1000,
    VDS_SF_SUPPORTS_STRIPE_LUNS               = 0x2000,
    VDS_SF_SUPPORTS_MIRROR_LUNS               = 0x4000,
    VDS_SF_SUPPORTS_PARITY_LUNS               = 0x8000,
    VDS_SF_SUPPORTS_AUTH_CHAP                 = 0x10000,
    VDS_SF_SUPPORTS_AUTH_MUTUAL_CHAP          = 0x20000,
    VDS_SF_SUPPORTS_SIMPLE_TARGET_CONFIG      = 0x40000,
    VDS_SF_SUPPORTS_LUN_NUMBER                = 0x80000,
    VDS_SF_SUPPORTS_MIRRORED_CACHE            = 0x100000,
    VDS_SF_READ_CACHING_CAPABLE               = 0x200000,
    VDS_SF_WRITE_CACHING_CAPABLE              = 0x400000,
    VDS_SF_MEDIA_SCAN_CAPABLE                 = 0x800000,
    VDS_SF_CONSISTENCY_CHECK_CAPABLE          = 0x1000000 
  } VDS_SUB_SYSTEM_FLAG;

  typedef enum _VDS_SUB_SYSTEM_STATUS {
    VDS_SSS_UNKNOWN             = 0,
    VDS_SSS_ONLINE              = 1,
    VDS_SSS_NOT_READY           = 2,
    VDS_SSS_OFFLINE             = 4,
    VDS_SSS_FAILED              = 5,
    VDS_SSS_PARTIALLY_MANAGED   = 9 
  } VDS_SUB_SYSTEM_STATUS;

  typedef enum _VDS_VERSION_SUPPORT_FLAG {
    VDS_VSF_1_0   = 0x1,
    VDS_VSF_1_1   = 0x2,
    VDS_VSF_2_0   = 0x4,
    VDS_VSF_2_1   = 0x8,
    VDS_VSF_3_0   = 0x10 
  } VDS_VERSION_SUPPORT_FLAG;

  typedef enum _VDS_VOLUME_FLAG {
    VDS_VF_SYSTEM_VOLUME                  = 0x1,
    VDS_VF_BOOT_VOLUME                    = 0x2,
    VDS_VF_ACTIVE                         = 0x4,
    VDS_VF_READONLY                       = 0x8,
    VDS_VF_HIDDEN                         = 0x10,
    VDS_VF_CAN_EXTEND                     = 0x20,
    VDS_VF_CAN_SHRINK                     = 0x40,
    VDS_VF_PAGEFILE                       = 0x80,
    VDS_VF_HIBERNATION                    = 0x100,
    VDS_VF_CRASHDUMP                      = 0x200,
    VDS_VF_INSTALLABLE                    = 0x400,
    VDS_VF_LBN_REMAP_ENABLED              = 0x800,
    VDS_VF_FORMATTING                     = 0x1000,
    VDS_VF_NOT_FORMATTABLE                = 0x2000,
    VDS_VF_NTFS_NOT_SUPPORTED             = 0x4000,
    VDS_VF_FAT32_NOT_SUPPORTED            = 0x8000,
    VDS_VF_FAT_NOT_SUPPORTED              = 0x10000,
    VDS_VF_NO_DEFAULT_DRIVE_LETTER        = 0x20000,
    VDS_VF_PERMANENTLY_DISMOUNTED         = 0x40000,
    VDS_VF_PERMANENT_DISMOUNT_SUPPORTED   = 0x80000,
    VDS_VF_SHADOW_COPY                    = 0x100000,
    VDS_VF_FVE_ENABLED                    = 0x200000,
    VDS_VF_DIRTY                          = 0x400000 
  } VDS_VOLUME_FLAG;

  typedef enum _VDS_VOLUME_PLEX_STATUS {
    VDS_VPS_UNKNOWN    = 0,
    VDS_VPS_ONLINE     = 1,
    VDS_VPS_NO_MEDIA   = 3,
    VDS_VPS_FAILED     = 5 
  } VDS_VOLUME_PLEX_STATUS;

  typedef enum _VDS_VOLUME_PLEX_TYPE {
    VDS_VPT_UNKNOWN   = 0,
    VDS_VPT_SIMPLE    = 10,
    VDS_VPT_SPAN      = 11,
    VDS_VPT_STRIPE    = 12,
    VDS_VPT_PARITY    = 14 
  } VDS_VOLUME_PLEX_TYPE;

  typedef enum _VDS_VOLUME_STATUS {
    VDS_VS_UNKNOWN    = 0,
    VDS_VS_ONLINE     = 1,
    VDS_VS_NO_MEDIA   = 3,
    VDS_VS_FAILED     = 5,
    VDS_VS_OFFLINE    = 4 
  } VDS_VOLUME_STATUS;

  typedef enum _VDS_VOLUME_TYPE {
    VDS_VT_UNKNOWN   = 0,
    VDS_VT_SIMPLE    = 10,
    VDS_VT_SPAN      = 11,
    VDS_VT_STRIPE    = 12,
    VDS_VT_MIRROR    = 13,
    VDS_VT_PARITY    = 14 
  } VDS_VOLUME_TYPE;

  typedef struct _VDS_PARTITION_INFO_GPT {
    GUID      partitionType;
    GUID      partitionId;
    ULONGLONG attributes;
    WCHAR     name[GPT_PARTITION_NAME_LENGTH];
  } VDS_PARTITION_INFO_GPT;

  typedef struct _CHANGE_ATTRIBUTES_PARAMETERS {
    VDS_PARTITION_STYLE style;
    __C89_NAMELESS union {
      struct {
	BOOLEAN bootIndicator;
      } MbrPartInfo;
      struct {
	ULONGLONG attributes;
      } GptPartInfo;
    };
  } CHANGE_ATTRIBUTES_PARAMETERS;

  typedef struct _CHANGE_PARTITION_TYPE_PARAMETERS {
    VDS_PARTITION_STYLE style;
    __C89_NAMELESS union {
      struct {
        BYTE partitionType;
      } MbrPartInfo;
      struct {
        GUID partitionType;
      } GptPartInfo;
    } ;
  } CHANGE_PARTITION_TYPE_PARAMETERS, *PCHANGE_PARTITION_TYPE_PARAMETERS;


  typedef struct _CREATE_PARTITION_PARAMETERS {
    VDS_PARTITION_STYLE style;
    __C89_NAMELESS union {
      struct {
	BYTE    partitionType;
	BOOLEAN bootIndicator;
      } MbrPartInfo;
      struct {
	GUID      partitionType;
	GUID      partitionId;
	ULONGLONG attributes;
	WCHAR     name[GPT_PARTITION_NAME_LENGTH];
      } GptPartInfo;
    };
  } CREATE_PARTITION_PARAMETERS;

  typedef struct _VDS_ASYNC_OUTPUT {
    VDS_ASYNC_OUTPUT_TYPE type;
    /*[switch(type)] */__C89_NAMELESS union {
      /*[case(VDS_ASYNCOUT_CREATEPARTITION)]*/
      struct {
	ULONGLONG     ullOffset;
	VDS_OBJECT_ID volumeId;
      } cp;
      /*[case(VDS_ASYNCOUT_CREATEVOLUME)]*/
      struct {
	IUnknown *pVolumeUnk;
      } cv;
      /*[case(VDS_ASYNCOUT_BREAKVOLUMEPLEX)]*/
      struct {
	IUnknown *pVolumeUnk;
      } bvp;
      /*[case(VDS_ASYNCOUT_CREATELUN)]*/
      struct {
	IUnknown *pLunUnk;
      } cl;
      /*[case(VDS_ASYNCOUT_CREATETARGET)]*/
      struct {
	IUnknown *pTargetUnk;
      } ct;
      /*[case(VDS_ASYNCOUT_CREATEPORTALGROUP)]*/
      struct {
	IUnknown *pPortalGroupUnk;
      } cpg;
      /*[case(VDS_ASYNCOUT_CREATE_VDISK)]*/
      struct {
	IUnknown *pVDiskUnk;
      } cvd;
    };
  }  VDS_ASYNC_OUTPUT;

#define VDS_NF_CONTROLLER_ARRIVE 103
#define VDS_NF_CONTROLLER_DEPART 104
#define VDS_NF_CONTROLLER_MODIFY 350
#define VDS_NF_CONTROLLER_REMOVED 351

  typedef struct _VDS_CONTROLLER_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID controllerId;
  } VDS_CONTROLLER_NOTIFICATION;

  typedef struct _VDS_CONTROLLER_PROP {
    VDS_OBJECT_ID         id;
    LPWSTR                pwszFriendlyName;
    LPWSTR                pwszIdentification;
    VDS_CONTROLLER_STATUS status;
    VDS_HEALTH            health;
    SHORT                 sNumberOfPorts;
  } VDS_CONTROLLER_PROP;

  typedef struct _VDS_DISK_EXTENT {
    VDS_OBJECT_ID        diskId;
    VDS_DISK_EXTENT_TYPE type;
    ULONGLONG            ullOffset;
    ULONGLONG            ullSize;
    VDS_OBJECT_ID        volumeId;
    VDS_OBJECT_ID        plexId;
    ULONG                memberIdx;
  } VDS_DISK_EXTENT, *PVDS_DISK_EXTENT;

  typedef struct _VDS_DISK_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID diskId;
  } VDS_DISK_NOTIFICATION;

  typedef struct _VDS_PACK_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID packId;
  } VDS_PACK_NOTIFICATION;

  typedef struct _VDS_VOLUME_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID volumeId;
    VDS_OBJECT_ID plexId;
    ULONG         ulPercentCompleted;
  } VDS_VOLUME_NOTIFICATION;

  typedef struct _VDS_PARTITION_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID diskId;
    ULONGLONG     ullOffset;
  } VDS_PARTITION_NOTIFICATION;

  typedef struct _VDS_DRIVE_LETTER_NOTIFICATION {
    ULONG         ulEvent;
    WCHAR         wcLetter;
    VDS_OBJECT_ID volumeId;
  } VDS_DRIVE_LETTER_NOTIFICATION;

  typedef struct _VDS_FILE_SYSTEM_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID volumeId;
    DWORD         dwPercentCompleted;
  } VDS_FILE_SYSTEM_NOTIFICATION;

  typedef struct _VDS_MOUNT_POINT_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID volumeId;
  } VDS_MOUNT_POINT_NOTIFICATION;

  typedef struct _VDS_SUB_SYSTEM_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID subSystemId;
  } VDS_SUB_SYSTEM_NOTIFICATION;

  typedef struct _VDS_DRIVE_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID driveId;
  } VDS_DRIVE_NOTIFICATION;

  typedef struct _VDS_LUN_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID LunId;
  } VDS_LUN_NOTIFICATION;

  typedef struct _VDS_PORT_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID portId;
  } VDS_PORT_NOTIFICATION;

  typedef struct _VDS_PORTAL_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID portalId;
  } VDS_PORTAL_NOTIFICATION;

  typedef struct _VDS_TARGET_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID targetId;
  } VDS_TARGET_NOTIFICATION;

  typedef struct _VDS_PORTAL_GROUP_NOTIFICATION {
    ULONG         ulEvent;
    VDS_OBJECT_ID portalGroupId;
  } VDS_PORTAL_GROUP_NOTIFICATION;

  typedef struct _VDS_NOTIFICATION {
    VDS_NOTIFICATION_TARGET_TYPE objectType;
    __C89_NAMELESS union {
      VDS_PACK_NOTIFICATION         Pack;
      VDS_DISK_NOTIFICATION         Disk;
      VDS_VOLUME_NOTIFICATION       Volume;
      VDS_PARTITION_NOTIFICATION    Partition;
      VDS_DRIVE_LETTER_NOTIFICATION Letter;
      VDS_FILE_SYSTEM_NOTIFICATION  FileSystem;
      VDS_MOUNT_POINT_NOTIFICATION  MountPoint;
      VDS_SUB_SYSTEM_NOTIFICATION   SubSystem;
      VDS_CONTROLLER_NOTIFICATION   Controller;
      VDS_DRIVE_NOTIFICATION        Drive;
      VDS_LUN_NOTIFICATION          Lun;
      VDS_PORT_NOTIFICATION         Port;
      VDS_PORTAL_NOTIFICATION       Portal;
      VDS_TARGET_NOTIFICATION       Target;
      VDS_PORTAL_GROUP_NOTIFICATION PortalGroup;
    };
  } VDS_NOTIFICATION;

  typedef enum _VDS_LUN_RESERVE_MODE {
    VDS_LRM_NONE = 0x00000000,
    VDS_LRM_EXCLUSIVE_RW = 0x00000001,
    VDS_LRM_EXCLUSIVE_RO = 0x00000002,
    VDS_LRM_SHARED_RO = 0x00000003,
    VDS_LRM_SHARED_RW = 0x00000004
  } VDS_LUN_RESERVE_MODE;

  typedef struct _VDS_DISK_PROP {
    VDS_OBJECT_ID        id;
    VDS_DISK_STATUS      status;
    VDS_LUN_RESERVE_MODE ReserveMode;
    VDS_HEALTH           health;
    DWORD                dwDeviceType;
    DWORD                dwMediaType;
    ULONGLONG            ullSize;
    ULONG                ulBytesPerSector;
    ULONG                ulSectorsPerTrack;
    ULONG                ulTracksPerCylinder;
    ULONG                ulFlags;
    VDS_STORAGE_BUS_TYPE BusType;
    VDS_PARTITION_STYLE  PartitionStyle;
    __C89_NAMELESS union {
      DWORD dwSignature;
      GUID  DiskGuid;
    };
    LPWSTR               pwszDiskAddress;
    LPWSTR               pwszName;
    LPWSTR               pwszFriendlyName;
    LPWSTR               pwszAdaptorName;
    LPWSTR               pwszDevicePath;
  } VDS_DISK_PROP, *PVDS_DISK_PROP;

  typedef struct _VDS_DRIVE_EXTENT {
    VDS_OBJECT_ID id;
    VDS_OBJECT_ID LunId;
    ULONGLONG     ullSize;
    WINBOOL       bUsed;
  } VDS_DRIVE_EXTENT;

#define VDS_NF_DRIVE_LETTER_FREE 201
#define VDS_NF_DRIVE_LETTER_ASSIGN 202

  typedef struct _VDS_DRIVE_LETTER_PROP {
    WCHAR         wcLetter;
    VDS_OBJECT_ID volumeId;
    ULONG         ulFlags;
    WINBOOL       bUsed;
  } VDS_DRIVE_LETTER_PROP, *PVDS_DRIVE_LETTER_PROP;

#define VDS_NF_DRIVE_ARRIVE 105
#define VDS_NF_DRIVE_DEPART 106
#define VDS_NF_DRIVE_MODIFY 107
#define VDS_NF_DRIVE_REMOVED 354

  typedef struct _VDS_DRIVE_PROP {
    VDS_OBJECT_ID    id;
    ULONGLONG        ullSize;
    LPWSTR           pwszFriendlyName;
    LPWSTR           pwszIdentification;
    ULONG            ulFlags;
    VDS_DRIVE_STATUS status;
    VDS_HEALTH       health;
    SHORT            sInternalBusNumber;
    SHORT            sSlotNumber;
  } VDS_DRIVE_PROP;

  typedef struct _VDS_FILE_SYSTEM_FORMAT_SUPPORT_PROP {
    ULONG  ulFlags;
    USHORT usRevision;
    ULONG  ulDefaultUnitAllocationSize;
    ULONG  rgulAllowedUnitAllocationSizes;
    WCHAR  wszName;
  } VDS_FILE_SYSTEM_FORMAT_SUPPORT_PROP, *PVDS_FILE_SYSTEM_FORMAT_SUPPORT_PROP;

#define VDS_NF_FILE_SYSTEM_MODIFY 203
#define VDS_NF_FILE_SYSTEM_FORMAT_PROGRESS 204

  typedef struct _VDS_FILE_SYSTEM_PROP {
    VDS_FILE_SYSTEM_TYPE type;
    VDS_OBJECT_ID        volumeId;
    ULONG                ulFlags;
    ULONGLONG            ullTotalAllocationUnits;
    ULONGLONG            ullAvailableAllocationUnits;
    ULONG                ulAllocationUnitSize;
    LPWSTR               pwszLabel;
  } VDS_FILE_SYSTEM_PROP, *PVDS_FILE_SYSTEM_PROP;

#define MAX_FS_NAME_SIZE 8

  typedef struct _VDS_FILE_SYSTEM_TYPE_PROP {
    VDS_FILE_SYSTEM_TYPE type;
    WCHAR                wszName[MAX_FS_NAME_SIZE];
    ULONG                ulFlags;
    ULONG                ulCompressionFlags;
    ULONG                ulMaxLableLength;
    LPWSTR               pwszIllegalLabelCharSet;
  } VDS_FILE_SYSTEM_TYPE_PROP, *PVDS_FILE_SYSTEM_TYPE_PROP;

  typedef struct _VDS_WWN {
    UCHAR rguchWwn[8];
  } VDS_WWN;

  typedef struct _VDS_HBAPORT_PROP {
    VDS_OBJECT_ID      id;
    VDS_WWN            wwnNode;
    VDS_WWN            wwnPort;
    VDS_HBAPORT_TYPE   type;
    VDS_HBAPORT_STATUS status;
    ULONG              ulPortSpeed;
    ULONG              ulSupportedPortSpeed;
  } VDS_HBAPORT_PROP;

#define VDS_HINT_FASTCRASHRECOVERYREQUIRED   0x0000000000000001ULL
#define VDS_HINT_MOSTLYREADS                 0x0000000000000002ULL
#define VDS_HINT_OPTIMIZEFORSEQUENTIALREADS  0x0000000000000004ULL
#define VDS_HINT_OPTIMIZEFORSEQUENTIALWRITES 0x0000000000000008ULL
#define VDS_HINT_READBACKVERIFYENABLED       0x0000000000000010ULL
#define VDS_HINT_REMAPENABLED                0x0000000000000020ULL
#define VDS_HINT_WRITETHROUGHCACHINGENABLED  0x0000000000000040ULL
#define VDS_HINT_HARDWARECHECKSUMENABLED     0x0000000000000080ULL
#define VDS_HINT_ISYANKABLE                  0x0000000000000100ULL
#define VDS_HINT_ALLOCATEHOTSPARE            0x0000000000000200ULL
#define VDS_HINT_BUSTYPE                     0x0000000000000400ULL
#define VDS_HINT_USEMIRROREDCACHE            0x0000000000000800ULL
#define VDS_HINT_READCACHINGENABLED          0x0000000000001000ULL
#define VDS_HINT_WRITECACHINGENABLED         0x0000000000002000ULL
#define VDS_HINT_MEDIASCANENABLED            0x0000000000004000ULL
#define VDS_HINT_CONSISTENCYCHECKENABLED     0x0000000000008000ULL

  typedef struct _VDS_HINTS {
    ULONGLONG ullHintMask;
    ULONGLONG ullExpectedMaximumSize;
    ULONG     ulOptimalReadSize;
    ULONG     ulOptimalReadAlignment;
    ULONG     ulOptimalWriteSize;
    ULONG     ulOptimalWriteAlignment;
    ULONG     ulMaximumDriveCount;
    ULONG     ulStripeSize;
    WINBOOL   bFastCrashRecoveryRequired;
    WINBOOL   bMostlyReads;
    WINBOOL   bOptimizeForSequentialReads;
    WINBOOL   bOptimizeForSequentialWrites;
    WINBOOL   bRemapEnabled;
    WINBOOL   bReadBackVerifyEnabled;
    WINBOOL   bWriteThroughCachingEnabled;
    WINBOOL   bHardwareChecksumEnabled;
    WINBOOL   bIsYankable;
    SHORT     sRebuildPriority;
  } VDS_HINTS, *PVDS_HINTS;

  typedef struct _VDS_INPUT_DISK {
    VDS_OBJECT_ID diskId;
    ULONGLONG     ullSize;
    VDS_OBJECT_ID plexId;
    ULONG         memberIdx;
  } VDS_INPUT_DISK;

  typedef struct _VDS_IPADDRESS {
    VDS_IPADDRESS_TYPE type;
    ULONG              ipv4Address;
    UCHAR              ipv6Address[16];
    ULONG              ulIpv6FlowInfo;
    ULONG              ulIpv6ScopeId;
    WCHAR              wszTextAddress[256 + 1];
    ULONG              ulPort;
  } VDS_IPADDRESS;

  typedef struct _VDS_ISCSI_INITIATOR_ADAPTER_PROP {
    VDS_OBJECT_ID id;
    LPWSTR        pwszName;
  } VDS_ISCSI_INITIATOR_ADAPTER_PROP;

  typedef struct _VDS_ISCSI_INITIATOR_PORTAL_PROP {
    VDS_OBJECT_ID id;
    VDS_IPADDRESS address;
    ULONG         ulPortIndex;
  } VDS_ISCSI_INITIATOR_PORTAL_PROP;

  typedef struct _VDS_ISCSI_PORTAL_PROP {
    VDS_OBJECT_ID           id;
    VDS_IPADDRESS           address;
    VDS_ISCSI_PORTAL_STATUS status;
  } VDS_ISCSI_PORTAL_PROP;

  typedef USHORT VDS_ISCSI_PORTALGROUP_TAG;

  typedef struct _VDS_ISCSI_PORTALGROUP_PROP {
    VDS_OBJECT_ID             id;
    VDS_ISCSI_PORTALGROUP_TAG tag;
  } VDS_ISCSI_PORTALGROUP_PROP;

  typedef struct _VDS_ISCSI_SHARED_SECRET {
    UCHAR *pSharedSecret;
    ULONG ulSharedSecretSize;
  } VDS_ISCSI_SHARED_SECRET;

  typedef struct _VDS_ISCSI_TARGET_PROP {
    VDS_OBJECT_ID id;
    LPWSTR        pwszIscsiName;
    LPWSTR        pwszFriendlyName;
    WINBOOL       bChapEnabled;
  } VDS_ISCSI_TARGET_PROP;

  typedef struct _VDS_STORAGE_IDENTIFIER {
    VDS_STORAGE_IDENTIFIER_CODE_SET m_CodeSet;
    VDS_STORAGE_IDENTIFIER_TYPE m_Type;
    ULONG m_cbIdentifier;
    BYTE* m_rgbIdentifier;
  } VDS_STORAGE_IDENTIFIER;

  typedef struct _VDS_STORAGE_DEVICE_ID_DESCRIPTOR {
    ULONG m_version;
    ULONG m_cIdentifiers;
    VDS_STORAGE_IDENTIFIER* m_rgIdentifiers;
  } VDS_STORAGE_DEVICE_ID_DESCRIPTOR;

#define VDS_NF_LUN_ARRIVE 108
#define VDS_NF_LUN_DEPART 109
#define VDS_NF_LUN_MODIFY 110

  typedef struct _VDS_LUN_PLEX_PROP {
    VDS_OBJECT_ID        id;
    ULONGLONG            ullSize;
    VDS_LUN_PLEX_TYPE    type;
    VDS_LUN_PLEX_STATUS  status;
    VDS_HEALTH           health;
    VDS_TRANSITION_STATE TransitionState;
    ULONG                ulFlags;
    ULONG                ulStripeSize;
    SHORT                sRebuildPriority;
  } VDS_LUN_PLEX_PROP;

  typedef struct _VDS_LUN_PROP {
    VDS_OBJECT_ID        id;
    ULONGLONG            ullSize;
    LPWSTR               pwszFriendlyName;
    LPWSTR               pwszIdentification;
    LPWSTR               pwszUnmaskingList;
    ULONG                ulFlags;
    VDS_LUN_TYPE         type;
    VDS_LUN_STATUS       status;
    VDS_HEALTH           health;
    VDS_TRANSITION_STATE TransitionState;
    SHORT                sRebuildPriority;
  } VDS_LUN_PROP, *PVDS_LUN_PROP;

#define VDS_NF_MOUNT_POINTS_CHANGE 205

#define VDS_NF_PACK_ARRIVE 1
#define VDS_NF_PACK_DEPART 2
#define VDS_NF_PACK_MODIFY 3

  typedef struct _VDS_PACK_PROP {
    VDS_OBJECT_ID   id;
    LPWSTR          pwszName;
    VDS_PACK_STATUS status;
    ULONG           ulFlags;
  } VDS_PACK_PROP, *PVDS_PACK_PROP;

  typedef struct _VDS_PARTITION_INFO_MBR {
    BYTE    partitionType;
    BOOLEAN bootIndicator;
    BOOLEAN recognizedPartition;
    DWORD   hiddenSectors;
  } VDS_PARTITION_INFO_MBR;

#define VDS_NF_PARTITION_ARRIVE 11
#define VDS_NF_PARTITION_DEPART 12
#define VDS_NF_PARTITION_MODIFY 13

  typedef struct _VDS_PARTITION_PROP {
    VDS_PARTITION_STYLE PartitionStyle;
    ULONG               ulFlags;
    ULONG               ulPartitionNumber;
    ULONGLONG           ullOffset;
    ULONGLONG           ullSize;
    __C89_NAMELESS union {
      VDS_PARTITION_INFO_MBR Mbr;
      VDS_PARTITION_INFO_GPT Gpt;
    };
  } VDS_PARTITION_PROP;

  typedef struct _VDS_PATH_INFO {
    VDS_PATH_ID         pathId;
    VDS_HWPROVIDER_TYPE type;
    VDS_PATH_STATUS     status;
    __C89_NAMELESS union {
      VDS_OBJECT_ID controllerPortId;
      VDS_OBJECT_ID targetPortalId;
    };
    __C89_NAMELESS union {
      VDS_OBJECT_ID hbaPortId;
      VDS_OBJECT_ID initiatorAdapterId;
    };
    __C89_NAMELESS union {
      VDS_HBAPORT_PROP *pHbaPortProp;
      VDS_IPADDRESS    *pInitiatorPortalIpAddr;
    };
  } VDS_PATH_INFO;

  typedef struct _VDS_PATH_POLICY {
    VDS_PATH_ID pathId;
    BOOL        bPrimaryPath;
    ULONG       ulWeight;
  } VDS_PATH_POLICY;

#define VDS_NF_PORT_ARRIVE 121
#define VDS_NF_PORT_DEPART 122
#define VDS_NF_PORT_MODIFY 352
#define VDS_NF_PORT_REMOVED 353

  typedef struct _VDS_PORT_PROP {
    VDS_OBJECT_ID   id;
    LPWSTR          pwszFriendlyName;
    LPWSTR          pwszIdentification;
    VDS_PORT_STATUS status;
  } VDS_PORT_PROP;

#define VDS_NF_PORTAL_GROUP_ARRIVE 129
#define VDS_NF_PORTAL_GROUP_DEPART 130
#define VDS_NF_PORTAL_GROUP_MODIFY 131
#define VDS_NF_PORTAL_ARRIVE 123
#define VDS_NF_PORTAL_DEPART 124
#define VDS_NF_PORTAL_MODIFY 125

  typedef struct _VDS_PROVIDER_PROP {
    VDS_OBJECT_ID     id;
    LPWSTR            pwszName;
    GUID              guidVersionId;
    LPWSTR            pwszVersion;
    VDS_PROVIDER_TYPE type;
    ULONG             ulFlags;
    ULONG             ulStripeSizeFlags;
    SHORT             sRebuildPriority;
  } VDS_PROVIDER_PROP;

  typedef struct VDS_REPARSE_POINT_PROP {
    VDS_OBJECT_ID SourceVolumeId;
    LPWSTR        pwszPath;
  } VDS_REPARSE_POINT_PROP, *PVDS_REPARSE_POINT_PROP;

  typedef struct _VDS_SERVICE_PROP {
    LPWSTR pwszVersion;
    ULONG  ulFlags;
  } VDS_SERVICE_PROP;

#define VDS_NF_SUB_SYSTEM_ARRIVE 101
#define VDS_NF_SUB_SYSTEM_DEPART 102
#define VDS_NF_SUB_SYSTEM_MODIFY 151

  typedef struct _VDS_SUB_SYSTEM_PROP {
    VDS_OBJECT_ID         id;
    LPWSTR                pwszFriendlyName;
    LPWSTR                pwszIdentification;
    ULONG                 ulFlags;
    ULONG                 ulStripeSizeFlags;
    VDS_SUB_SYSTEM_STATUS status;
    VDS_HEALTH            health;
    SHORT                 sNumberOfInternalBuses;
    SHORT                 sMaxNumberOfSlotsEachBus;
    SHORT                 sMaxNumberOfControllers;
    SHORT                 sRebuildPriority;
  } VDS_SUB_SYSTEM_PROP;

#define VDS_NF_TARGET_ARRIVE 126
#define VDS_NF_TARGET_DEPART 127
#define VDS_NF_TARGET_MODIFY 128
#define VDS_NF_VOLUME_ARRIVE 4
#define VDS_NF_VOLUME_DEPART 5
#define VDS_NF_VOLUME_MODIFY 6
#define VDS_NF_VOLUME_REBUILDING 7

  typedef struct _VDS_VOLUME_PLEX_PROP {
    VDS_OBJECT_ID          id;
    VDS_VOLUME_PLEX_TYPE   type;
    VDS_VOLUME_PLEX_STATUS status;
    VDS_HEALTH             health;
    VDS_TRANSITION_STATE   TransitionState;
    ULONGLONG              ullSize;
    ULONG                  ulStripeSize;
    ULONG                  ulNumberOfMembers;
  } VDS_VOLUME_PLEX_PROP, *PVDS_VOLUME_PLEX_PROP;

  typedef struct _VDS_VOLUME_PROP {
    VDS_OBJECT_ID        id;
    VDS_VOLUME_TYPE      type;
    VDS_VOLUME_STATUS    status;
    VDS_HEALTH           health;
    VDS_TRANSITION_STATE TransitionState;
    ULONGLONG            ullSize;
    ULONG                ulFlags;
    VDS_FILE_SYSTEM_TYPE RecommendedFileSystemType;
    LPWSTR               pwszName;
  } VDS_VOLUME_PROP, *PVDS_VOLUME_PROP;

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/

#include <vdslun.h>

#if (_WIN32_WINNT >= 0x0601)
#ifdef __cplusplus
extern "C" {
#endif
typedef enum _VDS_DISK_OFFLINE_REASON {
  VDSDiskOfflineReasonNone            = 0,
  VDSDiskOfflineReasonPolicy          = 1,
  VDSDiskOfflineReasonRedundantPath   = 2,
  VDSDiskOfflineReasonSnapshot        = 3,
  VDSDiskOfflineReasonCollision       = 4 
} VDS_DISK_OFFLINE_REASON;

typedef enum _VDS_STORAGE_POOL_STATUS {
  VDS_SPS_UNKNOWN     = 0,
  VDS_SPS_ONLINE      = 1,
  VDS_SPS_NOT_READY   = 2,
  VDS_SPS_OFFLINE     = 4 
} VDS_STORAGE_POOL_STATUS;

typedef enum _VDS_SUB_SYSTEM_SUPPORTED_RAID_TYPE_FLAG {
  VDS_SF_SUPPORTS_RAID2_LUNS    = 0x1,
  VDS_SF_SUPPORTS_RAID3_LUNS    = 0x2,
  VDS_SF_SUPPORTS_RAID4_LUNS    = 0x4,
  VDS_SF_SUPPORTS_RAID5_LUNS    = 0x8,
  VDS_SF_SUPPORTS_RAID6_LUNS    = 0x10,
  VDS_SF_SUPPORTS_RAID01_LUNS   = 0x20,
  VDS_SF_SUPPORTS_RAID03_LUNS   = 0x40,
  VDS_SF_SUPPORTS_RAID05_LUNS   = 0x80,
  VDS_SF_SUPPORTS_RAID10_LUNS   = 0x100,
  VDS_SF_SUPPORTS_RAID15_LUNS   = 0x200,
  VDS_SF_SUPPORTS_RAID30_LUNS   = 0x400,
  VDS_SF_SUPPORTS_RAID50_LUNS   = 0x800,
  VDS_SF_SUPPORTS_RAID51_LUNS   = 0x1000,
  VDS_SF_SUPPORTS_RAID53_LUNS   = 0x2000,
  VDS_SF_SUPPORTS_RAID60_LUNS   = 0x4000,
  VDS_SF_SUPPORTS_RAID61_LUNS   = 0x8000 
} VDS_SUB_SYSTEM_SUPPORTED_RAID_TYPE_FLAG;

typedef enum VDS_FORMAT_OPTION_FLAGS {
  VDS_FSOF_NONE                 = 0x00000000,
  VDS_FSOF_FORCE                = 0x00000001,
  VDS_FSOF_QUICK                = 0x00000002,
  VDS_FSOF_COMPRESSION          = 0x00000004,
  VDS_FSOF_DUPLICATE_METADATA   = 0x00000008 
} VDS_FORMAT_OPTION_FLAGS;

typedef enum _VDS_INTERCONNECT_FLAG {
  VDS_ITF_PCI_RAID        = 0x1,
  VDS_ITF_FIBRE_CHANNEL   = 0x2,
  VDS_ITF_ISCSI           = 0x4,
  VDS_ITF_SAS             = 0x8 
} VDS_INTERCONNECT_FLAG;

typedef enum _VDS_RAID_TYPE {
  VDS_RT_UNKNOWN   = 0,
  VDS_RT_RAID0     = 10,
  VDS_RT_RAID1     = 11,
  VDS_RT_RAID2     = 12,
  VDS_RT_RAID3     = 13,
  VDS_RT_RAID4     = 14,
  VDS_RT_RAID5     = 15,
  VDS_RT_RAID6     = 16,
  VDS_RT_RAID01    = 17,
  VDS_RT_RAID03    = 18,
  VDS_RT_RAID05    = 19,
  VDS_RT_RAID10    = 20,
  VDS_RT_RAID15    = 21,
  VDS_RT_RAID30    = 22,
  VDS_RT_RAID50    = 23,
  VDS_RT_RAID51    = 24,
  VDS_RT_RAID53    = 25,
  VDS_RT_RAID60    = 26,
  VDS_RT_RAID61    = 27 
} VDS_RAID_TYPE;

typedef enum _VDS_STORAGE_POOL_TYPE {
  VDS_SPT_UNKNOWN      = 0,
  VDS_SPT_PRIMORDIAL   = 0x1,
  VDS_SPT_CONCRETE     = 0x2 
} VDS_STORAGE_POOL_TYPE;

typedef enum _VDS_VDISK_STATE {
  VDS_VST_UNKNOWN             = 0,
  VDS_VST_ADDED               = 1,
  VDS_VST_OPEN                = 2,
  VDS_VST_ATTACH_PENDING      = 3,
  VDS_VST_ATTACHED_NOT_OPEN   = 4,
  VDS_VST_ATTACHED            = 5,
  VDS_VST_DETACH_PENDING      = 6,
  VDS_VST_COMPACTING          = 7,
  VDS_VST_MERGING             = 8,
  VDS_VST_EXPANDING           = 9,
  VDS_VST_DELETED             = 10,
  VDS_VST_MAX                 = 11 
} VDS_VDISK_STATE;

typedef struct _VDS_CREATE_VDISK_PARAMETERS {
  GUID      UniqueId;
  ULONGLONG MaximumSize;
  ULONG     BlockSizeInBytes;
  ULONG     SectorSizeInBytes;
  LPWSTR    pParentPath;
  LPWSTR    pSourcePath;
} VDS_CREATE_VDISK_PARAMETERS, *PVDS_CREATE_VDISK_PARAMETERS;

typedef struct _VDS_DISK_FREE_EXTENT {
  VDS_OBJECT_ID diskId;
  ULONGLONG     ullOffset;
  ULONGLONG     ullSize;
} VDS_DISK_FREE_EXTENT, *PVDS_DISK_FREE_EXTENT;

typedef struct _VDS_DISK_PROP2 {
  VDS_OBJECT_ID           id;
  VDS_DISK_STATUS         status;
  VDS_DISK_OFFLINE_REASON OfflineReason;
  VDS_LUN_RESERVE_MODE    ReserveMode;
  VDS_HEALTH              health;
  DWORD                   dwDeviceType;
  DWORD                   dwMediaType;
  ULONGLONG               ullSize;
  ULONG                   ulBytesPerSector;
  ULONG                   ulSectorsPerTrack;
  ULONG                   ulTracksPerCylinder;
  ULONG                   ulFlags;
  VDS_STORAGE_BUS_TYPE    BusType;
  VDS_PARTITION_STYLE     PartitionStyle;
  __C89_NAMELESS union {
    DWORD dwSignature;
    GUID  DiskGuid;
  };
  LPWSTR                  pwszDiskAddress;
  LPWSTR                  pwszName;
  LPWSTR                  pwszFriendlyName;
  LPWSTR                  pwszAdaptorName;
  LPWSTR                  pwszDevicePath;
  LPWSTR                  pwszLocationPath;
} VDS_DISK_PROP2, *PVDS_DISK_PROP2;

typedef struct _VDS_DRIVE_PROP2 {
  VDS_OBJECT_ID        id;
  ULONGLONG            ullSize;
  LPWSTR               pwszFriendlyName;
  LPWSTR               pwszIdentification;
  ULONG                ulFlags;
  VDS_DRIVE_STATUS     status;
  VDS_HEALTH           health;
  SHORT                sInternalBusNumber;
  SHORT                sSlotNumber;
  ULONG                ulEnclosureNumber;
  VDS_STORAGE_BUS_TYPE busType;
  ULONG                ulSpindleSpeed;
} VDS_DRIVE_PROP2, *PVDS_DRIVE_PROP2;

typedef struct _VDS_HINTS2 {
  ULONGLONG            ullHintMask;
  ULONGLONG            ullExpectedMaximumSize;
  ULONG                ulOptimalReadSize;
  ULONG                ulOptimalReadAlignment;
  ULONG                ulOptimalWriteSize;
  ULONG                ulOptimalWriteAlignment;
  ULONG                ulMaximumDriveCount;
  ULONG                ulStripeSize;
  ULONG                ulReserved1;
  ULONG                ulReserved2;
  ULONG                ulReserved3;
  WINBOOL              bFastCrashRecoveryRequired;
  WINBOOL              bMostlyReads;
  WINBOOL              bOptimizeForSequentialReads;
  WINBOOL              bOptimizeForSequentialWrites;
  WINBOOL              bRemapEnabled;
  WINBOOL              bReadBackVerifyEnabled;
  WINBOOL              bWriteThroughCachingEnabled;
  WINBOOL              bHardwareChecksumEnabled;
  WINBOOL              bIsYankable;
  WINBOOL              bAllocateHotSpare;
  WINBOOL              bUseMirroredCache;
  WINBOOL              bReadCachingEnabled;
  WINBOOL              bWriteCachingEnabled;
  WINBOOL              bMediaScanEnabled;
  WINBOOL              bConsistencyCheckEnabled;
  VDS_STORAGE_BUS_TYPE BusType;
  WINBOOL              bReserved1;
  WINBOOL              bReserved2;
  WINBOOL              bReserved3;
  SHORT                sRebuildPriority;
} VDS_HINTS2, *PVDS_HINTS2;

typedef struct _VDS_POOL_CUSTOM_ATTRIBUTES {
  LPWSTR pwszName;
  LPWSTR pwszValue;
} VDS_POOL_CUSTOM_ATTRIBUTES, *PVDS_POOL_CUSTOM_ATTRIBUTES;

typedef struct _VDS_POOL_ATTRIBUTES {
  ULONGLONG                  ullAttributeMask;
  VDS_RAID_TYPE              raidType;
  VDS_STORAGE_BUS_TYPE       busType;
  LPWSTR                     pwszIntendedUsage;
  WINBOOL                    bSpinDown;
  WINBOOL                    bIsThinProvisioned;
  ULONGLONG                  ullProvisionedSpace;
  WINBOOL                    bNoSinglePointOfFailure;
  ULONG                      ulDataRedundancyMax;
  ULONG                      ulDataRedundancyMin;
  ULONG                      ulDataRedundancyDefault;
  ULONG                      ulPackageRedundancyMax;
  ULONG                      ulPackageRedundancyMin;
  ULONG                      ulPackageRedundancyDefault;
  ULONG                      ulStripeSize;
  ULONG                      ulStripeSizeMax;
  ULONG                      ulStripeSizeMin;
  ULONG                      ulDefaultStripeSize;
  ULONG                      ulNumberOfColumns;
  ULONG                      ulNumberOfColumnsMax;
  ULONG                      ulNumberOfColumnsMin;
  ULONG                      ulDefaultNumberofColumns;
  ULONG                      ulDataAvailabilityHint;
  ULONG                      ulAccessRandomnessHint;
  ULONG                      ulAccessDirectionHint;
  ULONG                      ulAccessSizeHint;
  ULONG                      ulAccessLatencyHint;
  ULONG                      ulAccessBandwidthWeightHint;
  ULONG                      ulStorageCostHint;
  ULONG                      ulStorageEfficiencyHint;
  ULONG                      ulNumOfCustomAttributes;
  VDS_POOL_CUSTOM_ATTRIBUTES *pPoolCustomAttributes;
  WINBOOL                    bReserved1;
  WINBOOL                    bReserved2;
  ULONG                      ulReserved1;
  ULONG                      ulReserved2;
  ULONGLONG                  ullReserved1;
  ULONGLONG                  ullReserved2;
} VDS_POOL_ATTRIBUTES, *PVDS_POOL_ATTRIBUTES;

typedef struct _VDS_STORAGE_POOL_DRIVE_EXTENT {
  VDS_OBJECT_ID id;
  ULONGLONG     ullSize;
  WINBOOL       bUsed;
} VDS_STORAGE_POOL_DRIVE_EXTENT, *PVDS_STORAGE_POOL_DRIVE_EXTENT;

typedef struct _VDS_STORAGE_POOL_PROP {
  VDS_OBJECT_ID           id;
  VDS_STORAGE_POOL_STATUS status;
  VDS_HEALTH              health;
  VDS_STORAGE_POOL_TYPE   type;
  LPWSTR                  pwszName;
  LPWSTR                  pwszDescription;
  ULONGLONG               ullTotalConsumedSpace;
  ULONGLONG               ullTotalManagedSpace;
  ULONGLONG               ullRemainingFreeSpace;
} VDS_STORAGE_POOL_PROP, *PVDS_STORAGE_POOL_PROP;

typedef struct _VDS_SUB_SYSTEM_PROP2 {
  VDS_OBJECT_ID         id;
  LPWSTR                pwszFriendlyName;
  LPWSTR                pwszIdentification;
  ULONG                 ulFlags;
  ULONG                 ulStripeSizeFlags;
  ULONG                 ulSupportedRaidTypeFlags;
  VDS_SUB_SYSTEM_STATUS status;
  VDS_HEALTH            health;
  SHORT                 sNumberOfInternalBuses;
  SHORT                 sMaxNumberOfSlotsEachBus;
  SHORT                 sMaxNumberOfControllers;
  SHORT                 sRebuildPriority;
  ULONG                 ulNumberOfEnclosures;
} VDS_SUB_SYSTEM_PROP2, *PVDS_SUB_SYSTEM_PROP2;

typedef struct _VDS_VDISK_PROPERTIES {
  VDS_OBJECT_ID        Id;
  VDS_VDISK_STATE      State;
  VIRTUAL_STORAGE_TYPE VirtualDeviceType;
  ULONGLONG            VirtualSize;
  ULONGLONG            PhysicalSize;
  LPWSTR               pPath;
  LPWSTR               pDeviceName;
  DEPENDENT_DISK_FLAG  DiskFlag;
  WINBOOL              bIsChild;
  LPWSTR               pParentPath;
} VDS_VDISK_PROPERTIES, *PVDS_VDISK_PROPERTIES;

typedef struct _VDS_VOLUME_PROP2 {
  VDS_OBJECT_ID        id;
  VDS_VOLUME_TYPE      type;
  VDS_VOLUME_STATUS    status;
  VDS_HEALTH           health;
  VDS_TRANSITION_STATE TransitionState;
  ULONGLONG            ullSize;
  ULONG                ulFlags;
  VDS_FILE_SYSTEM_TYPE RecommendedFileSystemType;
  ULONG                cbUniqueId;
  LPWSTR               pwszName;
  BYTE                 *pUniqueId;
} VDS_VOLUME_PROP2, *PVDS_VOLUME_PROP2;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0601)*/

#endif /*_INC_VDS*/
