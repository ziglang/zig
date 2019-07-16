/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_COMDEF
#define _INC_COMDEF

#include <_mingw.h>

#ifndef RC_INVOKED

#ifndef __cplusplus
#error Native Compiler support only available in C++ compiler
#endif

#include <ole2.h>
#include <olectl.h>
#include <comutil.h>

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

#ifdef __cplusplus

class _com_error;
void WINAPI _com_raise_error(HRESULT hr,IErrorInfo *perrinfo = 0);
void WINAPI _set_com_error_handler(void (WINAPI *pHandler)(HRESULT hr,IErrorInfo *perrinfo));
void WINAPI _com_issue_errorex(HRESULT,IUnknown*,REFIID);
HRESULT WINAPI _com_dispatch_propget(IDispatch*,DISPID,VARTYPE,void*);
HRESULT __cdecl _com_dispatch_propput(IDispatch*,DISPID,VARTYPE,...);
HRESULT __cdecl _com_dispatch_method(IDispatch*,DISPID,WORD,VARTYPE,void*,const wchar_t*,...);
HRESULT WINAPI _com_dispatch_raw_propget(IDispatch*,DISPID,VARTYPE,void*) throw();
HRESULT __cdecl _com_dispatch_raw_propput(IDispatch*,DISPID,VARTYPE,...) throw();
HRESULT __cdecl _com_dispatch_raw_method(IDispatch*,DISPID,WORD,VARTYPE,void*,const wchar_t*,...) throw();

class _com_error {
public:
  _com_error(HRESULT hr,IErrorInfo *perrinfo = NULL,bool fAddRef = false) throw();
  _com_error(const _com_error &that) throw();
  virtual ~_com_error() throw();
  _com_error &operator=(const _com_error &that) throw();
  HRESULT Error() const throw();
  WORD WCode() const throw();
  IErrorInfo *ErrorInfo() const throw();
  _bstr_t Description() const;
  DWORD HelpContext() const throw();
  _bstr_t HelpFile() const;
  _bstr_t Source() const;
  GUID GUID_() const throw();
  const TCHAR *ErrorMessage() const throw();
  static HRESULT WCodeToHRESULT(WORD wCode) throw();
  static WORD HRESULTToWCode(HRESULT hr) throw();
private:
  void Dtor() throw();
  void Ctor(const _com_error &that) throw();
  enum {
    WCODE_HRESULT_FIRST = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_ITF,0x200),WCODE_HRESULT_LAST = MAKE_HRESULT(SEVERITY_ERROR,FACILITY_ITF+1,0) - 1
  };
  HRESULT m_hresult;
  IErrorInfo *m_perrinfo;
  mutable TCHAR *m_pszMsg;
};

inline _com_error::_com_error(HRESULT hr,IErrorInfo *perrinfo,bool fAddRef) throw() : m_hresult(hr),m_perrinfo(perrinfo),m_pszMsg(NULL) {
  if(m_perrinfo!=NULL && fAddRef) m_perrinfo->AddRef();
}

inline _com_error::_com_error(const _com_error &that) throw() {
  Ctor(that);
}

inline _com_error::~_com_error() throw() {
	Dtor();
}

inline _com_error &_com_error::operator=(const _com_error &that) throw() {
  if(this!=&that) {
    Dtor();
    Ctor(that); 
  }
  return *this;
}

inline HRESULT _com_error::Error() const throw() { return m_hresult; }
inline WORD _com_error::WCode() const throw() { return HRESULTToWCode(m_hresult); }

inline IErrorInfo *_com_error::ErrorInfo() const throw() {
  if(m_perrinfo!=NULL) m_perrinfo->AddRef();
  return m_perrinfo;
}

inline _bstr_t _com_error::Description() const {
  BSTR bstr = NULL;
  if(m_perrinfo!=NULL) m_perrinfo->GetDescription(&bstr);
  return _bstr_t(bstr,false);
}

inline DWORD _com_error::HelpContext() const throw() {
  DWORD dwHelpContext = 0;
  if(m_perrinfo!=NULL) m_perrinfo->GetHelpContext(&dwHelpContext);
  return dwHelpContext;
}

inline _bstr_t _com_error::HelpFile() const {
  BSTR bstr = NULL;
  if(m_perrinfo!=NULL)  m_perrinfo->GetHelpFile(&bstr);
  return _bstr_t(bstr,false);
}

inline _bstr_t _com_error::Source() const {
  BSTR bstr = NULL;
  if(m_perrinfo!=NULL) m_perrinfo->GetSource(&bstr);
  return _bstr_t(bstr,false);
}

inline _GUID _com_error::GUID_() const throw() {
  _GUID guid;
  memset (&guid, 0, sizeof (_GUID));
  if(m_perrinfo!=NULL) m_perrinfo->GetGUID(&guid);
  return guid;
}

