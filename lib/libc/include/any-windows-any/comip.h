/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_COMIP
#define _INC_COMIP

#include <_mingw.h>

#include <ole2.h>
#include <malloc.h>

#include <comutil.h>

#ifdef __cplusplus

#pragma push_macro("new")
#undef new

#include <new.h>

class _com_error;

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

void WINAPI _com_issue_error(HRESULT);
struct IUnknown;

template<typename _Interface,const IID *_IID >
class _com_IIID {
public:
  typedef _Interface Interface;
  static _Interface *GetInterfacePtr() throw() { return NULL; }
  static _Interface& GetInterface() throw() { return *GetInterfacePtr(); }
  static const IID& GetIID() throw() { return *_IID; }
};

/* This is needed for _COM_SMARTPTR_TYPEDEF using emulated __uuidof. Since we can't pass
 * IID as a template argument, it's passed as a wrapper function. */
template<typename _Interface,const IID &(*iid_getter)() >
class _com_IIID_getter {
public:
  typedef _Interface Interface;
  static _Interface *GetInterfacePtr() throw() { return NULL; }
  static _Interface& GetInterface() throw() { return *GetInterfacePtr(); }
  static const IID& GetIID() throw() { return iid_getter(); }
};

template<typename _IIID> class _com_ptr_t {
public:
  typedef _IIID ThisIIID;
  typedef typename _IIID::Interface Interface;
  static const IID& GetIID() throw() { return ThisIIID::GetIID(); }
  template<typename _OtherIID> _com_ptr_t(const _com_ptr_t<_OtherIID> &p) : m_pInterface(NULL) {
    HRESULT hr = _QueryInterface(p);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  template<typename _InterfaceType> _com_ptr_t(_InterfaceType *p) : m_pInterface(NULL) {
    HRESULT hr = _QueryInterface(p);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  _com_ptr_t(LPSTR str) { new(this) _com_ptr_t(static_cast<LPCSTR> (str),NULL); }
  _com_ptr_t(LPWSTR str) { new(this) _com_ptr_t(static_cast<LPCWSTR> (str),NULL); }
  explicit _com_ptr_t(_com_ptr_t *p) : m_pInterface(NULL) {
    if(!p) { _com_issue_error(E_POINTER); }
    else {
      m_pInterface = p->m_pInterface;
      AddRef();
    }
  }
  _com_ptr_t() throw() : m_pInterface(NULL) { }
  _com_ptr_t(int null) : m_pInterface(NULL) {
    if(null!=0) { _com_issue_error(E_POINTER); }
  }

#ifdef _NATIVE_NULLPTR_SUPPORTED
  _com_ptr_t(decltype(nullptr)) : m_pInterface(NULL) {}
#endif

  _com_ptr_t(const _com_ptr_t &cp) throw() : m_pInterface(cp.m_pInterface) { _AddRef(); }
  _com_ptr_t(Interface *pInterface) throw() : m_pInterface(pInterface) { _AddRef(); }
  _com_ptr_t(Interface *pInterface,bool fAddRef) throw() : m_pInterface(pInterface) {
    if(fAddRef) _AddRef();
  }
  _com_ptr_t(const _variant_t& varSrc) : m_pInterface(NULL) {
    HRESULT hr = QueryStdInterfaces(varSrc);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  explicit _com_ptr_t(const CLSID &clsid,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) : m_pInterface(NULL) {
    HRESULT hr = CreateInstance(clsid,pOuter,dwClsContext);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  explicit _com_ptr_t(LPCWSTR str,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) : m_pInterface(NULL) {
    HRESULT hr = CreateInstance(str,pOuter,dwClsContext);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  explicit _com_ptr_t(LPCSTR str,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) : m_pInterface(NULL) {
    HRESULT hr = CreateInstance(str,pOuter,dwClsContext);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
  }
  template<typename _OtherIID> _com_ptr_t &operator=(const _com_ptr_t<_OtherIID> &p) {
    HRESULT hr = _QueryInterface(p);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
    return *this;
  }
  template<typename _InterfaceType> _com_ptr_t &operator=(_InterfaceType *p) {
    HRESULT hr = _QueryInterface(p);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
    return *this;
  }
  _com_ptr_t &operator=(Interface *pInterface) throw() {
    if(m_pInterface!=pInterface) {
      Interface *pOldInterface = m_pInterface;
      m_pInterface = pInterface;
      _AddRef();
      if(pOldInterface!=NULL) pOldInterface->Release();
    }
    return *this;
  }
  _com_ptr_t &operator=(const _com_ptr_t &cp) throw() { return operator=(cp.m_pInterface); }
  _com_ptr_t &operator=(int null) {
    if(null!=0) { _com_issue_error(E_POINTER); }
    return operator=(reinterpret_cast<Interface*>(NULL));
  }
  _com_ptr_t &operator=(long long null) {
    if(null!=0) { _com_issue_error(E_POINTER); }
    return operator=(reinterpret_cast<Interface*>(NULL));
  }
  _com_ptr_t &operator=(const _variant_t& varSrc) {
    HRESULT hr = QueryStdInterfaces(varSrc);
    if(FAILED(hr) && (hr!=E_NOINTERFACE)) { _com_issue_error(hr); }
    return *this;
  }
  ~_com_ptr_t() throw() { _Release(); }
  void Attach(Interface *pInterface) throw() {
    _Release();
    m_pInterface = pInterface;
  }
  void Attach(Interface *pInterface,bool fAddRef) throw() {
    _Release();
    m_pInterface = pInterface;
    if(fAddRef) {
      if(!pInterface) { _com_issue_error(E_POINTER); }
      else pInterface->AddRef();
    }
  }
  Interface *Detach() throw() {
    Interface *const old = m_pInterface;
    m_pInterface = NULL;
    return old;
  }
  operator Interface*() const throw() { return m_pInterface; }
  operator Interface&() const {
    if(!m_pInterface) { _com_issue_error(E_POINTER); }
    return *m_pInterface;
  }
  Interface& operator*() const {
    if(!m_pInterface) { _com_issue_error(E_POINTER); }
    return *m_pInterface;
  }
  Interface **operator&() throw() {
    _Release();
    m_pInterface = NULL;
    return &m_pInterface;
  }
  Interface *operator->() const {
    if(!m_pInterface) { _com_issue_error(E_POINTER); }
    return m_pInterface;
  }
  operator bool() const throw() { return m_pInterface!=NULL; }
  template<typename _OtherIID> bool operator==(const _com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)==0; }
  template<typename _OtherIID> bool operator==(_com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)==0; }
  template<typename _InterfaceType> bool operator==(_InterfaceType *p) { return _CompareUnknown(p)==0; }
  bool operator==(Interface *p) { return (m_pInterface==p) ? true : _CompareUnknown(p)==0; }
  bool operator==(const _com_ptr_t &p) throw() { return operator==(p.m_pInterface); }
  bool operator==(_com_ptr_t &p) throw() { return operator==(p.m_pInterface); }
  bool operator==(int null) {
    if(null!=0) { _com_issue_error(E_POINTER); }
    return !m_pInterface;
  }
  bool operator==(long long null) {
    if(null) { _com_issue_error(E_POINTER); }
    return !m_pInterface;
  }
  template<typename _OtherIID> bool operator!=(const _com_ptr_t<_OtherIID> &p) { return !(operator==(p)); }
  template<typename _OtherIID> bool operator!=(_com_ptr_t<_OtherIID> &p) { return !(operator==(p)); }
  template<typename _InterfaceType> bool operator!=(_InterfaceType *p) { return !(operator==(p)); }
  bool operator!=(int null) { return !(operator==(null)); }
  bool operator!=(long long null) { return !(operator==(null)); }
  template<typename _OtherIID> bool operator<(const _com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)<0; }
  template<typename _OtherIID> bool operator<(_com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)<0; }
  template<typename _InterfaceType> bool operator<(_InterfaceType *p) { return _CompareUnknown(p)<0; }
  template<typename _OtherIID> bool operator>(const _com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)>0; }
  template<typename _OtherIID> bool operator>(_com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)>0; }
  template<typename _InterfaceType> bool operator>(_InterfaceType *p) { return _CompareUnknown(p)>0; }
  template<typename _OtherIID> bool operator<=(const _com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)<=0; }
  template<typename _OtherIID> bool operator<=(_com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)<=0; }
  template<typename _InterfaceType> bool operator<=(_InterfaceType *p) { return _CompareUnknown(p)<=0; }
  template<typename _OtherIID> bool operator>=(const _com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)>=0; }
  template<typename _OtherIID> bool operator>=(_com_ptr_t<_OtherIID> &p) { return _CompareUnknown(p)>=0; }
  template<typename _InterfaceType> bool operator>=(_InterfaceType *p) { return _CompareUnknown(p)>=0; }
  void Release() {
    if(!m_pInterface) { _com_issue_error(E_POINTER); }
    else {
      m_pInterface->Release();
      m_pInterface = NULL;
    }
  }
  void AddRef() {
    if(!m_pInterface) { _com_issue_error(E_POINTER); }
    else m_pInterface->AddRef();
  }
  Interface *GetInterfacePtr() const throw() { return m_pInterface; }
  Interface*& GetInterfacePtr() throw() { return m_pInterface; }
  HRESULT CreateInstance(const CLSID &rclsid,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) throw() {
    HRESULT hr;
    _Release();
    if(dwClsContext & (CLSCTX_LOCAL_SERVER | CLSCTX_REMOTE_SERVER)) {
      IUnknown *pIUnknown;
      hr = CoCreateInstance(rclsid,pOuter,dwClsContext,__uuidof(IUnknown),reinterpret_cast<void**>(&pIUnknown));
      if(SUCCEEDED(hr)) {
	hr = OleRun(pIUnknown);
	if(SUCCEEDED(hr)) hr = pIUnknown->QueryInterface(GetIID(),reinterpret_cast<void**>(&m_pInterface));
	pIUnknown->Release();
      }
    } else hr = CoCreateInstance(rclsid,pOuter,dwClsContext,GetIID(),reinterpret_cast<void**>(&m_pInterface));
    if(FAILED(hr)) m_pInterface = NULL;
    return hr;
  }
  HRESULT CreateInstance(LPCWSTR clsidString,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) throw() {
    if(!clsidString) return E_INVALIDARG;
    CLSID clsid;
    HRESULT hr;
    if(clsidString[0]==L'{') hr = CLSIDFromString(const_cast<LPWSTR> (clsidString),&clsid);
    else hr = CLSIDFromProgID(const_cast<LPWSTR> (clsidString),&clsid);
    if(FAILED(hr)) return hr;
    return CreateInstance(clsid,pOuter,dwClsContext);
  }
  HRESULT CreateInstance(LPCSTR clsidStringA,IUnknown *pOuter = NULL,DWORD dwClsContext = CLSCTX_ALL) throw() {
    if(!clsidStringA) return E_INVALIDARG;
    int size = lstrlenA(clsidStringA) + 1;
    int destSize = MultiByteToWideChar(CP_ACP,0,clsidStringA,size,NULL,0);
    if(destSize==0) return HRESULT_FROM_WIN32(GetLastError());
    LPWSTR clsidStringW;
    clsidStringW = static_cast<LPWSTR>(_malloca(destSize*sizeof(WCHAR)));
    if(!clsidStringW) return E_OUTOFMEMORY;
    if(MultiByteToWideChar(CP_ACP,0,clsidStringA,size,clsidStringW,destSize)==0) {
      _freea(clsidStringW);
      return HRESULT_FROM_WIN32(GetLastError());
    }
    HRESULT hr=CreateInstance(clsidStringW,pOuter,dwClsContext);
    _freea(clsidStringW);
    return hr;
  }
  HRESULT GetActiveObject(const CLSID &rclsid) throw() {
    _Release();
    IUnknown *pIUnknown;
    HRESULT hr = ::GetActiveObject(rclsid,NULL,&pIUnknown);
    if(SUCCEEDED(hr)) {
      hr = pIUnknown->QueryInterface(GetIID(),reinterpret_cast<void**>(&m_pInterface));
      pIUnknown->Release();
    }
    if(FAILED(hr)) m_pInterface = NULL;
    return hr;
  }
  HRESULT GetActiveObject(LPCWSTR clsidString) throw() {
    if(!clsidString) return E_INVALIDARG;
    CLSID clsid;
    HRESULT hr;
    if(clsidString[0]=='{') hr = CLSIDFromString(const_cast<LPWSTR> (clsidString),&clsid);
    else hr = CLSIDFromProgID(const_cast<LPWSTR> (clsidString),&clsid);
    if(FAILED(hr)) return hr;
    return GetActiveObject(clsid);
  }
  HRESULT GetActiveObject(LPCSTR clsidStringA) throw() {
    if(!clsidStringA) return E_INVALIDARG;
    int size = lstrlenA(clsidStringA) + 1;
    int destSize = MultiByteToWideChar(CP_ACP,0,clsidStringA,size,NULL,0);
    LPWSTR clsidStringW;
    try {
      clsidStringW = static_cast<LPWSTR>(_alloca(destSize*sizeof(WCHAR)));
    } catch (...) {
      clsidStringW = NULL;
    }
    if(!clsidStringW) return E_OUTOFMEMORY;
    if(MultiByteToWideChar(CP_ACP,0,clsidStringA,size,clsidStringW,destSize)==0) return HRESULT_FROM_WIN32(GetLastError());
    return GetActiveObject(clsidStringW);
  }
  template<typename _InterfaceType> HRESULT QueryInterface(const IID& iid,_InterfaceType*& p) throw () {
    if(m_pInterface!=NULL) return m_pInterface->QueryInterface(iid,reinterpret_cast<void**>(&p));
    return E_POINTER;
  }
  template<typename _InterfaceType> HRESULT QueryInterface(const IID& iid,_InterfaceType **p) throw() { return QueryInterface(iid,*p); }
