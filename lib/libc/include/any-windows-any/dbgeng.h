/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DBGENG_H__
#define __DBGENG_H__

#include <stdarg.h>
#include <objbase.h>

#ifndef _WDBGEXTS_
typedef struct _WINDBG_EXTENSION_APIS32 *PWINDBG_EXTENSION_APIS32;
typedef struct _WINDBG_EXTENSION_APIS64 *PWINDBG_EXTENSION_APIS64;
#endif

#ifndef _CRASHLIB_
typedef struct _MEMORY_BASIC_INFORMATION64 *PMEMORY_BASIC_INFORMATION64;
#endif

#ifdef __cplusplus
extern "C" {
#endif

  DEFINE_GUID(IID_IDebugAdvanced,0xf2df5f53,0x071f,0x47bd,0x9d,0xe6,0x57,0x34,0xc3,0xfe,0xd6,0x89);
  DEFINE_GUID(IID_IDebugBreakpoint,0x5bd9d474,0x5975,0x423a,0xb8,0x8b,0x65,0xa8,0xe7,0x11,0x0e,0x65);
  DEFINE_GUID(IID_IDebugClient,0x27fe5639,0x8407,0x4f47,0x83,0x64,0xee,0x11,0x8f,0xb0,0x8a,0xc8);
  DEFINE_GUID(IID_IDebugClient2,0xedbed635,0x372e,0x4dab,0xbb,0xfe,0xed,0x0d,0x2f,0x63,0xbe,0x81);
  DEFINE_GUID(IID_IDebugClient3,0xdd492d7f,0x71b8,0x4ad6,0xa8,0xdc,0x1c,0x88,0x74,0x79,0xff,0x91);
  DEFINE_GUID(IID_IDebugClient4,0xca83c3de,0x5089,0x4cf8,0x93,0xc8,0xd8,0x92,0x38,0x7f,0x2a,0x5e);
  DEFINE_GUID(IID_IDebugControl,0x5182e668,0x105e,0x416e,0xad,0x92,0x24,0xef,0x80,0x04,0x24,0xba);
  DEFINE_GUID(IID_IDebugControl2,0xd4366723,0x44df,0x4bed,0x8c,0x7e,0x4c,0x05,0x42,0x4f,0x45,0x88);
  DEFINE_GUID(IID_IDebugControl3,0x7df74a86,0xb03f,0x407f,0x90,0xab,0xa2,0x0d,0xad,0xce,0xad,0x08);
  DEFINE_GUID(IID_IDebugDataSpaces,0x88f7dfab,0x3ea7,0x4c3a,0xae,0xfb,0xc4,0xe8,0x10,0x61,0x73,0xaa);
  DEFINE_GUID(IID_IDebugDataSpaces2,0x7a5e852f,0x96e9,0x468f,0xac,0x1b,0x0b,0x3a,0xdd,0xc4,0xa0,0x49);
  DEFINE_GUID(IID_IDebugDataSpaces3,0x23f79d6c,0x8aaf,0x4f7c,0xa6,0x07,0x99,0x95,0xf5,0x40,0x7e,0x63);
  DEFINE_GUID(IID_IDebugEventCallbacks,0x337be28b,0x5036,0x4d72,0xb6,0xbf,0xc4,0x5f,0xbb,0x9f,0x2e,0xaa);
  DEFINE_GUID(IID_IDebugInputCallbacks,0x9f50e42c,0xf136,0x499e,0x9a,0x97,0x73,0x03,0x6c,0x94,0xed,0x2d);
  DEFINE_GUID(IID_IDebugOutputCallbacks,0x4bf58045,0xd654,0x4c40,0xb0,0xaf,0x68,0x30,0x90,0xf3,0x56,0xdc);
  DEFINE_GUID(IID_IDebugRegisters,0xce289126,0x9e84,0x45a7,0x93,0x7e,0x67,0xbb,0x18,0x69,0x14,0x93);
  DEFINE_GUID(IID_IDebugSymbolGroup,0xf2528316,0x0f1a,0x4431,0xae,0xed,0x11,0xd0,0x96,0xe1,0xe2,0xab);
  DEFINE_GUID(IID_IDebugSymbols,0x8c31e98c,0x983a,0x48a5,0x90,0x16,0x6f,0xe5,0xd6,0x67,0xa9,0x50);
  DEFINE_GUID(IID_IDebugSymbols2,0x3a707211,0xafdd,0x4495,0xad,0x4f,0x56,0xfe,0xcd,0xf8,0x16,0x3f);
  DEFINE_GUID(IID_IDebugSystemObjects,0x6b86fe2c,0x2c4f,0x4f0c,0x9d,0xa2,0x17,0x43,0x11,0xac,0xc3,0x27);
  DEFINE_GUID(IID_IDebugSystemObjects2,0x0ae9f5ff,0x1852,0x4679,0xb0,0x55,0x49,0x4b,0xee,0x64,0x07,0xee);
  DEFINE_GUID(IID_IDebugSystemObjects3,0xe9676e2f,0xe286,0x4ea3,0xb0,0xf9,0xdf,0xe5,0xd9,0xfc,0x33,0x0e);

  typedef struct IDebugAdvanced *PDEBUG_ADVANCED;
  typedef struct IDebugBreakpoint *PDEBUG_BREAKPOINT;
  typedef struct IDebugClient *PDEBUG_CLIENT;
  typedef struct IDebugClient2 *PDEBUG_CLIENT2;
  typedef struct IDebugClient3 *PDEBUG_CLIENT3;
  typedef struct IDebugClient4 *PDEBUG_CLIENT4;
  typedef struct IDebugControl *PDEBUG_CONTROL;
  typedef struct IDebugControl2 *PDEBUG_CONTROL2;
  typedef struct IDebugControl3 *PDEBUG_CONTROL3;
  typedef struct IDebugDataSpaces *PDEBUG_DATA_SPACES;
  typedef struct IDebugDataSpaces2 *PDEBUG_DATA_SPACES2;
  typedef struct IDebugDataSpaces3 *PDEBUG_DATA_SPACES3;
  typedef struct IDebugEventCallbacks *PDEBUG_EVENT_CALLBACKS;
  typedef struct IDebugInputCallbacks *PDEBUG_INPUT_CALLBACKS;
  typedef struct IDebugOutputCallbacks *PDEBUG_OUTPUT_CALLBACKS;
  typedef struct IDebugRegisters *PDEBUG_REGISTERS;
  typedef struct IDebugSymbolGroup *PDEBUG_SYMBOL_GROUP;
  typedef struct IDebugSymbols *PDEBUG_SYMBOLS;
  typedef struct IDebugSymbols2 *PDEBUG_SYMBOLS2;
  typedef struct IDebugSystemObjects *PDEBUG_SYSTEM_OBJECTS;
  typedef struct IDebugSystemObjects2 *PDEBUG_SYSTEM_OBJECTS2;
  typedef struct IDebugSystemObjects3 *PDEBUG_SYSTEM_OBJECTS3;

#define DEBUG_EXTEND64(Addr) ((ULONG64)(LONG64)(LONG)(Addr))

  STDAPI DebugConnect(PCSTR RemoteOptions,REFIID InterfaceId,PVOID *Interface);
  STDAPI DebugCreate(REFIID InterfaceId,PVOID *Interface);

#undef INTERFACE
#define INTERFACE IDebugAdvanced
  DECLARE_INTERFACE_(IDebugAdvanced,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetThreadContext)(THIS_ PVOID Context,ULONG ContextSize) PURE;
    STDMETHOD(SetThreadContext)(THIS_ PVOID Context,ULONG ContextSize) PURE;
  };

#define DEBUG_BREAKPOINT_CODE 0
#define DEBUG_BREAKPOINT_DATA 1

#define DEBUG_BREAKPOINT_GO_ONLY 0x00000001
#define DEBUG_BREAKPOINT_DEFERRED 0x00000002
#define DEBUG_BREAKPOINT_ENABLED 0x00000004
#define DEBUG_BREAKPOINT_ADDER_ONLY 0x00000008
#define DEBUG_BREAKPOINT_ONE_SHOT 0x00000010

#define DEBUG_BREAK_READ 0x00000001
#define DEBUG_BREAK_WRITE 0x00000002
#define DEBUG_BREAK_EXECUTE 0x00000004
#define DEBUG_BREAK_IO 0x00000008

  typedef struct _DEBUG_BREAKPOINT_PARAMETERS {
    ULONG64 Offset;
    ULONG Id;
    ULONG BreakType;
    ULONG ProcType;
    ULONG Flags;
    ULONG DataSize;
    ULONG DataAccessType;
    ULONG PassCount;
    ULONG CurrentPassCount;
    ULONG MatchThread;
    ULONG CommandSize;
    ULONG OffsetExpressionSize;
  } DEBUG_BREAKPOINT_PARAMETERS,*PDEBUG_BREAKPOINT_PARAMETERS;

#undef INTERFACE
#define INTERFACE IDebugBreakpoint
  DECLARE_INTERFACE_(IDebugBreakpoint,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetId)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetType)(THIS_ PULONG BreakType,PULONG ProcType) PURE;
    STDMETHOD(GetAdder)(THIS_ PDEBUG_CLIENT *Adder) PURE;
    STDMETHOD(GetFlags)(THIS_ PULONG Flags) PURE;
    STDMETHOD(AddFlags)(THIS_ ULONG Flags) PURE;
    STDMETHOD(RemoveFlags)(THIS_ ULONG Flags) PURE;
    STDMETHOD(SetFlags)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(SetOffset)(THIS_ ULONG64 Offset) PURE;
    STDMETHOD(GetDataParameters)(THIS_ PULONG Size,PULONG AccessType) PURE;
    STDMETHOD(SetDataParameters)(THIS_ ULONG Size,ULONG AccessType) PURE;
    STDMETHOD(GetPassCount)(THIS_ PULONG Count) PURE;
    STDMETHOD(SetPassCount)(THIS_ ULONG Count) PURE;
    STDMETHOD(GetCurrentPassCount)(THIS_ PULONG Count) PURE;
    STDMETHOD(GetMatchThreadId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetMatchThreadId)(THIS_ ULONG Thread) PURE;
    STDMETHOD(GetCommand)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetCommand)(THIS_ PCSTR Command) PURE;
    STDMETHOD(GetOffsetExpression)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG ExpressionSize) PURE;
    STDMETHOD(SetOffsetExpression)(THIS_ PCSTR Expression) PURE;
    STDMETHOD(GetParameters)(THIS_ PDEBUG_BREAKPOINT_PARAMETERS Params) PURE;
  };

#define DEBUG_ATTACH_KERNEL_CONNECTION 0x00000000
#define DEBUG_ATTACH_LOCAL_KERNEL 0x00000001
#define DEBUG_ATTACH_EXDI_DRIVER 0x00000002

#define DEBUG_GET_PROC_DEFAULT 0x00000000
#define DEBUG_GET_PROC_FULL_MATCH 0x00000001
#define DEBUG_GET_PROC_ONLY_MATCH 0x00000002

#define DEBUG_PROC_DESC_DEFAULT 0x00000000
#define DEBUG_PROC_DESC_NO_PATHS 0x00000001
#define DEBUG_PROC_DESC_NO_SERVICES 0x00000002
#define DEBUG_PROC_DESC_NO_MTS_PACKAGES 0x00000004
#define DEBUG_PROC_DESC_NO_COMMAND_LINE 0x00000008

#define DEBUG_ATTACH_DEFAULT 0x00000000
#define DEBUG_ATTACH_NONINVASIVE 0x00000001
#define DEBUG_ATTACH_EXISTING 0x00000002
#define DEBUG_ATTACH_NONINVASIVE_NO_SUSPEND 0x00000004
#define DEBUG_ATTACH_INVASIVE_NO_INITIAL_BREAK 0x00000008
#define DEBUG_ATTACH_INVASIVE_RESUME_PROCESS 0x00000010

#define DEBUG_CREATE_PROCESS_NO_DEBUG_HEAP CREATE_UNICODE_ENVIRONMENT
#define DEBUG_CREATE_PROCESS_THROUGH_RTL STACK_SIZE_PARAM_IS_A_RESERVATION

#define DEBUG_PROCESS_DETACH_ON_EXIT 0x00000001
#define DEBUG_PROCESS_ONLY_THIS_PROCESS 0x00000002

#define DEBUG_CONNECT_SESSION_DEFAULT 0x00000000
#define DEBUG_CONNECT_SESSION_NO_VERSION 0x00000001
#define DEBUG_CONNECT_SESSION_NO_ANNOUNCE 0x00000002

#define DEBUG_SERVERS_DEBUGGER 0x00000001
#define DEBUG_SERVERS_PROCESS 0x00000002
#define DEBUG_SERVERS_ALL 0x00000003

#define DEBUG_END_PASSIVE 0x00000000
#define DEBUG_END_ACTIVE_TERMINATE 0x00000001
#define DEBUG_END_ACTIVE_DETACH 0x00000002
#define DEBUG_END_REENTRANT 0x00000003
#define DEBUG_END_DISCONNECT 0x00000004

#define DEBUG_OUTPUT_NORMAL 0x00000001
#define DEBUG_OUTPUT_ERROR 0x00000002
#define DEBUG_OUTPUT_WARNING 0x00000004
#define DEBUG_OUTPUT_VERBOSE 0x00000008
#define DEBUG_OUTPUT_PROMPT 0x00000010
#define DEBUG_OUTPUT_PROMPT_REGISTERS 0x00000020
#define DEBUG_OUTPUT_EXTENSION_WARNING 0x00000040
#define DEBUG_OUTPUT_DEBUGGEE 0x00000080
#define DEBUG_OUTPUT_DEBUGGEE_PROMPT 0x00000100
#define DEBUG_OUTPUT_SYMBOLS 0x00000200

#define DEBUG_OUTPUT_IDENTITY_DEFAULT 0x00000000

#define DEBUG_IOUTPUT_KD_PROTOCOL 0x80000000
#define DEBUG_IOUTPUT_REMOTING 0x40000000
#define DEBUG_IOUTPUT_BREAKPOINT 0x20000000
#define DEBUG_IOUTPUT_EVENT 0x10000000

#undef INTERFACE
#define INTERFACE IDebugClient
  DECLARE_INTERFACE_(IDebugClient,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(AttachKernel)(THIS_ ULONG Flags,PCSTR ConnectOptions) PURE;
    STDMETHOD(GetKernelConnectionOptions)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG OptionsSize) PURE;
    STDMETHOD(SetKernelConnectionOptions)(THIS_ PCSTR Options) PURE;
    STDMETHOD(StartProcessServer)(THIS_ ULONG Flags,PCSTR Options,PVOID Reserved) PURE;
    STDMETHOD(ConnectProcessServer)(THIS_ PCSTR RemoteOptions,PULONG64 Server) PURE;
    STDMETHOD(DisconnectProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(GetRunningProcessSystemIds)(THIS_ ULONG64 Server,PULONG Ids,ULONG Count,PULONG ActualCount) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableName)(THIS_ ULONG64 Server,PCSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescription)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(AttachProcess)(THIS_ ULONG64 Server,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(CreateProcess)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttach)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(GetProcessOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(OpenDumpFile)(THIS_ PCSTR DumpFile) PURE;
    STDMETHOD(WriteDumpFile)(THIS_ PCSTR DumpFile,ULONG Qualifier) PURE;
    STDMETHOD(ConnectSession)(THIS_ ULONG Flags,ULONG HistoryLimit) PURE;
    STDMETHOD(StartServer)(THIS_ PCSTR Options) PURE;
    STDMETHOD(OutputServers)(THIS_ ULONG OutputControl,PCSTR Machine,ULONG Flags) PURE;
    STDMETHOD(TerminateProcesses)(THIS) PURE;
    STDMETHOD(DetachProcesses)(THIS) PURE;
    STDMETHOD(EndSession)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetExitCode)(THIS_ PULONG Code) PURE;
    STDMETHOD(DispatchCallbacks)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(ExitDispatch)(THIS_ PDEBUG_CLIENT Client) PURE;
    STDMETHOD(CreateClient)(THIS_ PDEBUG_CLIENT *Client) PURE;
    STDMETHOD(GetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetOutputMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(GetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,PULONG Mask) PURE;
    STDMETHOD(SetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,ULONG Mask) PURE;
    STDMETHOD(GetOutputWidth)(THIS_ PULONG Columns) PURE;
    STDMETHOD(SetOutputWidth)(THIS_ ULONG Columns) PURE;
    STDMETHOD(GetOutputLinePrefix)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PrefixSize) PURE;
    STDMETHOD(SetOutputLinePrefix)(THIS_ PCSTR Prefix) PURE;
    STDMETHOD(GetIdentity)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG IdentitySize) PURE;
    STDMETHOD(OutputIdentity)(THIS_ ULONG OutputControl,ULONG Flags,PCSTR Format) PURE;
    STDMETHOD(GetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS Callbacks) PURE;
    STDMETHOD(FlushCallbacks)(THIS) PURE;
  };

