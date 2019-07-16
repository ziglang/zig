/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __scardssp_h__
#define __scardssp_h__

#ifndef __IByteBuffer_FWD_DEFINED__
#define __IByteBuffer_FWD_DEFINED__
typedef struct IByteBuffer IByteBuffer;
#endif

#ifndef __ISCardTypeConv_FWD_DEFINED__
#define __ISCardTypeConv_FWD_DEFINED__
typedef struct ISCardTypeConv ISCardTypeConv;
#endif

#ifndef __ISCardCmd_FWD_DEFINED__
#define __ISCardCmd_FWD_DEFINED__
typedef struct ISCardCmd ISCardCmd;
#endif

#ifndef __ISCardISO7816_FWD_DEFINED__
#define __ISCardISO7816_FWD_DEFINED__
typedef struct ISCardISO7816 ISCardISO7816;
#endif

#ifndef __ISCard_FWD_DEFINED__
#define __ISCard_FWD_DEFINED__
typedef struct ISCard ISCard;
#endif

#ifndef __ISCardDatabase_FWD_DEFINED__
#define __ISCardDatabase_FWD_DEFINED__
typedef struct ISCardDatabase ISCardDatabase;
#endif

#ifndef __ISCardLocate_FWD_DEFINED__
#define __ISCardLocate_FWD_DEFINED__
typedef struct ISCardLocate ISCardLocate;
#endif

#ifndef __CByteBuffer_FWD_DEFINED__
#define __CByteBuffer_FWD_DEFINED__
#ifdef __cplusplus
typedef class CByteBuffer CByteBuffer;
#else
typedef struct CByteBuffer CByteBuffer;
#endif
#endif

#ifndef __CSCardTypeConv_FWD_DEFINED__
#define __CSCardTypeConv_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCardTypeConv CSCardTypeConv;
#else
typedef struct CSCardTypeConv CSCardTypeConv;
#endif
#endif

#ifndef __CSCardCmd_FWD_DEFINED__
#define __CSCardCmd_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCardCmd CSCardCmd;
#else
typedef struct CSCardCmd CSCardCmd;
#endif
#endif

#ifndef __CSCardISO7816_FWD_DEFINED__
#define __CSCardISO7816_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCardISO7816 CSCardISO7816;
#else
typedef struct CSCardISO7816 CSCardISO7816;
#endif
#endif

#ifndef __CSCard_FWD_DEFINED__
#define __CSCard_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCard CSCard;
#else
typedef struct CSCard CSCard;
#endif
#endif

#ifndef __CSCardDatabase_FWD_DEFINED__
#define __CSCardDatabase_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCardDatabase CSCardDatabase;
#else
typedef struct CSCardDatabase CSCardDatabase;
#endif
#endif

#ifndef __CSCardLocate_FWD_DEFINED__
#define __CSCardLocate_FWD_DEFINED__
#ifdef __cplusplus
typedef class CSCardLocate CSCardLocate;
#else
typedef struct CSCardLocate CSCardLocate;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _NULL_DEFINED
#define _NULL_DEFINED
#endif
#ifndef _BYTE_DEFINED
#define _BYTE_DEFINED
  typedef unsigned char BYTE;
#endif
#ifndef _LPBYTE_DEFINED
#define _LPBYTE_DEFINED
  typedef BYTE *LPBYTE;
#endif
#ifndef _LPCBYTE_DEFINED
#define _LPCBYTE_DEFINED
  typedef const BYTE *LPCBYTE;
#endif
#ifndef _HSCARD_DEFINED
#define _HSCARD_DEFINED
  typedef ULONG_PTR HSCARD;
#endif
#ifndef _LPHSCARD_DEFINED
#define _LPHSCARD_DEFINED
  typedef HSCARD *PHSCARD;

  typedef HSCARD *LPHSCARD;
#endif
#ifndef _HSCARDCONTEXT_DEFINED
#define _HSCARDCONTEXT_DEFINED
  typedef ULONG_PTR HSCARDCONTEXT;
#endif
#ifndef _LPHSCARDCONTEXT_DEFINED
#define _LPHSCARDCONTEXT_DEFINED
  typedef *PHSCARDCONTEXT;

  typedef *LPHSCARDCONTEXT;
#endif
#ifndef _BYTEARRAY_DEFINED
#define _BYTEARRAY_DEFINED
  typedef struct tagBYTEARRAY {
    HGLOBAL hMem;
    DWORD dwSize;
    LPBYTE pbyData;
  } BYTEARRAY;

#define _CB_BYTEARRAY_DEFINED
#define CB_BYTEARRAY (sizeof(BYTEARRAY))
#define _PBYTEARRAY_DEFINED
  typedef BYTEARRAY *PBYTEARRAY;

#define _PCBYTEARRAY_DEFINED
  typedef const BYTEARRAY *PCBYTEARRAY;

#define _LPBYTEARRAY_DEFINED
  typedef BYTEARRAY *LPBYTEARRAY;

#define _LPCBYTEARRAY_DEFINED
  typedef const BYTEARRAY *LPCBYTEARRAY;
#endif
#ifndef _STATSTRUCT
#define _STATSTRUCT
  typedef struct tagSTATSTRUCT {
    LONG type;
    LONG cbSize;
    LONG grfMode;
    LONG grfLocksSupported;
    LONG grfStateBits;
  } STATSTRUCT;

#define _CB_STATSTRUCT_DEFINED
#define CB_STATSTRUCT (sizeof(STATSTRUCT))
#define _LPSTATSTRUCT_DEFINED
  typedef STATSTRUCT *LPSTATSTRUCT;
#endif
#ifndef _ISO_APDU_TYPE
#define _ISO_APDU_TYPE
  typedef enum tagISO_APDU_TYPE {
    ISO_CASE_1 = 1,ISO_CASE_2 = 2,ISO_CASE_3 = 3,ISO_CASE_4 = 4
  } ISO_APDU_TYPE;
#endif
#ifndef _SCARD_SHARE_MODES_DEFINED
#define _SCARD_SHARE_MODES_DEFINED
  typedef enum tagSCARD_SHARE_MODES {
    EXCLUSIVE = 1,SHARED = 2
  } SCARD_SHARE_MODES;
#endif
#ifndef _SCARD_DISPOSITIONS_DEFINED
#define _SCARD_DISPOSITIONS_DEFINED
  typedef enum tagSCARD_DISPOSITIONS {
    LEAVE = 0,RESET = 1,UNPOWER = 2,EJECT = 3
  } SCARD_DISPOSITIONS;
#endif
#ifndef _SCARD_STATES_DEFINED
#define _SCARD_STATES_DEFINED
  typedef enum tagSCARD_STATES {
    ABSENT = 1,PRESENT = 2,SWALLOWED = 3,POWERED = 4,NEGOTIABLEMODE = 5,SPECIFICMODE = 6
  } SCARD_STATES;
#endif
#ifndef _SCARD_PROTOCOLS_DEFINED
#define _SCARD_PROTOCOLS_DEFINED
  typedef enum tagSCARD_PROTOCOLS {
    T0 = 0x1,T1 = 0x2,RAW = 0xff
  } SCARD_PROTOCOLS;
#endif
#ifndef _SCARD_INFO
#define _SCARD_INFO
  typedef struct tagSCARDINFO {
    HSCARD hCard;
    HSCARDCONTEXT hContext;
    SCARD_PROTOCOLS ActiveProtocol;
    SCARD_SHARE_MODES ShareMode;
    LONG_PTR hwndOwner;
    LONG_PTR lpfnConnectProc;
    LONG_PTR lpfnCheckProc;
    LONG_PTR lpfnDisconnectProc;
  } SCARDINFO;

#define _LPSCARDINFO
  typedef SCARDINFO *PSCARDINFO;
  typedef SCARDINFO *LPSCARDINFO;
#endif

#ifndef _LPBYTEBUFFER_DEFINED
#define _LPBYTEBUFFER_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0000_v0_0_s_ifspec;

