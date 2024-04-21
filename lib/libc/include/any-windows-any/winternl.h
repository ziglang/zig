/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINTERNL_
#define _WINTERNL_

#include <windef.h>

#ifndef NT_SUCCESS
#define NT_SUCCESS(status) ((NTSTATUS) (status) >= 0)
#endif

#ifndef NT_INFORMATION
#define NT_INFORMATION(Status) ((((ULONG)(Status)) >> 30) == 1)
#endif

#ifndef NT_WARNING
#define NT_WARNING(Status) ((((ULONG)(Status)) >> 30) == 2)
#endif

#ifndef NT_ERROR
#define NT_ERROR(Status) ((((ULONG)(Status)) >> 30) == 3)
#endif

#ifndef DEVICE_TYPE
#define DEVICE_TYPE ULONG
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __UNICODE_STRING_DEFINED
#define __UNICODE_STRING_DEFINED
  typedef struct _UNICODE_STRING {
    USHORT Length;
    USHORT MaximumLength;
    PWSTR Buffer;
  } UNICODE_STRING;
#endif

  typedef struct _PEB_LDR_DATA {
    BYTE Reserved1[8];
    PVOID Reserved2[3];
    LIST_ENTRY InMemoryOrderModuleList;
  } PEB_LDR_DATA,*PPEB_LDR_DATA;
 
  typedef struct _LDR_DATA_TABLE_ENTRY {
    PVOID Reserved1[2];
    LIST_ENTRY InMemoryOrderLinks;
    PVOID Reserved2[2];
    PVOID DllBase;
    PVOID Reserved3[2];
    UNICODE_STRING FullDllName;
    BYTE Reserved4[8];
    PVOID Reserved5[3];
    __C89_NAMELESS union {
      ULONG CheckSum;
      PVOID Reserved6;
    };
    ULONG TimeDateStamp;
  } LDR_DATA_TABLE_ENTRY,*PLDR_DATA_TABLE_ENTRY;

typedef struct _RTL_USER_PROCESS_PARAMETERS {
    BYTE Reserved1[16];
    PVOID Reserved2[10];
    UNICODE_STRING ImagePathName;
    UNICODE_STRING CommandLine;
  } RTL_USER_PROCESS_PARAMETERS,*PRTL_USER_PROCESS_PARAMETERS;
  
  /* This function pointer is undocumented and just valid for windows 2000.
     Therefore I guess.  */
  typedef VOID (NTAPI *PPS_POST_PROCESS_INIT_ROUTINE)(VOID);
  
  typedef struct _PEB {
    BYTE Reserved1[2];
    BYTE BeingDebugged;
    BYTE Reserved2[1];
    PVOID Reserved3[2];
    PPEB_LDR_DATA Ldr;
    PRTL_USER_PROCESS_PARAMETERS ProcessParameters;
    PVOID Reserved4[3];
    PVOID AtlThunkSListPtr;
    PVOID Reserved5;
    ULONG Reserved6;
    PVOID Reserved7;
    ULONG Reserved8;
    ULONG AtlThunkSListPtr32;
    PVOID Reserved9[45];
    BYTE Reserved10[96];
    PPS_POST_PROCESS_INIT_ROUTINE PostProcessInitRoutine;
    BYTE Reserved11[128];
    PVOID Reserved12[1];
    ULONG SessionId;
  } PEB,*PPEB;

  typedef struct _TEB {
    PVOID Reserved1[12];
    PPEB ProcessEnvironmentBlock;
    PVOID Reserved2[399];
    BYTE Reserved3[1952];
    PVOID TlsSlots[64];
    BYTE Reserved4[8];
    PVOID Reserved5[26];
    PVOID ReservedForOle;
    PVOID Reserved6[4];
    PVOID TlsExpansionSlots;
  } TEB;

  typedef TEB *PTEB;
  #if !defined (_NTDEF_) && !defined (_NTSTATUS_PSDK)
  #define _NTSTATUS_PSDK
  typedef LONG NTSTATUS, *PNTSTATUS;
  #endif
  typedef CONST char *PCSZ;

#ifndef __STRING_DEFINED
#define __STRING_DEFINED
  typedef struct _STRING {
    USHORT Length;
    USHORT MaximumLength;
    PCHAR Buffer;
  } STRING;
#endif

  typedef STRING *PSTRING;
  typedef STRING ANSI_STRING;
  typedef PSTRING PANSI_STRING;
  typedef PSTRING PCANSI_STRING;
  typedef STRING OEM_STRING;
  typedef PSTRING POEM_STRING;
  typedef CONST STRING *PCOEM_STRING;

  typedef UNICODE_STRING *PUNICODE_STRING;
  typedef const UNICODE_STRING *PCUNICODE_STRING;

#ifndef __OBJECT_ATTRIBUTES_DEFINED
#define __OBJECT_ATTRIBUTES_DEFINED
  typedef struct _OBJECT_ATTRIBUTES {
    ULONG Length;
#ifdef _WIN64
    ULONG pad1;
#endif
    HANDLE RootDirectory;
    PUNICODE_STRING ObjectName;
    ULONG Attributes;
#ifdef _WIN64
    ULONG pad2;
#endif
    PVOID SecurityDescriptor;
    PVOID SecurityQualityOfService;
  } OBJECT_ATTRIBUTES, *POBJECT_ATTRIBUTES;
#endif

/* Values for the Attributes member */
#define OBJ_INHERIT 0x00000002L
#define OBJ_PERMANENT 0x00000010L
#define OBJ_EXCLUSIVE 0x00000020L
#define OBJ_CASE_INSENSITIVE 0x00000040L
#define OBJ_OPENIF 0x00000080L
#define OBJ_OPENLINK 0x00000100L
#define OBJ_KERNEL_HANDLE 0x00000200L
#define OBJ_FORCE_ACCESS_CHECK 0x00000400L
#define OBJ_IGNORE_IMPERSONATED_DEVICEMAP 0x00000800L
#define OBJ_DONT_REPARSE 0x00001000L
#define OBJ_VALID_ATTRIBUTES 0x00001FF2L

/* Define the create disposition values */
#define FILE_SUPERSEDE 0x00000000
#define FILE_OPEN 0x00000001
#define FILE_CREATE 0x00000002
#define FILE_OPEN_IF 0x00000003
#define FILE_OVERWRITE 0x00000004
#define FILE_OVERWRITE_IF 0x00000005
#define FILE_MAXIMUM_DISPOSITION 0x00000005