#define DEBUG_FORMAT_DEFAULT 0x00000000
#define DEBUG_FORMAT_WRITE_CAB 0x20000000
#define DEBUG_FORMAT_CAB_SECONDARY_FILES 0x40000000
#define DEBUG_FORMAT_NO_OVERWRITE 0x80000000
#define DEBUG_FORMAT_USER_SMALL_FULL_MEMORY 0x00000001
#define DEBUG_FORMAT_USER_SMALL_HANDLE_DATA 0x00000002
#define DEBUG_FORMAT_USER_SMALL_UNLOADED_MODULES 0x00000004
#define DEBUG_FORMAT_USER_SMALL_INDIRECT_MEMORY 0x00000008
#define DEBUG_FORMAT_USER_SMALL_DATA_SEGMENTS 0x00000010
#define DEBUG_FORMAT_USER_SMALL_FILTER_MEMORY 0x00000020
#define DEBUG_FORMAT_USER_SMALL_FILTER_PATHS 0x00000040
#define DEBUG_FORMAT_USER_SMALL_PROCESS_THREAD_DATA 0x00000080
#define DEBUG_FORMAT_USER_SMALL_PRIVATE_READ_WRITE_MEMORY 0x00000100

#define DEBUG_DUMP_FILE_BASE 0xffffffff
#define DEBUG_DUMP_FILE_PAGE_FILE_DUMP 0x00000000
#define DEBUG_DUMP_FILE_LOAD_FAILED_INDEX 0xffffffff

#undef INTERFACE
#define INTERFACE IDebugClient2
  DECLARE_INTERFACE_(IDebugClient2,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(AttachKernel)(THIS_ ULONG Flags,PCSTR ConnectOptions) PURE;
    STDMETHOD(GetKernelConnectionOptions)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG OptionsSize) PURE;
    STDMETHOD(SetKernelConnectionOptions)(THIS_ PCSTR Options) PURE;
    STDMETHOD(StartProcessServer)(THIS_ ULONG Flags,PCSTR Options,PVOID Reserved) PURE;
    STDMETHOD(ConnectProcessServer)(THIS_ PCSTR RemoteOptions,PULONG64 Server) PURE;
    STDMETHOD(DisconnectProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(GetRunningProcessSystemIds)(THIS_ ULONG64 Server,PULONG Ids,ULONG Count,PULONG ActualCount) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableName)(THIS_ ULONG64 Server,PCSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescription)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(AttachProcess)(THIS_ ULONG64 Server,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(CreateProcess)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttach)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(GetProcessOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(OpenDumpFile)(THIS_ PCSTR DumpFile) PURE;
    STDMETHOD(WriteDumpFile)(THIS_ PCSTR DumpFile,ULONG Qualifier) PURE;
    STDMETHOD(ConnectSession)(THIS_ ULONG Flags,ULONG HistoryLimit) PURE;
    STDMETHOD(StartServer)(THIS_ PCSTR Options) PURE;
    STDMETHOD(OutputServers)(THIS_ ULONG OutputControl,PCSTR Machine,ULONG Flags) PURE;
    STDMETHOD(TerminateProcesses)(THIS) PURE;
    STDMETHOD(DetachProcesses)(THIS) PURE;
    STDMETHOD(EndSession)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetExitCode)(THIS_ PULONG Code) PURE;
    STDMETHOD(DispatchCallbacks)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(ExitDispatch)(THIS_ PDEBUG_CLIENT Client) PURE;
    STDMETHOD(CreateClient)(THIS_ PDEBUG_CLIENT *Client) PURE;
    STDMETHOD(GetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetOutputMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(GetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,PULONG Mask) PURE;
    STDMETHOD(SetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,ULONG Mask) PURE;
    STDMETHOD(GetOutputWidth)(THIS_ PULONG Columns) PURE;
    STDMETHOD(SetOutputWidth)(THIS_ ULONG Columns) PURE;
    STDMETHOD(GetOutputLinePrefix)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PrefixSize) PURE;
    STDMETHOD(SetOutputLinePrefix)(THIS_ PCSTR Prefix) PURE;
    STDMETHOD(GetIdentity)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG IdentitySize) PURE;
    STDMETHOD(OutputIdentity)(THIS_ ULONG OutputControl,ULONG Flags,PCSTR Format) PURE;
    STDMETHOD(GetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS Callbacks) PURE;
    STDMETHOD(FlushCallbacks)(THIS) PURE;
    STDMETHOD(WriteDumpFile2)(THIS_ PCSTR DumpFile,ULONG Qualifier,ULONG FormatFlags,PCSTR Comment) PURE;
    STDMETHOD(AddDumpInformationFile)(THIS_ PCSTR InfoFile,ULONG Type) PURE;
    STDMETHOD(EndProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(WaitForProcessServerEnd)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(IsKernelDebuggerEnabled)(THIS) PURE;
    STDMETHOD(TerminateCurrentProcess)(THIS) PURE;
    STDMETHOD(DetachCurrentProcess)(THIS) PURE;
    STDMETHOD(AbandonCurrentProcess)(THIS) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugClient3
  DECLARE_INTERFACE_(IDebugClient3,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(AttachKernel)(THIS_
      ULONG Flags,PCSTR ConnectOptions) PURE;
    STDMETHOD(GetKernelConnectionOptions)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG OptionsSize) PURE;
    STDMETHOD(SetKernelConnectionOptions)(THIS_ PCSTR Options) PURE;
    STDMETHOD(StartProcessServer)(THIS_ ULONG Flags,PCSTR Options,PVOID Reserved) PURE;
    STDMETHOD(ConnectProcessServer)(THIS_ PCSTR RemoteOptions,PULONG64 Server) PURE;
    STDMETHOD(DisconnectProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(GetRunningProcessSystemIds)(THIS_ ULONG64 Server,PULONG Ids,ULONG Count,PULONG ActualCount) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableName)(THIS_ ULONG64 Server,PCSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescription)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(AttachProcess)(THIS_ ULONG64 Server,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(CreateProcess)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttach)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(GetProcessOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(OpenDumpFile)(THIS_ PCSTR DumpFile) PURE;
    STDMETHOD(WriteDumpFile)(THIS_ PCSTR DumpFile,ULONG Qualifier) PURE;
    STDMETHOD(ConnectSession)(THIS_ ULONG Flags,ULONG HistoryLimit) PURE;
    STDMETHOD(StartServer)(THIS_ PCSTR Options) PURE;
    STDMETHOD(OutputServers)(THIS_ ULONG OutputControl,PCSTR Machine,ULONG Flags) PURE;
    STDMETHOD(TerminateProcesses)(THIS) PURE;
    STDMETHOD(DetachProcesses)(THIS) PURE;
    STDMETHOD(EndSession)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetExitCode)(THIS_ PULONG Code) PURE;
    STDMETHOD(DispatchCallbacks)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(ExitDispatch)(THIS_ PDEBUG_CLIENT Client) PURE;
    STDMETHOD(CreateClient)(THIS_ PDEBUG_CLIENT *Client) PURE;
    STDMETHOD(GetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetOutputMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(GetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,PULONG Mask) PURE;
    STDMETHOD(SetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,ULONG Mask) PURE;
    STDMETHOD(GetOutputWidth)(THIS_ PULONG Columns) PURE;
    STDMETHOD(SetOutputWidth)(THIS_ ULONG Columns) PURE;
    STDMETHOD(GetOutputLinePrefix)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PrefixSize) PURE;
    STDMETHOD(SetOutputLinePrefix)(THIS_ PCSTR Prefix) PURE;
    STDMETHOD(GetIdentity)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG IdentitySize) PURE;
    STDMETHOD(OutputIdentity)(THIS_ ULONG OutputControl,ULONG Flags,PCSTR Format) PURE;
    STDMETHOD(GetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS Callbacks) PURE;
    STDMETHOD(FlushCallbacks)(THIS) PURE;
    STDMETHOD(WriteDumpFile2)(THIS_ PCSTR DumpFile,ULONG Qualifier,ULONG FormatFlags,PCSTR Comment) PURE;
    STDMETHOD(AddDumpInformationFile)(THIS_ PCSTR InfoFile,ULONG Type) PURE;
    STDMETHOD(EndProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(WaitForProcessServerEnd)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(IsKernelDebuggerEnabled)(THIS) PURE;
    STDMETHOD(TerminateCurrentProcess)(THIS) PURE;
    STDMETHOD(DetachCurrentProcess)(THIS) PURE;
    STDMETHOD(AbandonCurrentProcess)(THIS) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableNameWide)(THIS_ ULONG64 Server,PCWSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescriptionWide)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PWSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PWSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(CreateProcessWide)(THIS_ ULONG64 Server,PWSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttachWide)(THIS_ ULONG64 Server,PWSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugClient4
  DECLARE_INTERFACE_(IDebugClient4,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(AttachKernel)(THIS_ ULONG Flags,PCSTR ConnectOptions) PURE;
    STDMETHOD(GetKernelConnectionOptions)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG OptionsSize) PURE;
    STDMETHOD(SetKernelConnectionOptions)(THIS_ PCSTR Options) PURE;
    STDMETHOD(StartProcessServer)(THIS_ ULONG Flags,PCSTR Options,PVOID Reserved) PURE;
    STDMETHOD(ConnectProcessServer)(THIS_ PCSTR RemoteOptions,PULONG64 Server) PURE;
    STDMETHOD(DisconnectProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(GetRunningProcessSystemIds)(THIS_ ULONG64 Server,PULONG Ids,ULONG Count,PULONG ActualCount) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableName)(THIS_ ULONG64 Server,PCSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescription)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(AttachProcess)(THIS_ ULONG64 Server,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(CreateProcess)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttach)(THIS_ ULONG64 Server,PSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(GetProcessOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetProcessOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(OpenDumpFile)(THIS_ PCSTR DumpFile) PURE;
    STDMETHOD(WriteDumpFile)(THIS_ PCSTR DumpFile,ULONG Qualifier) PURE;
    STDMETHOD(ConnectSession)(THIS_ ULONG Flags,ULONG HistoryLimit) PURE;
    STDMETHOD(StartServer)(THIS_ PCSTR Options) PURE;
    STDMETHOD(OutputServers)(THIS_ ULONG OutputControl,PCSTR Machine,ULONG Flags) PURE;
    STDMETHOD(TerminateProcesses)(THIS) PURE;
    STDMETHOD(DetachProcesses)(THIS) PURE;
    STDMETHOD(EndSession)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetExitCode)(THIS_ PULONG Code) PURE;
    STDMETHOD(DispatchCallbacks)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(ExitDispatch)(THIS_ PDEBUG_CLIENT Client) PURE;
    STDMETHOD(CreateClient)(THIS_ PDEBUG_CLIENT *Client) PURE;
    STDMETHOD(GetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetInputCallbacks)(THIS_ PDEBUG_INPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetOutputCallbacks)(THIS_ PDEBUG_OUTPUT_CALLBACKS Callbacks) PURE;
    STDMETHOD(GetOutputMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetOutputMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(GetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,PULONG Mask) PURE;
    STDMETHOD(SetOtherOutputMask)(THIS_ PDEBUG_CLIENT Client,ULONG Mask) PURE;
    STDMETHOD(GetOutputWidth)(THIS_ PULONG Columns) PURE;
    STDMETHOD(SetOutputWidth)(THIS_ ULONG Columns) PURE;
    STDMETHOD(GetOutputLinePrefix)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PrefixSize) PURE;
    STDMETHOD(SetOutputLinePrefix)(THIS_ PCSTR Prefix) PURE;
    STDMETHOD(GetIdentity)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG IdentitySize) PURE;
    STDMETHOD(OutputIdentity)(THIS_ ULONG OutputControl,ULONG Flags,PCSTR Format) PURE;
    STDMETHOD(GetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS *Callbacks) PURE;
    STDMETHOD(SetEventCallbacks)(THIS_ PDEBUG_EVENT_CALLBACKS Callbacks) PURE;
    STDMETHOD(FlushCallbacks)(THIS) PURE;
    STDMETHOD(WriteDumpFile2)(THIS_ PCSTR DumpFile,ULONG Qualifier,ULONG FormatFlags,PCSTR Comment) PURE;
    STDMETHOD(AddDumpInformationFile)(THIS_ PCSTR InfoFile,ULONG Type) PURE;
    STDMETHOD(EndProcessServer)(THIS_ ULONG64 Server) PURE;
    STDMETHOD(WaitForProcessServerEnd)(THIS_ ULONG Timeout) PURE;
    STDMETHOD(IsKernelDebuggerEnabled)(THIS) PURE;
    STDMETHOD(TerminateCurrentProcess)(THIS) PURE;
    STDMETHOD(DetachCurrentProcess)(THIS) PURE;
    STDMETHOD(AbandonCurrentProcess)(THIS) PURE;
    STDMETHOD(GetRunningProcessSystemIdByExecutableNameWide)(THIS_ ULONG64 Server,PCWSTR ExeName,ULONG Flags,PULONG Id) PURE;
    STDMETHOD(GetRunningProcessDescriptionWide)(THIS_ ULONG64 Server,ULONG SystemId,ULONG Flags,PWSTR ExeName,ULONG ExeNameSize,PULONG ActualExeNameSize,PWSTR Description,ULONG DescriptionSize,PULONG ActualDescriptionSize) PURE;
    STDMETHOD(CreateProcessWide)(THIS_ ULONG64 Server,PWSTR CommandLine,ULONG CreateFlags) PURE;
    STDMETHOD(CreateProcessAndAttachWide)(THIS_ ULONG64 Server,PWSTR CommandLine,ULONG CreateFlags,ULONG ProcessId,ULONG AttachFlags) PURE;
    STDMETHOD(OpenDumpFileWide)(THIS_ PCWSTR FileName,ULONG64 FileHandle) PURE;
    STDMETHOD(WriteDumpFileWide)(THIS_ PCWSTR FileName,ULONG64 FileHandle,ULONG Qualifier,ULONG FormatFlags,PCWSTR Comment) PURE;
    STDMETHOD(AddDumpInformationFileWide)(THIS_ PCWSTR FileName,ULONG64 FileHandle,ULONG Type) PURE;
    STDMETHOD(GetNumberDumpFiles)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetDumpFile)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG NameSize,PULONG64 Handle,PULONG Type) PURE;
    STDMETHOD(GetDumpFileWide)(THIS_ ULONG Index,PWSTR Buffer,ULONG BufferSize,PULONG NameSize,PULONG64 Handle,PULONG Type) PURE;
  };

