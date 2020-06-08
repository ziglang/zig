/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RPCNDR_H_VERSION__
#define __RPCNDR_H_VERSION__ (475)
#endif

#ifndef __RPCNDR_H__
#define __RPCNDR_H__

#ifdef __REQUIRED_RPCNDR_H_VERSION__
#if (475 < __REQUIRED_RPCNDR_H_VERSION__)
#error incorrect <rpcndr.h> version. Use the header that matches with the MIDL compiler.
#endif
#endif

#include <pshpack8.h>
#include <basetsd.h>
#include <rpcnsip.h>
#include <rpcsal.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NDR_CHAR_REP_MASK __MSABI_LONG(0X0000000FU)
#define NDR_INT_REP_MASK __MSABI_LONG(0X000000F0U)
#define NDR_FLOAT_REP_MASK __MSABI_LONG(0X0000FF00U)

#define NDR_LITTLE_ENDIAN __MSABI_LONG(0X00000010U)
#define NDR_BIG_ENDIAN __MSABI_LONG(0X00000000U)

#define NDR_IEEE_FLOAT __MSABI_LONG(0X00000000U)
#define NDR_VAX_FLOAT __MSABI_LONG(0X00000100U)
#define NDR_IBM_FLOAT __MSABI_LONG(0X00000300U)

#define NDR_ASCII_CHAR __MSABI_LONG(0X00000000U)
#define NDR_EBCDIC_CHAR __MSABI_LONG(0X00000001U)

#define NDR_LOCAL_DATA_REPRESENTATION __MSABI_LONG(0X00000010U)
#define NDR_LOCAL_ENDIAN NDR_LITTLE_ENDIAN

#if _WIN32_WINNT >= 0x601
#define TARGET_IS_NT61_OR_LATER 1
#else
#define TARGET_IS_NT61_OR_LATER 0
#endif
#if _WIN32_WINNT >= 0x600
#define TARGET_IS_NT60_OR_LATER 1
#else
#define TARGET_IS_NT60_OR_LATER 0
#endif
#define TARGET_IS_NT51_OR_LATER 1
#define TARGET_IS_NT50_OR_LATER 1
#define TARGET_IS_NT40_OR_LATER 1
#define TARGET_IS_NT351_OR_WIN95_OR_LATER 1

#ifdef RC_INVOKED
#define small char
#endif
  typedef unsigned char byte;
  typedef byte cs_byte;
  typedef unsigned char boolean;

#ifndef _HYPER_DEFINED
#define _HYPER_DEFINED
#define hyper /* __MINGW_EXTENSION */ __int64
#define MIDL_uhyper /* __MINGW_EXTENSION */ unsigned __int64
#endif

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
  typedef unsigned short wchar_t;
#endif

#ifndef _SIZE_T_DEFINED
#define _SIZE_T_DEFINED
#undef size_t
#ifdef _WIN64
  __MINGW_EXTENSION typedef unsigned __int64 size_t;
#else
  typedef unsigned int size_t;
#endif
#endif

#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
#undef ssize_t
#ifdef _WIN64
  __MINGW_EXTENSION typedef __int64 ssize_t;
#else
  typedef int ssize_t;
#endif
#endif

#ifdef __RPC_WIN32__
#if defined(_ARM_)
#define __RPC_CALLEE
#else
#define __RPC_CALLEE __stdcall
#endif
#endif

#ifndef __MIDL_USER_DEFINED
#define __MIDL_USER_DEFINED
#define midl_user_allocate MIDL_user_allocate
#define midl_user_free MIDL_user_free
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_USER MIDL_user_allocate(size_t);
  void __RPC_USER MIDL_user_free(void *);
#endif

#define RPC_VAR_ENTRY __cdecl

#if (defined(_X86_) && !defined(__x86_64)) || defined(__x86_64) || defined(__ia64__)
#define __MIDL_DECLSPEC_DLLIMPORT __declspec(dllimport)
#define __MIDL_DECLSPEC_DLLEXPORT __declspec(dllexport)
#else
#define __MIDL_DECLSPEC_DLLIMPORT
#define __MIDL_DECLSPEC_DLLEXPORT
#endif

  typedef void *NDR_CCONTEXT;

  typedef struct _NDR_SCONTEXT {
    void *pad[2];
    void *userContext;
  } *NDR_SCONTEXT;

#define NDRSContextValue(hContext) (&(hContext)->userContext)

#define cbNDRContext 20

  typedef void (__RPC_API *NDR_RUNDOWN)(void *context);
  typedef void (__RPC_API *NDR_NOTIFY_ROUTINE)(void);
  typedef void (__RPC_API *NDR_NOTIFY2_ROUTINE)(boolean flag);

  typedef struct _SCONTEXT_QUEUE {
    unsigned __LONG32 NumberOfObjects;
    NDR_SCONTEXT *ArrayOfObjects;
  } SCONTEXT_QUEUE,*PSCONTEXT_QUEUE;

  RPCRTAPI RPC_BINDING_HANDLE RPC_ENTRY NDRCContextBinding(NDR_CCONTEXT CContext);
  RPCRTAPI void RPC_ENTRY NDRCContextMarshall(NDR_CCONTEXT CContext,void *pBuff);
  RPCRTAPI void RPC_ENTRY NDRCContextUnmarshall(NDR_CCONTEXT *pCContext,RPC_BINDING_HANDLE hBinding,void *pBuff,unsigned __LONG32 DataRepresentation);
  RPCRTAPI void RPC_ENTRY NDRSContextMarshall(NDR_SCONTEXT CContext,void *pBuff,NDR_RUNDOWN userRunDownIn);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NDRSContextUnmarshall(void *pBuff,unsigned __LONG32 DataRepresentation);
  RPCRTAPI void RPC_ENTRY NDRSContextMarshallEx(RPC_BINDING_HANDLE BindingHandle,NDR_SCONTEXT CContext,void *pBuff,NDR_RUNDOWN userRunDownIn);
  RPCRTAPI void RPC_ENTRY NDRSContextMarshall2(RPC_BINDING_HANDLE BindingHandle,NDR_SCONTEXT CContext,void *pBuff,NDR_RUNDOWN userRunDownIn,void *CtxGuard,unsigned __LONG32 Flags);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NDRSContextUnmarshallEx(RPC_BINDING_HANDLE BindingHandle,void *pBuff,unsigned __LONG32 DataRepresentation);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NDRSContextUnmarshall2(RPC_BINDING_HANDLE BindingHandle,void *pBuff,unsigned __LONG32 DataRepresentation,void *CtxGuard,unsigned __LONG32 Flags);
  RPCRTAPI void RPC_ENTRY RpcSsDestroyClientContext(void **ContextHandle);