/* Define the create/open option flags */
#define FILE_DIRECTORY_FILE 0x00000001
#define FILE_WRITE_THROUGH 0x00000002
#define FILE_SEQUENTIAL_ONLY 0x00000004
#define FILE_NO_INTERMEDIATE_BUFFERING 0x00000008
#define FILE_SYNCHRONOUS_IO_ALERT 0x00000010
#define FILE_SYNCHRONOUS_IO_NONALERT 0x00000020
#define FILE_NON_DIRECTORY_FILE 0x00000040
#define FILE_CREATE_TREE_CONNECTION 0x00000080
#define FILE_COMPLETE_IF_OPLOCKED 0x00000100
#define FILE_NO_EA_KNOWLEDGE 0x00000200
#define FILE_OPEN_REMOTE_INSTANCE 0x00000400
#define FILE_RANDOM_ACCESS 0x00000800
#define FILE_DELETE_ON_CLOSE 0x00001000
#define FILE_OPEN_BY_FILE_ID 0x00002000
#define FILE_OPEN_FOR_BACKUP_INTENT 0x00004000
#define FILE_NO_COMPRESSION 0x00008000
#if (_WIN32_WINNT >= _WIN32_WINNT_WIN7)
#define FILE_OPEN_REQUIRING_OPLOCK 0x00010000
#endif
#define FILE_RESERVE_OPFILTER 0x00100000
#define FILE_OPEN_REPARSE_POINT 0x00200000
#define FILE_OPEN_NO_RECALL 0x00400000
#define FILE_OPEN_FOR_FREE_SPACE_QUERY 0x00800000
#define FILE_VALID_OPTION_FLAGS 0x00ffffff
#define FILE_VALID_PIPE_OPTION_FLAGS 0x00000032
#define FILE_VALID_MAILSLOT_OPTION_FLAGS 0x00000032
#define FILE_VALID_SET_FLAGS 0x00000036

/* Define the I/O status information return values for NtCreateFile/NtOpenFile */
#define FILE_SUPERSEDED 0x00000000
#define FILE_OPENED 0x00000001
#define FILE_CREATED 0x00000002
#define FILE_OVERWRITTEN 0x00000003
#define FILE_EXISTS 0x00000004
#define FILE_DOES_NOT_EXIST 0x00000005

 /* Helper Macro */
#ifndef InitializeObjectAttributes
 #define InitializeObjectAttributes(p,n,a,r,s) { \
   (p)->Length = sizeof(OBJECT_ATTRIBUTES); \
   (p)->RootDirectory = (r); \
   (p)->Attributes = (a); \
   (p)->ObjectName = (n); \
   (p)->SecurityDescriptor = (s); \
   (p)->SecurityQualityOfService = NULL; \
 }