#define DEBUG_STATUS_NO_CHANGE 0
#define DEBUG_STATUS_GO 1
#define DEBUG_STATUS_GO_HANDLED 2
#define DEBUG_STATUS_GO_NOT_HANDLED 3
#define DEBUG_STATUS_STEP_OVER 4
#define DEBUG_STATUS_STEP_INTO 5
#define DEBUG_STATUS_BREAK 6
#define DEBUG_STATUS_NO_DEBUGGEE 7
#define DEBUG_STATUS_STEP_BRANCH 8
#define DEBUG_STATUS_IGNORE_EVENT 9

#define DEBUG_STATUS_MASK 0xf

#define DEBUG_STATUS_INSIDE_WAIT 0x100000000
#define DEBUG_OUTCTL_THIS_CLIENT 0x00000000
#define DEBUG_OUTCTL_ALL_CLIENTS 0x00000001
#define DEBUG_OUTCTL_ALL_OTHER_CLIENTS 0x00000002
#define DEBUG_OUTCTL_IGNORE 0x00000003
#define DEBUG_OUTCTL_LOG_ONLY 0x00000004
#define DEBUG_OUTCTL_SEND_MASK 0x00000007
#define DEBUG_OUTCTL_NOT_LOGGED 0x00000008
#define DEBUG_OUTCTL_OVERRIDE_MASK 0x00000010
#define DEBUG_OUTCTL_AMBIENT 0xffffffff

#define DEBUG_INTERRUPT_ACTIVE 0
#define DEBUG_INTERRUPT_PASSIVE 1
#define DEBUG_INTERRUPT_EXIT 2

#define DEBUG_CURRENT_DEFAULT 0x0000000f
#define DEBUG_CURRENT_SYMBOL 0x00000001
#define DEBUG_CURRENT_DISASM 0x00000002
#define DEBUG_CURRENT_REGISTERS 0x00000004
#define DEBUG_CURRENT_SOURCE_LINE 0x00000008

#define DEBUG_DISASM_EFFECTIVE_ADDRESS 0x00000001
#define DEBUG_DISASM_MATCHING_SYMBOLS 0x00000002

#define DEBUG_LEVEL_SOURCE 0
#define DEBUG_LEVEL_ASSEMBLY 1

#define DEBUG_ENGOPT_IGNORE_DBGHELP_VERSION 0x00000001
#define DEBUG_ENGOPT_IGNORE_EXTENSION_VERSIONS 0x00000002

#define DEBUG_ENGOPT_ALLOW_NETWORK_PATHS 0x00000004
#define DEBUG_ENGOPT_DISALLOW_NETWORK_PATHS 0x00000008
#define DEBUG_ENGOPT_NETWORK_PATHS (0x00000004 | 0x00000008)
#define DEBUG_ENGOPT_IGNORE_LOADER_EXCEPTIONS 0x00000010
#define DEBUG_ENGOPT_INITIAL_BREAK 0x00000020
#define DEBUG_ENGOPT_INITIAL_MODULE_BREAK 0x00000040
#define DEBUG_ENGOPT_FINAL_BREAK 0x00000080
#define DEBUG_ENGOPT_NO_EXECUTE_REPEAT 0x00000100
#define DEBUG_ENGOPT_FAIL_INCOMPLETE_INFORMATION 0x00000200
#define DEBUG_ENGOPT_ALLOW_READ_ONLY_BREAKPOINTS 0x00000400
#define DEBUG_ENGOPT_SYNCHRONIZE_BREAKPOINTS 0x00000800
#define DEBUG_ENGOPT_DISALLOW_SHELL_COMMANDS 0x00001000
#define DEBUG_ENGOPT_ALL 0x00001FFF

#define DEBUG_ANY_ID 0xffffffff

  typedef struct _DEBUG_STACK_FRAME {
    ULONG64 InstructionOffset;
    ULONG64 ReturnOffset;
    ULONG64 FrameOffset;
    ULONG64 StackOffset;
    ULONG64 FuncTableEntry;
    ULONG64 Params[4];
    ULONG64 Reserved[6];
    WINBOOL Virtual;
    ULONG FrameNumber;
  } DEBUG_STACK_FRAME,*PDEBUG_STACK_FRAME;

#define DEBUG_STACK_ARGUMENTS 0x00000001
#define DEBUG_STACK_FUNCTION_INFO 0x00000002
#define DEBUG_STACK_SOURCE_LINE 0x00000004
#define DEBUG_STACK_FRAME_ADDRESSES 0x00000008
#define DEBUG_STACK_COLUMN_NAMES 0x00000010
#define DEBUG_STACK_NONVOLATILE_REGISTERS 0x00000020
#define DEBUG_STACK_FRAME_NUMBERS 0x00000040
#define DEBUG_STACK_PARAMETERS 0x00000080
#define DEBUG_STACK_FRAME_ADDRESSES_RA_ONLY 0x00000100
#define DEBUG_STACK_FRAME_MEMORY_USAGE 0x00000200

#define DEBUG_CLASS_UNINITIALIZED 0
#define DEBUG_CLASS_KERNEL 1
#define DEBUG_CLASS_USER_WINDOWS 2

#define DEBUG_DUMP_SMALL 1024
#define DEBUG_DUMP_DEFAULT 1025
#define DEBUG_DUMP_FULL 1026

#define DEBUG_KERNEL_CONNECTION 0
#define DEBUG_KERNEL_LOCAL 1
#define DEBUG_KERNEL_EXDI_DRIVER 2
#define DEBUG_KERNEL_SMALL_DUMP DEBUG_DUMP_SMALL
#define DEBUG_KERNEL_DUMP DEBUG_DUMP_DEFAULT
#define DEBUG_KERNEL_FULL_DUMP DEBUG_DUMP_FULL

#define DEBUG_USER_WINDOWS_PROCESS 0
#define DEBUG_USER_WINDOWS_PROCESS_SERVER 1
#define DEBUG_USER_WINDOWS_SMALL_DUMP DEBUG_DUMP_SMALL
#define DEBUG_USER_WINDOWS_DUMP DEBUG_DUMP_DEFAULT

#define DEBUG_EXTENSION_AT_ENGINE 0x00000000

#define DEBUG_EXECUTE_DEFAULT 0x00000000
#define DEBUG_EXECUTE_ECHO 0x00000001
#define DEBUG_EXECUTE_NOT_LOGGED 0x00000002
#define DEBUG_EXECUTE_NO_REPEAT 0x00000004

#define DEBUG_FILTER_CREATE_THREAD 0x00000000
#define DEBUG_FILTER_EXIT_THREAD 0x00000001
#define DEBUG_FILTER_CREATE_PROCESS 0x00000002
#define DEBUG_FILTER_EXIT_PROCESS 0x00000003
#define DEBUG_FILTER_LOAD_MODULE 0x00000004
#define DEBUG_FILTER_UNLOAD_MODULE 0x00000005
#define DEBUG_FILTER_SYSTEM_ERROR 0x00000006
#define DEBUG_FILTER_INITIAL_BREAKPOINT 0x00000007
#define DEBUG_FILTER_INITIAL_MODULE_LOAD 0x00000008
#define DEBUG_FILTER_DEBUGGEE_OUTPUT 0x00000009

#define DEBUG_FILTER_BREAK 0x00000000

#define DEBUG_FILTER_SECOND_CHANCE_BREAK 0x00000001
#define DEBUG_FILTER_OUTPUT 0x00000002
#define DEBUG_FILTER_IGNORE 0x00000003
#define DEBUG_FILTER_REMOVE 0x00000004

#define DEBUG_FILTER_GO_HANDLED 0x00000000
#define DEBUG_FILTER_GO_NOT_HANDLED 0x00000001

  typedef struct _DEBUG_SPECIFIC_FILTER_PARAMETERS {
    ULONG ExecutionOption;
    ULONG ContinueOption;
    ULONG TextSize;
    ULONG CommandSize;
    ULONG ArgumentSize;
  } DEBUG_SPECIFIC_FILTER_PARAMETERS,*PDEBUG_SPECIFIC_FILTER_PARAMETERS;

  typedef struct _DEBUG_EXCEPTION_FILTER_PARAMETERS {
    ULONG ExecutionOption;
    ULONG ContinueOption;
    ULONG TextSize;
    ULONG CommandSize;
    ULONG SecondCommandSize;
    ULONG ExceptionCode;
  } DEBUG_EXCEPTION_FILTER_PARAMETERS,*PDEBUG_EXCEPTION_FILTER_PARAMETERS;

#define DEBUG_WAIT_DEFAULT 0x00000000

  typedef struct _DEBUG_LAST_EVENT_INFO_BREAKPOINT {
    ULONG Id;
  } DEBUG_LAST_EVENT_INFO_BREAKPOINT,*PDEBUG_LAST_EVENT_INFO_BREAKPOINT;

  typedef struct _DEBUG_LAST_EVENT_INFO_EXCEPTION {
    EXCEPTION_RECORD64 ExceptionRecord;
    ULONG FirstChance;
  } DEBUG_LAST_EVENT_INFO_EXCEPTION,*PDEBUG_LAST_EVENT_INFO_EXCEPTION;

  typedef struct _DEBUG_LAST_EVENT_INFO_EXIT_THREAD {
    ULONG ExitCode;
  } DEBUG_LAST_EVENT_INFO_EXIT_THREAD,*PDEBUG_LAST_EVENT_INFO_EXIT_THREAD;

  typedef struct _DEBUG_LAST_EVENT_INFO_EXIT_PROCESS {
    ULONG ExitCode;
  } DEBUG_LAST_EVENT_INFO_EXIT_PROCESS,*PDEBUG_LAST_EVENT_INFO_EXIT_PROCESS;

  typedef struct _DEBUG_LAST_EVENT_INFO_LOAD_MODULE {
    ULONG64 Base;
  } DEBUG_LAST_EVENT_INFO_LOAD_MODULE,*PDEBUG_LAST_EVENT_INFO_LOAD_MODULE;

  typedef struct _DEBUG_LAST_EVENT_INFO_UNLOAD_MODULE {
    ULONG64 Base;
  } DEBUG_LAST_EVENT_INFO_UNLOAD_MODULE,*PDEBUG_LAST_EVENT_INFO_UNLOAD_MODULE;

  typedef struct _DEBUG_LAST_EVENT_INFO_SYSTEM_ERROR {
    ULONG Error;
    ULONG Level;
  } DEBUG_LAST_EVENT_INFO_SYSTEM_ERROR,*PDEBUG_LAST_EVENT_INFO_SYSTEM_ERROR;

#define DEBUG_VALUE_INVALID 0
#define DEBUG_VALUE_INT8 1
#define DEBUG_VALUE_INT16 2
#define DEBUG_VALUE_INT32 3
#define DEBUG_VALUE_INT64 4
#define DEBUG_VALUE_FLOAT32 5
#define DEBUG_VALUE_FLOAT64 6
#define DEBUG_VALUE_FLOAT80 7
#define DEBUG_VALUE_FLOAT82 8
#define DEBUG_VALUE_FLOAT128 9
#define DEBUG_VALUE_VECTOR64 10
#define DEBUG_VALUE_VECTOR128 11

#define DEBUG_VALUE_TYPES 12

  typedef struct _DEBUG_VALUE {
    __C89_NAMELESS union {
      UCHAR I8;
      USHORT I16;
      ULONG I32;
      __C89_NAMELESS struct {
	ULONG64 I64;
	WINBOOL Nat;
      };
      float F32;
      double F64;
      UCHAR F80Bytes[10];
      UCHAR F82Bytes[11];
      UCHAR F128Bytes[16];
      UCHAR VI8[16];
      USHORT VI16[8];
      ULONG VI32[4];
      ULONG64 VI64[2];
      float VF32[4];
      double VF64[2];
      struct {
	ULONG LowPart;
	ULONG HighPart;
      } I64Parts32;
      struct {
	ULONG64 LowPart;
	LONG64 HighPart;
      } F128Parts64;
      UCHAR RawBytes[24];
    };
    ULONG TailOfRawBytes;
    ULONG Type;
  } DEBUG_VALUE,*PDEBUG_VALUE;

