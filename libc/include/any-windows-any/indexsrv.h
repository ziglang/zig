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

#ifndef __indexsrv_h__
#define __indexsrv_h__

#ifndef __IPhraseSink_FWD_DEFINED__
#define __IPhraseSink_FWD_DEFINED__
typedef struct IPhraseSink IPhraseSink;
#endif

#ifndef __IWordSink_FWD_DEFINED__
#define __IWordSink_FWD_DEFINED__
typedef struct IWordSink IWordSink;
#endif

#ifndef __IWordBreaker_FWD_DEFINED__
#define __IWordBreaker_FWD_DEFINED__
typedef struct IWordBreaker IWordBreaker;
#endif

#ifndef __IWordFormSink_FWD_DEFINED__
#define __IWordFormSink_FWD_DEFINED__
typedef struct IWordFormSink IWordFormSink;
#endif

#ifndef __IStemmer_FWD_DEFINED__
#define __IStemmer_FWD_DEFINED__
typedef struct IStemmer IStemmer;
#endif

#ifndef __ISimpleCommandCreator_FWD_DEFINED__
#define __ISimpleCommandCreator_FWD_DEFINED__
typedef struct ISimpleCommandCreator ISimpleCommandCreator;
#endif

#ifndef __IColumnMapper_FWD_DEFINED__
#define __IColumnMapper_FWD_DEFINED__
typedef struct IColumnMapper IColumnMapper;
#endif

#ifndef __IColumnMapperCreator_FWD_DEFINED__
#define __IColumnMapperCreator_FWD_DEFINED__
typedef struct IColumnMapperCreator IColumnMapperCreator;
#endif

#include "oaidl.h"
#include "filter.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IPhraseSink_INTERFACE_DEFINED__
#define __IPhraseSink_INTERFACE_DEFINED__

  EXTERN_C const IID IID_IPhraseSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IPhraseSink : public IUnknown {
  public:
    virtual HRESULT WINAPI PutSmallPhrase(const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType) = 0;
    virtual HRESULT WINAPI PutPhrase(const WCHAR *pwcPhrase,ULONG cwcPhrase) = 0;
  };
