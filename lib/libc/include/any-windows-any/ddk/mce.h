#pragma once

#if defined(_X86_) || defined(_IA64_) || defined(_AMD64_)

typedef union _MCI_ADDR {
  _ANONYMOUS_STRUCT struct {
    ULONG Address;
    ULONG Reserved;
  } DUMMYSTRUCTNAME;
  ULONGLONG QuadPart;
} MCI_ADDR, *PMCI_ADDR;

typedef enum {
  HAL_MCE_RECORD,
  HAL_MCA_RECORD
} MCA_EXCEPTION_TYPE;

#if defined(_AMD64_)

#if (NTDDI_VERSION <= NTDDI_WINXP)

typedef union _MCI_STATS {
  struct {
    USHORT McaCod;
    USHORT ModelErrorCode;
    ULONG OtherInfo:25;
    ULONG Damage:1;
    ULONG AddressValid:1;
    ULONG MiscValid:1;
    ULONG Enabled:1;
    ULONG Uncorrected:1;
    ULONG OverFlow:1;
    ULONG Valid:1;
  } MciStatus;
  ULONG64 QuadPart;
} MCI_STATS, *PMCI_STATS;

#else

typedef union _MCI_STATS {
  struct {
    USHORT McaErrorCode;
    USHORT ModelErrorCode;
    ULONG OtherInformation:25;
    ULONG ContextCorrupt:1;
    ULONG AddressValid:1;
    ULONG MiscValid:1;
    ULONG ErrorEnabled:1;
    ULONG UncorrectedError:1;
    ULONG StatusOverFlow:1;
    ULONG Valid:1;
  } MciStatus;
  ULONG64 QuadPart;
} MCI_STATS, *PMCI_STATS;

#endif /* (NTDDI_VERSION <= NTDDI_WINXP) */

#endif /* defined(_AMD64_) */

#if defined(_X86_)
typedef union _MCI_STATS {
  struct {
    USHORT McaCod;
    USHORT MsCod;
    ULONG OtherInfo:25;
    ULONG Damage:1;
    ULONG AddressValid:1;
    ULONG MiscValid:1;
    ULONG Enabled:1;
    ULONG UnCorrected:1;
    ULONG OverFlow:1;
    ULONG Valid:1;
  } MciStats;
  ULONGLONG QuadPart;
} MCI_STATS, *PMCI_STATS;
#endif

#define MCA_EXTREG_V2MAX               24

#if defined(_X86_) || defined(_AMD64_)

#if (NTDDI_VERSION >= NTDDI_WINXP)

typedef struct _MCA_EXCEPTION {
  ULONG VersionNumber;
  MCA_EXCEPTION_TYPE ExceptionType;
  LARGE_INTEGER TimeStamp;
  ULONG ProcessorNumber;
  ULONG Reserved1;
  union {
    struct {
      UCHAR BankNumber;
      UCHAR Reserved2[7];
      MCI_STATS Status;
      MCI_ADDR Address;
      ULONGLONG Misc;
    } Mca;
    struct {
      ULONGLONG Address;
      ULONGLONG Type;
    } Mce;
  } u;
  ULONG ExtCnt;
  ULONG Reserved3;
  ULONGLONG ExtReg[MCA_EXTREG_V2MAX];
} MCA_EXCEPTION, *PMCA_EXCEPTION;

#else

typedef struct _MCA_EXCEPTION {
  ULONG VersionNumber;
  MCA_EXCEPTION_TYPE ExceptionType;
  LARGE_INTEGER TimeStamp;
  ULONG ProcessorNumber;
  ULONG Reserved1;
  union {
    struct {
      UCHAR BankNumber;
      UCHAR Reserved2[7];
      MCI_STATS Status;
      MCI_ADDR Address;
      ULONGLONG Misc;
    } Mca;
    struct {
      ULONGLONG Address;
      ULONGLONG Type;
    } Mce;
  } u;
} MCA_EXCEPTION, *PMCA_EXCEPTION;

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

typedef MCA_EXCEPTION CMC_EXCEPTION, *PCMC_EXCEPTION;
typedef MCA_EXCEPTION CPE_EXCEPTION, *PCPE_EXCEPTION;

#if (NTDDI_VERSION >= NTDDI_WINXP)
#define MCA_EXCEPTION_V1_SIZE FIELD_OFFSET(MCA_EXCEPTION, ExtCnt)
#define MCA_EXCEPTION_V2_SIZE sizeof(struct _MCA_EXCEPTION)
#endif

#endif /* defined(_X86_) || defined(_AMD64_) */

#if defined(_AMD64_) || defined(_IA64_)

typedef UCHAR ERROR_SEVERITY, *PERROR_SEVERITY;

typedef enum _ERROR_SEVERITY_VALUE {
  ErrorRecoverable = 0,
  ErrorFatal = 1,
  ErrorCorrected = 2,
  ErrorOthers = 3,
} ERROR_SEVERITY_VALUE;

#endif

#if defined(_IA64_)