private:
  Interface *m_pInterface;
  void _Release() throw() {
    if(m_pInterface!=NULL) m_pInterface->Release();
  }
  void _AddRef() throw() {
    if(m_pInterface!=NULL) m_pInterface->AddRef();
  }
  template<typename _InterfacePtr> HRESULT _QueryInterface(_InterfacePtr p) throw() {
    HRESULT hr;
    if(p!=NULL) {
      Interface *pInterface;
      hr = p->QueryInterface(GetIID(),reinterpret_cast<void**>(&pInterface));
      Attach(SUCCEEDED(hr)? pInterface: NULL);
    } else {
      operator=(static_cast<Interface*>(NULL));
      hr = E_NOINTERFACE;
    }
    return hr;
  }
  template<typename _InterfacePtr> int _CompareUnknown(_InterfacePtr p) {
    IUnknown *pu1,*pu2;
    if(m_pInterface!=NULL) {
      HRESULT hr = m_pInterface->QueryInterface(__uuidof(IUnknown),reinterpret_cast<void**>(&pu1));
      if(FAILED(hr)) {
	_com_issue_error(hr);
	pu1 = NULL;
      } else pu1->Release();
    } else pu1 = NULL;
    if(p!=NULL) {
      HRESULT hr = p->QueryInterface(__uuidof(IUnknown),reinterpret_cast<void**>(&pu2));
      if(FAILED(hr)) {
	_com_issue_error(hr);
	pu2 = NULL;
      } else pu2->Release();
    } else pu2 = NULL;
    return pu1 - pu2;
  }
  HRESULT QueryStdInterfaces(const _variant_t& varSrc) throw() {
    if(V_VT(&varSrc)==VT_DISPATCH) return _QueryInterface(V_DISPATCH(&varSrc));
    if(V_VT(&varSrc)==VT_UNKNOWN) return _QueryInterface(V_UNKNOWN(&varSrc));
    VARIANT varDest;
    VariantInit(&varDest);
    HRESULT hr = VariantChangeType(&varDest,const_cast<VARIANT*>(static_cast<const VARIANT*>(&varSrc)),0,VT_DISPATCH);
    if(SUCCEEDED(hr)) hr = _QueryInterface(V_DISPATCH(&varSrc));
    if(hr==E_NOINTERFACE) {
      VariantInit(&varDest);
      hr = VariantChangeType(&varDest,const_cast<VARIANT*>(static_cast<const VARIANT*>(&varSrc)),0,VT_UNKNOWN);
      if(SUCCEEDED(hr)) hr = _QueryInterface(V_UNKNOWN(&varSrc));
    }
    VariantClear(&varDest);
    return hr;
  }
};

