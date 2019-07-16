
#pragma once

#define _CLASS_

#include <ntdddisk.h>
#include <ntddcdrm.h>
#include <ntddtape.h>
#include <ntddscsi.h>
#include <ntddstor.h>

#include <stdio.h>

#include <scsi.h>

#define max(a,b) (((a) > (b)) ? (a) : (b))
#define min(a,b) (((a) < (b)) ? (a) : (b))

#define SRB_CLASS_FLAGS_LOW_PRIORITY      0x10000000
#define SRB_CLASS_FLAGS_PERSISTANT        0x20000000
#define SRB_CLASS_FLAGS_PAGING            0x40000000
#define SRB_CLASS_FLAGS_FREE_MDL          0x80000000

#define ASSERT_FDO(x) \
  ASSERT(((PCOMMON_DEVICE_EXTENSION) (x)->DeviceExtension)->IsFdo)

#define ASSERT_PDO(x) \
  ASSERT(!(((PCOMMON_DEVICE_EXTENSION) (x)->DeviceExtension)->IsFdo))

#define IS_CLEANUP_REQUEST(majorFunction)   \
  ((majorFunction == IRP_MJ_CLOSE) ||       \
   (majorFunction == IRP_MJ_CLEANUP) ||     \
   (majorFunction == IRP_MJ_SHUTDOWN))

#define DO_MCD(fdoExtension)                                 \
  (((fdoExtension)->MediaChangeDetectionInfo != NULL) &&     \
   ((fdoExtension)->MediaChangeDetectionInfo->MediaChangeDetectionDisableCount == 0))

#define IS_SCSIOP_READ(opCode)     \
  ((opCode == SCSIOP_READ6)   ||   \
   (opCode == SCSIOP_READ)    ||   \
   (opCode == SCSIOP_READ12)  ||   \
   (opCode == SCSIOP_READ16))

#define IS_SCSIOP_WRITE(opCode)     \
  ((opCode == SCSIOP_WRITE6)   ||   \
   (opCode == SCSIOP_WRITE)    ||   \
   (opCode == SCSIOP_WRITE12)  ||   \
   (opCode == SCSIOP_WRITE16))

#define IS_SCSIOP_READWRITE(opCode) (IS_SCSIOP_READ(opCode) || IS_SCSIOP_WRITE(opCode))

#define ADJUST_FUA_FLAG(fdoExt) {                                                       \
    if (TEST_FLAG(fdoExt->DeviceFlags, DEV_WRITE_CACHE) &&                              \
        !TEST_FLAG(fdoExt->DeviceFlags, DEV_POWER_PROTECTED) &&                         \
        !TEST_FLAG(fdoExt->ScanForSpecialFlags, CLASS_SPECIAL_FUA_NOT_SUPPORTED) ) {    \
        fdoExt->CdbForceUnitAccess = TRUE;                                              \
    } else {                                                                            \
        fdoExt->CdbForceUnitAccess = FALSE;                                             \
    }                                                                                   \
}

#define FREE_POOL(_PoolPtr)     \
    if (_PoolPtr != NULL) {     \
        ExFreePool(_PoolPtr);   \
        _PoolPtr = NULL;        \
    }

#ifdef POOL_TAGGING
#undef ExAllocatePool
#undef ExAllocatePoolWithQuota
#define ExAllocatePool(a,b) ExAllocatePoolWithTag(a,b,'nUcS')
//#define ExAllocatePool(a,b) #assert(0)
#define ExAllocatePoolWithQuota(a,b) ExAllocatePoolWithQuotaTag(a,b,'nUcS')
#endif

#define CLASS_TAG_AUTORUN_DISABLE           'ALcS'
#define CLASS_TAG_FILE_OBJECT_EXTENSION     'FLcS'
#define CLASS_TAG_MEDIA_CHANGE_DETECTION    'MLcS'
#define CLASS_TAG_MOUNT                     'mLcS'
#define CLASS_TAG_RELEASE_QUEUE             'qLcS'
#define CLASS_TAG_POWER                     'WLcS'
#define CLASS_TAG_WMI                       'wLcS'
#define CLASS_TAG_FAILURE_PREDICT           'fLcS'
#define CLASS_TAG_DEVICE_CONTROL            'OIcS'
#define CLASS_TAG_MODE_DATA                 'oLcS'
#define CLASS_TAG_MULTIPATH                 'mPcS'

#define MAXIMUM_RETRIES 4

#define CLASS_DRIVER_EXTENSION_KEY ((PVOID) ClassInitialize)

#define NO_REMOVE                         0
#define REMOVE_PENDING                    1
#define REMOVE_COMPLETE                   2

#define ClassAcquireRemoveLock(devobj, tag) \
  ClassAcquireRemoveLockEx(devobj, tag, __FILE__, __LINE__)

#ifdef TRY
#undef TRY
#endif
#ifdef LEAVE
#undef LEAVE
#endif

#ifdef FINALLY
#undef FINALLY
#endif

#define TRY
#define LEAVE             goto __tryLabel;
#define FINALLY           __tryLabel:

#if defined DebugPrint
#undef DebugPrint
#endif

#if DBG
#define DebugPrint(x) ClassDebugPrint x
#else
#define DebugPrint(x)
#endif

#define DEBUG_BUFFER_LENGTH                        256

#define START_UNIT_TIMEOUT                         (60 * 4)

#define MEDIA_CHANGE_DEFAULT_TIME                  1
#define MEDIA_CHANGE_TIMEOUT_TIME                  300