typedef union _ERROR_REVISION {
  USHORT Revision;
  _ANONYMOUS_STRUCT struct {
    UCHAR Minor;
    UCHAR Major;
  } DUMMYSTRUCTNAME;
} ERROR_REVISION, *PERROR_REVISION;

#if (NTDDI_VERSION > NTDDI_WINXP)
#define ERROR_MAJOR_REVISION_SAL_03_00      0
#define ERROR_MINOR_REVISION_SAL_03_00      2
#define ERROR_REVISION_SAL_03_00 {ERROR_MINOR_REVISION_SAL_03_00,ERROR_MAJOR_REVISION_SAL_03_00}
#define ERROR_FIXED_SECTION_REVISION {2,0}
#else
#define ERROR_REVISION_SAL_03_00 {2,0}
#endif /* (NTDDI_VERSION > NTDDI_WINXP) */

typedef union _ERROR_TIMESTAMP {
  ULONGLONG TimeStamp;
  _ANONYMOUS_STRUCT struct {
    UCHAR Seconds;
    UCHAR Minutes;
    UCHAR Hours;
    UCHAR Reserved;
    UCHAR Day;
    UCHAR Month;
    UCHAR Year;
    UCHAR Century;
  } DUMMYSTRUCTNAME;
} ERROR_TIMESTAMP, *PERROR_TIMESTAMP;

typedef struct _ERROR_GUID {
  ULONG Data1;
  USHORT Data2;
  USHORT Data3;
  UCHAR Data4[8];
} ERROR_GUID, *PERROR_GUID;

typedef ERROR_GUID            _ERROR_DEVICE_GUID;
typedef _ERROR_DEVICE_GUID    ERROR_DEVICE_GUID, *PERROR_DEVICE_GUID;

typedef ERROR_GUID            _ERROR_PLATFORM_GUID;
typedef _ERROR_PLATFORM_GUID  ERROR_PLATFORM_GUID, *PERROR_PLATFORM_GUID;

typedef union _ERROR_RECORD_VALID {
  UCHAR Valid;
  _ANONYMOUS_STRUCT struct {
    UCHAR OemPlatformID:1;
    UCHAR Reserved:7;
  } DUMMYSTRUCTNAME;
} ERROR_RECORD_VALID, *PERROR_RECORD_VALID;

typedef struct _ERROR_RECORD_HEADER {
  ULONGLONG Id;
  ERROR_REVISION Revision;
  ERROR_SEVERITY ErrorSeverity;
  ERROR_RECORD_VALID Valid;
  ULONG Length;
  ERROR_TIMESTAMP TimeStamp;
  UCHAR OemPlatformId[16];
} ERROR_RECORD_HEADER, *PERROR_RECORD_HEADER;

typedef union _ERROR_RECOVERY_INFO {
  UCHAR RecoveryInfo;
  _ANONYMOUS_STRUCT struct {
    UCHAR Corrected:1;
    UCHAR NotContained:1;
    UCHAR Reset:1;
    UCHAR Reserved:4;
    UCHAR Valid:1;
  } DUMMYSTRUCTNAME;
} ERROR_RECOVERY_INFO, *PERROR_RECOVERY_INFO;

typedef struct _ERROR_SECTION_HEADER {
  ERROR_DEVICE_GUID Guid;
  ERROR_REVISION Revision;
  ERROR_RECOVERY_INFO RecoveryInfo;
  UCHAR Reserved;
  ULONG Length;
} ERROR_SECTION_HEADER, *PERROR_SECTION_HEADER;

#if !defined(__midl)
__inline
USHORT
NTAPI
GetFwMceLogProcessorNumber(
  PERROR_RECORD_HEADER Log)
{
  PERROR_SECTION_HEADER section = (PERROR_SECTION_HEADER)((ULONG64)Log + sizeof(*Log));
  USHORT lid = (USHORT)((UCHAR)(section->Reserved));
#ifdef NONAMELESSUNION
  lid |= (USHORT)((UCHAR)(Log->TimeStamp.s.Reserved) << 8);
#else
  lid |= (USHORT)((UCHAR)(Log->TimeStamp.Reserved) << 8);
#endif
  return( lid );
}
#endif /* !__midl */

#define ERROR_PROCESSOR_GUID {0xe429faf1, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_MODINFO_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG CheckInfo:1;
    ULONGLONG RequestorIdentifier:1;
    ULONGLONG ResponderIdentifier:1;
    ULONGLONG TargetIdentifier:1;
    ULONGLONG PreciseIP:1;
    ULONGLONG Reserved:59;
  } DUMMYSTRUCTNAME;
} ERROR_MODINFO_VALID, *PERROR_MODINFO_VALID;

typedef enum _ERROR_CHECK_IS {
  isIA64 = 0,
  isIA32 = 1,
} ERROR_CHECK_IS;