#else
  typedef struct IPhraseSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IPhraseSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IPhraseSink *This);
      ULONG (WINAPI *Release)(IPhraseSink *This);
      HRESULT (WINAPI *PutSmallPhrase)(IPhraseSink *This,const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType);
      HRESULT (WINAPI *PutPhrase)(IPhraseSink *This,const WCHAR *pwcPhrase,ULONG cwcPhrase);
    END_INTERFACE
  } IPhraseSinkVtbl;
  struct IPhraseSink {
    CONST_VTBL struct IPhraseSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IPhraseSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IPhraseSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IPhraseSink_Release(This) (This)->lpVtbl->Release(This)
#define IPhraseSink_PutSmallPhrase(This,pwcNoun,cwcNoun,pwcModifier,cwcModifier,ulAttachmentType) (This)->lpVtbl->PutSmallPhrase(This,pwcNoun,cwcNoun,pwcModifier,cwcModifier,ulAttachmentType)
#define IPhraseSink_PutPhrase(This,pwcPhrase,cwcPhrase) (This)->lpVtbl->PutPhrase(This,pwcPhrase,cwcPhrase)
#endif
#endif
  HRESULT WINAPI IPhraseSink_PutSmallPhrase_Proxy(IPhraseSink *This,const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType);
  void __RPC_STUB IPhraseSink_PutSmallPhrase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IPhraseSink_PutPhrase_Proxy(IPhraseSink *This,const WCHAR *pwcPhrase,ULONG cwcPhrase);
  void __RPC_STUB IPhraseSink_PutPhrase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWordSink_INTERFACE_DEFINED__
#define __IWordSink_INTERFACE_DEFINED__
#ifndef _tagWORDREP_BREAK_TYPE_DEFINED
#define _tagWORDREP_BREAK_TYPE_DEFINED
  typedef enum tagWORDREP_BREAK_TYPE {
    WORDREP_BREAK_EOW = 0,WORDREP_BREAK_EOS = 1,WORDREP_BREAK_EOP = 2,WORDREP_BREAK_EOC = 3
  } WORDREP_BREAK_TYPE;
#define _WORDREP_BREAK_TYPE_DEFINED
#endif

  EXTERN_C const IID IID_IWordSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWordSink : public IUnknown {
  public:
    virtual HRESULT WINAPI PutWord(ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos) = 0;
    virtual HRESULT WINAPI PutAltWord(ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos) = 0;
    virtual HRESULT WINAPI StartAltPhrase(void) = 0;
    virtual HRESULT WINAPI EndAltPhrase(void) = 0;
    virtual HRESULT WINAPI PutBreak(WORDREP_BREAK_TYPE breakType) = 0;
  };
#else
  typedef struct IWordSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWordSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWordSink *This);
      ULONG (WINAPI *Release)(IWordSink *This);
      HRESULT (WINAPI *PutWord)(IWordSink *This,ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos);
      HRESULT (WINAPI *PutAltWord)(IWordSink *This,ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos);
      HRESULT (WINAPI *StartAltPhrase)(IWordSink *This);
      HRESULT (WINAPI *EndAltPhrase)(IWordSink *This);
      HRESULT (WINAPI *PutBreak)(IWordSink *This,WORDREP_BREAK_TYPE breakType);
    END_INTERFACE
  } IWordSinkVtbl;
  struct IWordSink {
    CONST_VTBL struct IWordSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWordSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWordSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWordSink_Release(This) (This)->lpVtbl->Release(This)
#define IWordSink_PutWord(This,cwc,pwcInBuf,cwcSrcLen,cwcSrcPos) (This)->lpVtbl->PutWord(This,cwc,pwcInBuf,cwcSrcLen,cwcSrcPos)
#define IWordSink_PutAltWord(This,cwc,pwcInBuf,cwcSrcLen,cwcSrcPos) (This)->lpVtbl->PutAltWord(This,cwc,pwcInBuf,cwcSrcLen,cwcSrcPos)
#define IWordSink_StartAltPhrase(This) (This)->lpVtbl->StartAltPhrase(This)
#define IWordSink_EndAltPhrase(This) (This)->lpVtbl->EndAltPhrase(This)
#define IWordSink_PutBreak(This,breakType) (This)->lpVtbl->PutBreak(This,breakType)
#endif
#endif
  HRESULT WINAPI IWordSink_PutWord_Proxy(IWordSink *This,ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos);
  void __RPC_STUB IWordSink_PutWord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordSink_PutAltWord_Proxy(IWordSink *This,ULONG cwc,const WCHAR *pwcInBuf,ULONG cwcSrcLen,ULONG cwcSrcPos);
  void __RPC_STUB IWordSink_PutAltWord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordSink_StartAltPhrase_Proxy(IWordSink *This);
  void __RPC_STUB IWordSink_StartAltPhrase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordSink_EndAltPhrase_Proxy(IWordSink *This);
  void __RPC_STUB IWordSink_EndAltPhrase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordSink_PutBreak_Proxy(IWordSink *This,WORDREP_BREAK_TYPE breakType);
  void __RPC_STUB IWordSink_PutBreak_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef _tagTEXT_SOURCE_DEFINED
#define _tagTEXT_SOURCE_DEFINED
  typedef HRESULT (WINAPI *PFNFILLTEXTBUFFER)(struct tagTEXT_SOURCE *pTextSource);
  typedef struct tagTEXT_SOURCE {
    PFNFILLTEXTBUFFER pfnFillTextBuffer;
    const WCHAR *awcBuffer;
    ULONG iEnd;
    ULONG iCur;
  } TEXT_SOURCE;
#define _TEXT_SOURCE_DEFINED
#endif

  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0127_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0127_v0_0_s_ifspec;

#ifndef __IWordBreaker_INTERFACE_DEFINED__
#define __IWordBreaker_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWordBreaker;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWordBreaker : public IUnknown {
  public:
    virtual HRESULT WINAPI Init(WINBOOL fQuery,ULONG ulMaxTokenSize,WINBOOL *pfLicense) = 0;
    virtual HRESULT WINAPI BreakText(TEXT_SOURCE *pTextSource,IWordSink *pWordSink,IPhraseSink *pPhraseSink) = 0;
    virtual HRESULT WINAPI ComposePhrase(const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType,WCHAR *pwcPhrase,ULONG *pcwcPhrase) = 0;
    virtual HRESULT WINAPI GetLicenseToUse(const WCHAR **ppwcsLicense) = 0;
  };