#ifndef __IByteBuffer_INTERFACE_DEFINED__
#define __IByteBuffer_INTERFACE_DEFINED__
  typedef IByteBuffer *LPBYTEBUFFER;
  typedef const IByteBuffer *LPCBYTEBUFFER;

  EXTERN_C const IID IID_IByteBuffer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IByteBuffer : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Stream(LPSTREAM *ppStream) = 0;
    virtual HRESULT WINAPI put_Stream(LPSTREAM pStream) = 0;
    virtual HRESULT WINAPI Clone(LPBYTEBUFFER *ppByteBuffer) = 0;
    virtual HRESULT WINAPI Commit(LONG grfCommitFlags) = 0;
    virtual HRESULT WINAPI CopyTo(LPBYTEBUFFER *ppByteBuffer,LONG cb,LONG *pcbRead = 0,LONG *pcbWritten = 0) = 0;
    virtual HRESULT WINAPI Initialize(LONG lSize = 1,BYTE *pData = 0) = 0;
    virtual HRESULT WINAPI LockRegion(LONG libOffset,LONG cb,LONG dwLockType) = 0;
    virtual HRESULT WINAPI Read(BYTE *pByte,LONG cb,LONG *pcbRead = 0) = 0;
    virtual HRESULT WINAPI Revert(void) = 0;
    virtual HRESULT WINAPI Seek(LONG dLibMove,LONG dwOrigin,LONG *pLibnewPosition = 0) = 0;
    virtual HRESULT WINAPI SetSize(LONG libNewSize) = 0;
    virtual HRESULT WINAPI Stat(LPSTATSTRUCT pstatstg,LONG grfStatFlag) = 0;
    virtual HRESULT WINAPI UnlockRegion(LONG libOffset,LONG cb,LONG dwLockType) = 0;
    virtual HRESULT WINAPI Write(BYTE *pByte,LONG cb,LONG *pcbWritten) = 0;
  };