inline const TCHAR *_com_error::ErrorMessage() const throw() {
  if(!m_pszMsg) {
    FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|FORMAT_MESSAGE_FROM_SYSTEM,NULL,m_hresult,MAKELANGID(LANG_NEUTRAL,SUBLANG_DEFAULT),(LPTSTR)&m_pszMsg,0,NULL);
    if(m_pszMsg!=NULL) {
      int nLen = lstrlen(m_pszMsg);
      if(nLen > 1 && m_pszMsg[nLen - 1]=='\n') {
	m_pszMsg[nLen-1] = 0;
	if(m_pszMsg[nLen - 2]=='\r') m_pszMsg[nLen-2] = 0;
      }
    } else {
      m_pszMsg = (LPTSTR)LocalAlloc(0,32 *sizeof(TCHAR));
      if(m_pszMsg!=NULL) {
	WORD wCode = WCode();
	if(wCode!=0) {
	  _COM_PRINTF_S_1(m_pszMsg,32,TEXT("IDispatch error #%d"),wCode);
	} else {
	  _COM_PRINTF_S_1(m_pszMsg,32,TEXT("Unknown error 0x%0lX"),m_hresult);
	}
      }
    }
  }
  return m_pszMsg;
}

inline HRESULT _com_error::WCodeToHRESULT(WORD wCode) throw() { return wCode >= 0xFE00 ? WCODE_HRESULT_LAST : WCODE_HRESULT_FIRST + wCode; }
inline WORD _com_error::HRESULTToWCode(HRESULT hr) throw() { return (hr >= WCODE_HRESULT_FIRST && hr <= WCODE_HRESULT_LAST) ? WORD(hr - WCODE_HRESULT_FIRST) : 0; }

inline void _com_error::Dtor() throw() {
  if(m_perrinfo!=NULL) m_perrinfo->Release();
  if(m_pszMsg!=NULL) LocalFree((HLOCAL)m_pszMsg);
}

inline void _com_error::Ctor(const _com_error &that) throw() {
  m_hresult = that.m_hresult;
  m_perrinfo = that.m_perrinfo;
  m_pszMsg = NULL;
  if(m_perrinfo!=NULL) m_perrinfo->AddRef();
}

inline void _com_issue_error(HRESULT hr) {
#if __EXCEPTIONS
    throw _com_error(hr);
#else
    /* This is designed to use exceptions. If exceptions are disabled, there is not much we can do here. */
    __debugbreak();
#endif
}


typedef int __missing_type__;

#if !defined(_COM_SMARTPTR)
#if !defined(_INC_COMIP)
#include <comip.h>
#endif
#define _COM_SMARTPTR _com_ptr_t
#define _COM_SMARTPTR_LEVEL2 _com_IIID
#endif
#if defined(_COM_SMARTPTR)
#if !defined(_COM_SMARTPTR_TYPEDEF)
#if defined(_COM_SMARTPTR_LEVEL2)
#ifdef __CRT_UUID_DECL
/* With our __uuidof, its result can't be passed directly as a template argument. We have _com_IIID_getter to work around that. */
#define _COM_SMARTPTR_TYPEDEF(Interface,aIID) inline const IID &__##Interface##_IID_getter(void) { return aIID; } typedef _COM_SMARTPTR< _com_IIID_getter<Interface, __##Interface##_IID_getter > > Interface ## Ptr
#else
#define _COM_SMARTPTR_TYPEDEF(Interface,IID) typedef _COM_SMARTPTR< _COM_SMARTPTR_LEVEL2<Interface, &IID > > Interface ## Ptr
#endif
#else
#define _COM_SMARTPTR_TYPEDEF(Interface,IID) typedef _COM_SMARTPTR<Interface,&IID > Interface ## Ptr
#endif
#endif
#endif

#if !defined(_COM_NO_STANDARD_GUIDS_)
#if defined(__IFontDisp_INTERFACE_DEFINED__)
#if !defined(Font)
  struct Font : IFontDisp {};
#endif
_COM_SMARTPTR_TYPEDEF(Font,__uuidof(IDispatch));

#endif
#if defined(__IFontEventsDisp_INTERFACE_DEFINED__)
#if !defined(FontEvents)
  struct FontEvents : IFontEventsDisp {};
#endif
_COM_SMARTPTR_TYPEDEF(FontEvents,__uuidof(IDispatch));
#endif
#if defined(__IPictureDisp_INTERFACE_DEFINED__)
#if !defined(Picture)
  struct Picture : IPictureDisp {};
#endif
_COM_SMARTPTR_TYPEDEF(Picture,__uuidof(IDispatch));
#endif

#include "comdefsp.h"
#endif
#endif

#endif /* __cplusplus */

#endif
