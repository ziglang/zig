/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INCL_NTMSAPI_H_
#define _INCL_NTMSAPI_H_

#include <_mingw_unicode.h>

#pragma pack(8)

#ifdef __cplusplus
extern "C" {
#endif

  /* See http://msdn.microsoft.com/en-us/library/cc245176%28PROT.13%29.aspx */
  typedef GUID NTMS_GUID;
  typedef GUID *LPNTMS_GUID;
  typedef BYTE *PSECURITY_DESCRIPTOR_NTMS;
  typedef ULONG_PTR NTMS_HANDLE;


#define NTMS_NULLGUID {0,0,0,{0,0,0,0,0,0,0,0}}
#define NTMS_IS_NULLGUID(id) ((id.Data1==0)&&(id.Data2==0)&&(id.Data3==0)&& (id.Data4[0]==0)&&(id.Data4[1]==0)&&(id.Data4[2]==0)&& (id.Data4[3]==0)&&(id.Data4[4]==0)&&(id.Data4[5]==0)&& (id.Data4[6]==0)&&(id.Data4[7]==0))

#define OpenNtmsSession __MINGW_NAME_AW(OpenNtmsSession)
#define GetNtmsDeviceName __MINGW_NAME_AW(GetNtmsDeviceName)
#define GetNtmsObjectInformation __MINGW_NAME_AW(GetNtmsObjectInformation)
#define SetNtmsObjectInformation __MINGW_NAME_AW(SetNtmsObjectInformation)
#define CreateNtmsMediaPool __MINGW_NAME_AW(CreateNtmsMediaPool)
#define GetNtmsMediaPoolName __MINGW_NAME_AW(GetNtmsMediaPoolName)
#define GetNtmsObjectAttribute __MINGW_NAME_AW(GetNtmsObjectAttribute)
#define SetNtmsObjectAttribute __MINGW_NAME_AW(SetNtmsObjectAttribute)
#define GetNtmsUIOptions __MINGW_NAME_AW(GetNtmsUIOptions)
#define SetNtmsUIOptions __MINGW_NAME_AW(SetNtmsUIOptions)
#define SubmitNtmsOperatorRequest __MINGW_NAME_AW(SubmitNtmsOperatorRequest)

#define CreateNtmsMedia __MINGW_NAME_AW(CreateNtmsMedia)
#define EjectDiskFromSADrive __MINGW_NAME_AW(EjectDiskFromSADrive)
#define GetVolumesFromDrive __MINGW_NAME_AW(GetVolumesFromDrive)

#ifndef NTMS_NOREDEF

  enum NtmsObjectsTypes {
    NTMS_UNKNOWN = 0,
    NTMS_OBJECT,NTMS_CHANGER,NTMS_CHANGER_TYPE,NTMS_COMPUTER,NTMS_DRIVE,NTMS_DRIVE_TYPE,NTMS_IEDOOR,NTMS_IEPORT,NTMS_LIBRARY,
    NTMS_LIBREQUEST,NTMS_LOGICAL_MEDIA,NTMS_MEDIA_POOL,NTMS_MEDIA_TYPE,NTMS_PARTITION,NTMS_PHYSICAL_MEDIA,NTMS_STORAGESLOT,
    NTMS_OPREQUEST,NTMS_UI_DESTINATION,NTMS_NUMBER_OF_OBJECT_TYPES
  };

  typedef struct _NTMS_ASYNC_IO {
    NTMS_GUID OperationId;
    NTMS_GUID EventId;
    DWORD dwOperationType;
    DWORD dwResult;
    DWORD dwAsyncState;
    HANDLE hEvent;
    WINBOOL bOnStateChange;
  } NTMS_ASYNC_IO,*LPNTMS_ASYNC_IO;

  enum NtmsAsyncStatus {
    NTMS_ASYNCSTATE_QUEUED = 0,NTMS_ASYNCSTATE_WAIT_RESOURCE,NTMS_ASYNCSTATE_WAIT_OPERATOR,NTMS_ASYNCSTATE_INPROCESS,NTMS_ASYNCSTATE_COMPLETE
  };

  enum NtmsAsyncOperations {
    NTMS_ASYNCOP_MOUNT = 1
  };
#endif

  enum NtmsSessionOptions {
    NTMS_SESSION_QUERYEXPEDITE = 0x1
  };

  HANDLE WINAPI OpenNtmsSessionW(LPCWSTR lpServer,LPCWSTR lpApplication,DWORD dwOptions);
  HANDLE WINAPI OpenNtmsSessionA(LPCSTR lpServer,LPCSTR lpApplication,DWORD dwOptions);
  DWORD WINAPI CloseNtmsSession(HANDLE hSession);

#ifndef NTMS_NOREDEF

  enum NtmsMountOptions {
    NTMS_MOUNT_READ = 0x0001,NTMS_MOUNT_WRITE = 0x0002,NTMS_MOUNT_ERROR_NOT_AVAILABLE = 0x0004,NTMS_MOUNT_ERROR_IF_UNAVAILABLE = 0x0004,
    NTMS_MOUNT_ERROR_OFFLINE = 0x0008,NTMS_MOUNT_ERROR_IF_OFFLINE = 0x0008,NTMS_MOUNT_SPECIFIC_DRIVE = 0x0010,NTMS_MOUNT_NOWAIT = 0x0020
  };

  enum NtmsDismountOptions {
    NTMS_DISMOUNT_DEFERRED = 0x0001,NTMS_DISMOUNT_IMMEDIATE = 0x0002
  };

  enum NtmsMountPriority {
    NTMS_PRIORITY_DEFAULT = 0,NTMS_PRIORITY_HIGHEST = 15,NTMS_PRIORITY_HIGH = 7,NTMS_PRIORITY_NORMAL = 0,NTMS_PRIORITY_LOW = -7,
    NTMS_PRIORITY_LOWEST = -15
  };

  typedef struct _NTMS_MOUNT_INFORMATION {
    DWORD dwSize;
    LPVOID lpReserved;
  } NTMS_MOUNT_INFORMATION,*LPNTMS_MOUNT_INFORMATION;
#endif

  DWORD WINAPI MountNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId,LPNTMS_GUID lpDriveId,DWORD dwCount,DWORD dwOptions,int dwPriority,DWORD dwTimeout,LPNTMS_MOUNT_INFORMATION lpMountInformation);
  DWORD WINAPI DismountNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId,DWORD dwCount,DWORD dwOptions);

#ifndef NTMS_NOREDEF
  enum NtmsAllocateOptions {
    NTMS_ALLOCATE_NEW = 0x0001,NTMS_ALLOCATE_NEXT = 0x0002,NTMS_ALLOCATE_ERROR_IF_UNAVAILABLE = 0x0004
  };

  typedef struct _NTMS_ALLOCATION_INFORMATION {
    DWORD dwSize;
    LPVOID lpReserved;
    NTMS_GUID AllocatedFrom;
  } NTMS_ALLOCATION_INFORMATION,*LPNTMS_ALLOCATION_INFORMATION;