#else
  typedef struct IWordBreakerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWordBreaker *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWordBreaker *This);
      ULONG (WINAPI *Release)(IWordBreaker *This);
      HRESULT (WINAPI *Init)(IWordBreaker *This,WINBOOL fQuery,ULONG ulMaxTokenSize,WINBOOL *pfLicense);
      HRESULT (WINAPI *BreakText)(IWordBreaker *This,TEXT_SOURCE *pTextSource,IWordSink *pWordSink,IPhraseSink *pPhraseSink);
      HRESULT (WINAPI *ComposePhrase)(IWordBreaker *This,const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType,WCHAR *pwcPhrase,ULONG *pcwcPhrase);
      HRESULT (WINAPI *GetLicenseToUse)(IWordBreaker *This,const WCHAR **ppwcsLicense);
    END_INTERFACE
  } IWordBreakerVtbl;
  struct IWordBreaker {
    CONST_VTBL struct IWordBreakerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWordBreaker_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWordBreaker_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWordBreaker_Release(This) (This)->lpVtbl->Release(This)
#define IWordBreaker_Init(This,fQuery,ulMaxTokenSize,pfLicense) (This)->lpVtbl->Init(This,fQuery,ulMaxTokenSize,pfLicense)
#define IWordBreaker_BreakText(This,pTextSource,pWordSink,pPhraseSink) (This)->lpVtbl->BreakText(This,pTextSource,pWordSink,pPhraseSink)
#define IWordBreaker_ComposePhrase(This,pwcNoun,cwcNoun,pwcModifier,cwcModifier,ulAttachmentType,pwcPhrase,pcwcPhrase) (This)->lpVtbl->ComposePhrase(This,pwcNoun,cwcNoun,pwcModifier,cwcModifier,ulAttachmentType,pwcPhrase,pcwcPhrase)
#define IWordBreaker_GetLicenseToUse(This,ppwcsLicense) (This)->lpVtbl->GetLicenseToUse(This,ppwcsLicense)
#endif
#endif
  HRESULT WINAPI IWordBreaker_Init_Proxy(IWordBreaker *This,WINBOOL fQuery,ULONG ulMaxTokenSize,WINBOOL *pfLicense);
  void __RPC_STUB IWordBreaker_Init_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordBreaker_BreakText_Proxy(IWordBreaker *This,TEXT_SOURCE *pTextSource,IWordSink *pWordSink,IPhraseSink *pPhraseSink);
  void __RPC_STUB IWordBreaker_BreakText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordBreaker_ComposePhrase_Proxy(IWordBreaker *This,const WCHAR *pwcNoun,ULONG cwcNoun,const WCHAR *pwcModifier,ULONG cwcModifier,ULONG ulAttachmentType,WCHAR *pwcPhrase,ULONG *pcwcPhrase);
  void __RPC_STUB IWordBreaker_ComposePhrase_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordBreaker_GetLicenseToUse_Proxy(IWordBreaker *This,const WCHAR **ppwcsLicense);
  void __RPC_STUB IWordBreaker_GetLicenseToUse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWordFormSink_INTERFACE_DEFINED__
#define __IWordFormSink_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IWordFormSink;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWordFormSink : public IUnknown {
  public:
    virtual HRESULT WINAPI PutAltWord(const WCHAR *pwcInBuf,ULONG cwc) = 0;
    virtual HRESULT WINAPI PutWord(const WCHAR *pwcInBuf,ULONG cwc) = 0;
  };