#define byte_from_ndr(source,target) { *(target) = *(*(char **)&(source)->Buffer)++; }
#define byte_array_from_ndr(Source,LowerIndex,UpperIndex,Target) { NDRcopy ((((char *)(Target))+(LowerIndex)),(Source)->Buffer,(unsigned int)((UpperIndex)-(LowerIndex))); *(unsigned __LONG32 *)&(Source)->Buffer += ((UpperIndex)-(LowerIndex)); }
#define boolean_from_ndr(source,target) { *(target) = *(*(char **)&(source)->Buffer)++; }
#define boolean_array_from_ndr(Source,LowerIndex,UpperIndex,Target) { NDRcopy ((((char *)(Target))+(LowerIndex)),(Source)->Buffer,(unsigned int)((UpperIndex)-(LowerIndex))); *(unsigned __LONG32 *)&(Source)->Buffer += ((UpperIndex)-(LowerIndex)); }
#define small_from_ndr(source,target) { *(target) = *(*(char **)&(source)->Buffer)++; }
#define small_from_ndr_temp(source,target,format) { *(target) = *(*(char **)(source))++; }
#define small_array_from_ndr(Source,LowerIndex,UpperIndex,Target) { NDRcopy ((((char *)(Target))+(LowerIndex)),(Source)->Buffer,(unsigned int)((UpperIndex)-(LowerIndex))); *(unsigned __LONG32 *)&(Source)->Buffer += ((UpperIndex)-(LowerIndex)); }

#define MIDL_ascii_strlen(string) strlen(string)
#define MIDL_ascii_strcpy(target,source) strcpy(target,source)
#define MIDL_memset(s,c,n) memset(s,c,n)

#ifndef _ERROR_STATUS_T_DEFINED
#define _ERROR_STATUS_T_DEFINED
typedef unsigned __LONG32 error_status_t;
#endif

#define _midl_ma1(p,cast) *(*(cast **)&p)++
#define _midl_ma2(p,cast) *(*(cast **)&p)++
#define _midl_ma4(p,cast) *(*(cast **)&p)++
#define _midl_ma8(p,cast) *(*(cast **)&p)++

#define _midl_unma1(p,cast) *((cast *)p)++
#define _midl_unma2(p,cast) *((cast *)p)++
#define _midl_unma3(p,cast) *((cast *)p)++
#define _midl_unma4(p,cast) *((cast *)p)++

#define _midl_fa2(p) (p = (RPC_BUFPTR)((ULONG_PTR)(p+1) & ~0x1))
#define _midl_fa4(p) (p = (RPC_BUFPTR)((ULONG_PTR)(p+3) & ~0x3))
#define _midl_fa8(p) (p = (RPC_BUFPTR)((ULONG_PTR)(p+7) & ~0x7))

#define _midl_addp(p,n) (p += n)
#define _midl_marsh_lhs(p,cast) *(*(cast **)&p)++
#define _midl_marsh_up(mp,p) *(*(unsigned __LONG32 **)&mp)++ = (unsigned __LONG32)p
#define _midl_advmp(mp) *(*(unsigned __LONG32 **)&mp)++
#define _midl_unmarsh_up(p) (*(*(unsigned __LONG32 **)&p)++)

#define NdrMarshConfStringHdr(p,s,l) (_midl_ma4(p,unsigned __LONG32) = s,_midl_ma4(p,unsigned __LONG32) = 0,_midl_ma4(p,unsigned __LONG32) = l)
#define NdrUnMarshConfStringHdr(p,s,l) (s=_midl_unma4(p,unsigned __LONG32),(_midl_addp(p,4)),(l=_midl_unma4(p,unsigned __LONG32)))
#define NdrMarshCCtxtHdl(pc,p) (NDRCContextMarshall((NDR_CCONTEXT)pc,p),p+20)
#define NdrUnMarshCCtxtHdl(pc,p,h,drep) (NDRCContextUnmarshall((NDR_CCONTEXT)pc,h,p,drep),p+20)
#define NdrUnMarshSCtxtHdl(pc,p,drep) (pc = NdrSContextUnMarshall(p,drep))
#define NdrMarshSCtxtHdl(pc,p,rd) (NdrSContextMarshall((NDR_SCONTEXT)pc,p,(NDR_RUNDOWN)rd))

#define NdrFieldOffset(s,f) (LONG_PTR)(& (((s *)0)->f))
#define NdrFieldPad(s,f,p,t) ((unsigned __LONG32)(NdrFieldOffset(s,f) - NdrFieldOffset(s,p)) - sizeof(t))

#define NdrFcShort(s) (unsigned char)(s & 0xff),(unsigned char)(s >> 8)
#define NdrFcLong(s) (unsigned char)(s & 0xff),(unsigned char)((s & 0x0000ff00) >> 8),(unsigned char)((s & 0x00ff0000) >> 16),(unsigned char)(s >> 24)

