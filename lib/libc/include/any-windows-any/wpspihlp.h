/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __WPSPIHLP_H__
#define __WPSPIHLP_H__

#include <windows.h>
#include "wptypes.h"

#define WPPFUNC __declspec(dllimport)

#define WPF_FORCE_BIND 0x00000100

typedef HRESULT (WINAPI *PFN_WPPBINDTOSITEA)(HWND hwnd,LPCSTR sSiteName,LPCSTR sURL,REFIID riid,DWORD dwFlag,DWORD dwReserved,PVOID *ppvUnk);
typedef HRESULT (WINAPI *PFN_WPPLISTSITESA)(LPDWORD pdwSitesBufLen,LPWPSITEINFOA pSitesBuffer,LPDWORD pdwNumSites);
typedef HRESULT (WINAPI *PFN_WPPDELETESITEA)(LPCSTR sSiteName);
typedef HRESULT (WINAPI *PFN_WPPBINDTOSITEW)(HWND hwnd,LPCWSTR sSiteName,LPCWSTR sURL,REFIID riid,DWORD dwFlag,DWORD dwReserved,PVOID *ppvUnk);
typedef HRESULT (WINAPI *PFN_WPPLISTSITESW)(LPDWORD pdwSitesBufLen,LPWPSITEINFOW pSitesBuffer,LPDWORD pdwNumSites);
typedef HRESULT (WINAPI *PFN_WPPDELETESITEW)(LPCWSTR sSiteName);

HRESULT WPPFUNC WINAPI WppBindToSiteA(HWND hwnd,LPCSTR sSiteName,LPCSTR sURL,REFIID riid,DWORD dwFlag,DWORD dwReserved,PVOID *ppvUnk);
HRESULT WPPFUNC WINAPI WppListSitesA(LPDWORD pdwSitesBufLen,LPWPSITEINFOA pSitesBuffer,LPDWORD pdwNumSites);
HRESULT WPPFUNC WINAPI WppDeleteSiteA(LPCSTR sSiteName);
HRESULT WPPFUNC WINAPI WppBindToSiteW(HWND hwnd,LPCWSTR sSiteName,LPCWSTR sURL,REFIID riid,DWORD dwFlag,DWORD dwReserved,PVOID *ppvUnk);
HRESULT WPPFUNC WINAPI WppListSitesW(LPDWORD pdwSitesBufLen,LPWPSITEINFOW pSitesBuffer,LPDWORD pdwNumSites);
HRESULT WPPFUNC WINAPI WppDeleteSiteW(LPCWSTR sSiteName);

#define EP_WPPBINDTOSITEW "WppBindToSiteW"
#define EP_WPPLISTSITESW "WppListSitesW"
#define EP_WPPDELETESITEW "WppDeleteSiteW"

#define EP_WPPBINDTOSITEA "WppBindToSiteA"
#define EP_WPPLISTSITESA "WppListSitesA"
#define EP_WPPDELETESITEA "WppDeleteSiteA"
#endif