#define MAXIMUM_RETRY_FOR_SINGLE_IO_IN_100NS_UNITS 0x3b9aca00

#ifdef ALLOCATE_SRB_FROM_POOL

#define ClasspAllocateSrb(ext)                      \
  ExAllocatePoolWithTag(NonPagedPool,               \
                        sizeof(SCSI_REQUEST_BLOCK), \
                        'sBRS')

#define ClasspFreeSrb(ext, srb) ExFreePool((srb));

#else /* ALLOCATE_SRB_FROM_POOL */

#define ClasspAllocateSrb(ext)                      \
  ExAllocateFromNPagedLookasideList(                \
      &((ext)->CommonExtension.SrbLookasideList))

#define ClasspFreeSrb(ext, srb)                   \
  ExFreeToNPagedLookasideList(                    \
      &((ext)->CommonExtension.SrbLookasideList), \
      (srb))

#endif /* ALLOCATE_SRB_FROM_POOL */

#define SET_FLAG(Flags, Bit)    ((Flags) |= (Bit))
#define CLEAR_FLAG(Flags, Bit)  ((Flags) &= ~(Bit))
#define TEST_FLAG(Flags, Bit)   (((Flags) & (Bit)) != 0)

#define CLASS_WORKING_SET_MAXIMUM                         2048

#define CLASS_INTERPRET_SENSE_INFO2_MAXIMUM_HISTORY_COUNT 30000

#define CLASS_SPECIAL_DISABLE_SPIN_DOWN                 0x00000001
#define CLASS_SPECIAL_DISABLE_SPIN_UP                   0x00000002
#define CLASS_SPECIAL_NO_QUEUE_LOCK                     0x00000008
#define CLASS_SPECIAL_DISABLE_WRITE_CACHE               0x00000010
#define CLASS_SPECIAL_CAUSE_NOT_REPORTABLE_HACK         0x00000020
#if ((NTDDI_VERSION == NTDDI_WIN2KSP3) || (OSVER(NTDDI_VERSION) == NTDDI_WINXP))
#define CLASS_SPECIAL_DISABLE_WRITE_CACHE_NOT_SUPPORTED 0x00000040
#endif
#define CLASS_SPECIAL_MODIFY_CACHE_UNSUCCESSFUL         0x00000040
#define CLASS_SPECIAL_FUA_NOT_SUPPORTED                 0x00000080
#define CLASS_SPECIAL_VALID_MASK                        0x000000FB
#define CLASS_SPECIAL_RESERVED         (~CLASS_SPECIAL_VALID_MASK)

#define DEV_WRITE_CACHE                                 0x00000001
#define DEV_USE_SCSI1                                   0x00000002
#define DEV_SAFE_START_UNIT                             0x00000004
#define DEV_NO_12BYTE_CDB                               0x00000008
#define DEV_POWER_PROTECTED                             0x00000010
#define DEV_USE_16BYTE_CDB                              0x00000020

#define GUID_CLASSPNP_QUERY_REGINFOEX {0x00e34b11, 0x2444, 0x4745, {0xa5, 0x3d, 0x62, 0x01, 0x00, 0xcd, 0x82, 0xf7}}
#define GUID_CLASSPNP_SENSEINFO2      {0x509a8c5f, 0x71d7, 0x48f6, {0x82, 0x1e, 0x17, 0x3c, 0x49, 0xbf, 0x2f, 0x18}}
#define GUID_CLASSPNP_WORKING_SET     {0x105701b0, 0x9e9b, 0x47cb, {0x97, 0x80, 0x81, 0x19, 0x8a, 0xf7, 0xb5, 0x24}}

#define DEFAULT_FAILURE_PREDICTION_PERIOD 60 * 60 * 1

static inline ULONG CountOfSetBitsUChar(UCHAR _X)
{ ULONG i = 0; while (_X) { _X &= _X - 1; i++; } return i; }
static inline ULONG CountOfSetBitsULong(ULONG _X)
{ ULONG i = 0; while (_X) { _X &= _X - 1; i++; } return i; }
static inline ULONG CountOfSetBitsULong32(ULONG32 _X)
{ ULONG i = 0; while (_X) { _X &= _X - 1; i++; } return i; }
static inline ULONG CountOfSetBitsULong64(ULONG64 _X)
{ ULONG i = 0; while (_X) { _X &= _X - 1; i++; } return i; }
static inline ULONG CountOfSetBitsUlongPtr(ULONG_PTR _X)
{ ULONG i = 0; while (_X) { _X &= _X - 1; i++; } return i; }

typedef enum _MEDIA_CHANGE_DETECTION_STATE {
  MediaUnknown,
  MediaPresent,
  MediaNotPresent,
  MediaUnavailable
} MEDIA_CHANGE_DETECTION_STATE, *PMEDIA_CHANGE_DETECTION_STATE;

typedef enum _CLASS_DEBUG_LEVEL {
  ClassDebugError = 0,
  ClassDebugWarning = 1,
  ClassDebugTrace = 2,
  ClassDebugInfo = 3,
  ClassDebugMediaLocks = 8,
  ClassDebugMCN = 9,
  ClassDebugDelayedRetry = 10,
  ClassDebugSenseInfo = 11,
  ClassDebugRemoveLock = 12,
  ClassDebugExternal4 = 13,
  ClassDebugExternal3 = 14,
  ClassDebugExternal2 = 15,
  ClassDebugExternal1 = 16
} CLASS_DEBUG_LEVEL, *PCLASS_DEBUG_LEVEL;

