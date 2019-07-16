/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INTSHCUT_H__
#define __INTSHCUT_H__

#include <_mingw_unicode.h>
#include <isguids.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _INTSHCUT_
#define INTSHCUTAPI
#else
#define INTSHCUTAPI DECLSPEC_IMPORT
#endif

#define E_FLAGS MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1000)
#define IS_E_EXEC_FAILED MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x2002)
#define URL_E_INVALID_SYNTAX MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1001)
#define URL_E_UNREGISTERED_PROTOCOL MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1002)

  typedef enum iurl_seturl_flags {
    IURL_SETURL_FL_GUESS_PROTOCOL = 0x0001,IURL_SETURL_FL_USE_DEFAULT_PROTOCOL = 0x0002
  } IURL_SETURL_FLAGS;

  typedef enum iurl_invokecommand_flags {
    IURL_INVOKECOMMAND_FL_ALLOW_UI = 0x0001,IURL_INVOKECOMMAND_FL_USE_DEFAULT_VERB = 0x0002,IURL_INVOKECOMMAND_FL_DDEWAIT = 0x0004
  } IURL_INVOKECOMMAND_FLAGS;

  typedef struct urlinvokecommandinfoA {
    DWORD dwcbSize;
    DWORD dwFlags;
    HWND hwndParent;
    LPCSTR pcszVerb;
  } URLINVOKECOMMANDINFOA;

  typedef URLINVOKECOMMANDINFOA *PURLINVOKECOMMANDINFOA;
  typedef const URLINVOKECOMMANDINFOA CURLINVOKECOMMANDINFOA;
  typedef const URLINVOKECOMMANDINFOA *PCURLINVOKECOMMANDINFOA;

  typedef struct urlinvokecommandinfoW {
    DWORD dwcbSize;
    DWORD dwFlags;
    HWND hwndParent;
    LPCWSTR pcszVerb;
  } URLINVOKECOMMANDINFOW;

  typedef URLINVOKECOMMANDINFOW *PURLINVOKECOMMANDINFOW;
  typedef const URLINVOKECOMMANDINFOW CURLINVOKECOMMANDINFOW;
  typedef const URLINVOKECOMMANDINFOW *PCURLINVOKECOMMANDINFOW;

#define URLINVOKECOMMANDINFO __MINGW_NAME_AW(URLINVOKECOMMANDINFO)
#define PURLINVOKECOMMANDINFO __MINGW_NAME_AW(PURLINVOKECOMMANDINFO)
#define CURLINVOKECOMMANDINFO __MINGW_NAME_AW(CURLINVOKECOMMANDINFO)
#define PCURLINVOKECOMMANDINFO __MINGW_NAME_AW(PCURLINVOKECOMMANDINFO)

#undef INTERFACE
#define INTERFACE IUniformResourceLocatorA

  DECLARE_INTERFACE_(IUniformResourceLocatorA,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(SetURL)(THIS_ LPCSTR pcszURL,DWORD dwInFlags) PURE;
    STDMETHOD(GetURL)(THIS_ LPSTR *ppszURL) PURE;
    STDMETHOD(InvokeCommand)(THIS_ PURLINVOKECOMMANDINFOA purlici) PURE;
  };

#undef INTERFACE
#define INTERFACE IUniformResourceLocatorW
  DECLARE_INTERFACE_(IUniformResourceLocatorW,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(SetURL)(THIS_ LPCWSTR pcszURL,DWORD dwInFlags) PURE;
    STDMETHOD(GetURL)(THIS_ LPWSTR *ppszURL) PURE;
    STDMETHOD(InvokeCommand)(THIS_ PURLINVOKECOMMANDINFOW purlici) PURE;
  };

#define IUniformResourceLocator __MINGW_NAME_AW(IUniformResourceLocator)

#define IUniformResourceLocatorVtbl __MINGW_NAME_AW_EXT(IUniformResourceLocator,Vtbl)

  typedef IUniformResourceLocator *PIUniformResourceLocator;
  typedef const IUniformResourceLocator CIUniformResourceLocator;
  typedef const IUniformResourceLocator *PCIUniformResourceLocator;

  typedef enum translateurl_in_flags {
    TRANSLATEURL_FL_GUESS_PROTOCOL = 0x0001,TRANSLATEURL_FL_USE_DEFAULT_PROTOCOL = 0x0002
  } TRANSLATEURL_IN_FLAGS;

  INTSHCUTAPI HRESULT WINAPI TranslateURLA(PCSTR pcszURL,DWORD dwInFlags,PSTR *ppszTranslatedURL);
  INTSHCUTAPI HRESULT WINAPI TranslateURLW(PCWSTR pcszURL,DWORD dwInFlags,PWSTR UNALIGNED *ppszTranslatedURL);

#define TranslateURL __MINGW_NAME_AW(TranslateURL)

  typedef enum urlassociationdialog_in_flags {
    URLASSOCDLG_FL_USE_DEFAULT_NAME = 0x0001,URLASSOCDLG_FL_REGISTER_ASSOC = 0x0002
  } URLASSOCIATIONDIALOG_IN_FLAGS;

  INTSHCUTAPI HRESULT WINAPI URLAssociationDialogA(HWND hwndParent,DWORD dwInFlags,PCSTR pcszFile,PCSTR pcszURL,PSTR pszAppBuf,UINT ucAppBufLen);
  INTSHCUTAPI HRESULT WINAPI URLAssociationDialogW(HWND hwndParent,DWORD dwInFlags,PCWSTR pcszFile,PCWSTR pcszURL,PWSTR pszAppBuf,UINT ucAppBufLen);

#define URLAssociationDialog __MINGW_NAME_AW(URLAssociationDialog)

  typedef enum mimeassociationdialog_in_flags {
    MIMEASSOCDLG_FL_REGISTER_ASSOC = 0x0001
  } MIMEASSOCIATIONDIALOG_IN_FLAGS;

  INTSHCUTAPI HRESULT WINAPI MIMEAssociationDialogA(HWND hwndParent,DWORD dwInFlags,PCSTR pcszFile,PCSTR pcszMIMEContentType,PSTR pszAppBuf,UINT ucAppBufLen);
  INTSHCUTAPI HRESULT WINAPI MIMEAssociationDialogW(HWND hwndParent,DWORD dwInFlags,PCWSTR pcszFile,PCWSTR pcszMIMEContentType,PWSTR pszAppBuf,UINT ucAppBufLen);

#define MIMEAssociationDialog __MINGW_NAME_AW(MIMEAssociationDialog)

  INTSHCUTAPI WINBOOL WINAPI InetIsOffline(DWORD dwFlags);

#ifdef __cplusplus
}
#endif
#endif