#undef INTERFACE
#define INTERFACE IDebugControl
  DECLARE_INTERFACE_(IDebugControl,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetInterrupt)(THIS) PURE;
    STDMETHOD(SetInterrupt)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetInterruptTimeout)(THIS_ PULONG Seconds) PURE;
    STDMETHOD(SetInterruptTimeout)(THIS_ ULONG Seconds) PURE;
    STDMETHOD(GetLogFile)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG FileSize,PBOOL Append) PURE;
    STDMETHOD(OpenLogFile)(THIS_ PCSTR File,WINBOOL Append) PURE;
    STDMETHOD(CloseLogFile)(THIS) PURE;
    STDMETHOD(GetLogMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetLogMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(Input)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG InputSize) PURE;
    STDMETHOD(ReturnInput)(THIS_ PCSTR Buffer) PURE;
    STDMETHODV(Output)(THIS_ ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(OutputVaList)(THIS_ ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(ControlledOutput)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(ControlledOutputVaList)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(OutputPrompt)(THIS_ ULONG OutputControl,PCSTR Format,...) PURE;
    STDMETHOD(OutputPromptVaList)(THIS_ ULONG OutputControl,PCSTR Format,va_list Args) PURE;
    STDMETHOD(GetPromptText)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(OutputCurrentState)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
    STDMETHOD(OutputVersionInformation)(THIS_ ULONG OutputControl) PURE;
    STDMETHOD(GetNotifyEventHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(SetNotifyEventHandle)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(Assemble)(THIS_ ULONG64 Offset,PCSTR Instr,PULONG64 EndOffset) PURE;
    STDMETHOD(Disassemble)(THIS_ ULONG64 Offset,ULONG Flags,PSTR Buffer,ULONG BufferSize,PULONG DisassemblySize,PULONG64 EndOffset) PURE;
    STDMETHOD(GetDisassembleEffectiveOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputDisassembly)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG Flags,PULONG64 EndOffset) PURE;
    STDMETHOD(OutputDisassemblyLines)(THIS_ ULONG OutputControl,ULONG PreviousLines,ULONG TotalLines,ULONG64 Offset,ULONG Flags,PULONG OffsetLine,PULONG64 StartOffset,PULONG64 EndOffset,PULONG64 LineOffsets) PURE;
    STDMETHOD(GetNearInstruction)(THIS_ ULONG64 Offset,LONG Delta,PULONG64 NearOffset) PURE;
    STDMETHOD(GetStackTrace)(THIS_ ULONG64 FrameOffset,ULONG64 StackOffset,ULONG64 InstructionOffset,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,PULONG FramesFilled) PURE;
    STDMETHOD(GetReturnOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputStackTrace)(THIS_ ULONG OutputControl,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,ULONG Flags) PURE;
    STDMETHOD(GetDebuggeeType)(THIS_ PULONG Class,PULONG Qualifier) PURE;
    STDMETHOD(GetActualProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetExecutingProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetNumberPossibleExecutingProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetPossibleExecutingProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetNumberProcessors)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSystemVersion)(THIS_ PULONG PlatformId,PULONG Major,PULONG Minor,PSTR ServicePackString,ULONG ServicePackStringSize,PULONG ServicePackStringUsed,PULONG ServicePackNumber,PSTR BuildString,ULONG BuildStringSize,PULONG BuildStringUsed) PURE;
    STDMETHOD(GetPageSize)(THIS_ PULONG Size) PURE;
    STDMETHOD(IsPointer64Bit)(THIS) PURE;
    STDMETHOD(ReadBugCheckData)(THIS_ PULONG Code,PULONG64 Arg1,PULONG64 Arg2,PULONG64 Arg3,PULONG64 Arg4) PURE;
    STDMETHOD(GetNumberSupportedProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSupportedProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetProcessorTypeNames)(THIS_ ULONG Type,PSTR FullNameBuffer,ULONG FullNameBufferSize,PULONG FullNameSize,PSTR AbbrevNameBuffer,ULONG AbbrevNameBufferSize,PULONG AbbrevNameSize) PURE;
    STDMETHOD(GetEffectiveProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(SetEffectiveProcessorType)(THIS_ ULONG Type) PURE;
    STDMETHOD(GetExecutionStatus)(THIS_ PULONG Status) PURE;
    STDMETHOD(SetExecutionStatus)(THIS_ ULONG Status) PURE;
    STDMETHOD(GetCodeLevel)(THIS_ PULONG Level) PURE;
    STDMETHOD(SetCodeLevel)(THIS_ ULONG Level) PURE;
    STDMETHOD(GetEngineOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetSystemErrorControl)(THIS_ PULONG OutputLevel,PULONG BreakLevel) PURE;
    STDMETHOD(SetSystemErrorControl)(THIS_ ULONG OutputLevel,ULONG BreakLevel) PURE;
    STDMETHOD(GetTextMacro)(THIS_ ULONG Slot,PSTR Buffer,ULONG BufferSize,PULONG MacroSize) PURE;
    STDMETHOD(SetTextMacro)(THIS_ ULONG Slot,PCSTR Macro) PURE;
    STDMETHOD(GetRadix)(THIS_ PULONG Radix) PURE;
    STDMETHOD(SetRadix)(THIS_ ULONG Radix) PURE;
    STDMETHOD(Evaluate)(THIS_ PCSTR Expression,ULONG DesiredType,PDEBUG_VALUE Value,PULONG RemainderIndex) PURE;
    STDMETHOD(CoerceValue)(THIS_ PDEBUG_VALUE In,ULONG OutType,PDEBUG_VALUE Out) PURE;
    STDMETHOD(CoerceValues)(THIS_ ULONG Count,PDEBUG_VALUE In,PULONG OutTypes,PDEBUG_VALUE Out) PURE;
    STDMETHOD(Execute)(THIS_ ULONG OutputControl,PCSTR Command,ULONG Flags) PURE;
    STDMETHOD(ExecuteCommandFile)(THIS_ ULONG OutputControl,PCSTR CommandFile,ULONG Flags) PURE;
    STDMETHOD(GetNumberBreakpoints)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetBreakpointByIndex)(THIS_ ULONG Index,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointById)(THIS_ ULONG Id,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointParameters)(THIS_ ULONG Count,PULONG Ids,ULONG Start,PDEBUG_BREAKPOINT_PARAMETERS Params) PURE;
    STDMETHOD(AddBreakpoint)(THIS_ ULONG Type,ULONG DesiredId,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(RemoveBreakpoint)(THIS_ PDEBUG_BREAKPOINT Bp) PURE;
    STDMETHOD(AddExtension)(THIS_ PCSTR Path,ULONG Flags,PULONG64 Handle) PURE;
    STDMETHOD(RemoveExtension)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(GetExtensionByPath)(THIS_ PCSTR Path,PULONG64 Handle) PURE;
    STDMETHOD(CallExtension)(THIS_ ULONG64 Handle,PCSTR Function,PCSTR Arguments) PURE;
    STDMETHOD(GetExtensionFunction)(THIS_ ULONG64 Handle,PCSTR FuncName,FARPROC *Function) PURE;
    STDMETHOD(GetWindbgExtensionApis32)(THIS_ PWINDBG_EXTENSION_APIS32 Api) PURE;
    STDMETHOD(GetWindbgExtensionApis64)(THIS_ PWINDBG_EXTENSION_APIS64 Api) PURE;
    STDMETHOD(GetNumberEventFilters)(THIS_ PULONG SpecificEvents,PULONG SpecificExceptions,PULONG ArbitraryExceptions) PURE;
    STDMETHOD(GetEventFilterText)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(GetEventFilterCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetEventFilterCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(GetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetSpecificFilterArgument)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG ArgumentSize) PURE;
    STDMETHOD(SetSpecificFilterArgument)(THIS_ ULONG Index,PCSTR Argument) PURE;
    STDMETHOD(GetExceptionFilterParameters)(THIS_ ULONG Count,PULONG Codes,ULONG Start,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetExceptionFilterParameters)(THIS_ ULONG Count,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetExceptionFilterSecondCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetExceptionFilterSecondCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(WaitForEvent)(THIS_ ULONG Flags,ULONG Timeout) PURE;
    STDMETHOD(GetLastEventInformation)(THIS_ PULONG Type,PULONG ProcessId,PULONG ThreadId,PVOID ExtraInformation,ULONG ExtraInformationSize,PULONG ExtraInformationUsed,PSTR Description,ULONG DescriptionSize,PULONG DescriptionUsed) PURE;
  };

#define DEBUG_OUT_TEXT_REPL_DEFAULT 0x00000000

#undef INTERFACE
#define INTERFACE IDebugControl2
  DECLARE_INTERFACE_(IDebugControl2,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetInterrupt)(THIS) PURE;
    STDMETHOD(SetInterrupt)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetInterruptTimeout)(THIS_ PULONG Seconds) PURE;
    STDMETHOD(SetInterruptTimeout)(THIS_ ULONG Seconds) PURE;
    STDMETHOD(GetLogFile)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG FileSize,PBOOL Append) PURE;
    STDMETHOD(OpenLogFile)(THIS_ PCSTR File,WINBOOL Append) PURE;
    STDMETHOD(CloseLogFile)(THIS) PURE;
    STDMETHOD(GetLogMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetLogMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(Input)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG InputSize) PURE;
    STDMETHOD(ReturnInput)(THIS_ PCSTR Buffer) PURE;
    STDMETHODV(Output)(THIS_ ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(OutputVaList)(THIS_ ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(ControlledOutput)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(ControlledOutputVaList)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(OutputPrompt)(THIS_ ULONG OutputControl,PCSTR Format,...) PURE;
    STDMETHOD(OutputPromptVaList)(THIS_ ULONG OutputControl,PCSTR Format,va_list Args) PURE;
    STDMETHOD(GetPromptText)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(OutputCurrentState)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
    STDMETHOD(OutputVersionInformation)(THIS_ ULONG OutputControl) PURE;
    STDMETHOD(GetNotifyEventHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(SetNotifyEventHandle)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(Assemble)(THIS_ ULONG64 Offset,PCSTR Instr,PULONG64 EndOffset) PURE;
    STDMETHOD(Disassemble)(THIS_ ULONG64 Offset,ULONG Flags,PSTR Buffer,ULONG BufferSize,PULONG DisassemblySize,PULONG64 EndOffset) PURE;
    STDMETHOD(GetDisassembleEffectiveOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputDisassembly)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG Flags,PULONG64 EndOffset) PURE;
    STDMETHOD(OutputDisassemblyLines)(THIS_ ULONG OutputControl,ULONG PreviousLines,ULONG TotalLines,ULONG64 Offset,ULONG Flags,PULONG OffsetLine,PULONG64 StartOffset,PULONG64 EndOffset,PULONG64 LineOffsets) PURE;
    STDMETHOD(GetNearInstruction)(THIS_ ULONG64 Offset,LONG Delta,PULONG64 NearOffset) PURE;
    STDMETHOD(GetStackTrace)(THIS_ ULONG64 FrameOffset,ULONG64 StackOffset,ULONG64 InstructionOffset,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,PULONG FramesFilled) PURE;
    STDMETHOD(GetReturnOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputStackTrace)(THIS_ ULONG OutputControl,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,ULONG Flags) PURE;
    STDMETHOD(GetDebuggeeType)(THIS_ PULONG Class,PULONG Qualifier) PURE;
    STDMETHOD(GetActualProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetExecutingProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetNumberPossibleExecutingProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetPossibleExecutingProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetNumberProcessors)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSystemVersion)(THIS_ PULONG PlatformId,PULONG Major,PULONG Minor,PSTR ServicePackString,ULONG ServicePackStringSize,PULONG ServicePackStringUsed,PULONG ServicePackNumber,PSTR BuildString,ULONG BuildStringSize,PULONG BuildStringUsed) PURE;
    STDMETHOD(GetPageSize)(THIS_ PULONG Size) PURE;
    STDMETHOD(IsPointer64Bit)(THIS) PURE;
    STDMETHOD(ReadBugCheckData)(THIS_ PULONG Code,PULONG64 Arg1,PULONG64 Arg2,PULONG64 Arg3,PULONG64 Arg4) PURE;
    STDMETHOD(GetNumberSupportedProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSupportedProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetProcessorTypeNames)(THIS_ ULONG Type,PSTR FullNameBuffer,ULONG FullNameBufferSize,PULONG FullNameSize,PSTR AbbrevNameBuffer,ULONG AbbrevNameBufferSize,PULONG AbbrevNameSize) PURE;
    STDMETHOD(GetEffectiveProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(SetEffectiveProcessorType)(THIS_ ULONG Type) PURE;
    STDMETHOD(GetExecutionStatus)(THIS_ PULONG Status) PURE;
    STDMETHOD(SetExecutionStatus)(THIS_ ULONG Status) PURE;
    STDMETHOD(GetCodeLevel)(THIS_ PULONG Level) PURE;
    STDMETHOD(SetCodeLevel)(THIS_ ULONG Level) PURE;
    STDMETHOD(GetEngineOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetSystemErrorControl)(THIS_ PULONG OutputLevel,PULONG BreakLevel) PURE;
    STDMETHOD(SetSystemErrorControl)(THIS_ ULONG OutputLevel,ULONG BreakLevel) PURE;
    STDMETHOD(GetTextMacro)(THIS_ ULONG Slot,PSTR Buffer,ULONG BufferSize,PULONG MacroSize) PURE;
    STDMETHOD(SetTextMacro)(THIS_ ULONG Slot,PCSTR Macro) PURE;
    STDMETHOD(GetRadix)(THIS_ PULONG Radix) PURE;
    STDMETHOD(SetRadix)(THIS_ ULONG Radix) PURE;
    STDMETHOD(Evaluate)(THIS_ PCSTR Expression,ULONG DesiredType,PDEBUG_VALUE Value,PULONG RemainderIndex) PURE;
    STDMETHOD(CoerceValue)(THIS_ PDEBUG_VALUE In,ULONG OutType,PDEBUG_VALUE Out) PURE;
    STDMETHOD(CoerceValues)(THIS_ ULONG Count,PDEBUG_VALUE In,PULONG OutTypes,PDEBUG_VALUE Out) PURE;
    STDMETHOD(Execute)(THIS_ ULONG OutputControl,PCSTR Command,ULONG Flags) PURE;
    STDMETHOD(ExecuteCommandFile)(THIS_ ULONG OutputControl,PCSTR CommandFile,ULONG Flags) PURE;
    STDMETHOD(GetNumberBreakpoints)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetBreakpointByIndex)(THIS_ ULONG Index,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointById)(THIS_ ULONG Id,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointParameters)(THIS_ ULONG Count,PULONG Ids,ULONG Start,PDEBUG_BREAKPOINT_PARAMETERS Params) PURE;
    STDMETHOD(AddBreakpoint)(THIS_ ULONG Type,ULONG DesiredId,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(RemoveBreakpoint)(THIS_ PDEBUG_BREAKPOINT Bp) PURE;
    STDMETHOD(AddExtension)(THIS_ PCSTR Path,ULONG Flags,PULONG64 Handle) PURE;
    STDMETHOD(RemoveExtension)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(GetExtensionByPath)(THIS_ PCSTR Path,PULONG64 Handle) PURE;
    STDMETHOD(CallExtension)(THIS_ ULONG64 Handle,PCSTR Function,PCSTR Arguments) PURE;
    STDMETHOD(GetExtensionFunction)(THIS_ ULONG64 Handle,PCSTR FuncName,FARPROC *Function) PURE;
    STDMETHOD(GetWindbgExtensionApis32)(THIS_ PWINDBG_EXTENSION_APIS32 Api) PURE;
    STDMETHOD(GetWindbgExtensionApis64)(THIS_ PWINDBG_EXTENSION_APIS64 Api) PURE;
    STDMETHOD(GetNumberEventFilters)(THIS_ PULONG SpecificEvents,PULONG SpecificExceptions,PULONG ArbitraryExceptions) PURE;
    STDMETHOD(GetEventFilterText)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(GetEventFilterCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetEventFilterCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(GetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetSpecificFilterArgument)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG ArgumentSize) PURE;
    STDMETHOD(SetSpecificFilterArgument)(THIS_ ULONG Index,PCSTR Argument) PURE;
    STDMETHOD(GetExceptionFilterParameters)(THIS_ ULONG Count,PULONG Codes,ULONG Start,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetExceptionFilterParameters)(THIS_ ULONG Count,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetExceptionFilterSecondCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetExceptionFilterSecondCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(WaitForEvent)(THIS_ ULONG Flags,ULONG Timeout) PURE;
    STDMETHOD(GetLastEventInformation)(THIS_ PULONG Type,PULONG ProcessId,PULONG ThreadId,PVOID ExtraInformation,ULONG ExtraInformationSize,PULONG ExtraInformationUsed,PSTR Description,ULONG DescriptionSize,PULONG DescriptionUsed) PURE;
    STDMETHOD(GetCurrentTimeDate)(THIS_ PULONG TimeDate) PURE;
    STDMETHOD(GetCurrentSystemUpTime)(THIS_ PULONG UpTime) PURE;
    STDMETHOD(GetDumpFormatFlags)(THIS_ PULONG FormatFlags) PURE;
    STDMETHOD(GetNumberTextReplacements)(THIS_ PULONG NumRepl) PURE;
    STDMETHOD(GetTextReplacement)(THIS_ PCSTR SrcText,ULONG Index,PSTR SrcBuffer,ULONG SrcBufferSize,PULONG SrcSize,PSTR DstBuffer,ULONG DstBufferSize,PULONG DstSize) PURE;
    STDMETHOD(SetTextReplacement)(THIS_ PCSTR SrcText,PCSTR DstText) PURE;
    STDMETHOD(RemoveTextReplacements)(THIS) PURE;
    STDMETHOD(OutputTextReplacements)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
  };

#define DEBUG_ASMOPT_DEFAULT 0x00000000
#define DEBUG_ASMOPT_VERBOSE 0x00000001
#define DEBUG_ASMOPT_NO_CODE_BYTES 0x00000002
#define DEBUG_ASMOPT_IGNORE_OUTPUT_WIDTH 0x00000004

#define DEBUG_EXPR_MASM 0x00000000
#define DEBUG_EXPR_CPLUSPLUS 0x00000001

#define DEBUG_EINDEX_NAME 0x00000000
#define DEBUG_EINDEX_FROM_START 0x00000000
#define DEBUG_EINDEX_FROM_END 0x00000001
#define DEBUG_EINDEX_FROM_CURRENT 0x00000002

#undef INTERFACE
#define INTERFACE IDebugControl3
  DECLARE_INTERFACE_(IDebugControl3,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetInterrupt)(THIS) PURE;
    STDMETHOD(SetInterrupt)(THIS_ ULONG Flags) PURE;
    STDMETHOD(GetInterruptTimeout)(THIS_ PULONG Seconds) PURE;
    STDMETHOD(SetInterruptTimeout)(THIS_ ULONG Seconds) PURE;
    STDMETHOD(GetLogFile)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG FileSize,PBOOL Append) PURE;
    STDMETHOD(OpenLogFile)(THIS_ PCSTR File,WINBOOL Append) PURE;
    STDMETHOD(CloseLogFile)(THIS) PURE;
    STDMETHOD(GetLogMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(SetLogMask)(THIS_ ULONG Mask) PURE;
    STDMETHOD(Input)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG InputSize) PURE;
    STDMETHOD(ReturnInput)(THIS_ PCSTR Buffer) PURE;
    STDMETHODV(Output)(THIS_ ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(OutputVaList)(THIS_ ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(ControlledOutput)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,...) PURE;
    STDMETHOD(ControlledOutputVaList)(THIS_ ULONG OutputControl,ULONG Mask,PCSTR Format,va_list Args) PURE;
    STDMETHODV(OutputPrompt)(THIS_ ULONG OutputControl,PCSTR Format,...) PURE;
    STDMETHOD(OutputPromptVaList)(THIS_ ULONG OutputControl,PCSTR Format,va_list Args) PURE;
    STDMETHOD(GetPromptText)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(OutputCurrentState)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
    STDMETHOD(OutputVersionInformation)(THIS_ ULONG OutputControl) PURE;
    STDMETHOD(GetNotifyEventHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(SetNotifyEventHandle)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(Assemble)(THIS_ ULONG64 Offset,PCSTR Instr,PULONG64 EndOffset) PURE;
    STDMETHOD(Disassemble)(THIS_ ULONG64 Offset,ULONG Flags,PSTR Buffer,ULONG BufferSize,PULONG DisassemblySize,PULONG64 EndOffset) PURE;
    STDMETHOD(GetDisassembleEffectiveOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputDisassembly)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG Flags,PULONG64 EndOffset) PURE;
    STDMETHOD(OutputDisassemblyLines)(THIS_ ULONG OutputControl,ULONG PreviousLines,ULONG TotalLines,ULONG64 Offset,ULONG Flags,PULONG OffsetLine,PULONG64 StartOffset,PULONG64 EndOffset,PULONG64 LineOffsets) PURE;
    STDMETHOD(GetNearInstruction)(THIS_ ULONG64 Offset,LONG Delta,PULONG64 NearOffset) PURE;
    STDMETHOD(GetStackTrace)(THIS_ ULONG64 FrameOffset,ULONG64 StackOffset,ULONG64 InstructionOffset,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,PULONG FramesFilled) PURE;
    STDMETHOD(GetReturnOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(OutputStackTrace)(THIS_ ULONG OutputControl,PDEBUG_STACK_FRAME Frames,ULONG FramesSize,ULONG Flags) PURE;
    STDMETHOD(GetDebuggeeType)(THIS_ PULONG Class,PULONG Qualifier) PURE;
    STDMETHOD(GetActualProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetExecutingProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(GetNumberPossibleExecutingProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetPossibleExecutingProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetNumberProcessors)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSystemVersion)(THIS_ PULONG PlatformId,PULONG Major,PULONG Minor,PSTR ServicePackString,ULONG ServicePackStringSize,PULONG ServicePackStringUsed,PULONG ServicePackNumber,PSTR BuildString,ULONG BuildStringSize,PULONG BuildStringUsed) PURE;
    STDMETHOD(GetPageSize)(THIS_ PULONG Size) PURE;
    STDMETHOD(IsPointer64Bit)(THIS) PURE;
    STDMETHOD(ReadBugCheckData)(THIS_ PULONG Code,PULONG64 Arg1,PULONG64 Arg2,PULONG64 Arg3,PULONG64 Arg4) PURE;
    STDMETHOD(GetNumberSupportedProcessorTypes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSupportedProcessorTypes)(THIS_ ULONG Start,ULONG Count,PULONG Types) PURE;
    STDMETHOD(GetProcessorTypeNames)(THIS_ ULONG Type,PSTR FullNameBuffer,ULONG FullNameBufferSize,PULONG FullNameSize,PSTR AbbrevNameBuffer,ULONG AbbrevNameBufferSize,PULONG AbbrevNameSize) PURE;
    STDMETHOD(GetEffectiveProcessorType)(THIS_ PULONG Type) PURE;
    STDMETHOD(SetEffectiveProcessorType)(THIS_ ULONG Type) PURE;
    STDMETHOD(GetExecutionStatus)(THIS_ PULONG Status) PURE;
    STDMETHOD(SetExecutionStatus)(THIS_ ULONG Status) PURE;
    STDMETHOD(GetCodeLevel)(THIS_ PULONG Level) PURE;
    STDMETHOD(SetCodeLevel)(THIS_ ULONG Level) PURE;
    STDMETHOD(GetEngineOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetEngineOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetSystemErrorControl)(THIS_ PULONG OutputLevel,PULONG BreakLevel) PURE;
    STDMETHOD(SetSystemErrorControl)(THIS_ ULONG OutputLevel,ULONG BreakLevel) PURE;
    STDMETHOD(GetTextMacro)(THIS_ ULONG Slot,PSTR Buffer,ULONG BufferSize,PULONG MacroSize) PURE;
    STDMETHOD(SetTextMacro)(THIS_ ULONG Slot,PCSTR Macro) PURE;
    STDMETHOD(GetRadix)(THIS_ PULONG Radix) PURE;
    STDMETHOD(SetRadix)(THIS_ ULONG Radix) PURE;
    STDMETHOD(Evaluate)(THIS_ PCSTR Expression,ULONG DesiredType,PDEBUG_VALUE Value,PULONG RemainderIndex) PURE;
    STDMETHOD(CoerceValue)(THIS_ PDEBUG_VALUE In,ULONG OutType,PDEBUG_VALUE Out) PURE;
    STDMETHOD(CoerceValues)(THIS_ ULONG Count,PDEBUG_VALUE In,PULONG OutTypes,PDEBUG_VALUE Out) PURE;
    STDMETHOD(Execute)(THIS_ ULONG OutputControl,PCSTR Command,ULONG Flags) PURE;
    STDMETHOD(ExecuteCommandFile)(THIS_ ULONG OutputControl,PCSTR CommandFile,ULONG Flags) PURE;
    STDMETHOD(GetNumberBreakpoints)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetBreakpointByIndex)(THIS_ ULONG Index,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointById)(THIS_ ULONG Id,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(GetBreakpointParameters)(THIS_ ULONG Count,PULONG Ids,ULONG Start,PDEBUG_BREAKPOINT_PARAMETERS Params) PURE;
    STDMETHOD(AddBreakpoint)(THIS_ ULONG Type,ULONG DesiredId,PDEBUG_BREAKPOINT *Bp) PURE;
    STDMETHOD(RemoveBreakpoint)(THIS_ PDEBUG_BREAKPOINT Bp) PURE;
    STDMETHOD(AddExtension)(THIS_ PCSTR Path,ULONG Flags,PULONG64 Handle) PURE;
    STDMETHOD(RemoveExtension)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(GetExtensionByPath)(THIS_ PCSTR Path,PULONG64 Handle) PURE;
    STDMETHOD(CallExtension)(THIS_ ULONG64 Handle,PCSTR Function,PCSTR Arguments) PURE;
    STDMETHOD(GetExtensionFunction)(THIS_ ULONG64 Handle,PCSTR FuncName,FARPROC *Function) PURE;
    STDMETHOD(GetWindbgExtensionApis32)(THIS_ PWINDBG_EXTENSION_APIS32 Api) PURE;
    STDMETHOD(GetWindbgExtensionApis64)(THIS_ PWINDBG_EXTENSION_APIS64 Api) PURE;
    STDMETHOD(GetNumberEventFilters)(THIS_ PULONG SpecificEvents,PULONG SpecificExceptions,PULONG ArbitraryExceptions) PURE;
    STDMETHOD(GetEventFilterText)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG TextSize) PURE;
    STDMETHOD(GetEventFilterCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetEventFilterCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(GetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetSpecificFilterParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SPECIFIC_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetSpecificFilterArgument)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG ArgumentSize) PURE;
    STDMETHOD(SetSpecificFilterArgument)(THIS_ ULONG Index,PCSTR Argument) PURE;
    STDMETHOD(GetExceptionFilterParameters)(THIS_ ULONG Count,PULONG Codes,ULONG Start,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(SetExceptionFilterParameters)(THIS_ ULONG Count,PDEBUG_EXCEPTION_FILTER_PARAMETERS Params) PURE;
    STDMETHOD(GetExceptionFilterSecondCommand)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG CommandSize) PURE;
    STDMETHOD(SetExceptionFilterSecondCommand)(THIS_ ULONG Index,PCSTR Command) PURE;
    STDMETHOD(WaitForEvent)(THIS_ ULONG Flags,ULONG Timeout) PURE;
    STDMETHOD(GetLastEventInformation)(THIS_ PULONG Type,PULONG ProcessId,PULONG ThreadId,PVOID ExtraInformation,ULONG ExtraInformationSize,PULONG ExtraInformationUsed,PSTR Description,ULONG DescriptionSize,PULONG DescriptionUsed) PURE;
    STDMETHOD(GetCurrentTimeDate)(THIS_ PULONG TimeDate) PURE;
    STDMETHOD(GetCurrentSystemUpTime)(THIS_ PULONG UpTime) PURE;
    STDMETHOD(GetDumpFormatFlags)(THIS_ PULONG FormatFlags) PURE;
    STDMETHOD(GetNumberTextReplacements)(THIS_ PULONG NumRepl) PURE;
    STDMETHOD(GetTextReplacement)(THIS_ PCSTR SrcText,ULONG Index,PSTR SrcBuffer,ULONG SrcBufferSize,PULONG SrcSize,PSTR DstBuffer,ULONG DstBufferSize,PULONG DstSize) PURE;
    STDMETHOD(SetTextReplacement)(THIS_ PCSTR SrcText,PCSTR DstText) PURE;
    STDMETHOD(RemoveTextReplacements)(THIS) PURE;
    STDMETHOD(OutputTextReplacements)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
    STDMETHOD(GetAssemblyOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddAssemblyOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveAssemblyOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetAssemblyOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetExpressionSyntax)(THIS_ PULONG Flags) PURE;
    STDMETHOD(SetExpressionSyntax)(THIS_ ULONG Flags) PURE;
    STDMETHOD(SetExpressionSyntaxByName)(THIS_ PCSTR AbbrevName) PURE;
    STDMETHOD(GetNumberExpressionSyntaxes)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetExpressionSyntaxNames)(THIS_ ULONG Index,PSTR FullNameBuffer,ULONG FullNameBufferSize,PULONG FullNameSize,PSTR AbbrevNameBuffer,ULONG AbbrevNameBufferSize,PULONG AbbrevNameSize) PURE;
    STDMETHOD(GetNumberEvents)(THIS_ PULONG Events) PURE;
    STDMETHOD(GetEventIndexDescription)(THIS_ ULONG Index,ULONG Which,PSTR Buffer,ULONG BufferSize,PULONG DescSize) PURE;
    STDMETHOD(GetCurrentEventIndex)(THIS_ PULONG Index) PURE;
    STDMETHOD(SetNextEventIndex)(THIS_ ULONG Relation,ULONG Value,PULONG NextIndex) PURE;
  };