typedef enum _ERROR_CACHE_CHECK_OPERATION {
  CacheUnknownOp = 0,
  CacheLoad = 1,
  CacheStore = 2,
  CacheInstructionFetch = 3,
  CacheDataPrefetch = 4,
  CacheSnoop = 5,
  CacheCastOut = 6,
  CacheMoveIn = 7,
} ERROR_CACHE_CHECK_OPERATION;

typedef enum _ERROR_CACHE_CHECK_MESI {
  CacheInvalid = 0,
  CacheHeldShared = 1,
  CacheHeldExclusive = 2,
  CacheModified = 3,
} ERROR_CACHE_CHECK_MESI;

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef union _ERROR_CACHE_CHECK {
  ULONGLONG CacheCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Operation:4;
    ULONGLONG Level:2;
    ULONGLONG Reserved1:2;
    ULONGLONG DataLine:1;
    ULONGLONG TagLine:1;
    ULONGLONG DataCache:1;
    ULONGLONG InstructionCache:1;
    ULONGLONG MESI:3;
    ULONGLONG MESIValid:1;
    ULONGLONG Way:5;
    ULONGLONG WayIndexValid:1;
    ULONGLONG Reserved2:1;
    ULONGLONG DP:1;
    ULONGLONG Reserved3:8;
    ULONGLONG Index:20;
    ULONGLONG Reserved4:2;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_CACHE_CHECK, *PERROR_CACHE_CHECK;

# else

typedef union _ERROR_CACHE_CHECK {
  ULONGLONG CacheCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Operation:4;
    ULONGLONG Level:2;
    ULONGLONG Reserved1:2;
    ULONGLONG DataLine:1;
    ULONGLONG TagLine:1;
    ULONGLONG DataCache:1;
    ULONGLONG InstructionCache:1;
    ULONGLONG MESI:3;
    ULONGLONG MESIValid:1;
    ULONGLONG Way:5;
    ULONGLONG WayIndexValid:1;
    ULONGLONG Reserved2:10;
    ULONGLONG Index:20;
    ULONGLONG Reserved3:2;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_CACHE_CHECK, *PERROR_CACHE_CHECK;

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

typedef enum _ERROR_TLB_CHECK_OPERATION {
  TlbUnknownOp = 0,
  TlbAccessWithLoad = 1,
  TlbAccessWithStore = 2,
  TlbAccessWithInstructionFetch = 3,
  TlbAccessWithDataPrefetch = 4,
  TlbShootDown = 5,
  TlbProbe = 6,
  TlbVhptFill = 7,
  TlbPurge = 8,
} ERROR_TLB_CHECK_OPERATION;

typedef union _ERROR_TLB_CHECK {
  ULONGLONG TlbCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG TRSlot:8;
    ULONGLONG TRSlotValid:1;
    ULONGLONG Reserved1:1;
    ULONGLONG Level:2;
    ULONGLONG Reserved2:4;
    ULONGLONG DataTransReg:1;
    ULONGLONG InstructionTransReg:1;
    ULONGLONG DataTransCache:1;
    ULONGLONG InstructionTransCache:1;
    ULONGLONG Operation:4;
    ULONGLONG Reserved3:30;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_TLB_CHECK, *PERROR_TLB_CHECK;

typedef enum _ERROR_BUS_CHECK_OPERATION {
  BusUnknownOp = 0,
  BusPartialRead = 1,
  BusPartialWrite = 2,
  BusFullLineRead = 3,
  BusFullLineWrite = 4,
  BusWriteBack = 5,
  BusSnoopProbe = 6,
  BusIncomingPtcG = 7,
  BusWriteCoalescing = 8,
} ERROR_BUS_CHECK_OPERATION;

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef union _ERROR_BUS_CHECK {
  ULONGLONG BusCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Size:5;
    ULONGLONG Internal:1;
    ULONGLONG External:1;
    ULONGLONG CacheTransfer:1;
    ULONGLONG Type:8;
    ULONGLONG Severity:5;
    ULONGLONG Hierarchy:2;
    ULONGLONG DP:1;
    ULONGLONG Status:8;
    ULONGLONG Reserved1:22;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_BUS_CHECK, *PERROR_BUS_CHECK;

#else

typedef union _ERROR_BUS_CHECK {
  ULONGLONG BusCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Size:5;
    ULONGLONG Internal:1;
    ULONGLONG External:1;
    ULONGLONG CacheTransfer:1;
    ULONGLONG Type:8;
    ULONGLONG Severity:5;
    ULONGLONG Hierarchy:2;
    ULONGLONG Reserved1:1;
    ULONGLONG Status:8;
    ULONGLONG Reserved2:22;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_BUS_CHECK, *PERROR_BUS_CHECK;

#endif

typedef enum _ERROR_REGFILE_CHECK_IDENTIFIER {
  RegFileUnknownId = 0,
  GeneralRegisterBank1 = 1,
  GeneralRegisterBank0 = 2,
  FloatingPointRegister = 3,
  BranchRegister = 4,
  PredicateRegister = 5,
  ApplicationRegister = 6,
  ControlRegister = 7,
  RegionRegister = 8,
  ProtectionKeyRegister = 9,
  DataBreakPointRegister = 10,
  InstructionBreakPointRegister = 11,
  PerformanceMonitorControlRegister = 12,
  PerformanceMonitorDataRegister = 13,
} ERROR_REGFILE_CHECK_IDENTIFIER;

typedef enum _ERROR_REGFILE_CHECK_OPERATION {
  RegFileUnknownOp = 0,
  RegFileRead = 1,
  RegFileWrite = 2,
} ERROR_REGFILE_CHECK_OPERATION;

typedef union _ERROR_REGFILE_CHECK {
  ULONGLONG RegFileCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Identifier:4;
    ULONGLONG Operation:4;
    ULONGLONG RegisterNumber:7;
    ULONGLONG RegisterNumberValid:1;
    ULONGLONG Reserved1:38;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG Reserved2:3;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_REGFILE_CHECK, *PERROR_REGFILE_CHECK;

#if (NTDDK_VERSION <= WINXP)
typedef enum _ERROR_MS_CHECK_OPERATION {
  MsUnknownOp = 0,
  MsReadOrLoad = 1,
  MsWriteOrStore = 2
} ERROR_MS_CHECK_OPERATION;
#else
typedef enum _ERROR_MS_CHECK_OPERATION {
  MsUnknownOp = 0,
  MsReadOrLoad = 1,
  MsWriteOrStore = 2,
  MsOverTemperature = 3,
  MsNormalTemperature = 4
} ERROR_MS_CHECK_OPERATION;
#endif

typedef union _ERROR_MS_CHECK {
  ULONGLONG MsCheck;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG StructureIdentifier:5;
    ULONGLONG Level:3;
    ULONGLONG ArrayId:4;
    ULONGLONG Operation:4;
    ULONGLONG Way:6;
    ULONGLONG WayValid:1;
    ULONGLONG IndexValid:1;
    ULONGLONG Reserved1:8;
    ULONGLONG Index:8;
    ULONGLONG Reserved2:14;
    ULONGLONG InstructionSet:1;
    ULONGLONG InstructionSetValid:1;
    ULONGLONG PrivilegeLevel:2;
    ULONGLONG PrivilegeLevelValid:1;
    ULONGLONG MachineCheckCorrected:1;
    ULONGLONG TargetAddressValid:1;
    ULONGLONG RequestIdValid:1;
    ULONGLONG ResponderIdValid:1;
    ULONGLONG PreciseIPValid:1;
  } DUMMYSTRUCTNAME;
} ERROR_MS_CHECK, *PERROR_MS_CHECK;

typedef union _ERROR_CHECK_INFO {
  ULONGLONG CheckInfo;
  ERROR_CACHE_CHECK CacheCheck;
  ERROR_TLB_CHECK TlbCheck;
  ERROR_BUS_CHECK BusCheck;
  ERROR_REGFILE_CHECK RegFileCheck;
  ERROR_MS_CHECK MsCheck;
} ERROR_CHECK_INFO, *PERROR_CHECK_INFO;

typedef struct _ERROR_MODINFO {
  ERROR_MODINFO_VALID Valid;
  ERROR_CHECK_INFO CheckInfo;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  ULONGLONG PreciseIP;
} ERROR_MODINFO, *PERROR_MODINFO;

typedef union _ERROR_PROCESSOR_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorMap:1;
    ULONGLONG StateParameter:1;
    ULONGLONG CRLid:1;
    ULONGLONG StaticStruct:1;
    ULONGLONG CacheCheckNum:4;
    ULONGLONG TlbCheckNum:4;
    ULONGLONG BusCheckNum:4;
    ULONGLONG RegFileCheckNum:4;
    ULONGLONG MsCheckNum:4;
    ULONGLONG CpuIdInfo:1;
    ULONGLONG Reserved:39;
  } DUMMYSTRUCTNAME;
} ERROR_PROCESSOR_VALID, *PERROR_PROCESSOR_VALID;

typedef union _ERROR_PROCESSOR_ERROR_MAP {
  ULONGLONG ErrorMap;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG   Cid:4;
    ULONGLONG   Tid:4;
    ULONGLONG   Eic:4;
    ULONGLONG   Edc:4;
    ULONGLONG   Eit:4;
    ULONGLONG   Edt:4;
    ULONGLONG   Ebh:4;
    ULONGLONG   Erf:4;
    ULONGLONG   Ems:16;
    ULONGLONG   Reserved:16;
  } DUMMYSTRUCTNAME;
} ERROR_PROCESSOR_ERROR_MAP, *PERROR_PROCESSOR_ERROR_MAP;

typedef ERROR_PROCESSOR_ERROR_MAP    _ERROR_PROCESSOR_LEVEL_INDEX;
typedef _ERROR_PROCESSOR_LEVEL_INDEX ERROR_PROCESSOR_LEVEL_INDEX, *PERROR_PROCESSOR_LEVEL_INDEX;

typedef union _ERROR_PROCESSOR_STATE_PARAMETER {
  ULONGLONG   StateParameter;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG reserved0:2;
    ULONGLONG rz:1;
    ULONGLONG ra:1;
    ULONGLONG me:1;
    ULONGLONG mn:1;
    ULONGLONG sy:1;
    ULONGLONG co:1;
    ULONGLONG ci:1;
    ULONGLONG us:1;
    ULONGLONG hd:1;
    ULONGLONG tl:1;
    ULONGLONG mi:1;
    ULONGLONG pi:1;
    ULONGLONG pm:1;
    ULONGLONG dy:1;
    ULONGLONG in:1;
    ULONGLONG rs:1;
    ULONGLONG cm:1;
    ULONGLONG ex:1;
    ULONGLONG cr:1;
    ULONGLONG pc:1;
    ULONGLONG dr:1;
    ULONGLONG tr:1;
    ULONGLONG rr:1;
    ULONGLONG ar:1;
    ULONGLONG br:1;
    ULONGLONG pr:1;
    ULONGLONG fp:1;
    ULONGLONG b1:1;
    ULONGLONG b0:1;
    ULONGLONG gr:1;
    ULONGLONG dsize:16;
    ULONGLONG reserved1:11;
    ULONGLONG cc:1;
    ULONGLONG tc:1;
    ULONGLONG bc:1;
    ULONGLONG rc:1;
    ULONGLONG uc:1;
  } DUMMYSTRUCTNAME;
} ERROR_PROCESSOR_STATE_PARAMETER, *PERROR_PROCESSOR_STATE_PARAMETER;

typedef union _PROCESSOR_LOCAL_ID {
  ULONGLONG LocalId;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG reserved:16;
    ULONGLONG eid:8;
    ULONGLONG id:8;
    ULONGLONG ignored:32;
  } DUMMYSTRUCTNAME;
} PROCESSOR_LOCAL_ID, *PPROCESSOR_LOCAL_ID;

