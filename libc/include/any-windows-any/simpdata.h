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

#ifndef __simpdata_h__
#define __simpdata_h__

#ifndef __OLEDBSimpleProviderListener_FWD_DEFINED__
#define __OLEDBSimpleProviderListener_FWD_DEFINED__
typedef struct OLEDBSimpleProviderListener OLEDBSimpleProviderListener;
#endif

#ifndef __OLEDBSimpleProvider_FWD_DEFINED__
#define __OLEDBSimpleProvider_FWD_DEFINED__
typedef struct OLEDBSimpleProvider OLEDBSimpleProvider;
#endif

#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef SIMPDATA_H
#define SIMPDATA_H

#ifdef _WIN64
  typedef LONGLONG DBROWCOUNT;
  typedef LONGLONG DB_LORDINAL;
#else
  typedef LONG DBROWCOUNT;
  typedef LONG DB_LORDINAL;
#endif

#define OSP_IndexLabel (0)
#define OSP_IndexAll (~0)
#define OSP_IndexUnknown (~0)

  extern RPC_IF_HANDLE __MIDL_itf_simpdata_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_simpdata_0000_v0_0_s_ifspec;

#ifndef __MSDAOSP_LIBRARY_DEFINED__
#define __MSDAOSP_LIBRARY_DEFINED__

  typedef enum OSPFORMAT {
    OSPFORMAT_RAW = 0,OSPFORMAT_DEFAULT = 0,OSPFORMAT_FORMATTED = 1,OSPFORMAT_HTML = 2
  } OSPFORMAT;

  typedef enum OSPRW {
    OSPRW_DEFAULT = 1,OSPRW_READONLY = 0,OSPRW_READWRITE = 1,OSPRW_MIXED = 2
  } OSPRW;

  typedef enum OSPFIND {
    OSPFIND_DEFAULT = 0,OSPFIND_UP = 1,OSPFIND_CASESENSITIVE = 2,OSPFIND_UPCASESENSITIVE = 3
  } OSPFIND;

  typedef enum OSPCOMP {
    OSPCOMP_EQ = 1,OSPCOMP_DEFAULT = 1,OSPCOMP_LT = 2,OSPCOMP_LE = 3,OSPCOMP_GE = 4,OSPCOMP_GT = 5,OSPCOMP_NE = 6
  } OSPCOMP;

  typedef enum OSPXFER {
    OSPXFER_COMPLETE = 0,OSPXFER_ABORT = 1,OSPXFER_ERROR = 2
  } OSPXFER;

  typedef OLEDBSimpleProvider *LPOLEDBSimpleProvider;

  EXTERN_C const IID LIBID_MSDAOSP;
#ifndef __OLEDBSimpleProviderListener_INTERFACE_DEFINED__
#define __OLEDBSimpleProviderListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_OLEDBSimpleProviderListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct OLEDBSimpleProviderListener : public IUnknown {
  public:
    virtual HRESULT WINAPI aboutToChangeCell(DBROWCOUNT iRow,DB_LORDINAL iColumn) = 0;
    virtual HRESULT WINAPI cellChanged(DBROWCOUNT iRow,DB_LORDINAL iColumn) = 0;
    virtual HRESULT WINAPI aboutToDeleteRows(DBROWCOUNT iRow,DBROWCOUNT cRows) = 0;
    virtual HRESULT WINAPI deletedRows(DBROWCOUNT iRow,DBROWCOUNT cRows) = 0;
    virtual HRESULT WINAPI aboutToInsertRows(DBROWCOUNT iRow,DBROWCOUNT cRows) = 0;
    virtual HRESULT WINAPI insertedRows(DBROWCOUNT iRow,DBROWCOUNT cRows) = 0;
    virtual HRESULT WINAPI rowsAvailable(DBROWCOUNT iRow,DBROWCOUNT cRows) = 0;
    virtual HRESULT WINAPI transferComplete(OSPXFER xfer) = 0;
  };