#define RPC_BAD_STUB_DATA_EXCEPTION_FILTER ((RpcExceptionCode()==STATUS_ACCESS_VIOLATION) || (RpcExceptionCode()==STATUS_DATATYPE_MISALIGNMENT) || (RpcExceptionCode()==RPC_X_BAD_STUB_DATA) || (RpcExceptionCode()==RPC_S_INVALID_BOUND))

  struct _MIDL_STUB_MESSAGE;
  struct _MIDL_STUB_DESC;
  struct _FULL_PTR_XLAT_TABLES;

  typedef unsigned char *RPC_BUFPTR;
  typedef unsigned __LONG32 RPC_LENGTH;
  typedef void (__RPC_API *EXPR_EVAL)(struct _MIDL_STUB_MESSAGE *);
  typedef const unsigned char *PFORMAT_STRING;

  typedef struct {
    __LONG32 Dimension;
    unsigned __LONG32 *BufferConformanceMark;
    unsigned __LONG32 *BufferVarianceMark;
    unsigned __LONG32 *MaxCountArray;
    unsigned __LONG32 *OffsetArray;
    unsigned __LONG32 *ActualCountArray;
  } ARRAY_INFO,*PARRAY_INFO;

  typedef struct _NDR_ASYNC_MESSAGE *PNDR_ASYNC_MESSAGE;
  typedef struct _NDR_CORRELATION_INFO *PNDR_CORRELATION_INFO;

  typedef struct {
    unsigned __LONG32 WireCodeset;
    unsigned __LONG32 DesiredReceivingCodeset;
    void *CSArrayInfo;
  } CS_STUB_INFO;

  struct _MIDL_SYNTAX_INFO;
  typedef struct _MIDL_SYNTAX_INFO MIDL_SYNTAX_INFO,*PMIDL_SYNTAX_INFO;

  struct NDR_ALLOC_ALL_NODES_CONTEXT;
  struct NDR_POINTER_QUEUE_STATE;
  struct _NDR_PROC_CONTEXT;

  typedef struct _MIDL_STUB_MESSAGE {
    PRPC_MESSAGE RpcMsg;
    unsigned char *Buffer;
    unsigned char *BufferStart;
    unsigned char *BufferEnd;
    unsigned char *BufferMark;
    unsigned __LONG32 BufferLength;
    unsigned __LONG32 MemorySize;
    unsigned char *Memory;
    unsigned char IsClient;
    unsigned char Pad;
    unsigned short uFlags2;
    int ReuseBuffer;
    struct NDR_ALLOC_ALL_NODES_CONTEXT *pAllocAllNodesContext;
    struct NDR_POINTER_QUEUE_STATE *pPointerQueueState;
    int IgnoreEmbeddedPointers;
    unsigned char *PointerBufferMark;
    unsigned char fBufferValid;
    unsigned char uFlags;
    unsigned short UniquePtrCount;
    ULONG_PTR MaxCount;
    unsigned __LONG32 Offset;
    unsigned __LONG32 ActualCount;
    void *(__RPC_API *pfnAllocate)(size_t);
    void (__RPC_API *pfnFree)(void *);
    unsigned char *StackTop;
    unsigned char *pPresentedType;
    unsigned char *pTransmitType;
    handle_t SavedHandle;
    const struct _MIDL_STUB_DESC *StubDesc;
    struct _FULL_PTR_XLAT_TABLES *FullPtrXlatTables;
    unsigned __LONG32 FullPtrRefId;
    unsigned __LONG32 PointerLength;
    int fInDontFree : 1;
    int fDontCallFreeInst : 1;
    int fInOnlyParam : 1;
    int fHasReturn : 1;
    int fHasExtensions : 1;
    int fHasNewCorrDesc : 1;
    int fIsOicfServer : 1;
    int fHasMemoryValidateCallback : 1;
    int fUnused : 8;
    int fUnused2 : 16;
    unsigned __LONG32 dwDestContext;
    void *pvDestContext;
    NDR_SCONTEXT *SavedContextHandles;
    __LONG32 ParamNumber;
    struct IRpcChannelBuffer *pRpcChannelBuffer;
    PARRAY_INFO pArrayInfo;
    unsigned __LONG32 *SizePtrCountArray;
    unsigned __LONG32 *SizePtrOffsetArray;
    unsigned __LONG32 *SizePtrLengthArray;
    void *pArgQueue;
    unsigned __LONG32 dwStubPhase;
    void *LowStackMark;
    PNDR_ASYNC_MESSAGE pAsyncMsg;
    PNDR_CORRELATION_INFO pCorrInfo;
    unsigned char *pCorrMemory;
    void *pMemoryList;
    CS_STUB_INFO *pCSInfo;
    unsigned char *ConformanceMark;
    unsigned char *VarianceMark;
#if defined(IA64)
    void *BackingStoreLowMark;
#else
    INT_PTR Unused;
#endif
    struct _NDR_PROC_CONTEXT *pContext;
    void *pUserMarshalList;
    INT_PTR Reserved51_2;
    INT_PTR Reserved51_3;
    INT_PTR Reserved51_4;
    INT_PTR Reserved51_5;
  } MIDL_STUB_MESSAGE,*PMIDL_STUB_MESSAGE;

  typedef void *(__RPC_API *GENERIC_BINDING_ROUTINE)(void *);
  typedef void (__RPC_API *GENERIC_UNBIND_ROUTINE)(void *,unsigned char *);

  typedef struct _GENERIC_BINDING_ROUTINE_PAIR {
    GENERIC_BINDING_ROUTINE pfnBind;
    GENERIC_UNBIND_ROUTINE pfnUnbind;
  } GENERIC_BINDING_ROUTINE_PAIR,*PGENERIC_BINDING_ROUTINE_PAIR;

  typedef struct __GENERIC_BINDING_INFO {
    void *pObj;
    unsigned int Size;
    GENERIC_BINDING_ROUTINE pfnBind;
    GENERIC_UNBIND_ROUTINE pfnUnbind;
  } GENERIC_BINDING_INFO,*PGENERIC_BINDING_INFO;