typedef struct _ERROR_PROCESSOR_MS {
  ULONGLONG MsError[1];
} ERROR_PROCESSOR_MS, *PERROR_PROCESSOR_MS;

typedef struct _ERROR_PROCESSOR_CPUID_INFO {
  ULONGLONG CpuId0;
  ULONGLONG CpuId1;
  ULONGLONG CpuId2;
  ULONGLONG CpuId3;
  ULONGLONG CpuId4;
  ULONGLONG Reserved;
} ERROR_PROCESSOR_CPUID_INFO, *PERROR_PROCESSOR_CPUID_INFO;

typedef union _ERROR_PROCESSOR_STATIC_INFO_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG MinState:1;
    ULONGLONG BR:1;
    ULONGLONG CR:1;
    ULONGLONG AR:1;
    ULONGLONG RR:1;
    ULONGLONG FR:1;
    ULONGLONG Reserved:58;
  } DUMMYSTRUCTNAME;
} ERROR_PROCESSOR_STATIC_INFO_VALID, *PERROR_PROCESSOR_STATIC_INFO_VALID;

typedef struct _ERROR_PROCESSOR_STATIC_INFO {
  ERROR_PROCESSOR_STATIC_INFO_VALID Valid;
  UCHAR MinState[1024];
  ULONGLONG BR[8];
  ULONGLONG CR[128];
  ULONGLONG AR[128];
  ULONGLONG RR[8];
  ULONGLONG FR[2 * 128];
} ERROR_PROCESSOR_STATIC_INFO, *PERROR_PROCESSOR_STATIC_INFO;