#endif

  DWORD WINAPI AllocateNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaPool,LPNTMS_GUID lpPartition,LPNTMS_GUID lpMediaId,DWORD dwOptions,DWORD dwTimeout,LPNTMS_ALLOCATION_INFORMATION lpAllocateInformation);
  DWORD WINAPI DeallocateNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId,DWORD dwOptions);
  DWORD WINAPI SwapNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId1,LPNTMS_GUID lpMediaId2);
  DWORD WINAPI AddNtmsMediaType(HANDLE hSession,LPNTMS_GUID lpMediaTypeId,LPNTMS_GUID lpLibId);
  DWORD WINAPI DeleteNtmsMediaType(HANDLE hSession,LPNTMS_GUID lpMediaTypeId,LPNTMS_GUID lpLibId);
  DWORD WINAPI ChangeNtmsMediaType(HANDLE hSession,LPNTMS_GUID lpMediaId,LPNTMS_GUID lpPoolId);
  DWORD WINAPI DecommissionNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId);
  DWORD WINAPI SetNtmsMediaComplete(HANDLE hSession,LPNTMS_GUID lpMediaId);
  DWORD WINAPI DeleteNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId);

#ifndef NTMS_NOREDEF
  enum NtmsCreateOptions {
    NTMS_OPEN_EXISTING = 0x0001,NTMS_CREATE_NEW = 0x0002,NTMS_OPEN_ALWAYS = 0x0003
  };
#endif

#ifdef PRE_SEVIL
  DWORD WINAPI CreateNtmsMediaPool(HANDLE hSession,LPCTSTR lpPoolName,LPNTMS_GUID lpMediaType,DWORD dwAction,LPSECURITY_ATTRIBUTES lpSecurityAttributes,LPNTMS_GUID lpPoolId);
#endif
  DWORD WINAPI CreateNtmsMediaPoolA(HANDLE hSession,LPCSTR lpPoolName,LPNTMS_GUID lpMediaType,DWORD dwAction,LPSECURITY_ATTRIBUTES lpSecurityAttributes,LPNTMS_GUID lpPoolId);
  DWORD WINAPI CreateNtmsMediaPoolW(HANDLE hSession,LPCWSTR lpPoolName,LPNTMS_GUID lpMediaType,DWORD dwAction,LPSECURITY_ATTRIBUTES lpSecurityAttributes,LPNTMS_GUID lpPoolId);
  DWORD WINAPI GetNtmsMediaPoolNameA(HANDLE hSession,LPNTMS_GUID lpPoolId,LPSTR lpNameBuf,LPDWORD lpdwBufSize);
  DWORD WINAPI GetNtmsMediaPoolNameW(HANDLE hSession,LPNTMS_GUID lpPoolId,LPWSTR lpNameBuf,LPDWORD lpdwBufSize);
  DWORD WINAPI MoveToNtmsMediaPool(HANDLE hSession,LPNTMS_GUID lpMediaId,LPNTMS_GUID lpPoolId);
  DWORD WINAPI DeleteNtmsMediaPool(HANDLE hSession,LPNTMS_GUID lpPoolId);
  DWORD WINAPI DeleteNtmsLibrary(HANDLE hSession,LPNTMS_GUID lpLibraryId);
  DWORD WINAPI DeleteNtmsDrive(HANDLE hSession,LPNTMS_GUID lpDriveId);

#define NTMS_OBJECTNAME_LENGTH 64
#define NTMS_DESCRIPTION_LENGTH 127
#define NTMS_DEVICENAME_LENGTH 64
#define NTMS_SERIALNUMBER_LENGTH 32
#define NTMS_REVISION_LENGTH 32
#define NTMS_BARCODE_LENGTH 64
#define NTMS_SEQUENCE_LENGTH 32
#define NTMS_VENDORNAME_LENGTH 128
#define NTMS_PRODUCTNAME_LENGTH 128
#define NTMS_USERNAME_LENGTH 64
#define NTMS_APPLICATIONNAME_LENGTH 64
#define NTMS_COMPUTERNAME_LENGTH 64
#define NTMS_I1_MESSAGE_LENGTH 127
#define NTMS_MESSAGE_LENGTH 256
#define NTMS_POOLHIERARCHY_LENGTH 512
#define NTMS_OMIDLABELID_LENGTH 255
#define NTMS_OMIDLABELTYPE_LENGTH 64
#define NTMS_OMIDLABELINFO_LENGTH 256

#ifndef NTMS_NOREDEF

  enum NtmsDriveState {
    NTMS_DRIVESTATE_DISMOUNTED = 0,NTMS_DRIVESTATE_MOUNTED = 1,NTMS_DRIVESTATE_LOADED = 2,NTMS_DRIVESTATE_UNLOADED = 5,
    NTMS_DRIVESTATE_BEING_CLEANED = 6,NTMS_DRIVESTATE_DISMOUNTABLE = 7
  };

#define _NTMS_DRIVEINFORMATION __MINGW_NAME_AW(_NTMS_DRIVEINFORMATION)
#define NTMS_DRIVEINFORMATION __MINGW_NAME_AW(NTMS_DRIVEINFORMATION)

  typedef struct _NTMS_DRIVEINFORMATIONA {
    DWORD Number;
    DWORD State;
    NTMS_GUID DriveType;
    CHAR szDeviceName[NTMS_DEVICENAME_LENGTH];
    CHAR szSerialNumber[NTMS_SERIALNUMBER_LENGTH];
    CHAR szRevision[NTMS_REVISION_LENGTH];
    WORD ScsiPort;
    WORD ScsiBus;
    WORD ScsiTarget;
    WORD ScsiLun;
    DWORD dwMountCount;
    SYSTEMTIME LastCleanedTs;
    NTMS_GUID SavedPartitionId;
    NTMS_GUID Library;
    GUID Reserved;
    DWORD dwDeferDismountDelay;
  } NTMS_DRIVEINFORMATIONA;

  typedef struct _NTMS_DRIVEINFORMATIONW {
    DWORD Number;
    DWORD State;
    NTMS_GUID DriveType;
    WCHAR szDeviceName[NTMS_DEVICENAME_LENGTH];
    WCHAR szSerialNumber[NTMS_SERIALNUMBER_LENGTH];
    WCHAR szRevision[NTMS_REVISION_LENGTH];
    WORD ScsiPort;
    WORD ScsiBus;
    WORD ScsiTarget;
    WORD ScsiLun;
    DWORD dwMountCount;
    SYSTEMTIME LastCleanedTs;
    NTMS_GUID SavedPartitionId;
    NTMS_GUID Library;
    GUID Reserved;
    DWORD dwDeferDismountDelay;
  } NTMS_DRIVEINFORMATIONW;

  enum NtmsLibraryType {
    NTMS_LIBRARYTYPE_UNKNOWN = 0,NTMS_LIBRARYTYPE_OFFLINE = 1,NTMS_LIBRARYTYPE_ONLINE = 2,NTMS_LIBRARYTYPE_STANDALONE = 3
  };

  enum NtmsLibraryFlags {
    NTMS_LIBRARYFLAG_FIXEDOFFLINE = 0x01,NTMS_LIBRARYFLAG_CLEANERPRESENT = 0x02,NTMS_LIBRARYFLAG_AUTODETECTCHANGE = 0x04,
    NTMS_LIBRARYFLAG_IGNORECLEANERUSESREMAINING = 0x08,NTMS_LIBRARYFLAG_RECOGNIZECLEANERBARCODE = 0x10
  };

  enum NtmsInventoryMethod {
    NTMS_INVENTORY_NONE = 0,NTMS_INVENTORY_FAST = 1,NTMS_INVENTORY_OMID = 2,NTMS_INVENTORY_DEFAULT = 3,NTMS_INVENTORY_SLOT = 4,
    NTMS_INVENTORY_STOP = 5,NTMS_INVENTORY_MAX
  };

  typedef struct _NTMS_LIBRARYINFORMATION {
    DWORD LibraryType;
    NTMS_GUID CleanerSlot;
    NTMS_GUID CleanerSlotDefault;
    WINBOOL LibrarySupportsDriveCleaning;
    WINBOOL BarCodeReaderInstalled;
    DWORD InventoryMethod;
    DWORD dwCleanerUsesRemaining;
    DWORD FirstDriveNumber;
    DWORD dwNumberOfDrives;
    DWORD FirstSlotNumber;
    DWORD dwNumberOfSlots;
    DWORD FirstDoorNumber;
    DWORD dwNumberOfDoors;
    DWORD FirstPortNumber;
    DWORD dwNumberOfPorts;
    DWORD FirstChangerNumber;
    DWORD dwNumberOfChangers;
    DWORD dwNumberOfMedia;
    DWORD dwNumberOfMediaTypes;
    DWORD dwNumberOfLibRequests;
    GUID Reserved;
    WINBOOL AutoRecovery;
    DWORD dwFlags;
  } NTMS_LIBRARYINFORMATION;