#define NDR_SHAREABLE __inline

  typedef void (__RPC_API *XMIT_HELPER_ROUTINE)(PMIDL_STUB_MESSAGE);

  typedef struct _XMIT_ROUTINE_QUINTUPLE {
    XMIT_HELPER_ROUTINE pfnTranslateToXmit;
    XMIT_HELPER_ROUTINE pfnTranslateFromXmit;
    XMIT_HELPER_ROUTINE pfnFreeXmit;
    XMIT_HELPER_ROUTINE pfnFreeInst;
  } XMIT_ROUTINE_QUINTUPLE,*PXMIT_ROUTINE_QUINTUPLE;

  typedef ULONG (__RPC_API *USER_MARSHAL_SIZING_ROUTINE)(ULONG *,ULONG,void *);
  typedef unsigned char *(__RPC_API *USER_MARSHAL_MARSHALLING_ROUTINE)(ULONG *,unsigned char *,void *);
  typedef unsigned char *(__RPC_API *USER_MARSHAL_UNMARSHALLING_ROUTINE)(ULONG *,unsigned char *,void *);
  typedef void (__RPC_API *USER_MARSHAL_FREEING_ROUTINE)(ULONG *,void *);

  typedef struct _USER_MARSHAL_ROUTINE_QUADRUPLE {
    USER_MARSHAL_SIZING_ROUTINE pfnBufferSize;
    USER_MARSHAL_MARSHALLING_ROUTINE pfnMarshall;
    USER_MARSHAL_UNMARSHALLING_ROUTINE pfnUnmarshall;
    USER_MARSHAL_FREEING_ROUTINE pfnFree;
  } USER_MARSHAL_ROUTINE_QUADRUPLE;

#define USER_MARSHAL_CB_SIGNATURE 'USRC'

  typedef enum _USER_MARSHAL_CB_TYPE {
    USER_MARSHAL_CB_BUFFER_SIZE,USER_MARSHAL_CB_MARSHALL,USER_MARSHAL_CB_UNMARSHALL,USER_MARSHAL_CB_FREE
  } USER_MARSHAL_CB_TYPE;

  typedef struct _USER_MARSHAL_CB {
    unsigned __LONG32 Flags;
    PMIDL_STUB_MESSAGE pStubMsg;
    PFORMAT_STRING pReserve;
    unsigned __LONG32 Signature;
    USER_MARSHAL_CB_TYPE CBType;
    PFORMAT_STRING pFormat;
    PFORMAT_STRING pTypeFormat;
  } USER_MARSHAL_CB;

#define USER_CALL_CTXT_MASK(f) ((f) & 0x00ff)
#define USER_CALL_AUX_MASK(f) ((f) & 0xff00)
#define GET_USER_DATA_REP(f) ((f) >> 16)

#define USER_CALL_IS_ASYNC 0x0100
#define USER_CALL_NEW_CORRELATION_DESC 0x0200

  typedef struct _MALLOC_FREE_STRUCT {
    void *(__RPC_API *pfnAllocate)(size_t);
    void (__RPC_API *pfnFree)(void *);
  } MALLOC_FREE_STRUCT;

  typedef struct _COMM_FAULT_OFFSETS {
    short CommOffset;
    short FaultOffset;
  } COMM_FAULT_OFFSETS;

  typedef enum _IDL_CS_CONVERT {
    IDL_CS_NO_CONVERT,IDL_CS_IN_PLACE_CONVERT,IDL_CS_NEW_BUFFER_CONVERT
  } IDL_CS_CONVERT;

  typedef void (__RPC_API *CS_TYPE_NET_SIZE_ROUTINE)(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 ulNetworkCodeSet,unsigned __LONG32 ulLocalBufferSize,IDL_CS_CONVERT *conversionType,unsigned __LONG32 *pulNetworkBufferSize,error_status_t *pStatus);
  typedef void (__RPC_API *CS_TYPE_LOCAL_SIZE_ROUTINE)(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 ulNetworkCodeSet,unsigned __LONG32 ulNetworkBufferSize,IDL_CS_CONVERT *conversionType,unsigned __LONG32 *pulLocalBufferSize,error_status_t *pStatus);
  typedef void (__RPC_API *CS_TYPE_TO_NETCS_ROUTINE)(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 ulNetworkCodeSet,void *pLocalData,unsigned __LONG32 ulLocalDataLength,byte *pNetworkData,unsigned __LONG32 *pulNetworkDataLength,error_status_t *pStatus);
  typedef void (__RPC_API *CS_TYPE_FROM_NETCS_ROUTINE)(RPC_BINDING_HANDLE hBinding,unsigned __LONG32 ulNetworkCodeSet,byte *pNetworkData,unsigned __LONG32 ulNetworkDataLength,unsigned __LONG32 ulLocalBufferSize,void *pLocalData,unsigned __LONG32 *pulLocalDataLength,error_status_t *pStatus);
  typedef void (__RPC_API *CS_TAG_GETTING_ROUTINE)(RPC_BINDING_HANDLE hBinding,int fServerSide,unsigned __LONG32 *pulSendingTag,unsigned __LONG32 *pulDesiredReceivingTag,unsigned __LONG32 *pulReceivingTag,error_status_t *pStatus);

  void __RPC_API RpcCsGetTags(RPC_BINDING_HANDLE hBinding,int fServerSide,unsigned __LONG32 *pulSendingTag,unsigned __LONG32 *pulDesiredReceivingTag,unsigned __LONG32 *pulReceivingTag,error_status_t *pStatus);

  typedef struct _NDR_CS_SIZE_CONVERT_ROUTINES {
    CS_TYPE_NET_SIZE_ROUTINE pfnNetSize;
    CS_TYPE_TO_NETCS_ROUTINE pfnToNetCs;
    CS_TYPE_LOCAL_SIZE_ROUTINE pfnLocalSize;
    CS_TYPE_FROM_NETCS_ROUTINE pfnFromNetCs;
  } NDR_CS_SIZE_CONVERT_ROUTINES;

  typedef struct _NDR_CS_ROUTINES {
    NDR_CS_SIZE_CONVERT_ROUTINES *pSizeConvertRoutines;
    CS_TAG_GETTING_ROUTINE *pTagGettingRoutines;
  } NDR_CS_ROUTINES;

  typedef struct _MIDL_STUB_DESC {
    void *RpcInterfaceInformation;
    void *(__RPC_API *pfnAllocate)(size_t);
    void (__RPC_API *pfnFree)(void *);
    union {
      handle_t *pAutoHandle;
      handle_t *pPrimitiveHandle;
      PGENERIC_BINDING_INFO pGenericBindingInfo;
    } IMPLICIT_HANDLE_INFO;
    const NDR_RUNDOWN *apfnNdrRundownRoutines;
    const GENERIC_BINDING_ROUTINE_PAIR *aGenericBindingRoutinePairs;
    const EXPR_EVAL *apfnExprEval;
    const XMIT_ROUTINE_QUINTUPLE *aXmitQuintuple;
    const unsigned char *pFormatTypes;
    int fCheckBounds;
    unsigned __LONG32 Version;
    MALLOC_FREE_STRUCT *pMallocFreeStruct;
    __LONG32 MIDLVersion;
    const COMM_FAULT_OFFSETS *CommFaultOffsets;
    const USER_MARSHAL_ROUTINE_QUADRUPLE *aUserMarshalQuadruple;
    const NDR_NOTIFY_ROUTINE *NotifyRoutineTable;
    ULONG_PTR mFlags;
    const NDR_CS_ROUTINES *CsRoutineTables;
    void *Reserved4;
    ULONG_PTR Reserved5;
  } MIDL_STUB_DESC;

  typedef const MIDL_STUB_DESC *PMIDL_STUB_DESC;
  typedef void *PMIDL_XMIT_TYPE;

  typedef struct _MIDL_FORMAT_STRING {
    short Pad;
    unsigned char Format[];
  } MIDL_FORMAT_STRING;

  typedef void (__RPC_API *STUB_THUNK)(PMIDL_STUB_MESSAGE);
  typedef __LONG32 (__RPC_API *SERVER_ROUTINE)();

  typedef struct _MIDL_SERVER_INFO_ {
    PMIDL_STUB_DESC pStubDesc;
    const SERVER_ROUTINE *DispatchTable;
    PFORMAT_STRING ProcString;
    const unsigned short *FmtStringOffset;
    const STUB_THUNK *ThunkTable;
    PRPC_SYNTAX_IDENTIFIER pTransferSyntax;
    ULONG_PTR nCount;
    PMIDL_SYNTAX_INFO pSyntaxInfo;
  } MIDL_SERVER_INFO,*PMIDL_SERVER_INFO;