typedef struct _ERROR_PROCESSOR {
  ERROR_SECTION_HEADER Header;
  ERROR_PROCESSOR_VALID Valid;
  ERROR_PROCESSOR_ERROR_MAP ErrorMap;
  ERROR_PROCESSOR_STATE_PARAMETER StateParameter;
  PROCESSOR_LOCAL_ID CRLid;
} ERROR_PROCESSOR, *PERROR_PROCESSOR;

#define ERROR_PROCESSOR_STATE_PARAMETER_CACHE_CHECK_SHIFT         59
#define ERROR_PROCESSOR_STATE_PARAMETER_CACHE_CHECK_MASK          0x1
#define ERROR_PROCESSOR_STATE_PARAMETER_TLB_CHECK_SHIFT           60
#define ERROR_PROCESSOR_STATE_PARAMETER_TLB_CHECK_MASK            0x1
#define ERROR_PROCESSOR_STATE_PARAMETER_BUS_CHECK_SHIFT           61
#define ERROR_PROCESSOR_STATE_PARAMETER_BUS_CHECK_MASK            0x1
#define ERROR_PROCESSOR_STATE_PARAMETER_REG_CHECK_SHIFT           62
#define ERROR_PROCESSOR_STATE_PARAMETER_REG_CHECK_MASK            0x1
#define ERROR_PROCESSOR_STATE_PARAMETER_MICROARCH_CHECK_SHIFT     63
#define ERROR_PROCESSOR_STATE_PARAMETER_MICROARCH_CHECK_MASK      0x1

