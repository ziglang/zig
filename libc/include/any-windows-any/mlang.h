/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include <_mingw_unicode.h>
#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef __mlang_h__
#define __mlang_h__

#ifndef __IMLangStringBufW_FWD_DEFINED__
#define __IMLangStringBufW_FWD_DEFINED__
typedef struct IMLangStringBufW IMLangStringBufW;
#endif

#ifndef __IMLangStringBufA_FWD_DEFINED__
#define __IMLangStringBufA_FWD_DEFINED__
typedef struct IMLangStringBufA IMLangStringBufA;
#endif

#ifndef __IMLangString_FWD_DEFINED__
#define __IMLangString_FWD_DEFINED__
typedef struct IMLangString IMLangString;
#endif

#ifndef __IMLangStringWStr_FWD_DEFINED__
#define __IMLangStringWStr_FWD_DEFINED__
typedef struct IMLangStringWStr IMLangStringWStr;
#endif

#ifndef __IMLangStringAStr_FWD_DEFINED__
#define __IMLangStringAStr_FWD_DEFINED__
typedef struct IMLangStringAStr IMLangStringAStr;
#endif

#ifndef __CMLangString_FWD_DEFINED__
#define __CMLangString_FWD_DEFINED__

#ifdef __cplusplus
typedef class CMLangString CMLangString;
#else
typedef struct CMLangString CMLangString;
#endif
#endif

#ifndef __IMLangLineBreakConsole_FWD_DEFINED__
#define __IMLangLineBreakConsole_FWD_DEFINED__
typedef struct IMLangLineBreakConsole IMLangLineBreakConsole;
#endif

#ifndef __IEnumCodePage_FWD_DEFINED__
#define __IEnumCodePage_FWD_DEFINED__
typedef struct IEnumCodePage IEnumCodePage;
#endif

#ifndef __IEnumRfc1766_FWD_DEFINED__
#define __IEnumRfc1766_FWD_DEFINED__
typedef struct IEnumRfc1766 IEnumRfc1766;
#endif

#ifndef __IEnumScript_FWD_DEFINED__
#define __IEnumScript_FWD_DEFINED__
typedef struct IEnumScript IEnumScript;
#endif

#ifndef __IMLangConvertCharset_FWD_DEFINED__
#define __IMLangConvertCharset_FWD_DEFINED__
typedef struct IMLangConvertCharset IMLangConvertCharset;
#endif

#ifndef __CMLangConvertCharset_FWD_DEFINED__
#define __CMLangConvertCharset_FWD_DEFINED__
#ifdef __cplusplus
typedef class CMLangConvertCharset CMLangConvertCharset;
#else
typedef struct CMLangConvertCharset CMLangConvertCharset;
#endif
#endif

#ifndef __IMultiLanguage_FWD_DEFINED__
#define __IMultiLanguage_FWD_DEFINED__
typedef struct IMultiLanguage IMultiLanguage;
#endif

#ifndef __IMultiLanguage2_FWD_DEFINED__
#define __IMultiLanguage2_FWD_DEFINED__
typedef struct IMultiLanguage2 IMultiLanguage2;
#endif

#ifndef __IMLangCodePages_FWD_DEFINED__
#define __IMLangCodePages_FWD_DEFINED__
typedef struct IMLangCodePages IMLangCodePages;
#endif

#ifndef __IMLangFontLink_FWD_DEFINED__
#define __IMLangFontLink_FWD_DEFINED__
typedef struct IMLangFontLink IMLangFontLink;
#endif

#ifndef __IMLangFontLink2_FWD_DEFINED__
#define __IMLangFontLink2_FWD_DEFINED__
typedef struct IMLangFontLink2 IMLangFontLink2;
#endif

#ifndef __IMultiLanguage3_FWD_DEFINED__
#define __IMultiLanguage3_FWD_DEFINED__
typedef struct IMultiLanguage3 IMultiLanguage3;
#endif

#ifndef __CMultiLanguage_FWD_DEFINED__
#define __CMultiLanguage_FWD_DEFINED__
#ifdef __cplusplus
typedef class CMultiLanguage CMultiLanguage;
#else
typedef struct CMultiLanguage CMultiLanguage;
#endif
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mlang_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mlang_0000_v0_0_s_ifspec;

#ifndef __MultiLanguage_LIBRARY_DEFINED__
#define __MultiLanguage_LIBRARY_DEFINED__

  typedef WORD LANGID;

  typedef enum tagMLSTR_FLAGS {
    MLSTR_READ = 1,MLSTR_WRITE = 2
  } MLSTR_FLAGS;

#define CPIOD_PEEK __MSABI_LONG(0x40000000)
#define CPIOD_FORCE_PROMPT __MSABI_LONG(0x80000000)

  EXTERN_C const IID LIBID_MultiLanguage;
#ifndef __IMLangStringBufW_INTERFACE_DEFINED__
#define __IMLangStringBufW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangStringBufW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangStringBufW : public IUnknown {
  public:
    virtual HRESULT WINAPI GetStatus(__LONG32 *plFlags,__LONG32 *pcchBuf) = 0;
    virtual HRESULT WINAPI LockBuf(__LONG32 cchOffset,__LONG32 cchMaxLock,WCHAR **ppszBuf,__LONG32 *pcchBuf) = 0;
    virtual HRESULT WINAPI UnlockBuf(const WCHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite) = 0;
    virtual HRESULT WINAPI Insert(__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 cchOffset,__LONG32 cchDelete) = 0;
  };
#else
  typedef struct IMLangStringBufWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangStringBufW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangStringBufW *This);
      ULONG (WINAPI *Release)(IMLangStringBufW *This);
      HRESULT (WINAPI *GetStatus)(IMLangStringBufW *This,__LONG32 *plFlags,__LONG32 *pcchBuf);
      HRESULT (WINAPI *LockBuf)(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchMaxLock,WCHAR **ppszBuf,__LONG32 *pcchBuf);
      HRESULT (WINAPI *UnlockBuf)(IMLangStringBufW *This,const WCHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite);
      HRESULT (WINAPI *Insert)(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual);
      HRESULT (WINAPI *Delete)(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchDelete);
    END_INTERFACE
  } IMLangStringBufWVtbl;
  struct IMLangStringBufW {
    CONST_VTBL struct IMLangStringBufWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangStringBufW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangStringBufW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangStringBufW_Release(This) (This)->lpVtbl->Release(This)
#define IMLangStringBufW_GetStatus(This,plFlags,pcchBuf) (This)->lpVtbl->GetStatus(This,plFlags,pcchBuf)
#define IMLangStringBufW_LockBuf(This,cchOffset,cchMaxLock,ppszBuf,pcchBuf) (This)->lpVtbl->LockBuf(This,cchOffset,cchMaxLock,ppszBuf,pcchBuf)
#define IMLangStringBufW_UnlockBuf(This,pszBuf,cchOffset,cchWrite) (This)->lpVtbl->UnlockBuf(This,pszBuf,cchOffset,cchWrite)
#define IMLangStringBufW_Insert(This,cchOffset,cchMaxInsert,pcchActual) (This)->lpVtbl->Insert(This,cchOffset,cchMaxInsert,pcchActual)
#define IMLangStringBufW_Delete(This,cchOffset,cchDelete) (This)->lpVtbl->Delete(This,cchOffset,cchDelete)
#endif
#endif
  HRESULT WINAPI IMLangStringBufW_GetStatus_Proxy(IMLangStringBufW *This,__LONG32 *plFlags,__LONG32 *pcchBuf);
  void __RPC_STUB IMLangStringBufW_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufW_LockBuf_Proxy(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchMaxLock,WCHAR **ppszBuf,__LONG32 *pcchBuf);
  void __RPC_STUB IMLangStringBufW_LockBuf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufW_UnlockBuf_Proxy(IMLangStringBufW *This,const WCHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite);
  void __RPC_STUB IMLangStringBufW_UnlockBuf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufW_Insert_Proxy(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual);
  void __RPC_STUB IMLangStringBufW_Insert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufW_Delete_Proxy(IMLangStringBufW *This,__LONG32 cchOffset,__LONG32 cchDelete);
  void __RPC_STUB IMLangStringBufW_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangStringBufA_INTERFACE_DEFINED__
#define __IMLangStringBufA_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangStringBufA;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangStringBufA : public IUnknown {
  public:
    virtual HRESULT WINAPI GetStatus(__LONG32 *plFlags,__LONG32 *pcchBuf) = 0;
    virtual HRESULT WINAPI LockBuf(__LONG32 cchOffset,__LONG32 cchMaxLock,CHAR **ppszBuf,__LONG32 *pcchBuf) = 0;
    virtual HRESULT WINAPI UnlockBuf(const CHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite) = 0;
    virtual HRESULT WINAPI Insert(__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual) = 0;
    virtual HRESULT WINAPI Delete(__LONG32 cchOffset,__LONG32 cchDelete) = 0;
  };
#else
  typedef struct IMLangStringBufAVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangStringBufA *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangStringBufA *This);
      ULONG (WINAPI *Release)(IMLangStringBufA *This);
      HRESULT (WINAPI *GetStatus)(IMLangStringBufA *This,__LONG32 *plFlags,__LONG32 *pcchBuf);
      HRESULT (WINAPI *LockBuf)(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchMaxLock,CHAR **ppszBuf,__LONG32 *pcchBuf);
      HRESULT (WINAPI *UnlockBuf)(IMLangStringBufA *This,const CHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite);
      HRESULT (WINAPI *Insert)(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual);
      HRESULT (WINAPI *Delete)(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchDelete);
    END_INTERFACE
  } IMLangStringBufAVtbl;
  struct IMLangStringBufA {
    CONST_VTBL struct IMLangStringBufAVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangStringBufA_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangStringBufA_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangStringBufA_Release(This) (This)->lpVtbl->Release(This)
#define IMLangStringBufA_GetStatus(This,plFlags,pcchBuf) (This)->lpVtbl->GetStatus(This,plFlags,pcchBuf)
#define IMLangStringBufA_LockBuf(This,cchOffset,cchMaxLock,ppszBuf,pcchBuf) (This)->lpVtbl->LockBuf(This,cchOffset,cchMaxLock,ppszBuf,pcchBuf)
#define IMLangStringBufA_UnlockBuf(This,pszBuf,cchOffset,cchWrite) (This)->lpVtbl->UnlockBuf(This,pszBuf,cchOffset,cchWrite)
#define IMLangStringBufA_Insert(This,cchOffset,cchMaxInsert,pcchActual) (This)->lpVtbl->Insert(This,cchOffset,cchMaxInsert,pcchActual)
#define IMLangStringBufA_Delete(This,cchOffset,cchDelete) (This)->lpVtbl->Delete(This,cchOffset,cchDelete)
#endif
#endif
  HRESULT WINAPI IMLangStringBufA_GetStatus_Proxy(IMLangStringBufA *This,__LONG32 *plFlags,__LONG32 *pcchBuf);
  void __RPC_STUB IMLangStringBufA_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufA_LockBuf_Proxy(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchMaxLock,CHAR **ppszBuf,__LONG32 *pcchBuf);
  void __RPC_STUB IMLangStringBufA_LockBuf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufA_UnlockBuf_Proxy(IMLangStringBufA *This,const CHAR *pszBuf,__LONG32 cchOffset,__LONG32 cchWrite);
  void __RPC_STUB IMLangStringBufA_UnlockBuf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufA_Insert_Proxy(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchMaxInsert,__LONG32 *pcchActual);
  void __RPC_STUB IMLangStringBufA_Insert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringBufA_Delete_Proxy(IMLangStringBufA *This,__LONG32 cchOffset,__LONG32 cchDelete);
  void __RPC_STUB IMLangStringBufA_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangString_INTERFACE_DEFINED__
#define __IMLangString_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangString;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangString : public IUnknown {
  public:
    virtual HRESULT WINAPI Sync(WINBOOL fNoAccess) = 0;
    virtual HRESULT WINAPI GetLength(__LONG32 *plLen) = 0;
    virtual HRESULT WINAPI SetMLStr(__LONG32 lDestPos,__LONG32 lDestLen,IUnknown *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen) = 0;
    virtual HRESULT WINAPI GetMLStr(__LONG32 lSrcPos,__LONG32 lSrcLen,IUnknown *pUnkOuter,DWORD dwClsContext,const IID *piid,IUnknown **ppDestMLStr,__LONG32 *plDestPos,__LONG32 *plDestLen) = 0;
  };