#define _NTMS_CHANGERINFORMATION __MINGW_NAME_AW(_NTMS_CHANGERINFORMATION)
#define NTMS_CHANGERINFORMATION __MINGW_NAME_AW(NTMS_CHANGERINFORMATION)

  typedef struct _NTMS_CHANGERINFORMATIONA {
    DWORD Number;
    NTMS_GUID ChangerType;
    CHAR szSerialNumber[NTMS_SERIALNUMBER_LENGTH];
    CHAR szRevision[NTMS_REVISION_LENGTH];
    CHAR szDeviceName[NTMS_DEVICENAME_LENGTH];
    WORD ScsiPort;
    WORD ScsiBus;
    WORD ScsiTarget;
    WORD ScsiLun;
    NTMS_GUID Library;
  } NTMS_CHANGERINFORMATIONA;

  typedef struct _NTMS_CHANGERINFORMATIONW {
    DWORD Number;
    NTMS_GUID ChangerType;
    WCHAR szSerialNumber[NTMS_SERIALNUMBER_LENGTH];
    WCHAR szRevision[NTMS_REVISION_LENGTH];
    WCHAR szDeviceName[NTMS_DEVICENAME_LENGTH];
    WORD ScsiPort;
    WORD ScsiBus;
    WORD ScsiTarget;
    WORD ScsiLun;
    NTMS_GUID Library;
  } NTMS_CHANGERINFORMATIONW;

  enum NtmsSlotState {
    NTMS_SLOTSTATE_UNKNOWN = 0,NTMS_SLOTSTATE_FULL = 1,NTMS_SLOTSTATE_EMPTY = 2,NTMS_SLOTSTATE_NOTPRESENT = 3,NTMS_SLOTSTATE_NEEDSINVENTORY = 4
  };

  typedef struct _NTMS_STORAGESLOTINFORMATION {
    DWORD Number;
    DWORD State;
    NTMS_GUID Library;
  } NTMS_STORAGESLOTINFORMATION;

  enum NtmsDoorState {
    NTMS_DOORSTATE_UNKNOWN = 0,NTMS_DOORSTATE_CLOSED = 1,NTMS_DOORSTATE_OPEN = 2
  };

  typedef struct _NTMS_IEDOORINFORMATION {
    DWORD Number;
    DWORD State;
    WORD MaxOpenSecs;
    NTMS_GUID Library;
  } NTMS_IEDOORINFORMATION;

  enum NtmsPortPosition {
    NTMS_PORTPOSITION_UNKNOWN = 0,NTMS_PORTPOSITION_EXTENDED = 1,NTMS_PORTPOSITION_RETRACTED = 2
  };

  enum NtmsPortContent {
    NTMS_PORTCONTENT_UNKNOWN = 0,NTMS_PORTCONTENT_FULL = 1,NTMS_PORTCONTENT_EMPTY = 2
  };

  typedef struct _NTMS_IEPORTINFORMATION {
    DWORD Number;
    DWORD Content;
    DWORD Position;
    WORD MaxExtendSecs;
    NTMS_GUID Library;
  } NTMS_IEPORTINFORMATION;

  enum NtmsBarCodeState {
    NTMS_BARCODESTATE_OK = 1,NTMS_BARCODESTATE_UNREADABLE = 2
  };

  enum NtmsMediaState {
    NTMS_MEDIASTATE_IDLE = 0,
    NTMS_MEDIASTATE_INUSE,NTMS_MEDIASTATE_MOUNTED,NTMS_MEDIASTATE_LOADED,NTMS_MEDIASTATE_UNLOADED,
    NTMS_MEDIASTATE_OPERROR,NTMS_MEDIASTATE_OPREQ
  };

#define _NTMS_PMIDINFORMATION __MINGW_NAME_AW(_NTMS_PMIDINFORMATION)
#define NTMS_PMIDINFORMATION __MINGW_NAME_AW(NTMS_PMIDINFORMATION)

  typedef struct _NTMS_PMIDINFORMATIONA {
    NTMS_GUID CurrentLibrary;
    NTMS_GUID MediaPool;
    NTMS_GUID Location;
    DWORD LocationType;
    NTMS_GUID MediaType;
    NTMS_GUID HomeSlot;
    CHAR szBarCode[NTMS_BARCODE_LENGTH];
    DWORD BarCodeState;
    CHAR szSequenceNumber[NTMS_SEQUENCE_LENGTH];
    DWORD MediaState;
    DWORD dwNumberOfPartitions;
    DWORD dwMediaTypeCode;
    DWORD dwDensityCode;
    NTMS_GUID MountedPartition;
  } NTMS_PMIDINFORMATIONA;

  typedef struct _NTMS_PMIDINFORMATIONW {
    NTMS_GUID CurrentLibrary;
    NTMS_GUID MediaPool;
    NTMS_GUID Location;
    DWORD LocationType;
    NTMS_GUID MediaType;
    NTMS_GUID HomeSlot;
    WCHAR szBarCode[NTMS_BARCODE_LENGTH];
    DWORD BarCodeState;
    WCHAR szSequenceNumber[NTMS_SEQUENCE_LENGTH];
    DWORD MediaState;
    DWORD dwNumberOfPartitions;
    DWORD dwMediaTypeCode;
    DWORD dwDensityCode;
    NTMS_GUID MountedPartition;
  } NTMS_PMIDINFORMATIONW;

  typedef struct _NTMS_LMIDINFORMATION {
    NTMS_GUID MediaPool;
    DWORD dwNumberOfPartitions;
  } NTMS_LMIDINFORMATION;

  enum NtmsPartitionState {
    NTMS_PARTSTATE_UNKNOWN = 0,
    NTMS_PARTSTATE_UNPREPARED,NTMS_PARTSTATE_INCOMPATIBLE,NTMS_PARTSTATE_DECOMMISSIONED,
    NTMS_PARTSTATE_AVAILABLE,NTMS_PARTSTATE_ALLOCATED,NTMS_PARTSTATE_COMPLETE,NTMS_PARTSTATE_FOREIGN,NTMS_PARTSTATE_IMPORT,
    NTMS_PARTSTATE_RESERVED
  };

#define NTMS_PARTSTATE_NEW NTMS_PARTSTATE_UNKNOWN