#define ERROR_PROCESSOR_STATE_PARAMETER_UNKNOWN_CHECK_SHIFT       ERROR_PROCESSOR_STATE_PARAMETER_MICROARCH_CHECK_SHIFT
#define ERROR_PROCESSOR_STATE_PARAMETER_UNKNOWN_CHECK_MASK        ERROR_PROCESSOR_STATE_PARAMETER_MICROARCH_CHECK_MASK

typedef enum _ERR_TYPES {
  ERR_INTERNAL = 1,
  ERR_BUS = 16,
  ERR_MEM = 4,
  ERR_TLB = 5,
  ERR_CACHE = 6,
  ERR_FUNCTION = 7,
  ERR_SELFTEST = 8,
  ERR_FLOW = 9,
  ERR_MAP = 17,
  ERR_IMPROPER = 18,
  ERR_UNIMPL = 19,
  ERR_LOL = 20,
  ERR_RESPONSE = 21,
  ERR_PARITY = 22,
  ERR_PROTOCOL = 23,
  ERR_ERROR = 24,
  ERR_TIMEOUT = 25,
  ERR_POISONED = 26,
} _ERR_TYPE;

typedef union _ERROR_STATUS {
  ULONGLONG Status;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG Reserved0:8;
    ULONGLONG Type:8;
    ULONGLONG Address:1;
    ULONGLONG Control:1;
    ULONGLONG Data:1;
    ULONGLONG Responder:1;
    ULONGLONG Requestor:1;
    ULONGLONG FirstError:1;
    ULONGLONG Overflow:1;
    ULONGLONG Reserved1:41;
  } DUMMYSTRUCTNAME;
} ERROR_STATUS, *PERROR_STATUS;

typedef struct _ERROR_OEM_DATA {
  USHORT Length;
} ERROR_OEM_DATA, *PERROR_OEM_DATA;

typedef union _ERROR_BUS_SPECIFIC_DATA {
  ULONGLONG BusSpecificData;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG LockAsserted:1;
    ULONGLONG DeferLogged:1;
    ULONGLONG IOQEmpty:1;
    ULONGLONG DeferredTransaction:1;
    ULONGLONG RetriedTransaction:1;
    ULONGLONG MemoryClaimedTransaction:1;
    ULONGLONG IOClaimedTransaction:1;
    ULONGLONG ResponseParitySignal:1;
    ULONGLONG DeferSignal:1;
    ULONGLONG HitMSignal:1;
    ULONGLONG HitSignal:1;
    ULONGLONG RequestBusFirstCycle:6;
    ULONGLONG RequestBusSecondCycle:6;
    ULONGLONG AddressParityBusFirstCycle:2;
    ULONGLONG AddressParityBusSecondCycle:2;
    ULONGLONG ResponseBus:3;
    ULONGLONG RequestParitySignalFirstCycle:1;
    ULONGLONG RequestParitySignalSecondCycle:1;
    ULONGLONG Reserved:32;
  } DUMMYSTRUCTNAME;
} ERROR_BUS_SPECIFIC_DATA, *PERROR_BUS_SPECIFIC_DATA;

#define ERROR_MEMORY_GUID {0xe429faf2, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_MEMORY_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG PhysicalAddress:1;
    ULONGLONG AddressMask:1;
    ULONGLONG Node:1;
    ULONGLONG Card:1;
    ULONGLONG Module:1;
    ULONGLONG Bank:1;
    ULONGLONG Device:1;
    ULONGLONG Row:1;
    ULONGLONG Column:1;
    ULONGLONG BitPosition:1;
    ULONGLONG RequestorId:1;
    ULONGLONG ResponderId:1;
    ULONGLONG TargetId:1;
    ULONGLONG BusSpecificData:1;
    ULONGLONG OemId:1;
    ULONGLONG OemData:1;
    ULONGLONG Reserved:47;
  } DUMMYSTRUCTNAME;
} ERROR_MEMORY_VALID, *PERROR_MEMORY_VALID;

typedef struct _ERROR_MEMORY {
  ERROR_SECTION_HEADER Header;
  ERROR_MEMORY_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ULONGLONG PhysicalAddress;
  ULONGLONG PhysicalAddressMask;
  USHORT Node;
  USHORT Card;
  USHORT Module;
  USHORT Bank;
  USHORT Device;
  USHORT Row;
  USHORT Column;
  USHORT BitPosition;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  ULONGLONG BusSpecificData;
  UCHAR OemId[16];
  ERROR_OEM_DATA OemData;
} ERROR_MEMORY, *PERROR_MEMORY;

#define ERROR_PCI_BUS_GUID {0xe429faf4, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_PCI_BUS_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG ErrorType:1;
    ULONGLONG Id:1;
    ULONGLONG Address:1;
    ULONGLONG Data:1;
    ULONGLONG CmdType:1;
    ULONGLONG RequestorId:1;
    ULONGLONG ResponderId:1;
    ULONGLONG TargetId:1;
    ULONGLONG OemId:1;
    ULONGLONG OemData:1;
    ULONGLONG Reserved:53;
  } DUMMYSTRUCTNAME;
} ERROR_PCI_BUS_VALID, *PERROR_PCI_BUS_VALID;