#endif

  typedef struct _OBJECT_DATA_INFORMATION {
    BOOLEAN InheritHandle;
    BOOLEAN ProtectFromClose;
  } OBJECT_DATA_INFORMATION, *POBJECT_DATA_INFORMATION;

  typedef struct _OBJECT_BASIC_INFORMATION {
    ULONG  Attributes;
    ACCESS_MASK  GrantedAccess;
    ULONG  HandleCount;
    ULONG  PointerCount;
    ULONG  PagedPoolUsage;
    ULONG  NonPagedPoolUsage;
    ULONG  Reserved[3];
    ULONG  NameInformationLength;
    ULONG  TypeInformationLength;
    ULONG  SecurityDescriptorLength;
    LARGE_INTEGER  CreateTime;
  } OBJECT_BASIC_INFORMATION, *POBJECT_BASIC_INFORMATION;

  typedef struct _OBJECT_NAME_INFORMATION {
    UNICODE_STRING Name;
  } OBJECT_NAME_INFORMATION, *POBJECT_NAME_INFORMATION;

  typedef struct _OBJECT_TYPE_INFORMATION {
    UNICODE_STRING TypeName;
    ULONG TotalNumberOfObjects;
    ULONG TotalNumberOfHandles;
    ULONG TotalPagedPoolUsage;
    ULONG TotalNonPagedPoolUsage;
    ULONG TotalNamePoolUsage;
    ULONG TotalHandleTableUsage;
    ULONG HighWaterNumberOfObjects;
    ULONG HighWaterNumberOfHandles;
    ULONG HighWaterPagedPoolUsage;
    ULONG HighWaterNonPagedPoolUsage;
    ULONG HighWaterNamePoolUsage;
    ULONG HighWaterHandleTableUsage;
    ULONG InvalidAttributes;
    GENERIC_MAPPING GenericMapping;
    ULONG ValidAccessMask;
    BOOLEAN SecurityRequired;
    BOOLEAN MaintainHandleCount;
    ULONG PoolType;
    ULONG DefaultPagedPoolCharge;
    ULONG DefaultNonPagedPoolCharge;
  } OBJECT_TYPE_INFORMATION, *POBJECT_TYPE_INFORMATION;

  typedef struct _OBJECT_ALL_INFORMATION { 
    ULONG NumberOfObjects; 
    OBJECT_TYPE_INFORMATION ObjectTypeInformation[1]; 
  }OBJECT_ALL_INFORMATION, *POBJECT_ALL_INFORMATION;

  typedef enum _FILE_INFORMATION_CLASS {
    FileDirectoryInformation = 1,
    FileFullDirectoryInformation,
    FileBothDirectoryInformation,
    FileBasicInformation,
    FileStandardInformation,
    FileInternalInformation,
    FileEaInformation,
    FileAccessInformation,
    FileNameInformation,
    FileRenameInformation,
    FileLinkInformation,
    FileNamesInformation,
    FileDispositionInformation,
    FilePositionInformation,
    FileFullEaInformation,
    FileModeInformation,
    FileAlignmentInformation,
    FileAllInformation,
    FileAllocationInformation,
    FileEndOfFileInformation,
    FileAlternateNameInformation,
    FileStreamInformation,
    FilePipeInformation,
    FilePipeLocalInformation,
    FilePipeRemoteInformation,
    FileMailslotQueryInformation,
    FileMailslotSetInformation,
    FileCompressionInformation,
    FileObjectIdInformation,
    FileCompletionInformation,
    FileMoveClusterInformation,
    FileQuotaInformation,
    FileReparsePointInformation,
    FileNetworkOpenInformation,
    FileAttributeTagInformation,
    FileTrackingInformation,
    FileIdBothDirectoryInformation,
    FileIdFullDirectoryInformation,
    FileValidDataLengthInformation,
    FileShortNameInformation = 40,
    FileSfioReserveInformation = 44,
    FileSfioVolumeInformation = 45,
    FileHardLinkInformation = 46,
    FileNormalizedNameInformation = 48,
    FileIdGlobalTxDirectoryInformation = 50,
    FileStandardLinkInformation = 54,
    FileMaximumInformation
  } FILE_INFORMATION_CLASS, *PFILE_INFORMATION_CLASS;

  typedef struct _FILE_DIRECTORY_INFORMATION {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    WCHAR FileName[ANYSIZE_ARRAY];
  } FILE_DIRECTORY_INFORMATION, *PFILE_DIRECTORY_INFORMATION;

  typedef struct _FILE_FULL_DIR_INFORMATION {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    WCHAR FileName[ANYSIZE_ARRAY];
  } FILE_FULL_DIR_INFORMATION, *PFILE_FULL_DIR_INFORMATION;

  typedef struct _FILE_ID_FULL_DIR_INFORMATION {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    LARGE_INTEGER FileId;
    WCHAR FileName[ANYSIZE_ARRAY];
  } FILE_ID_FULL_DIR_INFORMATION, *PFILE_ID_FULL_DIR_INFORMATION;

  typedef struct _FILE_BOTH_DIR_INFORMATION {
    ULONG NextEntryOffset;
	 ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    CHAR ShortNameLength;
    WCHAR ShortName[12];
    WCHAR FileName[ANYSIZE_ARRAY];
  } FILE_BOTH_DIR_INFORMATION, *PFILE_BOTH_DIR_INFORMATION;

  typedef struct _FILE_ID_BOTH_DIR_INFORMATION {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    CHAR ShortNameLength;
    WCHAR ShortName[12];
    LARGE_INTEGER FileId;
    WCHAR FileName[ANYSIZE_ARRAY];
  } FILE_ID_BOTH_DIR_INFORMATION, *PFILE_ID_BOTH_DIR_INFORMATION;

  /* Old names of dir info structures as (partially) used in Nebbitt's
     Native API Reference.  Keep for backward compatibility. */
  typedef struct _FILE_FULL_DIR_INFORMATION
    FILE_FULL_DIRECTORY_INFORMATION, *PFILE_FULL_DIRECTORY_INFORMATION;
  typedef struct _FILE_ID_FULL_DIR_INFORMATION
    FILE_ID_FULL_DIRECTORY_INFORMATION, *PFILE_ID_FULL_DIRECTORY_INFORMATION;
  typedef struct _FILE_BOTH_DIR_INFORMATION
    FILE_BOTH_DIRECTORY_INFORMATION, *PFILE_BOTH_DIRECTORY_INFORMATION;
  typedef struct _FILE_ID_BOTH_DIR_INFORMATION
    FILE_ID_BOTH_DIRECTORY_INFORMATION, *PFILE_ID_BOTH_DIRECTORY_INFORMATION;

  typedef struct _FILE_BASIC_INFORMATION {
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    ULONG FileAttributes;
  } FILE_BASIC_INFORMATION, *PFILE_BASIC_INFORMATION;

  typedef struct _FILE_STANDARD_INFORMATION {
    LARGE_INTEGER AllocationSize;
    LARGE_INTEGER EndOfFile;
    ULONG NumberOfLinks;
    BOOLEAN DeletePending;
    BOOLEAN Directory;
  } FILE_STANDARD_INFORMATION, *PFILE_STANDARD_INFORMATION;

  typedef struct _FILE_INTERNAL_INFORMATION {
    LARGE_INTEGER IndexNumber;
  } FILE_INTERNAL_INFORMATION, *PFILE_INTERNAL_INFORMATION;

  typedef struct _FILE_EA_INFORMATION {
    ULONG EaSize;
  } FILE_EA_INFORMATION, *PFILE_EA_INFORMATION;

  typedef struct _FILE_ACCESS_INFORMATION {
    ACCESS_MASK AccessFlags;
  } FILE_ACCESS_INFORMATION, *PFILE_ACCESS_INFORMATION;

  typedef struct _FILE_LINK_INFORMATION {
    BOOLEAN ReplaceIfExists;
    HANDLE RootDirectory;
    ULONG FileNameLength;
    WCHAR FileName[1];
  } FILE_LINK_INFORMATION, *PFILE_LINK_INFORMATION;

  typedef struct _FILE_NAME_INFORMATION {
    ULONG FileNameLength;
    WCHAR FileName[1];
  } FILE_NAME_INFORMATION, *PFILE_NAME_INFORMATION;

  typedef struct _FILE_RENAME_INFORMATION {
    BOOLEAN ReplaceIfExists;
    HANDLE RootDirectory;
    ULONG FileNameLength;
    WCHAR FileName[1];
  } FILE_RENAME_INFORMATION, *PFILE_RENAME_INFORMATION;

  typedef struct _FILE_NAMES_INFORMATION {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    ULONG FileNameLength;
    WCHAR FileName[1];
  } FILE_NAMES_INFORMATION, *PFILE_NAMES_INFORMATION;

  typedef struct _FILE_DISPOSITION_INFORMATION {
    BOOLEAN DoDeleteFile;
  } FILE_DISPOSITION_INFORMATION, *PFILE_DISPOSITION_INFORMATION;

  typedef struct _FILE_POSITION_INFORMATION {
    LARGE_INTEGER CurrentByteOffset;
  } FILE_POSITION_INFORMATION, *PFILE_POSITION_INFORMATION;

  typedef struct _FILE_ALIGNMENT_INFORMATION {
    ULONG AlignmentRequirement;
  } FILE_ALIGNMENT_INFORMATION, *PFILE_ALIGNMENT_INFORMATION;

  typedef struct _FILE_ALLOCATION_INFORMATION {
    LARGE_INTEGER AllocationSize;
  } FILE_ALLOCATION_INFORMATION, *PFILE_ALLOCATION_INFORMATION;

  typedef struct _FILE_END_OF_FILE_INFORMATION {
    LARGE_INTEGER EndOfFile;
  } FILE_END_OF_FILE_INFORMATION, *PFILE_END_OF_FILE_INFORMATION;

  typedef struct _FILE_NETWORK_OPEN_INFORMATION {
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER AllocationSize;
    LARGE_INTEGER EndOfFile;
    ULONG FileAttributes;
  } FILE_NETWORK_OPEN_INFORMATION, *PFILE_NETWORK_OPEN_INFORMATION;

  typedef struct _FILE_FULL_EA_INFORMATION {
    ULONG NextEntryOffset;
    UCHAR Flags;
    UCHAR EaNameLength;
    USHORT EaValueLength;
    CHAR EaName[1];
  } FILE_FULL_EA_INFORMATION, *PFILE_FULL_EA_INFORMATION;

  typedef struct _FILE_MODE_INFORMATION {
    ULONG Mode;
  } FILE_MODE_INFORMATION, *PFILE_MODE_INFORMATION;

  typedef struct _FILE_STREAM_INFORMATION {
    ULONG NextEntryOffset;
    ULONG StreamNameLength;
    LARGE_INTEGER StreamSize;
    LARGE_INTEGER StreamAllocationSize;
    WCHAR StreamName[1];
  } FILE_STREAM_INFORMATION, *PFILE_STREAM_INFORMATION;

  typedef struct _FILE_ATTRIBUTE_TAG_INFORMATION {
    ULONG FileAttributes;
    ULONG ReparseTag;
  } FILE_ATTRIBUTE_TAG_INFORMATION, *PFILE_ATTRIBUTE_TAG_INFORMATION;

  typedef struct _FILE_MAILSLOT_QUERY_INFORMATION {
    ULONG MaximumMessageSize;
    ULONG MailslotQuota;
    ULONG NextMessageSize;
    ULONG MessagesAvailable;
    LARGE_INTEGER ReadTimeout;
  } FILE_MAILSLOT_QUERY_INFORMATION, *PFILE_MAILSLOT_QUERY_INFORMATION;

  typedef struct _FILE_MAILSLOT_SET_INFORMATION {
    LARGE_INTEGER ReadTimeout;
  } FILE_MAILSLOT_SET_INFORMATION, *PFILE_MAILSLOT_SET_INFORMATION;

  typedef struct _FILE_PIPE_LOCAL_INFORMATION {
    ULONG NamedPipeType;
    ULONG NamedPipeConfiguration;
    ULONG MaximumInstances;
    ULONG CurrentInstances;
    ULONG InboundQuota;
    ULONG ReadDataAvailable;
    ULONG OutboundQuota;
    ULONG WriteQuotaAvailable;
    ULONG NamedPipeState;
    ULONG NamedPipeEnd;
  } FILE_PIPE_LOCAL_INFORMATION, *PFILE_PIPE_LOCAL_INFORMATION;

  typedef struct _FILE_ALL_INFORMATION {
    FILE_BASIC_INFORMATION     BasicInformation;
    FILE_STANDARD_INFORMATION  StandardInformation;
    FILE_INTERNAL_INFORMATION  InternalInformation;
    FILE_EA_INFORMATION        EaInformation;
    FILE_ACCESS_INFORMATION    AccessInformation;
    FILE_POSITION_INFORMATION  PositionInformation;
    FILE_MODE_INFORMATION      ModeInformation;
    FILE_ALIGNMENT_INFORMATION AlignmentInformation;
    FILE_NAME_INFORMATION      NameInformation;
  } FILE_ALL_INFORMATION, *PFILE_ALL_INFORMATION;

  typedef enum _FSINFOCLASS {
    FileFsVolumeInformation = 1,
    FileFsLabelInformation,
    FileFsSizeInformation,
    FileFsDeviceInformation,
    FileFsAttributeInformation,
    FileFsControlInformation,
    FileFsFullSizeInformation,
    FileFsObjectIdInformation,
    FileFsDriverPathInformation,
    FileFsVolumeFlagsInformation,
    FileFsMaximumInformation
  } FS_INFORMATION_CLASS, *PFS_INFORMATION_CLASS;

  typedef struct _FILE_FS_VOLUME_INFORMATION {
    LARGE_INTEGER VolumeCreationTime;
    ULONG VolumeSerialNumber;
    ULONG VolumeLabelLength;
    BOOLEAN SupportsObjects;
    WCHAR VolumeLabel[1];
  } FILE_FS_VOLUME_INFORMATION, *PFILE_FS_VOLUME_INFORMATION;

  typedef struct _FILE_FS_LABEL_INFORMATION {
    ULONG VolumeLabelLength;
    WCHAR VolumeLabel[1];
  } FILE_FS_LABEL_INFORMATION, *PFILE_FS_LABEL_INFORMATION;

  typedef struct _FILE_FS_SIZE_INFORMATION {
    LARGE_INTEGER TotalAllocationUnits;
    LARGE_INTEGER AvailableAllocationUnits;
    ULONG SectorsPerAllocationUnit;
    ULONG BytesPerSector;
  } FILE_FS_SIZE_INFORMATION, *PFILE_FS_SIZE_INFORMATION;

  typedef struct _FILE_FS_DEVICE_INFORMATION {
    DEVICE_TYPE DeviceType;
    ULONG Characteristics;
  } FILE_FS_DEVICE_INFORMATION, *PFILE_FS_DEVICE_INFORMATION;

  typedef struct _FILE_FS_ATTRIBUTE_INFORMATION {
    ULONG FileSystemAttributes;
    ULONG MaximumComponentNameLength;
    ULONG FileSystemNameLength;
    WCHAR FileSystemName[1];
  } FILE_FS_ATTRIBUTE_INFORMATION, *PFILE_FS_ATTRIBUTE_INFORMATION;

  typedef struct _FILE_FS_FULL_SIZE_INFORMATION {
    LARGE_INTEGER TotalAllocationUnits;
    LARGE_INTEGER CallerAvailableAllocationUnits;
    LARGE_INTEGER ActualAvailableAllocationUnits;
    ULONG SectorsPerAllocationUnit;
    ULONG BytesPerSector;
  } FILE_FS_FULL_SIZE_INFORMATION, *PFILE_FS_FULL_SIZE_INFORMATION;

  typedef struct _FILE_FS_OBJECTID_INFORMATION {
    UCHAR ObjectId[16];
    UCHAR ExtendedInfo[48];
  } FILE_FS_OBJECTID_INFORMATION, *PFILE_FS_OBJECTID_INFORMATION;

  typedef struct _IO_STATUS_BLOCK {
    __C89_NAMELESS union {
      NTSTATUS Status;
      PVOID Pointer;
    };
    ULONG_PTR Information;
  } IO_STATUS_BLOCK,*PIO_STATUS_BLOCK;

  typedef VOID (NTAPI *PIO_APC_ROUTINE)(PVOID ApcContext,PIO_STATUS_BLOCK IoStatusBlock,ULONG Reserved);

