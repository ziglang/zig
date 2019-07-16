/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _ADOCTINT_H_
#define _ADOCTINT_H_

#ifndef _INC_TCHAR
#include <tchar.h>
#endif

#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 500
#endif

#ifndef __REQUIRED_RPCSAL_H_VERSION__
#define __REQUIRED_RPCSAL_H_VERSION__ 100
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of rpcndr.h header.
#endif

#ifndef __adocat_h__
#define __adocat_h__

#ifndef ___ADOCollection_FWD_DEFINED__
#define ___ADOCollection_FWD_DEFINED__
typedef interface _ADOADOCollection _ADOCollection;
#endif

#ifndef ___ADODynaCollection_FWD_DEFINED__
#define ___ADODynaCollection_FWD_DEFINED__
typedef interface _ADODynaADOCollection _ADODynaCollection;
#endif

#ifndef ___Catalog_FWD_DEFINED__
#define ___Catalog_FWD_DEFINED__
typedef interface _ADOCatalog _Catalog;
#endif

#ifndef ___Table_FWD_DEFINED__
#define ___Table_FWD_DEFINED__
typedef interface _ADOTable _Table;
#endif

#ifndef ___Group25_FWD_DEFINED__
#define ___Group25_FWD_DEFINED__
typedef interface _Group25 _Group25;
#endif

#ifndef ___Group_FWD_DEFINED__
#define ___Group_FWD_DEFINED__
typedef interface _ADOGroup _Group;
#endif

#ifndef ___User25_FWD_DEFINED__
#define ___User25_FWD_DEFINED__
typedef interface _User25 _User25;
#endif

#ifndef ___User_FWD_DEFINED__
#define ___User_FWD_DEFINED__
typedef interface _ADOUser _User;
#endif

#ifndef ___Column_FWD_DEFINED__
#define ___Column_FWD_DEFINED__
typedef interface _ADOColumn _Column;
#endif

#ifndef ___Index_FWD_DEFINED__
#define ___Index_FWD_DEFINED__
typedef interface _ADOIndex _Index;
#endif

#ifndef ___Key_FWD_DEFINED__
#define ___Key_FWD_DEFINED__
typedef interface _ADOKey _Key;
#endif

#ifndef __View_FWD_DEFINED__
#define __View_FWD_DEFINED__
typedef interface ADOView View;
#endif

#ifndef __Procedure_FWD_DEFINED__
#define __Procedure_FWD_DEFINED__
typedef interface ADOProcedure Procedure;
#endif

#ifndef __Catalog_FWD_DEFINED__
#define __Catalog_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOCatalog Catalog;
#else
typedef struct ADOCatalog Catalog;
#endif
#endif

#ifndef __Table_FWD_DEFINED__
#define __Table_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOTable Table;
#else
typedef struct ADOTable Table;
#endif
#endif

#ifndef __Property_FWD_DEFINED__
#define __Property_FWD_DEFINED__
typedef interface ADOProperty Property;
#endif

#ifndef __Group_FWD_DEFINED__
#define __Group_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOGroup Group;
#else
typedef struct ADOGroup Group;
#endif
#endif

#ifndef __User_FWD_DEFINED__
#define __User_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOUser User;
#else
typedef struct ADOUser User;
#endif
#endif
#ifndef __Column_FWD_DEFINED__
#define __Column_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOColumn Column;
#else
typedef struct ADOColumn Column;
#endif
#endif
#ifndef __Index_FWD_DEFINED__
#define __Index_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOIndex Index;
#else
typedef struct ADOIndex Index;
#endif
#endif
#ifndef __Key_FWD_DEFINED__
#define __Key_FWD_DEFINED__
#ifdef __cplusplus
typedef class ADOKey Key;
#else
typedef struct ADOKey Key;
#endif
#endif
#ifndef __Tables_FWD_DEFINED__
#define __Tables_FWD_DEFINED__
typedef interface ADOTables Tables;
#endif

#ifndef __Columns_FWD_DEFINED__
#define __Columns_FWD_DEFINED__
typedef interface ADOColumns Columns;
#endif

#ifndef __Procedures_FWD_DEFINED__
#define __Procedures_FWD_DEFINED__
typedef interface ADOProcedures Procedures;
#endif

#ifndef __Views_FWD_DEFINED__
#define __Views_FWD_DEFINED__
typedef interface ADOViews Views;
#endif

#ifndef __Indexes_FWD_DEFINED__
#define __Indexes_FWD_DEFINED__
typedef interface ADOIndexes Indexes;
#endif

#ifndef __Keys_FWD_DEFINED__
#define __Keys_FWD_DEFINED__
typedef interface ADOKeys Keys;
#endif

#ifndef __Users_FWD_DEFINED__
#define __Users_FWD_DEFINED__
typedef interface ADOUsers Users;
#endif

#ifndef __Groups_FWD_DEFINED__
#define __Groups_FWD_DEFINED__
typedef interface ADOGroups Groups;
#endif
#ifndef __Properties_FWD_DEFINED__
#define __Properties_FWD_DEFINED__
typedef interface ADOProperties Properties;
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum RuleEnum {
    adRINone = 0,
    adRICascade = 1,
    adRISetNull = 2,
    adRISetDefault = 3
  } RuleEnum;

  typedef enum KeyTypeEnum {
    adKeyPrimary = 1,
    adKeyForeign = 2,
    adKeyUnique = 3
  } KeyTypeEnum;

  typedef enum ActionEnum {
    adAccessGrant = 1,
    adAccessSet = 2,
    adAccessDeny = 3,
    adAccessRevoke = 4
  } ActionEnum;

  typedef enum ColumnAttributesEnum {
    adColFixed = 1,
    adColNullable = 2
  } ColumnAttributesEnum;

  typedef enum SortOrderEnum {
    adSortAscending = 1,
    adSortDescending = 2
  } SortOrderEnum;

  typedef enum RightsEnum {
    adRightNone = __MSABI_LONG(0),
    adRightDrop = __MSABI_LONG(0x100),
    adRightExclusive = __MSABI_LONG(0x200),
    adRightReadDesign = __MSABI_LONG(0x400),
    adRightWriteDesign = __MSABI_LONG(0x800),
    adRightWithGrant = __MSABI_LONG(0x1000),
    adRightReference = __MSABI_LONG(0x2000),
    adRightCreate = __MSABI_LONG(0x4000),
    adRightInsert = __MSABI_LONG(0x8000),
    adRightDelete = __MSABI_LONG(0x10000),
    adRightReadPermissions = __MSABI_LONG(0x20000),
    adRightWritePermissions = __MSABI_LONG(0x40000),
    adRightWriteOwner = __MSABI_LONG(0x80000),
    adRightMaximumAllowed = __MSABI_LONG(0x2000000),
    adRightFull = __MSABI_LONG(0x10000000),
    adRightExecute = __MSABI_LONG(0x20000000),
    adRightUpdate = __MSABI_LONG(0x40000000),
    adRightRead = __MSABI_LONG(0x80000000)
  } RightsEnum;

  typedef