#else
  typedef struct IMLangStringVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangString *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangString *This);
      ULONG (WINAPI *Release)(IMLangString *This);
      HRESULT (WINAPI *Sync)(IMLangString *This,WINBOOL fNoAccess);
      HRESULT (WINAPI *GetLength)(IMLangString *This,__LONG32 *plLen);
      HRESULT (WINAPI *SetMLStr)(IMLangString *This,__LONG32 lDestPos,__LONG32 lDestLen,IUnknown *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen);
      HRESULT (WINAPI *GetMLStr)(IMLangString *This,__LONG32 lSrcPos,__LONG32 lSrcLen,IUnknown *pUnkOuter,DWORD dwClsContext,const IID *piid,IUnknown **ppDestMLStr,__LONG32 *plDestPos,__LONG32 *plDestLen);
    END_INTERFACE
  } IMLangStringVtbl;
  struct IMLangString {
    CONST_VTBL struct IMLangStringVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangString_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangString_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangString_Release(This) (This)->lpVtbl->Release(This)
#define IMLangString_Sync(This,fNoAccess) (This)->lpVtbl->Sync(This,fNoAccess)
#define IMLangString_GetLength(This,plLen) (This)->lpVtbl->GetLength(This,plLen)
#define IMLangString_SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen) (This)->lpVtbl->SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen)
#define IMLangString_GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen) (This)->lpVtbl->GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen)
#endif
#endif
  HRESULT WINAPI IMLangString_Sync_Proxy(IMLangString *This,WINBOOL fNoAccess);
  void __RPC_STUB IMLangString_Sync_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangString_GetLength_Proxy(IMLangString *This,__LONG32 *plLen);
  void __RPC_STUB IMLangString_GetLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangString_SetMLStr_Proxy(IMLangString *This,__LONG32 lDestPos,__LONG32 lDestLen,IUnknown *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen);
  void __RPC_STUB IMLangString_SetMLStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangString_GetMLStr_Proxy(IMLangString *This,__LONG32 lSrcPos,__LONG32 lSrcLen,IUnknown *pUnkOuter,DWORD dwClsContext,const IID *piid,IUnknown **ppDestMLStr,__LONG32 *plDestPos,__LONG32 *plDestLen);
  void __RPC_STUB IMLangString_GetMLStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangStringWStr_INTERFACE_DEFINED__
#define __IMLangStringWStr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangStringWStr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangStringWStr : public IMLangString {
  public:
    virtual HRESULT WINAPI SetWStr(__LONG32 lDestPos,__LONG32 lDestLen,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI SetStrBufW(__LONG32 lDestPos,__LONG32 lDestLen,IMLangStringBufW *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI GetWStr(__LONG32 lSrcPos,__LONG32 lSrcLen,WCHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI GetStrBufW(__LONG32 lSrcPos,__LONG32 lSrcMaxLen,IMLangStringBufW **ppDestBuf,__LONG32 *plDestLen) = 0;
    virtual HRESULT WINAPI LockWStr(__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,__LONG32 cchRequest,WCHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen) = 0;
    virtual HRESULT WINAPI UnlockWStr(const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI SetLocale(__LONG32 lDestPos,__LONG32 lDestLen,LCID locale) = 0;
    virtual HRESULT WINAPI GetLocale(__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen) = 0;
  };
#else
  typedef struct IMLangStringWStrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangStringWStr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangStringWStr *This);
      ULONG (WINAPI *Release)(IMLangStringWStr *This);
      HRESULT (WINAPI *Sync)(IMLangStringWStr *This,WINBOOL fNoAccess);
      HRESULT (WINAPI *GetLength)(IMLangStringWStr *This,__LONG32 *plLen);
      HRESULT (WINAPI *SetMLStr)(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,IUnknown *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen);
      HRESULT (WINAPI *GetMLStr)(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,IUnknown *pUnkOuter,DWORD dwClsContext,const IID *piid,IUnknown **ppDestMLStr,__LONG32 *plDestPos,__LONG32 *plDestLen);
      HRESULT (WINAPI *SetWStr)(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *SetStrBufW)(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,IMLangStringBufW *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *GetWStr)(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,WCHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *GetStrBufW)(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,IMLangStringBufW **ppDestBuf,__LONG32 *plDestLen);
      HRESULT (WINAPI *LockWStr)(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,__LONG32 cchRequest,WCHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen);
      HRESULT (WINAPI *UnlockWStr)(IMLangStringWStr *This,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *SetLocale)(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,LCID locale);
      HRESULT (WINAPI *GetLocale)(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen);
    END_INTERFACE
  } IMLangStringWStrVtbl;
  struct IMLangStringWStr {
    CONST_VTBL struct IMLangStringWStrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangStringWStr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangStringWStr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangStringWStr_Release(This) (This)->lpVtbl->Release(This)
#define IMLangStringWStr_Sync(This,fNoAccess) (This)->lpVtbl->Sync(This,fNoAccess)
#define IMLangStringWStr_GetLength(This,plLen) (This)->lpVtbl->GetLength(This,plLen)
#define IMLangStringWStr_SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen) (This)->lpVtbl->SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen)
#define IMLangStringWStr_GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen) (This)->lpVtbl->GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen)
#define IMLangStringWStr_SetWStr(This,lDestPos,lDestLen,pszSrc,cchSrc,pcchActual,plActualLen) (This)->lpVtbl->SetWStr(This,lDestPos,lDestLen,pszSrc,cchSrc,pcchActual,plActualLen)
#define IMLangStringWStr_SetStrBufW(This,lDestPos,lDestLen,pSrcBuf,pcchActual,plActualLen) (This)->lpVtbl->SetStrBufW(This,lDestPos,lDestLen,pSrcBuf,pcchActual,plActualLen)
#define IMLangStringWStr_GetWStr(This,lSrcPos,lSrcLen,pszDest,cchDest,pcchActual,plActualLen) (This)->lpVtbl->GetWStr(This,lSrcPos,lSrcLen,pszDest,cchDest,pcchActual,plActualLen)
#define IMLangStringWStr_GetStrBufW(This,lSrcPos,lSrcMaxLen,ppDestBuf,plDestLen) (This)->lpVtbl->GetStrBufW(This,lSrcPos,lSrcMaxLen,ppDestBuf,plDestLen)
#define IMLangStringWStr_LockWStr(This,lSrcPos,lSrcLen,lFlags,cchRequest,ppszDest,pcchDest,plDestLen) (This)->lpVtbl->LockWStr(This,lSrcPos,lSrcLen,lFlags,cchRequest,ppszDest,pcchDest,plDestLen)
#define IMLangStringWStr_UnlockWStr(This,pszSrc,cchSrc,pcchActual,plActualLen) (This)->lpVtbl->UnlockWStr(This,pszSrc,cchSrc,pcchActual,plActualLen)
#define IMLangStringWStr_SetLocale(This,lDestPos,lDestLen,locale) (This)->lpVtbl->SetLocale(This,lDestPos,lDestLen,locale)
#define IMLangStringWStr_GetLocale(This,lSrcPos,lSrcMaxLen,plocale,plLocalePos,plLocaleLen) (This)->lpVtbl->GetLocale(This,lSrcPos,lSrcMaxLen,plocale,plLocalePos,plLocaleLen)
#endif
#endif
  HRESULT WINAPI IMLangStringWStr_SetWStr_Proxy(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringWStr_SetWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_SetStrBufW_Proxy(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,IMLangStringBufW *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringWStr_SetStrBufW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_GetWStr_Proxy(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,WCHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringWStr_GetWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_GetStrBufW_Proxy(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,IMLangStringBufW **ppDestBuf,__LONG32 *plDestLen);
  void __RPC_STUB IMLangStringWStr_GetStrBufW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_LockWStr_Proxy(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,__LONG32 cchRequest,WCHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen);
  void __RPC_STUB IMLangStringWStr_LockWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_UnlockWStr_Proxy(IMLangStringWStr *This,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringWStr_UnlockWStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_SetLocale_Proxy(IMLangStringWStr *This,__LONG32 lDestPos,__LONG32 lDestLen,LCID locale);
  void __RPC_STUB IMLangStringWStr_SetLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringWStr_GetLocale_Proxy(IMLangStringWStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen);
  void __RPC_STUB IMLangStringWStr_GetLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangStringAStr_INTERFACE_DEFINED__
#define __IMLangStringAStr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangStringAStr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangStringAStr : public IMLangString {
  public:
    virtual HRESULT WINAPI SetAStr(__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI SetStrBufA(__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,IMLangStringBufA *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI GetAStr(__LONG32 lSrcPos,__LONG32 lSrcLen,UINT uCodePageIn,UINT *puCodePageOut,CHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI GetStrBufA(__LONG32 lSrcPos,__LONG32 lSrcMaxLen,UINT *puDestCodePage,IMLangStringBufA **ppDestBuf,__LONG32 *plDestLen) = 0;
    virtual HRESULT WINAPI LockAStr(__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,UINT uCodePageIn,__LONG32 cchRequest,UINT *puCodePageOut,CHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen) = 0;
    virtual HRESULT WINAPI UnlockAStr(const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen) = 0;
    virtual HRESULT WINAPI SetLocale(__LONG32 lDestPos,__LONG32 lDestLen,LCID locale) = 0;
    virtual HRESULT WINAPI GetLocale(__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen) = 0;
  };
#else
  typedef struct IMLangStringAStrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangStringAStr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangStringAStr *This);
      ULONG (WINAPI *Release)(IMLangStringAStr *This);
      HRESULT (WINAPI *Sync)(IMLangStringAStr *This,WINBOOL fNoAccess);
      HRESULT (WINAPI *GetLength)(IMLangStringAStr *This,__LONG32 *plLen);
      HRESULT (WINAPI *SetMLStr)(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,IUnknown *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen);
      HRESULT (WINAPI *GetMLStr)(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,IUnknown *pUnkOuter,DWORD dwClsContext,const IID *piid,IUnknown **ppDestMLStr,__LONG32 *plDestPos,__LONG32 *plDestLen);
      HRESULT (WINAPI *SetAStr)(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *SetStrBufA)(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,IMLangStringBufA *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *GetAStr)(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,UINT uCodePageIn,UINT *puCodePageOut,CHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *GetStrBufA)(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,UINT *puDestCodePage,IMLangStringBufA **ppDestBuf,__LONG32 *plDestLen);
      HRESULT (WINAPI *LockAStr)(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,UINT uCodePageIn,__LONG32 cchRequest,UINT *puCodePageOut,CHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen);
      HRESULT (WINAPI *UnlockAStr)(IMLangStringAStr *This,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
      HRESULT (WINAPI *SetLocale)(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,LCID locale);
      HRESULT (WINAPI *GetLocale)(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen);
    END_INTERFACE
  } IMLangStringAStrVtbl;
  struct IMLangStringAStr {
    CONST_VTBL struct IMLangStringAStrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangStringAStr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangStringAStr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangStringAStr_Release(This) (This)->lpVtbl->Release(This)
#define IMLangStringAStr_Sync(This,fNoAccess) (This)->lpVtbl->Sync(This,fNoAccess)
#define IMLangStringAStr_GetLength(This,plLen) (This)->lpVtbl->GetLength(This,plLen)
#define IMLangStringAStr_SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen) (This)->lpVtbl->SetMLStr(This,lDestPos,lDestLen,pSrcMLStr,lSrcPos,lSrcLen)
#define IMLangStringAStr_GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen) (This)->lpVtbl->GetMLStr(This,lSrcPos,lSrcLen,pUnkOuter,dwClsContext,piid,ppDestMLStr,plDestPos,plDestLen)
#define IMLangStringAStr_SetAStr(This,lDestPos,lDestLen,uCodePage,pszSrc,cchSrc,pcchActual,plActualLen) (This)->lpVtbl->SetAStr(This,lDestPos,lDestLen,uCodePage,pszSrc,cchSrc,pcchActual,plActualLen)
#define IMLangStringAStr_SetStrBufA(This,lDestPos,lDestLen,uCodePage,pSrcBuf,pcchActual,plActualLen) (This)->lpVtbl->SetStrBufA(This,lDestPos,lDestLen,uCodePage,pSrcBuf,pcchActual,plActualLen)
#define IMLangStringAStr_GetAStr(This,lSrcPos,lSrcLen,uCodePageIn,puCodePageOut,pszDest,cchDest,pcchActual,plActualLen) (This)->lpVtbl->GetAStr(This,lSrcPos,lSrcLen,uCodePageIn,puCodePageOut,pszDest,cchDest,pcchActual,plActualLen)
#define IMLangStringAStr_GetStrBufA(This,lSrcPos,lSrcMaxLen,puDestCodePage,ppDestBuf,plDestLen) (This)->lpVtbl->GetStrBufA(This,lSrcPos,lSrcMaxLen,puDestCodePage,ppDestBuf,plDestLen)
#define IMLangStringAStr_LockAStr(This,lSrcPos,lSrcLen,lFlags,uCodePageIn,cchRequest,puCodePageOut,ppszDest,pcchDest,plDestLen) (This)->lpVtbl->LockAStr(This,lSrcPos,lSrcLen,lFlags,uCodePageIn,cchRequest,puCodePageOut,ppszDest,pcchDest,plDestLen)
#define IMLangStringAStr_UnlockAStr(This,pszSrc,cchSrc,pcchActual,plActualLen) (This)->lpVtbl->UnlockAStr(This,pszSrc,cchSrc,pcchActual,plActualLen)
#define IMLangStringAStr_SetLocale(This,lDestPos,lDestLen,locale) (This)->lpVtbl->SetLocale(This,lDestPos,lDestLen,locale)
#define IMLangStringAStr_GetLocale(This,lSrcPos,lSrcMaxLen,plocale,plLocalePos,plLocaleLen) (This)->lpVtbl->GetLocale(This,lSrcPos,lSrcMaxLen,plocale,plLocalePos,plLocaleLen)
#endif
#endif
  HRESULT WINAPI IMLangStringAStr_SetAStr_Proxy(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringAStr_SetAStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_SetStrBufA_Proxy(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,UINT uCodePage,IMLangStringBufA *pSrcBuf,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringAStr_SetStrBufA_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_GetAStr_Proxy(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,UINT uCodePageIn,UINT *puCodePageOut,CHAR *pszDest,__LONG32 cchDest,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringAStr_GetAStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_GetStrBufA_Proxy(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,UINT *puDestCodePage,IMLangStringBufA **ppDestBuf,__LONG32 *plDestLen);
  void __RPC_STUB IMLangStringAStr_GetStrBufA_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_LockAStr_Proxy(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 lFlags,UINT uCodePageIn,__LONG32 cchRequest,UINT *puCodePageOut,CHAR **ppszDest,__LONG32 *pcchDest,__LONG32 *plDestLen);
  void __RPC_STUB IMLangStringAStr_LockAStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_UnlockAStr_Proxy(IMLangStringAStr *This,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 *pcchActual,__LONG32 *plActualLen);
  void __RPC_STUB IMLangStringAStr_UnlockAStr_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_SetLocale_Proxy(IMLangStringAStr *This,__LONG32 lDestPos,__LONG32 lDestLen,LCID locale);
  void __RPC_STUB IMLangStringAStr_SetLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangStringAStr_GetLocale_Proxy(IMLangStringAStr *This,__LONG32 lSrcPos,__LONG32 lSrcMaxLen,LCID *plocale,__LONG32 *plLocalePos,__LONG32 *plLocaleLen);
  void __RPC_STUB IMLangStringAStr_GetLocale_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_CMLangString;
#ifdef __cplusplus
  class CMLangString;
#endif

#ifndef __IMLangLineBreakConsole_INTERFACE_DEFINED__
#define __IMLangLineBreakConsole_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IMLangLineBreakConsole;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangLineBreakConsole : public IUnknown {
  public:
    virtual HRESULT WINAPI BreakLineML(IMLangString *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 cMinColumns,__LONG32 cMaxColumns,__LONG32 *plLineLen,__LONG32 *plSkipLen) = 0;
    virtual HRESULT WINAPI BreakLineW(LCID locale,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip) = 0;
    virtual HRESULT WINAPI BreakLineA(LCID locale,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip) = 0;
  };
#else
  typedef struct IMLangLineBreakConsoleVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangLineBreakConsole *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangLineBreakConsole *This);
      ULONG (WINAPI *Release)(IMLangLineBreakConsole *This);
      HRESULT (WINAPI *BreakLineML)(IMLangLineBreakConsole *This,IMLangString *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 cMinColumns,__LONG32 cMaxColumns,__LONG32 *plLineLen,__LONG32 *plSkipLen);
      HRESULT (WINAPI *BreakLineW)(IMLangLineBreakConsole *This,LCID locale,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip);
      HRESULT (WINAPI *BreakLineA)(IMLangLineBreakConsole *This,LCID locale,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip);
    END_INTERFACE
  } IMLangLineBreakConsoleVtbl;
  struct IMLangLineBreakConsole {
    CONST_VTBL struct IMLangLineBreakConsoleVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangLineBreakConsole_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangLineBreakConsole_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangLineBreakConsole_Release(This) (This)->lpVtbl->Release(This)
#define IMLangLineBreakConsole_BreakLineML(This,pSrcMLStr,lSrcPos,lSrcLen,cMinColumns,cMaxColumns,plLineLen,plSkipLen) (This)->lpVtbl->BreakLineML(This,pSrcMLStr,lSrcPos,lSrcLen,cMinColumns,cMaxColumns,plLineLen,plSkipLen)
#define IMLangLineBreakConsole_BreakLineW(This,locale,pszSrc,cchSrc,cMaxColumns,pcchLine,pcchSkip) (This)->lpVtbl->BreakLineW(This,locale,pszSrc,cchSrc,cMaxColumns,pcchLine,pcchSkip)
#define IMLangLineBreakConsole_BreakLineA(This,locale,uCodePage,pszSrc,cchSrc,cMaxColumns,pcchLine,pcchSkip) (This)->lpVtbl->BreakLineA(This,locale,uCodePage,pszSrc,cchSrc,cMaxColumns,pcchLine,pcchSkip)
#endif
#endif
  HRESULT WINAPI IMLangLineBreakConsole_BreakLineML_Proxy(IMLangLineBreakConsole *This,IMLangString *pSrcMLStr,__LONG32 lSrcPos,__LONG32 lSrcLen,__LONG32 cMinColumns,__LONG32 cMaxColumns,__LONG32 *plLineLen,__LONG32 *plSkipLen);
  void __RPC_STUB IMLangLineBreakConsole_BreakLineML_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangLineBreakConsole_BreakLineW_Proxy(IMLangLineBreakConsole *This,LCID locale,const WCHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip);
  void __RPC_STUB IMLangLineBreakConsole_BreakLineW_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangLineBreakConsole_BreakLineA_Proxy(IMLangLineBreakConsole *This,LCID locale,UINT uCodePage,const CHAR *pszSrc,__LONG32 cchSrc,__LONG32 cMaxColumns,__LONG32 *pcchLine,__LONG32 *pcchSkip);
  void __RPC_STUB IMLangLineBreakConsole_BreakLineA_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCodePage_INTERFACE_DEFINED__
#define __IEnumCodePage_INTERFACE_DEFINED__
#define MAX_MIMECP_NAME (64)
#define MAX_MIMECSET_NAME (50)
#define MAX_MIMEFACE_NAME (32)

  typedef enum tagMIMECONTF {
    MIMECONTF_MAILNEWS = 0x1,MIMECONTF_BROWSER = 0x2,MIMECONTF_MINIMAL = 0x4,MIMECONTF_IMPORT = 0x8,MIMECONTF_SAVABLE_MAILNEWS = 0x100,
    MIMECONTF_SAVABLE_BROWSER = 0x200,MIMECONTF_EXPORT = 0x400,MIMECONTF_PRIVCONVERTER = 0x10000,MIMECONTF_VALID = 0x20000,
    MIMECONTF_VALID_NLS = 0x40000,MIMECONTF_MIME_IE4 = 0x10000000,MIMECONTF_MIME_LATEST = 0x20000000,MIMECONTF_MIME_REGISTRY = 0x40000000
  } MIMECONTF;

  typedef struct tagMIMECPINFO {
    DWORD dwFlags;
    UINT uiCodePage;
    UINT uiFamilyCodePage;
    WCHAR wszDescription[64 ];
    WCHAR wszWebCharset[50 ];
    WCHAR wszHeaderCharset[50 ];
    WCHAR wszBodyCharset[50 ];
    WCHAR wszFixedWidthFont[32 ];
    WCHAR wszProportionalFont[32 ];
    BYTE bGDICharset;
  } MIMECPINFO;

  typedef struct tagMIMECPINFO *PMIMECPINFO;

  typedef struct tagMIMECSETINFO {
    UINT uiCodePage;
    UINT uiInternetEncoding;
    WCHAR wszCharset[50 ];
  } MIMECSETINFO;

  typedef struct tagMIMECSETINFO *PMIMECSETINFO;
  typedef IEnumCodePage *LPENUMCODEPAGE;

  EXTERN_C const IID IID_IEnumCodePage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCodePage : public IUnknown {
  public:
    virtual HRESULT WINAPI Clone(IEnumCodePage **ppEnum) = 0;
    virtual HRESULT WINAPI Next(ULONG celt,PMIMECPINFO rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
  };
#else
  typedef struct IEnumCodePageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCodePage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCodePage *This);
      ULONG (WINAPI *Release)(IEnumCodePage *This);
      HRESULT (WINAPI *Clone)(IEnumCodePage *This,IEnumCodePage **ppEnum);
      HRESULT (WINAPI *Next)(IEnumCodePage *This,ULONG celt,PMIMECPINFO rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumCodePage *This);
      HRESULT (WINAPI *Skip)(IEnumCodePage *This,ULONG celt);
    END_INTERFACE
  } IEnumCodePageVtbl;
  struct IEnumCodePage {
    CONST_VTBL struct IEnumCodePageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCodePage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCodePage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCodePage_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCodePage_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#define IEnumCodePage_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumCodePage_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCodePage_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#endif
#endif
  HRESULT WINAPI IEnumCodePage_Clone_Proxy(IEnumCodePage *This,IEnumCodePage **ppEnum);
  void __RPC_STUB IEnumCodePage_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCodePage_Next_Proxy(IEnumCodePage *This,ULONG celt,PMIMECPINFO rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumCodePage_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCodePage_Reset_Proxy(IEnumCodePage *This);
  void __RPC_STUB IEnumCodePage_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCodePage_Skip_Proxy(IEnumCodePage *This,ULONG celt);
  void __RPC_STUB IEnumCodePage_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumRfc1766_INTERFACE_DEFINED__
#define __IEnumRfc1766_INTERFACE_DEFINED__
#define MAX_RFC1766_NAME (6)
#define MAX_LOCALE_NAME (32)

  typedef struct tagRFC1766INFO {
    LCID lcid;
    WCHAR wszRfc1766[6 ];
    WCHAR wszLocaleName[32 ];
  } RFC1766INFO;

  typedef struct tagRFC1766INFO *PRFC1766INFO;
  typedef IEnumRfc1766 *LPENUMRFC1766;

  EXTERN_C const IID IID_IEnumRfc1766;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumRfc1766 : public IUnknown {
  public:
    virtual HRESULT WINAPI Clone(IEnumRfc1766 **ppEnum) = 0;
    virtual HRESULT WINAPI Next(ULONG celt,PRFC1766INFO rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
  };
#else
  typedef struct IEnumRfc1766Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumRfc1766 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumRfc1766 *This);
      ULONG (WINAPI *Release)(IEnumRfc1766 *This);
      HRESULT (WINAPI *Clone)(IEnumRfc1766 *This,IEnumRfc1766 **ppEnum);
      HRESULT (WINAPI *Next)(IEnumRfc1766 *This,ULONG celt,PRFC1766INFO rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumRfc1766 *This);
      HRESULT (WINAPI *Skip)(IEnumRfc1766 *This,ULONG celt);
    END_INTERFACE
  } IEnumRfc1766Vtbl;
  struct IEnumRfc1766 {
    CONST_VTBL struct IEnumRfc1766Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumRfc1766_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumRfc1766_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumRfc1766_Release(This) (This)->lpVtbl->Release(This)
#define IEnumRfc1766_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#define IEnumRfc1766_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumRfc1766_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumRfc1766_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#endif
#endif
  HRESULT WINAPI IEnumRfc1766_Clone_Proxy(IEnumRfc1766 *This,IEnumRfc1766 **ppEnum);
  void __RPC_STUB IEnumRfc1766_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumRfc1766_Next_Proxy(IEnumRfc1766 *This,ULONG celt,PRFC1766INFO rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumRfc1766_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumRfc1766_Reset_Proxy(IEnumRfc1766 *This);
  void __RPC_STUB IEnumRfc1766_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumRfc1766_Skip_Proxy(IEnumRfc1766 *This,ULONG celt);
  void __RPC_STUB IEnumRfc1766_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumScript_INTERFACE_DEFINED__
#define __IEnumScript_INTERFACE_DEFINED__
#define MAX_SCRIPT_NAME (48)

  typedef BYTE SCRIPT_ID;
  __MINGW_EXTENSION typedef __int64 SCRIPT_IDS;

  typedef enum tagSCRIPTCONTF {
    sidDefault = 0,sidMerge,sidAsciiSym,sidAsciiLatin,sidLatin,
    sidGreek,sidCyrillic,sidArmenian,sidHebrew,sidArabic,
    sidDevanagari,sidBengali,sidGurmukhi,sidGujarati,sidOriya,
    sidTamil,sidTelugu,sidKannada,sidMalayalam,sidThai,
    sidLao,sidTibetan,sidGeorgian,
    sidHangul,sidKana,sidBopomofo,sidHan,
    sidEthiopic,sidCanSyllabic,sidCherokee,
    sidYi,sidBraille,sidRunic,sidOgham,sidSinhala,
    sidSyriac,sidBurmese,sidKhmer,sidThaana,sidMongolian,
    sidUserDefined,sidLim,
    sidFEFirst = sidHangul,sidFELast = sidHan
  } SCRIPTCONTF;

  typedef struct tagSCRIPTINFO {
    SCRIPT_ID ScriptId;
    UINT uiCodePage;
    WCHAR wszDescription[48 ];
    WCHAR wszFixedWidthFont[32 ];
    WCHAR wszProportionalFont[32 ];
  } SCRIPTINFO;

  typedef struct tagSCRIPTINFO *PSCRIPTINFO;
  typedef IEnumScript *LPENUMScript;

  EXTERN_C const IID IID_IEnumScript;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumScript : public IUnknown {
  public:
    virtual HRESULT WINAPI Clone(IEnumScript **ppEnum) = 0;
    virtual HRESULT WINAPI Next(ULONG celt,PSCRIPTINFO rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
  };
#else
  typedef struct IEnumScriptVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumScript *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumScript *This);
      ULONG (WINAPI *Release)(IEnumScript *This);
      HRESULT (WINAPI *Clone)(IEnumScript *This,IEnumScript **ppEnum);
      HRESULT (WINAPI *Next)(IEnumScript *This,ULONG celt,PSCRIPTINFO rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumScript *This);
      HRESULT (WINAPI *Skip)(IEnumScript *This,ULONG celt);
    END_INTERFACE
  } IEnumScriptVtbl;
  struct IEnumScript {
    CONST_VTBL struct IEnumScriptVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumScript_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumScript_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumScript_Release(This) (This)->lpVtbl->Release(This)
#define IEnumScript_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#define IEnumScript_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumScript_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumScript_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#endif
#endif
  HRESULT WINAPI IEnumScript_Clone_Proxy(IEnumScript *This,IEnumScript **ppEnum);
  void __RPC_STUB IEnumScript_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumScript_Next_Proxy(IEnumScript *This,ULONG celt,PSCRIPTINFO rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumScript_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumScript_Reset_Proxy(IEnumScript *This);
  void __RPC_STUB IEnumScript_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumScript_Skip_Proxy(IEnumScript *This,ULONG celt);
  void __RPC_STUB IEnumScript_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangConvertCharset_INTERFACE_DEFINED__
#define __IMLangConvertCharset_INTERFACE_DEFINED__
  typedef enum tagMLCONVCHARF {
    MLCONVCHARF_AUTODETECT = 1,MLCONVCHARF_ENTITIZE = 2,MLCONVCHARF_NCR_ENTITIZE = 2,MLCONVCHARF_NAME_ENTITIZE = 4,MLCONVCHARF_USEDEFCHAR = 8,
    MLCONVCHARF_NOBESTFITCHARS = 16,MLCONVCHARF_DETECTJPN = 32
  } MLCONVCHAR;

  typedef enum tagMLCPF {
    MLDETECTF_MAILNEWS = 0x1,MLDETECTF_BROWSER = 0x2,MLDETECTF_VALID = 0x4,MLDETECTF_VALID_NLS = 0x8,MLDETECTF_PRESERVE_ORDER = 0x10,
    MLDETECTF_PREFERRED_ONLY = 0x20,MLDETECTF_FILTER_SPECIALCHAR = 0x40,MLDETECTF_EURO_UTF8 = 0x80
  } MLCP;

  typedef IMLangConvertCharset *LPMLANGCONVERTCHARSET;

  EXTERN_C const IID IID_IMLangConvertCharset;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangConvertCharset : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty) = 0;
    virtual HRESULT WINAPI GetSourceCodePage(UINT *puiSrcCodePage) = 0;
    virtual HRESULT WINAPI GetDestinationCodePage(UINT *puiDstCodePage) = 0;
    virtual HRESULT WINAPI GetProperty(DWORD *pdwProperty) = 0;
    virtual HRESULT WINAPI DoConversion(BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI DoConversionToUnicode(CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI DoConversionFromUnicode(WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize) = 0;
  };
#else
  typedef struct IMLangConvertCharsetVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangConvertCharset *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangConvertCharset *This);
      ULONG (WINAPI *Release)(IMLangConvertCharset *This);
      HRESULT (WINAPI *Initialize)(IMLangConvertCharset *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty);
      HRESULT (WINAPI *GetSourceCodePage)(IMLangConvertCharset *This,UINT *puiSrcCodePage);
      HRESULT (WINAPI *GetDestinationCodePage)(IMLangConvertCharset *This,UINT *puiDstCodePage);
      HRESULT (WINAPI *GetProperty)(IMLangConvertCharset *This,DWORD *pdwProperty);
      HRESULT (WINAPI *DoConversion)(IMLangConvertCharset *This,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *DoConversionToUnicode)(IMLangConvertCharset *This,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *DoConversionFromUnicode)(IMLangConvertCharset *This,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
    END_INTERFACE
  } IMLangConvertCharsetVtbl;
  struct IMLangConvertCharset {
    CONST_VTBL struct IMLangConvertCharsetVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangConvertCharset_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangConvertCharset_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangConvertCharset_Release(This) (This)->lpVtbl->Release(This)
#define IMLangConvertCharset_Initialize(This,uiSrcCodePage,uiDstCodePage,dwProperty) (This)->lpVtbl->Initialize(This,uiSrcCodePage,uiDstCodePage,dwProperty)
#define IMLangConvertCharset_GetSourceCodePage(This,puiSrcCodePage) (This)->lpVtbl->GetSourceCodePage(This,puiSrcCodePage)
#define IMLangConvertCharset_GetDestinationCodePage(This,puiDstCodePage) (This)->lpVtbl->GetDestinationCodePage(This,puiDstCodePage)
#define IMLangConvertCharset_GetProperty(This,pdwProperty) (This)->lpVtbl->GetProperty(This,pdwProperty)
#define IMLangConvertCharset_DoConversion(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->DoConversion(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMLangConvertCharset_DoConversionToUnicode(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->DoConversionToUnicode(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMLangConvertCharset_DoConversionFromUnicode(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->DoConversionFromUnicode(This,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#endif
#endif
  HRESULT WINAPI IMLangConvertCharset_Initialize_Proxy(IMLangConvertCharset *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty);
  void __RPC_STUB IMLangConvertCharset_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_GetSourceCodePage_Proxy(IMLangConvertCharset *This,UINT *puiSrcCodePage);
  void __RPC_STUB IMLangConvertCharset_GetSourceCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_GetDestinationCodePage_Proxy(IMLangConvertCharset *This,UINT *puiDstCodePage);
  void __RPC_STUB IMLangConvertCharset_GetDestinationCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_GetProperty_Proxy(IMLangConvertCharset *This,DWORD *pdwProperty);
  void __RPC_STUB IMLangConvertCharset_GetProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_DoConversion_Proxy(IMLangConvertCharset *This,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMLangConvertCharset_DoConversion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_DoConversionToUnicode_Proxy(IMLangConvertCharset *This,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMLangConvertCharset_DoConversionToUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangConvertCharset_DoConversionFromUnicode_Proxy(IMLangConvertCharset *This,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMLangConvertCharset_DoConversionFromUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_CMLangConvertCharset;
#ifdef __cplusplus
  class CMLangConvertCharset;
#endif

#ifndef __IMultiLanguage_INTERFACE_DEFINED__
#define __IMultiLanguage_INTERFACE_DEFINED__
  typedef IMultiLanguage *LPMULTILANGUAGE;

  EXTERN_C const IID IID_IMultiLanguage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultiLanguage : public IUnknown {
  public:
    virtual HRESULT WINAPI GetNumberOfCodePageInfo(UINT *pcCodePage) = 0;
    virtual HRESULT WINAPI GetCodePageInfo(UINT uiCodePage,PMIMECPINFO pCodePageInfo) = 0;
    virtual HRESULT WINAPI GetFamilyCodePage(UINT uiCodePage,UINT *puiFamilyCodePage) = 0;
    virtual HRESULT WINAPI EnumCodePages(DWORD grfFlags,IEnumCodePage **ppEnumCodePage) = 0;
    virtual HRESULT WINAPI GetCharsetInfo(BSTR Charset,PMIMECSETINFO pCharsetInfo) = 0;
    virtual HRESULT WINAPI IsConvertible(DWORD dwSrcEncoding,DWORD dwDstEncoding) = 0;
    virtual HRESULT WINAPI ConvertString(DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringToUnicode(DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringFromUnicode(DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringReset(void) = 0;
    virtual HRESULT WINAPI GetRfc1766FromLcid(LCID Locale,BSTR *pbstrRfc1766) = 0;
    virtual HRESULT WINAPI GetLcidFromRfc1766(LCID *pLocale,BSTR bstrRfc1766) = 0;
    virtual HRESULT WINAPI EnumRfc1766(IEnumRfc1766 **ppEnumRfc1766) = 0;
    virtual HRESULT WINAPI GetRfc1766Info(LCID Locale,PRFC1766INFO pRfc1766Info) = 0;
    virtual HRESULT WINAPI CreateConvertCharset(UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset) = 0;
  };
#else
  typedef struct IMultiLanguageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultiLanguage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultiLanguage *This);
      ULONG (WINAPI *Release)(IMultiLanguage *This);
      HRESULT (WINAPI *GetNumberOfCodePageInfo)(IMultiLanguage *This,UINT *pcCodePage);
      HRESULT (WINAPI *GetCodePageInfo)(IMultiLanguage *This,UINT uiCodePage,PMIMECPINFO pCodePageInfo);
      HRESULT (WINAPI *GetFamilyCodePage)(IMultiLanguage *This,UINT uiCodePage,UINT *puiFamilyCodePage);
      HRESULT (WINAPI *EnumCodePages)(IMultiLanguage *This,DWORD grfFlags,IEnumCodePage **ppEnumCodePage);
      HRESULT (WINAPI *GetCharsetInfo)(IMultiLanguage *This,BSTR Charset,PMIMECSETINFO pCharsetInfo);
      HRESULT (WINAPI *IsConvertible)(IMultiLanguage *This,DWORD dwSrcEncoding,DWORD dwDstEncoding);
      HRESULT (WINAPI *ConvertString)(IMultiLanguage *This,DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringToUnicode)(IMultiLanguage *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringFromUnicode)(IMultiLanguage *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringReset)(IMultiLanguage *This);
      HRESULT (WINAPI *GetRfc1766FromLcid)(IMultiLanguage *This,LCID Locale,BSTR *pbstrRfc1766);
      HRESULT (WINAPI *GetLcidFromRfc1766)(IMultiLanguage *This,LCID *pLocale,BSTR bstrRfc1766);
      HRESULT (WINAPI *EnumRfc1766)(IMultiLanguage *This,IEnumRfc1766 **ppEnumRfc1766);
      HRESULT (WINAPI *GetRfc1766Info)(IMultiLanguage *This,LCID Locale,PRFC1766INFO pRfc1766Info);
      HRESULT (WINAPI *CreateConvertCharset)(IMultiLanguage *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset);
    END_INTERFACE
  } IMultiLanguageVtbl;
  struct IMultiLanguage {
    CONST_VTBL struct IMultiLanguageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultiLanguage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultiLanguage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultiLanguage_Release(This) (This)->lpVtbl->Release(This)
#define IMultiLanguage_GetNumberOfCodePageInfo(This,pcCodePage) (This)->lpVtbl->GetNumberOfCodePageInfo(This,pcCodePage)
#define IMultiLanguage_GetCodePageInfo(This,uiCodePage,pCodePageInfo) (This)->lpVtbl->GetCodePageInfo(This,uiCodePage,pCodePageInfo)
#define IMultiLanguage_GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage) (This)->lpVtbl->GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage)
#define IMultiLanguage_EnumCodePages(This,grfFlags,ppEnumCodePage) (This)->lpVtbl->EnumCodePages(This,grfFlags,ppEnumCodePage)
#define IMultiLanguage_GetCharsetInfo(This,Charset,pCharsetInfo) (This)->lpVtbl->GetCharsetInfo(This,Charset,pCharsetInfo)
#define IMultiLanguage_IsConvertible(This,dwSrcEncoding,dwDstEncoding) (This)->lpVtbl->IsConvertible(This,dwSrcEncoding,dwDstEncoding)
#define IMultiLanguage_ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage_ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage_ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage_ConvertStringReset(This) (This)->lpVtbl->ConvertStringReset(This)
#define IMultiLanguage_GetRfc1766FromLcid(This,Locale,pbstrRfc1766) (This)->lpVtbl->GetRfc1766FromLcid(This,Locale,pbstrRfc1766)
#define IMultiLanguage_GetLcidFromRfc1766(This,pLocale,bstrRfc1766) (This)->lpVtbl->GetLcidFromRfc1766(This,pLocale,bstrRfc1766)
#define IMultiLanguage_EnumRfc1766(This,ppEnumRfc1766) (This)->lpVtbl->EnumRfc1766(This,ppEnumRfc1766)
#define IMultiLanguage_GetRfc1766Info(This,Locale,pRfc1766Info) (This)->lpVtbl->GetRfc1766Info(This,Locale,pRfc1766Info)
#define IMultiLanguage_CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset) (This)->lpVtbl->CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset)
#endif
#endif
  HRESULT WINAPI IMultiLanguage_GetNumberOfCodePageInfo_Proxy(IMultiLanguage *This,UINT *pcCodePage);
  void __RPC_STUB IMultiLanguage_GetNumberOfCodePageInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetCodePageInfo_Proxy(IMultiLanguage *This,UINT uiCodePage,PMIMECPINFO pCodePageInfo);
  void __RPC_STUB IMultiLanguage_GetCodePageInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetFamilyCodePage_Proxy(IMultiLanguage *This,UINT uiCodePage,UINT *puiFamilyCodePage);
  void __RPC_STUB IMultiLanguage_GetFamilyCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_EnumCodePages_Proxy(IMultiLanguage *This,DWORD grfFlags,IEnumCodePage **ppEnumCodePage);
  void __RPC_STUB IMultiLanguage_EnumCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetCharsetInfo_Proxy(IMultiLanguage *This,BSTR Charset,PMIMECSETINFO pCharsetInfo);
  void __RPC_STUB IMultiLanguage_GetCharsetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_IsConvertible_Proxy(IMultiLanguage *This,DWORD dwSrcEncoding,DWORD dwDstEncoding);
  void __RPC_STUB IMultiLanguage_IsConvertible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_ConvertString_Proxy(IMultiLanguage *This,DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage_ConvertString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_ConvertStringToUnicode_Proxy(IMultiLanguage *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage_ConvertStringToUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_ConvertStringFromUnicode_Proxy(IMultiLanguage *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage_ConvertStringFromUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_ConvertStringReset_Proxy(IMultiLanguage *This);
  void __RPC_STUB IMultiLanguage_ConvertStringReset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetRfc1766FromLcid_Proxy(IMultiLanguage *This,LCID Locale,BSTR *pbstrRfc1766);
  void __RPC_STUB IMultiLanguage_GetRfc1766FromLcid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetLcidFromRfc1766_Proxy(IMultiLanguage *This,LCID *pLocale,BSTR bstrRfc1766);
  void __RPC_STUB IMultiLanguage_GetLcidFromRfc1766_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_EnumRfc1766_Proxy(IMultiLanguage *This,IEnumRfc1766 **ppEnumRfc1766);
  void __RPC_STUB IMultiLanguage_EnumRfc1766_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_GetRfc1766Info_Proxy(IMultiLanguage *This,LCID Locale,PRFC1766INFO pRfc1766Info);
  void __RPC_STUB IMultiLanguage_GetRfc1766Info_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage_CreateConvertCharset_Proxy(IMultiLanguage *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset);
  void __RPC_STUB IMultiLanguage_CreateConvertCharset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMultiLanguage2_INTERFACE_DEFINED__
#define __IMultiLanguage2_INTERFACE_DEFINED__
  typedef IMultiLanguage2 *LPMULTILANGUAGE2;

  typedef enum tagMLDETECTCP {
    MLDETECTCP_NONE = 0,MLDETECTCP_7BIT = 1,MLDETECTCP_8BIT = 2,MLDETECTCP_DBCS = 4,MLDETECTCP_HTML = 8,MLDETECTCP_NUMBER = 16
  } MLDETECTCP;

  typedef struct tagDetectEncodingInfo {
    UINT nLangID;
    UINT nCodePage;
    INT nDocPercent;
    INT nConfidence;
  } DetectEncodingInfo;

  typedef struct tagDetectEncodingInfo *pDetectEncodingInfo;

  typedef enum tagSCRIPTFONTCONTF {
    SCRIPTCONTF_FIXED_FONT = 0x1,SCRIPTCONTF_PROPORTIONAL_FONT = 0x2,SCRIPTCONTF_SCRIPT_USER = 0x10000,SCRIPTCONTF_SCRIPT_HIDE = 0x20000,
    SCRIPTCONTF_SCRIPT_SYSTEM = 0x40000
  } SCRIPTFONTCONTF;

  typedef struct tagSCRIPFONTINFO {
    SCRIPT_IDS scripts;
    WCHAR wszFont[32 ];
  } SCRIPTFONTINFO;

  typedef struct tagSCRIPFONTINFO *PSCRIPTFONTINFO;

  EXTERN_C const IID IID_IMultiLanguage2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultiLanguage2 : public IUnknown {
  public:
    virtual HRESULT WINAPI GetNumberOfCodePageInfo(UINT *pcCodePage) = 0;
    virtual HRESULT WINAPI GetCodePageInfo(UINT uiCodePage,LANGID LangId,PMIMECPINFO pCodePageInfo) = 0;
    virtual HRESULT WINAPI GetFamilyCodePage(UINT uiCodePage,UINT *puiFamilyCodePage) = 0;
    virtual HRESULT WINAPI EnumCodePages(DWORD grfFlags,LANGID LangId,IEnumCodePage **ppEnumCodePage) = 0;
    virtual HRESULT WINAPI GetCharsetInfo(BSTR Charset,PMIMECSETINFO pCharsetInfo) = 0;
    virtual HRESULT WINAPI IsConvertible(DWORD dwSrcEncoding,DWORD dwDstEncoding) = 0;
    virtual HRESULT WINAPI ConvertString(DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringToUnicode(DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringFromUnicode(DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize) = 0;
    virtual HRESULT WINAPI ConvertStringReset(void) = 0;
    virtual HRESULT WINAPI GetRfc1766FromLcid(LCID Locale,BSTR *pbstrRfc1766) = 0;
    virtual HRESULT WINAPI GetLcidFromRfc1766(LCID *pLocale,BSTR bstrRfc1766) = 0;
    virtual HRESULT WINAPI EnumRfc1766(LANGID LangId,IEnumRfc1766 **ppEnumRfc1766) = 0;
    virtual HRESULT WINAPI GetRfc1766Info(LCID Locale,LANGID LangId,PRFC1766INFO pRfc1766Info) = 0;
    virtual HRESULT WINAPI CreateConvertCharset(UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset) = 0;
    virtual HRESULT WINAPI ConvertStringInIStream(DWORD *pdwMode,DWORD dwFlag,WCHAR *lpFallBack,DWORD dwSrcEncoding,DWORD dwDstEncoding,IStream *pstmIn,IStream *pstmOut) = 0;
    virtual HRESULT WINAPI ConvertStringToUnicodeEx(DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack) = 0;
    virtual HRESULT WINAPI ConvertStringFromUnicodeEx(DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack) = 0;
    virtual HRESULT WINAPI DetectCodepageInIStream(DWORD dwFlag,DWORD dwPrefWinCodePage,IStream *pstmIn,DetectEncodingInfo *lpEncoding,INT *pnScores) = 0;
    virtual HRESULT WINAPI DetectInputCodepage(DWORD dwFlag,DWORD dwPrefWinCodePage,CHAR *pSrcStr,INT *pcSrcSize,DetectEncodingInfo *lpEncoding,INT *pnScores) = 0;
    virtual HRESULT WINAPI ValidateCodePage(UINT uiCodePage,HWND hwnd) = 0;
    virtual HRESULT WINAPI GetCodePageDescription(UINT uiCodePage,LCID lcid,LPWSTR lpWideCharStr,int cchWideChar) = 0;
    virtual HRESULT WINAPI IsCodePageInstallable(UINT uiCodePage) = 0;
    virtual HRESULT WINAPI SetMimeDBSource(MIMECONTF dwSource) = 0;
    virtual HRESULT WINAPI GetNumberOfScripts(UINT *pnScripts) = 0;
    virtual HRESULT WINAPI EnumScripts(DWORD dwFlags,LANGID LangId,IEnumScript **ppEnumScript) = 0;
    virtual HRESULT WINAPI ValidateCodePageEx(UINT uiCodePage,HWND hwnd,DWORD dwfIODControl) = 0;
  };
#else
  typedef struct IMultiLanguage2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultiLanguage2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultiLanguage2 *This);
      ULONG (WINAPI *Release)(IMultiLanguage2 *This);
      HRESULT (WINAPI *GetNumberOfCodePageInfo)(IMultiLanguage2 *This,UINT *pcCodePage);
      HRESULT (WINAPI *GetCodePageInfo)(IMultiLanguage2 *This,UINT uiCodePage,LANGID LangId,PMIMECPINFO pCodePageInfo);
      HRESULT (WINAPI *GetFamilyCodePage)(IMultiLanguage2 *This,UINT uiCodePage,UINT *puiFamilyCodePage);
      HRESULT (WINAPI *EnumCodePages)(IMultiLanguage2 *This,DWORD grfFlags,LANGID LangId,IEnumCodePage **ppEnumCodePage);
      HRESULT (WINAPI *GetCharsetInfo)(IMultiLanguage2 *This,BSTR Charset,PMIMECSETINFO pCharsetInfo);
      HRESULT (WINAPI *IsConvertible)(IMultiLanguage2 *This,DWORD dwSrcEncoding,DWORD dwDstEncoding);
      HRESULT (WINAPI *ConvertString)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringToUnicode)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringFromUnicode)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringReset)(IMultiLanguage2 *This);
      HRESULT (WINAPI *GetRfc1766FromLcid)(IMultiLanguage2 *This,LCID Locale,BSTR *pbstrRfc1766);
      HRESULT (WINAPI *GetLcidFromRfc1766)(IMultiLanguage2 *This,LCID *pLocale,BSTR bstrRfc1766);
      HRESULT (WINAPI *EnumRfc1766)(IMultiLanguage2 *This,LANGID LangId,IEnumRfc1766 **ppEnumRfc1766);
      HRESULT (WINAPI *GetRfc1766Info)(IMultiLanguage2 *This,LCID Locale,LANGID LangId,PRFC1766INFO pRfc1766Info);
      HRESULT (WINAPI *CreateConvertCharset)(IMultiLanguage2 *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset);
      HRESULT (WINAPI *ConvertStringInIStream)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwFlag,WCHAR *lpFallBack,DWORD dwSrcEncoding,DWORD dwDstEncoding,IStream *pstmIn,IStream *pstmOut);
      HRESULT (WINAPI *ConvertStringToUnicodeEx)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
      HRESULT (WINAPI *ConvertStringFromUnicodeEx)(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
      HRESULT (WINAPI *DetectCodepageInIStream)(IMultiLanguage2 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,IStream *pstmIn,DetectEncodingInfo *lpEncoding,INT *pnScores);
      HRESULT (WINAPI *DetectInputCodepage)(IMultiLanguage2 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,CHAR *pSrcStr,INT *pcSrcSize,DetectEncodingInfo *lpEncoding,INT *pnScores);
      HRESULT (WINAPI *ValidateCodePage)(IMultiLanguage2 *This,UINT uiCodePage,HWND hwnd);
      HRESULT (WINAPI *GetCodePageDescription)(IMultiLanguage2 *This,UINT uiCodePage,LCID lcid,LPWSTR lpWideCharStr,int cchWideChar);
      HRESULT (WINAPI *IsCodePageInstallable)(IMultiLanguage2 *This,UINT uiCodePage);
      HRESULT (WINAPI *SetMimeDBSource)(IMultiLanguage2 *This,MIMECONTF dwSource);
      HRESULT (WINAPI *GetNumberOfScripts)(IMultiLanguage2 *This,UINT *pnScripts);
      HRESULT (WINAPI *EnumScripts)(IMultiLanguage2 *This,DWORD dwFlags,LANGID LangId,IEnumScript **ppEnumScript);
      HRESULT (WINAPI *ValidateCodePageEx)(IMultiLanguage2 *This,UINT uiCodePage,HWND hwnd,DWORD dwfIODControl);
    END_INTERFACE
  } IMultiLanguage2Vtbl;
  struct IMultiLanguage2 {
    CONST_VTBL struct IMultiLanguage2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultiLanguage2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultiLanguage2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultiLanguage2_Release(This) (This)->lpVtbl->Release(This)
#define IMultiLanguage2_GetNumberOfCodePageInfo(This,pcCodePage) (This)->lpVtbl->GetNumberOfCodePageInfo(This,pcCodePage)
#define IMultiLanguage2_GetCodePageInfo(This,uiCodePage,LangId,pCodePageInfo) (This)->lpVtbl->GetCodePageInfo(This,uiCodePage,LangId,pCodePageInfo)
#define IMultiLanguage2_GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage) (This)->lpVtbl->GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage)
#define IMultiLanguage2_EnumCodePages(This,grfFlags,LangId,ppEnumCodePage) (This)->lpVtbl->EnumCodePages(This,grfFlags,LangId,ppEnumCodePage)
#define IMultiLanguage2_GetCharsetInfo(This,Charset,pCharsetInfo) (This)->lpVtbl->GetCharsetInfo(This,Charset,pCharsetInfo)
#define IMultiLanguage2_IsConvertible(This,dwSrcEncoding,dwDstEncoding) (This)->lpVtbl->IsConvertible(This,dwSrcEncoding,dwDstEncoding)
#define IMultiLanguage2_ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage2_ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage2_ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage2_ConvertStringReset(This) (This)->lpVtbl->ConvertStringReset(This)
#define IMultiLanguage2_GetRfc1766FromLcid(This,Locale,pbstrRfc1766) (This)->lpVtbl->GetRfc1766FromLcid(This,Locale,pbstrRfc1766)
#define IMultiLanguage2_GetLcidFromRfc1766(This,pLocale,bstrRfc1766) (This)->lpVtbl->GetLcidFromRfc1766(This,pLocale,bstrRfc1766)
#define IMultiLanguage2_EnumRfc1766(This,LangId,ppEnumRfc1766) (This)->lpVtbl->EnumRfc1766(This,LangId,ppEnumRfc1766)
#define IMultiLanguage2_GetRfc1766Info(This,Locale,LangId,pRfc1766Info) (This)->lpVtbl->GetRfc1766Info(This,Locale,LangId,pRfc1766Info)
#define IMultiLanguage2_CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset) (This)->lpVtbl->CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset)
#define IMultiLanguage2_ConvertStringInIStream(This,pdwMode,dwFlag,lpFallBack,dwSrcEncoding,dwDstEncoding,pstmIn,pstmOut) (This)->lpVtbl->ConvertStringInIStream(This,pdwMode,dwFlag,lpFallBack,dwSrcEncoding,dwDstEncoding,pstmIn,pstmOut)
#define IMultiLanguage2_ConvertStringToUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack) (This)->lpVtbl->ConvertStringToUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack)
#define IMultiLanguage2_ConvertStringFromUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack) (This)->lpVtbl->ConvertStringFromUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack)
#define IMultiLanguage2_DetectCodepageInIStream(This,dwFlag,dwPrefWinCodePage,pstmIn,lpEncoding,pnScores) (This)->lpVtbl->DetectCodepageInIStream(This,dwFlag,dwPrefWinCodePage,pstmIn,lpEncoding,pnScores)
#define IMultiLanguage2_DetectInputCodepage(This,dwFlag,dwPrefWinCodePage,pSrcStr,pcSrcSize,lpEncoding,pnScores) (This)->lpVtbl->DetectInputCodepage(This,dwFlag,dwPrefWinCodePage,pSrcStr,pcSrcSize,lpEncoding,pnScores)
#define IMultiLanguage2_ValidateCodePage(This,uiCodePage,hwnd) (This)->lpVtbl->ValidateCodePage(This,uiCodePage,hwnd)
#define IMultiLanguage2_GetCodePageDescription(This,uiCodePage,lcid,lpWideCharStr,cchWideChar) (This)->lpVtbl->GetCodePageDescription(This,uiCodePage,lcid,lpWideCharStr,cchWideChar)
#define IMultiLanguage2_IsCodePageInstallable(This,uiCodePage) (This)->lpVtbl->IsCodePageInstallable(This,uiCodePage)
#define IMultiLanguage2_SetMimeDBSource(This,dwSource) (This)->lpVtbl->SetMimeDBSource(This,dwSource)
#define IMultiLanguage2_GetNumberOfScripts(This,pnScripts) (This)->lpVtbl->GetNumberOfScripts(This,pnScripts)
#define IMultiLanguage2_EnumScripts(This,dwFlags,LangId,ppEnumScript) (This)->lpVtbl->EnumScripts(This,dwFlags,LangId,ppEnumScript)
#define IMultiLanguage2_ValidateCodePageEx(This,uiCodePage,hwnd,dwfIODControl) (This)->lpVtbl->ValidateCodePageEx(This,uiCodePage,hwnd,dwfIODControl)
#endif
#endif
  HRESULT WINAPI IMultiLanguage2_GetNumberOfCodePageInfo_Proxy(IMultiLanguage2 *This,UINT *pcCodePage);
  void __RPC_STUB IMultiLanguage2_GetNumberOfCodePageInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetCodePageInfo_Proxy(IMultiLanguage2 *This,UINT uiCodePage,LANGID LangId,PMIMECPINFO pCodePageInfo);
  void __RPC_STUB IMultiLanguage2_GetCodePageInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetFamilyCodePage_Proxy(IMultiLanguage2 *This,UINT uiCodePage,UINT *puiFamilyCodePage);
  void __RPC_STUB IMultiLanguage2_GetFamilyCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_EnumCodePages_Proxy(IMultiLanguage2 *This,DWORD grfFlags,LANGID LangId,IEnumCodePage **ppEnumCodePage);
  void __RPC_STUB IMultiLanguage2_EnumCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetCharsetInfo_Proxy(IMultiLanguage2 *This,BSTR Charset,PMIMECSETINFO pCharsetInfo);
  void __RPC_STUB IMultiLanguage2_GetCharsetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_IsConvertible_Proxy(IMultiLanguage2 *This,DWORD dwSrcEncoding,DWORD dwDstEncoding);
  void __RPC_STUB IMultiLanguage2_IsConvertible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertString_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage2_ConvertString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringToUnicode_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage2_ConvertStringToUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringFromUnicode_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
  void __RPC_STUB IMultiLanguage2_ConvertStringFromUnicode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringReset_Proxy(IMultiLanguage2 *This);
  void __RPC_STUB IMultiLanguage2_ConvertStringReset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetRfc1766FromLcid_Proxy(IMultiLanguage2 *This,LCID Locale,BSTR *pbstrRfc1766);
  void __RPC_STUB IMultiLanguage2_GetRfc1766FromLcid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetLcidFromRfc1766_Proxy(IMultiLanguage2 *This,LCID *pLocale,BSTR bstrRfc1766);
  void __RPC_STUB IMultiLanguage2_GetLcidFromRfc1766_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_EnumRfc1766_Proxy(IMultiLanguage2 *This,LANGID LangId,IEnumRfc1766 **ppEnumRfc1766);
  void __RPC_STUB IMultiLanguage2_EnumRfc1766_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetRfc1766Info_Proxy(IMultiLanguage2 *This,LCID Locale,LANGID LangId,PRFC1766INFO pRfc1766Info);
  void __RPC_STUB IMultiLanguage2_GetRfc1766Info_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_CreateConvertCharset_Proxy(IMultiLanguage2 *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset);
  void __RPC_STUB IMultiLanguage2_CreateConvertCharset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringInIStream_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwFlag,WCHAR *lpFallBack,DWORD dwSrcEncoding,DWORD dwDstEncoding,IStream *pstmIn,IStream *pstmOut);
  void __RPC_STUB IMultiLanguage2_ConvertStringInIStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringToUnicodeEx_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
  void __RPC_STUB IMultiLanguage2_ConvertStringToUnicodeEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ConvertStringFromUnicodeEx_Proxy(IMultiLanguage2 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
  void __RPC_STUB IMultiLanguage2_ConvertStringFromUnicodeEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_DetectCodepageInIStream_Proxy(IMultiLanguage2 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,IStream *pstmIn,DetectEncodingInfo *lpEncoding,INT *pnScores);
  void __RPC_STUB IMultiLanguage2_DetectCodepageInIStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_DetectInputCodepage_Proxy(IMultiLanguage2 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,CHAR *pSrcStr,INT *pcSrcSize,DetectEncodingInfo *lpEncoding,INT *pnScores);
  void __RPC_STUB IMultiLanguage2_DetectInputCodepage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ValidateCodePage_Proxy(IMultiLanguage2 *This,UINT uiCodePage,HWND hwnd);
  void __RPC_STUB IMultiLanguage2_ValidateCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetCodePageDescription_Proxy(IMultiLanguage2 *This,UINT uiCodePage,LCID lcid,LPWSTR lpWideCharStr,int cchWideChar);
  void __RPC_STUB IMultiLanguage2_GetCodePageDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_IsCodePageInstallable_Proxy(IMultiLanguage2 *This,UINT uiCodePage);
  void __RPC_STUB IMultiLanguage2_IsCodePageInstallable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_SetMimeDBSource_Proxy(IMultiLanguage2 *This,MIMECONTF dwSource);
  void __RPC_STUB IMultiLanguage2_SetMimeDBSource_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_GetNumberOfScripts_Proxy(IMultiLanguage2 *This,UINT *pnScripts);
  void __RPC_STUB IMultiLanguage2_GetNumberOfScripts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_EnumScripts_Proxy(IMultiLanguage2 *This,DWORD dwFlags,LANGID LangId,IEnumScript **ppEnumScript);
  void __RPC_STUB IMultiLanguage2_EnumScripts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage2_ValidateCodePageEx_Proxy(IMultiLanguage2 *This,UINT uiCodePage,HWND hwnd,DWORD dwfIODControl);
  void __RPC_STUB IMultiLanguage2_ValidateCodePageEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangCodePages_INTERFACE_DEFINED__
#define __IMLangCodePages_INTERFACE_DEFINED__
  typedef IMLangCodePages *PMLANGCODEPAGES;

  EXTERN_C const IID IID_IMLangCodePages;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangCodePages : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCharCodePages(WCHAR chSrc,DWORD *pdwCodePages) = 0;
    virtual HRESULT WINAPI GetStrCodePages(const WCHAR *pszSrc,__LONG32 cchSrc,DWORD dwPriorityCodePages,DWORD *pdwCodePages,__LONG32 *pcchCodePages) = 0;
    virtual HRESULT WINAPI CodePageToCodePages(UINT uCodePage,DWORD *pdwCodePages) = 0;
    virtual HRESULT WINAPI CodePagesToCodePage(DWORD dwCodePages,UINT uDefaultCodePage,UINT *puCodePage) = 0;
  };
#else
  typedef struct IMLangCodePagesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangCodePages *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangCodePages *This);
      ULONG (WINAPI *Release)(IMLangCodePages *This);
      HRESULT (WINAPI *GetCharCodePages)(IMLangCodePages *This,WCHAR chSrc,DWORD *pdwCodePages);
      HRESULT (WINAPI *GetStrCodePages)(IMLangCodePages *This,const WCHAR *pszSrc,__LONG32 cchSrc,DWORD dwPriorityCodePages,DWORD *pdwCodePages,__LONG32 *pcchCodePages);
      HRESULT (WINAPI *CodePageToCodePages)(IMLangCodePages *This,UINT uCodePage,DWORD *pdwCodePages);
      HRESULT (WINAPI *CodePagesToCodePage)(IMLangCodePages *This,DWORD dwCodePages,UINT uDefaultCodePage,UINT *puCodePage);
    END_INTERFACE
  } IMLangCodePagesVtbl;
  struct IMLangCodePages {
    CONST_VTBL struct IMLangCodePagesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangCodePages_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangCodePages_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangCodePages_Release(This) (This)->lpVtbl->Release(This)
#define IMLangCodePages_GetCharCodePages(This,chSrc,pdwCodePages) (This)->lpVtbl->GetCharCodePages(This,chSrc,pdwCodePages)
#define IMLangCodePages_GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages) (This)->lpVtbl->GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages)
#define IMLangCodePages_CodePageToCodePages(This,uCodePage,pdwCodePages) (This)->lpVtbl->CodePageToCodePages(This,uCodePage,pdwCodePages)
#define IMLangCodePages_CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage) (This)->lpVtbl->CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage)
#endif
#endif
  HRESULT WINAPI IMLangCodePages_GetCharCodePages_Proxy(IMLangCodePages *This,WCHAR chSrc,DWORD *pdwCodePages);
  void __RPC_STUB IMLangCodePages_GetCharCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangCodePages_GetStrCodePages_Proxy(IMLangCodePages *This,const WCHAR *pszSrc,__LONG32 cchSrc,DWORD dwPriorityCodePages,DWORD *pdwCodePages,__LONG32 *pcchCodePages);
  void __RPC_STUB IMLangCodePages_GetStrCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangCodePages_CodePageToCodePages_Proxy(IMLangCodePages *This,UINT uCodePage,DWORD *pdwCodePages);
  void __RPC_STUB IMLangCodePages_CodePageToCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangCodePages_CodePagesToCodePage_Proxy(IMLangCodePages *This,DWORD dwCodePages,UINT uDefaultCodePage,UINT *puCodePage);
  void __RPC_STUB IMLangCodePages_CodePagesToCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangFontLink_INTERFACE_DEFINED__
#define __IMLangFontLink_INTERFACE_DEFINED__
  typedef IMLangFontLink *PMLANGFONTLINK;

  EXTERN_C const IID IID_IMLangFontLink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangFontLink : public IMLangCodePages {
  public:
    virtual HRESULT WINAPI GetFontCodePages(HDC hDC,HFONT hFont,DWORD *pdwCodePages) = 0;
    virtual HRESULT WINAPI MapFont(HDC hDC,DWORD dwCodePages,HFONT hSrcFont,HFONT *phDestFont) = 0;
    virtual HRESULT WINAPI ReleaseFont(HFONT hFont) = 0;
    virtual HRESULT WINAPI ResetFontMapping(void) = 0;
  };
#else
  typedef struct IMLangFontLinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangFontLink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangFontLink *This);
      ULONG (WINAPI *Release)(IMLangFontLink *This);
      HRESULT (WINAPI *GetCharCodePages)(IMLangFontLink *This,WCHAR chSrc,DWORD *pdwCodePages);
      HRESULT (WINAPI *GetStrCodePages)(IMLangFontLink *This,const WCHAR *pszSrc,__LONG32 cchSrc,DWORD dwPriorityCodePages,DWORD *pdwCodePages,__LONG32 *pcchCodePages);
      HRESULT (WINAPI *CodePageToCodePages)(IMLangFontLink *This,UINT uCodePage,DWORD *pdwCodePages);
      HRESULT (WINAPI *CodePagesToCodePage)(IMLangFontLink *This,DWORD dwCodePages,UINT uDefaultCodePage,UINT *puCodePage);
      HRESULT (WINAPI *GetFontCodePages)(IMLangFontLink *This,HDC hDC,HFONT hFont,DWORD *pdwCodePages);
      HRESULT (WINAPI *MapFont)(IMLangFontLink *This,HDC hDC,DWORD dwCodePages,HFONT hSrcFont,HFONT *phDestFont);
      HRESULT (WINAPI *ReleaseFont)(IMLangFontLink *This,HFONT hFont);
      HRESULT (WINAPI *ResetFontMapping)(IMLangFontLink *This);
    END_INTERFACE
  } IMLangFontLinkVtbl;
  struct IMLangFontLink {
    CONST_VTBL struct IMLangFontLinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangFontLink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangFontLink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangFontLink_Release(This) (This)->lpVtbl->Release(This)
#define IMLangFontLink_GetCharCodePages(This,chSrc,pdwCodePages) (This)->lpVtbl->GetCharCodePages(This,chSrc,pdwCodePages)
#define IMLangFontLink_GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages) (This)->lpVtbl->GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages)
#define IMLangFontLink_CodePageToCodePages(This,uCodePage,pdwCodePages) (This)->lpVtbl->CodePageToCodePages(This,uCodePage,pdwCodePages)
#define IMLangFontLink_CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage) (This)->lpVtbl->CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage)
#define IMLangFontLink_GetFontCodePages(This,hDC,hFont,pdwCodePages) (This)->lpVtbl->GetFontCodePages(This,hDC,hFont,pdwCodePages)
#define IMLangFontLink_MapFont(This,hDC,dwCodePages,hSrcFont,phDestFont) (This)->lpVtbl->MapFont(This,hDC,dwCodePages,hSrcFont,phDestFont)
#define IMLangFontLink_ReleaseFont(This,hFont) (This)->lpVtbl->ReleaseFont(This,hFont)
#define IMLangFontLink_ResetFontMapping(This) (This)->lpVtbl->ResetFontMapping(This)
#endif
#endif
  HRESULT WINAPI IMLangFontLink_GetFontCodePages_Proxy(IMLangFontLink *This,HDC hDC,HFONT hFont,DWORD *pdwCodePages);
  void __RPC_STUB IMLangFontLink_GetFontCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink_MapFont_Proxy(IMLangFontLink *This,HDC hDC,DWORD dwCodePages,HFONT hSrcFont,HFONT *phDestFont);
  void __RPC_STUB IMLangFontLink_MapFont_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink_ReleaseFont_Proxy(IMLangFontLink *This,HFONT hFont);
  void __RPC_STUB IMLangFontLink_ReleaseFont_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink_ResetFontMapping_Proxy(IMLangFontLink *This);
  void __RPC_STUB IMLangFontLink_ResetFontMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMLangFontLink2_INTERFACE_DEFINED__
#define __IMLangFontLink2_INTERFACE_DEFINED__
  typedef struct tagUNICODERANGE {
    WCHAR wcFrom;
    WCHAR wcTo;
  } UNICODERANGE;

  typedef IMLangFontLink2 *PMLANGFONTLINK2;

  EXTERN_C const IID IID_IMLangFontLink2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMLangFontLink2 : public IMLangCodePages {
  public:
    virtual HRESULT WINAPI GetFontCodePages(HDC hDC,HFONT hFont,DWORD *pdwCodePages) = 0;
    virtual HRESULT WINAPI ReleaseFont(HFONT hFont) = 0;
    virtual HRESULT WINAPI ResetFontMapping(void) = 0;
    virtual HRESULT WINAPI MapFont(HDC hDC,DWORD dwCodePages,WCHAR chSrc,HFONT *pFont) = 0;
    virtual HRESULT WINAPI GetFontUnicodeRanges(HDC hDC,UINT *puiRanges,UNICODERANGE *pUranges) = 0;
    virtual HRESULT WINAPI GetScriptFontInfo(SCRIPT_ID sid,DWORD dwFlags,UINT *puiFonts,SCRIPTFONTINFO *pScriptFont) = 0;
    virtual HRESULT WINAPI CodePageToScriptID(UINT uiCodePage,SCRIPT_ID *pSid) = 0;
  };
#else
  typedef struct IMLangFontLink2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMLangFontLink2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMLangFontLink2 *This);
      ULONG (WINAPI *Release)(IMLangFontLink2 *This);
      HRESULT (WINAPI *GetCharCodePages)(IMLangFontLink2 *This,WCHAR chSrc,DWORD *pdwCodePages);
      HRESULT (WINAPI *GetStrCodePages)(IMLangFontLink2 *This,const WCHAR *pszSrc,__LONG32 cchSrc,DWORD dwPriorityCodePages,DWORD *pdwCodePages,__LONG32 *pcchCodePages);
      HRESULT (WINAPI *CodePageToCodePages)(IMLangFontLink2 *This,UINT uCodePage,DWORD *pdwCodePages);
      HRESULT (WINAPI *CodePagesToCodePage)(IMLangFontLink2 *This,DWORD dwCodePages,UINT uDefaultCodePage,UINT *puCodePage);
      HRESULT (WINAPI *GetFontCodePages)(IMLangFontLink2 *This,HDC hDC,HFONT hFont,DWORD *pdwCodePages);
      HRESULT (WINAPI *ReleaseFont)(IMLangFontLink2 *This,HFONT hFont);
      HRESULT (WINAPI *ResetFontMapping)(IMLangFontLink2 *This);
      HRESULT (WINAPI *MapFont)(IMLangFontLink2 *This,HDC hDC,DWORD dwCodePages,WCHAR chSrc,HFONT *pFont);
      HRESULT (WINAPI *GetFontUnicodeRanges)(IMLangFontLink2 *This,HDC hDC,UINT *puiRanges,UNICODERANGE *pUranges);
      HRESULT (WINAPI *GetScriptFontInfo)(IMLangFontLink2 *This,SCRIPT_ID sid,DWORD dwFlags,UINT *puiFonts,SCRIPTFONTINFO *pScriptFont);
      HRESULT (WINAPI *CodePageToScriptID)(IMLangFontLink2 *This,UINT uiCodePage,SCRIPT_ID *pSid);
    END_INTERFACE
  } IMLangFontLink2Vtbl;
  struct IMLangFontLink2 {
    CONST_VTBL struct IMLangFontLink2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMLangFontLink2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMLangFontLink2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMLangFontLink2_Release(This) (This)->lpVtbl->Release(This)
#define IMLangFontLink2_GetCharCodePages(This,chSrc,pdwCodePages) (This)->lpVtbl->GetCharCodePages(This,chSrc,pdwCodePages)
#define IMLangFontLink2_GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages) (This)->lpVtbl->GetStrCodePages(This,pszSrc,cchSrc,dwPriorityCodePages,pdwCodePages,pcchCodePages)
#define IMLangFontLink2_CodePageToCodePages(This,uCodePage,pdwCodePages) (This)->lpVtbl->CodePageToCodePages(This,uCodePage,pdwCodePages)
#define IMLangFontLink2_CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage) (This)->lpVtbl->CodePagesToCodePage(This,dwCodePages,uDefaultCodePage,puCodePage)
#define IMLangFontLink2_GetFontCodePages(This,hDC,hFont,pdwCodePages) (This)->lpVtbl->GetFontCodePages(This,hDC,hFont,pdwCodePages)
#define IMLangFontLink2_ReleaseFont(This,hFont) (This)->lpVtbl->ReleaseFont(This,hFont)
#define IMLangFontLink2_ResetFontMapping(This) (This)->lpVtbl->ResetFontMapping(This)
#define IMLangFontLink2_MapFont(This,hDC,dwCodePages,chSrc,pFont) (This)->lpVtbl->MapFont(This,hDC,dwCodePages,chSrc,pFont)
#define IMLangFontLink2_GetFontUnicodeRanges(This,hDC,puiRanges,pUranges) (This)->lpVtbl->GetFontUnicodeRanges(This,hDC,puiRanges,pUranges)
#define IMLangFontLink2_GetScriptFontInfo(This,sid,dwFlags,puiFonts,pScriptFont) (This)->lpVtbl->GetScriptFontInfo(This,sid,dwFlags,puiFonts,pScriptFont)
#define IMLangFontLink2_CodePageToScriptID(This,uiCodePage,pSid) (This)->lpVtbl->CodePageToScriptID(This,uiCodePage,pSid)
#endif
#endif
  HRESULT WINAPI IMLangFontLink2_GetFontCodePages_Proxy(IMLangFontLink2 *This,HDC hDC,HFONT hFont,DWORD *pdwCodePages);
  void __RPC_STUB IMLangFontLink2_GetFontCodePages_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_ReleaseFont_Proxy(IMLangFontLink2 *This,HFONT hFont);
  void __RPC_STUB IMLangFontLink2_ReleaseFont_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_ResetFontMapping_Proxy(IMLangFontLink2 *This);
  void __RPC_STUB IMLangFontLink2_ResetFontMapping_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_MapFont_Proxy(IMLangFontLink2 *This,HDC hDC,DWORD dwCodePages,WCHAR chSrc,HFONT *pFont);
  void __RPC_STUB IMLangFontLink2_MapFont_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_GetFontUnicodeRanges_Proxy(IMLangFontLink2 *This,HDC hDC,UINT *puiRanges,UNICODERANGE *pUranges);
  void __RPC_STUB IMLangFontLink2_GetFontUnicodeRanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_GetScriptFontInfo_Proxy(IMLangFontLink2 *This,SCRIPT_ID sid,DWORD dwFlags,UINT *puiFonts,SCRIPTFONTINFO *pScriptFont);
  void __RPC_STUB IMLangFontLink2_GetScriptFontInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMLangFontLink2_CodePageToScriptID_Proxy(IMLangFontLink2 *This,UINT uiCodePage,SCRIPT_ID *pSid);
  void __RPC_STUB IMLangFontLink2_CodePageToScriptID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IMultiLanguage3_INTERFACE_DEFINED__
#define __IMultiLanguage3_INTERFACE_DEFINED__
  typedef IMultiLanguage3 *LPMULTILANGUAGE3;

  EXTERN_C const IID IID_IMultiLanguage3;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IMultiLanguage3 : public IMultiLanguage2 {
  public:
    virtual HRESULT WINAPI DetectOutboundCodePage(DWORD dwFlags,LPCWSTR lpWideCharStr,UINT cchWideChar,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar) = 0;
    virtual HRESULT WINAPI DetectOutboundCodePageInIStream(DWORD dwFlags,IStream *pStrIn,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar) = 0;
  };
#else
  typedef struct IMultiLanguage3Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IMultiLanguage3 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IMultiLanguage3 *This);
      ULONG (WINAPI *Release)(IMultiLanguage3 *This);
      HRESULT (WINAPI *GetNumberOfCodePageInfo)(IMultiLanguage3 *This,UINT *pcCodePage);
      HRESULT (WINAPI *GetCodePageInfo)(IMultiLanguage3 *This,UINT uiCodePage,LANGID LangId,PMIMECPINFO pCodePageInfo);
      HRESULT (WINAPI *GetFamilyCodePage)(IMultiLanguage3 *This,UINT uiCodePage,UINT *puiFamilyCodePage);
      HRESULT (WINAPI *EnumCodePages)(IMultiLanguage3 *This,DWORD grfFlags,LANGID LangId,IEnumCodePage **ppEnumCodePage);
      HRESULT (WINAPI *GetCharsetInfo)(IMultiLanguage3 *This,BSTR Charset,PMIMECSETINFO pCharsetInfo);
      HRESULT (WINAPI *IsConvertible)(IMultiLanguage3 *This,DWORD dwSrcEncoding,DWORD dwDstEncoding);
      HRESULT (WINAPI *ConvertString)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,BYTE *pSrcStr,UINT *pcSrcSize,BYTE *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringToUnicode)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringFromUnicode)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize);
      HRESULT (WINAPI *ConvertStringReset)(IMultiLanguage3 *This);
      HRESULT (WINAPI *GetRfc1766FromLcid)(IMultiLanguage3 *This,LCID Locale,BSTR *pbstrRfc1766);
      HRESULT (WINAPI *GetLcidFromRfc1766)(IMultiLanguage3 *This,LCID *pLocale,BSTR bstrRfc1766);
      HRESULT (WINAPI *EnumRfc1766)(IMultiLanguage3 *This,LANGID LangId,IEnumRfc1766 **ppEnumRfc1766);
      HRESULT (WINAPI *GetRfc1766Info)(IMultiLanguage3 *This,LCID Locale,LANGID LangId,PRFC1766INFO pRfc1766Info);
      HRESULT (WINAPI *CreateConvertCharset)(IMultiLanguage3 *This,UINT uiSrcCodePage,UINT uiDstCodePage,DWORD dwProperty,IMLangConvertCharset **ppMLangConvertCharset);
      HRESULT (WINAPI *ConvertStringInIStream)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwFlag,WCHAR *lpFallBack,DWORD dwSrcEncoding,DWORD dwDstEncoding,IStream *pstmIn,IStream *pstmOut);
      HRESULT (WINAPI *ConvertStringToUnicodeEx)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwEncoding,CHAR *pSrcStr,UINT *pcSrcSize,WCHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
      HRESULT (WINAPI *ConvertStringFromUnicodeEx)(IMultiLanguage3 *This,DWORD *pdwMode,DWORD dwEncoding,WCHAR *pSrcStr,UINT *pcSrcSize,CHAR *pDstStr,UINT *pcDstSize,DWORD dwFlag,WCHAR *lpFallBack);
      HRESULT (WINAPI *DetectCodepageInIStream)(IMultiLanguage3 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,IStream *pstmIn,DetectEncodingInfo *lpEncoding,INT *pnScores);
      HRESULT (WINAPI *DetectInputCodepage)(IMultiLanguage3 *This,DWORD dwFlag,DWORD dwPrefWinCodePage,CHAR *pSrcStr,INT *pcSrcSize,DetectEncodingInfo *lpEncoding,INT *pnScores);
      HRESULT (WINAPI *ValidateCodePage)(IMultiLanguage3 *This,UINT uiCodePage,HWND hwnd);
      HRESULT (WINAPI *GetCodePageDescription)(IMultiLanguage3 *This,UINT uiCodePage,LCID lcid,LPWSTR lpWideCharStr,int cchWideChar);
      HRESULT (WINAPI *IsCodePageInstallable)(IMultiLanguage3 *This,UINT uiCodePage);
      HRESULT (WINAPI *SetMimeDBSource)(IMultiLanguage3 *This,MIMECONTF dwSource);
      HRESULT (WINAPI *GetNumberOfScripts)(IMultiLanguage3 *This,UINT *pnScripts);
      HRESULT (WINAPI *EnumScripts)(IMultiLanguage3 *This,DWORD dwFlags,LANGID LangId,IEnumScript **ppEnumScript);
      HRESULT (WINAPI *ValidateCodePageEx)(IMultiLanguage3 *This,UINT uiCodePage,HWND hwnd,DWORD dwfIODControl);
      HRESULT (WINAPI *DetectOutboundCodePage)(IMultiLanguage3 *This,DWORD dwFlags,LPCWSTR lpWideCharStr,UINT cchWideChar,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar);
      HRESULT (WINAPI *DetectOutboundCodePageInIStream)(IMultiLanguage3 *This,DWORD dwFlags,IStream *pStrIn,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar);
    END_INTERFACE
  } IMultiLanguage3Vtbl;
  struct IMultiLanguage3 {
    CONST_VTBL struct IMultiLanguage3Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IMultiLanguage3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IMultiLanguage3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IMultiLanguage3_Release(This) (This)->lpVtbl->Release(This)
#define IMultiLanguage3_GetNumberOfCodePageInfo(This,pcCodePage) (This)->lpVtbl->GetNumberOfCodePageInfo(This,pcCodePage)
#define IMultiLanguage3_GetCodePageInfo(This,uiCodePage,LangId,pCodePageInfo) (This)->lpVtbl->GetCodePageInfo(This,uiCodePage,LangId,pCodePageInfo)
#define IMultiLanguage3_GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage) (This)->lpVtbl->GetFamilyCodePage(This,uiCodePage,puiFamilyCodePage)
#define IMultiLanguage3_EnumCodePages(This,grfFlags,LangId,ppEnumCodePage) (This)->lpVtbl->EnumCodePages(This,grfFlags,LangId,ppEnumCodePage)
#define IMultiLanguage3_GetCharsetInfo(This,Charset,pCharsetInfo) (This)->lpVtbl->GetCharsetInfo(This,Charset,pCharsetInfo)
#define IMultiLanguage3_IsConvertible(This,dwSrcEncoding,dwDstEncoding) (This)->lpVtbl->IsConvertible(This,dwSrcEncoding,dwDstEncoding)
#define IMultiLanguage3_ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertString(This,pdwMode,dwSrcEncoding,dwDstEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage3_ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringToUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage3_ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize) (This)->lpVtbl->ConvertStringFromUnicode(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize)
#define IMultiLanguage3_ConvertStringReset(This) (This)->lpVtbl->ConvertStringReset(This)
#define IMultiLanguage3_GetRfc1766FromLcid(This,Locale,pbstrRfc1766) (This)->lpVtbl->GetRfc1766FromLcid(This,Locale,pbstrRfc1766)
#define IMultiLanguage3_GetLcidFromRfc1766(This,pLocale,bstrRfc1766) (This)->lpVtbl->GetLcidFromRfc1766(This,pLocale,bstrRfc1766)
#define IMultiLanguage3_EnumRfc1766(This,LangId,ppEnumRfc1766) (This)->lpVtbl->EnumRfc1766(This,LangId,ppEnumRfc1766)
#define IMultiLanguage3_GetRfc1766Info(This,Locale,LangId,pRfc1766Info) (This)->lpVtbl->GetRfc1766Info(This,Locale,LangId,pRfc1766Info)
#define IMultiLanguage3_CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset) (This)->lpVtbl->CreateConvertCharset(This,uiSrcCodePage,uiDstCodePage,dwProperty,ppMLangConvertCharset)
#define IMultiLanguage3_ConvertStringInIStream(This,pdwMode,dwFlag,lpFallBack,dwSrcEncoding,dwDstEncoding,pstmIn,pstmOut) (This)->lpVtbl->ConvertStringInIStream(This,pdwMode,dwFlag,lpFallBack,dwSrcEncoding,dwDstEncoding,pstmIn,pstmOut)
#define IMultiLanguage3_ConvertStringToUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack) (This)->lpVtbl->ConvertStringToUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack)
#define IMultiLanguage3_ConvertStringFromUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack) (This)->lpVtbl->ConvertStringFromUnicodeEx(This,pdwMode,dwEncoding,pSrcStr,pcSrcSize,pDstStr,pcDstSize,dwFlag,lpFallBack)
#define IMultiLanguage3_DetectCodepageInIStream(This,dwFlag,dwPrefWinCodePage,pstmIn,lpEncoding,pnScores) (This)->lpVtbl->DetectCodepageInIStream(This,dwFlag,dwPrefWinCodePage,pstmIn,lpEncoding,pnScores)
#define IMultiLanguage3_DetectInputCodepage(This,dwFlag,dwPrefWinCodePage,pSrcStr,pcSrcSize,lpEncoding,pnScores) (This)->lpVtbl->DetectInputCodepage(This,dwFlag,dwPrefWinCodePage,pSrcStr,pcSrcSize,lpEncoding,pnScores)
#define IMultiLanguage3_ValidateCodePage(This,uiCodePage,hwnd) (This)->lpVtbl->ValidateCodePage(This,uiCodePage,hwnd)
#define IMultiLanguage3_GetCodePageDescription(This,uiCodePage,lcid,lpWideCharStr,cchWideChar) (This)->lpVtbl->GetCodePageDescription(This,uiCodePage,lcid,lpWideCharStr,cchWideChar)
#define IMultiLanguage3_IsCodePageInstallable(This,uiCodePage) (This)->lpVtbl->IsCodePageInstallable(This,uiCodePage)
#define IMultiLanguage3_SetMimeDBSource(This,dwSource) (This)->lpVtbl->SetMimeDBSource(This,dwSource)
#define IMultiLanguage3_GetNumberOfScripts(This,pnScripts) (This)->lpVtbl->GetNumberOfScripts(This,pnScripts)
#define IMultiLanguage3_EnumScripts(This,dwFlags,LangId,ppEnumScript) (This)->lpVtbl->EnumScripts(This,dwFlags,LangId,ppEnumScript)
#define IMultiLanguage3_ValidateCodePageEx(This,uiCodePage,hwnd,dwfIODControl) (This)->lpVtbl->ValidateCodePageEx(This,uiCodePage,hwnd,dwfIODControl)
#define IMultiLanguage3_DetectOutboundCodePage(This,dwFlags,lpWideCharStr,cchWideChar,puiPreferredCodePages,nPreferredCodePages,puiDetectedCodePages,pnDetectedCodePages,lpSpecialChar) (This)->lpVtbl->DetectOutboundCodePage(This,dwFlags,lpWideCharStr,cchWideChar,puiPreferredCodePages,nPreferredCodePages,puiDetectedCodePages,pnDetectedCodePages,lpSpecialChar)
#define IMultiLanguage3_DetectOutboundCodePageInIStream(This,dwFlags,pStrIn,puiPreferredCodePages,nPreferredCodePages,puiDetectedCodePages,pnDetectedCodePages,lpSpecialChar) (This)->lpVtbl->DetectOutboundCodePageInIStream(This,dwFlags,pStrIn,puiPreferredCodePages,nPreferredCodePages,puiDetectedCodePages,pnDetectedCodePages,lpSpecialChar)
#endif
#endif
  HRESULT WINAPI IMultiLanguage3_DetectOutboundCodePage_Proxy(IMultiLanguage3 *This,DWORD dwFlags,LPCWSTR lpWideCharStr,UINT cchWideChar,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar);
  void __RPC_STUB IMultiLanguage3_DetectOutboundCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IMultiLanguage3_DetectOutboundCodePageInIStream_Proxy(IMultiLanguage3 *This,DWORD dwFlags,IStream *pStrIn,UINT *puiPreferredCodePages,UINT nPreferredCodePages,UINT *puiDetectedCodePages,UINT *pnDetectedCodePages,WCHAR *lpSpecialChar);
  void __RPC_STUB IMultiLanguage3_DetectOutboundCodePageInIStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_CMultiLanguage;
#ifdef __cplusplus
  class CMultiLanguage;
#endif
#endif

#ifndef _MLANG_H_API_DEF_
#define _MLANG_H_API_DEF_
  STDAPI LcidToRfc1766A(LCID Locale,LPSTR pszRfc1766,int iMaxLength);
  STDAPI LcidToRfc1766W(LCID Locale,LPWSTR pszRfc1766,int nChar);

#define LcidToRfc1766 __MINGW_NAME_AW(LcidToRfc1766)

  STDAPI Rfc1766ToLcidA(LCID *pLocale,LPCSTR pszRfc1766);
  STDAPI Rfc1766ToLcidW(LCID *pLocale,LPCWSTR pszRfc1766);

#define Rfc1766ToLcid __MINGW_NAME_AW(Rfc1766ToLcid)

  STDAPI IsConvertINetStringAvailable(DWORD dwSrcEncoding,DWORD dwDstEncoding);
  STDAPI ConvertINetString(LPDWORD lpdwMode,DWORD dwSrcEncoding,DWORD dwDstEncoding,LPCSTR lpSrcStr,LPINT lpnSrcSize,LPSTR lpDstStr,LPINT lpnDstSize);
  STDAPI ConvertINetMultiByteToUnicode(LPDWORD lpdwMode,DWORD dwEncoding,LPCSTR lpSrcStr,LPINT lpnMultiCharCount,LPWSTR lpDstStr,LPINT lpnWideCharCount);
  STDAPI ConvertINetUnicodeToMultiByte(LPDWORD lpdwMode,DWORD dwEncoding,LPCWSTR lpSrcStr,LPINT lpnWideCharCount,LPSTR lpDstStr,LPINT lpnMultiCharCount);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mlang_0131_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mlang_0131_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
