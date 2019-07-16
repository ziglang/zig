/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MSPUTILS_H_
#define __MSPUTILS_H_

#if _ATL_VER >= 0x0300
#define DECLARE_VQI()
#else
#define DECLARE_VQI() STDMETHOD(QueryInterface)(REFIID iid,void **ppvObject) = 0; STDMETHOD_(ULONG,AddRef)() = 0; STDMETHOD_(ULONG,Release)() = 0;
#endif

#define MSP_(hr) (FAILED(hr)?MSP_ERROR:MSP_TRACE)

extern __inline WINBOOL IsValidAggregatedMediaType(DWORD dwAggregatedMediaType) {
  const DWORD dwAllPossibleMediaTypes = TAPIMEDIATYPE_AUDIO | TAPIMEDIATYPE_VIDEO | TAPIMEDIATYPE_DATAMODEM | TAPIMEDIATYPE_G3FAX | TAPIMEDIATYPE_MULTITRACK;
  WINBOOL bValidMediaType = FALSE;
  if((0==(dwAggregatedMediaType & dwAllPossibleMediaTypes)) || (0!=(dwAggregatedMediaType & (~dwAllPossibleMediaTypes)))) {
    bValidMediaType = FALSE;
  } else {
    bValidMediaType = TRUE;
  }
  return bValidMediaType;
}

extern __inline WINBOOL IsSingleMediaType(DWORD dwMediaType) { return !((dwMediaType==0) || ((dwMediaType & (dwMediaType - 1))!=0)); }
extern __inline WINBOOL IsValidSingleMediaType(DWORD dwMediaType,DWORD dwMask) { return IsSingleMediaType(dwMediaType) && ((dwMediaType & dwMask)==dwMediaType); }

const DWORD INITIAL = 8;
const DWORD DELTA = 8;

template <class T,DWORD dwInitial = INITIAL,DWORD dwDelta = DELTA> class CMSPArray {
protected:
  T *m_aT;
  int m_nSize;
  int m_nAllocSize;
public:
  CMSPArray() : m_aT(NULL),m_nSize(0),m_nAllocSize(0) { }
  ~CMSPArray() { RemoveAll(); }
  int GetSize() const { return m_nSize; }
  WINBOOL Grow() {
    T *aT;
    int nNewAllocSize = (m_nAllocSize==0) ? dwInitial : (m_nSize + DELTA);
    aT = (T *)realloc(m_aT,nNewAllocSize *sizeof(T));
    if(!aT) return FALSE;
    m_nAllocSize = nNewAllocSize;
    m_aT = aT;
    return TRUE;
  }
  WINBOOL Add(T &t) {
    if(m_nSize==m_nAllocSize) {
      if(!Grow()) return FALSE;
    }
    m_nSize++;
    SetAtIndex(m_nSize - 1,t);
    return TRUE;
  }
  WINBOOL Remove(T &t) {
    int nIndex = Find(t);
    if(nIndex==-1) return FALSE;
    return RemoveAt(nIndex);
  }
  WINBOOL RemoveAt(int nIndex) {
    if(nIndex!=(m_nSize - 1))
      memmove((void*)&m_aT[nIndex],(void*)&m_aT[nIndex + 1],(m_nSize - (nIndex + 1))*sizeof(T));
    m_nSize--;
    return TRUE;
  }
  void RemoveAll() {
    if(m_nAllocSize > 0) {
      free(m_aT);
      m_aT = NULL;
      m_nSize = 0;
      m_nAllocSize = 0;
    }
  }
  T &operator[] (int nIndex) const {
    _ASSERTE(nIndex >= 0 && nIndex < m_nSize);
    return m_aT[nIndex];
  }
  T *GetData() const { return m_aT; }
  void SetAtIndex(int nIndex,T &t) {
    _ASSERTE(nIndex >= 0 && nIndex < m_nSize);
    m_aT[nIndex] = t;
  }
  int Find(T &t) const {
    for(int i = 0;i < m_nSize;i++) {
      if(m_aT[i]==t) return i;
    }
    return -1;
  }
};

class CMSPCritSection {
private:
  CRITICAL_SECTION m_CritSec;
public:
  CMSPCritSection() { InitializeCriticalSection(&m_CritSec); }
  ~CMSPCritSection() { DeleteCriticalSection(&m_CritSec); }
  void Lock() { EnterCriticalSection(&m_CritSec); }
  WINBOOL TryLock() { return TryEnterCriticalSection(&m_CritSec); }
  void Unlock() { LeaveCriticalSection(&m_CritSec); }
};

class CLock {
private:
  CMSPCritSection &m_CriticalSection;
public:
  CLock(CMSPCritSection &CriticalSection) : m_CriticalSection(CriticalSection) {
    m_CriticalSection.Lock();
  }
  ~CLock() { m_CriticalSection.Unlock(); }
};