#else
  typedef struct IWordFormSinkVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWordFormSink *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWordFormSink *This);
      ULONG (WINAPI *Release)(IWordFormSink *This);
      HRESULT (WINAPI *PutAltWord)(IWordFormSink *This,const WCHAR *pwcInBuf,ULONG cwc);
      HRESULT (WINAPI *PutWord)(IWordFormSink *This,const WCHAR *pwcInBuf,ULONG cwc);
    END_INTERFACE
  } IWordFormSinkVtbl;
  struct IWordFormSink {
    CONST_VTBL struct IWordFormSinkVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWordFormSink_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWordFormSink_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWordFormSink_Release(This) (This)->lpVtbl->Release(This)
#define IWordFormSink_PutAltWord(This,pwcInBuf,cwc) (This)->lpVtbl->PutAltWord(This,pwcInBuf,cwc)
#define IWordFormSink_PutWord(This,pwcInBuf,cwc) (This)->lpVtbl->PutWord(This,pwcInBuf,cwc)
#endif
#endif
  HRESULT WINAPI IWordFormSink_PutAltWord_Proxy(IWordFormSink *This,const WCHAR *pwcInBuf,ULONG cwc);
  void __RPC_STUB IWordFormSink_PutAltWord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWordFormSink_PutWord_Proxy(IWordFormSink *This,const WCHAR *pwcInBuf,ULONG cwc);
  void __RPC_STUB IWordFormSink_PutWord_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IStemmer_INTERFACE_DEFINED__
#define __IStemmer_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IStemmer;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IStemmer : public IUnknown {
  public:
    virtual HRESULT WINAPI Init(ULONG ulMaxTokenSize,WINBOOL *pfLicense) = 0;
    virtual HRESULT WINAPI GenerateWordForms(const WCHAR *pwcInBuf,ULONG cwc,IWordFormSink *pStemSink) = 0;
    virtual HRESULT WINAPI GetLicenseToUse(const WCHAR **ppwcsLicense) = 0;
  };
#else
  typedef struct IStemmerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IStemmer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IStemmer *This);
      ULONG (WINAPI *Release)(IStemmer *This);
      HRESULT (WINAPI *Init)(IStemmer *This,ULONG ulMaxTokenSize,WINBOOL *pfLicense);
      HRESULT (WINAPI *GenerateWordForms)(IStemmer *This,const WCHAR *pwcInBuf,ULONG cwc,IWordFormSink *pStemSink);
      HRESULT (WINAPI *GetLicenseToUse)(IStemmer *This,const WCHAR **ppwcsLicense);
    END_INTERFACE
  } IStemmerVtbl;
  struct IStemmer {
    CONST_VTBL struct IStemmerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IStemmer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IStemmer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IStemmer_Release(This) (This)->lpVtbl->Release(This)
#define IStemmer_Init(This,ulMaxTokenSize,pfLicense) (This)->lpVtbl->Init(This,ulMaxTokenSize,pfLicense)
#define IStemmer_GenerateWordForms(This,pwcInBuf,cwc,pStemSink) (This)->lpVtbl->GenerateWordForms(This,pwcInBuf,cwc,pStemSink)
#define IStemmer_GetLicenseToUse(This,ppwcsLicense) (This)->lpVtbl->GetLicenseToUse(This,ppwcsLicense)
#endif
#endif
  HRESULT WINAPI IStemmer_Init_Proxy(IStemmer *This,ULONG ulMaxTokenSize,WINBOOL *pfLicense);
  void __RPC_STUB IStemmer_Init_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStemmer_GenerateWordForms_Proxy(IStemmer *This,const WCHAR *pwcInBuf,ULONG cwc,IWordFormSink *pStemSink);
  void __RPC_STUB IStemmer_GenerateWordForms_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStemmer_GetLicenseToUse_Proxy(IStemmer *This,const WCHAR **ppwcsLicense);
  void __RPC_STUB IStemmer_GetLicenseToUse_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0130_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0130_v0_0_s_ifspec;

#ifndef __ISimpleCommandCreator_INTERFACE_DEFINED__
#define __ISimpleCommandCreator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ISimpleCommandCreator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISimpleCommandCreator : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateICommand(IUnknown **ppIUnknown,IUnknown *pOuterUnk) = 0;
    virtual HRESULT WINAPI VerifyCatalog(const WCHAR *pwszMachine,const WCHAR *pwszCatalogName) = 0;
    virtual HRESULT WINAPI GetDefaultCatalog(WCHAR *pwszCatalogName,ULONG cwcIn,ULONG *pcwcOut) = 0;
  };