#ifdef __ia64__
  typedef struct _FRAME_POINTERS {
    ULONGLONG MemoryStackFp;
    ULONGLONG BackingStoreFp;
  } FRAME_POINTERS,*PFRAME_POINTERS;

#define UNWIND_HISTORY_TABLE_SIZE 12

  typedef struct _RUNTIME_FUNCTION {
    ULONG BeginAddress;
    ULONG EndAddress;
    ULONG UnwindInfoAddress;
  } RUNTIME_FUNCTION,*PRUNTIME_FUNCTION;

  typedef struct _UNWIND_HISTORY_TABLE_ENTRY {
    ULONG64 ImageBase;
    ULONG64 Gp;
    PRUNTIME_FUNCTION FunctionEntry;
  } UNWIND_HISTORY_TABLE_ENTRY,*PUNWIND_HISTORY_TABLE_ENTRY;

  typedef struct _UNWIND_HISTORY_TABLE {
    ULONG Count;
    UCHAR Search;
    ULONG64 LowAddress;
    ULONG64 HighAddress;
    UNWIND_HISTORY_TABLE_ENTRY Entry[UNWIND_HISTORY_TABLE_SIZE];
  } UNWIND_HISTORY_TABLE,*PUNWIND_HISTORY_TABLE;
#endif

  typedef struct _VM_COUNTERS {
    SIZE_T PeakVirtualSize;
    SIZE_T VirtualSize;
    ULONG PageFaultCount;
    SIZE_T PeakWorkingSetSize;
    SIZE_T WorkingSetSize;
    SIZE_T QuotaPeakPagedPoolUsage;
    SIZE_T QuotaPagedPoolUsage;
    SIZE_T QuotaPeakNonPagedPoolUsage;
    SIZE_T QuotaNonPagedPoolUsage;
    SIZE_T PagefileUsage;
    SIZE_T PeakPagefileUsage;
  } VM_COUNTERS, *PVM_COUNTERS;

  typedef enum _THREAD_STATE {
    StateInitialized = 0,
    StateReady, StateRunning, StateStandby, StateTerminated,
    StateWait, StateTransition,
    StateUnknown
  } THREAD_STATE;

  typedef struct _CLIENT_ID {
    HANDLE UniqueProcess;
    HANDLE UniqueThread;
  } CLIENT_ID, *PCLIENT_ID;

  typedef LONG KPRIORITY;

  typedef enum _KWAIT_REASON {
    Executive = 0,
    FreePage, PageIn, PoolAllocation, DelayExecution,
    Suspended, UserRequest, WrExecutive, WrFreePage, WrPageIn,
    WrPoolAllocation, WrDelayExecution, WrSuspended,
    WrUserRequest, WrEventPair, WrQueue, WrLpcReceive,
    WrLpcReply, WrVirtualMemory, WrPageOut, WrRendezvous,
    Spare2, Spare3, Spare4, Spare5, Spare6, WrKernel,
    MaximumWaitReason
  } KWAIT_REASON;

  typedef struct _SYSTEM_THREADS
  {
    LARGE_INTEGER KernelTime;
    LARGE_INTEGER UserTime;
    LARGE_INTEGER CreateTime;
    ULONG WaitTime;
    PVOID StartAddress;
    CLIENT_ID ClientId;
    KPRIORITY Priority;
    KPRIORITY BasePriority;
    ULONG ContextSwitchCount;
    THREAD_STATE State;
    KWAIT_REASON WaitReason;
  } SYSTEM_THREADS, *PSYSTEM_THREADS;

  typedef struct _PROCESS_BASIC_INFORMATION {
    NTSTATUS ExitStatus;
    PPEB PebBaseAddress;
    KAFFINITY AffinityMask;
    KPRIORITY BasePriority;
    ULONG_PTR UniqueProcessId;
    ULONG_PTR InheritedFromUniqueProcessId;
  } PROCESS_BASIC_INFORMATION, *PPROCESS_BASIC_INFORMATION;

  typedef struct _KERNEL_USER_TIMES {
    FILETIME CreateTime;
    FILETIME ExitTime;
    LARGE_INTEGER KernelTime;
    LARGE_INTEGER UserTime;
  } KERNEL_USER_TIMES, *PKERNEL_USER_TIMES;

  typedef struct _SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION {
    LARGE_INTEGER IdleTime;
    LARGE_INTEGER KernelTime;
    LARGE_INTEGER UserTime;
    LARGE_INTEGER Reserved1[2];
    ULONG Reserved2;
  } SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION,*PSYSTEM_PROCESSOR_PERFORMANCE_INFORMATION;

  typedef struct _SYSTEM_PROCESS_INFORMATION {
    ULONG NextEntryOffset;
    ULONG NumberOfThreads;
    LARGE_INTEGER Reserved[3];
    LARGE_INTEGER CreateTime;
    LARGE_INTEGER UserTime;
    LARGE_INTEGER KernelTime;
    UNICODE_STRING ImageName;
    KPRIORITY BasePriority;
    HANDLE UniqueProcessId;
    HANDLE InheritedFromUniqueProcessId;
    ULONG HandleCount;
    ULONG SessionId;
    ULONG PageDirectoryBase;
    VM_COUNTERS VirtualMemoryCounters;
    SIZE_T PrivatePageCount;
    IO_COUNTERS IoCounters;
  } SYSTEM_PROCESS_INFORMATION,*PSYSTEM_PROCESS_INFORMATION;

  typedef struct _SYSTEM_THREAD_INFORMATION {
    LARGE_INTEGER Reserved1[3];
    ULONG Reserved2;
    PVOID StartAddress;
    CLIENT_ID ClientId;
    KPRIORITY Priority;
    LONG BasePriority;
    ULONG Reserved3;
    ULONG ThreadState;
    ULONG WaitReason;
  } SYSTEM_THREAD_INFORMATION, *PSYSTEM_THREAD_INFORMATION;

  typedef struct _SYSTEM_REGISTRY_QUOTA_INFORMATION {
    ULONG RegistryQuotaAllowed;
    ULONG RegistryQuotaUsed;
    PVOID Reserved1;
  } SYSTEM_REGISTRY_QUOTA_INFORMATION,*PSYSTEM_REGISTRY_QUOTA_INFORMATION;

  typedef struct _SYSTEM_BASIC_INFORMATION {
    BYTE Reserved1[4];
    ULONG MaximumIncrement;
    ULONG PhysicalPageSize;
    ULONG NumberOfPhysicalPages;
    ULONG LowestPhysicalPage;
    ULONG HighestPhysicalPage;
    ULONG AllocationGranularity;
    ULONG_PTR LowestUserAddress;
    ULONG_PTR HighestUserAddress;
    ULONG_PTR ActiveProcessors;
    CCHAR NumberOfProcessors;
  } SYSTEM_BASIC_INFORMATION,*PSYSTEM_BASIC_INFORMATION;

  typedef struct _SYSTEM_PROCESSOR_INFORMATION {
    USHORT ProcessorArchitecture;
    USHORT ProcessorLevel;
    USHORT ProcessorRevision;
    USHORT Unknown;
    ULONG FeatureBits;
  } SYSTEM_PROCESSOR_INFORMATION, *PSYSTEM_PROCESSOR_INFORMATION;

  typedef struct _SYSTEM_TIMEOFDAY_INFORMATION {
    LARGE_INTEGER BootTime;
    LARGE_INTEGER CurrentTime;
    LARGE_INTEGER TimeZoneBias;
    ULONG CurrentTimeZoneId;
    BYTE Reserved1[20];
  } SYSTEM_TIMEOFDAY_INFORMATION,*PSYSTEM_TIMEOFDAY_INFORMATION;

  typedef struct _SYSTEM_PERFORMANCE_INFORMATION {
    LARGE_INTEGER IdleTime;
    LARGE_INTEGER ReadTransferCount;
    LARGE_INTEGER WriteTransferCount;
    LARGE_INTEGER OtherTransferCount;
    ULONG ReadOperationCount;
    ULONG WriteOperationCount;
    ULONG OtherOperationCount;
    ULONG AvailablePages;
    ULONG TotalCommittedPages;
    ULONG TotalCommitLimit;
    ULONG PeakCommitment;
    ULONG PageFaults;
    ULONG WriteCopyFaults;
    ULONG TransitionFaults;
    ULONG CacheTransitionFaults;
    ULONG DemandZeroFaults;
    ULONG PagesRead;
    ULONG PageReadIos;
    ULONG CacheReads;
    ULONG CacheIos;
    ULONG PagefilePagesWritten;
    ULONG PagefilePageWriteIos;
    ULONG MappedFilePagesWritten;
    ULONG MappedFilePageWriteIos;
    ULONG PagedPoolUsage;
    ULONG NonPagedPoolUsage;
    ULONG PagedPoolAllocs;
    ULONG PagedPoolFrees;
    ULONG NonPagedPoolAllocs;
    ULONG NonPagedPoolFrees;
    ULONG TotalFreeSystemPtes;
    ULONG SystemCodePage;
    ULONG TotalSystemDriverPages;
    ULONG TotalSystemCodePages;
    ULONG SmallNonPagedLookasideListAllocateHits;
    ULONG SmallPagedLookasideListAllocateHits;
    ULONG Reserved3;
    ULONG MmSystemCachePage;
    ULONG PagedPoolPage;
    ULONG SystemDriverPage;
    ULONG FastReadNoWait;
    ULONG FastReadWait;
    ULONG FastReadResourceMiss;
    ULONG FastReadNotPossible;
    ULONG FastMdlReadNoWait;
    ULONG FastMdlReadWait;
    ULONG FastMdlReadResourceMiss;
    ULONG FastMdlReadNotPossible;
    ULONG MapDataNoWait;
    ULONG MapDataWait;
    ULONG MapDataNoWaitMiss;
    ULONG MapDataWaitMiss;
    ULONG PinMappedDataCount;
    ULONG PinReadNoWait;
    ULONG PinReadWait;
    ULONG PinReadNoWaitMiss;
    ULONG PinReadWaitMiss;
    ULONG CopyReadNoWait;
    ULONG CopyReadWait;
    ULONG CopyReadNoWaitMiss;
    ULONG CopyReadWaitMiss;
    ULONG MdlReadNoWait;
    ULONG MdlReadWait;
    ULONG MdlReadNoWaitMiss;
    ULONG MdlReadWaitMiss;
    ULONG ReadAheadIos;
    ULONG LazyWriteIos;
    ULONG LazyWritePages;
    ULONG DataFlushes;
    ULONG DataPages;
    ULONG ContextSwitches;
    ULONG FirstLevelTbFills;
    ULONG SecondLevelTbFills;
    ULONG SystemCalls;
  } SYSTEM_PERFORMANCE_INFORMATION, *PSYSTEM_PERFORMANCE_INFORMATION;

  typedef struct _SYSTEM_EXCEPTION_INFORMATION {
    BYTE Reserved1[16];
  } SYSTEM_EXCEPTION_INFORMATION,*PSYSTEM_EXCEPTION_INFORMATION;

  typedef struct _SYSTEM_LOOKASIDE_INFORMATION {
    BYTE Reserved1[32];
  } SYSTEM_LOOKASIDE_INFORMATION,*PSYSTEM_LOOKASIDE_INFORMATION;

  typedef struct _SYSTEM_INTERRUPT_INFORMATION {
    BYTE Reserved1[24];
  } SYSTEM_INTERRUPT_INFORMATION,*PSYSTEM_INTERRUPT_INFORMATION;

  typedef struct _SYSTEM_POLICY_INFORMATION {
    PVOID Reserved1[2];
    ULONG Reserved2[3];
  } SYSTEM_POLICY_INFORMATION, *PSYSTEM_POLICY_INFORMATION;

  typedef struct _SYSTEM_HANDLE_ENTRY {
    ULONG OwnerPid;
    BYTE ObjectType;
    BYTE HandleFlags;
    USHORT HandleValue;
    PVOID ObjectPointer;
    ULONG AccessMask;
  } SYSTEM_HANDLE_ENTRY, *PSYSTEM_HANDLE_ENTRY;

  typedef struct _SYSTEM_HANDLE_INFORMATION {
    ULONG Count;
    SYSTEM_HANDLE_ENTRY Handle[1];
  } SYSTEM_HANDLE_INFORMATION, *PSYSTEM_HANDLE_INFORMATION;

  typedef struct _SYSTEM_PAGEFILE_INFORMATION {
    ULONG NextEntryOffset;
    ULONG CurrentSize;
    ULONG TotalUsed;
    ULONG PeakUsed;
    UNICODE_STRING FileName;
  } SYSTEM_PAGEFILE_INFORMATION, *PSYSTEM_PAGEFILE_INFORMATION;

  typedef struct _PUBLIC_OBJECT_BASIC_INFORMATION {
    ULONG Attributes;
    ACCESS_MASK GrantedAccess;
    ULONG HandleCount;
    ULONG PointerCount;
    ULONG Reserved[10];
  } PUBLIC_OBJECT_BASIC_INFORMATION, *PPUBLIC_OBJECT_BASIC_INFORMATION;

  typedef struct __PUBLIC_OBJECT_TYPE_INFORMATION {
    UNICODE_STRING TypeName;
    ULONG Reserved[22];
  } PUBLIC_OBJECT_TYPE_INFORMATION, *PPUBLIC_OBJECT_TYPE_INFORMATION;

  typedef enum _PROCESSINFOCLASS {
    ProcessBasicInformation,
    ProcessQuotaLimits,
    ProcessIoCounters,
    ProcessVmCounters,
    ProcessTimes,
    ProcessBasePriority,
    ProcessRaisePriority,
    ProcessDebugPort,
    ProcessExceptionPort,
    ProcessAccessToken,
    ProcessLdtInformation,
    ProcessLdtSize,
    ProcessDefaultHardErrorMode,
    ProcessIoPortHandlers,
    ProcessPooledUsageAndLimits,
    ProcessWorkingSetWatch,
    ProcessUserModeIOPL,
    ProcessEnableAlignmentFaultFixup,
    ProcessPriorityClass,
    ProcessWx86Information,
    ProcessHandleCount,
    ProcessAffinityMask,
    ProcessPriorityBoost,
    ProcessDeviceMap,
    ProcessSessionInformation,
    ProcessForegroundInformation,
    ProcessWow64Information,
    ProcessImageFileName,
    ProcessLUIDDeviceMapsEnabled,
    ProcessBreakOnTermination,
    ProcessDebugObjectHandle,
    ProcessDebugFlags,
    ProcessHandleTracing,
    ProcessIoPriority,
    ProcessExecuteFlags,
    ProcessTlsInformation,
    ProcessCookie,
    ProcessImageInformation,
    ProcessCycleTime,
    ProcessPagePriority,
    ProcessInstrumentationCallback,
    ProcessThreadStackAllocation,
    ProcessWorkingSetWatchEx,
    ProcessImageFileNameWin32,
    ProcessImageFileMapping,
    ProcessAffinityUpdateMode,
    ProcessMemoryAllocationMode,
    ProcessGroupInformation,
    ProcessTokenVirtualizationEnabled,
    ProcessConsoleHostProcess,
    ProcessWindowInformation,
    MaxProcessInfoClass
  } PROCESSINFOCLASS;

  typedef enum _THREADINFOCLASS {
     ThreadBasicInformation,
     ThreadTimes,
     ThreadPriority,
     ThreadBasePriority,
     ThreadAffinityMask,
     ThreadImpersonationToken,
     ThreadDescriptorTableEntry,
     ThreadEnableAlignmentFaultFixup,
     ThreadEventPair,
     ThreadQuerySetWin32StartAddress,
     ThreadZeroTlsCell,
     ThreadPerformanceCount,
     ThreadAmILastThread,
     ThreadIdealProcessor,
     ThreadPriorityBoost,
     ThreadSetTlsArrayAddress,
     ThreadIsIoPending,
     ThreadHideFromDebugger
  } THREADINFOCLASS;

  typedef struct _THREAD_NAME_INFORMATION {
    UNICODE_STRING ThreadName;
  } THREAD_NAME_INFORMATION, *PTHREAD_NAME_INFORMATION;