#else
  typedef struct OLEDBSimpleProviderListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(OLEDBSimpleProviderListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(OLEDBSimpleProviderListener *This);
      ULONG (WINAPI *Release)(OLEDBSimpleProviderListener *This);
      HRESULT (WINAPI *aboutToChangeCell)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DB_LORDINAL iColumn);
      HRESULT (WINAPI *cellChanged)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DB_LORDINAL iColumn);
      HRESULT (WINAPI *aboutToDeleteRows)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
      HRESULT (WINAPI *deletedRows)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
      HRESULT (WINAPI *aboutToInsertRows)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
      HRESULT (WINAPI *insertedRows)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
      HRESULT (WINAPI *rowsAvailable)(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
      HRESULT (WINAPI *transferComplete)(OLEDBSimpleProviderListener *This,OSPXFER xfer);
    END_INTERFACE
  } OLEDBSimpleProviderListenerVtbl;
  struct OLEDBSimpleProviderListener {
    CONST_VTBL struct OLEDBSimpleProviderListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define OLEDBSimpleProviderListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define OLEDBSimpleProviderListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define OLEDBSimpleProviderListener_Release(This) (This)->lpVtbl->Release(This)
#define OLEDBSimpleProviderListener_aboutToChangeCell(This,iRow,iColumn) (This)->lpVtbl->aboutToChangeCell(This,iRow,iColumn)
#define OLEDBSimpleProviderListener_cellChanged(This,iRow,iColumn) (This)->lpVtbl->cellChanged(This,iRow,iColumn)
#define OLEDBSimpleProviderListener_aboutToDeleteRows(This,iRow,cRows) (This)->lpVtbl->aboutToDeleteRows(This,iRow,cRows)
#define OLEDBSimpleProviderListener_deletedRows(This,iRow,cRows) (This)->lpVtbl->deletedRows(This,iRow,cRows)
#define OLEDBSimpleProviderListener_aboutToInsertRows(This,iRow,cRows) (This)->lpVtbl->aboutToInsertRows(This,iRow,cRows)
#define OLEDBSimpleProviderListener_insertedRows(This,iRow,cRows) (This)->lpVtbl->insertedRows(This,iRow,cRows)
#define OLEDBSimpleProviderListener_rowsAvailable(This,iRow,cRows) (This)->lpVtbl->rowsAvailable(This,iRow,cRows)
#define OLEDBSimpleProviderListener_transferComplete(This,xfer) (This)->lpVtbl->transferComplete(This,xfer)
#endif
#endif
  HRESULT WINAPI OLEDBSimpleProviderListener_aboutToChangeCell_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DB_LORDINAL iColumn);
  void __RPC_STUB OLEDBSimpleProviderListener_aboutToChangeCell_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_cellChanged_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DB_LORDINAL iColumn);
  void __RPC_STUB OLEDBSimpleProviderListener_cellChanged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_aboutToDeleteRows_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
  void __RPC_STUB OLEDBSimpleProviderListener_aboutToDeleteRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_deletedRows_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
  void __RPC_STUB OLEDBSimpleProviderListener_deletedRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_aboutToInsertRows_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
  void __RPC_STUB OLEDBSimpleProviderListener_aboutToInsertRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_insertedRows_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
  void __RPC_STUB OLEDBSimpleProviderListener_insertedRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_rowsAvailable_Proxy(OLEDBSimpleProviderListener *This,DBROWCOUNT iRow,DBROWCOUNT cRows);
  void __RPC_STUB OLEDBSimpleProviderListener_rowsAvailable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProviderListener_transferComplete_Proxy(OLEDBSimpleProviderListener *This,OSPXFER xfer);
  void __RPC_STUB OLEDBSimpleProviderListener_transferComplete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __OLEDBSimpleProvider_INTERFACE_DEFINED__
