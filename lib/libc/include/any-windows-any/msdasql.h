/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSDASQL_H_
#define _MSDASQL_H_

#undef MSDASQLDECLSPEC
#define MSDASQLDECLSPEC __declspec(selectany)

#ifdef DBINITCONSTANTS
extern const MSDASQLDECLSPEC GUID IID_ISQLRequestDiagFields = { 0x228972f0,0xb5ff,0x11d0,{ 0x8a,0x80,0x0,0xc0,0x4f,0xd6,0x11,0xcd } };
extern const MSDASQLDECLSPEC GUID IID_ISQLGetDiagField = { 0x228972f1,0xb5ff,0x11d0,{ 0x8a,0x80,0x0,0xc0,0x4f,0xd6,0x11,0xcd } };
extern const MSDASQLDECLSPEC GUID IID_IRowsetChangeExtInfo = {0x0C733A8F,0x2A1C,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}};
extern const MSDASQLDECLSPEC GUID CLSID_MSDASQL = {0xC8B522CB,0x5CF3,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}};
extern const MSDASQLDECLSPEC GUID CLSID_MSDASQL_ENUMERATOR = {0xC8B522CD,0x5CF3,0x11CE,{0xAD,0xE5,0x00,0xAA,0x00,0x44,0x77,0x3D}};
#else
extern const GUID IID_ISQLRequestDiagFields;
extern const GUID IID_ISQLGetDiagField;
extern const GUID IID_IRowsetChangeExtInfo;
extern const GUID CLSID_MSDASQL;
extern const GUID CLSID_MSDASQL_ENUMERATOR;
#endif

#ifdef DBINITCONSTANTS
extern const MSDASQLDECLSPEC GUID DBPROPSET_PROVIDERDATASOURCEINFO = {0x497c60e0,0x7123,0x11cf,{0xb1,0x71,0x0,0xaa,0x0,0x57,0x59,0x9e}};
extern const MSDASQLDECLSPEC GUID DBPROPSET_PROVIDERROWSET = {0x497c60e1,0x7123,0x11cf,{0xb1,0x71,0x0,0xaa,0x0,0x57,0x59,0x9e}};
extern const MSDASQLDECLSPEC GUID DBPROPSET_PROVIDERDBINIT = {0x497c60e2,0x7123,0x11cf,{0xb1,0x71,0x0,0xaa,0x0,0x57,0x59,0x9e}};
extern const MSDASQLDECLSPEC GUID DBPROPSET_PROVIDERSTMTATTR = {0x497c60e3,0x7123,0x11cf,{0xb1,0x71,0x0,0xaa,0x0,0x57,0x59,0x9e}};
extern const MSDASQLDECLSPEC GUID DBPROPSET_PROVIDERCONNATTR = {0x497c60e4,0x7123,0x11cf,{0xb1,0x71,0x0,0xaa,0x0,0x57,0x59,0x9e}};
#else
extern const GUID DBPROPSET_PROVIDERDATASOURCEINFO;
extern const GUID DBPROPSET_PROVIDERROWSET;
extern const GUID DBPROPSET_PROVIDERDBINIT;
extern const GUID DBPROPSET_PROVIDERSTMTATTR;
extern const GUID DBPROPSET_PROVIDERCONNATTR;
#endif

#define KAGPROP_QUERYBASEDUPDATES 2
#define KAGPROP_MARSHALLABLE 3
#define KAGPROP_POSITIONONNEWROW 4
#define KAGPROP_IRowsetChangeExtInfo 5
#define KAGPROP_CURSOR 6
#define KAGPROP_CONCURRENCY 7
#define KAGPROP_BLOBSONFOCURSOR 8
#define KAGPROP_INCLUDENONEXACT 9
#define KAGPROP_FORCESSFIREHOSEMODE 10
#define KAGPROP_FORCENOPARAMETERREBIND 11
#define KAGPROP_FORCENOPREPARE 12
#define KAGPROP_FORCENOREEXECUTE 13