#define CODEINTEGRITY_OPTION_ENABLED 0x01
#define CODEINTEGRITY_OPTION_TESTSIGN 0x02
#define CODEINTEGRITY_OPTION_UMCI_ENABLED 0x04
#define CODEINTEGRITY_OPTION_UMCI_AUDITMODE_ENABLED 0x08
#define CODEINTEGRITY_OPTION_UMCI_EXCLUSIONPATHS_ENABLED 0x10
#define CODEINTEGRITY_OPTION_TEST_BUILD 0x20
#define CODEINTEGRITY_OPTION_PREPRODUCTION_BUILD 0x40
#define CODEINTEGRITY_OPTION_DEBUGMODE_ENABLED 0x80
#define CODEINTEGRITY_OPTION_FLIGHT_BUILD 0x100
#define CODEINTEGRITY_OPTION_FLIGHTING_ENABLED 0x200
#define CODEINTEGRITY_OPTION_HVCI_KMCI_ENABLED 0x400
#define CODEINTEGRITY_OPTION_HVCI_KMCI_AUDITMODE_ENABLED 0x800
#define CODEINTEGRITY_OPTION_HVCI_KMCI_STRICTMODE_ENABLED 0x1000
#define CODEINTEGRITY_OPTION_HVCI_IUM_ENABLED 0x2000

  typedef struct _SYSTEM_CODEINTEGRITY_INFORMATION {
    ULONG Length;
    ULONG CodeIntegrityOptions;
  } SYSTEM_CODEINTEGRITY_INFORMATION, *PSYSTEM_CODEINTEGRITY_INFORMATION;

  typedef enum _SYSTEM_INFORMATION_CLASS {
    SystemBasicInformation = 0,
    SystemProcessorInformation = 1,
    SystemPerformanceInformation = 2,
    SystemTimeOfDayInformation = 3,
    SystemProcessInformation = 5,
    SystemProcessorPerformanceInformation = 8,
    SystemHandleInformation = 16,
    SystemPagefileInformation = 18,
    SystemInterruptInformation = 23,
    SystemExceptionInformation = 33,
    SystemRegistryQuotaInformation = 37,
    SystemLookasideInformation = 45,
    SystemCodeIntegrityInformation = 103,
    SystemPolicyInformation = 134
  } SYSTEM_INFORMATION_CLASS;

  typedef enum _OBJECT_INFORMATION_CLASS {
    ObjectBasicInformation,
    ObjectNameInformation,
    ObjectTypeInformation,
    ObjectAllInformation,
    ObjectDataInformation
 } OBJECT_INFORMATION_CLASS, *POBJECT_INFORMATION_CLASS;