#define __OLEDBSimpleProvider_INTERFACE_DEFINED__
  EXTERN_C const IID IID_OLEDBSimpleProvider;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct OLEDBSimpleProvider : public IUnknown {
  public:
    virtual HRESULT WINAPI getRowCount(DBROWCOUNT *pcRows) = 0;
    virtual HRESULT WINAPI getColumnCount(DB_LORDINAL *pcColumns) = 0;
    virtual HRESULT WINAPI getRWStatus(DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPRW *prwStatus) = 0;
    virtual HRESULT WINAPI getVariant(DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT *pVar) = 0;
    virtual HRESULT WINAPI setVariant(DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT Var) = 0;
    virtual HRESULT WINAPI getLocale(BSTR *pbstrLocale) = 0;
    virtual HRESULT WINAPI deleteRows(DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsDeleted) = 0;
    virtual HRESULT WINAPI insertRows(DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsInserted) = 0;
    virtual HRESULT WINAPI find(DBROWCOUNT iRowStart,DB_LORDINAL iColumn,VARIANT val,OSPFIND findFlags,OSPCOMP compType,DBROWCOUNT *piRowFound) = 0;
    virtual HRESULT WINAPI addOLEDBSimpleProviderListener(OLEDBSimpleProviderListener *pospIListener) = 0;
    virtual HRESULT WINAPI removeOLEDBSimpleProviderListener(OLEDBSimpleProviderListener *pospIListener) = 0;
    virtual HRESULT WINAPI isAsync(WINBOOL *pbAsynch) = 0;
    virtual HRESULT WINAPI getEstimatedRows(DBROWCOUNT *piRows) = 0;
    virtual HRESULT WINAPI stopTransfer(void) = 0;
  };