#define DEBUG_DATA_SPACE_VIRTUAL 0
#define DEBUG_DATA_SPACE_PHYSICAL 1
#define DEBUG_DATA_SPACE_CONTROL 2
#define DEBUG_DATA_SPACE_IO 3
#define DEBUG_DATA_SPACE_MSR 4
#define DEBUG_DATA_SPACE_BUS_DATA 5
#define DEBUG_DATA_SPACE_DEBUGGER_DATA 6
#define DEBUG_DATA_SPACE_COUNT 7

#define DEBUG_DATA_KernBase 24
#define DEBUG_DATA_BreakpointWithStatusAddr 32
#define DEBUG_DATA_SavedContextAddr 40
#define DEBUG_DATA_KiCallUserModeAddr 56
#define DEBUG_DATA_KeUserCallbackDispatcherAddr 64
#define DEBUG_DATA_PsLoadedModuleListAddr 72
#define DEBUG_DATA_PsActiveProcessHeadAddr 80
#define DEBUG_DATA_PspCidTableAddr 88
#define DEBUG_DATA_ExpSystemResourcesListAddr 96
#define DEBUG_DATA_ExpPagedPoolDescriptorAddr 104
#define DEBUG_DATA_ExpNumberOfPagedPoolsAddr 112
#define DEBUG_DATA_KeTimeIncrementAddr 120
#define DEBUG_DATA_KeBugCheckCallbackListHeadAddr 128
#define DEBUG_DATA_KiBugcheckDataAddr 136
#define DEBUG_DATA_IopErrorLogListHeadAddr 144
#define DEBUG_DATA_ObpRootDirectoryObjectAddr 152
#define DEBUG_DATA_ObpTypeObjectTypeAddr 160
#define DEBUG_DATA_MmSystemCacheStartAddr 168
#define DEBUG_DATA_MmSystemCacheEndAddr 176
#define DEBUG_DATA_MmSystemCacheWsAddr 184
#define DEBUG_DATA_MmPfnDatabaseAddr 192
#define DEBUG_DATA_MmSystemPtesStartAddr 200
#define DEBUG_DATA_MmSystemPtesEndAddr 208
#define DEBUG_DATA_MmSubsectionBaseAddr 216
#define DEBUG_DATA_MmNumberOfPagingFilesAddr 224
#define DEBUG_DATA_MmLowestPhysicalPageAddr 232
#define DEBUG_DATA_MmHighestPhysicalPageAddr 240
#define DEBUG_DATA_MmNumberOfPhysicalPagesAddr 248
#define DEBUG_DATA_MmMaximumNonPagedPoolInBytesAddr 256
#define DEBUG_DATA_MmNonPagedSystemStartAddr 264
#define DEBUG_DATA_MmNonPagedPoolStartAddr 272
#define DEBUG_DATA_MmNonPagedPoolEndAddr 280
#define DEBUG_DATA_MmPagedPoolStartAddr 288
#define DEBUG_DATA_MmPagedPoolEndAddr 296
#define DEBUG_DATA_MmPagedPoolInformationAddr 304
#define DEBUG_DATA_MmPageSize 312
#define DEBUG_DATA_MmSizeOfPagedPoolInBytesAddr 320
#define DEBUG_DATA_MmTotalCommitLimitAddr 328
#define DEBUG_DATA_MmTotalCommittedPagesAddr 336
#define DEBUG_DATA_MmSharedCommitAddr 344
#define DEBUG_DATA_MmDriverCommitAddr 352
#define DEBUG_DATA_MmProcessCommitAddr 360
#define DEBUG_DATA_MmPagedPoolCommitAddr 368
#define DEBUG_DATA_MmExtendedCommitAddr 376
#define DEBUG_DATA_MmZeroedPageListHeadAddr 384
#define DEBUG_DATA_MmFreePageListHeadAddr 392
#define DEBUG_DATA_MmStandbyPageListHeadAddr 400
#define DEBUG_DATA_MmModifiedPageListHeadAddr 408
#define DEBUG_DATA_MmModifiedNoWritePageListHeadAddr 416
#define DEBUG_DATA_MmAvailablePagesAddr 424
#define DEBUG_DATA_MmResidentAvailablePagesAddr 432
#define DEBUG_DATA_PoolTrackTableAddr 440
#define DEBUG_DATA_NonPagedPoolDescriptorAddr 448
#define DEBUG_DATA_MmHighestUserAddressAddr 456
#define DEBUG_DATA_MmSystemRangeStartAddr 464
#define DEBUG_DATA_MmUserProbeAddressAddr 472
#define DEBUG_DATA_KdPrintCircularBufferAddr 480
#define DEBUG_DATA_KdPrintCircularBufferEndAddr 488
#define DEBUG_DATA_KdPrintWritePointerAddr 496
#define DEBUG_DATA_KdPrintRolloverCountAddr 504
#define DEBUG_DATA_MmLoadedUserImageListAddr 512
#define DEBUG_DATA_NtBuildLabAddr 520
#define DEBUG_DATA_KiNormalSystemCall 528
#define DEBUG_DATA_KiProcessorBlockAddr 536
#define DEBUG_DATA_MmUnloadedDriversAddr 544
#define DEBUG_DATA_MmLastUnloadedDriverAddr 552
#define DEBUG_DATA_MmTriageActionTakenAddr 560
#define DEBUG_DATA_MmSpecialPoolTagAddr 568
#define DEBUG_DATA_KernelVerifierAddr 576
#define DEBUG_DATA_MmVerifierDataAddr 584
#define DEBUG_DATA_MmAllocatedNonPagedPoolAddr 592
#define DEBUG_DATA_MmPeakCommitmentAddr 600
#define DEBUG_DATA_MmTotalCommitLimitMaximumAddr 608
#define DEBUG_DATA_CmNtCSDVersionAddr 616
#define DEBUG_DATA_MmPhysicalMemoryBlockAddr 624
#define DEBUG_DATA_MmSessionBase 632
#define DEBUG_DATA_MmSessionSize 640
#define DEBUG_DATA_MmSystemParentTablePage 648
#define DEBUG_DATA_MmVirtualTranslationBase 656
#define DEBUG_DATA_OffsetKThreadNextProcessor 664
#define DEBUG_DATA_OffsetKThreadTeb 666
#define DEBUG_DATA_OffsetKThreadKernelStack 668
#define DEBUG_DATA_OffsetKThreadInitialStack 670
#define DEBUG_DATA_OffsetKThreadApcProcess 672
#define DEBUG_DATA_OffsetKThreadState 674
#define DEBUG_DATA_OffsetKThreadBStore 676
#define DEBUG_DATA_OffsetKThreadBStoreLimit 678
#define DEBUG_DATA_SizeEProcess 680
#define DEBUG_DATA_OffsetEprocessPeb 682
#define DEBUG_DATA_OffsetEprocessParentCID 684
#define DEBUG_DATA_OffsetEprocessDirectoryTableBase 686
#define DEBUG_DATA_SizePrcb 688
#define DEBUG_DATA_OffsetPrcbDpcRoutine 690
#define DEBUG_DATA_OffsetPrcbCurrentThread 692
#define DEBUG_DATA_OffsetPrcbMhz 694
#define DEBUG_DATA_OffsetPrcbCpuType 696
#define DEBUG_DATA_OffsetPrcbVendorString 698
#define DEBUG_DATA_OffsetPrcbProcessorState 700
#define DEBUG_DATA_OffsetPrcbNumber 702
#define DEBUG_DATA_SizeEThread 704
#define DEBUG_DATA_KdPrintCircularBufferPtrAddr 712
#define DEBUG_DATA_KdPrintBufferSizeAddr 720