typedef enum {
  EventGeneration,
  DataBlockCollection
} CLASSENABLEDISABLEFUNCTION;

typedef enum {
  FailurePredictionNone = 0,
  FailurePredictionIoctl,
  FailurePredictionSmart,
  FailurePredictionSense
} FAILURE_PREDICTION_METHOD, *PFAILURE_PREDICTION_METHOD;

typedef enum {
  PowerDownDeviceInitial,
  PowerDownDeviceLocked,
  PowerDownDeviceStopped,
  PowerDownDeviceOff,
  PowerDownDeviceUnlocked
} CLASS_POWER_DOWN_STATE;

typedef enum {
  PowerDownDeviceInitial2,
  PowerDownDeviceLocked2,
  PowerDownDeviceFlushed2,
  PowerDownDeviceStopped2,
  PowerDownDeviceOff2,
  PowerDownDeviceUnlocked2
} CLASS_POWER_DOWN_STATE2;

typedef enum {
  PowerUpDeviceInitial,
  PowerUpDeviceLocked,
  PowerUpDeviceOn,
  PowerUpDeviceStarted,
  PowerUpDeviceUnlocked
} CLASS_POWER_UP_STATE;

struct _CLASS_INIT_DATA;
typedef struct _CLASS_INIT_DATA CLASS_INIT_DATA, *PCLASS_INIT_DATA;

struct _CLASS_PRIVATE_FDO_DATA;
typedef struct _CLASS_PRIVATE_FDO_DATA CLASS_PRIVATE_FDO_DATA, *PCLASS_PRIVATE_FDO_DATA;

struct _CLASS_PRIVATE_PDO_DATA;
typedef struct _CLASS_PRIVATE_PDO_DATA CLASS_PRIVATE_PDO_DATA, *PCLASS_PRIVATE_PDO_DATA;

struct _CLASS_PRIVATE_COMMON_DATA;
typedef struct _CLASS_PRIVATE_COMMON_DATA CLASS_PRIVATE_COMMON_DATA, *PCLASS_PRIVATE_COMMON_DATA;

struct _MEDIA_CHANGE_DETECTION_INFO;
typedef struct _MEDIA_CHANGE_DETECTION_INFO MEDIA_CHANGE_DETECTION_INFO, *PMEDIA_CHANGE_DETECTION_INFO;

typedef struct _DICTIONARY {
  ULONGLONG Signature;
  struct _DICTIONARY_HEADER* List;
  KSPIN_LOCK SpinLock;
} DICTIONARY, *PDICTIONARY;

typedef struct _CLASSPNP_SCAN_FOR_SPECIAL_INFO {
  PCHAR VendorId;
  PCHAR ProductId;
  PCHAR ProductRevision;
  ULONG_PTR Data;
} CLASSPNP_SCAN_FOR_SPECIAL_INFO, *PCLASSPNP_SCAN_FOR_SPECIAL_INFO;

typedef VOID
(NTAPI *PCLASS_ERROR)(
  PDEVICE_OBJECT DeviceObject,
  PSCSI_REQUEST_BLOCK Srb,
  NTSTATUS *Status,
  BOOLEAN *Retry);

typedef NTSTATUS
(NTAPI *PCLASS_ADD_DEVICE)(
  PDRIVER_OBJECT DriverObject,
  PDEVICE_OBJECT Pdo);

typedef NTSTATUS
(NTAPI *PCLASS_POWER_DEVICE)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

typedef NTSTATUS
(NTAPI *PCLASS_START_DEVICE)(
  PDEVICE_OBJECT DeviceObject);

typedef NTSTATUS
(NTAPI *PCLASS_STOP_DEVICE)(
  PDEVICE_OBJECT DeviceObject,
  UCHAR Type);

typedef NTSTATUS
(NTAPI *PCLASS_INIT_DEVICE)(
  PDEVICE_OBJECT DeviceObject);

typedef NTSTATUS
(NTAPI *PCLASS_ENUM_DEVICE)(
  PDEVICE_OBJECT DeviceObject);

typedef NTSTATUS
(NTAPI *PCLASS_READ_WRITE)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

typedef NTSTATUS
(NTAPI *PCLASS_DEVICE_CONTROL)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

typedef NTSTATUS
(NTAPI *PCLASS_SHUTDOWN_FLUSH)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

typedef NTSTATUS
(NTAPI *PCLASS_CREATE_CLOSE)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

typedef NTSTATUS
(NTAPI *PCLASS_QUERY_ID)(
  PDEVICE_OBJECT DeviceObject,
  BUS_QUERY_ID_TYPE IdType,
  PUNICODE_STRING IdString);

typedef NTSTATUS
(NTAPI *PCLASS_REMOVE_DEVICE)(
  PDEVICE_OBJECT DeviceObject,
  UCHAR Type);

typedef VOID
(NTAPI *PCLASS_UNLOAD)(
  PDRIVER_OBJECT DriverObject);

typedef NTSTATUS
(NTAPI *PCLASS_QUERY_PNP_CAPABILITIES)(
  PDEVICE_OBJECT PhysicalDeviceObject,
  PDEVICE_CAPABILITIES Capabilities);

typedef VOID
(NTAPI *PCLASS_TICK)(
  PDEVICE_OBJECT DeviceObject);