#else
  typedef struct ISimpleCommandCreatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISimpleCommandCreator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISimpleCommandCreator *This);
      ULONG (WINAPI *Release)(ISimpleCommandCreator *This);
      HRESULT (WINAPI *CreateICommand)(ISimpleCommandCreator *This,IUnknown **ppIUnknown,IUnknown *pOuterUnk);
      HRESULT (WINAPI *VerifyCatalog)(ISimpleCommandCreator *This,const WCHAR *pwszMachine,const WCHAR *pwszCatalogName);
      HRESULT (WINAPI *GetDefaultCatalog)(ISimpleCommandCreator *This,WCHAR *pwszCatalogName,ULONG cwcIn,ULONG *pcwcOut);
    END_INTERFACE
  } ISimpleCommandCreatorVtbl;
  struct ISimpleCommandCreator {
    CONST_VTBL struct ISimpleCommandCreatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISimpleCommandCreator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISimpleCommandCreator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISimpleCommandCreator_Release(This) (This)->lpVtbl->Release(This)
#define ISimpleCommandCreator_CreateICommand(This,ppIUnknown,pOuterUnk) (This)->lpVtbl->CreateICommand(This,ppIUnknown,pOuterUnk)
#define ISimpleCommandCreator_VerifyCatalog(This,pwszMachine,pwszCatalogName) (This)->lpVtbl->VerifyCatalog(This,pwszMachine,pwszCatalogName)
#define ISimpleCommandCreator_GetDefaultCatalog(This,pwszCatalogName,cwcIn,pcwcOut) (This)->lpVtbl->GetDefaultCatalog(This,pwszCatalogName,cwcIn,pcwcOut)
#endif
#endif
  HRESULT WINAPI ISimpleCommandCreator_CreateICommand_Proxy(ISimpleCommandCreator *This,IUnknown **ppIUnknown,IUnknown *pOuterUnk);
  void __RPC_STUB ISimpleCommandCreator_CreateICommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISimpleCommandCreator_VerifyCatalog_Proxy(ISimpleCommandCreator *This,const WCHAR *pwszMachine,const WCHAR *pwszCatalogName);
  void __RPC_STUB ISimpleCommandCreator_VerifyCatalog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISimpleCommandCreator_GetDefaultCatalog_Proxy(ISimpleCommandCreator *This,WCHAR *pwszCatalogName,ULONG cwcIn,ULONG *pcwcOut);
  void __RPC_STUB ISimpleCommandCreator_GetDefaultCatalog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define CLSID_CISimpleCommandCreator {0xc7b6c04a,0xcbb5,0x11d0,{0xbb,0x4c,0x0,0xc0,0x4f,0xc2,0xf4,0x10 } }
  typedef struct tagDBID DBID;
  typedef WORD DBTYPE;

  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0131_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0131_v0_0_s_ifspec;

#ifndef __IColumnMapper_INTERFACE_DEFINED__
#define __IColumnMapper_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IColumnMapper;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IColumnMapper : public IUnknown {
  public:
    virtual HRESULT WINAPI GetPropInfoFromName(const WCHAR *wcsPropName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth) = 0;
    virtual HRESULT WINAPI GetPropInfoFromId(const DBID *pPropId,WCHAR **pwcsName,DBTYPE *pPropType,unsigned int *puiWidth) = 0;
    virtual HRESULT WINAPI EnumPropInfo(ULONG iEntry,const WCHAR **pwcsName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth) = 0;
    virtual HRESULT WINAPI IsMapUpToDate(void) = 0;
  };