#define _NTMS_PARTITIONINFORMATION __MINGW_NAME_AW(_NTMS_PARTITIONINFORMATION)
#define NTMS_PARTITIONINFORMATION __MINGW_NAME_AW(NTMS_PARTITIONINFORMATION)

  typedef struct _NTMS_PARTITIONINFORMATIONA {
    NTMS_GUID PhysicalMedia;
    NTMS_GUID LogicalMedia;
    DWORD State;
    WORD Side;
    DWORD dwOmidLabelIdLength;
    BYTE OmidLabelId[NTMS_OMIDLABELID_LENGTH];
    CHAR szOmidLabelType[NTMS_OMIDLABELTYPE_LENGTH];
    CHAR szOmidLabelInfo[NTMS_OMIDLABELINFO_LENGTH];
    DWORD dwMountCount;
    DWORD dwAllocateCount;
    LARGE_INTEGER Capacity;
  } NTMS_PARTITIONINFORMATIONA;

  typedef struct _NTMS_PARTITIONINFORMATIONW {
    NTMS_GUID PhysicalMedia;
    NTMS_GUID LogicalMedia;
    DWORD State;
    WORD Side;
    DWORD dwOmidLabelIdLength;
    BYTE OmidLabelId[NTMS_OMIDLABELID_LENGTH];
    WCHAR szOmidLabelType[NTMS_OMIDLABELTYPE_LENGTH];
    WCHAR szOmidLabelInfo[NTMS_OMIDLABELINFO_LENGTH];
    DWORD dwMountCount;
    DWORD dwAllocateCount;
    LARGE_INTEGER Capacity;
  } NTMS_PARTITIONINFORMATIONW;

  enum NtmsPoolType {
    NTMS_POOLTYPE_UNKNOWN = 0,NTMS_POOLTYPE_SCRATCH = 1,NTMS_POOLTYPE_FOREIGN = 2,NTMS_POOLTYPE_IMPORT = 3,NTMS_POOLTYPE_APPLICATION = 1000
  };

  enum NtmsAllocationPolicy {
    NTMS_ALLOCATE_FROMSCRATCH = 1
  };

  enum NtmsDeallocationPolicy {
    NTMS_DEALLOCATE_TOSCRATCH = 1
  };

  typedef struct _NTMS_MEDIAPOOLINFORMATION {
    DWORD PoolType;
    NTMS_GUID MediaType;
    NTMS_GUID Parent;
    DWORD AllocationPolicy;
    DWORD DeallocationPolicy;
    DWORD dwMaxAllocates;
    DWORD dwNumberOfPhysicalMedia;
    DWORD dwNumberOfLogicalMedia;
    DWORD dwNumberOfMediaPools;
  } NTMS_MEDIAPOOLINFORMATION;

  enum NtmsReadWriteCharacteristics {
    NTMS_MEDIARW_UNKNOWN = 0,NTMS_MEDIARW_REWRITABLE = 1,NTMS_MEDIARW_WRITEONCE = 2,NTMS_MEDIARW_READONLY = 3
  };

  typedef struct _NTMS_MEDIATYPEINFORMATION {
    DWORD MediaType;
    DWORD NumberOfSides;
    DWORD ReadWriteCharacteristics;
    DWORD DeviceType;
  } NTMS_MEDIATYPEINFORMATION;

#define _NTMS_DRIVETYPEINFORMATION __MINGW_NAME_AW(_NTMS_DRIVETYPEINFORMATION)
#define NTMS_DRIVETYPEINFORMATION __MINGW_NAME_AW(NTMS_DRIVETYPEINFORMATION)

  typedef struct _NTMS_DRIVETYPEINFORMATIONA {
    CHAR szVendor[NTMS_VENDORNAME_LENGTH];
    CHAR szProduct[NTMS_PRODUCTNAME_LENGTH];
    DWORD NumberOfHeads;
    DWORD DeviceType;
  } NTMS_DRIVETYPEINFORMATIONA;

  typedef struct _NTMS_DRIVETYPEINFORMATIONW {
    WCHAR szVendor[NTMS_VENDORNAME_LENGTH];
    WCHAR szProduct[NTMS_PRODUCTNAME_LENGTH];
    DWORD NumberOfHeads;
    DWORD DeviceType;
  } NTMS_DRIVETYPEINFORMATIONW;

#define _NTMS_CHANGERTYPEINFORMATION __MINGW_NAME_AW(_NTMS_CHANGERTYPEINFORMATION)
#define NTMS_CHANGERTYPEINFORMATION __MINGW_NAME_AW(NTMS_CHANGERTYPEINFORMATION)

  typedef struct _NTMS_CHANGERTYPEINFORMATIONA {
    CHAR szVendor[NTMS_VENDORNAME_LENGTH];
    CHAR szProduct[NTMS_PRODUCTNAME_LENGTH];
    DWORD DeviceType;
  } NTMS_CHANGERTYPEINFORMATIONA;

  typedef struct _NTMS_CHANGERTYPEINFORMATIONW {
    WCHAR szVendor[NTMS_VENDORNAME_LENGTH];
    WCHAR szProduct[NTMS_PRODUCTNAME_LENGTH];
    DWORD DeviceType;
  } NTMS_CHANGERTYPEINFORMATIONW;

  enum NtmsLmOperation {
    NTMS_LM_REMOVE = 0,NTMS_LM_DISABLECHANGER = 1,NTMS_LM_DISABLELIBRARY = 1,NTMS_LM_ENABLECHANGER = 2,NTMS_LM_ENABLELIBRARY = 2,
    NTMS_LM_DISABLEDRIVE = 3,NTMS_LM_ENABLEDRIVE = 4,NTMS_LM_DISABLEMEDIA = 5,NTMS_LM_ENABLEMEDIA = 6,NTMS_LM_UPDATEOMID = 7,
    NTMS_LM_INVENTORY = 8,NTMS_LM_DOORACCESS = 9,NTMS_LM_EJECT = 10,NTMS_LM_EJECTCLEANER = 11,NTMS_LM_INJECT = 12,NTMS_LM_INJECTCLEANER = 13,
    NTMS_LM_PROCESSOMID = 14,NTMS_LM_CLEANDRIVE = 15,NTMS_LM_DISMOUNT = 16,NTMS_LM_MOUNT = 17,NTMS_LM_WRITESCRATCH = 18,NTMS_LM_CLASSIFY = 19,
    NTMS_LM_RESERVECLEANER = 20,NTMS_LM_RELEASECLEANER = 21,NTMS_LM_MAXWORKITEM
  };

  enum NtmsLmState {
    NTMS_LM_QUEUED = 0,NTMS_LM_INPROCESS = 1,NTMS_LM_PASSED = 2,NTMS_LM_FAILED = 3,NTMS_LM_INVALID = 4,NTMS_LM_WAITING = 5,
    NTMS_LM_DEFERRED = 6,NTMS_LM_DEFFERED = 6,NTMS_LM_CANCELLED = 7,NTMS_LM_STOPPED = 8
  };