typedef NTSTATUS
(NTAPI *PCLASS_QUERY_WMI_REGINFO_EX)(
  PDEVICE_OBJECT DeviceObject,
  ULONG *RegFlags,
  PUNICODE_STRING Name,
  PUNICODE_STRING MofResouceName);

typedef NTSTATUS
(NTAPI *PCLASS_QUERY_WMI_REGINFO)(
  PDEVICE_OBJECT DeviceObject,
  ULONG *RegFlags,
  PUNICODE_STRING Name);

typedef NTSTATUS
(NTAPI *PCLASS_QUERY_WMI_DATABLOCK)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG GuidIndex,
  ULONG BufferAvail,
  PUCHAR Buffer);

typedef NTSTATUS
(NTAPI *PCLASS_SET_WMI_DATABLOCK)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG GuidIndex,
  ULONG BufferSize,
  PUCHAR Buffer);

typedef NTSTATUS
(NTAPI *PCLASS_SET_WMI_DATAITEM)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG GuidIndex,
  ULONG DataItemId,
  ULONG BufferSize,
  PUCHAR Buffer);

typedef NTSTATUS
(NTAPI *PCLASS_EXECUTE_WMI_METHOD)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG GuidIndex,
  ULONG MethodId,
  ULONG InBufferSize,
  ULONG OutBufferSize,
  PUCHAR Buffer);

typedef NTSTATUS
(NTAPI *PCLASS_WMI_FUNCTION_CONTROL)(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG GuidIndex,
  CLASSENABLEDISABLEFUNCTION Function,
  BOOLEAN Enable);

typedef struct _SRB_HISTORY_ITEM {
  LARGE_INTEGER TickCountSent;
  LARGE_INTEGER TickCountCompleted;
  ULONG MillisecondsDelayOnRetry;
  SENSE_DATA NormalizedSenseData;
  UCHAR SrbStatus;
  UCHAR ClassDriverUse;
} SRB_HISTORY_ITEM, *PSRB_HISTORY_ITEM;

typedef struct _SRB_HISTORY {
  ULONG_PTR ClassDriverUse[4];
  ULONG TotalHistoryCount;
  ULONG UsedHistoryCount;
  SRB_HISTORY_ITEM History[1];
} SRB_HISTORY, *PSRB_HISTORY;

typedef BOOLEAN
(NTAPI *PCLASS_INTERPRET_SENSE_INFO)(
  PDEVICE_OBJECT Fdo,
  PIRP OriginalRequest,
  PSCSI_REQUEST_BLOCK Srb,
  UCHAR MajorFunctionCode,
  ULONG IoDeviceCode,
  ULONG PreviousRetryCount,
  SRB_HISTORY *RequestHistory,
  NTSTATUS *Status,
  LONGLONG *RetryIn100nsUnits);

typedef VOID
(NTAPI *PCLASS_COMPRESS_RETRY_HISTORY_DATA)(
  PDEVICE_OBJECT DeviceObject,
  PSRB_HISTORY RequestHistory);

typedef struct {
  GUID Guid;
  ULONG InstanceCount;
  ULONG Flags;
} GUIDREGINFO, *PGUIDREGINFO;

typedef struct _CLASS_WMI_INFO {
  ULONG GuidCount;
  PGUIDREGINFO GuidRegInfo;
  PCLASS_QUERY_WMI_REGINFO ClassQueryWmiRegInfo;
  PCLASS_QUERY_WMI_DATABLOCK ClassQueryWmiDataBlock;
  PCLASS_SET_WMI_DATABLOCK ClassSetWmiDataBlock;
  PCLASS_SET_WMI_DATAITEM ClassSetWmiDataItem;
  PCLASS_EXECUTE_WMI_METHOD ClassExecuteWmiMethod;
  PCLASS_WMI_FUNCTION_CONTROL ClassWmiFunctionControl;
} CLASS_WMI_INFO, *PCLASS_WMI_INFO;

typedef struct _CLASS_DEV_INFO {
  ULONG DeviceExtensionSize;
  DEVICE_TYPE DeviceType;
  UCHAR StackSize;
  ULONG DeviceCharacteristics;
  PCLASS_ERROR ClassError;
  PCLASS_READ_WRITE ClassReadWriteVerification;
  PCLASS_DEVICE_CONTROL ClassDeviceControl;
  PCLASS_SHUTDOWN_FLUSH ClassShutdownFlush;
  PCLASS_CREATE_CLOSE ClassCreateClose;
  PCLASS_INIT_DEVICE ClassInitDevice;
  PCLASS_START_DEVICE ClassStartDevice;
  PCLASS_POWER_DEVICE ClassPowerDevice;
  PCLASS_STOP_DEVICE ClassStopDevice;
  PCLASS_REMOVE_DEVICE ClassRemoveDevice;
  PCLASS_QUERY_PNP_CAPABILITIES ClassQueryPnpCapabilities;
  CLASS_WMI_INFO ClassWmiInfo;
} CLASS_DEV_INFO, *PCLASS_DEV_INFO;

struct _CLASS_INIT_DATA {
  ULONG InitializationDataSize;
  CLASS_DEV_INFO FdoData;
  CLASS_DEV_INFO PdoData;
  PCLASS_ADD_DEVICE ClassAddDevice;
  PCLASS_ENUM_DEVICE ClassEnumerateDevice;
  PCLASS_QUERY_ID ClassQueryId;
  PDRIVER_STARTIO ClassStartIo;
  PCLASS_UNLOAD ClassUnload;
  PCLASS_TICK ClassTick;
};