#else
  typedef struct OLEDBSimpleProviderVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(OLEDBSimpleProvider *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(OLEDBSimpleProvider *This);
      ULONG (WINAPI *Release)(OLEDBSimpleProvider *This);
      HRESULT (WINAPI *getRowCount)(OLEDBSimpleProvider *This,DBROWCOUNT *pcRows);
      HRESULT (WINAPI *getColumnCount)(OLEDBSimpleProvider *This,DB_LORDINAL *pcColumns);
      HRESULT (WINAPI *getRWStatus)(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPRW *prwStatus);
      HRESULT (WINAPI *getVariant)(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT *pVar);
      HRESULT (WINAPI *setVariant)(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT Var);
      HRESULT (WINAPI *getLocale)(OLEDBSimpleProvider *This,BSTR *pbstrLocale);
      HRESULT (WINAPI *deleteRows)(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsDeleted);
      HRESULT (WINAPI *insertRows)(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsInserted);
      HRESULT (WINAPI *find)(OLEDBSimpleProvider *This,DBROWCOUNT iRowStart,DB_LORDINAL iColumn,VARIANT val,OSPFIND findFlags,OSPCOMP compType,DBROWCOUNT *piRowFound);
      HRESULT (WINAPI *addOLEDBSimpleProviderListener)(OLEDBSimpleProvider *This,OLEDBSimpleProviderListener *pospIListener);
      HRESULT (WINAPI *removeOLEDBSimpleProviderListener)(OLEDBSimpleProvider *This,OLEDBSimpleProviderListener *pospIListener);
      HRESULT (WINAPI *isAsync)(OLEDBSimpleProvider *This,WINBOOL *pbAsynch);
      HRESULT (WINAPI *getEstimatedRows)(OLEDBSimpleProvider *This,DBROWCOUNT *piRows);
      HRESULT (WINAPI *stopTransfer)(OLEDBSimpleProvider *This);
    END_INTERFACE
  } OLEDBSimpleProviderVtbl;
  struct OLEDBSimpleProvider {
    CONST_VTBL struct OLEDBSimpleProviderVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define OLEDBSimpleProvider_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define OLEDBSimpleProvider_AddRef(This) (This)->lpVtbl->AddRef(This)
#define OLEDBSimpleProvider_Release(This) (This)->lpVtbl->Release(This)
#define OLEDBSimpleProvider_getRowCount(This,pcRows) (This)->lpVtbl->getRowCount(This,pcRows)
#define OLEDBSimpleProvider_getColumnCount(This,pcColumns) (This)->lpVtbl->getColumnCount(This,pcColumns)
#define OLEDBSimpleProvider_getRWStatus(This,iRow,iColumn,prwStatus) (This)->lpVtbl->getRWStatus(This,iRow,iColumn,prwStatus)
#define OLEDBSimpleProvider_getVariant(This,iRow,iColumn,format,pVar) (This)->lpVtbl->getVariant(This,iRow,iColumn,format,pVar)
#define OLEDBSimpleProvider_setVariant(This,iRow,iColumn,format,Var) (This)->lpVtbl->setVariant(This,iRow,iColumn,format,Var)
#define OLEDBSimpleProvider_getLocale(This,pbstrLocale) (This)->lpVtbl->getLocale(This,pbstrLocale)
#define OLEDBSimpleProvider_deleteRows(This,iRow,cRows,pcRowsDeleted) (This)->lpVtbl->deleteRows(This,iRow,cRows,pcRowsDeleted)
#define OLEDBSimpleProvider_insertRows(This,iRow,cRows,pcRowsInserted) (This)->lpVtbl->insertRows(This,iRow,cRows,pcRowsInserted)
#define OLEDBSimpleProvider_find(This,iRowStart,iColumn,val,findFlags,compType,piRowFound) (This)->lpVtbl->find(This,iRowStart,iColumn,val,findFlags,compType,piRowFound)
#define OLEDBSimpleProvider_addOLEDBSimpleProviderListener(This,pospIListener) (This)->lpVtbl->addOLEDBSimpleProviderListener(This,pospIListener)
#define OLEDBSimpleProvider_removeOLEDBSimpleProviderListener(This,pospIListener) (This)->lpVtbl->removeOLEDBSimpleProviderListener(This,pospIListener)
#define OLEDBSimpleProvider_isAsync(This,pbAsynch) (This)->lpVtbl->isAsync(This,pbAsynch)
#define OLEDBSimpleProvider_getEstimatedRows(This,piRows) (This)->lpVtbl->getEstimatedRows(This,piRows)
#define OLEDBSimpleProvider_stopTransfer(This) (This)->lpVtbl->stopTransfer(This)
#endif
#endif
  HRESULT WINAPI OLEDBSimpleProvider_getRowCount_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT *pcRows);
  void __RPC_STUB OLEDBSimpleProvider_getRowCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_getColumnCount_Proxy(OLEDBSimpleProvider *This,DB_LORDINAL *pcColumns);
  void __RPC_STUB OLEDBSimpleProvider_getColumnCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_getRWStatus_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPRW *prwStatus);
  void __RPC_STUB OLEDBSimpleProvider_getRWStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_getVariant_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT *pVar);
  void __RPC_STUB OLEDBSimpleProvider_getVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_setVariant_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DB_LORDINAL iColumn,OSPFORMAT format,VARIANT Var);
  void __RPC_STUB OLEDBSimpleProvider_setVariant_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_getLocale_Proxy(OLEDBSimpleProvider *This,BSTR *pbstrLocale);
  void __RPC_STUB OLEDBSimpleProvider_getLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_deleteRows_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsDeleted);
  void __RPC_STUB OLEDBSimpleProvider_deleteRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_insertRows_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRow,DBROWCOUNT cRows,DBROWCOUNT *pcRowsInserted);
  void __RPC_STUB OLEDBSimpleProvider_insertRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_find_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT iRowStart,DB_LORDINAL iColumn,VARIANT val,OSPFIND findFlags,OSPCOMP compType,DBROWCOUNT *piRowFound);
  void __RPC_STUB OLEDBSimpleProvider_find_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_addOLEDBSimpleProviderListener_Proxy(OLEDBSimpleProvider *This,OLEDBSimpleProviderListener *pospIListener);
  void __RPC_STUB OLEDBSimpleProvider_addOLEDBSimpleProviderListener_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_removeOLEDBSimpleProviderListener_Proxy(OLEDBSimpleProvider *This,OLEDBSimpleProviderListener *pospIListener);
  void __RPC_STUB OLEDBSimpleProvider_removeOLEDBSimpleProviderListener_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_isAsync_Proxy(OLEDBSimpleProvider *This,WINBOOL *pbAsynch);
  void __RPC_STUB OLEDBSimpleProvider_isAsync_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_getEstimatedRows_Proxy(OLEDBSimpleProvider *This,DBROWCOUNT *piRows);
  void __RPC_STUB OLEDBSimpleProvider_getEstimatedRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI OLEDBSimpleProvider_stopTransfer_Proxy(OLEDBSimpleProvider *This);
  void __RPC_STUB OLEDBSimpleProvider_stopTransfer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_simpdata_0117_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_simpdata_0117_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