#else
  typedef struct IByteBufferVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IByteBuffer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IByteBuffer *This);
      ULONG (WINAPI *Release)(IByteBuffer *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IByteBuffer *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IByteBuffer *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IByteBuffer *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IByteBuffer *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Stream)(IByteBuffer *This,LPSTREAM *ppStream);
      HRESULT (WINAPI *put_Stream)(IByteBuffer *This,LPSTREAM pStream);
      HRESULT (WINAPI *Clone)(IByteBuffer *This,LPBYTEBUFFER *ppByteBuffer);
      HRESULT (WINAPI *Commit)(IByteBuffer *This,LONG grfCommitFlags);
      HRESULT (WINAPI *CopyTo)(IByteBuffer *This,LPBYTEBUFFER *ppByteBuffer,LONG cb,LONG *pcbRead,LONG *pcbWritten);
      HRESULT (WINAPI *Initialize)(IByteBuffer *This,LONG lSize,BYTE *pData);
      HRESULT (WINAPI *LockRegion)(IByteBuffer *This,LONG libOffset,LONG cb,LONG dwLockType);
      HRESULT (WINAPI *Read)(IByteBuffer *This,BYTE *pByte,LONG cb,LONG *pcbRead);
      HRESULT (WINAPI *Revert)(IByteBuffer *This);
      HRESULT (WINAPI *Seek)(IByteBuffer *This,LONG dLibMove,LONG dwOrigin,LONG *pLibnewPosition);
      HRESULT (WINAPI *SetSize)(IByteBuffer *This,LONG libNewSize);
      HRESULT (WINAPI *Stat)(IByteBuffer *This,LPSTATSTRUCT pstatstg,LONG grfStatFlag);
      HRESULT (WINAPI *UnlockRegion)(IByteBuffer *This,LONG libOffset,LONG cb,LONG dwLockType);
      HRESULT (WINAPI *Write)(IByteBuffer *This,BYTE *pByte,LONG cb,LONG *pcbWritten);
    END_INTERFACE
  } IByteBufferVtbl;
  struct IByteBuffer {
    CONST_VTBL struct IByteBufferVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IByteBuffer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IByteBuffer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IByteBuffer_Release(This) (This)->lpVtbl->Release(This)
#define IByteBuffer_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IByteBuffer_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IByteBuffer_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IByteBuffer_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IByteBuffer_get_Stream(This,ppStream) (This)->lpVtbl->get_Stream(This,ppStream)
#define IByteBuffer_put_Stream(This,pStream) (This)->lpVtbl->put_Stream(This,pStream)
#define IByteBuffer_Clone(This,ppByteBuffer) (This)->lpVtbl->Clone(This,ppByteBuffer)
#define IByteBuffer_Commit(This,grfCommitFlags) (This)->lpVtbl->Commit(This,grfCommitFlags)
#define IByteBuffer_CopyTo(This,ppByteBuffer,cb,pcbRead,pcbWritten) (This)->lpVtbl->CopyTo(This,ppByteBuffer,cb,pcbRead,pcbWritten)
#define IByteBuffer_Initialize(This,lSize,pData) (This)->lpVtbl->Initialize(This,lSize,pData)
#define IByteBuffer_LockRegion(This,libOffset,cb,dwLockType) (This)->lpVtbl->LockRegion(This,libOffset,cb,dwLockType)
#define IByteBuffer_Read(This,pByte,cb,pcbRead) (This)->lpVtbl->Read(This,pByte,cb,pcbRead)
#define IByteBuffer_Revert(This) (This)->lpVtbl->Revert(This)
#define IByteBuffer_Seek(This,dLibMove,dwOrigin,pLibnewPosition) (This)->lpVtbl->Seek(This,dLibMove,dwOrigin,pLibnewPosition)
#define IByteBuffer_SetSize(This,libNewSize) (This)->lpVtbl->SetSize(This,libNewSize)
#define IByteBuffer_Stat(This,pstatstg,grfStatFlag) (This)->lpVtbl->Stat(This,pstatstg,grfStatFlag)
#define IByteBuffer_UnlockRegion(This,libOffset,cb,dwLockType) (This)->lpVtbl->UnlockRegion(This,libOffset,cb,dwLockType)
#define IByteBuffer_Write(This,pByte,cb,pcbWritten) (This)->lpVtbl->Write(This,pByte,cb,pcbWritten)
#endif
#endif
  HRESULT WINAPI IByteBuffer_get_Stream_Proxy(IByteBuffer *This,LPSTREAM *ppStream);
  void __RPC_STUB IByteBuffer_get_Stream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_put_Stream_Proxy(IByteBuffer *This,LPSTREAM pStream);
  void __RPC_STUB IByteBuffer_put_Stream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Clone_Proxy(IByteBuffer *This,LPBYTEBUFFER *ppByteBuffer);
  void __RPC_STUB IByteBuffer_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Commit_Proxy(IByteBuffer *This,LONG grfCommitFlags);
  void __RPC_STUB IByteBuffer_Commit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_CopyTo_Proxy(IByteBuffer *This,LPBYTEBUFFER *ppByteBuffer,LONG cb,LONG *pcbRead,LONG *pcbWritten);
  void __RPC_STUB IByteBuffer_CopyTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Initialize_Proxy(IByteBuffer *This,LONG lSize,BYTE *pData);
  void __RPC_STUB IByteBuffer_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_LockRegion_Proxy(IByteBuffer *This,LONG libOffset,LONG cb,LONG dwLockType);
  void __RPC_STUB IByteBuffer_LockRegion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Read_Proxy(IByteBuffer *This,BYTE *pByte,LONG cb,LONG *pcbRead);
  void __RPC_STUB IByteBuffer_Read_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Revert_Proxy(IByteBuffer *This);
  void __RPC_STUB IByteBuffer_Revert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Seek_Proxy(IByteBuffer *This,LONG dLibMove,LONG dwOrigin,LONG *pLibnewPosition);
  void __RPC_STUB IByteBuffer_Seek_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_SetSize_Proxy(IByteBuffer *This,LONG libNewSize);
  void __RPC_STUB IByteBuffer_SetSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Stat_Proxy(IByteBuffer *This,LPSTATSTRUCT pstatstg,LONG grfStatFlag);
  void __RPC_STUB IByteBuffer_Stat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_UnlockRegion_Proxy(IByteBuffer *This,LONG libOffset,LONG cb,LONG dwLockType);
  void __RPC_STUB IByteBuffer_UnlockRegion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IByteBuffer_Write_Proxy(IByteBuffer *This,BYTE *pByte,LONG cb,LONG *pcbWritten);
  void __RPC_STUB IByteBuffer_Write_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARDTYPECONV_DEFINED
#define _LPSCARDTYPECONV_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0244_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0244_v0_0_s_ifspec;

#ifndef __ISCardTypeConv_INTERFACE_DEFINED__
#define __ISCardTypeConv_INTERFACE_DEFINED__
  typedef ISCardTypeConv *LPSCARDTYPECONV;

  EXTERN_C const IID IID_ISCardTypeConv;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCardTypeConv : public IDispatch {
  public:
    virtual HRESULT WINAPI ConvertByteArrayToByteBuffer(LPBYTE pbyArray,DWORD dwArraySize,LPBYTEBUFFER *ppbyBuffer) = 0;
    virtual HRESULT WINAPI ConvertByteBufferToByteArray(LPBYTEBUFFER pbyBuffer,LPBYTEARRAY *ppArray) = 0;
    virtual HRESULT WINAPI ConvertByteBufferToSafeArray(LPBYTEBUFFER pbyBuffer,LPSAFEARRAY *ppbyArray) = 0;
    virtual HRESULT WINAPI ConvertSafeArrayToByteBuffer(LPSAFEARRAY pbyArray,LPBYTEBUFFER *ppbyBuff) = 0;
    virtual HRESULT WINAPI CreateByteArray(DWORD dwAllocSize,LPBYTE *ppbyArray) = 0;
    virtual HRESULT WINAPI CreateByteBuffer(DWORD dwAllocSize,LPBYTEBUFFER *ppbyBuff) = 0;
    virtual HRESULT WINAPI CreateSafeArray(UINT nAllocSize,LPSAFEARRAY *ppArray) = 0;
    virtual HRESULT WINAPI FreeIStreamMemoryPtr(LPSTREAM pStrm,LPBYTE pMem) = 0;
    virtual HRESULT WINAPI GetAtIStreamMemory(LPSTREAM pStrm,LPBYTEARRAY *ppMem) = 0;
    virtual HRESULT WINAPI SizeOfIStream(LPSTREAM pStrm,ULARGE_INTEGER *puliSize) = 0;
  };
#else
  typedef struct ISCardTypeConvVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCardTypeConv *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCardTypeConv *This);
      ULONG (WINAPI *Release)(ISCardTypeConv *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCardTypeConv *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCardTypeConv *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCardTypeConv *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCardTypeConv *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ConvertByteArrayToByteBuffer)(ISCardTypeConv *This,LPBYTE pbyArray,DWORD dwArraySize,LPBYTEBUFFER *ppbyBuffer);
      HRESULT (WINAPI *ConvertByteBufferToByteArray)(ISCardTypeConv *This,LPBYTEBUFFER pbyBuffer,LPBYTEARRAY *ppArray);
      HRESULT (WINAPI *ConvertByteBufferToSafeArray)(ISCardTypeConv *This,LPBYTEBUFFER pbyBuffer,LPSAFEARRAY *ppbyArray);
      HRESULT (WINAPI *ConvertSafeArrayToByteBuffer)(ISCardTypeConv *This,LPSAFEARRAY pbyArray,LPBYTEBUFFER *ppbyBuff);
      HRESULT (WINAPI *CreateByteArray)(ISCardTypeConv *This,DWORD dwAllocSize,LPBYTE *ppbyArray);
      HRESULT (WINAPI *CreateByteBuffer)(ISCardTypeConv *This,DWORD dwAllocSize,LPBYTEBUFFER *ppbyBuff);
      HRESULT (WINAPI *CreateSafeArray)(ISCardTypeConv *This,UINT nAllocSize,LPSAFEARRAY *ppArray);
      HRESULT (WINAPI *FreeIStreamMemoryPtr)(ISCardTypeConv *This,LPSTREAM pStrm,LPBYTE pMem);
      HRESULT (WINAPI *GetAtIStreamMemory)(ISCardTypeConv *This,LPSTREAM pStrm,LPBYTEARRAY *ppMem);
      HRESULT (WINAPI *SizeOfIStream)(ISCardTypeConv *This,LPSTREAM pStrm,ULARGE_INTEGER *puliSize);
    END_INTERFACE
  } ISCardTypeConvVtbl;
  struct ISCardTypeConv {
    CONST_VTBL struct ISCardTypeConvVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCardTypeConv_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCardTypeConv_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCardTypeConv_Release(This) (This)->lpVtbl->Release(This)
#define ISCardTypeConv_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCardTypeConv_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCardTypeConv_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCardTypeConv_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCardTypeConv_ConvertByteArrayToByteBuffer(This,pbyArray,dwArraySize,ppbyBuffer) (This)->lpVtbl->ConvertByteArrayToByteBuffer(This,pbyArray,dwArraySize,ppbyBuffer)
#define ISCardTypeConv_ConvertByteBufferToByteArray(This,pbyBuffer,ppArray) (This)->lpVtbl->ConvertByteBufferToByteArray(This,pbyBuffer,ppArray)
#define ISCardTypeConv_ConvertByteBufferToSafeArray(This,pbyBuffer,ppbyArray) (This)->lpVtbl->ConvertByteBufferToSafeArray(This,pbyBuffer,ppbyArray)
#define ISCardTypeConv_ConvertSafeArrayToByteBuffer(This,pbyArray,ppbyBuff) (This)->lpVtbl->ConvertSafeArrayToByteBuffer(This,pbyArray,ppbyBuff)
#define ISCardTypeConv_CreateByteArray(This,dwAllocSize,ppbyArray) (This)->lpVtbl->CreateByteArray(This,dwAllocSize,ppbyArray)
#define ISCardTypeConv_CreateByteBuffer(This,dwAllocSize,ppbyBuff) (This)->lpVtbl->CreateByteBuffer(This,dwAllocSize,ppbyBuff)
#define ISCardTypeConv_CreateSafeArray(This,nAllocSize,ppArray) (This)->lpVtbl->CreateSafeArray(This,nAllocSize,ppArray)
#define ISCardTypeConv_FreeIStreamMemoryPtr(This,pStrm,pMem) (This)->lpVtbl->FreeIStreamMemoryPtr(This,pStrm,pMem)
#define ISCardTypeConv_GetAtIStreamMemory(This,pStrm,ppMem) (This)->lpVtbl->GetAtIStreamMemory(This,pStrm,ppMem)
#define ISCardTypeConv_SizeOfIStream(This,pStrm,puliSize) (This)->lpVtbl->SizeOfIStream(This,pStrm,puliSize)
#endif
#endif
  HRESULT WINAPI ISCardTypeConv_ConvertByteArrayToByteBuffer_Proxy(ISCardTypeConv *This,LPBYTE pbyArray,DWORD dwArraySize,LPBYTEBUFFER *ppbyBuffer);
  void __RPC_STUB ISCardTypeConv_ConvertByteArrayToByteBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_ConvertByteBufferToByteArray_Proxy(ISCardTypeConv *This,LPBYTEBUFFER pbyBuffer,LPBYTEARRAY *ppArray);
  void __RPC_STUB ISCardTypeConv_ConvertByteBufferToByteArray_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_ConvertByteBufferToSafeArray_Proxy(ISCardTypeConv *This,LPBYTEBUFFER pbyBuffer,LPSAFEARRAY *ppbyArray);
  void __RPC_STUB ISCardTypeConv_ConvertByteBufferToSafeArray_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_ConvertSafeArrayToByteBuffer_Proxy(ISCardTypeConv *This,LPSAFEARRAY pbyArray,LPBYTEBUFFER *ppbyBuff);
  void __RPC_STUB ISCardTypeConv_ConvertSafeArrayToByteBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_CreateByteArray_Proxy(ISCardTypeConv *This,DWORD dwAllocSize,LPBYTE *ppbyArray);
  void __RPC_STUB ISCardTypeConv_CreateByteArray_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_CreateByteBuffer_Proxy(ISCardTypeConv *This,DWORD dwAllocSize,LPBYTEBUFFER *ppbyBuff);
  void __RPC_STUB ISCardTypeConv_CreateByteBuffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_CreateSafeArray_Proxy(ISCardTypeConv *This,UINT nAllocSize,LPSAFEARRAY *ppArray);
  void __RPC_STUB ISCardTypeConv_CreateSafeArray_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_FreeIStreamMemoryPtr_Proxy(ISCardTypeConv *This,LPSTREAM pStrm,LPBYTE pMem);
  void __RPC_STUB ISCardTypeConv_FreeIStreamMemoryPtr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_GetAtIStreamMemory_Proxy(ISCardTypeConv *This,LPSTREAM pStrm,LPBYTEARRAY *ppMem);
  void __RPC_STUB ISCardTypeConv_GetAtIStreamMemory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardTypeConv_SizeOfIStream_Proxy(ISCardTypeConv *This,LPSTREAM pStrm,ULARGE_INTEGER *puliSize);
  void __RPC_STUB ISCardTypeConv_SizeOfIStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARDCMD_DEFINED
#define _LPSCARDCMD_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0245_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0245_v0_0_s_ifspec;
#ifndef __ISCardCmd_INTERFACE_DEFINED__
#define __ISCardCmd_INTERFACE_DEFINED__
  typedef ISCardCmd *LPSCARDCMD;

  EXTERN_C const IID IID_ISCardCmd;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCardCmd : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Apdu(LPBYTEBUFFER *ppApdu) = 0;
    virtual HRESULT WINAPI put_Apdu(LPBYTEBUFFER pApdu) = 0;
    virtual HRESULT WINAPI get_ApduLength(LONG *plSize) = 0;
    virtual HRESULT WINAPI get_ApduReply(LPBYTEBUFFER *ppReplyApdu) = 0;
    virtual HRESULT WINAPI put_ApduReply(LPBYTEBUFFER pReplyApdu) = 0;
    virtual HRESULT WINAPI get_ApduReplyLength(LONG *plSize) = 0;
    virtual HRESULT WINAPI put_ApduReplyLength(LONG lSize) = 0;
    virtual HRESULT WINAPI get_ClassId(BYTE *pbyClass) = 0;
    virtual HRESULT WINAPI put_ClassId(BYTE byClass = 0) = 0;
    virtual HRESULT WINAPI get_Data(LPBYTEBUFFER *ppData) = 0;
    virtual HRESULT WINAPI put_Data(LPBYTEBUFFER pData) = 0;
    virtual HRESULT WINAPI get_InstructionId(BYTE *pbyIns) = 0;
    virtual HRESULT WINAPI put_InstructionId(BYTE byIns) = 0;
    virtual HRESULT WINAPI get_LeField(LONG *plSize) = 0;
    virtual HRESULT WINAPI get_P1(BYTE *pbyP1) = 0;
    virtual HRESULT WINAPI put_P1(BYTE byP1) = 0;
    virtual HRESULT WINAPI get_P2(BYTE *pbyP2) = 0;
    virtual HRESULT WINAPI put_P2(BYTE byP2) = 0;
    virtual HRESULT WINAPI get_P3(BYTE *pbyP3) = 0;
    virtual HRESULT WINAPI get_ReplyStatus(LPWORD pwStatus) = 0;
    virtual HRESULT WINAPI put_ReplyStatus(WORD wStatus) = 0;
    virtual HRESULT WINAPI get_ReplyStatusSW1(BYTE *pbySW1) = 0;
    virtual HRESULT WINAPI get_ReplyStatusSW2(BYTE *pbySW2) = 0;
    virtual HRESULT WINAPI get_Type(ISO_APDU_TYPE *pType) = 0;
    virtual HRESULT WINAPI get_Nad(BYTE *pbNad) = 0;
    virtual HRESULT WINAPI put_Nad(BYTE bNad) = 0;
    virtual HRESULT WINAPI get_ReplyNad(BYTE *pbNad) = 0;
    virtual HRESULT WINAPI put_ReplyNad(BYTE bNad) = 0;
    virtual HRESULT WINAPI BuildCmd(BYTE byClassId,BYTE byInsId,BYTE byP1 = 0,BYTE byP2 = 0,LPBYTEBUFFER pbyData = 0,LONG *plLe = 0) = 0;
    virtual HRESULT WINAPI Clear(void) = 0;
    virtual HRESULT WINAPI Encapsulate(LPBYTEBUFFER pApdu,ISO_APDU_TYPE ApduType) = 0;
    virtual HRESULT WINAPI get_AlternateClassId(BYTE *pbyClass) = 0;
    virtual HRESULT WINAPI put_AlternateClassId(BYTE byClass) = 0;
  };