class CCSLock {
private:
  CRITICAL_SECTION *m_pCritSec;
public:
  CCSLock(CRITICAL_SECTION *pCritSec) : m_pCritSec(pCritSec) {
    EnterCriticalSection(m_pCritSec);
  }
  ~CCSLock() { LeaveCriticalSection(m_pCritSec); }
};

#ifndef CONTAINING_RECORD
#define CONTAINING_RECORD(address,type,field) ((type *)((PCHAR)(address) - (ULONG_PTR)(&((type *)0)->field)))
#endif

#ifndef InitializeListHead
#define InitializeListHead(ListHead) ((ListHead)->Flink = (ListHead)->Blink = (ListHead))
#define IsListEmpty(ListHead) ((ListHead)->Flink==(ListHead))
#define RemoveHeadList(ListHead) (ListHead)->Flink; {RemoveEntryList((ListHead)->Flink)}
#define RemoveTailList(ListHead) (ListHead)->Blink; {RemoveEntryList((ListHead)->Blink)}
#define RemoveEntryList(Entry) { PLIST_ENTRY _EX_Blink; PLIST_ENTRY _EX_Flink; _EX_Flink = (Entry)->Flink; _EX_Blink = (Entry)->Blink; _EX_Blink->Flink = _EX_Flink; _EX_Flink->Blink = _EX_Blink; }
#define InsertTailList(ListHead,Entry) { PLIST_ENTRY _EX_Blink; PLIST_ENTRY _EX_ListHead; _EX_ListHead = (ListHead); _EX_Blink = _EX_ListHead->Blink; (Entry)->Flink = _EX_ListHead; (Entry)->Blink = _EX_Blink; _EX_Blink->Flink = (Entry); _EX_ListHead->Blink = (Entry); }
#define InsertHeadList(ListHead,Entry) { PLIST_ENTRY _EX_Flink; PLIST_ENTRY _EX_ListHead; _EX_ListHead = (ListHead); _EX_Flink = _EX_ListHead->Flink; (Entry)->Flink = _EX_Flink; (Entry)->Blink = _EX_ListHead; _EX_Flink->Blink = (Entry); _EX_ListHead->Flink = (Entry); }

WINBOOL IsNodeOnList(PLIST_ENTRY ListHead,PLIST_ENTRY Entry);
#endif

template <class T> ULONG MSPAddRefHelper (T *pMyThis) {
  LOG((MSP_INFO,"MSPAddRefHelper - this = 0x%08x",pMyThis));
  typedef CComAggObject<T> AggClass;
  AggClass *p = CONTAINING_RECORD(pMyThis,AggClass,m_contained);
  return p->AddRef();
}

template <class T> ULONG MSPReleaseHelper (T *pMyThis) {
  LOG((MSP_INFO,"MSPReleaseHelper - this = 0x%08x",pMyThis));
  typedef CComAggObject<T> AggClass;
  AggClass *p = CONTAINING_RECORD(pMyThis,AggClass,m_contained);
  return p->Release();
}

#include <objsafe.h>

class CMSPObjectSafetyImpl : public IObjectSafety {
public:
  CMSPObjectSafetyImpl() : m_dwSafety(0) { }
  enum {
    SUPPORTED_SAFETY_OPTIONS = INTERFACESAFE_FOR_UNTRUSTED_CALLER | INTERFACESAFE_FOR_UNTRUSTED_DATA
  };
  STDMETHOD(SetInterfaceSafetyOptions)(REFIID riid,DWORD dwOptionSetMask,DWORD dwEnabledOptions) {
    if((~SUPPORTED_SAFETY_OPTIONS & dwOptionSetMask)!=0) return E_FAIL;
    IUnknown *pUnk = NULL;
    HRESULT hr = QueryInterface(riid,(void**)&pUnk);
    if(SUCCEEDED(hr)) {
      pUnk->Release();
      pUnk = NULL;
      s_CritSection.Lock();
      m_dwSafety = (dwEnabledOptions & dwOptionSetMask) | (m_dwSafety & ~dwOptionSetMask);
      s_CritSection.Unlock();
    }
    return hr;
  }
  STDMETHOD(GetInterfaceSafetyOptions)(REFIID riid,DWORD *pdwSupportedOptions,DWORD *pdwEnabledOptions) {
    if(IsBadWritePtr(pdwSupportedOptions,sizeof(DWORD)) || IsBadWritePtr(pdwEnabledOptions,sizeof(DWORD))) return E_POINTER;
    *pdwSupportedOptions = 0;
    *pdwEnabledOptions = 0;
    IUnknown *pUnk = NULL;
    HRESULT hr = QueryInterface(riid,(void**)&pUnk);
    if(SUCCEEDED(hr)) {
      pUnk->Release();
      pUnk = NULL;
      *pdwSupportedOptions = SUPPORTED_SAFETY_OPTIONS;
      s_CritSection.Lock();
      *pdwEnabledOptions = m_dwSafety;
      s_CritSection.Unlock();
    }
    return hr;
  }
private:
  DWORD m_dwSafety;
  static CMSPCritSection s_CritSection;
};

#endif
