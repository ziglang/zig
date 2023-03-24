const std = @import("../../std.zig");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const DWORD64 = windows.DWORD64;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const NTSTATUS = windows.NTSTATUS;
const WORD = windows.WORD;
const HANDLE = windows.HANDLE;
const ACCESS_MASK = windows.ACCESS_MASK;
const IO_APC_ROUTINE = windows.IO_APC_ROUTINE;
const BOOLEAN = windows.BOOLEAN;
const OBJECT_ATTRIBUTES = windows.OBJECT_ATTRIBUTES;
const PVOID = windows.PVOID;
const IO_STATUS_BLOCK = windows.IO_STATUS_BLOCK;
const LARGE_INTEGER = windows.LARGE_INTEGER;
const OBJECT_INFORMATION_CLASS = windows.OBJECT_INFORMATION_CLASS;
const FILE_INFORMATION_CLASS = windows.FILE_INFORMATION_CLASS;
const FS_INFORMATION_CLASS = windows.FS_INFORMATION_CLASS;
const UNICODE_STRING = windows.UNICODE_STRING;
const RTL_OSVERSIONINFOW = windows.RTL_OSVERSIONINFOW;
const FILE_BASIC_INFORMATION = windows.FILE_BASIC_INFORMATION;
const SIZE_T = windows.SIZE_T;
const CURDIR = windows.CURDIR;
const PCWSTR = windows.PCWSTR;
const RTL_QUERY_REGISTRY_TABLE = windows.RTL_QUERY_REGISTRY_TABLE;
const CONTEXT = windows.CONTEXT;
const UNWIND_HISTORY_TABLE = windows.UNWIND_HISTORY_TABLE;
const RUNTIME_FUNCTION = windows.RUNTIME_FUNCTION;
const KNONVOLATILE_CONTEXT_POINTERS = windows.KNONVOLATILE_CONTEXT_POINTERS;
const EXCEPTION_ROUTINE = windows.EXCEPTION_ROUTINE;

pub const PROCESSINFOCLASS = enum(c_int) {
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
    MaxProcessInfoClass,
};

pub extern "ntdll" fn NtQueryInformationProcess(
    ProcessHandle: HANDLE,
    ProcessInformationClass: PROCESSINFOCLASS,
    ProcessInformation: *anyopaque,
    ProcessInformationLength: ULONG,
    ReturnLength: ?*ULONG,
) callconv(WINAPI) NTSTATUS;