#define KAGPROP_ACCESSIBLEPROCEDURES 2
#define KAGPROP_ACCESSIBLETABLES 3
#define KAGPROP_ODBCSQLOPTIEF 4
#define KAGPROP_OJCAPABILITY 5
#define KAGPROP_PROCEDURES 6
#define KAGPROP_DRIVERNAME 7
#define KAGPROP_DRIVERVER 8
#define KAGPROP_DRIVERODBCVER 9
#define KAGPROP_LIKEESCAPECLAUSE 10
#define KAGPROP_SPECIALCHARACTERS 11
#define KAGPROP_MAXCOLUMNSINGROUPBY 12
#define KAGPROP_MAXCOLUMNSININDEX 13
#define KAGPROP_MAXCOLUMNSINORDERBY 14
#define KAGPROP_MAXCOLUMNSINSELECT 15
#define KAGPROP_MAXCOLUMNSINTABLE 16
#define KAGPROP_NUMERICFUNCTIONS 17
#define KAGPROP_ODBCSQLCONFORMANCE 18
#define KAGPROP_OUTERJOINS 19
#define KAGPROP_STRINGFUNCTIONS 20
#define KAGPROP_SYSTEMFUNCTIONS 21
#define KAGPROP_TIMEDATEFUNCTIONS 22
#define KAGPROP_FILEUSAGE 23
#define KAGPROP_ACTIVESTATEMENTS 24

#define KAGPROP_AUTH_TRUSTEDCONNECTION 2
#define KAGPROP_AUTH_SERVERINTEGRATED 3

#define KAGPROPVAL_CONCUR_ROWVER 0x00000001
#define KAGPROPVAL_CONCUR_VALUES 0x00000002
#define KAGPROPVAL_CONCUR_LOCK 0x00000004
#define KAGPROPVAL_CONCUR_READ_ONLY 0x00000008

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

#ifndef __rstcei_h__
#define __rstcei_h__

#ifndef __IRowsetChangeExtInfo_FWD_DEFINED__
#define __IRowsetChangeExtInfo_FWD_DEFINED__
typedef struct IRowsetChangeExtInfo IRowsetChangeExtInfo;
#endif

#include "oledb.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IRowsetChangeExtInfo_INTERFACE_DEFINED__
#define __IRowsetChangeExtInfo_INTERFACE_DEFINED__

  EXTERN_C const IID IID_IRowsetChangeExtInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetChangeExtInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetOriginalRow(HCHAPTER hReserved,HROW hRow,HROW *phRowOriginal) = 0;
    virtual HRESULT WINAPI GetPendingColumns(HCHAPTER hReserved,HROW hRow,ULONG cColumnOrdinals,const ULONG rgiOrdinals[],DBPENDINGSTATUS rgColumnStatus[]) = 0;
  };
#else
  typedef struct IRowsetChangeExtInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetChangeExtInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetChangeExtInfo *This);
      ULONG (WINAPI *Release)(IRowsetChangeExtInfo *This);
      HRESULT (WINAPI *GetOriginalRow)(IRowsetChangeExtInfo *This,HCHAPTER hReserved,HROW hRow,HROW *phRowOriginal);
      HRESULT (WINAPI *GetPendingColumns)(IRowsetChangeExtInfo *This,HCHAPTER hReserved,HROW hRow,ULONG cColumnOrdinals,const ULONG rgiOrdinals[],DBPENDINGSTATUS rgColumnStatus[]);
    END_INTERFACE
  } IRowsetChangeExtInfoVtbl;
  struct IRowsetChangeExtInfo {
    CONST_VTBL struct IRowsetChangeExtInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetChangeExtInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetChangeExtInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetChangeExtInfo_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetChangeExtInfo_GetOriginalRow(This,hReserved,hRow,phRowOriginal) (This)->lpVtbl->GetOriginalRow(This,hReserved,hRow,phRowOriginal)
#define IRowsetChangeExtInfo_GetPendingColumns(This,hReserved,hRow,cColumnOrdinals,rgiOrdinals,rgColumnStatus) (This)->lpVtbl->GetPendingColumns(This,hReserved,hRow,cColumnOrdinals,rgiOrdinals,rgColumnStatus)
#endif
#endif
  HRESULT WINAPI IRowsetChangeExtInfo_GetOriginalRow_Proxy(IRowsetChangeExtInfo *This,HCHAPTER hReserved,HROW hRow,HROW *phRowOriginal);
  void __RPC_STUB IRowsetChangeExtInfo_GetOriginalRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetChangeExtInfo_GetPendingColumns_Proxy(IRowsetChangeExtInfo *This,HCHAPTER hReserved,HROW hRow,ULONG cColumnOrdinals,const ULONG rgiOrdinals[],DBPENDINGSTATUS rgColumnStatus[]);
  void __RPC_STUB IRowsetChangeExtInfo_GetPendingColumns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif

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

#ifndef __kagdiag_h__
#define __kagdiag_h__

#ifndef __ISQLRequestDiagFields_FWD_DEFINED__
#define __ISQLRequestDiagFields_FWD_DEFINED__
typedef struct ISQLRequestDiagFields ISQLRequestDiagFields;
#endif

#ifndef __ISQLGetDiagField_FWD_DEFINED__
#define __ISQLGetDiagField_FWD_DEFINED__
typedef struct ISQLGetDiagField ISQLGetDiagField;
#endif

#include "unknwn.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  enum KAGREQDIAGFLAGSENUM {
    KAGREQDIAGFLAGS_HEADER = 0x1,KAGREQDIAGFLAGS_RECORD = 0x2
  };

  typedef struct tagKAGREQDIAG {
    ULONG ulDiagFlags;
    VARTYPE vt;
    SHORT sDiagField;
  } KAGREQDIAG;

  typedef struct tagKAGGETDIAG {
    ULONG ulSize;
    VARIANTARG vDiagInfo;
    SHORT sDiagField;
  } KAGGETDIAG;

  extern RPC_IF_HANDLE __MIDL_itf_kagdiag_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_kagdiag_0000_v0_0_s_ifspec;