typedef struct _FILE_OBJECT_EXTENSION {
  PFILE_OBJECT FileObject;
  PDEVICE_OBJECT DeviceObject;
  ULONG LockCount;
  ULONG McnDisableCount;
} FILE_OBJECT_EXTENSION, *PFILE_OBJECT_EXTENSION;

typedef struct _CLASS_WORKING_SET {
  ULONG Size;
  ULONG XferPacketsWorkingSetMaximum;
  ULONG XferPacketsWorkingSetMinimum;
} CLASS_WORKING_SET, *PCLASS_WORKING_SET;

typedef struct _CLASS_INTERPRET_SENSE_INFO2 {
  ULONG Size;
  ULONG HistoryCount;
  PCLASS_COMPRESS_RETRY_HISTORY_DATA Compress;
  PCLASS_INTERPRET_SENSE_INFO Interpret;
} CLASS_INTERPRET_SENSE_INFO2, *PCLASS_INTERPRET_SENSE_INFO2;

C_ASSERT((MAXULONG - sizeof(SRB_HISTORY)) / 30000 >= sizeof(SRB_HISTORY_ITEM));

typedef struct _CLASS_DRIVER_EXTENSION {
  UNICODE_STRING RegistryPath;
  CLASS_INIT_DATA InitData;
  ULONG DeviceCount;
#if (NTDDI_VERSION >= NTDDI_WINXP)
  PCLASS_QUERY_WMI_REGINFO_EX ClassFdoQueryWmiRegInfoEx;
  PCLASS_QUERY_WMI_REGINFO_EX ClassPdoQueryWmiRegInfoEx;
#endif
#if (NTDDI_VERSION >= NTDDI_VISTA)
  REGHANDLE EtwHandle;
  PDRIVER_DISPATCH DeviceMajorFunctionTable[IRP_MJ_MAXIMUM_FUNCTION + 1];
  PDRIVER_DISPATCH MpDeviceMajorFunctionTable[IRP_MJ_MAXIMUM_FUNCTION + 1];
  PCLASS_INTERPRET_SENSE_INFO2 InterpretSenseInfo;
  PCLASS_WORKING_SET WorkingSet;
#endif
} CLASS_DRIVER_EXTENSION, *PCLASS_DRIVER_EXTENSION;

typedef struct _COMMON_DEVICE_EXTENSION {
  ULONG Version;
  PDEVICE_OBJECT DeviceObject;
  PDEVICE_OBJECT LowerDeviceObject;
  struct _FUNCTIONAL_DEVICE_EXTENSION *PartitionZeroExtension;
  PCLASS_DRIVER_EXTENSION DriverExtension;
  LONG RemoveLock;
  KEVENT RemoveEvent;
  KSPIN_LOCK RemoveTrackingSpinlock;
  PVOID RemoveTrackingList;
  LONG RemoveTrackingUntrackedCount;
  PVOID DriverData;
  _ANONYMOUS_STRUCT struct {
    BOOLEAN IsFdo:1;
    BOOLEAN IsInitialized:1;
    BOOLEAN IsSrbLookasideListInitialized:1;
  } DUMMYSTRUCTNAME;
  UCHAR PreviousState;
  UCHAR CurrentState;
  ULONG IsRemoved;
  UNICODE_STRING DeviceName;
  struct _PHYSICAL_DEVICE_EXTENSION *ChildList;
  ULONG PartitionNumber;
  LARGE_INTEGER PartitionLength;
  LARGE_INTEGER StartingOffset;
  PCLASS_DEV_INFO DevInfo;
  ULONG PagingPathCount;
  ULONG DumpPathCount;
  ULONG HibernationPathCount;
  KEVENT PathCountEvent;
#ifndef ALLOCATE_SRB_FROM_POOL
  NPAGED_LOOKASIDE_LIST SrbLookasideList;
#endif
  UNICODE_STRING MountedDeviceInterfaceName;
  ULONG GuidCount;
  PGUIDREGINFO GuidRegInfo;
  DICTIONARY FileObjectDictionary;
#if (NTDDI_VERSION >= NTDDI_WINXP)
  PCLASS_PRIVATE_COMMON_DATA PrivateCommonData;
#else
  ULONG_PTR Reserved1;
#endif
#if (NTDDI_VERSION >= NTDDI_VISTA)
  PDRIVER_DISPATCH *DispatchTable;
#else
  ULONG_PTR Reserved2;
#endif
  ULONG_PTR Reserved3;
  ULONG_PTR Reserved4;
} COMMON_DEVICE_EXTENSION, *PCOMMON_DEVICE_EXTENSION;

typedef struct _PHYSICAL_DEVICE_EXTENSION {
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      ULONG Version;
      PDEVICE_OBJECT DeviceObject;
    } DUMMYSTRUCTNAME;
    COMMON_DEVICE_EXTENSION CommonExtension;
  } DUMMYUNIONNAME;
  BOOLEAN IsMissing;
  BOOLEAN IsEnumerated;
#if (NTDDI_VERSION >= NTDDI_WINXP)
  PCLASS_PRIVATE_PDO_DATA PrivatePdoData;
#else
  ULONG_PTR Reserved1;
#endif
  ULONG_PTR Reserved2;
  ULONG_PTR Reserved3;
  ULONG_PTR Reserved4;
} PHYSICAL_DEVICE_EXTENSION, *PPHYSICAL_DEVICE_EXTENSION;