pub const THREADINFOCLASS = enum(c_int) {
    ThreadBasicInformation,
    ThreadTimes,
    ThreadPriority,
    ThreadBasePriority,
    ThreadAffinityMask,
    ThreadImpersonationToken,
    ThreadDescriptorTableEntry,
    ThreadEnableAlignmentFaultFixup,
    ThreadEventPair_Reusable,
    ThreadQuerySetWin32StartAddress,
    ThreadZeroTlsCell,
    ThreadPerformanceCount,
    ThreadAmILastThread,
    ThreadIdealProcessor,
    ThreadPriorityBoost,
    ThreadSetTlsArrayAddress,
    ThreadIsIoPending,
    // Windows 2000+ from here
    ThreadHideFromDebugger,
    // Windows XP+ from here
    ThreadBreakOnTermination,
    ThreadSwitchLegacyState,
    ThreadIsTerminated,
    // Windows Vista+ from here
    ThreadLastSystemCall,
    ThreadIoPriority,
    ThreadCycleTime,
    ThreadPagePriority,
    ThreadActualBasePriority,
    ThreadTebInformation,
    ThreadCSwitchMon,
    // Windows 7+ from here
    ThreadCSwitchPmu,
    ThreadWow64Context,
    ThreadGroupInformation,
    ThreadUmsInformation,
    ThreadCounterProfiling,
    ThreadIdealProcessorEx,
    // Windows 8+ from here
    ThreadCpuAccountingInformation,
    // Windows 8.1+ from here
    ThreadSuspendCount,
    // Windows 10+ from here
    ThreadHeterogeneousCpuPolicy,
    ThreadContainerId,
    ThreadNameInformation,
    ThreadSelectedCpuSets,
    ThreadSystemThreadInformation,
    ThreadActualGroupAffinity,
};
pub extern "ntdll" fn NtQueryInformationThread(
    ThreadHandle: HANDLE,
    ThreadInformationClass: THREADINFOCLASS,
    ThreadInformation: *anyopaque,
    ThreadInformationLength: ULONG,
    ReturnLength: ?*ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn NtSetInformationThread(
    ThreadHandle: HANDLE,
    ThreadInformationClass: THREADINFOCLASS,
    ThreadInformation: *const anyopaque,
    ThreadInformationLength: ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn RtlGetVersion(
    lpVersionInformation: *RTL_OSVERSIONINFOW,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn RtlCaptureStackBackTrace(
    FramesToSkip: DWORD,
    FramesToCapture: DWORD,
    BackTrace: **anyopaque,
    BackTraceHash: ?*DWORD,
) callconv(WINAPI) WORD;
pub extern "ntdll" fn RtlCaptureContext(ContextRecord: *CONTEXT) callconv(WINAPI) void;
pub extern "ntdll" fn RtlLookupFunctionEntry(
    ControlPc: DWORD64,
    ImageBase: *DWORD64,
    HistoryTable: *UNWIND_HISTORY_TABLE,
) callconv(WINAPI) ?*RUNTIME_FUNCTION;
pub extern "ntdll" fn RtlVirtualUnwind(
    HandlerType: DWORD,
    ImageBase: DWORD64,
    ControlPc: DWORD64,
    FunctionEntry: *RUNTIME_FUNCTION,
    ContextRecord: *CONTEXT,
    HandlerData: *?PVOID,
    EstablisherFrame: *DWORD64,
    ContextPointers: ?*KNONVOLATILE_CONTEXT_POINTERS,
) callconv(WINAPI) *EXCEPTION_ROUTINE;
pub extern "ntdll" fn NtQueryInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *anyopaque,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn NtSetInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: PVOID,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtQueryAttributesFile(
    ObjectAttributes: *OBJECT_ATTRIBUTES,
    FileAttributes: *FILE_BASIC_INFORMATION,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtCreateFile(
    FileHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: *OBJECT_ATTRIBUTES,
    IoStatusBlock: *IO_STATUS_BLOCK,
    AllocationSize: ?*LARGE_INTEGER,
    FileAttributes: ULONG,
    ShareAccess: ULONG,
    CreateDisposition: ULONG,
    CreateOptions: ULONG,
    EaBuffer: ?*anyopaque,
    EaLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn NtDeviceIoControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    IoControlCode: ULONG,
    InputBuffer: ?*const anyopaque,
    InputBufferLength: ULONG,
    OutputBuffer: ?PVOID,
    OutputBufferLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn NtFsControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FsControlCode: ULONG,
    InputBuffer: ?*const anyopaque,
    InputBufferLength: ULONG,
    OutputBuffer: ?PVOID,
    OutputBufferLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn NtClose(Handle: HANDLE) callconv(WINAPI) NTSTATUS;
pub extern "ntdll" fn RtlDosPathNameToNtPathName_U(
    DosPathName: [*:0]const u16,
    NtPathName: *UNICODE_STRING,
    NtFileNamePart: ?*?[*:0]const u16,
    DirectoryInfo: ?*CURDIR,
) callconv(WINAPI) BOOL;
pub extern "ntdll" fn RtlFreeUnicodeString(UnicodeString: *UNICODE_STRING) callconv(WINAPI) void;

pub extern "ntdll" fn NtQueryDirectoryFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *anyopaque,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
    ReturnSingleEntry: BOOLEAN,
    FileName: ?*UNICODE_STRING,
    RestartScan: BOOLEAN,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtCreateKeyedEvent(
    KeyedEventHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: ?PVOID,
    Flags: ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtReleaseKeyedEvent(
    EventHandle: ?HANDLE,
    Key: ?*const anyopaque,
    Alertable: BOOLEAN,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtWaitForKeyedEvent(
    EventHandle: ?HANDLE,
    Key: ?*const anyopaque,
    Alertable: BOOLEAN,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn RtlSetCurrentDirectory_U(PathName: *UNICODE_STRING) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtQueryObject(
    Handle: HANDLE,
    ObjectInformationClass: OBJECT_INFORMATION_CLASS,
    ObjectInformation: PVOID,
    ObjectInformationLength: ULONG,
    ReturnLength: ?*ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtQueryVolumeInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FsInformation: *anyopaque,
    Length: ULONG,
    FsInformationClass: FS_INFORMATION_CLASS,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn RtlWakeAddressAll(
    Address: ?*const anyopaque,
) callconv(WINAPI) void;

pub extern "ntdll" fn RtlWakeAddressSingle(
    Address: ?*const anyopaque,
) callconv(WINAPI) void;

pub extern "ntdll" fn RtlWaitOnAddress(
    Address: ?*const anyopaque,
    CompareAddress: ?*const anyopaque,
    AddressSize: SIZE_T,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn RtlEqualUnicodeString(
    String1: *const UNICODE_STRING,
    String2: *const UNICODE_STRING,
    CaseInSensitive: BOOLEAN,
) callconv(WINAPI) BOOLEAN;

pub extern "ntdll" fn RtlUpcaseUnicodeChar(
    SourceCharacter: u16,
) callconv(WINAPI) u16;

pub extern "ntdll" fn NtLockFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?*IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    ByteOffset: *const LARGE_INTEGER,
    Length: *const LARGE_INTEGER,
    Key: ?*ULONG,
    FailImmediately: BOOLEAN,
    ExclusiveLock: BOOLEAN,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtUnlockFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    ByteOffset: *const LARGE_INTEGER,
    Length: *const LARGE_INTEGER,
    Key: ?*ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtOpenKey(
    KeyHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: OBJECT_ATTRIBUTES,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn RtlQueryRegistryValues(
    RelativeTo: ULONG,
    Path: PCWSTR,
    QueryTable: [*]RTL_QUERY_REGISTRY_TABLE,
    Context: ?*anyopaque,
    Environment: ?*anyopaque,
) callconv(WINAPI) NTSTATUS;

pub extern "ntdll" fn NtProtectVirtualMemory(
    ProcessHandle: HANDLE,
    BaseAddress: *PVOID,
    NumberOfBytesToProtect: *ULONG,
    NewAccessProtection: ULONG,
    OldAccessProtection: *ULONG,
) callconv(WINAPI) NTSTATUS;