#ifndef __ISQLRequestDiagFields_INTERFACE_DEFINED__
#define __ISQLRequestDiagFields_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISQLRequestDiagFields;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISQLRequestDiagFields : public IUnknown {
  public:
    virtual HRESULT WINAPI RequestDiagFields(ULONG cDiagFields,KAGREQDIAG rgDiagFields[]) = 0;
  };
#else
  typedef struct ISQLRequestDiagFieldsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISQLRequestDiagFields *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISQLRequestDiagFields *This);
      ULONG (WINAPI *Release)(ISQLRequestDiagFields *This);
      HRESULT (WINAPI *RequestDiagFields)(ISQLRequestDiagFields *This,ULONG cDiagFields,KAGREQDIAG rgDiagFields[]);
    END_INTERFACE
  } ISQLRequestDiagFieldsVtbl;
  struct ISQLRequestDiagFields {
    CONST_VTBL struct ISQLRequestDiagFieldsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISQLRequestDiagFields_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISQLRequestDiagFields_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISQLRequestDiagFields_Release(This) (This)->lpVtbl->Release(This)
#define ISQLRequestDiagFields_RequestDiagFields(This,cDiagFields,rgDiagFields) (This)->lpVtbl->RequestDiagFields(This,cDiagFields,rgDiagFields)
#endif
#endif
  HRESULT WINAPI ISQLRequestDiagFields_RequestDiagFields_Proxy(ISQLRequestDiagFields *This,ULONG cDiagFields,KAGREQDIAG rgDiagFields[]);
  void __RPC_STUB ISQLRequestDiagFields_RequestDiagFields_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISQLGetDiagField_INTERFACE_DEFINED__
#define __ISQLGetDiagField_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISQLGetDiagField;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISQLGetDiagField : public IUnknown {
  public:
    virtual HRESULT WINAPI GetDiagField(KAGGETDIAG *pDiagInfo) = 0;
  };
#else
  typedef struct ISQLGetDiagFieldVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISQLGetDiagField *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISQLGetDiagField *This);
      ULONG (WINAPI *Release)(ISQLGetDiagField *This);
      HRESULT (WINAPI *GetDiagField)(ISQLGetDiagField *This,KAGGETDIAG *pDiagInfo);
    END_INTERFACE
  } ISQLGetDiagFieldVtbl;
  struct ISQLGetDiagField {
    CONST_VTBL struct ISQLGetDiagFieldVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISQLGetDiagField_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISQLGetDiagField_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISQLGetDiagField_Release(This) (This)->lpVtbl->Release(This)
#define ISQLGetDiagField_GetDiagField(This,pDiagInfo) (This)->lpVtbl->GetDiagField(This,pDiagInfo)
#endif
#endif
  HRESULT WINAPI ISQLGetDiagField_GetDiagField_Proxy(ISQLGetDiagField *This,KAGGETDIAG *pDiagInfo);
  void __RPC_STUB ISQLGetDiagField_GetDiagField_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
#endif