#ifdef _ADOINT_H_
  class dummy dummy;
#else
  enum DataTypeEnum {
    adEmpty = 0,
    adTinyInt = 16,
    adSmallInt = 2,
    adInteger = 3,
    adBigInt = 20,
    adUnsignedTinyInt = 17,
    adUnsignedSmallInt = 18,
    adUnsignedInt = 19,
    adUnsignedBigInt = 21,
    adSingle = 4,
    adDouble = 5,
    adCurrency = 6,
    adDecimal = 14,
    adNumeric = 131,
    adBoolean = 11,
    adError = 10,
    adUserDefined = 132,
    adVariant = 12,
    adIDispatch = 9,
    adIUnknown = 13,
    adGUID = 72,
    adDate = 7,
    adDBDate = 133,
    adDBTime = 134,
    adDBTimeStamp = 135,
    adBSTR = 8,
    adChar = 129,
    adVarChar = 200,
    adLongVarChar = 201,
    adWChar = 130,
    adVarWChar = 202,
    adLongVarWChar = 203,
    adBinary = 128,
    adVarBinary = 204,
    adLongVarBinary = 205,
    adChapter = 136,
    adFileTime = 64,
    adPropVariant = 138,
    adVarNumeric = 139
  } DataTypeEnum;
#endif

  typedef enum AllowNullsEnum {
    adIndexNullsAllow = 0,
    adIndexNullsDisallow = 1,
    adIndexNullsIgnore = 2,
    adIndexNullsIgnoreAny = 4
  } AllowNullsEnum;

  typedef enum ObjectTypeEnum {
    adPermObjProviderSpecific = -1,
    adPermObjTable = 1,
    adPermObjColumn = 2,
    adPermObjDatabase = 3,
    adPermObjProcedure = 4,
    adPermObjView = 5
  } ObjectTypeEnum;

  typedef enum InheritTypeEnum {
    adInheritNone = 0,
    adInheritObjects = 1,
    adInheritContainers = 2,
    adInheritBoth = 3,
    adInheritNoPropogate = 4
  } InheritTypeEnum;

  extern RPC_IF_HANDLE __MIDL_itf_adocat_0000_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_adocat_0000_0000_v0_0_s_ifspec;

#ifndef __ADOX_LIBRARY_DEFINED__
#define __ADOX_LIBRARY_DEFINED__

  EXTERN_C const IID LIBID_ADOX;

#ifndef ___ADOCollection_INTERFACE_DEFINED__
#define ___ADOCollection_INTERFACE_DEFINED__

  EXTERN_C const IID IID__ADOCollection;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000512-0000-0010-8000-00AA006D2EA4")
  _ADOADOCollection : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Count (long *c) = 0;
    virtual HRESULT STDMETHODCALLTYPE _NewEnum (IUnknown **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Refresh (void) = 0;
  };