#if (_WIN32_WINNT >= 0x0501)
#define INTERNAL_TS_ACTIVE_CONSOLE_ID (*((volatile ULONG*)(0x7ffe02d8)))
#endif

#define RtlMoveMemory(Destination,Source,Length) memmove((Destination),(Source),(Length))
#define RtlFillMemory(Destination,Length,Fill) memset((Destination),(Fill),(Length))
#define RtlZeroMemory(Destination,Length) memset((Destination),0,(Length))

  typedef struct _KEY_VALUE_ENTRY {
    PUNICODE_STRING ValueName;
    ULONG DataLength;
    ULONG DataOffset;
    ULONG Type;
  } KEY_VALUE_ENTRY, *PKEY_VALUE_ENTRY;

  typedef enum _KEY_SET_INFORMATION_CLASS {
    KeyWriteTimeInformation,
    KeyWow64FlagsInformation,
    KeyControlFlagsInformation,
    KeySetVirtualizationInformation,
    KeySetDebugInformation,
    KeySetHandleTagsInformation,
    MaxKeySetInfoClass
  } KEY_SET_INFORMATION_CLASS;

  NTSTATUS NTAPI NtClose(HANDLE Handle);
  NTSTATUS NTAPI NtCreateFile(PHANDLE FileHandle,ACCESS_MASK DesiredAccess,POBJECT_ATTRIBUTES ObjectAttributes,PIO_STATUS_BLOCK IoStatusBlock,PLARGE_INTEGER AllocationSize,ULONG FileAttributes,ULONG ShareAccess,ULONG CreateDisposition,ULONG CreateOptions,PVOID EaBuffer,ULONG EaLength);
  NTSTATUS NTAPI NtOpenFile(PHANDLE FileHandle,ACCESS_MASK DesiredAccess,POBJECT_ATTRIBUTES ObjectAttributes,PIO_STATUS_BLOCK IoStatusBlock,ULONG ShareAccess,ULONG OpenOptions);
  NTSTATUS NTAPI NtRenameKey(HANDLE KeyHandle, PUNICODE_STRING NewName);
  NTSTATUS NTAPI NtNotifyChangeMultipleKeys(HANDLE MasterKeyHandle, ULONG Count, OBJECT_ATTRIBUTES SubordinateObjects[], HANDLE Event, PIO_APC_ROUTINE ApcRoutine, PVOID ApcContext, PIO_STATUS_BLOCK IoStatusBlock, ULONG CompletionFilter, BOOLEAN WatchTree, PVOID Buffer, ULONG BufferSize, BOOLEAN Asynchronous);
  NTSTATUS NTAPI NtQueryMultipleValueKey(HANDLE KeyHandle, PKEY_VALUE_ENTRY ValueEntries, ULONG EntryCount, PVOID ValueBuffer, PULONG BufferLength, PULONG RequiredBufferLength);
  NTSTATUS NTAPI NtSetInformationKey(HANDLE KeyHandle, KEY_SET_INFORMATION_CLASS KeySetInformationClass, PVOID KeySetInformation, ULONG KeySetInformationLength);
  NTSTATUS NTAPI NtFsControlFile(HANDLE FileHandle,HANDLE Event,PIO_APC_ROUTINE ApcRoutine,PVOID ApcContext,PIO_STATUS_BLOCK IoStatusBlock,ULONG IoControlCode,PVOID InputBuffer,ULONG InputBufferLength,PVOID OutputBuffer,ULONG OutputBufferLength);
  NTSTATUS NTAPI NtDeviceIoControlFile(HANDLE FileHandle,HANDLE Event,PIO_APC_ROUTINE ApcRoutine,PVOID ApcContext,PIO_STATUS_BLOCK IoStatusBlock,ULONG IoControlCode,PVOID InputBuffer,ULONG InputBufferLength,PVOID OutputBuffer,ULONG OutputBufferLength);
  NTSTATUS NTAPI NtWaitForSingleObject(HANDLE Handle,BOOLEAN Alertable,PLARGE_INTEGER Timeout);
  BOOLEAN NTAPI RtlIsNameLegalDOS8Dot3(PUNICODE_STRING Name,POEM_STRING OemName,PBOOLEAN NameContainsSpaces);
  ULONG NTAPI RtlNtStatusToDosError (NTSTATUS Status);
  NTSTATUS NTAPI NtQueryInformationProcess(HANDLE ProcessHandle,PROCESSINFOCLASS ProcessInformationClass,PVOID ProcessInformation,ULONG ProcessInformationLength,PULONG ReturnLength);
  NTSTATUS NTAPI NtQueryInformationThread(HANDLE ThreadHandle,THREADINFOCLASS ThreadInformationClass,PVOID ThreadInformation,ULONG ThreadInformationLength,PULONG ReturnLength);
  NTSTATUS NTAPI NtSetInformationThread(HANDLE ThreadHandle,THREADINFOCLASS ThreadInformationClass,PVOID ThreadInformation,ULONG ThreadInformationLength);
  NTSTATUS NTAPI NtQueryInformationFile(HANDLE hFile,PIO_STATUS_BLOCK io,PVOID ptr,ULONG len,FILE_INFORMATION_CLASS FileInformationClass);
  NTSTATUS NTAPI NtQueryObject(HANDLE Handle,OBJECT_INFORMATION_CLASS ObjectInformationClass,PVOID ObjectInformation,ULONG ObjectInformationLength,PULONG ReturnLength);
  NTSTATUS NTAPI NtQuerySystemInformation(SYSTEM_INFORMATION_CLASS SystemInformationClass,PVOID SystemInformation,ULONG SystemInformationLength,PULONG ReturnLength);
  NTSTATUS NTAPI NtQuerySystemTime(PLARGE_INTEGER SystemTime);
  NTSTATUS NTAPI NtQueryTimerResolution(PULONG MaximumTime,PULONG MinimumTime,PULONG CurrentTime);
  NTSTATUS NTAPI NtQueryVolumeInformationFile(HANDLE hFile,PIO_STATUS_BLOCK io,PVOID ptr,ULONG len,FS_INFORMATION_CLASS FsInformationClass);
  NTSTATUS NTAPI NtSetInformationFile(HANDLE hFile,PIO_STATUS_BLOCK io,PVOID ptr,ULONG len,FILE_INFORMATION_CLASS FileInformationClass);
  NTSTATUS NTAPI NtSetInformationProcess(HANDLE ProcessHandle, PROCESSINFOCLASS ProcessInformationClass, PVOID ProcessInformation, ULONG ProcessInformationLength);
  NTSTATUS NTAPI NtSetVolumeInformationFile(HANDLE hFile,PIO_STATUS_BLOCK io,PVOID ptr,ULONG len,FILE_INFORMATION_CLASS FileInformationClass);
  NTSTATUS NTAPI RtlLocalTimeToSystemTime(PLARGE_INTEGER LocalTime,PLARGE_INTEGER SystemTime);
  BOOLEAN NTAPI RtlTimeToSecondsSince1970(PLARGE_INTEGER Time,PULONG ElapsedSeconds);
  VOID NTAPI RtlFreeAnsiString(PANSI_STRING AnsiString);
  VOID NTAPI RtlFreeUnicodeString(PUNICODE_STRING UnicodeString);
  VOID NTAPI RtlFreeOemString(POEM_STRING OemString);
  VOID NTAPI RtlInitString (PSTRING DestinationString,PCSZ SourceString);
  NTSTATUS NTAPI RtlInitStringEx(PSTRING DestinationString, PCSZ SourceString);
  VOID NTAPI RtlInitAnsiString(PANSI_STRING DestinationString,PCSZ SourceString);
  NTSTATUS NTAPI RtlInitAnsiStringEx(PANSI_STRING DestinationString, PCSZ SourceString);
  VOID NTAPI RtlInitUnicodeString(PUNICODE_STRING DestinationString,PCWSTR SourceString);
  NTSTATUS NTAPI RtlAnsiStringToUnicodeString(PUNICODE_STRING DestinationString,PCANSI_STRING SourceString,BOOLEAN AllocateDestinationString);
  NTSTATUS NTAPI RtlUnicodeStringToAnsiString(PANSI_STRING DestinationString,PCUNICODE_STRING SourceString,BOOLEAN AllocateDestinationString);
  NTSTATUS NTAPI RtlUnicodeStringToOemString(POEM_STRING DestinationString,PCUNICODE_STRING SourceString,BOOLEAN AllocateDestinationString);
  NTSTATUS NTAPI RtlUnicodeToMultiByteSize(PULONG BytesInMultiByteString,PWCH UnicodeString,ULONG BytesInUnicodeString);
  NTSTATUS NTAPI RtlCharToInteger (PCSZ String,ULONG Base,PULONG Value);
  NTSTATUS NTAPI RtlConvertSidToUnicodeString(PUNICODE_STRING UnicodeString,PSID Sid,BOOLEAN AllocateDestinationString);
  ULONG NTAPI RtlUniform(PULONG Seed);
  VOID NTAPI RtlUnwind (PVOID TargetFrame,PVOID TargetIp,PEXCEPTION_RECORD ExceptionRecord,PVOID ReturnValue);
  BOOL NTAPI RtlDosPathNameToNtPathName_U(PCWSTR DosPathName, PUNICODE_STRING NtPathName, PCWSTR *NtFileNamePart, VOID *DirectoryInfo);
  BOOLEAN NTAPI RtlPrefixUnicodeString(PCUNICODE_STRING String1, PCUNICODE_STRING String2, BOOLEAN CaseInSensitive);
  BOOLEAN NTAPI RtlCreateUnicodeStringFromAsciiz(PUNICODE_STRING target, LPCSTR src);