#define DEBUG_DATA_PaeEnabled 100000
#define DEBUG_DATA_SharedUserData 100008
#define DEBUG_DATA_ProductType 100016
#define DEBUG_DATA_SuiteMask 100024

  typedef struct _DEBUG_PROCESSOR_IDENTIFICATION_ALPHA {
    ULONG Type;
    ULONG Revision;
  } DEBUG_PROCESSOR_IDENTIFICATION_ALPHA,*PDEBUG_PROCESSOR_IDENTIFICATION_ALPHA;

  typedef struct _DEBUG_PROCESSOR_IDENTIFICATION_AMD64 {
    ULONG Family;
    ULONG Model;
    ULONG Stepping;
    CHAR VendorString[16];
  } DEBUG_PROCESSOR_IDENTIFICATION_AMD64,*PDEBUG_PROCESSOR_IDENTIFICATION_AMD64;

  typedef struct _DEBUG_PROCESSOR_IDENTIFICATION_IA64 {
    ULONG Model;
    ULONG Revision;
    ULONG Family;
    ULONG ArchRev;
    CHAR VendorString[16];
  } DEBUG_PROCESSOR_IDENTIFICATION_IA64,*PDEBUG_PROCESSOR_IDENTIFICATION_IA64;

  typedef struct _DEBUG_PROCESSOR_IDENTIFICATION_X86 {
    ULONG Family;
    ULONG Model;
    ULONG Stepping;
    CHAR VendorString[16];
  } DEBUG_PROCESSOR_IDENTIFICATION_X86,*PDEBUG_PROCESSOR_IDENTIFICATION_X86;

  typedef struct _DEBUG_PROCESSOR_IDENTIFICATION_ARM {
    ULONG Type;
    ULONG Revision;
  } DEBUG_PROCESSOR_IDENTIFICATION_ARM,*PDEBUG_PROCESSOR_IDENTIFICATION_ARM;

  typedef union _DEBUG_PROCESSOR_IDENTIFICATION_ALL {
    DEBUG_PROCESSOR_IDENTIFICATION_ALPHA Alpha;
    DEBUG_PROCESSOR_IDENTIFICATION_AMD64 Amd64;
    DEBUG_PROCESSOR_IDENTIFICATION_IA64 Ia64;
    DEBUG_PROCESSOR_IDENTIFICATION_X86 X86;
    DEBUG_PROCESSOR_IDENTIFICATION_ARM Arm;
  } DEBUG_PROCESSOR_IDENTIFICATION_ALL,*PDEBUG_PROCESSOR_IDENTIFICATION_ALL;

#define DEBUG_DATA_KPCR_OFFSET 0
#define DEBUG_DATA_KPRCB_OFFSET 1
#define DEBUG_DATA_KTHREAD_OFFSET 2
#define DEBUG_DATA_BASE_TRANSLATION_VIRTUAL_OFFSET 3
#define DEBUG_DATA_PROCESSOR_IDENTIFICATION 4
#define DEBUG_DATA_PROCESSOR_SPEED 5

