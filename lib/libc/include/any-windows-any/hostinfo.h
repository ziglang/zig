/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef HOST_INFO_H_INCLUDED
#define HOST_INFO_H_INCLUDED

const GUID IID_IHostInfoUpdate = { 0x1d044690,0x8923,0x11d0,{ 0xab,0xd2,0x0,0xa0,0xc9,0x11,0xe8,0xb2 } };

enum hostinfo {
  hostinfoLocale = 0,hostinfoCodePage = 1,hostinfoErrorLocale = 2
};

#ifdef __cplusplus
class IHostInfoUpdate : public IUnknown {
public:
  STDMETHOD(QueryInterface)(REFIID riid,void **ppvObj) = 0;
  STDMETHOD_(ULONG,AddRef)(void) = 0;
  STDMETHOD_(ULONG,Release)(void) = 0;
  STDMETHOD(UpdateInfo)(hostinfo hostinfoNew) = 0;
};
#endif /* __cplusplus */

const GUID IID_IHostInfoProvider = { 0xf8418ae0,0x9a5d,0x11d0,{ 0xab,0xd4,0x0,0xa0,0xc9,0x11,0xe8,0xb2 } };

#ifdef __cplusplus
class IHostInfoProvider : public IUnknown {
public:
  STDMETHOD(QueryInterface)(REFIID riid,void **ppvObj) = 0;
  STDMETHOD_(ULONG,AddRef)(void) = 0;
  STDMETHOD_(ULONG,Release)(void) = 0;
  STDMETHOD(GetHostInfo)(hostinfo hostinfoRequest,void **ppvInfo) = 0;
};
#endif /* __cplusplus */

#endif
