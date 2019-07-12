/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _SQLOLEDB_H_
#define _SQLOLEDB_H_

#include <oledb.h>

#ifdef DBINITCONSTANTS
extern const GUID CLSID_SQLOLEDB = {0xc7ff16c,0x38e3,0x11d0,{0x97,0xab,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID CLSID_SQLOLEDB_ERROR = {0xc0932c62,0x38e5,0x11d0,{0x97,0xab,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID CLSID_SQLOLEDB_ENUMERATOR = {0xdfa22b8e,0xe68d,0x11d0,{0x97,0xe4,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
#else
extern const GUID CLSID_SQLOLEDB;
extern const GUID CLSID_SQLOLEDB_ERROR;
extern const GUID CLSID_SQLOLEDB_ENUMERATOR;
#endif

#ifdef DBINITCONSTANTS
extern const GUID IID_ISQLServerErrorInfo = {0x5cf4ca12,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_IRowsetFastLoad = {0x5cf4ca13,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID IID_IUMSInitialize = {0x5cf4ca14,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};

extern const GUID IID_ISchemaLock = {0x4c2389fb,0x2511,0x11d4,{0xb2,0x58,0x0,0xc0,0x4f,0x79,0x71,0xce}};

extern const GUID DBGUID_MSSQLXML = {0x5d531cb2,0xe6ed,0x11d2,{0xb2,0x52,0x00,0xc0,0x4f,0x68,0x1b,0x71}};
extern const GUID DBGUID_XPATH = {0xec2a4293,0xe898,0x11d2,{0xb1,0xb7,0x00,0xc0,0x4f,0x68,0x0c,0x56}};

extern const IID IID_ICommandStream = {0x0c733abf,0x2a1c,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
extern const IID IID_ISQLXMLHelper = {0xd22a7678,0xf860,0x40cd,{0xa5,0x67,0x15,0x63,0xde,0xb4,0x6d,0x49}};
#else
extern const GUID IID_ISQLServerErrorInfo;
extern const GUID IID_IRowsetFastLoad;
extern const GUID IID_IUMSInitialize;
extern const GUID IID_ISchemaLock;

extern const GUID DBGUID_MSSQLXML;
extern const GUID DBGUID_XPATH;
extern const IID IID_ISQLXMLHelper;
#endif

#ifdef DBINITCONSTANTS
extern const GUID DBSCHEMA_LINKEDSERVERS = {0x9093caf4,0x2eac,0x11d1,{0x98,0x9,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
#else
extern const GUID DBSCHEMA_LINKEDSERVERS;
#endif

#define CRESTRICTIONS_DBSCHEMA_LINKEDSERVERS 1

#ifdef DBINITCONSTANTS
extern const GUID DBPROPSET_SQLSERVERDATASOURCE = {0x28efaee4,0x2d2c,0x11d1,{0x98,0x7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID DBPROPSET_SQLSERVERDATASOURCEINFO = {0xdf10cb94,0x35f6,0x11d2,{0x9c,0x54,0x0,0xc0,0x4f,0x79,0x71,0xd3}};
extern const GUID DBPROPSET_SQLSERVERDBINIT = {0x5cf4ca10,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID DBPROPSET_SQLSERVERROWSET = {0x5cf4ca11,0xef21,0x11d0,{0x97,0xe7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID DBPROPSET_SQLSERVERSESSION = {0x28efaee5,0x2d2c,0x11d1,{0x98,0x7,0x0,0xc0,0x4f,0xc2,0xad,0x98}};
extern const GUID DBPROPSET_SQLSERVERCOLUMN = {0x3b63fb5e,0x3fbb,0x11d3,{0x9f,0x29,0x0,0xc0,0x4f,0x8e,0xe9,0xdc}};
extern const GUID DBPROPSET_SQLSERVERSTREAM = {0x9f79c073,0x8a6d,0x4bca,{0xa8,0xa8,0xc9,0xb7,0x9a,0x9b,0x96,0x2d}};
#else
extern const GUID DBPROPSET_SQLSERVERDATASOURCE;
extern const GUID DBPROPSET_SQLSERVERDATASOURCEINFO;
extern const GUID DBPROPSET_SQLSERVERDBINIT;
extern const GUID DBPROPSET_SQLSERVERROWSET;
extern const GUID DBPROPSET_SQLSERVERSESSION;
extern const GUID DBPROPSET_SQLSERVERCOLUMN;
extern const GUID DBPROPSET_SQLSERVERSTREAM;
#endif

#ifdef DBINITCONSTANTS
extern const DBID DBCOLUMN_SS_COMPFLAGS = {{0x627bd890,0xed54,0x11d2,{0xb9,0x94,0x0,0xc0,0x4f,0x8c,0xa8,0x2c}},DBKIND_GUID_PROPID,(LPOLESTR)100};
extern const DBID DBCOLUMN_SS_SORTID = {{0x627bd890,0xed54,0x11d2,{0xb9,0x94,0x0,0xc0,0x4f,0x8c,0xa8,0x2c}},DBKIND_GUID_PROPID,(LPOLESTR)101};
extern const DBID DBCOLUMN_BASETABLEINSTANCE = {{0x627bd890,0xed54,0x11d2,{0xb9,0x94,0x0,0xc0,0x4f,0x8c,0xa8,0x2c}},DBKIND_GUID_PROPID,(LPOLESTR)102};
extern const DBID DBCOLUMN_SS_TDSCOLLATION = {{0x627bd890,0xed54,0x11d2,{0xb9,0x94,0x0,0xc0,0x4f,0x8c,0xa8,0x2c}},DBKIND_GUID_PROPID,(LPOLESTR)103};
#else
extern const DBID DBCOLUMN_SS_COMPFLAGS;
extern const DBID DBCOLUMN_SS_SORTID;
extern const DBID DBCOLUMN_BASETABLEINSTANCE;
extern const DBID DBCOLUMN_SS_TDSCOLLATION;
#endif

#if (OLEDBVER==0x0210)
#define DBPROP_INIT_GENERALTIMEOUT __MSABI_LONG(0x11c)
#endif

#define SSPROP_ENABLEFASTLOAD 2

#define SSPROP_UNICODELCID 2
#define SSPROP_UNICODECOMPARISONSTYLE 3
#define SSPROP_COLUMNLEVELCOLLATION 4
#define SSPROP_CHARACTERSET 5
#define SSPROP_SORTORDER 6
#define SSPROP_CURRENTCOLLATION 7

#define SSPROP_INIT_CURRENTLANGUAGE 4
#define SSPROP_INIT_NETWORKADDRESS 5
#define SSPROP_INIT_NETWORKLIBRARY 6
#define SSPROP_INIT_USEPROCFORPREP 7
#define SSPROP_INIT_AUTOTRANSLATE 8
#define SSPROP_INIT_PACKETSIZE 9
#define SSPROP_INIT_APPNAME 10
#define SSPROP_INIT_WSID 11
#define SSPROP_INIT_FILENAME 12
#define SSPROP_INIT_ENCRYPT 13
#define SSPROP_AUTH_REPL_SERVER_NAME 14
#define SSPROP_INIT_TAGCOLUMNCOLLATION 15

#define SSPROPVAL_USEPROCFORPREP_OFF 0
#define SSPROPVAL_USEPROCFORPREP_ON 1
#define SSPROPVAL_USEPROCFORPREP_ON_DROP 2

#define SSPROP_QUOTEDCATALOGNAMES 2
#define SSPROP_ALLOWNATIVEVARIANT 3
#define SSPROP_SQLXMLXPROGID 4

#define SSPROP_MAXBLOBLENGTH 8
#define SSPROP_FASTLOADOPTIONS 9
#define SSPROP_FASTLOADKEEPNULLS 10
#define SSPROP_FASTLOADKEEPIDENTITY 11
#define SSPROP_CURSORAUTOFETCH 12
#define SSPROP_DEFERPREPARE 13
#define SSPROP_IRowsetFastLoad 14

#define SSPROP_COL_COLLATIONNAME 14

#define SSPROP_STREAM_MAPPINGSCHEMA 15
#define SSPROP_STREAM_XSL 16
#define SSPROP_STREAM_BASEPATH 17
#define SSPROP_STREAM_COMMANDTYPE 18
#define SSPROP_STREAM_XMLROOT 19
#define SSPROP_STREAM_FLAGS 20
#define SSPROP_STREAM_CONTENTTYPE 23

#define STREAM_FLAGS_DISALLOW_URL 0x00000001
#define STREAM_FLAGS_DISALLOW_ABSOLUTE_PATH 0x00000002
#define STREAM_FLAGS_DISALLOW_QUERY 0x00000004
#define STREAM_FLAGS_DONTCACHEMAPPINGSCHEMA 0x00000008
#define STREAM_FLAGS_DONTCACHETEMPLATE 0x00000010
#define STREAM_FLAGS_DONTCACHEXSL 0x00000020
#define STREAM_FLAGS_DISALLOW_UPDATEGRAMS 0x00000040
#define STREAM_FLAGS_RESERVED 0xffff0000

#define SSPROPVAL_COMMANDTYPE_REGULAR 21
#define SSPROPVAL_COMMANDTYPE_BULKLOAD 22

#define V_SS_VT(X) ((X)->vt)
#define V_SS_UNION(X,Y) ((X)->Y)

#define V_SS_UI1(X) V_SS_UNION(X,bTinyIntVal)
#define V_SS_I2(X) V_SS_UNION(X,sShortIntVal)
#define V_SS_I4(X) V_SS_UNION(X,lIntVal)
#define V_SS_I8(X) V_SS_UNION(X,llBigIntVal)

#define V_SS_R4(X) V_SS_UNION(X,fltRealVal)
#define V_SS_R8(X) V_SS_UNION(X,dblFloatVal)
#define V_SS_UI4(X) V_SS_UNION(X,ulVal)

#define V_SS_MONEY(X) V_SS_UNION(X,cyMoneyVal)
#define V_SS_SMALLMONEY(X) V_SS_UNION(X,cyMoneyVal)

#define V_SS_WSTRING(X) V_SS_UNION(X,NCharVal)
#define V_SS_WVARSTRING(X) V_SS_UNION(X,NCharVal)

#define V_SS_STRING(X) V_SS_UNION(X,CharVal)
#define V_SS_VARSTRING(X) V_SS_UNION(X,CharVal)

#define V_SS_BIT(X) V_SS_UNION(X,fBitVal)
#define V_SS_GUID(X) V_SS_UNION(X,rgbGuidVal)

#define V_SS_NUMERIC(X) V_SS_UNION(X,numNumericVal)
#define V_SS_DECIMAL(X) V_SS_UNION(X,numNumericVal)

#define V_SS_BINARY(X) V_SS_UNION(X,BinaryVal)
#define V_SS_VARBINARY(X) V_SS_UNION(X,BinaryVal)

#define V_SS_DATETIME(X) V_SS_UNION(X,tsDateTimeVal)
#define V_SS_SMALLDATETIME(X) V_SS_UNION(X,tsDateTimeVal)

#define V_SS_UNKNOWN(X) V_SS_UNION(X,UnknownType)

#define V_SS_IMAGE(X) V_SS_UNION(X,ImageVal)
#define V_SS_TEXT(X) V_SS_UNION(X,TextVal)
#define V_SS_NTEXT(X) V_SS_UNION(X,NTextVal)

#define DBTYPE_SQLVARIANT 144

enum SQLVARENUM {
  VT_SS_EMPTY = DBTYPE_EMPTY,VT_SS_NULL = DBTYPE_NULL,VT_SS_UI1 = DBTYPE_UI1,VT_SS_I2 = DBTYPE_I2,VT_SS_I4 = DBTYPE_I4,VT_SS_I8 = DBTYPE_I8,
  VT_SS_R4 = DBTYPE_R4,VT_SS_R8 = DBTYPE_R8,VT_SS_MONEY = DBTYPE_CY,VT_SS_SMALLMONEY = 200,VT_SS_WSTRING = 201,VT_SS_WVARSTRING = 202,
  VT_SS_STRING =203,VT_SS_VARSTRING =204,VT_SS_BIT =DBTYPE_BOOL,VT_SS_GUID =DBTYPE_GUID,VT_SS_NUMERIC =DBTYPE_NUMERIC,VT_SS_DECIMAL =205,
  VT_SS_DATETIME = DBTYPE_DBTIMESTAMP,VT_SS_SMALLDATETIME =206,VT_SS_BINARY =207,VT_SS_VARBINARY =208,VT_SS_UNKNOWN = 209
};

typedef unsigned short SSVARTYPE;

struct SSVARIANT {
  SSVARTYPE vt;
  DWORD dwReserved1;
  DWORD dwReserved2;
  __C89_NAMELESS union {
    BYTE bTinyIntVal;
    SHORT sShortIntVal;
    LONG lIntVal;
    LONGLONG llBigIntVal;
    FLOAT fltRealVal;
    DOUBLE dblFloatVal;
    CY cyMoneyVal;
    struct _NCharVal {
      SHORT sActualLength;
      SHORT sMaxLength;
      WCHAR *pwchNCharVal;
      BYTE rgbReserved[5];
      DWORD dwReserved;
      WCHAR *pwchReserved;
    } NCharVal;
    struct _CharVal {
      SHORT sActualLength;
      SHORT sMaxLength;
      CHAR *pchCharVal;
      BYTE rgbReserved[5];
      DWORD dwReserved;
      WCHAR *pwchReserved;
    } CharVal;
    VARIANT_BOOL fBitVal;
    BYTE rgbGuidVal [16];
    DB_NUMERIC numNumericVal;
    struct _BinaryVal {
      SHORT sActualLength;
      SHORT sMaxLength;
      BYTE *prgbBinaryVal;
      DWORD dwReserved;
    } BinaryVal;
    DBTIMESTAMP tsDateTimeVal;
    struct _UnknownType {
      DWORD dwActualLength;
      BYTE rgMetadata [16];
      BYTE *pUnknownData;
    } UnknownType;
    struct _BLOBType {
      DBOBJECT dbobj;
      IUnknown *pUnk;
    } BLOBType;
  };
};

#if defined(__cplusplus) && !defined(CINTERFACE)
struct IUMSInitialize : public IUnknown {
public:
  virtual HRESULT WINAPI Initialize (VOID *pUMS) = 0;
};

struct IUMS {
public:
  virtual VOID WINAPI SqlUmsSuspend (ULONG ticks) = 0;
  virtual VOID WINAPI SqlUmsYield (ULONG ticks) = 0;
  virtual VOID WINAPI SqlUmsSwitchPremptive () = 0;
  virtual VOID WINAPI SqlUmsSwitchNonPremptive() = 0;
  virtual WINBOOL WINAPI SqlUmsFIsPremptive() = 0;
};
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

#ifndef __sqloledb_h__
#define __sqloledb_h__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __ISQLServerErrorInfo_FWD_DEFINED__
#define __ISQLServerErrorInfo_FWD_DEFINED__
  typedef struct ISQLServerErrorInfo ISQLServerErrorInfo;
#endif

#ifndef __IRowsetFastLoad_FWD_DEFINED__
#define __IRowsetFastLoad_FWD_DEFINED__
  typedef struct IRowsetFastLoad IRowsetFastLoad;
#endif

#ifndef __ISchemaLock_FWD_DEFINED__
#define __ISchemaLock_FWD_DEFINED__
  typedef struct ISchemaLock ISchemaLock;
#endif

#include "unknwn.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef struct tagSSErrorInfo {
    LPOLESTR pwszMessage;
    LPOLESTR pwszServer;
    LPOLESTR pwszProcedure;
    LONG lNative;
    BYTE bState;
    BYTE bClass;
    WORD wLineNumber;
  } SSERRORINFO;

  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0000_v0_0_s_ifspec;
#ifndef __ISQLServerErrorInfo_INTERFACE_DEFINED__
#define __ISQLServerErrorInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISQLServerErrorInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISQLServerErrorInfo : public IUnknown {
  public:
    virtual HRESULT WINAPI GetErrorInfo(SSERRORINFO **ppErrorInfo,OLECHAR **ppStringsBuffer) = 0;
  };
#else
  typedef struct ISQLServerErrorInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISQLServerErrorInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISQLServerErrorInfo *This);
      ULONG (WINAPI *Release)(ISQLServerErrorInfo *This);
      HRESULT (WINAPI *GetErrorInfo)(ISQLServerErrorInfo *This,SSERRORINFO **ppErrorInfo,OLECHAR **ppStringsBuffer);
    END_INTERFACE
  } ISQLServerErrorInfoVtbl;
  struct ISQLServerErrorInfo {
    CONST_VTBL struct ISQLServerErrorInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISQLServerErrorInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISQLServerErrorInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISQLServerErrorInfo_Release(This) (This)->lpVtbl->Release(This)
#define ISQLServerErrorInfo_GetErrorInfo(This,ppErrorInfo,ppStringsBuffer) (This)->lpVtbl->GetErrorInfo(This,ppErrorInfo,ppStringsBuffer)
#endif
#endif
  HRESULT WINAPI ISQLServerErrorInfo_GetErrorInfo_Proxy(ISQLServerErrorInfo *This,SSERRORINFO **ppErrorInfo,OLECHAR **ppStringsBuffer);
  void __RPC_STUB ISQLServerErrorInfo_GetErrorInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef _WIN64
  typedef ULONG_PTR HACCESSOR;
#else
  typedef ULONG HACCESSOR;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0006_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0006_v0_0_s_ifspec;
#ifndef __IRowsetFastLoad_INTERFACE_DEFINED__
#define __IRowsetFastLoad_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IRowsetFastLoad;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRowsetFastLoad : public IUnknown {
  public:
    virtual HRESULT WINAPI InsertRow(HACCESSOR hAccessor,void *pData) = 0;
    virtual HRESULT WINAPI Commit(WINBOOL fDone) = 0;
  };
#else
  typedef struct IRowsetFastLoadVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRowsetFastLoad *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRowsetFastLoad *This);
      ULONG (WINAPI *Release)(IRowsetFastLoad *This);
      HRESULT (WINAPI *InsertRow)(IRowsetFastLoad *This,HACCESSOR hAccessor,void *pData);
      HRESULT (WINAPI *Commit)(IRowsetFastLoad *This,WINBOOL fDone);
    END_INTERFACE
  } IRowsetFastLoadVtbl;
  struct IRowsetFastLoad {
    CONST_VTBL struct IRowsetFastLoadVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRowsetFastLoad_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRowsetFastLoad_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRowsetFastLoad_Release(This) (This)->lpVtbl->Release(This)
#define IRowsetFastLoad_InsertRow(This,hAccessor,pData) (This)->lpVtbl->InsertRow(This,hAccessor,pData)
#define IRowsetFastLoad_Commit(This,fDone) (This)->lpVtbl->Commit(This,fDone)
#endif
#endif
  HRESULT WINAPI IRowsetFastLoad_InsertRow_Proxy(IRowsetFastLoad *This,HACCESSOR hAccessor,void *pData);
  void __RPC_STUB IRowsetFastLoad_InsertRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRowsetFastLoad_Commit_Proxy(IRowsetFastLoad *This,WINBOOL fDone);
  void __RPC_STUB IRowsetFastLoad_Commit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef DWORD LOCKMODE;

  enum LOCKMODEENUM {
    LOCKMODE_INVALID = 0,
    LOCKMODE_EXCLUSIVE,LOCKMODE_SHARED
  };

  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0007_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_sqloledb_0007_v0_0_s_ifspec;
#ifndef __ISchemaLock_INTERFACE_DEFINED__
#define __ISchemaLock_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISchemaLock;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISchemaLock : public IUnknown {
  public:
    virtual HRESULT WINAPI GetSchemaLock(DBID *pTableID,LOCKMODE lmMode,HANDLE *phLockHandle,ULONGLONG *pTableVersion) = 0;
    virtual HRESULT WINAPI ReleaseSchemaLock(HANDLE hLockHandle) = 0;
  };
#else
  typedef struct ISchemaLockVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISchemaLock *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISchemaLock *This);
      ULONG (WINAPI *Release)(ISchemaLock *This);
      HRESULT (WINAPI *GetSchemaLock)(ISchemaLock *This,DBID *pTableID,LOCKMODE lmMode,HANDLE *phLockHandle,ULONGLONG *pTableVersion);
      HRESULT (WINAPI *ReleaseSchemaLock)(ISchemaLock *This,HANDLE hLockHandle);
    END_INTERFACE
  } ISchemaLockVtbl;
  struct ISchemaLock {
    CONST_VTBL struct ISchemaLockVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISchemaLock_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISchemaLock_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISchemaLock_Release(This) (This)->lpVtbl->Release(This)
#define ISchemaLock_GetSchemaLock(This,pTableID,lmMode,phLockHandle,pTableVersion) (This)->lpVtbl->GetSchemaLock(This,pTableID,lmMode,phLockHandle,pTableVersion)
#define ISchemaLock_ReleaseSchemaLock(This,hLockHandle) (This)->lpVtbl->ReleaseSchemaLock(This,hLockHandle)
#endif
#endif
  HRESULT WINAPI ISchemaLock_GetSchemaLock_Proxy(ISchemaLock *This,DBID *pTableID,LOCKMODE lmMode,HANDLE *phLockHandle,ULONGLONG *pTableVersion);
  void __RPC_STUB ISchemaLock_GetSchemaLock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISchemaLock_ReleaseSchemaLock_Proxy(ISchemaLock *This,HANDLE hLockHandle);
  void __RPC_STUB ISchemaLock_ReleaseSchemaLock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
#endif