typedef struct _CLASS_POWER_OPTIONS {
  ULONG PowerDown:1;
  ULONG LockQueue:1;
  ULONG HandleSpinDown:1;
  ULONG HandleSpinUp:1;
  ULONG Reserved:27;
} CLASS_POWER_OPTIONS, *PCLASS_POWER_OPTIONS;

typedef struct _CLASS_POWER_CONTEXT {
  union {
    CLASS_POWER_DOWN_STATE PowerDown;
    CLASS_POWER_DOWN_STATE2 PowerDown2;
    CLASS_POWER_UP_STATE PowerUp;
  } PowerChangeState;
  CLASS_POWER_OPTIONS Options;
  BOOLEAN InUse;
  BOOLEAN QueueLocked;
  NTSTATUS FinalStatus;
  ULONG RetryCount;
  ULONG RetryInterval;
  PIO_COMPLETION_ROUTINE CompletionRoutine;
  PDEVICE_OBJECT DeviceObject;
  PIRP Irp;
  SCSI_REQUEST_BLOCK Srb;
} CLASS_POWER_CONTEXT, *PCLASS_POWER_CONTEXT;

typedef struct _COMPLETION_CONTEXT {
  PDEVICE_OBJECT DeviceObject;
  SCSI_REQUEST_BLOCK Srb;
} COMPLETION_CONTEXT, *PCOMPLETION_CONTEXT;

SCSIPORTAPI
ULONG
NTAPI
ClassInitialize(
  PVOID Argument1,
  PVOID Argument2,
  PCLASS_INIT_DATA InitializationData);

typedef struct _CLASS_QUERY_WMI_REGINFO_EX_LIST {
  ULONG Size;
  PCLASS_QUERY_WMI_REGINFO_EX ClassFdoQueryWmiRegInfoEx;
  PCLASS_QUERY_WMI_REGINFO_EX ClassPdoQueryWmiRegInfoEx;
} CLASS_QUERY_WMI_REGINFO_EX_LIST, *PCLASS_QUERY_WMI_REGINFO_EX_LIST;

typedef struct _FUNCTIONAL_DEVICE_EXTENSION {
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      ULONG Version;
      PDEVICE_OBJECT DeviceObject;
    } DUMMYSTRUCTNAME;
    COMMON_DEVICE_EXTENSION CommonExtension;
  } DUMMYUNIONNAME;
  PDEVICE_OBJECT LowerPdo;
  PSTORAGE_DEVICE_DESCRIPTOR DeviceDescriptor;
  PSTORAGE_ADAPTER_DESCRIPTOR AdapterDescriptor;
  DEVICE_POWER_STATE DevicePowerState;
  ULONG DMByteSkew;
  ULONG DMSkew;
  BOOLEAN DMActive;
  DISK_GEOMETRY DiskGeometry;
  PSENSE_DATA SenseData;
  ULONG TimeOutValue;
  ULONG DeviceNumber;
  ULONG SrbFlags;
  ULONG ErrorCount;
  LONG LockCount;
  LONG ProtectedLockCount;
  LONG InternalLockCount;
  KEVENT EjectSynchronizationEvent;
  USHORT DeviceFlags;
  UCHAR SectorShift;
#if (NTDDI_VERSION >= NTDDI_VISTA)
  UCHAR CdbForceUnitAccess;
#else
  UCHAR ReservedByte;
#endif
  PMEDIA_CHANGE_DETECTION_INFO MediaChangeDetectionInfo;
  PKEVENT Unused1;
  HANDLE Unused2;
  FILE_OBJECT_EXTENSION KernelModeMcnContext;
  ULONG MediaChangeCount;
  HANDLE DeviceDirectory;
  KSPIN_LOCK ReleaseQueueSpinLock;
  PIRP ReleaseQueueIrp;
  SCSI_REQUEST_BLOCK ReleaseQueueSrb;
  BOOLEAN ReleaseQueueNeeded;
  BOOLEAN ReleaseQueueInProgress;
  BOOLEAN ReleaseQueueIrpFromPool;
  BOOLEAN FailurePredicted;
  ULONG FailureReason;
  struct _FAILURE_PREDICTION_INFO* FailurePredictionInfo;
  BOOLEAN PowerDownInProgress;
  ULONG EnumerationInterlock;
  KEVENT ChildLock;
  PKTHREAD ChildLockOwner;
  ULONG ChildLockAcquisitionCount;
  ULONG ScanForSpecialFlags;
  KDPC PowerRetryDpc;
  KTIMER PowerRetryTimer;
  CLASS_POWER_CONTEXT PowerContext;

#if (NTDDI_VERSION <= NTDDI_WIN2K)

#if (SPVER(NTDDI_VERSION) < 2))
  ULONG_PTR Reserved1;
  ULONG_PTR Reserved2;
  ULONG_PTR Reserved3;
  ULONG_PTR Reserved4;
#else
  ULONG CompletionSuccessCount;
  ULONG SavedSrbFlags;
  ULONG SavedErrorCount;
  ULONG_PTR Reserved1;
#endif

#else /* (NTDDI_VERSION <= NTDDI_WIN2K) */

  PCLASS_PRIVATE_FDO_DATA PrivateFdoData;
  ULONG_PTR Reserved2;
  ULONG_PTR Reserved3;
  ULONG_PTR Reserved4;

#endif /* (NTDDI_VERSION <= NTDDI_WIN2K) */

} FUNCTIONAL_DEVICE_EXTENSION, *PFUNCTIONAL_DEVICE_EXTENSION;