#else
  typedef struct _ADOCollectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOADOCollection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOADOCollection *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOADOCollection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOADOCollection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOADOCollection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOADOCollection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOADOCollection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (_ADOADOCollection *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (_ADOADOCollection *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (_ADOADOCollection *This);
    END_INTERFACE
  } _ADOCollectionVtbl;
  interface _ADOCollection {
    CONST_VTBL struct _ADOCollectionVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _ADOCollection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _ADOCollection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _ADOCollection_Release(This) ((This)->lpVtbl ->Release (This))
#define _ADOCollection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _ADOCollection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _ADOCollection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _ADOCollection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Collection_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define _ADOCollection__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define _ADOCollection_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#endif

#endif
#endif

#ifndef ___ADODynaCollection_INTERFACE_DEFINED__
#define ___ADODynaCollection_INTERFACE_DEFINED__

  EXTERN_C const IID IID__ADODynaCollection;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000513-0000-0010-8000-00AA006D2EA4")
  _ADODynaADOCollection : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE Append (IDispatch *Object) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct _ADODynaCollectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADODynaADOCollection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADODynaADOCollection *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADODynaADOCollection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADODynaADOCollection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADODynaADOCollection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADODynaADOCollection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADODynaADOCollection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (_ADODynaADOCollection *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (_ADODynaADOCollection *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (_ADODynaADOCollection *This);
    HRESULT (STDMETHODCALLTYPE *Append) (_ADODynaADOCollection *This, IDispatch *Object);
    HRESULT (STDMETHODCALLTYPE *Delete) (_ADODynaADOCollection *This, VARIANT Item);
    END_INTERFACE
  } _ADODynaCollectionVtbl;

  interface _ADODynaCollection {
    CONST_VTBL struct _ADODynaCollectionVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _ADODynaCollection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _ADODynaCollection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _ADODynaCollection_Release(This) ((This)->lpVtbl ->Release (This))
#define _ADODynaCollection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _ADODynaCollection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _ADODynaCollection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _ADODynaCollection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _DynaCollection_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define _ADODynaCollection__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define _ADODynaCollection_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define _ADODynaCollection_Append(This, Object) ((This)->lpVtbl ->Append (This, Object))
#define _ADODynaCollection_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef ___Catalog_INTERFACE_DEFINED__
#define ___Catalog_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Catalog;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000603-0000-0010-8000-00AA006D2EA4")
  _ADOCatalog : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Tables (ADOTables **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (VARIANT newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (IDispatch *pCon) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Procedures (ADOProcedures **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Views (ADOViews **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Groups (ADOGroups **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Users (ADOUsers **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Create (BSTR ConnectString, VARIANT *Connection) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetObjectOwner (BSTR ObjectName, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, BSTR *OwnerName) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetObjectOwner (BSTR ObjectName, ObjectTypeEnum ObjectType, BSTR UserName, VARIANT ObjectTypeId) = 0;
  };
#else
  typedef struct _CatalogVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOCatalog *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOCatalog *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOCatalog *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOCatalog *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOCatalog *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOCatalog *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOCatalog *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Tables) (_ADOCatalog *This, ADOTables **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (_ADOCatalog *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (_ADOCatalog *This, VARIANT newVal);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveConnection) (_ADOCatalog *This, IDispatch *pCon);
    HRESULT (STDMETHODCALLTYPE *get_Procedures) (_ADOCatalog *This, ADOProcedures **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Views) (_ADOCatalog *This, ADOViews **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Groups) (_ADOCatalog *This, ADOGroups **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Users) (_ADOCatalog *This, ADOUsers **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Create) (_ADOCatalog *This, BSTR ConnectString, VARIANT *Connection);
    HRESULT (STDMETHODCALLTYPE *GetObjectOwner) (_ADOCatalog *This, BSTR ObjectName, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, BSTR *OwnerName);
    HRESULT (STDMETHODCALLTYPE *SetObjectOwner) (_ADOCatalog *This, BSTR ObjectName, ObjectTypeEnum ObjectType, BSTR UserName, VARIANT ObjectTypeId);
    END_INTERFACE
  } _CatalogVtbl;

  interface _Catalog {
    CONST_VTBL struct _CatalogVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Catalog_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Catalog_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Catalog_Release(This) ((This)->lpVtbl ->Release (This))
#define _Catalog_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Catalog_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Catalog_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Catalog_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Catalog_get_Tables(This, ppvObject) ((This)->lpVtbl ->get_Tables (This, ppvObject))
#define _Catalog_get_ActiveConnection(This, pVal) ((This)->lpVtbl ->get_ActiveConnection (This, pVal))
#define _Catalog_put_ActiveConnection(This, newVal) ((This)->lpVtbl ->put_ActiveConnection (This, newVal))
#define _Catalog_putref_ActiveConnection(This, pCon) ((This)->lpVtbl ->putref_ActiveConnection (This, pCon))
#define _Catalog_get_Procedures(This, ppvObject) ((This)->lpVtbl ->get_Procedures (This, ppvObject))
#define _Catalog_get_Views(This, ppvObject) ((This)->lpVtbl ->get_Views (This, ppvObject))
#define _Catalog_get_Groups(This, ppvObject) ((This)->lpVtbl ->get_Groups (This, ppvObject))
#define _Catalog_get_Users(This, ppvObject) ((This)->lpVtbl ->get_Users (This, ppvObject))
#define _Catalog_Create(This, ConnectString, Connection) ((This)->lpVtbl ->Create (This, ConnectString, Connection))
#define _Catalog_GetObjectOwner(This, ObjectName, ObjectType, ObjectTypeId, OwnerName) ((This)->lpVtbl ->GetObjectOwner (This, ObjectName, ObjectType, ObjectTypeId, OwnerName))
#define _Catalog_SetObjectOwner(This, ObjectName, ObjectType, UserName, ObjectTypeId) ((This)->lpVtbl ->SetObjectOwner (This, ObjectName, ObjectType, UserName, ObjectTypeId))
#endif

#endif
#endif

#ifndef ___Table_INTERFACE_DEFINED__
#define ___Table_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Table;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000610-0000-0010-8000-00AA006D2EA4")
  _ADOTable : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Columns (ADOColumns **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Indexes (ADOIndexes **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Keys (ADOKeys **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateCreated (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateModified (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentCatalog (_ADOCatalog **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ParentCatalog (_ADOCatalog *ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ParentCatalog (_ADOCatalog *ppvObject) = 0;
  };
#else
  typedef struct _TableVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOTable *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOTable *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOTable *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOTable *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOTable *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOTable *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOTable *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Columns) (_ADOTable *This, ADOColumns **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOTable *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOTable *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_Type) (_ADOTable *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *get_Indexes) (_ADOTable *This, ADOIndexes **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Keys) (_ADOTable *This, ADOKeys **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOTable *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_DateCreated) (_ADOTable *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *get_DateModified) (_ADOTable *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *get_ParentCatalog) (_ADOTable *This, _ADOCatalog **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_ParentCatalog) (_ADOTable *This, _ADOCatalog *ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ParentADOCatalog) (_ADOTable *This, _ADOCatalog *ppvObject);
    END_INTERFACE
  } _TableVtbl;

  interface _Table {
    CONST_VTBL struct _TableVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Table_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Table_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Table_Release(This) ((This)->lpVtbl ->Release (This))
#define _Table_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Table_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Table_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Table_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Table_get_Columns(This, ppvObject) ((This)->lpVtbl ->get_Columns (This, ppvObject))
#define _Table_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Table_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Table_get_Type(This, pVal) ((This)->lpVtbl ->get_Type (This, pVal))
#define _Table_get_Indexes(This, ppvObject) ((This)->lpVtbl ->get_Indexes (This, ppvObject))
#define _Table_get_Keys(This, ppvObject) ((This)->lpVtbl ->get_Keys (This, ppvObject))
#define _Table_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Table_get_DateCreated(This, pVal) ((This)->lpVtbl ->get_DateCreated (This, pVal))
#define _Table_get_DateModified(This, pVal) ((This)->lpVtbl ->get_DateModified (This, pVal))
#define _Table_get_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->get_ParentCatalog (This, ppvObject))
#define _Table_put_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->put_ParentCatalog (This, ppvObject))
#define _Table_putref_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->putref_ParentCatalog (This, ppvObject))
#endif

#endif
#endif

#ifndef ___Group25_INTERFACE_DEFINED__
#define ___Group25_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Group25;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000616-0000-0010-8000-00AA006D2EA4")
  _Group25 : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetPermissions (VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetPermissions (VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Users (ADOUsers **ppvObject) = 0;
  };
#else
  typedef struct _Group25Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_Group25 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_Group25 *This);
    ULONG (STDMETHODCALLTYPE *Release) (_Group25 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_Group25 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_Group25 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_Group25 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_Group25 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_Group25 *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_Group25 *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *GetPermissions) (_Group25 *This, VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights);
    HRESULT (STDMETHODCALLTYPE *SetPermissions) (_Group25 *This, VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId);
    HRESULT (STDMETHODCALLTYPE *get_Users) (_Group25 *This, ADOUsers **ppvObject);
    END_INTERFACE
  } _Group25Vtbl;

  interface _Group25 {
    CONST_VTBL struct _Group25Vtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Group25_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Group25_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Group25_Release(This) ((This)->lpVtbl ->Release (This))
#define _Group25_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Group25_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Group25_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Group25_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Group25_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Group25_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Group25_GetPermissions(This, Name, ObjectType, ObjectTypeId, Rights) ((This)->lpVtbl ->GetPermissions (This, Name, ObjectType, ObjectTypeId, Rights))
#define _Group25_SetPermissions(This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId) ((This)->lpVtbl ->SetPermissions (This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId))
#define _Group25_get_Users(This, ppvObject) ((This)->lpVtbl ->get_Users (This, ppvObject))
#endif

#endif
#endif
#ifndef ___Group_INTERFACE_DEFINED__
#define ___Group_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Group;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000628-0000-0010-8000-00AA006D2EA4")
  _ADOGroup : public _Group25 {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentCatalog (_ADOCatalog **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ParentCatalog (_ADOCatalog *ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ParentCatalog (_ADOCatalog *ppvObject) = 0;
  };
#else
  typedef struct _GroupVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOGroup *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOGroup *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOGroup *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOGroup *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOGroup *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOGroup *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOGroup *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOGroup *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOGroup *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *GetPermissions) (_ADOGroup *This, VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights);
    HRESULT (STDMETHODCALLTYPE *SetPermissions) (_ADOGroup *This, VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId);
    HRESULT (STDMETHODCALLTYPE *get_Users) (_ADOGroup *This, ADOUsers **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOGroup *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ParentCatalog) (_ADOGroup *This, _ADOCatalog **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_ParentCatalog) (_ADOGroup *This, _ADOCatalog *ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ParentADOCatalog) (_ADOGroup *This, _ADOCatalog *ppvObject);
    END_INTERFACE
  } _GroupVtbl;

  interface _Group {
    CONST_VTBL struct _GroupVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Group_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Group_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Group_Release(This) ((This)->lpVtbl ->Release (This))
#define _Group_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Group_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Group_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Group_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Group_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Group_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Group_GetPermissions(This, Name, ObjectType, ObjectTypeId, Rights) ((This)->lpVtbl ->GetPermissions (This, Name, ObjectType, ObjectTypeId, Rights))
#define _Group_SetPermissions(This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId) ((This)->lpVtbl ->SetPermissions (This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId))
#define _Group_get_Users(This, ppvObject) ((This)->lpVtbl ->get_Users (This, ppvObject))
#define _Group_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Group_get_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->get_ParentCatalog (This, ppvObject))
#define _Group_put_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->put_ParentCatalog (This, ppvObject))
#define _Group_putref_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->putref_ParentCatalog (This, ppvObject))
#endif
#endif

#endif

#ifndef ___User25_INTERFACE_DEFINED__
#define ___User25_INTERFACE_DEFINED__

  EXTERN_C const IID IID__User25;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000619-0000-0010-8000-00AA006D2EA4")
  _User25 : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetPermissions (VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetPermissions (VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId) = 0;
    virtual HRESULT STDMETHODCALLTYPE ChangePassword (BSTR OldPassword, BSTR NewPassword) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Groups (ADOGroups **ppvObject) = 0;
  };
#else
  typedef struct _User25Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_User25 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_User25 *This);
    ULONG (STDMETHODCALLTYPE *Release) (_User25 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_User25 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_User25 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_User25 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_User25 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_User25 *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_User25 *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *GetPermissions) (_User25 *This, VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights);
    HRESULT (STDMETHODCALLTYPE *SetPermissions) (_User25 *This, VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId);
    HRESULT (STDMETHODCALLTYPE *ChangePassword) (_User25 *This, BSTR OldPassword, BSTR NewPassword);
    HRESULT (STDMETHODCALLTYPE *get_Groups) (_User25 *This, ADOGroups **ppvObject);
    END_INTERFACE
  } _User25Vtbl;

  interface _User25 {
    CONST_VTBL struct _User25Vtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _User25_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _User25_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _User25_Release(This) ((This)->lpVtbl ->Release (This))
#define _User25_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _User25_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _User25_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _User25_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _User25_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _User25_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _User25_GetPermissions(This, Name, ObjectType, ObjectTypeId, Rights) ((This)->lpVtbl ->GetPermissions (This, Name, ObjectType, ObjectTypeId, Rights))
#define _User25_SetPermissions(This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId) ((This)->lpVtbl ->SetPermissions (This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId))
#define _User25_ChangePassword(This, OldPassword, NewPassword) ((This)->lpVtbl ->ChangePassword (This, OldPassword, NewPassword))
#define _User25_get_Groups(This, ppvObject) ((This)->lpVtbl ->get_Groups (This, ppvObject))
#endif

#endif
#endif

#ifndef ___User_INTERFACE_DEFINED__
#define ___User_INTERFACE_DEFINED__

  EXTERN_C const IID IID__User;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000627-0000-0010-8000-00AA006D2EA4")
  _ADOUser : public _User25 {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentCatalog (_ADOCatalog **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ParentCatalog (_ADOCatalog *ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ParentCatalog (_ADOCatalog *ppvObject) = 0;
  };
#else
  typedef struct _UserVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOUser *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOUser *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOUser *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOUser *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOUser *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOUser *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOUser *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOUser *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOUser *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *GetPermissions) (_ADOUser *This, VARIANT Name, ObjectTypeEnum ObjectType, VARIANT ObjectTypeId, RightsEnum *Rights);
    HRESULT (STDMETHODCALLTYPE *SetPermissions) (_ADOUser *This, VARIANT Name, ObjectTypeEnum ObjectType, ActionEnum Action, RightsEnum Rights, InheritTypeEnum Inherit, VARIANT ObjectTypeId);
    HRESULT (STDMETHODCALLTYPE *ChangePassword) (_ADOUser *This, BSTR OldPassword, BSTR NewPassword);
    HRESULT (STDMETHODCALLTYPE *get_Groups) (_ADOUser *This, ADOGroups **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOUser *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ParentCatalog) (_ADOUser *This, _ADOCatalog **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_ParentCatalog) (_ADOUser *This, _ADOCatalog *ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ParentADOCatalog) (_ADOUser *This, _ADOCatalog *ppvObject);
    END_INTERFACE
  } _UserVtbl;

  interface _User {
    CONST_VTBL struct _UserVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _User_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _User_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _User_Release(This) ((This)->lpVtbl ->Release (This))
#define _User_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _User_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _User_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _User_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _User_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _User_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _User_GetPermissions(This, Name, ObjectType, ObjectTypeId, Rights) ((This)->lpVtbl ->GetPermissions (This, Name, ObjectType, ObjectTypeId, Rights))
#define _User_SetPermissions(This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId) ((This)->lpVtbl ->SetPermissions (This, Name, ObjectType, Action, Rights, Inherit, ObjectTypeId))
#define _User_ChangePassword(This, OldPassword, NewPassword) ((This)->lpVtbl ->ChangePassword (This, OldPassword, NewPassword))
#define _User_get_Groups(This, ppvObject) ((This)->lpVtbl ->get_Groups (This, ppvObject))
#define _User_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _User_get_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->get_ParentCatalog (This, ppvObject))
#define _User_put_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->put_ParentCatalog (This, ppvObject))
#define _User_putref_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->putref_ParentCatalog (This, ppvObject))
#endif

#endif
#endif

#ifndef ___Column_INTERFACE_DEFINED__
#define ___Column_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Column;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("0000061C-0000-0010-8000-00AA006D2EA4")
  _ADOColumn : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (ColumnAttributesEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (ColumnAttributesEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DefinedSize (long *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DefinedSize (long DefinedSize) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_NumericScale (BYTE *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_NumericScale (BYTE newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Precision (long *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Precision (long newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RelatedColumn (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_RelatedColumn (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_SortOrder (SortOrderEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_SortOrder (SortOrderEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Type (DataTypeEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentCatalog (_ADOCatalog **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ParentCatalog (_ADOCatalog *ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ParentCatalog (_ADOCatalog *ppvObject) = 0;
  };
#else
  typedef struct _ColumnVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOColumn *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOColumn *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOColumn *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOColumn *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOColumn *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOColumn *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOColumn *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOColumn *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOColumn *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (_ADOColumn *This, ColumnAttributesEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (_ADOColumn *This, ColumnAttributesEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_DefinedSize) (_ADOColumn *This, long *pVal);
    HRESULT (STDMETHODCALLTYPE *put_DefinedSize) (_ADOColumn *This, long DefinedSize);
    HRESULT (STDMETHODCALLTYPE *get_NumericScale) (_ADOColumn *This, BYTE *pVal);
    HRESULT (STDMETHODCALLTYPE *put_NumericScale) (_ADOColumn *This, BYTE newVal);
    HRESULT (STDMETHODCALLTYPE *get_Precision) (_ADOColumn *This, long *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Precision) (_ADOColumn *This, long newVal);
    HRESULT (STDMETHODCALLTYPE *get_RelatedColumn) (_ADOColumn *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_RelatedColumn) (_ADOColumn *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_SortOrder) (_ADOColumn *This, SortOrderEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_SortOrder) (_ADOColumn *This, SortOrderEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_Type) (_ADOColumn *This, DataTypeEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Type) (_ADOColumn *This, DataTypeEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOColumn *This, ADOProperties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_ParentCatalog) (_ADOColumn *This, _ADOCatalog **ppvObject);
    HRESULT (STDMETHODCALLTYPE *put_ParentCatalog) (_ADOColumn *This, _ADOCatalog *ppvObject);
    HRESULT (STDMETHODCALLTYPE *putref_ParentADOCatalog) (_ADOColumn *This, _ADOCatalog *ppvObject);
    END_INTERFACE
  } _ColumnVtbl;

  interface _Column {
    CONST_VTBL struct _ColumnVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Column_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Column_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Column_Release(This) ((This)->lpVtbl ->Release (This))
#define _Column_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Column_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Column_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Column_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Column_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Column_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Column_get_Attributes(This, pVal) ((This)->lpVtbl ->get_Attributes (This, pVal))
#define _Column_put_Attributes(This, newVal) ((This)->lpVtbl ->put_Attributes (This, newVal))
#define _Column_get_DefinedSize(This, pVal) ((This)->lpVtbl ->get_DefinedSize (This, pVal))
#define _Column_put_DefinedSize(This, DefinedSize) ((This)->lpVtbl ->put_DefinedSize (This, DefinedSize))
#define _Column_get_NumericScale(This, pVal) ((This)->lpVtbl ->get_NumericScale (This, pVal))
#define _Column_put_NumericScale(This, newVal) ((This)->lpVtbl ->put_NumericScale (This, newVal))
#define _Column_get_Precision(This, pVal) ((This)->lpVtbl ->get_Precision (This, pVal))
#define _Column_put_Precision(This, newVal) ((This)->lpVtbl ->put_Precision (This, newVal))
#define _Column_get_RelatedColumn(This, pVal) ((This)->lpVtbl ->get_RelatedColumn (This, pVal))
#define _Column_put_RelatedColumn(This, newVal) ((This)->lpVtbl ->put_RelatedColumn (This, newVal))
#define _Column_get_SortOrder(This, pVal) ((This)->lpVtbl ->get_SortOrder (This, pVal))
#define _Column_put_SortOrder(This, newVal) ((This)->lpVtbl ->put_SortOrder (This, newVal))
#define _Column_get_Type(This, pVal) ((This)->lpVtbl ->get_Type (This, pVal))
#define _Column_put_Type(This, newVal) ((This)->lpVtbl ->put_Type (This, newVal))
#define _Column_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define _Column_get_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->get_ParentCatalog (This, ppvObject))
#define _Column_put_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->put_ParentCatalog (This, ppvObject))
#define _Column_putref_ParentCatalog(This, ppvObject) ((This)->lpVtbl ->putref_ParentCatalog (This, ppvObject))
#endif

#endif
#endif

#ifndef ___Index_INTERFACE_DEFINED__
#define ___Index_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Index;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("0000061F-0000-0010-8000-00AA006D2EA4")
  _ADOIndex : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Clustered (VARIANT_BOOL *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Clustered (VARIANT_BOOL newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_IndexNulls (AllowNullsEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_IndexNulls (AllowNullsEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_PrimaryKey (VARIANT_BOOL *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_PrimaryKey (VARIANT_BOOL newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Unique (VARIANT_BOOL *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Unique (VARIANT_BOOL newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Columns (ADOColumns **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (ADOProperties **ppvObject) = 0;
  };
#else
  typedef struct _IndexVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOIndex *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOIndex *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOIndex *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOIndex *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOIndex *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOIndex *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOIndex *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOIndex *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOIndex *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_Clustered) (_ADOIndex *This, VARIANT_BOOL *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Clustered) (_ADOIndex *This, VARIANT_BOOL newVal);
    HRESULT (STDMETHODCALLTYPE *get_IndexNulls) (_ADOIndex *This, AllowNullsEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_IndexNulls) (_ADOIndex *This, AllowNullsEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_PrimaryKey) (_ADOIndex *This, VARIANT_BOOL *pVal);
    HRESULT (STDMETHODCALLTYPE *put_PrimaryKey) (_ADOIndex *This, VARIANT_BOOL newVal);
    HRESULT (STDMETHODCALLTYPE *get_Unique) (_ADOIndex *This, VARIANT_BOOL *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Unique) (_ADOIndex *This, VARIANT_BOOL newVal);
    HRESULT (STDMETHODCALLTYPE *get_Columns) (_ADOIndex *This, ADOColumns **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (_ADOIndex *This, ADOProperties **ppvObject);
    END_INTERFACE
  } _IndexVtbl;

  interface _Index {
    CONST_VTBL struct _IndexVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Index_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Index_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Index_Release(This) ((This)->lpVtbl ->Release (This))
#define _Index_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Index_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Index_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Index_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Index_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Index_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Index_get_Clustered(This, pVal) ((This)->lpVtbl ->get_Clustered (This, pVal))
#define _Index_put_Clustered(This, newVal) ((This)->lpVtbl ->put_Clustered (This, newVal))
#define _Index_get_IndexNulls(This, pVal) ((This)->lpVtbl ->get_IndexNulls (This, pVal))
#define _Index_put_IndexNulls(This, newVal) ((This)->lpVtbl ->put_IndexNulls (This, newVal))
#define _Index_get_PrimaryKey(This, pVal) ((This)->lpVtbl ->get_PrimaryKey (This, pVal))
#define _Index_put_PrimaryKey(This, newVal) ((This)->lpVtbl ->put_PrimaryKey (This, newVal))
#define _Index_get_Unique(This, pVal) ((This)->lpVtbl ->get_Unique (This, pVal))
#define _Index_put_Unique(This, newVal) ((This)->lpVtbl ->put_Unique (This, newVal))
#define _Index_get_Columns(This, ppvObject) ((This)->lpVtbl ->get_Columns (This, ppvObject))
#define _Index_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#endif

#endif
#endif

#ifndef ___Key_INTERFACE_DEFINED__
#define ___Key_INTERFACE_DEFINED__

  EXTERN_C const IID IID__Key;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000622-0000-0010-8000-00AA006D2EA4")
  _ADOKey : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Name (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DeleteRule (RuleEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_DeleteRule (RuleEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (KeyTypeEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Type (KeyTypeEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_RelatedTable (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_RelatedTable (BSTR newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UpdateRule (RuleEnum *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_UpdateRule (RuleEnum newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Columns (ADOColumns **ppvObject) = 0;
  };
#else
  typedef struct _KeyVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (_ADOKey *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (_ADOKey *This);
    ULONG (STDMETHODCALLTYPE *Release) (_ADOKey *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (_ADOKey *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (_ADOKey *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (_ADOKey *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (_ADOKey *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (_ADOKey *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Name) (_ADOKey *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_DeleteRule) (_ADOKey *This, RuleEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_DeleteRule) (_ADOKey *This, RuleEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_Type) (_ADOKey *This, KeyTypeEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Type) (_ADOKey *This, KeyTypeEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_RelatedTable) (_ADOKey *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *put_RelatedTable) (_ADOKey *This, BSTR newVal);
    HRESULT (STDMETHODCALLTYPE *get_UpdateRule) (_ADOKey *This, RuleEnum *pVal);
    HRESULT (STDMETHODCALLTYPE *put_UpdateRule) (_ADOKey *This, RuleEnum newVal);
    HRESULT (STDMETHODCALLTYPE *get_Columns) (_ADOKey *This, ADOColumns **ppvObject);
    END_INTERFACE
  } _KeyVtbl;

  interface _Key {
    CONST_VTBL struct _KeyVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define _Key_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define _Key_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define _Key_Release(This) ((This)->lpVtbl ->Release (This))
#define _Key_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define _Key_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define _Key_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define _Key_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define _Key_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define _Key_put_Name(This, newVal) ((This)->lpVtbl ->put_Name (This, newVal))
#define _Key_get_DeleteRule(This, pVal) ((This)->lpVtbl ->get_DeleteRule (This, pVal))
#define _Key_put_DeleteRule(This, newVal) ((This)->lpVtbl ->put_DeleteRule (This, newVal))
#define _Key_get_Type(This, pVal) ((This)->lpVtbl ->get_Type (This, pVal))
#define _Key_put_Type(This, newVal) ((This)->lpVtbl ->put_Type (This, newVal))
#define _Key_get_RelatedTable(This, pVal) ((This)->lpVtbl ->get_RelatedTable (This, pVal))
#define _Key_put_RelatedTable(This, newVal) ((This)->lpVtbl ->put_RelatedTable (This, newVal))
#define _Key_get_UpdateRule(This, pVal) ((This)->lpVtbl ->get_UpdateRule (This, pVal))
#define _Key_put_UpdateRule(This, newVal) ((This)->lpVtbl ->put_UpdateRule (This, newVal))
#define _Key_get_Columns(This, ppvObject) ((This)->lpVtbl ->get_Columns (This, ppvObject))
#endif

#endif
#endif

#ifndef __View_INTERFACE_DEFINED__
#define __View_INTERFACE_DEFINED__

  EXTERN_C const IID IID_View;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000613-0000-0010-8000-00AA006D2EA4")
  ADOView : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Command (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Command (VARIANT newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_Command (IDispatch *pComm) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateCreated (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateModified (VARIANT *pVal) = 0;
  };
#else
  typedef struct ViewVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOView *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOView *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOView *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOView *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOView *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOView *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOView *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Command) (ADOView *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *put_Command) (ADOView *This, VARIANT newVal);
    HRESULT (STDMETHODCALLTYPE *putref_Command) (ADOView *This, IDispatch *pComm);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ADOView *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *get_DateCreated) (ADOView *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *get_DateModified) (ADOView *This, VARIANT *pVal);
    END_INTERFACE
  } ViewVtbl;

  interface View {
    CONST_VTBL struct ViewVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define View_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define View_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define View_Release(This) ((This)->lpVtbl ->Release (This))
#define View_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define View_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define View_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define View_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define View_get_Command(This, pVal) ((This)->lpVtbl ->get_Command (This, pVal))
#define View_put_Command(This, newVal) ((This)->lpVtbl ->put_Command (This, newVal))
#define View_putref_Command(This, pComm) ((This)->lpVtbl ->putref_Command (This, pComm))
#define View_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define View_get_DateCreated(This, pVal) ((This)->lpVtbl ->get_DateCreated (This, pVal))
#define View_get_DateModified(This, pVal) ((This)->lpVtbl ->get_DateModified (This, pVal))
#endif

#endif
#endif

#ifndef __Procedure_INTERFACE_DEFINED__
#define __Procedure_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Procedure;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000625-0000-0010-8000-00AA006D2EA4")
  ADOProcedure : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Command (VARIANT *pVar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Command (VARIANT newVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_Command (IDispatch *pComm) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateCreated (VARIANT *pVal) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DateModified (VARIANT *pVal) = 0;
  };
#else
  typedef struct ProcedureVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProcedure *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProcedure *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProcedure *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProcedure *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProcedure *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProcedure *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProcedure *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Command) (ADOProcedure *This, VARIANT *pVar);
    HRESULT (STDMETHODCALLTYPE *put_Command) (ADOProcedure *This, VARIANT newVal);
    HRESULT (STDMETHODCALLTYPE *putref_Command) (ADOProcedure *This, IDispatch *pComm);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ADOProcedure *This, BSTR *pVal);
    HRESULT (STDMETHODCALLTYPE *get_DateCreated) (ADOProcedure *This, VARIANT *pVal);
    HRESULT (STDMETHODCALLTYPE *get_DateModified) (ADOProcedure *This, VARIANT *pVal);
    END_INTERFACE
  } ProcedureVtbl;

  interface Procedure {
    CONST_VTBL struct ProcedureVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Procedure_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Procedure_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Procedure_Release(This) ((This)->lpVtbl ->Release (This))
#define Procedure_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Procedure_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Procedure_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Procedure_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Procedure_get_Command(This, pVar) ((This)->lpVtbl ->get_Command (This, pVar))
#define Procedure_put_Command(This, newVal) ((This)->lpVtbl ->put_Command (This, newVal))
#define Procedure_putref_Command(This, pComm) ((This)->lpVtbl ->putref_Command (This, pComm))
#define Procedure_get_Name(This, pVal) ((This)->lpVtbl ->get_Name (This, pVal))
#define Procedure_get_DateCreated(This, pVal) ((This)->lpVtbl ->get_DateCreated (This, pVal))
#define Procedure_get_DateModified(This, pVal) ((This)->lpVtbl ->get_DateModified (This, pVal))
#endif

#endif
#endif

  EXTERN_C const CLSID CLSID_Catalog;

#ifdef __cplusplus
  Catalog;
#endif
  EXTERN_C const CLSID CLSID_Table;
#ifdef __cplusplus
  Table;
#endif
#ifndef __Property_INTERFACE_DEFINED__
#define __Property_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Property;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000503-0000-0010-8000-00AA006D2EA4")
  ADOProperty : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pval) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT val) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (DataTypeEnum *ptype) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Attributes (long *plAttributes) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Attributes (long lAttributes) = 0;
  };
#else
  typedef struct PropertyVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProperty *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProperty *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProperty *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProperty *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProperty *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProperty *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProperty *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Value) (ADOProperty *This, VARIANT *pval);
    HRESULT (STDMETHODCALLTYPE *put_Value) (ADOProperty *This, VARIANT val);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ADOProperty *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Type) (ADOProperty *This, DataTypeEnum *ptype);
    HRESULT (STDMETHODCALLTYPE *get_Attributes) (ADOProperty *This, long *plAttributes);
    HRESULT (STDMETHODCALLTYPE *put_Attributes) (ADOProperty *This, long lAttributes);
    END_INTERFACE
  } PropertyVtbl;

  interface Property {
    CONST_VTBL struct PropertyVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Property_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Property_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Property_Release(This) ((This)->lpVtbl ->Release (This))
#define Property_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Property_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Property_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Property_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Property_get_Value(This, pval) ((This)->lpVtbl ->get_Value (This, pval))
#define Property_put_Value(This, val) ((This)->lpVtbl ->put_Value (This, val))
#define Property_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Property_get_Type(This, ptype) ((This)->lpVtbl ->get_Type (This, ptype))
#define Property_get_Attributes(This, plAttributes) ((This)->lpVtbl ->get_Attributes (This, plAttributes))
#define Property_put_Attributes(This, lAttributes) ((This)->lpVtbl ->put_Attributes (This, lAttributes))
#endif

#endif
#endif

  EXTERN_C const CLSID CLSID_Group;

#ifdef __cplusplus
  Group;
#endif

  EXTERN_C const CLSID CLSID_User;

#ifdef __cplusplus
  User;
#endif

  EXTERN_C const CLSID CLSID_Column;

#ifdef __cplusplus
  Column;
#endif

  EXTERN_C const CLSID CLSID_Index;

#ifdef __cplusplus
  Index;
#endif

  EXTERN_C const CLSID CLSID_Key;

#ifdef __cplusplus
  Key;
#endif

#ifndef __Tables_INTERFACE_DEFINED__
#define __Tables_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Tables;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000611-0000-0010-8000-00AA006D2EA4")
  ADOTables : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, Table **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct TablesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOTables *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOTables *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOTables *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOTables *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOTables *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOTables *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOTables *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOTables *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOTables *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOTables *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOTables *This, VARIANT Item, Table **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOTables *This, VARIANT Item);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOTables *This, VARIANT Item);
    END_INTERFACE
  } TablesVtbl;

  interface Tables {
    CONST_VTBL struct TablesVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Tables_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Tables_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Tables_Release(This) ((This)->lpVtbl ->Release (This))
#define Tables_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Tables_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Tables_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Tables_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Tables_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Tables__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Tables_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Tables_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Tables_Append(This, Item) ((This)->lpVtbl ->Append (This, Item))
#define Tables_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Columns_INTERFACE_DEFINED__
#define __Columns_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Columns;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("0000061D-0000-0010-8000-00AA006D2EA4")
  ADOColumns : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, Column **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item, DataTypeEnum Type = adVarWChar, long DefinedSize = 0) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct ColumnsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOColumns *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOColumns *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOColumns *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOColumns *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOColumns *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOColumns *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOColumns *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOColumns *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOColumns *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOColumns *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOColumns *This, VARIANT Item, Column **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOColumns *This, VARIANT Item, DataTypeEnum Type, long DefinedSize);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOColumns *This, VARIANT Item);
    END_INTERFACE
  } ColumnsVtbl;

  interface Columns {
    CONST_VTBL struct ColumnsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Columns_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Columns_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Columns_Release(This) ((This)->lpVtbl ->Release (This))
#define Columns_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Columns_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Columns_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Columns_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Columns_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Columns__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Columns_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Columns_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Columns_Append(This, Item, Type, DefinedSize) ((This)->lpVtbl ->Append (This, Item, Type, DefinedSize))
#define Columns_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Procedures_INTERFACE_DEFINED__
#define __Procedures_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Procedures;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000626-0000-0010-8000-00AA006D2EA4")
  ADOProcedures : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, ADOProcedure **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (BSTR Name, IDispatch *Command) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct ProceduresVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProcedures *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProcedures *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProcedures *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProcedures *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProcedures *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProcedures *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProcedures *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOProcedures *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOProcedures *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOProcedures *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOProcedures *This, VARIANT Item, ADOProcedure **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOProcedures *This, BSTR Name, IDispatch *Command);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOProcedures *This, VARIANT Item);
    END_INTERFACE
  } ProceduresVtbl;

  interface Procedures {
    CONST_VTBL struct ProceduresVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Procedures_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Procedures_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Procedures_Release(This) ((This)->lpVtbl ->Release (This))
#define Procedures_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Procedures_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Procedures_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Procedures_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Procedures_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Procedures__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Procedures_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Procedures_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Procedures_Append(This, Name, Command) ((This)->lpVtbl ->Append (This, Name, Command))
#define Procedures_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Views_INTERFACE_DEFINED__
#define __Views_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Views;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000614-0000-0010-8000-00AA006D2EA4")
  ADOViews : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, ADOView **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (BSTR Name, IDispatch *Command) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct ViewsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOViews *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOViews *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOViews *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOViews *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOViews *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOViews *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOViews *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOViews *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOViews *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOViews *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOViews *This, VARIANT Item, ADOView **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOViews *This, BSTR Name, IDispatch *Command);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOViews *This, VARIANT Item);
    END_INTERFACE
  } ViewsVtbl;

  interface Views {
    CONST_VTBL struct ViewsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Views_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Views_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Views_Release(This) ((This)->lpVtbl ->Release (This))
#define Views_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Views_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Views_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Views_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Views_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Views__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Views_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Views_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Views_Append(This, Name, Command) ((This)->lpVtbl ->Append (This, Name, Command))
#define Views_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Indexes_INTERFACE_DEFINED__
#define __Indexes_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Indexes;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000620-0000-0010-8000-00AA006D2EA4")
  ADOIndexes : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, Index **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item, VARIANT columns) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct IndexesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOIndexes *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOIndexes *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOIndexes *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOIndexes *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOIndexes *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOIndexes *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOIndexes *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOIndexes *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOIndexes *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOIndexes *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOIndexes *This, VARIANT Item, Index **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOIndexes *This, VARIANT Item, VARIANT columns);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOIndexes *This, VARIANT Item);
    END_INTERFACE
  } IndexesVtbl;

  interface Indexes {
    CONST_VTBL struct IndexesVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Indexes_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Indexes_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Indexes_Release(This) ((This)->lpVtbl ->Release (This))
#define Indexes_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Indexes_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Indexes_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Indexes_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Indexes_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Indexes__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Indexes_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Indexes_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Indexes_Append(This, Item, columns) ((This)->lpVtbl ->Append (This, Item, columns))
#define Indexes_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Keys_INTERFACE_DEFINED__
#define __Keys_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Keys;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000623-0000-0010-8000-00AA006D2EA4")
  ADOKeys : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, Key **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item, KeyTypeEnum Type, VARIANT Column, BSTR RelatedADOTable = L"", BSTR RelatedADOColumn = L"") = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct KeysVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOKeys *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOKeys *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOKeys *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOKeys *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOKeys *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOKeys *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOKeys *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOKeys *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOKeys *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOKeys *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOKeys *This, VARIANT Item, Key **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOKeys *This, VARIANT Item, KeyTypeEnum Type, VARIANT Column, BSTR RelatedTable, BSTR RelatedColumn);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOKeys *This, VARIANT Item);
    END_INTERFACE
  } KeysVtbl;

  interface Keys {
    CONST_VTBL struct KeysVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Keys_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Keys_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Keys_Release(This) ((This)->lpVtbl ->Release (This))
#define Keys_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Keys_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Keys_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Keys_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Keys_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Keys__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Keys_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Keys_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Keys_Append(This, Item, Type, Column, RelatedTable, RelatedColumn) ((This)->lpVtbl ->Append (This, Item, Type, Column, RelatedTable, RelatedColumn))
#define Keys_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Users_INTERFACE_DEFINED__
#define __Users_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Users;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("0000061A-0000-0010-8000-00AA006D2EA4")
  ADOUsers : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, User **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item, BSTR Password = L"") = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct UsersVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOUsers *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOUsers *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOUsers *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOUsers *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOUsers *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOUsers *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOUsers *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOUsers *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOUsers *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOUsers *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOUsers *This, VARIANT Item, User **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOUsers *This, VARIANT Item, BSTR Password);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOUsers *This, VARIANT Item);
    END_INTERFACE
  } UsersVtbl;
  interface Users {
    CONST_VTBL struct UsersVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Users_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Users_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Users_Release(This) ((This)->lpVtbl ->Release (This))
#define Users_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Users_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Users_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Users_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Users_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Users__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Users_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Users_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Users_Append(This, Item, Password) ((This)->lpVtbl ->Append (This, Item, Password))
#define Users_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Groups_INTERFACE_DEFINED__
#define __Groups_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Groups;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000617-0000-0010-8000-00AA006D2EA4")
  ADOGroups : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, Group **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Append (VARIANT Item) = 0;
    virtual HRESULT STDMETHODCALLTYPE Delete (VARIANT Item) = 0;
  };
#else
  typedef struct GroupsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOGroups *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOGroups *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOGroups *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOGroups *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOGroups *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOGroups *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOGroups *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOGroups *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOGroups *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOGroups *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOGroups *This, VARIANT Item, Group **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Append) (ADOGroups *This, VARIANT Item);
    HRESULT (STDMETHODCALLTYPE *Delete) (ADOGroups *This, VARIANT Item);
    END_INTERFACE
  } GroupsVtbl;

  interface Groups {
    CONST_VTBL struct GroupsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Groups_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Groups_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Groups_Release(This) ((This)->lpVtbl ->Release (This))
#define Groups_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Groups_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Groups_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Groups_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Groups_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Groups__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Groups_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Groups_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#define Groups_Append(This, Item) ((This)->lpVtbl ->Append (This, Item))
#define Groups_Delete(This, Item) ((This)->lpVtbl ->Delete (This, Item))
#endif

#endif
#endif

#ifndef __Properties_INTERFACE_DEFINED__
#define __Properties_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Properties;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("00000504-0000-0010-8000-00AA006D2EA4")
  ADOProperties : public _ADOCollection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Item, ADOProperty **ppvObject) = 0;
  };
#else
  typedef struct PropertiesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ADOProperties *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ADOProperties *This);
    ULONG (STDMETHODCALLTYPE *Release) (ADOProperties *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ADOProperties *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ADOProperties *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ADOProperties *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ADOProperties *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Count) (ADOProperties *This, long *c);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (ADOProperties *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Refresh) (ADOProperties *This);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ADOProperties *This, VARIANT Item, ADOProperty **ppvObject);
    END_INTERFACE
  } PropertiesVtbl;

  interface Properties {
    CONST_VTBL struct PropertiesVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Properties_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Properties_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Properties_Release(This) ((This)->lpVtbl ->Release (This))
#define Properties_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Properties_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Properties_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Properties_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Properties_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Properties__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Properties_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Properties_get_Item(This, Item, ppvObject) ((This)->lpVtbl ->get_Item (This, Item, ppvObject))
#endif

#endif
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif

#define ADOCatalog _ADOCatalog
#define ADOTable _ADOTable
#define ADOGroup _ADOGroup
#define ADOUser _ADOUser
#define ADOIndex _ADOIndex
#define ADOColumn _ADOColumn
#define ADOKey _ADOKey
#define ADOParameter _ADOParameter
#define ADOCollection _ADOCollection
#define ADODynaCollection _ADODynaCollection

#endif