#undef INTERFACE
#define INTERFACE IDebugDataSpaces
  DECLARE_INTERFACE_(IDebugDataSpaces,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(ReadVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(SearchVirtual)(THIS_ ULONG64 Offset,ULONG64 Length,PVOID Pattern,ULONG PatternSize,ULONG PatternGranularity,PULONG64 MatchOffset) PURE;
    STDMETHOD(ReadVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadPointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(WritePointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(ReadPhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WritePhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadMsr)(THIS_ ULONG Msr,PULONG64 Value) PURE;
    STDMETHOD(WriteMsr)(THIS_ ULONG Msr,ULONG64 Value) PURE;
    STDMETHOD(ReadBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(CheckLowMemory)(THIS) PURE;
    STDMETHOD(ReadDebuggerData)(THIS_ ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(ReadProcessorSystemData)(THIS_ ULONG Processor,ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
  };

#define DEBUG_HANDLE_DATA_TYPE_BASIC 0
#define DEBUG_HANDLE_DATA_TYPE_TYPE_NAME 1
#define DEBUG_HANDLE_DATA_TYPE_OBJECT_NAME 2
#define DEBUG_HANDLE_DATA_TYPE_HANDLE_COUNT 3
#define DEBUG_HANDLE_DATA_TYPE_TYPE_NAME_WIDE 4
#define DEBUG_HANDLE_DATA_TYPE_OBJECT_NAME_WIDE 5

  typedef struct _DEBUG_HANDLE_DATA_BASIC {
    ULONG TypeNameSize;
    ULONG ObjectNameSize;
    ULONG Attributes;
    ULONG GrantedAccess;
    ULONG HandleCount;
    ULONG PointerCount;
  } DEBUG_HANDLE_DATA_BASIC,*PDEBUG_HANDLE_DATA_BASIC;

#undef INTERFACE
#define INTERFACE IDebugDataSpaces2
  DECLARE_INTERFACE_(IDebugDataSpaces2,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(ReadVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(SearchVirtual)(THIS_ ULONG64 Offset,ULONG64 Length,PVOID Pattern,ULONG PatternSize,ULONG PatternGranularity,PULONG64 MatchOffset) PURE;
    STDMETHOD(ReadVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadPointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(WritePointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(ReadPhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WritePhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadMsr)(THIS_ ULONG Msr,PULONG64 Value) PURE;
    STDMETHOD(WriteMsr)(THIS_ ULONG Msr,ULONG64 Value) PURE;
    STDMETHOD(ReadBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(CheckLowMemory)(THIS) PURE;
    STDMETHOD(ReadDebuggerData)(THIS_ ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(ReadProcessorSystemData)(THIS_ ULONG Processor,ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(VirtualToPhysical)(THIS_ ULONG64 Virtual,PULONG64 Physical) PURE;
    STDMETHOD(GetVirtualTranslationPhysicalOffsets)(THIS_ ULONG64 Virtual,PULONG64 Offsets,ULONG OffsetsSize,PULONG Levels) PURE;
    STDMETHOD(ReadHandleData)(THIS_ ULONG64 Handle,ULONG DataType,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(FillVirtual)(THIS_ ULONG64 Start,ULONG Size,PVOID Pattern,ULONG PatternSize,PULONG Filled) PURE;
    STDMETHOD(FillPhysical)(THIS_ ULONG64 Start,ULONG Size,PVOID Pattern,ULONG PatternSize,PULONG Filled) PURE;
    STDMETHOD(QueryVirtual)(THIS_ ULONG64 Offset,PMEMORY_BASIC_INFORMATION64 Info) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugDataSpaces3
  DECLARE_INTERFACE_(IDebugDataSpaces3,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(ReadVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtual)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(SearchVirtual)(THIS_ ULONG64 Offset,ULONG64 Length,PVOID Pattern,ULONG PatternSize,ULONG PatternGranularity,PULONG64 MatchOffset) PURE;
    STDMETHOD(ReadVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteVirtualUncached)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadPointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(WritePointersVirtual)(THIS_ ULONG Count,ULONG64 Offset,PULONG64 Ptrs) PURE;
    STDMETHOD(ReadPhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WritePhysical)(THIS_ ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteControl)(THIS_ ULONG Processor,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteIo)(THIS_ ULONG InterfaceType,ULONG BusNumber,ULONG AddressSpace,ULONG64 Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(ReadMsr)(THIS_ ULONG Msr,PULONG64 Value) PURE;
    STDMETHOD(WriteMsr)(THIS_ ULONG Msr,ULONG64 Value) PURE;
    STDMETHOD(ReadBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteBusData)(THIS_ ULONG BusDataType,ULONG BusNumber,ULONG SlotNumber,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(CheckLowMemory)(THIS) PURE;
    STDMETHOD(ReadDebuggerData)(THIS_
      ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(ReadProcessorSystemData)(THIS_ ULONG Processor,ULONG Index,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(VirtualToPhysical)(THIS_ ULONG64 Virtual,PULONG64 Physical) PURE;
    STDMETHOD(GetVirtualTranslationPhysicalOffsets)(THIS_ ULONG64 Virtual,PULONG64 Offsets,ULONG OffsetsSize,PULONG Levels) PURE;
    STDMETHOD(ReadHandleData)(THIS_ ULONG64 Handle,ULONG DataType,PVOID Buffer,ULONG BufferSize,PULONG DataSize) PURE;
    STDMETHOD(FillVirtual)(THIS_ ULONG64 Start,ULONG Size,PVOID Pattern,ULONG PatternSize,PULONG Filled) PURE;
    STDMETHOD(FillPhysical)(THIS_ ULONG64 Start,ULONG Size,PVOID Pattern,ULONG PatternSize,PULONG Filled) PURE;
    STDMETHOD(QueryVirtual)(THIS_ ULONG64 Offset,PMEMORY_BASIC_INFORMATION64 Info) PURE;
    STDMETHOD(ReadImageNtHeaders)(THIS_ ULONG64 ImageBase,PIMAGE_NT_HEADERS64 Headers) PURE;
    STDMETHOD(ReadTagged)(THIS_ LPGUID Tag,ULONG Offset,PVOID Buffer,ULONG BufferSize,PULONG TotalSize) PURE;
    STDMETHOD(StartEnumTagged)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetNextTagged)(THIS_ ULONG64 Handle,LPGUID Tag,PULONG Size) PURE;
    STDMETHOD(EndEnumTagged)(THIS_ ULONG64 Handle) PURE;
  };

#define DEBUG_EVENT_BREAKPOINT 0x00000001
#define DEBUG_EVENT_EXCEPTION 0x00000002
#define DEBUG_EVENT_CREATE_THREAD 0x00000004
#define DEBUG_EVENT_EXIT_THREAD 0x00000008
#define DEBUG_EVENT_CREATE_PROCESS 0x00000010
#define DEBUG_EVENT_EXIT_PROCESS 0x00000020
#define DEBUG_EVENT_LOAD_MODULE 0x00000040
#define DEBUG_EVENT_UNLOAD_MODULE 0x00000080
#define DEBUG_EVENT_SYSTEM_ERROR 0x00000100
#define DEBUG_EVENT_SESSION_STATUS 0x00000200
#define DEBUG_EVENT_CHANGE_DEBUGGEE_STATE 0x00000400
#define DEBUG_EVENT_CHANGE_ENGINE_STATE 0x00000800
#define DEBUG_EVENT_CHANGE_SYMBOL_STATE 0x00001000

#define DEBUG_SESSION_ACTIVE 0x00000000

#define DEBUG_SESSION_END_SESSION_ACTIVE_TERMINATE 0x00000001
#define DEBUG_SESSION_END_SESSION_ACTIVE_DETACH 0x00000002
#define DEBUG_SESSION_END_SESSION_PASSIVE 0x00000003
#define DEBUG_SESSION_END 0x00000004
#define DEBUG_SESSION_REBOOT 0x00000005
#define DEBUG_SESSION_HIBERNATE 0x00000006
#define DEBUG_SESSION_FAILURE 0x00000007

#define DEBUG_CDS_ALL 0xffffffff

#define DEBUG_CDS_REGISTERS 0x00000001
#define DEBUG_CDS_DATA 0x00000002

#define DEBUG_CES_ALL 0xffffffff

#define DEBUG_CES_CURRENT_THREAD 0x00000001
#define DEBUG_CES_EFFECTIVE_PROCESSOR 0x00000002
#define DEBUG_CES_BREAKPOINTS 0x00000004
#define DEBUG_CES_CODE_LEVEL 0x00000008
#define DEBUG_CES_EXECUTION_STATUS 0x00000010
#define DEBUG_CES_ENGINE_OPTIONS 0x00000020
#define DEBUG_CES_LOG_FILE 0x00000040
#define DEBUG_CES_RADIX 0x00000080
#define DEBUG_CES_EVENT_FILTERS 0x00000100
#define DEBUG_CES_PROCESS_OPTIONS 0x00000200
#define DEBUG_CES_EXTENSIONS 0x00000400
#define DEBUG_CES_SYSTEMS 0x00000800
#define DEBUG_CES_ASSEMBLY_OPTIONS 0x00001000
#define DEBUG_CES_EXPRESSION_SYNTAX 0x00002000
#define DEBUG_CES_TEXT_REPLACEMENTS 0x00004000

#define DEBUG_CSS_ALL 0xffffffff

#define DEBUG_CSS_LOADS 0x00000001
#define DEBUG_CSS_UNLOADS 0x00000002
#define DEBUG_CSS_SCOPE 0x00000004
#define DEBUG_CSS_PATHS 0x00000008
#define DEBUG_CSS_SYMBOL_OPTIONS 0x00000010
#define DEBUG_CSS_TYPE_OPTIONS 0x00000020

#undef INTERFACE
#define INTERFACE IDebugEventCallbacks
  DECLARE_INTERFACE_(IDebugEventCallbacks,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetInterestMask)(THIS_ PULONG Mask) PURE;
    STDMETHOD(Breakpoint)(THIS_ PDEBUG_BREAKPOINT Bp) PURE;
    STDMETHOD(Exception)(THIS_ PEXCEPTION_RECORD64 Exception,ULONG FirstChance) PURE;
    STDMETHOD(CreateThread)(THIS_ ULONG64 Handle,ULONG64 DataOffset,ULONG64 StartOffset) PURE;
    STDMETHOD(ExitThread)(THIS_ ULONG ExitCode) PURE;
    STDMETHOD(CreateProcess)(THIS_ ULONG64 ImageFileHandle,ULONG64 Handle,ULONG64 BaseOffset,ULONG ModuleSize,PCSTR ModuleName,PCSTR ImageName,ULONG CheckSum,ULONG TimeDateStamp,ULONG64 InitialThreadHandle,ULONG64 ThreadDataOffset,ULONG64 StartOffset) PURE;
    STDMETHOD(ExitProcess)(THIS_ ULONG ExitCode) PURE;
    STDMETHOD(LoadModule)(THIS_ ULONG64 ImageFileHandle,ULONG64 BaseOffset,ULONG ModuleSize,PCSTR ModuleName,PCSTR ImageName,ULONG CheckSum,ULONG TimeDateStamp) PURE;
    STDMETHOD(UnloadModule)(THIS_ PCSTR ImageBaseName,ULONG64 BaseOffset) PURE;
    STDMETHOD(SystemError)(THIS_ ULONG Error,ULONG Level) PURE;
    STDMETHOD(SessionStatus)(THIS_ ULONG Status) PURE;
    STDMETHOD(ChangeDebuggeeState)(THIS_ ULONG Flags,ULONG64 Argument) PURE;
    STDMETHOD(ChangeEngineState)(THIS_ ULONG Flags,ULONG64 Argument) PURE;
    STDMETHOD(ChangeSymbolState)(THIS_ ULONG Flags,ULONG64 Argument) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugInputCallbacks
  DECLARE_INTERFACE_(IDebugInputCallbacks,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(StartInput)(THIS_ ULONG BufferSize) PURE;
    STDMETHOD(EndInput)(THIS) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugOutputCallbacks
  DECLARE_INTERFACE_(IDebugOutputCallbacks,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(Output)(THIS_ ULONG Mask,PCSTR Text) PURE;
  };

#define DEBUG_REGISTER_SUB_REGISTER 0x00000001

#define DEBUG_REGISTERS_DEFAULT 0x00000000
#define DEBUG_REGISTERS_INT32 0x00000001
#define DEBUG_REGISTERS_INT64 0x00000002
#define DEBUG_REGISTERS_FLOAT 0x00000004
#define DEBUG_REGISTERS_ALL 0x00000007

  typedef struct _DEBUG_REGISTER_DESCRIPTION {
    ULONG Type;
    ULONG Flags;
    ULONG SubregMaster;
    ULONG SubregLength;
    ULONG64 SubregMask;
    ULONG SubregShift;
    ULONG Reserved0;
  } DEBUG_REGISTER_DESCRIPTION,*PDEBUG_REGISTER_DESCRIPTION;

#undef INTERFACE
#define INTERFACE IDebugRegisters
  DECLARE_INTERFACE_(IDebugRegisters,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetNumberRegisters)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetDescription)(THIS_ ULONG Register,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize,PDEBUG_REGISTER_DESCRIPTION Desc) PURE;
    STDMETHOD(GetIndexByName)(THIS_ PCSTR Name,PULONG Index) PURE;
    STDMETHOD(GetValue)(THIS_ ULONG Register,PDEBUG_VALUE Value) PURE;
    STDMETHOD(SetValue)(THIS_ ULONG Register,PDEBUG_VALUE Value) PURE;
    STDMETHOD(GetValues)(THIS_ ULONG Count,PULONG Indices,ULONG Start,PDEBUG_VALUE Values) PURE;
    STDMETHOD(SetValues)(THIS_ ULONG Count,PULONG Indices,ULONG Start,PDEBUG_VALUE Values) PURE;
    STDMETHOD(OutputRegisters)(THIS_ ULONG OutputControl,ULONG Flags) PURE;
    STDMETHOD(GetInstructionOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetStackOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetFrameOffset)(THIS_ PULONG64 Offset) PURE;
  };

#define DEBUG_OUTPUT_SYMBOLS_DEFAULT 0x00000000
#define DEBUG_OUTPUT_SYMBOLS_NO_NAMES 0x00000001
#define DEBUG_OUTPUT_SYMBOLS_NO_OFFSETS 0x00000002
#define DEBUG_OUTPUT_SYMBOLS_NO_VALUES 0x00000004
#define DEBUG_OUTPUT_SYMBOLS_NO_TYPES 0x00000010

#define DEBUG_OUTPUT_NAME_END "**NAME**"
#define DEBUG_OUTPUT_OFFSET_END "**OFF**"
#define DEBUG_OUTPUT_VALUE_END "**VALUE**"
#define DEBUG_OUTPUT_TYPE_END "**TYPE**"

#define DEBUG_SYMBOL_EXPANSION_LEVEL_MASK 0x0000000f
#define DEBUG_SYMBOL_EXPANDED 0x00000010
#define DEBUG_SYMBOL_READ_ONLY 0x00000020
#define DEBUG_SYMBOL_IS_ARRAY 0x00000040
#define DEBUG_SYMBOL_IS_FLOAT 0x00000080
#define DEBUG_SYMBOL_IS_ARGUMENT 0x00000100
#define DEBUG_SYMBOL_IS_LOCAL 0x00000200

  typedef struct _DEBUG_SYMBOL_PARAMETERS {
    ULONG64 Module;
    ULONG TypeId;
    ULONG ParentSymbol;
    ULONG SubElements;
    ULONG Flags;
    ULONG64 Reserved;
  } DEBUG_SYMBOL_PARAMETERS,*PDEBUG_SYMBOL_PARAMETERS;

#undef INTERFACE
#define INTERFACE IDebugSymbolGroup
  DECLARE_INTERFACE_(IDebugSymbolGroup,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetNumberSymbols)(THIS_ PULONG Number) PURE;
    STDMETHOD(AddSymbol)(THIS_ PCSTR Name,PULONG Index) PURE;
    STDMETHOD(RemoveSymbolByName)(THIS_ PCSTR Name) PURE;
    STDMETHOD(RemoveSymbolByIndex)(THIS_ ULONG Index) PURE;
    STDMETHOD(GetSymbolName)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetSymbolParameters)(THIS_ ULONG Start,ULONG Count,PDEBUG_SYMBOL_PARAMETERS Params) PURE;
    STDMETHOD(ExpandSymbol)(THIS_ ULONG Index,WINBOOL Expand) PURE;
    STDMETHOD(OutputSymbols)(THIS_ ULONG OutputControl,ULONG Flags,ULONG Start,ULONG Count) PURE;
    STDMETHOD(WriteSymbol)(THIS_ ULONG Index,PCSTR Value) PURE;
    STDMETHOD(OutputAsType)(THIS_ ULONG Index,PCSTR Type) PURE;
  };

#define DEBUG_MODULE_LOADED 0x00000000
#define DEBUG_MODULE_UNLOADED 0x00000001
#define DEBUG_MODULE_USER_MODE 0x00000002
#define DEBUG_MODULE_SYM_BAD_CHECKSUM 0x00010000

#define DEBUG_SYMTYPE_NONE 0
#define DEBUG_SYMTYPE_COFF 1
#define DEBUG_SYMTYPE_CODEVIEW 2
#define DEBUG_SYMTYPE_PDB 3
#define DEBUG_SYMTYPE_EXPORT 4
#define DEBUG_SYMTYPE_DEFERRED 5
#define DEBUG_SYMTYPE_SYM 6
#define DEBUG_SYMTYPE_DIA 7

  typedef struct _DEBUG_MODULE_PARAMETERS {
    ULONG64 Base;
    ULONG Size;
    ULONG TimeDateStamp;
    ULONG Checksum;
    ULONG Flags;
    ULONG SymbolType;
    ULONG ImageNameSize;
    ULONG ModuleNameSize;
    ULONG LoadedImageNameSize;
    ULONG SymbolFileNameSize;
    ULONG MappedImageNameSize;
    ULONG64 Reserved[2];
  } DEBUG_MODULE_PARAMETERS,*PDEBUG_MODULE_PARAMETERS;

#define DEBUG_SCOPE_GROUP_ARGUMENTS 0x00000001
#define DEBUG_SCOPE_GROUP_LOCALS 0x00000002
#define DEBUG_SCOPE_GROUP_ALL 0x00000003

#define DEBUG_OUTTYPE_DEFAULT 0x00000000
#define DEBUG_OUTTYPE_NO_INDENT 0x00000001
#define DEBUG_OUTTYPE_NO_OFFSET 0x00000002
#define DEBUG_OUTTYPE_VERBOSE 0x00000004
#define DEBUG_OUTTYPE_COMPACT_OUTPUT 0x00000008
#define DEBUG_OUTTYPE_RECURSION_LEVEL(Max) (((Max) & 0xf) << 4)
#define DEBUG_OUTTYPE_ADDRESS_OF_FIELD 0x00010000
#define DEBUG_OUTTYPE_ADDRESS_AT_END 0x00020000
#define DEBUG_OUTTYPE_BLOCK_RECURSE 0x00200000

#define DEBUG_FIND_SOURCE_DEFAULT 0x00000000
#define DEBUG_FIND_SOURCE_FULL_PATH 0x00000001
#define DEBUG_FIND_SOURCE_BEST_MATCH 0x00000002

#define DEBUG_INVALID_OFFSET ((ULONG64)-1)

#undef INTERFACE
#define INTERFACE IDebugSymbols
  DECLARE_INTERFACE_(IDebugSymbols,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetSymbolOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetNameByOffset)(THIS_ ULONG64 Offset,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetOffsetByName)(THIS_ PCSTR Symbol,PULONG64 Offset) PURE;
    STDMETHOD(GetNearNameByOffset)(THIS_ ULONG64 Offset,LONG Delta,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetLineByOffset)(THIS_ ULONG64 Offset,PULONG Line,PSTR FileBuffer,ULONG FileBufferSize,PULONG FileSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetOffsetByLine)(THIS_ ULONG Line,PCSTR File,PULONG64 Offset) PURE;
    STDMETHOD(GetNumberModules)(THIS_ PULONG Loaded,PULONG Unloaded) PURE;
    STDMETHOD(GetModuleByIndex)(THIS_ ULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleByModuleName)(THIS_ PCSTR Name,ULONG StartIndex,PULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleByOffset)(THIS_ ULONG64 Offset,ULONG StartIndex,PULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleNames)(THIS_ ULONG Index,ULONG64 Base,PSTR ImageNameBuffer,ULONG ImageNameBufferSize,PULONG ImageNameSize,PSTR ModuleNameBuffer,ULONG ModuleNameBufferSize,PULONG ModuleNameSize,PSTR LoadedImageNameBuffer,ULONG LoadedImageNameBufferSize,PULONG LoadedImageNameSize) PURE;
    STDMETHOD(GetModuleParameters)(THIS_ ULONG Count,PULONG64 Bases,ULONG Start,PDEBUG_MODULE_PARAMETERS Params) PURE;
    STDMETHOD(GetSymbolModule)(THIS_ PCSTR Symbol,PULONG64 Base) PURE;
    STDMETHOD(GetTypeName)(THIS_ ULONG64 Module,ULONG TypeId,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetTypeId)(THIS_ ULONG64 Module,PCSTR Name,PULONG TypeId) PURE;
    STDMETHOD(GetTypeSize)(THIS_ ULONG64 Module,ULONG TypeId,PULONG Size) PURE;
    STDMETHOD(GetFieldOffset)(THIS_ ULONG64 Module,ULONG TypeId,PCSTR Field,PULONG Offset) PURE;
    STDMETHOD(GetSymbolTypeId)(THIS_ PCSTR Symbol,PULONG TypeId,PULONG64 Module) PURE;
    STDMETHOD(GetOffsetTypeId)(THIS_ ULONG64 Offset,PULONG TypeId,PULONG64 Module) PURE;
    STDMETHOD(ReadTypedDataVirtual)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteTypedDataVirtual)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(OutputTypedDataVirtual)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG64 Module,ULONG TypeId,ULONG Flags) PURE;
    STDMETHOD(ReadTypedDataPhysical)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteTypedDataPhysical)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(OutputTypedDataPhysical)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG64 Module,ULONG TypeId,ULONG Flags) PURE;
    STDMETHOD(GetScope)(THIS_ PULONG64 InstructionOffset,PDEBUG_STACK_FRAME ScopeFrame,PVOID ScopeContext,ULONG ScopeContextSize) PURE;
    STDMETHOD(SetScope)(THIS_ ULONG64 InstructionOffset,PDEBUG_STACK_FRAME ScopeFrame,PVOID ScopeContext,ULONG ScopeContextSize) PURE;
    STDMETHOD(ResetScope)(THIS) PURE;
    STDMETHOD(GetScopeSymbolGroup)(THIS_ ULONG Flags,PDEBUG_SYMBOL_GROUP Update,PDEBUG_SYMBOL_GROUP *Symbols) PURE;
    STDMETHOD(CreateSymbolGroup)(THIS_ PDEBUG_SYMBOL_GROUP *Group) PURE;
    STDMETHOD(StartSymbolMatch)(THIS_ PCSTR Pattern,PULONG64 Handle) PURE;
    STDMETHOD(GetNextSymbolMatch)(THIS_ ULONG64 Handle,PSTR Buffer,ULONG BufferSize,PULONG MatchSize,PULONG64 Offset) PURE;
    STDMETHOD(EndSymbolMatch)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(Reload)(THIS_ PCSTR Module) PURE;
    STDMETHOD(GetSymbolPath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(SetSymbolPath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendSymbolPath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(GetImagePath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(SetImagePath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendImagePath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(GetSourcePath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(GetSourcePathElement)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG ElementSize) PURE;
    STDMETHOD(SetSourcePath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendSourcePath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(FindSourceFile)(THIS_ ULONG StartElement,PCSTR File,ULONG Flags,PULONG FoundElement,PSTR Buffer,ULONG BufferSize,PULONG FoundSize) PURE;
    STDMETHOD(GetSourceFileLineOffsets)(THIS_ PCSTR File,PULONG64 Buffer,ULONG BufferLines,PULONG FileLines) PURE;
  };

#define DEBUG_MODNAME_IMAGE 0x00000000
#define DEBUG_MODNAME_MODULE 0x00000001
#define DEBUG_MODNAME_LOADED_IMAGE 0x00000002
#define DEBUG_MODNAME_SYMBOL_FILE 0x00000003
#define DEBUG_MODNAME_MAPPED_IMAGE 0x00000004

#define DEBUG_TYPEOPTS_UNICODE_DISPLAY 0x00000001
#define DEBUG_TYPEOPTS_LONGSTATUS_DISPLAY 0x00000002
#define DEBUG_TYPEOPTS_FORCERADIX_OUTPUT 0x00000004

#undef INTERFACE
#define INTERFACE IDebugSymbols2
  DECLARE_INTERFACE_(IDebugSymbols2,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetSymbolOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetSymbolOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(GetNameByOffset)(THIS_ ULONG64 Offset,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetOffsetByName)(THIS_ PCSTR Symbol,PULONG64 Offset) PURE;
    STDMETHOD(GetNearNameByOffset)(THIS_ ULONG64 Offset,LONG Delta,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetLineByOffset)(THIS_ ULONG64 Offset,PULONG Line,PSTR FileBuffer,ULONG FileBufferSize,PULONG FileSize,PULONG64 Displacement) PURE;
    STDMETHOD(GetOffsetByLine)(THIS_ ULONG Line,PCSTR File,PULONG64 Offset) PURE;
    STDMETHOD(GetNumberModules)(THIS_ PULONG Loaded,PULONG Unloaded) PURE;
    STDMETHOD(GetModuleByIndex)(THIS_ ULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleByModuleName)(THIS_ PCSTR Name,ULONG StartIndex,PULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleByOffset)(THIS_ ULONG64 Offset,ULONG StartIndex,PULONG Index,PULONG64 Base) PURE;
    STDMETHOD(GetModuleNames)(THIS_ ULONG Index,ULONG64 Base,PSTR ImageNameBuffer,ULONG ImageNameBufferSize,PULONG ImageNameSize,PSTR ModuleNameBuffer,ULONG ModuleNameBufferSize,PULONG ModuleNameSize,PSTR LoadedImageNameBuffer,ULONG LoadedImageNameBufferSize,PULONG LoadedImageNameSize) PURE;
    STDMETHOD(GetModuleParameters)(THIS_ ULONG Count,PULONG64 Bases,ULONG Start,PDEBUG_MODULE_PARAMETERS Params) PURE;
    STDMETHOD(GetSymbolModule)(THIS_ PCSTR Symbol,PULONG64 Base) PURE;
    STDMETHOD(GetTypeName)(THIS_ ULONG64 Module,ULONG TypeId,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetTypeId)(THIS_ ULONG64 Module,PCSTR Name,PULONG TypeId) PURE;
    STDMETHOD(GetTypeSize)(THIS_ ULONG64 Module,ULONG TypeId,PULONG Size) PURE;
    STDMETHOD(GetFieldOffset)(THIS_ ULONG64 Module,ULONG TypeId,PCSTR Field,PULONG Offset) PURE;
    STDMETHOD(GetSymbolTypeId)(THIS_ PCSTR Symbol,PULONG TypeId,PULONG64 Module) PURE;
    STDMETHOD(GetOffsetTypeId)(THIS_ ULONG64 Offset,PULONG TypeId,PULONG64 Module) PURE;
    STDMETHOD(ReadTypedDataVirtual)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteTypedDataVirtual)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(OutputTypedDataVirtual)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG64 Module,ULONG TypeId,ULONG Flags) PURE;
    STDMETHOD(ReadTypedDataPhysical)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesRead) PURE;
    STDMETHOD(WriteTypedDataPhysical)(THIS_ ULONG64 Offset,ULONG64 Module,ULONG TypeId,PVOID Buffer,ULONG BufferSize,PULONG BytesWritten) PURE;
    STDMETHOD(OutputTypedDataPhysical)(THIS_ ULONG OutputControl,ULONG64 Offset,ULONG64 Module,ULONG TypeId,ULONG Flags) PURE;
    STDMETHOD(GetScope)(THIS_ PULONG64 InstructionOffset,PDEBUG_STACK_FRAME ScopeFrame,PVOID ScopeContext,ULONG ScopeContextSize) PURE;
    STDMETHOD(SetScope)(THIS_ ULONG64 InstructionOffset,PDEBUG_STACK_FRAME ScopeFrame,PVOID ScopeContext,ULONG ScopeContextSize) PURE;
    STDMETHOD(ResetScope)(THIS) PURE;
    STDMETHOD(GetScopeSymbolGroup)(THIS_ ULONG Flags,PDEBUG_SYMBOL_GROUP Update,PDEBUG_SYMBOL_GROUP *Symbols) PURE;
    STDMETHOD(CreateSymbolGroup)(THIS_ PDEBUG_SYMBOL_GROUP *Group) PURE;
    STDMETHOD(StartSymbolMatch)(THIS_ PCSTR Pattern,PULONG64 Handle) PURE;
    STDMETHOD(GetNextSymbolMatch)(THIS_ ULONG64 Handle,PSTR Buffer,ULONG BufferSize,PULONG MatchSize,PULONG64 Offset) PURE;
    STDMETHOD(EndSymbolMatch)(THIS_ ULONG64 Handle) PURE;
    STDMETHOD(Reload)(THIS_ PCSTR Module) PURE;
    STDMETHOD(GetSymbolPath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(SetSymbolPath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendSymbolPath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(GetImagePath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(SetImagePath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendImagePath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(GetSourcePath)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG PathSize) PURE;
    STDMETHOD(GetSourcePathElement)(THIS_ ULONG Index,PSTR Buffer,ULONG BufferSize,PULONG ElementSize) PURE;
    STDMETHOD(SetSourcePath)(THIS_ PCSTR Path) PURE;
    STDMETHOD(AppendSourcePath)(THIS_ PCSTR Addition) PURE;
    STDMETHOD(FindSourceFile)(THIS_ ULONG StartElement,PCSTR File,ULONG Flags,PULONG FoundElement,PSTR Buffer,ULONG BufferSize,PULONG FoundSize) PURE;
    STDMETHOD(GetSourceFileLineOffsets)(THIS_ PCSTR File,PULONG64 Buffer,ULONG BufferLines,PULONG FileLines) PURE;
    STDMETHOD(GetModuleVersionInformation)(THIS_ ULONG Index,ULONG64 Base,PCSTR Item,PVOID Buffer,ULONG BufferSize,PULONG VerInfoSize) PURE;
    STDMETHOD(GetModuleNameString)(THIS_ ULONG Which,ULONG Index,ULONG64 Base,PSTR Buffer,ULONG BufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetConstantName)(THIS_ ULONG64 Module,ULONG TypeId,ULONG64 Value,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetFieldName)(THIS_ ULONG64 Module,ULONG TypeId,ULONG FieldIndex,PSTR NameBuffer,ULONG NameBufferSize,PULONG NameSize) PURE;
    STDMETHOD(GetTypeOptions)(THIS_ PULONG Options) PURE;
    STDMETHOD(AddTypeOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(RemoveTypeOptions)(THIS_ ULONG Options) PURE;
    STDMETHOD(SetTypeOptions)(THIS_ ULONG Options) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugSystemObjects
  DECLARE_INTERFACE_(IDebugSystemObjects,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetEventThread)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetEventProcess)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentThreadId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetCurrentProcessId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentProcessId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetNumberThreads)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetTotalNumberThreads)(THIS_ PULONG Total,PULONG LargestProcess) PURE;
    STDMETHOD(GetThreadIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetThreadIdByProcessor)(THIS_ ULONG Processor,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadTeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByTeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetThreadIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetThreadIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetNumberProcesses)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetProcessIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetCurrentProcessDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessPeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByPeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetProcessIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetProcessIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessExecutableName)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG ExeSize) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugSystemObjects2
  DECLARE_INTERFACE_(IDebugSystemObjects2,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetEventThread)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetEventProcess)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentThreadId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetCurrentProcessId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentProcessId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetNumberThreads)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetTotalNumberThreads)(THIS_ PULONG Total,PULONG LargestProcess) PURE;
    STDMETHOD(GetThreadIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetThreadIdByProcessor)(THIS_ ULONG Processor,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadTeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByTeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetThreadIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetThreadIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetNumberProcesses)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetProcessIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetCurrentProcessDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessPeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByPeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetProcessIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetProcessIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessExecutableName)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG ExeSize) PURE;
    STDMETHOD(GetCurrentProcessUpTime)(THIS_ PULONG UpTime) PURE;
    STDMETHOD(GetImplicitThreadDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(SetImplicitThreadDataOffset)(THIS_ ULONG64 Offset) PURE;
    STDMETHOD(GetImplicitProcessDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(SetImplicitProcessDataOffset)(THIS_ ULONG64 Offset) PURE;
  };

#undef INTERFACE
#define INTERFACE IDebugSystemObjects3
  DECLARE_INTERFACE_(IDebugSystemObjects3,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(GetEventThread)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetEventProcess)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentThreadId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetCurrentProcessId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentProcessId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetNumberThreads)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetTotalNumberThreads)(THIS_ PULONG Total,PULONG LargestProcess) PURE;
    STDMETHOD(GetThreadIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetThreadIdByProcessor)(THIS_ ULONG Processor,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadTeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetThreadIdByTeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetThreadIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentThreadHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetThreadIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetNumberProcesses)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetProcessIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids,PULONG SysIds) PURE;
    STDMETHOD(GetCurrentProcessDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByDataOffset)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessPeb)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(GetProcessIdByPeb)(THIS_ ULONG64 Offset,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessSystemId)(THIS_ PULONG SysId) PURE;
    STDMETHOD(GetProcessIdBySystemId)(THIS_ ULONG SysId,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessHandle)(THIS_ PULONG64 Handle) PURE;
    STDMETHOD(GetProcessIdByHandle)(THIS_ ULONG64 Handle,PULONG Id) PURE;
    STDMETHOD(GetCurrentProcessExecutableName)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG ExeSize) PURE;
    STDMETHOD(GetCurrentProcessUpTime)(THIS_ PULONG UpTime) PURE;
    STDMETHOD(GetImplicitThreadDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(SetImplicitThreadDataOffset)(THIS_ ULONG64 Offset) PURE;
    STDMETHOD(GetImplicitProcessDataOffset)(THIS_ PULONG64 Offset) PURE;
    STDMETHOD(SetImplicitProcessDataOffset)(THIS_ ULONG64 Offset) PURE;
    STDMETHOD(GetEventSystem)(THIS_ PULONG Id) PURE;
    STDMETHOD(GetCurrentSystemId)(THIS_ PULONG Id) PURE;
    STDMETHOD(SetCurrentSystemId)(THIS_ ULONG Id) PURE;
    STDMETHOD(GetNumberSystems)(THIS_ PULONG Number) PURE;
    STDMETHOD(GetSystemIdsByIndex)(THIS_ ULONG Start,ULONG Count,PULONG Ids) PURE;
    STDMETHOD(GetTotalNumberThreadsAndProcesses)(THIS_ PULONG TotalThreads,PULONG TotalProcesses,PULONG LargestProcessThreads,PULONG LargestSystemThreads,PULONG LargestSystemProcesses) PURE;
    STDMETHOD(GetCurrentSystemServer)(THIS_ PULONG64 Server) PURE;
    STDMETHOD(GetSystemByServer)(THIS_ ULONG64 Server,PULONG Id) PURE;
    STDMETHOD(GetCurrentSystemServerName)(THIS_ PSTR Buffer,ULONG BufferSize,PULONG NameSize) PURE;
  };

#define DEBUG_COMMAND_EXCEPTION_ID 0xdbe00dbe

#define DEBUG_CMDEX_INVALID 0x00000000
#define DEBUG_CMDEX_ADD_EVENT_STRING 0x00000001
#define DEBUG_CMDEX_RESET_EVENT_STRINGS 0x00000002

#if !defined(DEBUG_NO_IMPLEMENTATION) && !defined(__CRT__NO_INLINE)
  __CRT_INLINE void DebugCommandException(ULONG Command,ULONG ArgSize,PVOID Arg) {
    ULONG_PTR ExArgs[4];
    ExArgs[0] = DEBUG_COMMAND_EXCEPTION_ID;
    ExArgs[1] = Command;
    ExArgs[2] = ArgSize;
    ExArgs[3] = (ULONG_PTR)Arg;
    RaiseException(DBG_COMMAND_EXCEPTION,0,4,ExArgs);
  }
#endif

  typedef HRESULT (CALLBACK *PDEBUG_EXTENSION_INITIALIZE)(PULONG Version,PULONG Flags);
  typedef void (CALLBACK *PDEBUG_EXTENSION_UNINITIALIZE)(void);

#define DEBUG_NOTIFY_SESSION_ACTIVE 0x00000000
#define DEBUG_NOTIFY_SESSION_INACTIVE 0x00000001
#define DEBUG_NOTIFY_SESSION_ACCESSIBLE 0x00000002
#define DEBUG_NOTIFY_SESSION_INACCESSIBLE 0x00000003

  typedef void (CALLBACK *PDEBUG_EXTENSION_NOTIFY)(ULONG Notify,ULONG64 Argument);
  typedef HRESULT (CALLBACK *PDEBUG_EXTENSION_CALL)(PDEBUG_CLIENT Client,PCSTR Args);

#define DEBUG_EXTENSION_CONTINUE_SEARCH HRESULT_FROM_NT(0xC0000271)
#define DEBUG_EXTENSION_VERSION(Major,Minor) ((((Major) & 0xffff) << 16) | ((Minor) & 0xffff))

#ifdef __cplusplus
};

#ifndef DEBUG_NO_IMPLEMENTATION
class DebugBaseEventCallbacks : public IDebugEventCallbacks {
public:
  STDMETHOD(QueryInterface)(THIS_ REFIID InterfaceId,PVOID *Interface) {
    *Interface = NULL;
    if(IsEqualIID(InterfaceId,IID_IUnknown) || IsEqualIID(InterfaceId,IID_IDebugEventCallbacks)) {
      *Interface = (IDebugEventCallbacks *)this;
      AddRef();
      return S_OK;
    } else return E_NOINTERFACE;
  }
  STDMETHOD(Breakpoint)(THIS_ PDEBUG_BREAKPOINT Bp) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(Exception)(THIS_ PEXCEPTION_RECORD64 Exception,ULONG FirstChance) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(CreateThread)(THIS_ ULONG64 Handle,ULONG64 DataOffset,ULONG64 StartOffset) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(ExitThread)(THIS_ ULONG ExitCode) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(CreateProcess)(THIS_ ULONG64 ImageFileHandle,ULONG64 Handle,ULONG64 BaseOffset,ULONG ModuleSize,PCSTR ModuleName,PCSTR ImageName,ULONG CheckSum,ULONG TimeDateStamp,ULONG64 InitialThreadHandle,ULONG64 ThreadDataOffset,ULONG64 StartOffset) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(ExitProcess)(THIS_ ULONG ExitCode) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(LoadModule)(THIS_ ULONG64 ImageFileHandle,ULONG64 BaseOffset,ULONG ModuleSize,PCSTR ModuleName,PCSTR ImageName,ULONG CheckSum,ULONG TimeDateStamp) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(UnloadModule)(THIS_ PCSTR ImageBaseName,ULONG64 BaseOffset) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(SystemError)(THIS_ ULONG Error,ULONG Level) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(SessionStatus)(THIS_ ULONG Status) { return DEBUG_STATUS_NO_CHANGE; }
  STDMETHOD(ChangeDebuggeeState)(THIS_ ULONG Flags,ULONG64 Argument) { return S_OK; }
  STDMETHOD(ChangeEngineState)(THIS_ ULONG Flags,ULONG64 Argument) { return S_OK; }
  STDMETHOD(ChangeSymbolState)(THIS_ ULONG Flags,ULONG64 Argument) { return S_OK; }
};
#endif
#endif
#endif