SCSIPORTAPI
ULONG
NTAPI
ClassInitializeEx(
  PDRIVER_OBJECT DriverObject,
  LPGUID Guid,
  PVOID Data);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassCreateDeviceObject(
  PDRIVER_OBJECT DriverObject,
  PCCHAR ObjectNameBuffer,
  PDEVICE_OBJECT LowerDeviceObject,
  BOOLEAN IsFdo,
  PDEVICE_OBJECT *DeviceObject);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassReadDriveCapacity(
  PDEVICE_OBJECT DeviceObject);

SCSIPORTAPI
VOID
NTAPI
ClassReleaseQueue(
  PDEVICE_OBJECT DeviceObject);

SCSIPORTAPI
VOID
NTAPI
ClassSplitRequest(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  ULONG MaximumBytes);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassDeviceControl(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassIoComplete(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  PVOID Context);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassIoCompleteAssociated(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  PVOID Context);

SCSIPORTAPI
BOOLEAN
NTAPI
ClassInterpretSenseInfo(
  PDEVICE_OBJECT DeviceObject,
  PSCSI_REQUEST_BLOCK Srb,
  UCHAR MajorFunctionCode,
  ULONG IoDeviceCode,
  ULONG RetryCount,
  NTSTATUS *Status,
  ULONG *RetryInterval);

VOID
NTAPI
ClassSendDeviceIoControlSynchronous(
  ULONG IoControlCode,
  PDEVICE_OBJECT TargetDeviceObject,
  PVOID Buffer,
  ULONG InputBufferLength,
  ULONG OutputBufferLength,
  BOOLEAN InternalDeviceIoControl,
  PIO_STATUS_BLOCK IoStatus);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassSendIrpSynchronous(
  PDEVICE_OBJECT TargetDeviceObject,
  PIRP Irp);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassForwardIrpSynchronous(
  PCOMMON_DEVICE_EXTENSION CommonExtension,
  PIRP Irp);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassSendSrbSynchronous(
  PDEVICE_OBJECT DeviceObject,
  PSCSI_REQUEST_BLOCK Srb,
  PVOID BufferAddress,
  ULONG BufferLength,
  BOOLEAN WriteToDevice);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassSendSrbAsynchronous(
  PDEVICE_OBJECT DeviceObject,
  PSCSI_REQUEST_BLOCK Srb,
  PIRP Irp,
  PVOID BufferAddress,
  ULONG BufferLength,
  BOOLEAN WriteToDevice);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassBuildRequest(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

SCSIPORTAPI
ULONG
NTAPI
ClassModeSense(
  PDEVICE_OBJECT DeviceObject,
  PCHAR ModeSenseBuffer,
  ULONG Length,
  UCHAR PageMode);

SCSIPORTAPI
PVOID
NTAPI
ClassFindModePage(
  PCHAR ModeSenseBuffer,
  ULONG Length,
  UCHAR PageMode,
  BOOLEAN Use6Byte);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassClaimDevice(
  PDEVICE_OBJECT LowerDeviceObject,
  BOOLEAN Release);
  
SCSIPORTAPI
NTSTATUS
NTAPI
ClassInternalIoControl (
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

SCSIPORTAPI
VOID
NTAPI
ClassInitializeSrbLookasideList(
  PCOMMON_DEVICE_EXTENSION CommonExtension,
  ULONG NumberElements);

SCSIPORTAPI
VOID
NTAPI
ClassDeleteSrbLookasideList(
  PCOMMON_DEVICE_EXTENSION CommonExtension);

SCSIPORTAPI
ULONG
NTAPI
ClassQueryTimeOutRegistryValue(
  PDEVICE_OBJECT DeviceObject);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassGetDescriptor(
  PDEVICE_OBJECT DeviceObject,
  PSTORAGE_PROPERTY_ID PropertyId,
  PSTORAGE_DESCRIPTOR_HEADER *Descriptor);

SCSIPORTAPI
VOID
NTAPI
ClassInvalidateBusRelations(
  PDEVICE_OBJECT Fdo);

SCSIPORTAPI
VOID
NTAPI
ClassMarkChildrenMissing(
  PFUNCTIONAL_DEVICE_EXTENSION Fdo);

SCSIPORTAPI
BOOLEAN
NTAPI
ClassMarkChildMissing(
  PPHYSICAL_DEVICE_EXTENSION PdoExtension,
  BOOLEAN AcquireChildLock);

SCSIPORTAPI
VOID
ClassDebugPrint(
  CLASS_DEBUG_LEVEL DebugPrintLevel,
  PCCHAR DebugMessage,
  ...);

SCSIPORTAPI
PCLASS_DRIVER_EXTENSION
NTAPI
ClassGetDriverExtension(
  PDRIVER_OBJECT DriverObject);

SCSIPORTAPI
VOID
NTAPI
ClassCompleteRequest(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  CCHAR PriorityBoost);

SCSIPORTAPI
VOID
NTAPI
ClassReleaseRemoveLock(
  PDEVICE_OBJECT DeviceObject,
  PIRP Tag);

SCSIPORTAPI
ULONG
NTAPI
ClassAcquireRemoveLockEx(
  PDEVICE_OBJECT DeviceObject,
  PVOID Tag,
  PCSTR File,
  ULONG Line);

SCSIPORTAPI
VOID
NTAPI
ClassUpdateInformationInRegistry(
  PDEVICE_OBJECT Fdo,
  PCHAR DeviceName,
  ULONG DeviceNumber,
  PINQUIRYDATA InquiryData,
  ULONG InquiryDataLength);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassWmiCompleteRequest(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  NTSTATUS Status,
  ULONG BufferUsed,
  CCHAR PriorityBoost);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassWmiFireEvent(
  PDEVICE_OBJECT DeviceObject,
  LPGUID Guid,
  ULONG InstanceIndex,
  ULONG EventDataSize,
  PVOID EventData);

SCSIPORTAPI
VOID
NTAPI
ClassResetMediaChangeTimer(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

SCSIPORTAPI
VOID
NTAPI
ClassInitializeMediaChangeDetection(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PUCHAR EventPrefix);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassInitializeTestUnitPolling(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  BOOLEAN AllowDriveToSleep);

SCSIPORTAPI
PVPB
NTAPI
ClassGetVpb(
  PDEVICE_OBJECT DeviceObject);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassSpinDownPowerHandler(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

NTSTATUS
NTAPI
ClassStopUnitPowerHandler(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp);

NTSTATUS
NTAPI
ClassSetFailurePredictionPoll(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  FAILURE_PREDICTION_METHOD FailurePredictionMethod,
  ULONG PollingPeriod);

VOID
NTAPI
ClassNotifyFailurePredicted(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PUCHAR Buffer,
  ULONG BufferSize,
  BOOLEAN LogError,
  ULONG UniqueErrorValue,
  UCHAR PathId,
  UCHAR TargetId,
  UCHAR Lun);

SCSIPORTAPI
VOID
NTAPI
ClassAcquireChildLock(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

SCSIPORTAPI
VOID
NTAPI
ClassReleaseChildLock(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

NTSTATUS
NTAPI
ClassSignalCompletion(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  PKEVENT Event);

VOID
NTAPI
ClassSendStartUnit(
  PDEVICE_OBJECT DeviceObject);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassRemoveDevice(
  PDEVICE_OBJECT DeviceObject,
  UCHAR RemoveType);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassAsynchronousCompletion(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  PVOID Event);

SCSIPORTAPI
VOID
NTAPI
ClassCheckMediaState(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

SCSIPORTAPI
NTSTATUS
NTAPI
ClassCheckVerifyComplete(
  PDEVICE_OBJECT DeviceObject,
  PIRP Irp,
  PVOID Context);

SCSIPORTAPI
VOID
NTAPI
ClassSetMediaChangeState(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  MEDIA_CHANGE_DETECTION_STATE State,
  BOOLEAN Wait);

SCSIPORTAPI
VOID
NTAPI
ClassEnableMediaChangeDetection(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

SCSIPORTAPI
VOID
NTAPI
ClassDisableMediaChangeDetection(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

SCSIPORTAPI
VOID
NTAPI
ClassCleanupMediaChangeDetection(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension);

VOID
NTAPI
ClassGetDeviceParameter(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PWSTR SubkeyName,
  PWSTR ParameterName,
  PULONG ParameterValue);

NTSTATUS
NTAPI
ClassSetDeviceParameter(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PWSTR SubkeyName,
  PWSTR ParameterName,
  ULONG ParameterValue);

#if (NTDDI_VERSION >= NTDDI_VISTA)

PFILE_OBJECT_EXTENSION
NTAPI
ClassGetFsContext(
  PCOMMON_DEVICE_EXTENSION CommonExtension,
  PFILE_OBJECT FileObject);

VOID
NTAPI
ClassSendNotification(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  const GUID *Guid,
  ULONG ExtraDataSize,
  PVOID ExtraData);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

static __inline
BOOLEAN
PORT_ALLOCATED_SENSE(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PSCSI_REQUEST_BLOCK Srb)
{
  return ((BOOLEAN)((TEST_FLAG(Srb->SrbFlags, SRB_FLAGS_PORT_DRIVER_ALLOCSENSE) &&
          TEST_FLAG(Srb->SrbFlags, SRB_FLAGS_FREE_SENSE_BUFFER))                &&
          (Srb->SenseInfoBuffer != FdoExtension->SenseData)));
}

static __inline
VOID
FREE_PORT_ALLOCATED_SENSE_BUFFER(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  PSCSI_REQUEST_BLOCK Srb)
{
  ASSERT(TEST_FLAG(Srb->SrbFlags, SRB_FLAGS_PORT_DRIVER_ALLOCSENSE));
  ASSERT(TEST_FLAG(Srb->SrbFlags, SRB_FLAGS_FREE_SENSE_BUFFER));
  ASSERT(Srb->SenseInfoBuffer != FdoExtension->SenseData);

  ExFreePool(Srb->SenseInfoBuffer);
  Srb->SenseInfoBuffer = FdoExtension->SenseData;
  Srb->SenseInfoBufferLength = SENSE_BUFFER_SIZE;
  CLEAR_FLAG(Srb->SrbFlags, SRB_FLAGS_FREE_SENSE_BUFFER);
  return;
}

typedef VOID
(NTAPI *PCLASS_SCAN_FOR_SPECIAL_HANDLER)(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  ULONG_PTR Data);

VOID
NTAPI
ClassScanForSpecial(
  PFUNCTIONAL_DEVICE_EXTENSION FdoExtension,
  CLASSPNP_SCAN_FOR_SPECIAL_INFO DeviceList[],
  PCLASS_SCAN_FOR_SPECIAL_HANDLER Function);