#undef _MIDL_STUBLESS_PROXY_INFO

  typedef struct _MIDL_STUBLESS_PROXY_INFO {
    PMIDL_STUB_DESC pStubDesc;
    PFORMAT_STRING ProcFormatString;
    const unsigned short *FormatStringOffset;
    PRPC_SYNTAX_IDENTIFIER pTransferSyntax;
    ULONG_PTR nCount;
    PMIDL_SYNTAX_INFO pSyntaxInfo;
  } MIDL_STUBLESS_PROXY_INFO;

  typedef MIDL_STUBLESS_PROXY_INFO *PMIDL_STUBLESS_PROXY_INFO;

  struct _MIDL_SYNTAX_INFO {
    RPC_SYNTAX_IDENTIFIER TransferSyntax;
    RPC_DISPATCH_TABLE *DispatchTable;
    PFORMAT_STRING ProcString;
    const unsigned short *FmtStringOffset;
    PFORMAT_STRING TypeString;
    const void *aUserMarshalQuadruple;
    ULONG_PTR pReserved1;
    ULONG_PTR pReserved2;
  };

  typedef unsigned short *PARAM_OFFSETTABLE,*PPARAM_OFFSETTABLE;

  typedef union _CLIENT_CALL_RETURN {
    void *Pointer;
    LONG_PTR Simple;
  } CLIENT_CALL_RETURN;

  typedef enum {
    XLAT_SERVER = 1,XLAT_CLIENT
  } XLAT_SIDE;

  typedef struct _FULL_PTR_TO_REFID_ELEMENT {
    struct _FULL_PTR_TO_REFID_ELEMENT *Next;
    void *Pointer;
    unsigned __LONG32 RefId;
    unsigned char State;
  } FULL_PTR_TO_REFID_ELEMENT,*PFULL_PTR_TO_REFID_ELEMENT;

  typedef struct _FULL_PTR_XLAT_TABLES {

    struct {
      void **XlatTable;
      unsigned char *StateTable;
      unsigned __LONG32 NumberOfEntries;
    } RefIdToPointer;
    struct {
      PFULL_PTR_TO_REFID_ELEMENT *XlatTable;
      unsigned __LONG32 NumberOfBuckets;
      unsigned __LONG32 HashMask;
    } PointerToRefId;
    unsigned __LONG32 NextRefId;
    XLAT_SIDE XlatSide;
  } FULL_PTR_XLAT_TABLES,*PFULL_PTR_XLAT_TABLES;

  RPC_STATUS RPC_ENTRY NdrClientGetSupportedSyntaxes(RPC_CLIENT_INTERFACE *pInf,unsigned __LONG32 *pCount,MIDL_SYNTAX_INFO **pArr);
  RPC_STATUS RPC_ENTRY NdrServerGetSupportedSyntaxes(RPC_SERVER_INTERFACE *pInf,unsigned __LONG32 *pCount,MIDL_SYNTAX_INFO **pArr,unsigned __LONG32 *pPreferSyntaxIndex);
  RPCRTAPI void RPC_ENTRY NdrSimpleTypeMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,unsigned char FormatChar);
  RPCRTAPI unsigned char *RPC_ENTRY NdrPointerMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrCsArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrCsTagMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrSimpleStructMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantStructMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantVaryingStructMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrComplexStructMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrFixedArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantVaryingArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrVaryingArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrComplexArrayMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNonConformantStringMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantStringMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrEncapsulatedUnionMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNonEncapsulatedUnionMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrByteCountPointerMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrXmitOrRepAsMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrUserMarshalMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned char *RPC_ENTRY NdrInterfacePointerMarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrClientContextMarshall(PMIDL_STUB_MESSAGE pStubMsg,NDR_CCONTEXT ContextHandle,int fCheck);
  RPCRTAPI void RPC_ENTRY NdrServerContextMarshall(PMIDL_STUB_MESSAGE pStubMsg,NDR_SCONTEXT ContextHandle,NDR_RUNDOWN RundownRoutine);
  RPCRTAPI void RPC_ENTRY NdrServerContextNewMarshall(PMIDL_STUB_MESSAGE pStubMsg,NDR_SCONTEXT ContextHandle,NDR_RUNDOWN RundownRoutine,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrSimpleTypeUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,unsigned char FormatChar);
  RPCRTAPI unsigned char *RPC_ENTRY NdrCsArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrCsTagUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrRangeUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI void RPC_ENTRY NdrCorrelationInitialize(PMIDL_STUB_MESSAGE pStubMsg,void *pMemory,unsigned __LONG32 CacheSize,unsigned __LONG32 flags);
  RPCRTAPI void RPC_ENTRY NdrCorrelationPass(PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI void RPC_ENTRY NdrCorrelationFree(PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI unsigned char *RPC_ENTRY NdrPointerUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrSimpleStructUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantStructUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantVaryingStructUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrComplexStructUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrFixedArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantVaryingArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrVaryingArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrComplexArrayUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNonConformantStringUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrConformantStringUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrEncapsulatedUnionUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNonEncapsulatedUnionUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrByteCountPointerUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrXmitOrRepAsUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrUserMarshalUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI unsigned char *RPC_ENTRY NdrInterfacePointerUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **ppMemory,PFORMAT_STRING pFormat,unsigned char fMustAlloc);
  RPCRTAPI void RPC_ENTRY NdrClientContextUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,NDR_CCONTEXT *pContextHandle,RPC_BINDING_HANDLE BindHandle);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NdrServerContextUnmarshall(PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NdrContextHandleInitialize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI NDR_SCONTEXT RPC_ENTRY NdrServerContextNewUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrPointerBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrCsArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrCsTagBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrSimpleStructBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantStructBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantVaryingStructBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrComplexStructBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrFixedArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantVaryingArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrVaryingArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrComplexArrayBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantStringBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrNonConformantStringBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrEncapsulatedUnionBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrNonEncapsulatedUnionBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrByteCountPointerBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrXmitOrRepAsBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrUserMarshalBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrInterfacePointerBufferSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrContextHandleSize(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrPointerMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrCsArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrCsTagMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrSimpleStructMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrConformantStructMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrConformantVaryingStructMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrComplexStructMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrFixedArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrConformantArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrConformantVaryingArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrVaryingArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrComplexArrayMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrConformantStringMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrNonConformantStringMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrEncapsulatedUnionMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrNonEncapsulatedUnionMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrXmitOrRepAsMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrUserMarshalMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrInterfacePointerMemorySize(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrPointerFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrCsArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrSimpleStructFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantStructFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantVaryingStructFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrComplexStructFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrFixedArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConformantVaryingArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrVaryingArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrComplexArrayFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrEncapsulatedUnionFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrNonEncapsulatedUnionFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrByteCountPointerFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrXmitOrRepAsFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrUserMarshalFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrInterfacePointerFree(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pMemory,PFORMAT_STRING pFormat);
  RPCRTAPI void RPC_ENTRY NdrConvert2(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat,__LONG32 NumberParams);
  RPCRTAPI void RPC_ENTRY NdrConvert(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);

#define USER_MARSHAL_FC_BYTE 1
#define USER_MARSHAL_FC_CHAR 2
#define USER_MARSHAL_FC_SMALL 3
#define USER_MARSHAL_FC_USMALL 4
#define USER_MARSHAL_FC_WCHAR 5
#define USER_MARSHAL_FC_SHORT 6
#define USER_MARSHAL_FC_USHORT 7
#define USER_MARSHAL_FC_LONG 8
#define USER_MARSHAL_FC_ULONG 9
#define USER_MARSHAL_FC_FLOAT 10
#define USER_MARSHAL_FC_HYPER 11
#define USER_MARSHAL_FC_DOUBLE 12

  RPCRTAPI unsigned char *RPC_ENTRY NdrUserMarshalSimpleTypeConvert(unsigned __LONG32 *pFlags,unsigned char *pBuffer,unsigned char FormatChar);
  RPCRTAPI void RPC_ENTRY NdrClientInitializeNew(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,unsigned int ProcNum);
  RPCRTAPI unsigned char *RPC_ENTRY NdrServerInitializeNew(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor);
  RPCRTAPI void RPC_ENTRY NdrServerInitializePartial(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,unsigned __LONG32 RequestedBufferSize);
  RPCRTAPI void RPC_ENTRY NdrClientInitialize(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,unsigned int ProcNum);
  RPCRTAPI unsigned char *RPC_ENTRY NdrServerInitialize(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor);
  RPCRTAPI unsigned char *RPC_ENTRY NdrServerInitializeUnmarshall (PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY NdrServerInitializeMarshall (PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI unsigned char *RPC_ENTRY NdrGetBuffer(PMIDL_STUB_MESSAGE pStubMsg,unsigned __LONG32 BufferLength,RPC_BINDING_HANDLE Handle);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNsGetBuffer(PMIDL_STUB_MESSAGE pStubMsg,unsigned __LONG32 BufferLength,RPC_BINDING_HANDLE Handle);
  RPCRTAPI unsigned char *RPC_ENTRY NdrSendReceive(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pBufferEnd);
  RPCRTAPI unsigned char *RPC_ENTRY NdrNsSendReceive(PMIDL_STUB_MESSAGE pStubMsg,unsigned char *pBufferEnd,RPC_BINDING_HANDLE *pAutoHandle);
  RPCRTAPI void RPC_ENTRY NdrFreeBuffer(PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI RPC_STATUS RPC_ENTRY NdrGetDcomProtocolVersion(PMIDL_STUB_MESSAGE pStubMsg,RPC_VERSION *pVersion);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrClientCall2(PMIDL_STUB_DESC pStubDescriptor,PFORMAT_STRING pFormat,...);
#if defined (__arm__)
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrpClientCall2(PMIDL_STUB_DESC pStubDescriptor, PFORMAT_STRING pFormat, unsigned char *StartofStack);
#endif
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrClientCall(PMIDL_STUB_DESC pStubDescriptor,PFORMAT_STRING pFormat,...);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrAsyncClientCall(PMIDL_STUB_DESC pStubDescriptor,PFORMAT_STRING pFormat,...);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrDcomAsyncClientCall(PMIDL_STUB_DESC pStubDescriptor,PFORMAT_STRING pFormat,...);

  typedef enum {
    STUB_UNMARSHAL,STUB_CALL_SERVER,STUB_MARSHAL,STUB_CALL_SERVER_NO_HRESULT
  } STUB_PHASE;

  typedef enum {
    PROXY_CALCSIZE,PROXY_GETBUFFER,PROXY_MARSHAL,PROXY_SENDRECEIVE,PROXY_UNMARSHAL
  } PROXY_PHASE;

  struct IRpcStubBuffer;

  RPCRTAPI void RPC_ENTRY NdrAsyncServerCall(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI __LONG32 RPC_ENTRY NdrAsyncStubCall(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI __LONG32 RPC_ENTRY NdrDcomAsyncStubCall(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI __LONG32 RPC_ENTRY NdrStubCall2(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI void RPC_ENTRY NdrServerCall2(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI __LONG32 RPC_ENTRY NdrStubCall (struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI void RPC_ENTRY NdrServerCall(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI int RPC_ENTRY NdrServerUnmarshall(struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,PFORMAT_STRING pFormat,void *pParamList);
  RPCRTAPI void RPC_ENTRY NdrServerMarshall(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat);
  RPCRTAPI RPC_STATUS RPC_ENTRY NdrMapCommAndFaultStatus(PMIDL_STUB_MESSAGE pStubMsg,unsigned __LONG32 *pCommStatus,unsigned __LONG32 *pFaultStatus,RPC_STATUS Status);
  RPCRTAPI int RPC_ENTRY NdrSH_UPDecision(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,RPC_BUFPTR pBuffer);
  RPCRTAPI int RPC_ENTRY NdrSH_TLUPDecision(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem);
  RPCRTAPI int RPC_ENTRY NdrSH_TLUPDecisionBuffer(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem);
  RPCRTAPI int RPC_ENTRY NdrSH_IfAlloc(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI int RPC_ENTRY NdrSH_IfAllocRef(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI int RPC_ENTRY NdrSH_IfAllocSet(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI RPC_BUFPTR RPC_ENTRY NdrSH_IfCopy(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI RPC_BUFPTR RPC_ENTRY NdrSH_IfAllocCopy(PMIDL_STUB_MESSAGE pStubMsg,unsigned char **pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI unsigned __LONG32 RPC_ENTRY NdrSH_Copy(unsigned char *pStubMsg,unsigned char *pPtrInMem,unsigned __LONG32 Count);
  RPCRTAPI void RPC_ENTRY NdrSH_IfFree(PMIDL_STUB_MESSAGE pMessage,unsigned char *pPtr);
  RPCRTAPI RPC_BUFPTR RPC_ENTRY NdrSH_StringMarshall(PMIDL_STUB_MESSAGE pMessage,unsigned char *pMemory,unsigned __LONG32 Count,int Size);
  RPCRTAPI RPC_BUFPTR RPC_ENTRY NdrSH_StringUnMarshall(PMIDL_STUB_MESSAGE pMessage,unsigned char **pMemory,int Size);

  typedef void *RPC_SS_THREAD_HANDLE;

  typedef void *__RPC_API RPC_CLIENT_ALLOC(size_t Size);
  typedef void __RPC_API RPC_CLIENT_FREE(void *Ptr);

  RPCRTAPI void *RPC_ENTRY RpcSsAllocate(size_t Size);
  RPCRTAPI void RPC_ENTRY RpcSsDisableAllocate(void);
  RPCRTAPI void RPC_ENTRY RpcSsEnableAllocate(void);
  RPCRTAPI void RPC_ENTRY RpcSsFree(void *NodeToFree);
  RPCRTAPI RPC_SS_THREAD_HANDLE RPC_ENTRY RpcSsGetThreadHandle(void);
  RPCRTAPI void RPC_ENTRY RpcSsSetClientAllocFree(RPC_CLIENT_ALLOC *ClientAlloc,RPC_CLIENT_FREE *ClientFree);
  RPCRTAPI void RPC_ENTRY RpcSsSetThreadHandle(RPC_SS_THREAD_HANDLE Id);
  RPCRTAPI void RPC_ENTRY RpcSsSwapClientAllocFree(RPC_CLIENT_ALLOC *ClientAlloc,RPC_CLIENT_FREE *ClientFree,RPC_CLIENT_ALLOC **OldClientAlloc,RPC_CLIENT_FREE **OldClientFree);
  RPCRTAPI void *RPC_ENTRY RpcSmAllocate(size_t Size,RPC_STATUS *pStatus);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmClientFree(void *pNodeToFree);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmDestroyClientContext(void **ContextHandle);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmDisableAllocate(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmEnableAllocate(void);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmFree(void *NodeToFree);
  RPCRTAPI RPC_SS_THREAD_HANDLE RPC_ENTRY RpcSmGetThreadHandle (RPC_STATUS *pStatus);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmSetClientAllocFree(RPC_CLIENT_ALLOC *ClientAlloc,RPC_CLIENT_FREE *ClientFree);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmSetThreadHandle(RPC_SS_THREAD_HANDLE Id);
  RPCRTAPI RPC_STATUS RPC_ENTRY RpcSmSwapClientAllocFree(RPC_CLIENT_ALLOC *ClientAlloc,RPC_CLIENT_FREE *ClientFree,RPC_CLIENT_ALLOC **OldClientAlloc,RPC_CLIENT_FREE **OldClientFree);
  RPCRTAPI void RPC_ENTRY NdrRpcSsEnableAllocate(PMIDL_STUB_MESSAGE pMessage);
  RPCRTAPI void RPC_ENTRY NdrRpcSsDisableAllocate(PMIDL_STUB_MESSAGE pMessage);
  RPCRTAPI void RPC_ENTRY NdrRpcSmSetClientToOsf(PMIDL_STUB_MESSAGE pMessage);
  RPCRTAPI void *RPC_ENTRY NdrRpcSmClientAllocate(size_t Size);
  RPCRTAPI void RPC_ENTRY NdrRpcSmClientFree(void *NodeToFree);
  RPCRTAPI void *RPC_ENTRY NdrRpcSsDefaultAllocate(size_t Size);
  RPCRTAPI void RPC_ENTRY NdrRpcSsDefaultFree(void *NodeToFree);
  RPCRTAPI PFULL_PTR_XLAT_TABLES RPC_ENTRY NdrFullPointerXlatInit(unsigned __LONG32 NumberOfPointers,XLAT_SIDE XlatSide);
  RPCRTAPI void RPC_ENTRY NdrFullPointerXlatFree(PFULL_PTR_XLAT_TABLES pXlatTables);
  RPCRTAPI int RPC_ENTRY NdrFullPointerQueryPointer(PFULL_PTR_XLAT_TABLES pXlatTables,void *pPointer,unsigned char QueryType,unsigned __LONG32 *pRefId);
  RPCRTAPI int RPC_ENTRY NdrFullPointerQueryRefId(PFULL_PTR_XLAT_TABLES pXlatTables,unsigned __LONG32 RefId,unsigned char QueryType,void **ppPointer);
  RPCRTAPI void RPC_ENTRY NdrFullPointerInsertRefId(PFULL_PTR_XLAT_TABLES pXlatTables,unsigned __LONG32 RefId,void *pPointer);
  RPCRTAPI int RPC_ENTRY NdrFullPointerFree(PFULL_PTR_XLAT_TABLES pXlatTables,void *Pointer);
  RPCRTAPI void *RPC_ENTRY NdrAllocate(PMIDL_STUB_MESSAGE pStubMsg,size_t Len);
  RPCRTAPI void RPC_ENTRY NdrClearOutParameters(PMIDL_STUB_MESSAGE pStubMsg,PFORMAT_STRING pFormat,void *ArgAddr);
  RPCRTAPI void *RPC_ENTRY NdrOleAllocate(size_t Size);
  RPCRTAPI void RPC_ENTRY NdrOleFree(void *NodeToFree);

#ifdef CONST_VTABLE
#define CONST_VTBL const
#else
#define CONST_VTBL
#endif

#ifndef DECLSPEC_SELECTANY
#define DECLSPEC_SELECTANY __declspec(selectany)
#endif

#define MIDL_INTERFACE(x) struct
#ifdef __cplusplus
#define EXTERN_GUID(itf,l1,s1,s2,c1,c2,c3,c4,c5,c6,c7,c8) EXTERN_C const IID DECLSPEC_SELECTANY itf = {l1,s1,s2,{c1,c2,c3,c4,c5,c6,c7,c8}}
#else
#define EXTERN_GUID(itf,l1,s1,s2,c1,c2,c3,c4,c5,c6,c7,c8) const IID DECLSPEC_SELECTANY itf = {l1,s1,s2,{c1,c2,c3,c4,c5,c6,c7,c8}}
#endif

  typedef struct _NDR_USER_MARSHAL_INFO_LEVEL1 {
    void *Buffer;
    unsigned __LONG32 BufferSize;
    void *(__RPC_API *pfnAllocate)(size_t);
    void (__RPC_API *pfnFree)(void *);
    struct IRpcChannelBuffer *pRpcChannelBuffer;
    ULONG_PTR Reserved[5];
  } NDR_USER_MARSHAL_INFO_LEVEL1;

  typedef struct _NDR_USER_MARSHAL_INFO {
    unsigned __LONG32 InformationLevel;
    __C89_NAMELESS union {
      NDR_USER_MARSHAL_INFO_LEVEL1 Level1;
    };
  } NDR_USER_MARSHAL_INFO;

  RPC_STATUS RPC_ENTRY NdrGetUserMarshalInfo(unsigned __LONG32 *pFlags,unsigned __LONG32 InformationLevel,NDR_USER_MARSHAL_INFO *pMarshalInfo);
  RPC_STATUS RPC_ENTRY NdrCreateServerInterfaceFromStub(struct IRpcStubBuffer *pStub,RPC_SERVER_INTERFACE *pServerIf);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY NdrClientCall3(MIDL_STUBLESS_PROXY_INFO *pProxyInfo,unsigned __LONG32 nProcNum,void *pReturnValue,...);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY Ndr64AsyncClientCall(MIDL_STUBLESS_PROXY_INFO *pProxyInfo,unsigned __LONG32 nProcNum,void *pReturnValue,...);
  CLIENT_CALL_RETURN RPC_VAR_ENTRY Ndr64DcomAsyncClientCall(MIDL_STUBLESS_PROXY_INFO *pProxyInfo,unsigned __LONG32 nProcNum,void *pReturnValue,...);

  struct IRpcStubBuffer;

  RPCRTAPI void RPC_ENTRY Ndr64AsyncServerCall(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY Ndr64AsyncServerCall64(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY Ndr64AsyncServerCallAll(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI __LONG32 RPC_ENTRY Ndr64AsyncStubCall(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI __LONG32 RPC_ENTRY Ndr64DcomAsyncStubCall(struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI __LONG32 RPC_ENTRY NdrStubCall3 (struct IRpcStubBuffer *pThis,struct IRpcChannelBuffer *pChannel,PRPC_MESSAGE pRpcMsg,unsigned __LONG32 *pdwStubPhase);
  RPCRTAPI void RPC_ENTRY NdrServerCallAll(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY NdrServerCallNdr64(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY NdrServerCall3(PRPC_MESSAGE pRpcMsg);
  RPCRTAPI void RPC_ENTRY NdrPartialIgnoreClientMarshall(PMIDL_STUB_MESSAGE pStubMsg,void *pMemory);
  RPCRTAPI void RPC_ENTRY NdrPartialIgnoreServerUnmarshall(PMIDL_STUB_MESSAGE pStubMsg,void **ppMemory);
  RPCRTAPI void RPC_ENTRY NdrPartialIgnoreClientBufferSize(PMIDL_STUB_MESSAGE pStubMsg,void *pMemory);
  RPCRTAPI void RPC_ENTRY NdrPartialIgnoreServerInitialize(PMIDL_STUB_MESSAGE pStubMsg,void **ppMemory,PFORMAT_STRING pFormat);
  void RPC_ENTRY RpcUserFree(handle_t AsyncHandle,void *pBuffer);

#ifdef __cplusplus
}
#endif

#include <poppack.h>
#endif