#define _NTMS_LIBREQUESTINFORMATION __MINGW_NAME_AW(_NTMS_LIBREQUESTINFORMATION)
#define NTMS_LIBREQUESTINFORMATION __MINGW_NAME_AW(NTMS_LIBREQUESTINFORMATION)

  typedef struct _NTMS_LIBREQUESTINFORMATIONA {
    DWORD OperationCode;
    DWORD OperationOption;
    DWORD State;
    NTMS_GUID PartitionId;
    NTMS_GUID DriveId;
    NTMS_GUID PhysMediaId;
    NTMS_GUID Library;
    NTMS_GUID SlotId;
    SYSTEMTIME TimeQueued;
    SYSTEMTIME TimeCompleted;
    CHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    CHAR szUser[NTMS_USERNAME_LENGTH];
    CHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
    DWORD dwErrorCode;
    NTMS_GUID WorkItemId;
    DWORD dwPriority;
  } NTMS_LIBREQUESTINFORMATIONA;

  typedef struct _NTMS_LIBREQUESTINFORMATIONW {
    DWORD OperationCode;
    DWORD OperationOption;
    DWORD State;
    NTMS_GUID PartitionId;
    NTMS_GUID DriveId;
    NTMS_GUID PhysMediaId;
    NTMS_GUID Library;
    NTMS_GUID SlotId;
    SYSTEMTIME TimeQueued;
    SYSTEMTIME TimeCompleted;
    WCHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    WCHAR szUser[NTMS_USERNAME_LENGTH];
    WCHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
    DWORD dwErrorCode;
    NTMS_GUID WorkItemId;
    DWORD dwPriority;
  } NTMS_LIBREQUESTINFORMATIONW;

  enum NtmsOpreqCommand {
    NTMS_OPREQ_UNKNOWN = 0,NTMS_OPREQ_NEWMEDIA,NTMS_OPREQ_CLEANER,NTMS_OPREQ_DEVICESERVICE,NTMS_OPREQ_MOVEMEDIA,
    NTMS_OPREQ_MESSAGE
  };

  enum NtmsOpreqState {
    NTMS_OPSTATE_UNKNOWN = 0,
    NTMS_OPSTATE_SUBMITTED,NTMS_OPSTATE_ACTIVE,NTMS_OPSTATE_INPROGRESS,NTMS_OPSTATE_REFUSED,
    NTMS_OPSTATE_COMPLETE
  };