typedef struct _ERROR_PCI_BUS_TYPE {
  UCHAR Type;
  UCHAR Reserved;
} ERROR_PCI_BUS_TYPE, *PERROR_PCI_BUS_TYPE;

#define PciBusUnknownError       ((UCHAR)0)
#define PciBusDataParityError    ((UCHAR)1)
#define PciBusSystemError        ((UCHAR)2)
#define PciBusMasterAbort        ((UCHAR)3)
#define PciBusTimeOut            ((UCHAR)4)
#define PciMasterDataParityError ((UCHAR)5)
#define PciAddressParityError    ((UCHAR)6)
#define PciCommandParityError    ((UCHAR)7)

typedef struct _ERROR_PCI_BUS_ID {
  UCHAR BusNumber;
  UCHAR SegmentNumber;
} ERROR_PCI_BUS_ID, *PERROR_PCI_BUS_ID;

typedef struct _ERROR_PCI_BUS {
  ERROR_SECTION_HEADER Header;
  ERROR_PCI_BUS_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ERROR_PCI_BUS_TYPE Type;
  ERROR_PCI_BUS_ID Id;
  UCHAR Reserved[4];
  ULONGLONG Address;
  ULONGLONG Data;
  ULONGLONG CmdType;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  UCHAR OemId[16];
  ERROR_OEM_DATA OemData;
} ERROR_PCI_BUS, *PERROR_PCI_BUS;

#define ERROR_PCI_COMPONENT_GUID {0xe429faf6, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_PCI_COMPONENT_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG Info:1;
    ULONGLONG MemoryMappedRegistersPairs:1;
    ULONGLONG ProgrammedIORegistersPairs:1;
    ULONGLONG RegistersDataPairs:1;
    ULONGLONG OemData:1;
    ULONGLONG Reserved:58;
  } DUMMYSTRUCTNAME;
} ERROR_PCI_COMPONENT_VALID, *PERROR_PCI_COMPONENT_VALID;

typedef struct _ERROR_PCI_COMPONENT_INFO {
  USHORT VendorId;
  USHORT DeviceId;
  UCHAR ClassCodeInterface;
  UCHAR ClassCodeSubClass;
  UCHAR ClassCodeBaseClass;
  UCHAR FunctionNumber;
  UCHAR DeviceNumber;
  UCHAR BusNumber;
  UCHAR SegmentNumber;
  UCHAR Reserved0;
  ULONG Reserved1;
} ERROR_PCI_COMPONENT_INFO, *PERROR_PCI_COMPONENT_INFO;

typedef struct _ERROR_PCI_COMPONENT {
  ERROR_SECTION_HEADER Header;
  ERROR_PCI_COMPONENT_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ERROR_PCI_COMPONENT_INFO Info;
  ULONG MemoryMappedRegistersPairs;
  ULONG ProgrammedIORegistersPairs;
} ERROR_PCI_COMPONENT, *PERROR_PCI_COMPONENT;

#define ERROR_SYSTEM_EVENT_LOG_GUID {0xe429faf3, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_SYSTEM_EVENT_LOG_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG RecordId:1;
    ULONGLONG RecordType:1;
    ULONGLONG GeneratorId:1;
    ULONGLONG EVMRev:1;
    ULONGLONG SensorType:1;
    ULONGLONG SensorNum:1;
    ULONGLONG EventDirType:1;
    ULONGLONG EventData1:1;
    ULONGLONG EventData2:1;
    ULONGLONG EventData3:1;
    ULONGLONG Reserved:54;
  } DUMMYSTRUCTNAME;
} ERROR_SYSTEM_EVENT_LOG_VALID, *PSYSTEM_EVENT_LOG_VALID;

typedef struct _ERROR_SYSTEM_EVENT_LOG {
  ERROR_SECTION_HEADER Header;
  ERROR_SYSTEM_EVENT_LOG_VALID Valid;
  USHORT RecordId;
  UCHAR RecordType;
  ULONG TimeStamp;
  USHORT GeneratorId;
  UCHAR EVMRevision;
  UCHAR SensorType;
  UCHAR SensorNumber;
  UCHAR EventDir;
  UCHAR Data1;
  UCHAR Data2;
  UCHAR Data3;
} ERROR_SYSTEM_EVENT_LOG, *PERROR_SYSTEM_EVENT_LOG;

#define ERROR_SMBIOS_GUID {0xe429faf5, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_SMBIOS_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG EventType:1;
    ULONGLONG Length:1;
    ULONGLONG TimeStamp:1;
    ULONGLONG OemData:1;
    ULONGLONG Reserved:60;
  } DUMMYSTRUCTNAME;
} ERROR_SMBIOS_VALID, *PERROR_SMBIOS_VALID;