#else
  typedef struct IColumnMapperVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IColumnMapper *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IColumnMapper *This);
      ULONG (WINAPI *Release)(IColumnMapper *This);
      HRESULT (WINAPI *GetPropInfoFromName)(IColumnMapper *This,const WCHAR *wcsPropName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth);
      HRESULT (WINAPI *GetPropInfoFromId)(IColumnMapper *This,const DBID *pPropId,WCHAR **pwcsName,DBTYPE *pPropType,unsigned int *puiWidth);
      HRESULT (WINAPI *EnumPropInfo)(IColumnMapper *This,ULONG iEntry,const WCHAR **pwcsName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth);
      HRESULT (WINAPI *IsMapUpToDate)(IColumnMapper *This);
    END_INTERFACE
  } IColumnMapperVtbl;
  struct IColumnMapper {
    CONST_VTBL struct IColumnMapperVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IColumnMapper_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IColumnMapper_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IColumnMapper_Release(This) (This)->lpVtbl->Release(This)
#define IColumnMapper_GetPropInfoFromName(This,wcsPropName,ppPropId,pPropType,puiWidth) (This)->lpVtbl->GetPropInfoFromName(This,wcsPropName,ppPropId,pPropType,puiWidth)
#define IColumnMapper_GetPropInfoFromId(This,pPropId,pwcsName,pPropType,puiWidth) (This)->lpVtbl->GetPropInfoFromId(This,pPropId,pwcsName,pPropType,puiWidth)
#define IColumnMapper_EnumPropInfo(This,iEntry,pwcsName,ppPropId,pPropType,puiWidth) (This)->lpVtbl->EnumPropInfo(This,iEntry,pwcsName,ppPropId,pPropType,puiWidth)
#define IColumnMapper_IsMapUpToDate(This) (This)->lpVtbl->IsMapUpToDate(This)
#endif
#endif
  HRESULT WINAPI IColumnMapper_GetPropInfoFromName_Proxy(IColumnMapper *This,const WCHAR *wcsPropName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth);
  void __RPC_STUB IColumnMapper_GetPropInfoFromName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IColumnMapper_GetPropInfoFromId_Proxy(IColumnMapper *This,const DBID *pPropId,WCHAR **pwcsName,DBTYPE *pPropType,unsigned int *puiWidth);
  void __RPC_STUB IColumnMapper_GetPropInfoFromId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IColumnMapper_EnumPropInfo_Proxy(IColumnMapper *This,ULONG iEntry,const WCHAR **pwcsName,DBID **ppPropId,DBTYPE *pPropType,unsigned int *puiWidth);
  void __RPC_STUB IColumnMapper_EnumPropInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IColumnMapper_IsMapUpToDate_Proxy(IColumnMapper *This);
  void __RPC_STUB IColumnMapper_IsMapUpToDate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define LOCAL_MACHINE (L".")
#define SYSTEM_DEFAULT_CAT (L"__SystemDefault__")
#define INDEX_SERVER_DEFAULT_CAT (L"__IndexServerDefault__")

  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0132_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_indexsrv_0132_v0_0_s_ifspec;

#ifndef __IColumnMapperCreator_INTERFACE_DEFINED__
#define __IColumnMapperCreator_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IColumnMapperCreator;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IColumnMapperCreator : public IUnknown {
  public:
    virtual HRESULT WINAPI GetColumnMapper(const WCHAR *wcsMachineName,const WCHAR *wcsCatalogName,IColumnMapper **ppColumnMapper) = 0;
  };
#else
  typedef struct IColumnMapperCreatorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IColumnMapperCreator *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IColumnMapperCreator *This);
      ULONG (WINAPI *Release)(IColumnMapperCreator *This);
      HRESULT (WINAPI *GetColumnMapper)(IColumnMapperCreator *This,const WCHAR *wcsMachineName,const WCHAR *wcsCatalogName,IColumnMapper **ppColumnMapper);
    END_INTERFACE
  } IColumnMapperCreatorVtbl;
  struct IColumnMapperCreator {
    CONST_VTBL struct IColumnMapperCreatorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IColumnMapperCreator_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IColumnMapperCreator_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IColumnMapperCreator_Release(This) (This)->lpVtbl->Release(This)
#define IColumnMapperCreator_GetColumnMapper(This,wcsMachineName,wcsCatalogName,ppColumnMapper) (This)->lpVtbl->GetColumnMapper(This,wcsMachineName,wcsCatalogName,ppColumnMapper)
#endif
#endif
  HRESULT WINAPI IColumnMapperCreator_GetColumnMapper_Proxy(IColumnMapperCreator *This,const WCHAR *wcsMachineName,const WCHAR *wcsCatalogName,IColumnMapper **ppColumnMapper);
  void __RPC_STUB IColumnMapperCreator_GetColumnMapper_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
