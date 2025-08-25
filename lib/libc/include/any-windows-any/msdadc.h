/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
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

#ifndef __msdadc_h__
#define __msdadc_h__

#ifndef __IDataConvert_FWD_DEFINED__
#define __IDataConvert_FWD_DEFINED__
typedef struct IDataConvert IDataConvert;
#endif

#ifndef __IDCInfo_FWD_DEFINED__
#define __IDCInfo_FWD_DEFINED__
typedef struct IDCInfo IDCInfo;
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "oledb.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include <pshpack8.h>
#undef OLEDBDECLSPEC
#define OLEDBDECLSPEC __declspec(selectany)

  extern RPC_IF_HANDLE __MIDL_itf_msdadc_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdadc_0000_v0_0_s_ifspec;

#ifndef __IDataConvert_INTERFACE_DEFINED__
#define __IDataConvert_INTERFACE_DEFINED__

  typedef DWORD DBDATACONVERT;

  enum DBDATACONVERTENUM {
    DBDATACONVERT_DEFAULT = 0,DBDATACONVERT_SETDATABEHAVIOR = 0x1,DBDATACONVERT_LENGTHFROMNTS = 0x2,DBDATACONVERT_DSTISFIXEDLENGTH = 0x4,
    DBDATACONVERT_DECIMALSCALE = 0x8
  };

  EXTERN_C const IID IID_IDataConvert;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDataConvert : public IUnknown {
  public:
    virtual HRESULT WINAPI DataConvert(DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH cbSrcLength,DBLENGTH *pcbDstLength,void *pSrc,void *pDst,DBLENGTH cbDstMaxLength,DBSTATUS dbsSrcStatus,DBSTATUS *pdbsStatus,BYTE bPrecision,BYTE bScale,DBDATACONVERT dwFlags) = 0;
    virtual HRESULT WINAPI CanConvert(DBTYPE wSrcType,DBTYPE wDstType) = 0;
    virtual HRESULT WINAPI GetConversionSize(DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH *pcbSrcLength,DBLENGTH *pcbDstLength,void *pSrc) = 0;
  };
#else
  typedef struct IDataConvertVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDataConvert *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDataConvert *This);
      ULONG (WINAPI *Release)(IDataConvert *This);
      HRESULT (WINAPI *DataConvert)(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH cbSrcLength,DBLENGTH *pcbDstLength,void *pSrc,void *pDst,DBLENGTH cbDstMaxLength,DBSTATUS dbsSrcStatus,DBSTATUS *pdbsStatus,BYTE bPrecision,BYTE bScale,DBDATACONVERT dwFlags);
      HRESULT (WINAPI *CanConvert)(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType);
      HRESULT (WINAPI *GetConversionSize)(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH *pcbSrcLength,DBLENGTH *pcbDstLength,void *pSrc);
    END_INTERFACE
  } IDataConvertVtbl;
  struct IDataConvert {
    CONST_VTBL struct IDataConvertVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDataConvert_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDataConvert_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDataConvert_Release(This) (This)->lpVtbl->Release(This)
#define IDataConvert_DataConvert(This,wSrcType,wDstType,cbSrcLength,pcbDstLength,pSrc,pDst,cbDstMaxLength,dbsSrcStatus,pdbsStatus,bPrecision,bScale,dwFlags) (This)->lpVtbl->DataConvert(This,wSrcType,wDstType,cbSrcLength,pcbDstLength,pSrc,pDst,cbDstMaxLength,dbsSrcStatus,pdbsStatus,bPrecision,bScale,dwFlags)
#define IDataConvert_CanConvert(This,wSrcType,wDstType) (This)->lpVtbl->CanConvert(This,wSrcType,wDstType)
#define IDataConvert_GetConversionSize(This,wSrcType,wDstType,pcbSrcLength,pcbDstLength,pSrc) (This)->lpVtbl->GetConversionSize(This,wSrcType,wDstType,pcbSrcLength,pcbDstLength,pSrc)
#endif
#endif
  HRESULT WINAPI IDataConvert_DataConvert_Proxy(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH cbSrcLength,DBLENGTH *pcbDstLength,void *pSrc,void *pDst,DBLENGTH cbDstMaxLength,DBSTATUS dbsSrcStatus,DBSTATUS *pdbsStatus,BYTE bPrecision,BYTE bScale,DBDATACONVERT dwFlags);
  void __RPC_STUB IDataConvert_DataConvert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataConvert_CanConvert_Proxy(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType);
  void __RPC_STUB IDataConvert_CanConvert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDataConvert_GetConversionSize_Proxy(IDataConvert *This,DBTYPE wSrcType,DBTYPE wDstType,DBLENGTH *pcbSrcLength,DBLENGTH *pcbDstLength,void *pSrc);
  void __RPC_STUB IDataConvert_GetConversionSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDCInfo_INTERFACE_DEFINED__
#define __IDCInfo_INTERFACE_DEFINED__
  typedef DWORD DCINFOTYPE;

  enum DCINFOTYPEENUM {
    DCINFOTYPE_VERSION = 1
  };
  typedef struct tagDCINFO {
    DCINFOTYPE eInfoType;
    VARIANT vData;
  } DCINFO;

  EXTERN_C const IID IID_IDCInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDCInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetInfo(ULONG cInfo,DCINFOTYPE rgeInfoType[],DCINFO **prgInfo) = 0;
    virtual HRESULT WINAPI SetInfo(ULONG cInfo,DCINFO rgInfo[]) = 0;
  };
#else
  typedef struct IDCInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDCInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDCInfo *This);
      ULONG (WINAPI *Release)(IDCInfo *This);
      HRESULT (WINAPI *GetInfo)(IDCInfo *This,ULONG cInfo,DCINFOTYPE rgeInfoType[],DCINFO **prgInfo);
      HRESULT (WINAPI *SetInfo)(IDCInfo *This,ULONG cInfo,DCINFO rgInfo[]);
    END_INTERFACE
  } IDCInfoVtbl;
  struct IDCInfo {
    CONST_VTBL struct IDCInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDCInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDCInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDCInfo_Release(This) (This)->lpVtbl->Release(This)
#define IDCInfo_GetInfo(This,cInfo,rgeInfoType,prgInfo) (This)->lpVtbl->GetInfo(This,cInfo,rgeInfoType,prgInfo)
#define IDCInfo_SetInfo(This,cInfo,rgInfo) (This)->lpVtbl->SetInfo(This,cInfo,rgInfo)
#endif
#endif
  HRESULT WINAPI IDCInfo_GetInfo_Proxy(IDCInfo *This,ULONG cInfo,DCINFOTYPE rgeInfoType[],DCINFO **prgInfo);
  void __RPC_STUB IDCInfo_GetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDCInfo_SetInfo_Proxy(IDCInfo *This,ULONG cInfo,DCINFO rgInfo[]);
  void __RPC_STUB IDCInfo_SetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern const GUID OLEDBDECLSPEC IID_IDataConvert = { 0x0c733a8d,0x2a1c,0x11ce,{ 0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d } };
  extern const GUID OLEDBDECLSPEC IID_IDCInfo = { 0x0c733a9c,0x2a1c,0x11ce,{ 0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d } };

#include <poppack.h>

  extern RPC_IF_HANDLE __MIDL_itf_msdadc_0360_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdadc_0360_v0_0_s_ifspec;

  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