typedef UCHAR ERROR_SMBIOS_EVENT_TYPE, *PERROR_SMBIOS_EVENT_TYPE;

typedef struct _ERROR_SMBIOS {
  ERROR_SECTION_HEADER Header;
  ERROR_SMBIOS_VALID Valid;
  ERROR_SMBIOS_EVENT_TYPE EventType;
  UCHAR Length;
  ERROR_TIMESTAMP TimeStamp;
  ERROR_OEM_DATA OemData;
} ERROR_SMBIOS, *PERROR_SMBIOS;

#define ERROR_PLATFORM_SPECIFIC_GUID {0xe429faf7, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_PLATFORM_SPECIFIC_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG RequestorId:1;
    ULONGLONG ResponderId:1;
    ULONGLONG TargetId:1;
    ULONGLONG BusSpecificData:1;
    ULONGLONG OemId:1;
    ULONGLONG OemData:1;
    ULONGLONG OemDevicePath:1;
    ULONGLONG Reserved:56;
  } DUMMYSTRUCTNAME;
} ERROR_PLATFORM_SPECIFIC_VALID, *PERROR_PLATFORM_SPECIFIC_VALID;

typedef struct _ERROR_PLATFORM_SPECIFIC {
  ERROR_SECTION_HEADER Header;
  ERROR_PLATFORM_SPECIFIC_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  ERROR_BUS_SPECIFIC_DATA BusSpecificData;
  UCHAR OemId[16];
  ERROR_OEM_DATA OemData;
} ERROR_PLATFORM_SPECIFIC, *PERROR_PLATFORM_SPECIFIC;

#define ERROR_PLATFORM_BUS_GUID {0xe429faf9, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_PLATFORM_BUS_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG RequestorId:1;
    ULONGLONG ResponderId:1;
    ULONGLONG TargetId:1;
    ULONGLONG BusSpecificData:1;
    ULONGLONG OemId:1;
    ULONGLONG OemData:1;
    ULONGLONG OemDevicePath:1;
    ULONGLONG Reserved:56;
  } DUMMYSTRUCTNAME;
} ERROR_PLATFORM_BUS_VALID, *PERROR_PLATFORM_BUS_VALID;

typedef struct _ERROR_PLATFORM_BUS {
  ERROR_SECTION_HEADER Header;
  ERROR_PLATFORM_BUS_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  ERROR_BUS_SPECIFIC_DATA BusSpecificData;
  UCHAR OemId[16];
  ERROR_OEM_DATA OemData;
} ERROR_PLATFORM_BUS, *PERROR_PLATFORM_BUS;

#define ERROR_PLATFORM_HOST_CONTROLLER_GUID {0xe429faf8, 0x3cb7, 0x11d4, {0xbc, 0xa7, 0x0, 0x80, 0xc7, 0x3c, 0x88, 0x81}}

typedef union _ERROR_PLATFORM_HOST_CONTROLLER_VALID {
  ULONGLONG Valid;
  _ANONYMOUS_STRUCT struct {
    ULONGLONG ErrorStatus:1;
    ULONGLONG RequestorId:1;
    ULONGLONG ResponderId:1;
    ULONGLONG TargetId:1;
    ULONGLONG BusSpecificData:1;
    ULONGLONG OemId:1;
    ULONGLONG OemData:1;
    ULONGLONG OemDevicePath:1;
    ULONGLONG Reserved:56;
  } DUMMYSTRUCTNAME;
} ERROR_PLATFORM_HOST_CONTROLLER_VALID, *PERROR_PLATFORM_HOST_CONTROLLER_VALID;

typedef struct _ERROR_PLATFORM_HOST_CONTROLLER {
  ERROR_SECTION_HEADER Header;
  ERROR_PCI_COMPONENT_VALID Valid;
  ERROR_STATUS ErrorStatus;
  ULONGLONG RequestorId;
  ULONGLONG ResponderId;
  ULONGLONG TargetId;
  ERROR_BUS_SPECIFIC_DATA BusSpecificData;
  UCHAR OemId[16];
  ERROR_OEM_DATA OemData;
} ERROR_PLATFORM_HOST_CONTROLLER, *PERROR_PLATFORM_HOST_CONTROLLER;

typedef ERROR_RECORD_HEADER ERROR_LOGRECORD, *PERROR_LOGRECORD;
typedef ERROR_RECORD_HEADER MCA_EXCEPTION, *PMCA_EXCEPTION;
typedef ERROR_RECORD_HEADER CMC_EXCEPTION, *PCMC_EXCEPTION;
typedef ERROR_RECORD_HEADER CPE_EXCEPTION, *PCPE_EXCEPTION;
#if (NTDDI_VERSION > NTDDI_WINXP)
typedef ERROR_RECORD_HEADER INIT_EXCEPTION, *PINIT_EXCEPTION;
#endif

#endif /* defined(_IA64_) */

#endif /* defined(_X86_) || defined(_IA64_) || defined(_AMD64_) */
