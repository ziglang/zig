/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

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

#ifndef __adomd_h__
#define __adomd_h__

#ifndef __ICatalog_FWD_DEFINED__
#define __ICatalog_FWD_DEFINED__
typedef interface ICatalog ICatalog;
#endif

#ifndef __ICellset_FWD_DEFINED__
#define __ICellset_FWD_DEFINED__
typedef interface ICellset ICellset;
#endif

#ifndef __Cell_FWD_DEFINED__
#define __Cell_FWD_DEFINED__
typedef interface Cell Cell;
#endif

#ifndef __Axis_FWD_DEFINED__
#define __Axis_FWD_DEFINED__
typedef interface Axis Axis;
#endif

#ifndef __Position_FWD_DEFINED__
#define __Position_FWD_DEFINED__
typedef interface Position Position;
#endif

#ifndef __Member_FWD_DEFINED__
#define __Member_FWD_DEFINED__
typedef interface Member Member;
#endif

#ifndef __Level_FWD_DEFINED__
#define __Level_FWD_DEFINED__
typedef interface Level Level;
#endif

#ifndef __CubeDef25_FWD_DEFINED__
#define __CubeDef25_FWD_DEFINED__
typedef interface CubeDef25 CubeDef25;
#endif

#ifndef __CubeDef_FWD_DEFINED__
#define __CubeDef_FWD_DEFINED__
typedef interface CubeDef CubeDef;
#endif

#ifndef __Dimension_FWD_DEFINED__
#define __Dimension_FWD_DEFINED__
typedef interface Dimension Dimension;
#endif

#ifndef __Hierarchy_FWD_DEFINED__
#define __Hierarchy_FWD_DEFINED__
typedef interface Hierarchy Hierarchy;
#endif

#ifndef __MD_Collection_FWD_DEFINED__
#define __MD_Collection_FWD_DEFINED__
typedef interface MD_Collection MD_Collection;
#endif

#ifndef __Members_FWD_DEFINED__
#define __Members_FWD_DEFINED__
typedef interface Members Members;
#endif

#ifndef __Levels_FWD_DEFINED__
#define __Levels_FWD_DEFINED__
typedef interface Levels Levels;
#endif

#ifndef __Axes_FWD_DEFINED__
#define __Axes_FWD_DEFINED__
typedef interface Axes Axes;
#endif

#ifndef __Positions_FWD_DEFINED__
#define __Positions_FWD_DEFINED__
typedef interface Positions Positions;
#endif

#ifndef __Hierarchies_FWD_DEFINED__
#define __Hierarchies_FWD_DEFINED__
typedef interface Hierarchies Hierarchies;
#endif

#ifndef __Dimensions_FWD_DEFINED__
#define __Dimensions_FWD_DEFINED__
typedef interface Dimensions Dimensions;
#endif

#ifndef __CubeDefs_FWD_DEFINED__
#define __CubeDefs_FWD_DEFINED__
typedef interface CubeDefs CubeDefs;
#endif

#ifndef __Catalog_FWD_DEFINED__
#define __Catalog_FWD_DEFINED__

#ifdef __cplusplus
typedef class Catalog Catalog;
#else
typedef struct Catalog Catalog;
#endif
#endif

#ifndef __Cellset_FWD_DEFINED__
#define __Cellset_FWD_DEFINED__

#ifdef __cplusplus
typedef class Cellset Cellset;
#else
typedef struct Cellset Cellset;
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

  extern RPC_IF_HANDLE __MIDL_itf_adomd_0000_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_adomd_0000_0000_v0_0_s_ifspec;

#ifndef __ADOMD_LIBRARY_DEFINED__
#define __ADOMD_LIBRARY_DEFINED__

  typedef DECLSPEC_UUID ("000002AE-0000-0010-8000-00AA006D2EA4")
  enum MemberTypeEnum {
    adMemberUnknown = 0,
    adMemberRegular = 0x1,
    adMemberAll = 0x2,
    adMemberMeasure = 0x3,
    adMemberFormula = 0x4
  } MemberTypeEnum;

  typedef DECLSPEC_UUID ("C23BBD43-E494-4d00-B4D1-6C9A2CE17CE3")
  enum SchemaObjectTypeEnum {
    adObjectTypeDimension = 1,
    adObjectTypeHierarchy = 2,
    adObjectTypeLevel = 3,
    adObjectTypeMember = 4
  } SchemaObjectTypeEnum;

  EXTERN_C const IID LIBID_ADOMD;