#define _NTMS_OPREQUESTINFORMATION __MINGW_NAME_AW(_NTMS_OPREQUESTINFORMATION)
#define NTMS_OPREQUESTINFORMATION __MINGW_NAME_AW(NTMS_OPREQUESTINFORMATION)

  typedef struct _NTMS_OPREQUESTINFORMATIONA {
    DWORD Request;
    SYSTEMTIME Submitted;
    DWORD State;
    CHAR szMessage[NTMS_MESSAGE_LENGTH];
    DWORD Arg1Type;
    NTMS_GUID Arg1;
    DWORD Arg2Type;
    NTMS_GUID Arg2;
    CHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    CHAR szUser[NTMS_USERNAME_LENGTH];
    CHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_OPREQUESTINFORMATIONA;

  typedef struct _NTMS_OPREQUESTINFORMATIONW {
    DWORD Request;
    SYSTEMTIME Submitted;
    DWORD State;
    WCHAR szMessage[NTMS_MESSAGE_LENGTH];
    DWORD Arg1Type;
    NTMS_GUID Arg1;
    DWORD Arg2Type;
    NTMS_GUID Arg2;
    WCHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    WCHAR szUser[NTMS_USERNAME_LENGTH];
    WCHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_OPREQUESTINFORMATIONW;

  typedef struct _NTMS_COMPUTERINFORMATION {
    DWORD dwLibRequestPurgeTime;
    DWORD dwOpRequestPurgeTime;
    DWORD dwLibRequestFlags;
    DWORD dwOpRequestFlags;
    DWORD dwMediaPoolPolicy;
  } NTMS_COMPUTERINFORMATION;

  enum NtmsLibRequestFlags {
    NTMS_LIBREQFLAGS_NOAUTOPURGE = 0x01,NTMS_LIBREQFLAGS_NOFAILEDPURGE = 0x02
  };

  enum NtmsOpRequestFlags {
    NTMS_OPREQFLAGS_NOAUTOPURGE = 0x01,NTMS_OPREQFLAGS_NOFAILEDPURGE = 0x02,NTMS_OPREQFLAGS_NOALERTS = 0x10,NTMS_OPREQFLAGS_NOTRAYICON = 0x20
  };

  enum NtmsMediaPoolPolicy {
    NTMS_POOLPOLICY_PURGEOFFLINESCRATCH = 0x01,NTMS_POOLPOLICY_KEEPOFFLINEIMPORT = 0x02
  };

#define _NTMS_OBJECTINFORMATION __MINGW_NAME_AW(_NTMS_OBJECTINFORMATION)
#define NTMS_OBJECTINFORMATION __MINGW_NAME_AW(NTMS_OBJECTINFORMATION)
#define LPNTMS_OBJECTINFORMATION __MINGW_NAME_AW(LPNTMS_OBJECTINFORMATION)

  enum NtmsOperationalState {
    NTMS_READY = 0,
    NTMS_INITIALIZING = 10,
    NTMS_NEEDS_SERVICE = 20,
    NTMS_NOT_PRESENT = 21
  };

  typedef struct _RSM_MESSAGE {
      LPGUID lpguidOperation;
      DWORD dwNtmsType;
      DWORD dwState;
      DWORD dwFlags;
      DWORD dwPriority;
      DWORD dwErrorCode;
      LPWSTR lpszComputerName;
      LPWSTR lpszApplication;
      LPWSTR lpszUser;
      LPWSTR lpszTimeSubmitted;
      LPWSTR lpszMessage;
  } RSM_MESSAGE, *LPRSM_MESSAGE;

  typedef struct _NTMS_OBJECTINFORMATIONA {
    DWORD dwSize;
    DWORD dwType;
    SYSTEMTIME Created;
    SYSTEMTIME Modified;
    NTMS_GUID ObjectGuid;
    WINBOOL Enabled;
    DWORD dwOperationalState;
    CHAR szName[NTMS_OBJECTNAME_LENGTH];
    CHAR szDescription[NTMS_DESCRIPTION_LENGTH];
    union {
      NTMS_DRIVEINFORMATIONA Drive;
      NTMS_DRIVETYPEINFORMATIONA DriveType;
      NTMS_LIBRARYINFORMATION Library;
      NTMS_CHANGERINFORMATIONA Changer;
      NTMS_CHANGERTYPEINFORMATIONA ChangerType;
      NTMS_STORAGESLOTINFORMATION StorageSlot;
      NTMS_IEDOORINFORMATION IEDoor;
      NTMS_IEPORTINFORMATION IEPort;
      NTMS_PMIDINFORMATIONA PhysicalMedia;
      NTMS_LMIDINFORMATION LogicalMedia;
      NTMS_PARTITIONINFORMATIONA Partition;
      NTMS_MEDIAPOOLINFORMATION MediaPool;
      NTMS_MEDIATYPEINFORMATION MediaType;
      NTMS_LIBREQUESTINFORMATIONA LibRequest;
      NTMS_OPREQUESTINFORMATIONA OpRequest;
      NTMS_COMPUTERINFORMATION Computer;
    } Info;
  } NTMS_OBJECTINFORMATIONA,*LPNTMS_OBJECTINFORMATIONA;

  typedef struct _NTMS_OBJECTINFORMATIONW {
    DWORD dwSize;
    DWORD dwType;
    SYSTEMTIME Created;
    SYSTEMTIME Modified;
    NTMS_GUID ObjectGuid;
    WINBOOL Enabled;
    DWORD dwOperationalState;
    WCHAR szName[NTMS_OBJECTNAME_LENGTH];
    WCHAR szDescription[NTMS_DESCRIPTION_LENGTH];
    union {
      NTMS_DRIVEINFORMATIONW Drive;
      NTMS_DRIVETYPEINFORMATIONW DriveType;
      NTMS_LIBRARYINFORMATION Library;
      NTMS_CHANGERINFORMATIONW Changer;
      NTMS_CHANGERTYPEINFORMATIONW ChangerType;
      NTMS_STORAGESLOTINFORMATION StorageSlot;
      NTMS_IEDOORINFORMATION IEDoor;
      NTMS_IEPORTINFORMATION IEPort;
      NTMS_PMIDINFORMATIONW PhysicalMedia;
      NTMS_LMIDINFORMATION LogicalMedia;
      NTMS_PARTITIONINFORMATIONW Partition;
      NTMS_MEDIAPOOLINFORMATION MediaPool;
      NTMS_MEDIATYPEINFORMATION MediaType;
      NTMS_LIBREQUESTINFORMATIONW LibRequest;
      NTMS_OPREQUESTINFORMATIONW OpRequest;
      NTMS_COMPUTERINFORMATION Computer;
    } Info;
  } NTMS_OBJECTINFORMATIONW,*LPNTMS_OBJECTINFORMATIONW;

#define NTMS_I1_LIBREQUESTINFORMATION __MINGW_NAME_AW(NTMS_I1_LIBREQUESTINFORMATION)
#define NTMS_I1_PARTITIONINFORMATION __MINGW_NAME_AW(NTMS_I1_PARTITIONINFORMATION)
#define NTMS_I1_PMIDINFORMATION __MINGW_NAME_AW(NTMS_I1_PMIDINFORMATION)
#define NTMS_I1_OPREQUESTINFORMATION __MINGW_NAME_AW(NTMS_I1_OPREQUESTINFORMATION)
#define NTMS_I1_OBJECTINFORMATION __MINGW_NAME_AW(NTMS_I1_OBJECTINFORMATION)

  typedef struct _NTMS_I1_LIBRARYINFORMATION {
    DWORD LibraryType;
    NTMS_GUID CleanerSlot;
    NTMS_GUID CleanerSlotDefault;
    WINBOOL LibrarySupportsDriveCleaning;
    WINBOOL BarCodeReaderInstalled;
    DWORD InventoryMethod;
    DWORD dwCleanerUsesRemaining;
    DWORD FirstDriveNumber;
    DWORD dwNumberOfDrives;
    DWORD FirstSlotNumber;
    DWORD dwNumberOfSlots;
    DWORD FirstDoorNumber;
    DWORD dwNumberOfDoors;
    DWORD FirstPortNumber;
    DWORD dwNumberOfPorts;
    DWORD FirstChangerNumber;
    DWORD dwNumberOfChangers;
    DWORD dwNumberOfMedia;
    DWORD dwNumberOfMediaTypes;
    DWORD dwNumberOfLibRequests;
    GUID Reserved;
  } NTMS_I1_LIBRARYINFORMATION;

  typedef struct _NTMS_I1_LIBREQUESTINFORMATIONA {
    DWORD OperationCode;
    DWORD OperationOption;
    DWORD State;
    NTMS_GUID PartitionId;
    NTMS_GUID DriveId;
    NTMS_GUID PhysMediaId;
    NTMS_GUID Library;
    NTMS_GUID SlotId;
    SYSTEMTIME TimeQueued;
    SYSTEMTIME TimeCompleted;
    CHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    CHAR szUser[NTMS_USERNAME_LENGTH];
    CHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_I1_LIBREQUESTINFORMATIONA;

  typedef struct _NTMS_I1_LIBREQUESTINFORMATIONW {
    DWORD OperationCode;
    DWORD OperationOption;
    DWORD State;
    NTMS_GUID PartitionId;
    NTMS_GUID DriveId;
    NTMS_GUID PhysMediaId;
    NTMS_GUID Library;
    NTMS_GUID SlotId;
    SYSTEMTIME TimeQueued;
    SYSTEMTIME TimeCompleted;
    WCHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    WCHAR szUser[NTMS_USERNAME_LENGTH];
    WCHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_I1_LIBREQUESTINFORMATIONW;

  typedef struct _NTMS_I1_PMIDINFORMATIONA {
    NTMS_GUID CurrentLibrary;
    NTMS_GUID MediaPool;
    NTMS_GUID Location;
    DWORD LocationType;
    NTMS_GUID MediaType;
    NTMS_GUID HomeSlot;
    CHAR szBarCode[NTMS_BARCODE_LENGTH];
    DWORD BarCodeState;
    CHAR szSequenceNumber[NTMS_SEQUENCE_LENGTH];
    DWORD MediaState;
    DWORD dwNumberOfPartitions;
  } NTMS_I1_PMIDINFORMATIONA;

  typedef struct _NTMS_I1_PMIDINFORMATIONW {
    NTMS_GUID CurrentLibrary;
    NTMS_GUID MediaPool;
    NTMS_GUID Location;
    DWORD LocationType;
    NTMS_GUID MediaType;
    NTMS_GUID HomeSlot;
    WCHAR szBarCode[NTMS_BARCODE_LENGTH];
    DWORD BarCodeState;
    WCHAR szSequenceNumber[NTMS_SEQUENCE_LENGTH];
    DWORD MediaState;
    DWORD dwNumberOfPartitions;
  } NTMS_I1_PMIDINFORMATIONW;

  typedef struct _NTMS_I1_PARTITIONINFORMATIONA {
    NTMS_GUID PhysicalMedia;
    NTMS_GUID LogicalMedia;
    DWORD State;
    WORD Side;
    DWORD dwOmidLabelIdLength;
    BYTE OmidLabelId[255];
    CHAR szOmidLabelType[64];
    CHAR szOmidLabelInfo[256];
    DWORD dwMountCount;
    DWORD dwAllocateCount;
  } NTMS_I1_PARTITIONINFORMATIONA;

  typedef struct _NTMS_I1_PARTITIONINFORMATIONW {
    NTMS_GUID PhysicalMedia;
    NTMS_GUID LogicalMedia;
    DWORD State;
    WORD Side;
    DWORD dwOmidLabelIdLength;
    BYTE OmidLabelId[255];
    WCHAR szOmidLabelType[64];
    WCHAR szOmidLabelInfo[256];
    DWORD dwMountCount;
    DWORD dwAllocateCount;
  } NTMS_I1_PARTITIONINFORMATIONW;

  typedef struct _NTMS_I1_OPREQUESTINFORMATIONA {
    DWORD Request;
    SYSTEMTIME Submitted;
    DWORD State;
    CHAR szMessage[NTMS_I1_MESSAGE_LENGTH];
    DWORD Arg1Type;
    NTMS_GUID Arg1;
    DWORD Arg2Type;
    NTMS_GUID Arg2;
    CHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    CHAR szUser[NTMS_USERNAME_LENGTH];
    CHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_I1_OPREQUESTINFORMATIONA;

  typedef struct _NTMS_I1_OPREQUESTINFORMATIONW {
    DWORD Request;
    SYSTEMTIME Submitted;
    DWORD State;
    WCHAR szMessage[NTMS_I1_MESSAGE_LENGTH];
    DWORD Arg1Type;
    NTMS_GUID Arg1;
    DWORD Arg2Type;
    NTMS_GUID Arg2;
    WCHAR szApplication[NTMS_APPLICATIONNAME_LENGTH];
    WCHAR szUser[NTMS_USERNAME_LENGTH];
    WCHAR szComputer[NTMS_COMPUTERNAME_LENGTH];
  } NTMS_I1_OPREQUESTINFORMATIONW;

  typedef struct _NTMS_I1_OBJECTINFORMATIONA {
    DWORD dwSize;
    DWORD dwType;
    SYSTEMTIME Created;
    SYSTEMTIME Modified;
    NTMS_GUID ObjectGuid;
    WINBOOL Enabled;
    DWORD dwOperationalState;
    CHAR szName[NTMS_OBJECTNAME_LENGTH];
    CHAR szDescription[NTMS_DESCRIPTION_LENGTH];
    union {
      NTMS_DRIVEINFORMATIONA Drive;
      NTMS_DRIVETYPEINFORMATIONA DriveType;
      NTMS_I1_LIBRARYINFORMATION Library;
      NTMS_CHANGERINFORMATIONA Changer;
      NTMS_CHANGERTYPEINFORMATIONA ChangerType;
      NTMS_STORAGESLOTINFORMATION StorageSlot;
      NTMS_IEDOORINFORMATION IEDoor;
      NTMS_IEPORTINFORMATION IEPort;
      NTMS_I1_PMIDINFORMATIONA PhysicalMedia;
      NTMS_LMIDINFORMATION LogicalMedia;
      NTMS_I1_PARTITIONINFORMATIONA Partition;
      NTMS_MEDIAPOOLINFORMATION MediaPool;
      NTMS_MEDIATYPEINFORMATION MediaType;
      NTMS_I1_LIBREQUESTINFORMATIONA LibRequest;
      NTMS_I1_OPREQUESTINFORMATIONA OpRequest;
    } Info;
  } NTMS_I1_OBJECTINFORMATIONA,*LPNTMS_I1_OBJECTINFORMATIONA;

  typedef struct _NTMS_I1_OBJECTINFORMATIONW {
    DWORD dwSize;
    DWORD dwType;
    SYSTEMTIME Created;
    SYSTEMTIME Modified;
    NTMS_GUID ObjectGuid;
    WINBOOL Enabled;
    DWORD dwOperationalState;
    WCHAR szName[NTMS_OBJECTNAME_LENGTH];
    WCHAR szDescription[NTMS_DESCRIPTION_LENGTH];
    union {
      NTMS_DRIVEINFORMATIONW Drive;
      NTMS_DRIVETYPEINFORMATIONW DriveType;
      NTMS_I1_LIBRARYINFORMATION Library;
      NTMS_CHANGERINFORMATIONW Changer;
      NTMS_CHANGERTYPEINFORMATIONW ChangerType;
      NTMS_STORAGESLOTINFORMATION StorageSlot;
      NTMS_IEDOORINFORMATION IEDoor;
      NTMS_IEPORTINFORMATION IEPort;
      NTMS_I1_PMIDINFORMATIONW PhysicalMedia;
      NTMS_LMIDINFORMATION LogicalMedia;
      NTMS_I1_PARTITIONINFORMATIONW Partition;
      NTMS_MEDIAPOOLINFORMATION MediaPool;
      NTMS_MEDIATYPEINFORMATION MediaType;
      NTMS_I1_LIBREQUESTINFORMATIONW LibRequest;
      NTMS_I1_OPREQUESTINFORMATIONW OpRequest;
    } Info;
  } NTMS_I1_OBJECTINFORMATIONW,*LPNTMS_I1_OBJECTINFORMATIONW;
#endif

#ifndef NTMS_NOREDEF

  enum NtmsCreateNtmsMediaOptions {
    NTMS_ERROR_ON_DUPLICATE = 0x0001
  };
#endif

#ifdef PRE_SEVIL
  DWORD WINAPI GetNtmsObjectInformation(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATION lpInfo);
  DWORD WINAPI SetNtmsObjectInformation(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATION lpInfo);
#endif
  DWORD WINAPI GetNtmsObjectInformationA(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATIONA lpInfo);
  DWORD WINAPI GetNtmsObjectInformationW(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATIONW lpInfo);
  DWORD WINAPI SetNtmsObjectInformationA(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATIONA lpInfo);
  DWORD WINAPI SetNtmsObjectInformationW(HANDLE hSession,LPNTMS_GUID lpObjectId,LPNTMS_OBJECTINFORMATIONW lpInfo);
  DWORD WINAPI CreateNtmsMediaA(HANDLE hSession,LPNTMS_OBJECTINFORMATIONA lpMedia,LPNTMS_OBJECTINFORMATIONA lpList,DWORD dwOptions);
  DWORD WINAPI CreateNtmsMediaW(HANDLE hSession,LPNTMS_OBJECTINFORMATIONW lpMedia,LPNTMS_OBJECTINFORMATIONW lpList,DWORD dwOptions);
  enum NtmsEnumerateOption {
    NTMS_ENUM_DEFAULT = 0,NTMS_ENUM_ROOTPOOL = 1
  };
  DWORD WINAPI EnumerateNtmsObject(HANDLE hSession,const LPNTMS_GUID lpContainerId,LPNTMS_GUID lpList,LPDWORD lpdwListSize,DWORD dwType,DWORD dwOptions);
  DWORD WINAPI DisableNtmsObject(HANDLE hSession,DWORD dwType,LPNTMS_GUID lpObjectId);
  DWORD WINAPI EnableNtmsObject(HANDLE hSession,DWORD dwType,LPNTMS_GUID lpObjectId);
  enum NtmsEjectOperation {
    NTMS_EJECT_START = 0,NTMS_EJECT_STOP = 1,NTMS_EJECT_QUEUE = 2,NTMS_EJECT_FORCE = 3,NTMS_EJECT_IMMEDIATE = 4,NTMS_EJECT_ASK_USER = 5
  };
  DWORD WINAPI EjectNtmsMedia(HANDLE hSession,LPNTMS_GUID lpMediaId,LPNTMS_GUID lpEjectOperation,DWORD dwAction);
  enum NtmsInjectOperation {
    NTMS_INJECT_START = 0,NTMS_INJECT_STOP = 1,NTMS_INJECT_RETRACT = 2,NTMS_INJECT_STARTMANY = 3
  };
  DWORD WINAPI InjectNtmsMedia(HANDLE hSession,LPNTMS_GUID lpLibraryId,LPNTMS_GUID lpInjectOperation,DWORD dwAction);
  DWORD WINAPI AccessNtmsLibraryDoor(HANDLE hSession,LPNTMS_GUID lpLibraryId,DWORD dwAction);
  DWORD WINAPI CleanNtmsDrive(HANDLE hSession,LPNTMS_GUID lpDriveId);
  DWORD WINAPI DismountNtmsDrive(HANDLE hSession,LPNTMS_GUID lpDriveId);
  DWORD WINAPI InventoryNtmsLibrary(HANDLE hSession,LPNTMS_GUID lpLibraryId,DWORD dwAction);
  DWORD WINAPI IdentifyNtmsSlot(HANDLE hSession,LPNTMS_GUID lpSlotId,DWORD dwOption);

#define NTMS_OMID_TYPE_RAW_LABEL 0x01
#define NTMS_OMID_TYPE_FILESYSTEM_INFO 0x02

  typedef struct {
    WCHAR FileSystemType[64];
    WCHAR VolumeName[256];
    DWORD SerialNumber;
  } NTMS_FILESYSTEM_INFO;

  DWORD WINAPI UpdateNtmsOmidInfo(HANDLE hSession,LPNTMS_GUID lpMediaId,DWORD labelType,DWORD numberOfBytes,LPVOID lpBuffer);
  DWORD WINAPI CancelNtmsLibraryRequest(HANDLE hSession,LPNTMS_GUID lpRequestId);
  DWORD WINAPI GetNtmsRequestOrder(HANDLE hSession,LPNTMS_GUID lpRequestId,LPDWORD lpdwOrderNumber);
  DWORD WINAPI SetNtmsRequestOrder(HANDLE hSession,LPNTMS_GUID lpRequestId,DWORD dwOrderNumber);
  DWORD WINAPI DeleteNtmsRequests(HANDLE hSession,LPNTMS_GUID lpRequestId,DWORD dwType,DWORD dwCount);
  DWORD WINAPI ReserveNtmsCleanerSlot (HANDLE hSession,LPNTMS_GUID lpLibrary,LPNTMS_GUID lpSlot);
  DWORD WINAPI ReleaseNtmsCleanerSlot (HANDLE hSession,LPNTMS_GUID lpLibrary);
  DWORD WINAPI InjectNtmsCleaner (HANDLE hSession,LPNTMS_GUID lpLibrary,LPNTMS_GUID lpInjectOperation,DWORD dwNumberOfCleansLeft,DWORD dwAction);
  DWORD WINAPI EjectNtmsCleaner (HANDLE hSession,LPNTMS_GUID lpLibrary,LPNTMS_GUID lpEjectOperation,DWORD dwAction);
  DWORD WINAPI BeginNtmsDeviceChangeDetection(HANDLE hSession,LPHANDLE lpDetectHandle);
  DWORD WINAPI SetNtmsDeviceChangeDetection(HANDLE hSession,HANDLE DetectHandle,LPNTMS_GUID lpRequestId,DWORD dwType,DWORD dwCount);
  DWORD WINAPI EndNtmsDeviceChangeDetection(HANDLE hSession,HANDLE DetectHandle);

#ifndef NTMS_NOREDEF
  enum NtmsDriveType {
    NTMS_UNKNOWN_DRIVE = 0
  };
#endif

  DWORD WINAPI GetNtmsObjectSecurity(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,SECURITY_INFORMATION RequestedInformation,PSECURITY_DESCRIPTOR lpSecurityDescriptor,DWORD nLength,LPDWORD lpnLengthNeeded);
  DWORD WINAPI SetNtmsObjectSecurity(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR lpSecurityDescriptor);
  enum NtmsAccessMask {
    NTMS_USE_ACCESS = 0x1,
    NTMS_MODIFY_ACCESS = 0x2,
    NTMS_CONTROL_ACCESS = 0x4 /* Hmm, could be 3, too. */
  };

#define NTMS_GENERIC_READ NTMS_USE_ACCESS
#define NTMS_GENERIC_WRITE NTMS_USE_ACCESS | NTMS_MODIFY_ACCESS
#define NTMS_GENERIC_EXECUTE NTMS_USE_ACCESS | NTMS_MODIFY_ACCESS | NTMS_CONTROL_ACCESS
#define NTMS_GENERIC_ALL NTMS_USE_ACCESS | NTMS_MODIFY_ACCESS | NTMS_CONTROL_ACCESS

#define NTMS_MAXATTR_LENGTH 0x10000
#define NTMS_MAXATTR_NAMELEN 32

  DWORD WINAPI GetNtmsObjectAttributeA(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,LPCSTR lpAttributeName,LPVOID lpAttributeData,LPDWORD lpAttributeSize);
  DWORD WINAPI GetNtmsObjectAttributeW(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,LPCWSTR lpAttributeName,LPVOID lpAttributeData,LPDWORD lpAttributeSize);
  DWORD WINAPI SetNtmsObjectAttributeA(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,LPCSTR lpAttributeName,LPVOID lpAttributeData,DWORD dwAttributeSize);
  DWORD WINAPI SetNtmsObjectAttributeW(HANDLE hSession,LPNTMS_GUID lpObjectId,DWORD dwType,LPCWSTR lpAttributeName,LPVOID lpAttributeData,DWORD AttributeSize);

  enum NtmsUITypes {
    NTMS_UITYPE_INVALID = 0,
    NTMS_UITYPE_INFO,NTMS_UITYPE_REQ,NTMS_UITYPE_ERR,NTMS_UITYPE_MAX
  };

  enum NtmsUIOperations {
    NTMS_UIDEST_ADD = 1,
    NTMS_UIDEST_DELETE,NTMS_UIDEST_DELETEALL,
    NTMS_UIOPERATION_MAX
  };

  DWORD WINAPI GetNtmsUIOptionsA(HANDLE hSession,const LPNTMS_GUID lpObjectId,DWORD dwType,LPSTR lpszDestination,LPDWORD lpdwBufSize);
  DWORD WINAPI GetNtmsUIOptionsW(HANDLE hSession,const LPNTMS_GUID lpObjectId,DWORD dwType,LPWSTR lpszDestination,LPDWORD lpdwBufSize);
  DWORD WINAPI SetNtmsUIOptionsA(HANDLE hSession,const LPNTMS_GUID lpObjectId,DWORD dwType,DWORD dwOperation,LPCSTR lpszDestination);
  DWORD WINAPI SetNtmsUIOptionsW(HANDLE hSession,const LPNTMS_GUID lpObjectId,DWORD dwType,DWORD dwOperation,LPCWSTR lpszDestination);
  DWORD WINAPI SubmitNtmsOperatorRequestW(HANDLE hSession,DWORD dwRequest,LPCWSTR lpMessage,LPNTMS_GUID lpArg1Id,LPNTMS_GUID lpArg2Id,LPNTMS_GUID lpRequestId);
  DWORD WINAPI SubmitNtmsOperatorRequestA(HANDLE hSession,DWORD dwRequest,LPCSTR lpMessage,LPNTMS_GUID lpArg1Id,LPNTMS_GUID lpArg2Id,LPNTMS_GUID lpRequestId);
  DWORD WINAPI WaitForNtmsOperatorRequest(HANDLE hSession,LPNTMS_GUID lpRequestId,DWORD dwTimeout);
  DWORD WINAPI CancelNtmsOperatorRequest(HANDLE hSession,LPNTMS_GUID lpRequestId);
  DWORD WINAPI SatisfyNtmsOperatorRequest(HANDLE hSession,LPNTMS_GUID lpRequestId);

#ifndef NTMS_NOREDEF
  enum NtmsNotificationOperations {
    NTMS_OBJ_UPDATE = 1,
    NTMS_OBJ_INSERT,NTMS_OBJ_DELETE,NTMS_EVENT_SIGNAL,NTMS_EVENT_COMPLETE
  };

  typedef struct _NTMS_NOTIFICATIONINFORMATION {
    DWORD dwOperation;
    NTMS_GUID ObjectId;
  } NTMS_NOTIFICATIONINFORMATION,*LPNTMS_NOTIFICATIONINFORMATION;
#endif

  DWORD WINAPI ImportNtmsDatabase(HANDLE hSession);
  DWORD WINAPI ExportNtmsDatabase(HANDLE hSession);
  DWORD WINAPI ImportNtmsDatabase(HANDLE hSession);
  DWORD WINAPI ExportNtmsDatabase(HANDLE hSession);
  HANDLE WINAPI OpenNtmsNotification(HANDLE hSession,DWORD dwType);
  DWORD WINAPI WaitForNtmsNotification(HANDLE hNotification,LPNTMS_NOTIFICATIONINFORMATION lpNotificationInformation,DWORD dwTimeout);
  DWORD WINAPI CloseNtmsNotification(HANDLE hNotification);
  DWORD WINAPI EjectDiskFromSADriveW(LPCWSTR lpComputerName,LPCWSTR lpAppName,LPCWSTR lpDeviceName,HWND hWnd,LPCWSTR lpTitle,LPCWSTR lpMessage,DWORD dwOptions);
  DWORD WINAPI EjectDiskFromSADriveA(LPCSTR lpComputerName,LPCSTR lpAppName,LPCSTR lpDeviceName,HWND hWnd,LPCSTR lpTitle,LPCSTR lpMessage,DWORD dwOptions);
  DWORD WINAPI GetVolumesFromDriveW(LPWSTR pszDriveName,LPWSTR *VolumeNameBufferPtr,LPWSTR *DriveLetterBufferPtr);
  DWORD WINAPI GetVolumesFromDriveA(LPSTR pszDriveName,LPSTR *VolumeNameBufferPtr,LPSTR *DriveLetterBufferPtr);

#ifdef __cplusplus
}
#endif

#pragma pack()
#endif