#else
  typedef struct ISCardCmdVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCardCmd *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCardCmd *This);
      ULONG (WINAPI *Release)(ISCardCmd *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCardCmd *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCardCmd *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCardCmd *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCardCmd *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Apdu)(ISCardCmd *This,LPBYTEBUFFER *ppApdu);
      HRESULT (WINAPI *put_Apdu)(ISCardCmd *This,LPBYTEBUFFER pApdu);
      HRESULT (WINAPI *get_ApduLength)(ISCardCmd *This,LONG *plSize);
      HRESULT (WINAPI *get_ApduReply)(ISCardCmd *This,LPBYTEBUFFER *ppReplyApdu);
      HRESULT (WINAPI *put_ApduReply)(ISCardCmd *This,LPBYTEBUFFER pReplyApdu);
      HRESULT (WINAPI *get_ApduReplyLength)(ISCardCmd *This,LONG *plSize);
      HRESULT (WINAPI *put_ApduReplyLength)(ISCardCmd *This,LONG lSize);
      HRESULT (WINAPI *get_ClassId)(ISCardCmd *This,BYTE *pbyClass);
      HRESULT (WINAPI *put_ClassId)(ISCardCmd *This,BYTE byClass);
      HRESULT (WINAPI *get_Data)(ISCardCmd *This,LPBYTEBUFFER *ppData);
      HRESULT (WINAPI *put_Data)(ISCardCmd *This,LPBYTEBUFFER pData);
      HRESULT (WINAPI *get_InstructionId)(ISCardCmd *This,BYTE *pbyIns);
      HRESULT (WINAPI *put_InstructionId)(ISCardCmd *This,BYTE byIns);
      HRESULT (WINAPI *get_LeField)(ISCardCmd *This,LONG *plSize);
      HRESULT (WINAPI *get_P1)(ISCardCmd *This,BYTE *pbyP1);
      HRESULT (WINAPI *put_P1)(ISCardCmd *This,BYTE byP1);
      HRESULT (WINAPI *get_P2)(ISCardCmd *This,BYTE *pbyP2);
      HRESULT (WINAPI *put_P2)(ISCardCmd *This,BYTE byP2);
      HRESULT (WINAPI *get_P3)(ISCardCmd *This,BYTE *pbyP3);
      HRESULT (WINAPI *get_ReplyStatus)(ISCardCmd *This,LPWORD pwStatus);
      HRESULT (WINAPI *put_ReplyStatus)(ISCardCmd *This,WORD wStatus);
      HRESULT (WINAPI *get_ReplyStatusSW1)(ISCardCmd *This,BYTE *pbySW1);
      HRESULT (WINAPI *get_ReplyStatusSW2)(ISCardCmd *This,BYTE *pbySW2);
      HRESULT (WINAPI *get_Type)(ISCardCmd *This,ISO_APDU_TYPE *pType);
      HRESULT (WINAPI *get_Nad)(ISCardCmd *This,BYTE *pbNad);
      HRESULT (WINAPI *put_Nad)(ISCardCmd *This,BYTE bNad);
      HRESULT (WINAPI *get_ReplyNad)(ISCardCmd *This,BYTE *pbNad);
      HRESULT (WINAPI *put_ReplyNad)(ISCardCmd *This,BYTE bNad);
      HRESULT (WINAPI *BuildCmd)(ISCardCmd *This,BYTE byClassId,BYTE byInsId,BYTE byP1,BYTE byP2,LPBYTEBUFFER pbyData,LONG *plLe);
      HRESULT (WINAPI *Clear)(ISCardCmd *This);
      HRESULT (WINAPI *Encapsulate)(ISCardCmd *This,LPBYTEBUFFER pApdu,ISO_APDU_TYPE ApduType);
      HRESULT (WINAPI *get_AlternateClassId)(ISCardCmd *This,BYTE *pbyClass);
      HRESULT (WINAPI *put_AlternateClassId)(ISCardCmd *This,BYTE byClass);
    END_INTERFACE
  } ISCardCmdVtbl;
  struct ISCardCmd {
    CONST_VTBL struct ISCardCmdVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCardCmd_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCardCmd_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCardCmd_Release(This) (This)->lpVtbl->Release(This)
#define ISCardCmd_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCardCmd_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCardCmd_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCardCmd_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCardCmd_get_Apdu(This,ppApdu) (This)->lpVtbl->get_Apdu(This,ppApdu)
#define ISCardCmd_put_Apdu(This,pApdu) (This)->lpVtbl->put_Apdu(This,pApdu)
#define ISCardCmd_get_ApduLength(This,plSize) (This)->lpVtbl->get_ApduLength(This,plSize)
#define ISCardCmd_get_ApduReply(This,ppReplyApdu) (This)->lpVtbl->get_ApduReply(This,ppReplyApdu)
#define ISCardCmd_put_ApduReply(This,pReplyApdu) (This)->lpVtbl->put_ApduReply(This,pReplyApdu)
#define ISCardCmd_get_ApduReplyLength(This,plSize) (This)->lpVtbl->get_ApduReplyLength(This,plSize)
#define ISCardCmd_put_ApduReplyLength(This,lSize) (This)->lpVtbl->put_ApduReplyLength(This,lSize)
#define ISCardCmd_get_ClassId(This,pbyClass) (This)->lpVtbl->get_ClassId(This,pbyClass)
#define ISCardCmd_put_ClassId(This,byClass) (This)->lpVtbl->put_ClassId(This,byClass)
#define ISCardCmd_get_Data(This,ppData) (This)->lpVtbl->get_Data(This,ppData)
#define ISCardCmd_put_Data(This,pData) (This)->lpVtbl->put_Data(This,pData)
#define ISCardCmd_get_InstructionId(This,pbyIns) (This)->lpVtbl->get_InstructionId(This,pbyIns)
#define ISCardCmd_put_InstructionId(This,byIns) (This)->lpVtbl->put_InstructionId(This,byIns)
#define ISCardCmd_get_LeField(This,plSize) (This)->lpVtbl->get_LeField(This,plSize)
#define ISCardCmd_get_P1(This,pbyP1) (This)->lpVtbl->get_P1(This,pbyP1)
#define ISCardCmd_put_P1(This,byP1) (This)->lpVtbl->put_P1(This,byP1)
#define ISCardCmd_get_P2(This,pbyP2) (This)->lpVtbl->get_P2(This,pbyP2)
#define ISCardCmd_put_P2(This,byP2) (This)->lpVtbl->put_P2(This,byP2)
#define ISCardCmd_get_P3(This,pbyP3) (This)->lpVtbl->get_P3(This,pbyP3)
#define ISCardCmd_get_ReplyStatus(This,pwStatus) (This)->lpVtbl->get_ReplyStatus(This,pwStatus)
#define ISCardCmd_put_ReplyStatus(This,wStatus) (This)->lpVtbl->put_ReplyStatus(This,wStatus)
#define ISCardCmd_get_ReplyStatusSW1(This,pbySW1) (This)->lpVtbl->get_ReplyStatusSW1(This,pbySW1)
#define ISCardCmd_get_ReplyStatusSW2(This,pbySW2) (This)->lpVtbl->get_ReplyStatusSW2(This,pbySW2)
#define ISCardCmd_get_Type(This,pType) (This)->lpVtbl->get_Type(This,pType)
#define ISCardCmd_get_Nad(This,pbNad) (This)->lpVtbl->get_Nad(This,pbNad)
#define ISCardCmd_put_Nad(This,bNad) (This)->lpVtbl->put_Nad(This,bNad)
#define ISCardCmd_get_ReplyNad(This,pbNad) (This)->lpVtbl->get_ReplyNad(This,pbNad)
#define ISCardCmd_put_ReplyNad(This,bNad) (This)->lpVtbl->put_ReplyNad(This,bNad)
#define ISCardCmd_BuildCmd(This,byClassId,byInsId,byP1,byP2,pbyData,plLe) (This)->lpVtbl->BuildCmd(This,byClassId,byInsId,byP1,byP2,pbyData,plLe)
#define ISCardCmd_Clear(This) (This)->lpVtbl->Clear(This)
#define ISCardCmd_Encapsulate(This,pApdu,ApduType) (This)->lpVtbl->Encapsulate(This,pApdu,ApduType)
#define ISCardCmd_get_AlternateClassId(This,pbyClass) (This)->lpVtbl->get_AlternateClassId(This,pbyClass)
#define ISCardCmd_put_AlternateClassId(This,byClass) (This)->lpVtbl->put_AlternateClassId(This,byClass)
#endif
#endif
  HRESULT WINAPI ISCardCmd_get_Apdu_Proxy(ISCardCmd *This,LPBYTEBUFFER *ppApdu);
  void __RPC_STUB ISCardCmd_get_Apdu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_Apdu_Proxy(ISCardCmd *This,LPBYTEBUFFER pApdu);
  void __RPC_STUB ISCardCmd_put_Apdu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ApduLength_Proxy(ISCardCmd *This,LONG *plSize);
  void __RPC_STUB ISCardCmd_get_ApduLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ApduReply_Proxy(ISCardCmd *This,LPBYTEBUFFER *ppReplyApdu);
  void __RPC_STUB ISCardCmd_get_ApduReply_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_ApduReply_Proxy(ISCardCmd *This,LPBYTEBUFFER pReplyApdu);
  void __RPC_STUB ISCardCmd_put_ApduReply_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ApduReplyLength_Proxy(ISCardCmd *This,LONG *plSize);
  void __RPC_STUB ISCardCmd_get_ApduReplyLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_ApduReplyLength_Proxy(ISCardCmd *This,LONG lSize);
  void __RPC_STUB ISCardCmd_put_ApduReplyLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ClassId_Proxy(ISCardCmd *This,BYTE *pbyClass);
  void __RPC_STUB ISCardCmd_get_ClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_ClassId_Proxy(ISCardCmd *This,BYTE byClass);
  void __RPC_STUB ISCardCmd_put_ClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_Data_Proxy(ISCardCmd *This,LPBYTEBUFFER *ppData);
  void __RPC_STUB ISCardCmd_get_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_Data_Proxy(ISCardCmd *This,LPBYTEBUFFER pData);
  void __RPC_STUB ISCardCmd_put_Data_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_InstructionId_Proxy(ISCardCmd *This,BYTE *pbyIns);
  void __RPC_STUB ISCardCmd_get_InstructionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_InstructionId_Proxy(ISCardCmd *This,BYTE byIns);
  void __RPC_STUB ISCardCmd_put_InstructionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_LeField_Proxy(ISCardCmd *This,LONG *plSize);
  void __RPC_STUB ISCardCmd_get_LeField_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_P1_Proxy(ISCardCmd *This,BYTE *pbyP1);
  void __RPC_STUB ISCardCmd_get_P1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_P1_Proxy(ISCardCmd *This,BYTE byP1);
  void __RPC_STUB ISCardCmd_put_P1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_P2_Proxy(ISCardCmd *This,BYTE *pbyP2);
  void __RPC_STUB ISCardCmd_get_P2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_P2_Proxy(ISCardCmd *This,BYTE byP2);
  void __RPC_STUB ISCardCmd_put_P2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_P3_Proxy(ISCardCmd *This,BYTE *pbyP3);
  void __RPC_STUB ISCardCmd_get_P3_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ReplyStatus_Proxy(ISCardCmd *This,LPWORD pwStatus);
  void __RPC_STUB ISCardCmd_get_ReplyStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_ReplyStatus_Proxy(ISCardCmd *This,WORD wStatus);
  void __RPC_STUB ISCardCmd_put_ReplyStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ReplyStatusSW1_Proxy(ISCardCmd *This,BYTE *pbySW1);
  void __RPC_STUB ISCardCmd_get_ReplyStatusSW1_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ReplyStatusSW2_Proxy(ISCardCmd *This,BYTE *pbySW2);
  void __RPC_STUB ISCardCmd_get_ReplyStatusSW2_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_Type_Proxy(ISCardCmd *This,ISO_APDU_TYPE *pType);
  void __RPC_STUB ISCardCmd_get_Type_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_Nad_Proxy(ISCardCmd *This,BYTE *pbNad);
  void __RPC_STUB ISCardCmd_get_Nad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_Nad_Proxy(ISCardCmd *This,BYTE bNad);
  void __RPC_STUB ISCardCmd_put_Nad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_ReplyNad_Proxy(ISCardCmd *This,BYTE *pbNad);
  void __RPC_STUB ISCardCmd_get_ReplyNad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_ReplyNad_Proxy(ISCardCmd *This,BYTE bNad);
  void __RPC_STUB ISCardCmd_put_ReplyNad_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_BuildCmd_Proxy(ISCardCmd *This,BYTE byClassId,BYTE byInsId,BYTE byP1,BYTE byP2,LPBYTEBUFFER pbyData,LONG *plLe);
  void __RPC_STUB ISCardCmd_BuildCmd_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_Clear_Proxy(ISCardCmd *This);
  void __RPC_STUB ISCardCmd_Clear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_Encapsulate_Proxy(ISCardCmd *This,LPBYTEBUFFER pApdu,ISO_APDU_TYPE ApduType);
  void __RPC_STUB ISCardCmd_Encapsulate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_get_AlternateClassId_Proxy(ISCardCmd *This,BYTE *pbyClass);
  void __RPC_STUB ISCardCmd_get_AlternateClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardCmd_put_AlternateClassId_Proxy(ISCardCmd *This,BYTE byClass);
  void __RPC_STUB ISCardCmd_put_AlternateClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARDISO7816_DEFINED
#define _LPSCARDISO7816_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0246_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0246_v0_0_s_ifspec;
#ifndef __ISCardISO7816_INTERFACE_DEFINED__
#define __ISCardISO7816_INTERFACE_DEFINED__
  typedef ISCardISO7816 *LPSCARDISO;
  typedef LPSCARDISO LPSCARDISO7816;

  EXTERN_C const IID IID_ISCardISO7816;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCardISO7816 : public IDispatch {
  public:
    virtual HRESULT WINAPI AppendRecord(BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI EraseBinary(BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI ExternalAuthenticate(BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI GetChallenge(LONG lBytesExpected,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI GetData(BYTE byP1,BYTE byP2,LONG lBytesToGet,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI GetResponse(BYTE byP1,BYTE byP2,LONG lDataLength,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI InternalAuthenticate(BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LONG lReplyBytes,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI ManageChannel(BYTE byChannelState,BYTE byChannel,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI PutData(BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI ReadBinary(BYTE byP1,BYTE byP2,LONG lBytesToRead,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI ReadRecord(BYTE byRecordId,BYTE byRefCtrl,LONG lBytesToRead,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI SelectFile(BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LONG lBytesToRead,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI SetDefaultClassId(BYTE byClass) = 0;
    virtual HRESULT WINAPI UpdateBinary(BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI UpdateRecord(BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI Verify(BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI WriteBinary(BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI WriteRecord(BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd) = 0;
  };
#else
  typedef struct ISCardISO7816Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCardISO7816 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCardISO7816 *This);
      ULONG (WINAPI *Release)(ISCardISO7816 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCardISO7816 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCardISO7816 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCardISO7816 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCardISO7816 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *AppendRecord)(ISCardISO7816 *This,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *EraseBinary)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *ExternalAuthenticate)(ISCardISO7816 *This,BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *GetChallenge)(ISCardISO7816 *This,LONG lBytesExpected,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *GetData)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lBytesToGet,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *GetResponse)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lDataLength,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *InternalAuthenticate)(ISCardISO7816 *This,BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LONG lReplyBytes,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *ManageChannel)(ISCardISO7816 *This,BYTE byChannelState,BYTE byChannel,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *PutData)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *ReadBinary)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lBytesToRead,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *ReadRecord)(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LONG lBytesToRead,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *SelectFile)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LONG lBytesToRead,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *SetDefaultClassId)(ISCardISO7816 *This,BYTE byClass);
      HRESULT (WINAPI *UpdateBinary)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *UpdateRecord)(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *Verify)(ISCardISO7816 *This,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *WriteBinary)(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *WriteRecord)(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
    END_INTERFACE
  } ISCardISO7816Vtbl;
  struct ISCardISO7816 {
    CONST_VTBL struct ISCardISO7816Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCardISO7816_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCardISO7816_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCardISO7816_Release(This) (This)->lpVtbl->Release(This)
#define ISCardISO7816_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCardISO7816_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCardISO7816_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCardISO7816_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCardISO7816_AppendRecord(This,byRefCtrl,pData,ppCmd) (This)->lpVtbl->AppendRecord(This,byRefCtrl,pData,ppCmd)
#define ISCardISO7816_EraseBinary(This,byP1,byP2,pData,ppCmd) (This)->lpVtbl->EraseBinary(This,byP1,byP2,pData,ppCmd)
#define ISCardISO7816_ExternalAuthenticate(This,byAlgorithmRef,bySecretRef,pChallenge,ppCmd) (This)->lpVtbl->ExternalAuthenticate(This,byAlgorithmRef,bySecretRef,pChallenge,ppCmd)
#define ISCardISO7816_GetChallenge(This,lBytesExpected,ppCmd) (This)->lpVtbl->GetChallenge(This,lBytesExpected,ppCmd)
#define ISCardISO7816_GetData(This,byP1,byP2,lBytesToGet,ppCmd) (This)->lpVtbl->GetData(This,byP1,byP2,lBytesToGet,ppCmd)
#define ISCardISO7816_GetResponse(This,byP1,byP2,lDataLength,ppCmd) (This)->lpVtbl->GetResponse(This,byP1,byP2,lDataLength,ppCmd)
#define ISCardISO7816_InternalAuthenticate(This,byAlgorithmRef,bySecretRef,pChallenge,lReplyBytes,ppCmd) (This)->lpVtbl->InternalAuthenticate(This,byAlgorithmRef,bySecretRef,pChallenge,lReplyBytes,ppCmd)
#define ISCardISO7816_ManageChannel(This,byChannelState,byChannel,ppCmd) (This)->lpVtbl->ManageChannel(This,byChannelState,byChannel,ppCmd)
#define ISCardISO7816_PutData(This,byP1,byP2,pData,ppCmd) (This)->lpVtbl->PutData(This,byP1,byP2,pData,ppCmd)
#define ISCardISO7816_ReadBinary(This,byP1,byP2,lBytesToRead,ppCmd) (This)->lpVtbl->ReadBinary(This,byP1,byP2,lBytesToRead,ppCmd)
#define ISCardISO7816_ReadRecord(This,byRecordId,byRefCtrl,lBytesToRead,ppCmd) (This)->lpVtbl->ReadRecord(This,byRecordId,byRefCtrl,lBytesToRead,ppCmd)
#define ISCardISO7816_SelectFile(This,byP1,byP2,pData,lBytesToRead,ppCmd) (This)->lpVtbl->SelectFile(This,byP1,byP2,pData,lBytesToRead,ppCmd)
#define ISCardISO7816_SetDefaultClassId(This,byClass) (This)->lpVtbl->SetDefaultClassId(This,byClass)
#define ISCardISO7816_UpdateBinary(This,byP1,byP2,pData,ppCmd) (This)->lpVtbl->UpdateBinary(This,byP1,byP2,pData,ppCmd)
#define ISCardISO7816_UpdateRecord(This,byRecordId,byRefCtrl,pData,ppCmd) (This)->lpVtbl->UpdateRecord(This,byRecordId,byRefCtrl,pData,ppCmd)
#define ISCardISO7816_Verify(This,byRefCtrl,pData,ppCmd) (This)->lpVtbl->Verify(This,byRefCtrl,pData,ppCmd)
#define ISCardISO7816_WriteBinary(This,byP1,byP2,pData,ppCmd) (This)->lpVtbl->WriteBinary(This,byP1,byP2,pData,ppCmd)
#define ISCardISO7816_WriteRecord(This,byRecordId,byRefCtrl,pData,ppCmd) (This)->lpVtbl->WriteRecord(This,byRecordId,byRefCtrl,pData,ppCmd)
#endif
#endif
  HRESULT WINAPI ISCardISO7816_AppendRecord_Proxy(ISCardISO7816 *This,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_AppendRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_EraseBinary_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_EraseBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_ExternalAuthenticate_Proxy(ISCardISO7816 *This,BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_ExternalAuthenticate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_GetChallenge_Proxy(ISCardISO7816 *This,LONG lBytesExpected,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_GetChallenge_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_GetData_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lBytesToGet,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_GetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_GetResponse_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lDataLength,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_GetResponse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_InternalAuthenticate_Proxy(ISCardISO7816 *This,BYTE byAlgorithmRef,BYTE bySecretRef,LPBYTEBUFFER pChallenge,LONG lReplyBytes,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_InternalAuthenticate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_ManageChannel_Proxy(ISCardISO7816 *This,BYTE byChannelState,BYTE byChannel,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_ManageChannel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_PutData_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_PutData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_ReadBinary_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LONG lBytesToRead,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_ReadBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_ReadRecord_Proxy(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LONG lBytesToRead,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_ReadRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_SelectFile_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LONG lBytesToRead,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_SelectFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_SetDefaultClassId_Proxy(ISCardISO7816 *This,BYTE byClass);
  void __RPC_STUB ISCardISO7816_SetDefaultClassId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_UpdateBinary_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_UpdateBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_UpdateRecord_Proxy(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_UpdateRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_Verify_Proxy(ISCardISO7816 *This,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_Verify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_WriteBinary_Proxy(ISCardISO7816 *This,BYTE byP1,BYTE byP2,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_WriteBinary_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardISO7816_WriteRecord_Proxy(ISCardISO7816 *This,BYTE byRecordId,BYTE byRefCtrl,LPBYTEBUFFER pData,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCardISO7816_WriteRecord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARD_DEFINED
#define _LPSCARD_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0247_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0247_v0_0_s_ifspec;
#ifndef __ISCard_INTERFACE_DEFINED__
#define __ISCard_INTERFACE_DEFINED__
  typedef ISCard *LPSCARD;
  typedef LPSCARD LPSMARTCARD;

  EXTERN_C const IID IID_ISCard;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCard : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Atr(LPBYTEBUFFER *ppAtr) = 0;
    virtual HRESULT WINAPI get_CardHandle(HSCARD *pHandle) = 0;
    virtual HRESULT WINAPI get_Context(HSCARDCONTEXT *pContext) = 0;
    virtual HRESULT WINAPI get_Protocol(SCARD_PROTOCOLS *pProtocol) = 0;
    virtual HRESULT WINAPI get_Status(SCARD_STATES *pStatus) = 0;
    virtual HRESULT WINAPI AttachByHandle(HSCARD hCard) = 0;
    virtual HRESULT WINAPI AttachByReader(BSTR bstrReaderName,SCARD_SHARE_MODES ShareMode = EXCLUSIVE,SCARD_PROTOCOLS PrefProtocol = T0) = 0;
    virtual HRESULT WINAPI Detach(SCARD_DISPOSITIONS Disposition = LEAVE) = 0;
    virtual HRESULT WINAPI LockSCard(void) = 0;
    virtual HRESULT WINAPI ReAttach(SCARD_SHARE_MODES ShareMode = EXCLUSIVE,SCARD_DISPOSITIONS InitState = LEAVE) = 0;
    virtual HRESULT WINAPI Transaction(LPSCARDCMD *ppCmd) = 0;
    virtual HRESULT WINAPI UnlockSCard(SCARD_DISPOSITIONS Disposition = LEAVE) = 0;
  };
#else
  typedef struct ISCardVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCard *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCard *This);
      ULONG (WINAPI *Release)(ISCard *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCard *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCard *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCard *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCard *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Atr)(ISCard *This,LPBYTEBUFFER *ppAtr);
      HRESULT (WINAPI *get_CardHandle)(ISCard *This,HSCARD *pHandle);
      HRESULT (WINAPI *get_Context)(ISCard *This,HSCARDCONTEXT *pContext);
      HRESULT (WINAPI *get_Protocol)(ISCard *This,SCARD_PROTOCOLS *pProtocol);
      HRESULT (WINAPI *get_Status)(ISCard *This,SCARD_STATES *pStatus);
      HRESULT (WINAPI *AttachByHandle)(ISCard *This,HSCARD hCard);
      HRESULT (WINAPI *AttachByReader)(ISCard *This,BSTR bstrReaderName,SCARD_SHARE_MODES ShareMode,SCARD_PROTOCOLS PrefProtocol);
      HRESULT (WINAPI *Detach)(ISCard *This,SCARD_DISPOSITIONS Disposition);
      HRESULT (WINAPI *LockSCard)(ISCard *This);
      HRESULT (WINAPI *ReAttach)(ISCard *This,SCARD_SHARE_MODES ShareMode,SCARD_DISPOSITIONS InitState);
      HRESULT (WINAPI *Transaction)(ISCard *This,LPSCARDCMD *ppCmd);
      HRESULT (WINAPI *UnlockSCard)(ISCard *This,SCARD_DISPOSITIONS Disposition);
    END_INTERFACE
  } ISCardVtbl;
  struct ISCard {
    CONST_VTBL struct ISCardVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCard_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCard_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCard_Release(This) (This)->lpVtbl->Release(This)
#define ISCard_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCard_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCard_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCard_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCard_get_Atr(This,ppAtr) (This)->lpVtbl->get_Atr(This,ppAtr)
#define ISCard_get_CardHandle(This,pHandle) (This)->lpVtbl->get_CardHandle(This,pHandle)
#define ISCard_get_Context(This,pContext) (This)->lpVtbl->get_Context(This,pContext)
#define ISCard_get_Protocol(This,pProtocol) (This)->lpVtbl->get_Protocol(This,pProtocol)
#define ISCard_get_Status(This,pStatus) (This)->lpVtbl->get_Status(This,pStatus)
#define ISCard_AttachByHandle(This,hCard) (This)->lpVtbl->AttachByHandle(This,hCard)
#define ISCard_AttachByReader(This,bstrReaderName,ShareMode,PrefProtocol) (This)->lpVtbl->AttachByReader(This,bstrReaderName,ShareMode,PrefProtocol)
#define ISCard_Detach(This,Disposition) (This)->lpVtbl->Detach(This,Disposition)
#define ISCard_LockSCard(This) (This)->lpVtbl->LockSCard(This)
#define ISCard_ReAttach(This,ShareMode,InitState) (This)->lpVtbl->ReAttach(This,ShareMode,InitState)
#define ISCard_Transaction(This,ppCmd) (This)->lpVtbl->Transaction(This,ppCmd)
#define ISCard_UnlockSCard(This,Disposition) (This)->lpVtbl->UnlockSCard(This,Disposition)
#endif
#endif
  HRESULT WINAPI ISCard_get_Atr_Proxy(ISCard *This,LPBYTEBUFFER *ppAtr);
  void __RPC_STUB ISCard_get_Atr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_get_CardHandle_Proxy(ISCard *This,HSCARD *pHandle);
  void __RPC_STUB ISCard_get_CardHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_get_Context_Proxy(ISCard *This,HSCARDCONTEXT *pContext);
  void __RPC_STUB ISCard_get_Context_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_get_Protocol_Proxy(ISCard *This,SCARD_PROTOCOLS *pProtocol);
  void __RPC_STUB ISCard_get_Protocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_get_Status_Proxy(ISCard *This,SCARD_STATES *pStatus);
  void __RPC_STUB ISCard_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_AttachByHandle_Proxy(ISCard *This,HSCARD hCard);
  void __RPC_STUB ISCard_AttachByHandle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_AttachByReader_Proxy(ISCard *This,BSTR bstrReaderName,SCARD_SHARE_MODES ShareMode,SCARD_PROTOCOLS PrefProtocol);
  void __RPC_STUB ISCard_AttachByReader_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_Detach_Proxy(ISCard *This,SCARD_DISPOSITIONS Disposition);
  void __RPC_STUB ISCard_Detach_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_LockSCard_Proxy(ISCard *This);
  void __RPC_STUB ISCard_LockSCard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_ReAttach_Proxy(ISCard *This,SCARD_SHARE_MODES ShareMode,SCARD_DISPOSITIONS InitState);
  void __RPC_STUB ISCard_ReAttach_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_Transaction_Proxy(ISCard *This,LPSCARDCMD *ppCmd);
  void __RPC_STUB ISCard_Transaction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCard_UnlockSCard_Proxy(ISCard *This,SCARD_DISPOSITIONS Disposition);
  void __RPC_STUB ISCard_UnlockSCard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARDDATABASE_DEFINED
#define _LPSCARDDATABASE_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0248_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0248_v0_0_s_ifspec;
#ifndef __ISCardDatabase_INTERFACE_DEFINED__
#define __ISCardDatabase_INTERFACE_DEFINED__
  typedef ISCardDatabase *LPSCARDDATABASE;

  EXTERN_C const IID IID_ISCardDatabase;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCardDatabase : public IDispatch {
  public:
    virtual HRESULT WINAPI GetProviderCardId(BSTR bstrCardName,LPGUID *ppguidProviderId) = 0;
    virtual HRESULT WINAPI ListCardInterfaces(BSTR bstrCardName,LPSAFEARRAY *ppInterfaceGuids) = 0;
    virtual HRESULT WINAPI ListCards(LPBYTEBUFFER pAtr,LPSAFEARRAY pInterfaceGuids,__LONG32 localeId,LPSAFEARRAY *ppCardNames) = 0;
    virtual HRESULT WINAPI ListReaderGroups(__LONG32 localeId,LPSAFEARRAY *ppReaderGroups) = 0;
    virtual HRESULT WINAPI ListReaders(__LONG32 localeId,LPSAFEARRAY *ppReaders) = 0;
  };
#else
  typedef struct ISCardDatabaseVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCardDatabase *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCardDatabase *This);
      ULONG (WINAPI *Release)(ISCardDatabase *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCardDatabase *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCardDatabase *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCardDatabase *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCardDatabase *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetProviderCardId)(ISCardDatabase *This,BSTR bstrCardName,LPGUID *ppguidProviderId);
      HRESULT (WINAPI *ListCardInterfaces)(ISCardDatabase *This,BSTR bstrCardName,LPSAFEARRAY *ppInterfaceGuids);
      HRESULT (WINAPI *ListCards)(ISCardDatabase *This,LPBYTEBUFFER pAtr,LPSAFEARRAY pInterfaceGuids,__LONG32 localeId,LPSAFEARRAY *ppCardNames);
      HRESULT (WINAPI *ListReaderGroups)(ISCardDatabase *This,__LONG32 localeId,LPSAFEARRAY *ppReaderGroups);
      HRESULT (WINAPI *ListReaders)(ISCardDatabase *This,__LONG32 localeId,LPSAFEARRAY *ppReaders);
    END_INTERFACE
  } ISCardDatabaseVtbl;
  struct ISCardDatabase {
    CONST_VTBL struct ISCardDatabaseVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCardDatabase_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCardDatabase_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCardDatabase_Release(This) (This)->lpVtbl->Release(This)
#define ISCardDatabase_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCardDatabase_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCardDatabase_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCardDatabase_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCardDatabase_GetProviderCardId(This,bstrCardName,ppguidProviderId) (This)->lpVtbl->GetProviderCardId(This,bstrCardName,ppguidProviderId)
#define ISCardDatabase_ListCardInterfaces(This,bstrCardName,ppInterfaceGuids) (This)->lpVtbl->ListCardInterfaces(This,bstrCardName,ppInterfaceGuids)
#define ISCardDatabase_ListCards(This,pAtr,pInterfaceGuids,localeId,ppCardNames) (This)->lpVtbl->ListCards(This,pAtr,pInterfaceGuids,localeId,ppCardNames)
#define ISCardDatabase_ListReaderGroups(This,localeId,ppReaderGroups) (This)->lpVtbl->ListReaderGroups(This,localeId,ppReaderGroups)
#define ISCardDatabase_ListReaders(This,localeId,ppReaders) (This)->lpVtbl->ListReaders(This,localeId,ppReaders)
#endif
#endif
  HRESULT WINAPI ISCardDatabase_GetProviderCardId_Proxy(ISCardDatabase *This,BSTR bstrCardName,LPGUID *ppguidProviderId);
  void __RPC_STUB ISCardDatabase_GetProviderCardId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardDatabase_ListCardInterfaces_Proxy(ISCardDatabase *This,BSTR bstrCardName,LPSAFEARRAY *ppInterfaceGuids);
  void __RPC_STUB ISCardDatabase_ListCardInterfaces_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardDatabase_ListCards_Proxy(ISCardDatabase *This,LPBYTEBUFFER pAtr,LPSAFEARRAY pInterfaceGuids,__LONG32 localeId,LPSAFEARRAY *ppCardNames);
  void __RPC_STUB ISCardDatabase_ListCards_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardDatabase_ListReaderGroups_Proxy(ISCardDatabase *This,__LONG32 localeId,LPSAFEARRAY *ppReaderGroups);
  void __RPC_STUB ISCardDatabase_ListReaderGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardDatabase_ListReaders_Proxy(ISCardDatabase *This,__LONG32 localeId,LPSAFEARRAY *ppReaders);
  void __RPC_STUB ISCardDatabase_ListReaders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef _LPSCARDLOCATE_DEFINED
#define _LPSCARDLOCATE_DEFINED
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0249_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0249_v0_0_s_ifspec;
#ifndef __ISCardLocate_INTERFACE_DEFINED__
#define __ISCardLocate_INTERFACE_DEFINED__
  typedef ISCardLocate *LPSCARDLOCATE;
  typedef LPSCARDLOCATE LPSCARDLOC;

  EXTERN_C const IID IID_ISCardLocate;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISCardLocate : public IDispatch {
  public:
    virtual HRESULT WINAPI ConfigureCardGuidSearch(LPSAFEARRAY pCardGuids,LPSAFEARRAY pGroupNames = 0,BSTR bstrTitle = L"",LONG lFlags = 1) = 0;
    virtual HRESULT WINAPI ConfigureCardNameSearch(LPSAFEARRAY pCardNames,LPSAFEARRAY pGroupNames = 0,BSTR bstrTitle = L"",LONG lFlags = 1) = 0;
    virtual HRESULT WINAPI FindCard(SCARD_SHARE_MODES ShareMode,SCARD_PROTOCOLS Protocols,LONG lFlags,LPSCARDINFO *ppCardInfo) = 0;
  };
#else
  typedef struct ISCardLocateVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISCardLocate *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISCardLocate *This);
      ULONG (WINAPI *Release)(ISCardLocate *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISCardLocate *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISCardLocate *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISCardLocate *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISCardLocate *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ConfigureCardGuidSearch)(ISCardLocate *This,LPSAFEARRAY pCardGuids,LPSAFEARRAY pGroupNames,BSTR bstrTitle,LONG lFlags);
      HRESULT (WINAPI *ConfigureCardNameSearch)(ISCardLocate *This,LPSAFEARRAY pCardNames,LPSAFEARRAY pGroupNames,BSTR bstrTitle,LONG lFlags);
      HRESULT (WINAPI *FindCard)(ISCardLocate *This,SCARD_SHARE_MODES ShareMode,SCARD_PROTOCOLS Protocols,LONG lFlags,LPSCARDINFO *ppCardInfo);
    END_INTERFACE
  } ISCardLocateVtbl;
  struct ISCardLocate {
    CONST_VTBL struct ISCardLocateVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISCardLocate_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISCardLocate_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISCardLocate_Release(This) (This)->lpVtbl->Release(This)
#define ISCardLocate_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISCardLocate_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISCardLocate_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISCardLocate_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISCardLocate_ConfigureCardGuidSearch(This,pCardGuids,pGroupNames,bstrTitle,lFlags) (This)->lpVtbl->ConfigureCardGuidSearch(This,pCardGuids,pGroupNames,bstrTitle,lFlags)
#define ISCardLocate_ConfigureCardNameSearch(This,pCardNames,pGroupNames,bstrTitle,lFlags) (This)->lpVtbl->ConfigureCardNameSearch(This,pCardNames,pGroupNames,bstrTitle,lFlags)
#define ISCardLocate_FindCard(This,ShareMode,Protocols,lFlags,ppCardInfo) (This)->lpVtbl->FindCard(This,ShareMode,Protocols,lFlags,ppCardInfo)
#endif
#endif
  HRESULT WINAPI ISCardLocate_ConfigureCardGuidSearch_Proxy(ISCardLocate *This,LPSAFEARRAY pCardGuids,LPSAFEARRAY pGroupNames,BSTR bstrTitle,LONG lFlags);
  void __RPC_STUB ISCardLocate_ConfigureCardGuidSearch_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardLocate_ConfigureCardNameSearch_Proxy(ISCardLocate *This,LPSAFEARRAY pCardNames,LPSAFEARRAY pGroupNames,BSTR bstrTitle,LONG lFlags);
  void __RPC_STUB ISCardLocate_ConfigureCardNameSearch_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISCardLocate_FindCard_Proxy(ISCardLocate *This,SCARD_SHARE_MODES ShareMode,SCARD_PROTOCOLS Protocols,LONG lFlags,LPSCARDINFO *ppCardInfo);
  void __RPC_STUB ISCardLocate_FindCard_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0250_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_scardssp_0250_v0_0_s_ifspec;
#ifndef __SCARDSSPLib_LIBRARY_DEFINED__
#define __SCARDSSPLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_SCARDSSPLib;
  EXTERN_C const CLSID CLSID_CByteBuffer;
#ifdef __cplusplus
  class CByteBuffer;
#endif
  EXTERN_C const CLSID CLSID_CSCardTypeConv;
#ifdef __cplusplus
  class CSCardTypeConv;
#endif
  EXTERN_C const CLSID CLSID_CSCardCmd;
#ifdef __cplusplus
  class CSCardCmd;
#endif
  EXTERN_C const CLSID CLSID_CSCardISO7816;
#ifdef __cplusplus
  class CSCardISO7816;
#endif
  EXTERN_C const CLSID CLSID_CSCard;
#ifdef __cplusplus
  class CSCard;
#endif
  EXTERN_C const CLSID CLSID_CSCardDatabase;
#ifdef __cplusplus
  class CSCardDatabase;
#endif
  EXTERN_C const CLSID CLSID_CSCardLocate;
#ifdef __cplusplus
  class CSCardLocate;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API HGLOBAL_UserSize(ULONG *,ULONG,HGLOBAL *);
  unsigned char *__RPC_API HGLOBAL_UserMarshal(ULONG *,unsigned char *,HGLOBAL *);
  unsigned char *__RPC_API HGLOBAL_UserUnmarshal(ULONG *,unsigned char *,HGLOBAL *);
  void __RPC_API HGLOBAL_UserFree(ULONG *,HGLOBAL *);
  ULONG __RPC_API LPSAFEARRAY_UserSize(ULONG *,ULONG,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserMarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  unsigned char *__RPC_API LPSAFEARRAY_UserUnmarshal(ULONG *,unsigned char *,LPSAFEARRAY *);
  void __RPC_API LPSAFEARRAY_UserFree(ULONG *,LPSAFEARRAY *);

#ifdef __cplusplus
}
#endif
#endif