template<typename _InterfaceType> bool operator==(int null,_com_ptr_t<_InterfaceType> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return !p;
}

template<typename _Interface,typename _InterfacePtr> bool operator==(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p==i; }

template<typename _Interface> bool operator!=(int null,_com_ptr_t<_Interface> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return p!=NULL;
}

template<typename _Interface,typename _InterfacePtr> bool operator!=(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p!=i; }

template<typename _Interface> bool operator<(int null,_com_ptr_t<_Interface> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return p>NULL;
}

template<typename _Interface,typename _InterfacePtr> bool operator<(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p>i; }

template<typename _Interface> bool operator>(int null,_com_ptr_t<_Interface> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return p<NULL;
}

template<typename _Interface,typename _InterfacePtr> bool operator>(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p<i; }

template<typename _Interface> bool operator<=(int null,_com_ptr_t<_Interface> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return p>=NULL;
}

template<typename _Interface,typename _InterfacePtr> bool operator<=(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p>=i; }

template<typename _Interface> bool operator>=(int null,_com_ptr_t<_Interface> &p) {
  if(null!=0) { _com_issue_error(E_POINTER); }
  return p<=NULL;
}

template<typename _Interface,typename _InterfacePtr> bool operator>=(_Interface *i,_com_ptr_t<_InterfacePtr> &p) { return p<=i; }

#pragma pop_macro("new")

#endif /* __cplusplus */

#endif /* _INC_COMIP */