#ifndef __ICatalog_INTERFACE_DEFINED__
#define __ICatalog_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ICatalog;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("228136B1-8BD3-11D0-B4EF-00A0C9138CA4")
  ICatalog : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (IDispatch *pconn) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (BSTR bstrConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (IDispatch **ppConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_CubeDefs (CubeDefs **ppvObject) = 0;
  };
#else
  typedef struct ICatalogVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ICatalog *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ICatalog *This);
    ULONG (STDMETHODCALLTYPE *Release) (ICatalog *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ICatalog *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ICatalog *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ICatalog *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ICatalog *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (ICatalog *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveConnection) (ICatalog *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (ICatalog *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (ICatalog *This, IDispatch **ppConn);
    HRESULT (STDMETHODCALLTYPE *get_CubeDefs) (ICatalog *This, CubeDefs **ppvObject);
    END_INTERFACE
  } ICatalogVtbl;

  interface ICatalog {
    CONST_VTBL struct ICatalogVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define ICatalog_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ICatalog_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ICatalog_Release(This) ((This)->lpVtbl ->Release (This))
#define ICatalog_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ICatalog_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ICatalog_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ICatalog_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define ICatalog_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define ICatalog_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define ICatalog_put_ActiveConnection(This, bstrConn) ((This)->lpVtbl ->put_ActiveConnection (This, bstrConn))
#define ICatalog_get_ActiveConnection(This, ppConn) ((This)->lpVtbl ->get_ActiveConnection (This, ppConn))
#define ICatalog_get_CubeDefs(This, ppvObject) ((This)->lpVtbl ->get_CubeDefs (This, ppvObject))
#endif

#endif
#endif

#ifndef __ICellset_INTERFACE_DEFINED__
#define __ICellset_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ICellset;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281372A-8BD3-11D0-B4EF-00A0C9138CA4")
  ICellset : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (SAFEARRAY **idx, Cell **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE Open (VARIANT DataSource, VARIANT ActiveConnection) = 0;
    virtual HRESULT STDMETHODCALLTYPE Close (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_Source (IDispatch *pcmd) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Source (BSTR bstrCmd) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Source (VARIANT *pvSource) = 0;
    virtual HRESULT STDMETHODCALLTYPE putref_ActiveConnection (IDispatch *pconn) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_ActiveConnection (BSTR bstrConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ActiveConnection (IDispatch **ppConn) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_State (LONG *plState) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Axes (Axes **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_FilterAxis (Axis **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
  };
#else
  typedef struct ICellsetVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (ICellset *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (ICellset *This);
    ULONG (STDMETHODCALLTYPE *Release) (ICellset *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (ICellset *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (ICellset *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (ICellset *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (ICellset *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Item) (ICellset *This, SAFEARRAY **idx, Cell **ppvObject);
    HRESULT (STDMETHODCALLTYPE *Open) (ICellset *This, VARIANT DataSource, VARIANT ActiveConnection);
    HRESULT (STDMETHODCALLTYPE *Close) (ICellset *This);
    HRESULT (STDMETHODCALLTYPE *putref_Source) (ICellset *This, IDispatch *pcmd);
    HRESULT (STDMETHODCALLTYPE *put_Source) (ICellset *This, BSTR bstrCmd);
    HRESULT (STDMETHODCALLTYPE *get_Source) (ICellset *This, VARIANT *pvSource);
    HRESULT (STDMETHODCALLTYPE *putref_ActiveConnection) (ICellset *This, IDispatch *pconn);
    HRESULT (STDMETHODCALLTYPE *put_ActiveConnection) (ICellset *This, BSTR bstrConn);
    HRESULT (STDMETHODCALLTYPE *get_ActiveConnection) (ICellset *This, IDispatch **ppConn);
    HRESULT (STDMETHODCALLTYPE *get_State) (ICellset *This, LONG *plState);
    HRESULT (STDMETHODCALLTYPE *get_Axes) (ICellset *This, Axes **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_FilterAxis) (ICellset *This, Axis **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (ICellset *This, Properties **ppvObject);
    END_INTERFACE
  } ICellsetVtbl;

  interface ICellset {
    CONST_VTBL struct ICellsetVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define ICellset_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define ICellset_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define ICellset_Release(This) ((This)->lpVtbl ->Release (This))
#define ICellset_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define ICellset_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define ICellset_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define ICellset_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define ICellset_get_Item(This, idx, ppvObject) ((This)->lpVtbl ->get_Item (This, idx, ppvObject))
#define ICellset_Open(This, DataSource, ActiveConnection) ((This)->lpVtbl ->Open (This, DataSource, ActiveConnection))
#define ICellset_Close(This) ((This)->lpVtbl ->Close (This))
#define ICellset_putref_Source(This, pcmd) ((This)->lpVtbl ->putref_Source (This, pcmd))
#define ICellset_put_Source(This, bstrCmd) ((This)->lpVtbl ->put_Source (This, bstrCmd))
#define ICellset_get_Source(This, pvSource) ((This)->lpVtbl ->get_Source (This, pvSource))
#define ICellset_putref_ActiveConnection(This, pconn) ((This)->lpVtbl ->putref_ActiveConnection (This, pconn))
#define ICellset_put_ActiveConnection(This, bstrConn) ((This)->lpVtbl ->put_ActiveConnection (This, bstrConn))
#define ICellset_get_ActiveConnection(This, ppConn) ((This)->lpVtbl ->get_ActiveConnection (This, ppConn))
#define ICellset_get_State(This, plState) ((This)->lpVtbl ->get_State (This, plState))
#define ICellset_get_Axes(This, ppvObject) ((This)->lpVtbl ->get_Axes (This, ppvObject))
#define ICellset_get_FilterAxis(This, ppvObject) ((This)->lpVtbl ->get_FilterAxis (This, ppvObject))
#define ICellset_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#endif

#endif
#endif

#ifndef __Cell_INTERFACE_DEFINED__
#define __Cell_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Cell;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281372E-8BD3-11D0-B4EF-00A0C9138CA4")
  Cell : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Value (VARIANT *pvar) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_Value (VARIANT var) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Positions (Positions **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_FormattedValue (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE put_FormattedValue (BSTR bstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Ordinal (long *pl) = 0;
  };
#else
  typedef struct CellVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Cell *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Cell *This);
    ULONG (STDMETHODCALLTYPE *Release) (Cell *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Cell *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Cell *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Cell *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Cell *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Value) (Cell *This, VARIANT *pvar);
    HRESULT (STDMETHODCALLTYPE *put_Value) (Cell *This, VARIANT var);
    HRESULT (STDMETHODCALLTYPE *get_Positions) (Cell *This, Positions **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Cell *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_FormattedValue) (Cell *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *put_FormattedValue) (Cell *This, BSTR bstr);
    HRESULT (STDMETHODCALLTYPE *get_Ordinal) (Cell *This, long *pl);
    END_INTERFACE
  } CellVtbl;
  interface Cell {
    CONST_VTBL struct CellVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Cell_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Cell_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Cell_Release(This) ((This)->lpVtbl ->Release (This))
#define Cell_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Cell_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Cell_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Cell_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Cell_get_Value(This, pvar) ((This)->lpVtbl ->get_Value (This, pvar))
#define Cell_put_Value(This, var) ((This)->lpVtbl ->put_Value (This, var))
#define Cell_get_Positions(This, ppvObject) ((This)->lpVtbl ->get_Positions (This, ppvObject))
#define Cell_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Cell_get_FormattedValue(This, pbstr) ((This)->lpVtbl ->get_FormattedValue (This, pbstr))
#define Cell_put_FormattedValue(This, bstr) ((This)->lpVtbl ->put_FormattedValue (This, bstr))
#define Cell_get_Ordinal(This, pl) ((This)->lpVtbl ->get_Ordinal (This, pl))
#endif

#endif
#endif

#ifndef __Axis_INTERFACE_DEFINED__
#define __Axis_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Axis;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813732-8BD3-11D0-B4EF-00A0C9138CA4")
  Axis : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DimensionCount (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Positions (Positions **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
  };
#else
  typedef struct AxisVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Axis *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Axis *This);
    ULONG (STDMETHODCALLTYPE *Release) (Axis *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Axis *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Axis *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Axis *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Axis *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Axis *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_DimensionCount) (Axis *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Positions) (Axis *This, Positions **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Axis *This, Properties **ppvObject);
    END_INTERFACE
  } AxisVtbl;

  interface Axis {
    CONST_VTBL struct AxisVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Axis_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Axis_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Axis_Release(This) ((This)->lpVtbl ->Release (This))
#define Axis_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Axis_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Axis_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Axis_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Axis_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Axis_get_DimensionCount(This, pl) ((This)->lpVtbl ->get_DimensionCount (This, pl))
#define Axis_get_Positions(This, ppvObject) ((This)->lpVtbl ->get_Positions (This, ppvObject))
#define Axis_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#endif

#endif
#endif

#ifndef __Position_INTERFACE_DEFINED__
#define __Position_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Position;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813734-8BD3-11D0-B4EF-00A0C9138CA4")
  Position : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Ordinal (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Members (Members **ppvObject) = 0;
  };
#else
  typedef struct PositionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Position *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Position *This);
    ULONG (STDMETHODCALLTYPE *Release) (Position *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Position *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Position *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Position *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Position *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Ordinal) (Position *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_Members) (Position *This, Members **ppvObject);
    END_INTERFACE
  } PositionVtbl;

  interface Position {
    CONST_VTBL struct PositionVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Position_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Position_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Position_Release(This) ((This)->lpVtbl ->Release (This))
#define Position_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Position_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Position_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Position_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Position_get_Ordinal(This, pl) ((This)->lpVtbl ->get_Ordinal (This, pl))
#define Position_get_Members(This, ppvObject) ((This)->lpVtbl ->get_Members (This, ppvObject))
#endif

#endif
#endif

#ifndef __Member_INTERFACE_DEFINED__
#define __Member_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Member;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813736-8BD3-11D0-B4EF-00A0C9138CA4")
  Member : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UniqueName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Caption (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Parent (Member **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_LevelDepth (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_LevelName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Type (MemberTypeEnum *ptype) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ChildCount (long *pl) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_DrilledDown (VARIANT_BOOL *pf) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_ParentSameAsPrev (VARIANT_BOOL *pf) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Children (Members **ppvObject) = 0;
  };
#else
  typedef struct MemberVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Member *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Member *This);
    ULONG (STDMETHODCALLTYPE *Release) (Member *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Member *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Member *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Member *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Member *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Member *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_UniqueName) (Member *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Caption) (Member *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (Member *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Parent) (Member *This, Member **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_LevelDepth) (Member *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_LevelName) (Member *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Member *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Type) (Member *This, MemberTypeEnum *ptype);
    HRESULT (STDMETHODCALLTYPE *get_ChildCount) (Member *This, long *pl);
    HRESULT (STDMETHODCALLTYPE *get_DrilledDown) (Member *This, VARIANT_BOOL *pf);
    HRESULT (STDMETHODCALLTYPE *get_ParentSameAsPrev) (Member *This, VARIANT_BOOL *pf);
    HRESULT (STDMETHODCALLTYPE *get_Children) (Member *This, Members **ppvObject);
    END_INTERFACE
  } MemberVtbl;

  interface Member {
    CONST_VTBL struct MemberVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Member_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Member_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Member_Release(This) ((This)->lpVtbl ->Release (This))
#define Member_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Member_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Member_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Member_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Member_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Member_get_UniqueName(This, pbstr) ((This)->lpVtbl ->get_UniqueName (This, pbstr))
#define Member_get_Caption(This, pbstr) ((This)->lpVtbl ->get_Caption (This, pbstr))
#define Member_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define Member_get_Parent(This, ppvObject) ((This)->lpVtbl ->get_Parent (This, ppvObject))
#define Member_get_LevelDepth(This, pl) ((This)->lpVtbl ->get_LevelDepth (This, pl))
#define Member_get_LevelName(This, pbstr) ((This)->lpVtbl ->get_LevelName (This, pbstr))
#define Member_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Member_get_Type(This, ptype) ((This)->lpVtbl ->get_Type (This, ptype))
#define Member_get_ChildCount(This, pl) ((This)->lpVtbl ->get_ChildCount (This, pl))
#define Member_get_DrilledDown(This, pf) ((This)->lpVtbl ->get_DrilledDown (This, pf))
#define Member_get_ParentSameAsPrev(This, pf) ((This)->lpVtbl ->get_ParentSameAsPrev (This, pf))
#define Member_get_Children(This, ppvObject) ((This)->lpVtbl ->get_Children (This, ppvObject))
#endif

#endif
#endif

#ifndef __Level_INTERFACE_DEFINED__
#define __Level_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Level;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281373A-8BD3-11D0-B4EF-00A0C9138CA4")
  Level : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UniqueName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Caption (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Depth (short *pw) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Members (Members **ppvObject) = 0;
  };
#else
  typedef struct LevelVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Level *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Level *This);
    ULONG (STDMETHODCALLTYPE *Release) (Level *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Level *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Level *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Level *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Level *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Level *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_UniqueName) (Level *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Caption) (Level *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (Level *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Depth) (Level *This, short *pw);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Level *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Members) (Level *This, Members **ppvObject);
    END_INTERFACE
  } LevelVtbl;

  interface Level {
    CONST_VTBL struct LevelVtbl *lpVtbl;
  };

#ifdef COBJMACROS

#define Level_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Level_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Level_Release(This) ((This)->lpVtbl ->Release (This))
#define Level_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Level_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Level_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Level_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Level_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Level_get_UniqueName(This, pbstr) ((This)->lpVtbl ->get_UniqueName (This, pbstr))
#define Level_get_Caption(This, pbstr) ((This)->lpVtbl ->get_Caption (This, pbstr))
#define Level_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define Level_get_Depth(This, pw) ((This)->lpVtbl ->get_Depth (This, pw))
#define Level_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Level_get_Members(This, ppvObject) ((This)->lpVtbl ->get_Members (This, ppvObject))
#endif

#endif
#endif

#ifndef __CubeDef25_INTERFACE_DEFINED__
#define __CubeDef25_INTERFACE_DEFINED__

  EXTERN_C const IID IID_CubeDef25;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281373E-8BD3-11D0-B4EF-00A0C9138CA4")
  CubeDef25 : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Dimensions (Dimensions **ppvObject) = 0;
  };
#else
  typedef struct CubeDef25Vtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (CubeDef25 *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (CubeDef25 *This);
    ULONG (STDMETHODCALLTYPE *Release) (CubeDef25 *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (CubeDef25 *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (CubeDef25 *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (CubeDef25 *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (CubeDef25 *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (CubeDef25 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (CubeDef25 *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (CubeDef25 *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Dimensions) (CubeDef25 *This, Dimensions **ppvObject);
    END_INTERFACE
  } CubeDef25Vtbl;

  interface CubeDef25 {
    CONST_VTBL struct CubeDef25Vtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define CubeDef25_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define CubeDef25_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define CubeDef25_Release(This) ((This)->lpVtbl ->Release (This))
#define CubeDef25_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define CubeDef25_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define CubeDef25_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define CubeDef25_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define CubeDef25_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define CubeDef25_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define CubeDef25_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define CubeDef25_get_Dimensions(This, ppvObject) ((This)->lpVtbl ->get_Dimensions (This, ppvObject))
#endif

#endif
#endif

#ifndef __CubeDef_INTERFACE_DEFINED__
#define __CubeDef_INTERFACE_DEFINED__

  EXTERN_C const IID IID_CubeDef;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("DA16A34A-7B7A-46fd-AD9D-66DF1E699FA1")
  CubeDef : public CubeDef25 {
    public:
    virtual HRESULT STDMETHODCALLTYPE GetSchemaObject (SchemaObjectTypeEnum eObjType, BSTR bsUniqueName, IDispatch **ppObj) = 0;
  };
#else
  typedef struct CubeDefVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (CubeDef *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (CubeDef *This);
    ULONG (STDMETHODCALLTYPE *Release) (CubeDef *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (CubeDef *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (CubeDef *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (CubeDef *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (CubeDef *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (CubeDef *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (CubeDef *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (CubeDef *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Dimensions) (CubeDef *This, Dimensions **ppvObject);
    HRESULT (STDMETHODCALLTYPE *GetSchemaObject) (CubeDef *This, SchemaObjectTypeEnum eObjType, BSTR bsUniqueName, IDispatch **ppObj);
    END_INTERFACE
  } CubeDefVtbl;

  interface CubeDef {
    CONST_VTBL struct CubeDefVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define CubeDef_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define CubeDef_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define CubeDef_Release(This) ((This)->lpVtbl ->Release (This))
#define CubeDef_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define CubeDef_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define CubeDef_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define CubeDef_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define CubeDef_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define CubeDef_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define CubeDef_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define CubeDef_get_Dimensions(This, ppvObject) ((This)->lpVtbl ->get_Dimensions (This, ppvObject))
#define CubeDef_GetSchemaObject(This, eObjType, bsUniqueName, ppObj) ((This)->lpVtbl ->GetSchemaObject (This, eObjType, bsUniqueName, ppObj))
#endif

#endif
#endif

#ifndef __Dimension_INTERFACE_DEFINED__
#define __Dimension_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Dimension;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813742-8BD3-11D0-B4EF-00A0C9138CA4")
  Dimension : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UniqueName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Hierarchies (Hierarchies **ppvObject) = 0;
  };
#else
  typedef struct DimensionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Dimension *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Dimension *This);
    ULONG (STDMETHODCALLTYPE *Release) (Dimension *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Dimension *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Dimension *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Dimension *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Dimension *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Dimension *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_UniqueName) (Dimension *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (Dimension *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Dimension *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Hierarchies) (Dimension *This, Hierarchies **ppvObject);
    END_INTERFACE
  } DimensionVtbl;

  interface Dimension {
    CONST_VTBL struct DimensionVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Dimension_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Dimension_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Dimension_Release(This) ((This)->lpVtbl ->Release (This))
#define Dimension_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Dimension_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Dimension_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Dimension_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Dimension_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Dimension_get_UniqueName(This, pbstr) ((This)->lpVtbl ->get_UniqueName (This, pbstr))
#define Dimension_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define Dimension_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Dimension_get_Hierarchies(This, ppvObject) ((This)->lpVtbl ->get_Hierarchies (This, ppvObject))
#endif

#endif
#endif

#ifndef __Hierarchy_INTERFACE_DEFINED__
#define __Hierarchy_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Hierarchy;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813746-8BD3-11D0-B4EF-00A0C9138CA4")
  Hierarchy : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Name (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_UniqueName (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Description (BSTR *pbstr) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Properties (Properties **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Levels (Levels **ppvObject) = 0;
  };
#else
  typedef struct HierarchyVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Hierarchy *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Hierarchy *This);
    ULONG (STDMETHODCALLTYPE *Release) (Hierarchy *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Hierarchy *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Hierarchy *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Hierarchy *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Hierarchy *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *get_Name) (Hierarchy *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_UniqueName) (Hierarchy *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Description) (Hierarchy *This, BSTR *pbstr);
    HRESULT (STDMETHODCALLTYPE *get_Properties) (Hierarchy *This, Properties **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Levels) (Hierarchy *This, Levels **ppvObject);
    END_INTERFACE
  } HierarchyVtbl;

  interface Hierarchy {
    CONST_VTBL struct HierarchyVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Hierarchy_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Hierarchy_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Hierarchy_Release(This) ((This)->lpVtbl ->Release (This))
#define Hierarchy_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Hierarchy_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Hierarchy_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Hierarchy_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Hierarchy_get_Name(This, pbstr) ((This)->lpVtbl ->get_Name (This, pbstr))
#define Hierarchy_get_UniqueName(This, pbstr) ((This)->lpVtbl ->get_UniqueName (This, pbstr))
#define Hierarchy_get_Description(This, pbstr) ((This)->lpVtbl ->get_Description (This, pbstr))
#define Hierarchy_get_Properties(This, ppvObject) ((This)->lpVtbl ->get_Properties (This, ppvObject))
#define Hierarchy_get_Levels(This, ppvObject) ((This)->lpVtbl ->get_Levels (This, ppvObject))
#endif

#endif
#endif

#ifndef __MD_Collection_INTERFACE_DEFINED__
#define __MD_Collection_INTERFACE_DEFINED__

  EXTERN_C const IID IID_MD_Collection;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813751-8BD3-11D0-B4EF-00A0C9138CA4")
  MD_Collection : public IDispatch {
    public:
    virtual HRESULT STDMETHODCALLTYPE Refresh (void) = 0;
    virtual HRESULT STDMETHODCALLTYPE _NewEnum (IUnknown **ppvObject) = 0;
    virtual HRESULT STDMETHODCALLTYPE get_Count (long *c) = 0;
  };
#else
  typedef struct MD_CollectionVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (MD_Collection *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (MD_Collection *This);
    ULONG (STDMETHODCALLTYPE *Release) (MD_Collection *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (MD_Collection *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (MD_Collection *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (MD_Collection *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (MD_Collection *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (MD_Collection *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (MD_Collection *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (MD_Collection *This, long *c);
    END_INTERFACE
  } MD_CollectionVtbl;

  interface MD_Collection {
    CONST_VTBL struct MD_CollectionVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define MD_Collection_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define MD_Collection_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define MD_Collection_Release(This) ((This)->lpVtbl ->Release (This))
#define MD_Collection_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define MD_Collection_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define MD_Collection_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define MD_Collection_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define MD_Collection_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define MD_Collection__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define MD_Collection_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#endif

#endif
#endif

#ifndef __Members_INTERFACE_DEFINED__
#define __Members_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Members;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813757-8BD3-11D0-B4EF-00A0C9138CA4")
  Members : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Member **ppvObject) = 0;
  };
#else
  typedef struct MembersVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Members *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Members *This);
    ULONG (STDMETHODCALLTYPE *Release) (Members *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Members *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Members *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Members *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Members *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Members *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Members *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Members *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Members *This, VARIANT Index, Member **ppvObject);
    END_INTERFACE
  } MembersVtbl;

  interface Members {
    CONST_VTBL struct MembersVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Members_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Members_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Members_Release(This) ((This)->lpVtbl ->Release (This))
#define Members_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Members_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Members_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Members_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Members_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Members__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Members_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Members_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __Levels_INTERFACE_DEFINED__
#define __Levels_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Levels;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813758-8BD3-11D0-B4EF-00A0C9138CA4")
  Levels : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Level **ppvObject) = 0;
  };
#else
  typedef struct LevelsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Levels *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Levels *This);
    ULONG (STDMETHODCALLTYPE *Release) (Levels *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Levels *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Levels *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Levels *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Levels *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Levels *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Levels *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Levels *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Levels *This, VARIANT Index, Level **ppvObject);
    END_INTERFACE
  } LevelsVtbl;

  interface Levels {
    CONST_VTBL struct LevelsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Levels_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Levels_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Levels_Release(This) ((This)->lpVtbl ->Release (This))
#define Levels_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Levels_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Levels_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Levels_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Levels_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Levels__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Levels_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Levels_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __Axes_INTERFACE_DEFINED__
#define __Axes_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Axes;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("22813759-8BD3-11D0-B4EF-00A0C9138CA4")
  Axes : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Axis **ppvObject) = 0;
  };
#else
  typedef struct AxesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Axes *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Axes *This);
    ULONG (STDMETHODCALLTYPE *Release) (Axes *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Axes *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Axes *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Axes *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Axes *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Axes *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Axes *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Axes *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Axes *This, VARIANT Index, Axis **ppvObject);
    END_INTERFACE
  } AxesVtbl;

  interface Axes {
    CONST_VTBL struct AxesVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Axes_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Axes_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Axes_Release(This) ((This)->lpVtbl ->Release (This))
#define Axes_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Axes_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Axes_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Axes_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Axes_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Axes__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Axes_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Axes_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __Positions_INTERFACE_DEFINED__
#define __Positions_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Positions;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281375A-8BD3-11D0-B4EF-00A0C9138CA4")
  Positions : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Position **ppvObject) = 0;
  };
#else
  typedef struct PositionsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Positions *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Positions *This);
    ULONG (STDMETHODCALLTYPE *Release) (Positions *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Positions *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Positions *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Positions *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Positions *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Positions *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Positions *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Positions *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Positions *This, VARIANT Index, Position **ppvObject);
    END_INTERFACE
  } PositionsVtbl;

  interface Positions {
    CONST_VTBL struct PositionsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Positions_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Positions_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Positions_Release(This) ((This)->lpVtbl ->Release (This))
#define Positions_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Positions_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Positions_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Positions_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Positions_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Positions__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Positions_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Positions_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __Hierarchies_INTERFACE_DEFINED__
#define __Hierarchies_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Hierarchies;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281375B-8BD3-11D0-B4EF-00A0C9138CA4")
  Hierarchies : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Hierarchy **ppvObject) = 0;
  };
#else
  typedef struct HierarchiesVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Hierarchies *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Hierarchies *This);
    ULONG (STDMETHODCALLTYPE *Release) (Hierarchies *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Hierarchies *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Hierarchies *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Hierarchies *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Hierarchies *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Hierarchies *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Hierarchies *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Hierarchies *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Hierarchies *This, VARIANT Index, Hierarchy **ppvObject);
    END_INTERFACE
  } HierarchiesVtbl;

  interface Hierarchies {
    CONST_VTBL struct HierarchiesVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Hierarchies_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Hierarchies_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Hierarchies_Release(This) ((This)->lpVtbl ->Release (This))
#define Hierarchies_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Hierarchies_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Hierarchies_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Hierarchies_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Hierarchies_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Hierarchies__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Hierarchies_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Hierarchies_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __Dimensions_INTERFACE_DEFINED__
#define __Dimensions_INTERFACE_DEFINED__

  EXTERN_C const IID IID_Dimensions;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281375C-8BD3-11D0-B4EF-00A0C9138CA4")
  Dimensions : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, Dimension **ppvObject) = 0;
  };
#else
  typedef struct DimensionsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (Dimensions *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (Dimensions *This);
    ULONG (STDMETHODCALLTYPE *Release) (Dimensions *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (Dimensions *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (Dimensions *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (Dimensions *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (Dimensions *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (Dimensions *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (Dimensions *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (Dimensions *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (Dimensions *This, VARIANT Index, Dimension **ppvObject);
    END_INTERFACE
  } DimensionsVtbl;

  interface Dimensions {
    CONST_VTBL struct DimensionsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define Dimensions_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define Dimensions_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define Dimensions_Release(This) ((This)->lpVtbl ->Release (This))
#define Dimensions_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define Dimensions_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define Dimensions_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define Dimensions_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define Dimensions_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define Dimensions__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define Dimensions_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define Dimensions_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

#ifndef __CubeDefs_INTERFACE_DEFINED__
#define __CubeDefs_INTERFACE_DEFINED__

  EXTERN_C const IID IID_CubeDefs;

#if defined (__cplusplus) && !defined (CINTERFACE)
  MIDL_INTERFACE ("2281375D-8BD3-11D0-B4EF-00A0C9138CA4")
  CubeDefs : public MD_Collection {
    public:
    virtual HRESULT STDMETHODCALLTYPE get_Item (VARIANT Index, CubeDef **ppvObject) = 0;
  };
#else
  typedef struct CubeDefsVtbl {
    BEGIN_INTERFACE HRESULT (STDMETHODCALLTYPE *QueryInterface) (CubeDefs *This, REFIID riid, _COM_Outptr_ void **ppvObject);
    ULONG (STDMETHODCALLTYPE *AddRef) (CubeDefs *This);
    ULONG (STDMETHODCALLTYPE *Release) (CubeDefs *This);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfoCount) (CubeDefs *This, UINT *pctinfo);
    HRESULT (STDMETHODCALLTYPE *GetTypeInfo) (CubeDefs *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo);
    HRESULT (STDMETHODCALLTYPE *GetIDsOfNames) (CubeDefs *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId);
    HRESULT (STDMETHODCALLTYPE *Invoke) (CubeDefs *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr);
    HRESULT (STDMETHODCALLTYPE *Refresh) (CubeDefs *This);
    HRESULT (STDMETHODCALLTYPE *_NewEnum) (CubeDefs *This, IUnknown **ppvObject);
    HRESULT (STDMETHODCALLTYPE *get_Count) (CubeDefs *This, long *c);
    HRESULT (STDMETHODCALLTYPE *get_Item) (CubeDefs *This, VARIANT Index, CubeDef **ppvObject);
    END_INTERFACE
  } CubeDefsVtbl;

  interface CubeDefs {
    CONST_VTBL struct CubeDefsVtbl *lpVtbl;
  };

#ifdef COBJMACROS
#define CubeDefs_QueryInterface(This, riid, ppvObject) ((This)->lpVtbl ->QueryInterface (This, riid, ppvObject))
#define CubeDefs_AddRef(This) ((This)->lpVtbl ->AddRef (This))
#define CubeDefs_Release(This) ((This)->lpVtbl ->Release (This))
#define CubeDefs_GetTypeInfoCount(This, pctinfo) ((This)->lpVtbl ->GetTypeInfoCount (This, pctinfo))
#define CubeDefs_GetTypeInfo(This, iTInfo, lcid, ppTInfo) ((This)->lpVtbl ->GetTypeInfo (This, iTInfo, lcid, ppTInfo))
#define CubeDefs_GetIDsOfNames(This, riid, rgszNames, cNames, lcid, rgDispId) ((This)->lpVtbl ->GetIDsOfNames (This, riid, rgszNames, cNames, lcid, rgDispId))
#define CubeDefs_Invoke(This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr) ((This)->lpVtbl ->Invoke (This, dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr))
#define CubeDefs_Refresh(This) ((This)->lpVtbl ->Refresh (This))
#define CubeDefs__NewEnum(This, ppvObject) ((This)->lpVtbl ->_NewEnum (This, ppvObject))
#define CubeDefs_get_Count(This, c) ((This)->lpVtbl ->get_Count (This, c))
#define CubeDefs_get_Item(This, Index, ppvObject) ((This)->lpVtbl ->get_Item (This, Index, ppvObject))
#endif

#endif
#endif

  EXTERN_C const CLSID CLSID_Catalog;

#ifdef __cplusplus
  class DECLSPEC_UUID ("228136B0-8BD3-11D0-B4EF-00A0C9138CA4")
  Catalog;
#endif

  EXTERN_C const CLSID CLSID_Cellset;
#ifdef __cplusplus
  class DECLSPEC_UUID ("228136B8-8BD3-11D0-B4EF-00A0C9138CA4")
  Cellset;
#endif
#endif

#ifdef __cplusplus
}
#endif

#endif