#ifdef __ia64__
  VOID RtlUnwind2(FRAME_POINTERS TargetFrame,PVOID TargetIp,PEXCEPTION_RECORD ExceptionRecord,PVOID ReturnValue,PCONTEXT ContextRecord);
  VOID RtlUnwindEx(FRAME_POINTERS TargetFrame,PVOID TargetIp,PEXCEPTION_RECORD ExceptionRecord,PVOID ReturnValue,PCONTEXT ContextRecord,PUNWIND_HISTORY_TABLE HistoryTable);
#endif

  typedef NTSTATUS (NTAPI *PRTL_HEAP_COMMIT_ROUTINE) (PVOID Base, PVOID *CommitAddress, PSIZE_T CommitSize);

  typedef struct _RTL_HEAP_PARAMETERS {
    ULONG Length;
    SIZE_T SegmentReserve;
    SIZE_T SegmentCommit;
    SIZE_T DeCommitFreeBlockThreshold;
    SIZE_T DeCommitTotalFreeThreshold;
    SIZE_T MaximumAllocationSize;
    SIZE_T VirtualMemoryThreshold;
    SIZE_T InitialCommit;
    SIZE_T InitialReserve;
    PRTL_HEAP_COMMIT_ROUTINE CommitRoutine;
    SIZE_T Reserved[ 2 ];
  } RTL_HEAP_PARAMETERS, *PRTL_HEAP_PARAMETERS;

  BOOLEAN NTAPI RtlFreeHeap(PVOID HeapHandle, ULONG Flags, PVOID HeapBase);
  PVOID NTAPI RtlAllocateHeap(PVOID HeapHandle, ULONG Flags, SIZE_T Size);
  PVOID NTAPI RtlCreateHeap(ULONG Flags, PVOID HeapBase, SIZE_T ReserveSize, SIZE_T CommitSize, PVOID Lock, PRTL_HEAP_PARAMETERS Parameters);
  PVOID NTAPI RtlDestroyHeap(PVOID HeapHandle);

#define LOGONID_CURRENT ((ULONG)-1)
#define SERVERNAME_CURRENT ((HANDLE)NULL)

  typedef enum _WINSTATIONINFOCLASS {
    WinStationInformation = 8
  } WINSTATIONINFOCLASS;

  typedef struct _WINSTATIONINFORMATIONW {
    BYTE Reserved2[70];
    ULONG LogonId;
    BYTE Reserved3[1140];
  } WINSTATIONINFORMATIONW,*PWINSTATIONINFORMATIONW;

  typedef BOOLEAN (NTAPI *PWINSTATIONQUERYINFORMATIONW)(HANDLE,ULONG,WINSTATIONINFOCLASS,PVOID,ULONG,PULONG);

#ifdef __cplusplus
}
#endif

#endif

