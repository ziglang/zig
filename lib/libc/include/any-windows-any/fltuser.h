/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __FLTUSER_H__
#define __FLTUSER_H__

#include <winapifamily.h>
#include <sdkddkver.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <fltuserstructures.h>

#if ((OSVER(NTDDI_VERSION) == NTDDI_WIN2K && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WIN2KSP4)) \
     || (OSVER(NTDDI_VERSION) == NTDDI_WINXP && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WINXPSP2)) \
     || (OSVER(NTDDI_VERSION) == NTDDI_WS03 && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WS03SP1)) \
     || NTDDI_VERSION >= NTDDI_VISTA)

#ifdef __cplusplus
extern "C" {
#endif

#define FLT_ASSERT(e)
#define FLT_ASSERTMSG(m, e)

HRESULT WINAPI FilterAttach(LPCWSTR lpFilterName, LPCWSTR lpVolumeName, LPCWSTR lpInstanceName, DWORD dwCreatedInstanceNameLength, LPWSTR lpCreatedInstanceName);
HRESULT WINAPI FilterAttachAtAltitude(LPCWSTR lpFilterName, LPCWSTR lpVolumeName, LPCWSTR lpAltitude, LPCWSTR lpInstanceName, DWORD dwCreatedInstanceNameLength, LPWSTR lpCreatedInstanceName);
HRESULT WINAPI FilterClose(HFILTER hFilter);
HRESULT WINAPI FilterConnectCommunicationPort(LPCWSTR lpPortName, DWORD dwOptions, LPCVOID lpContext, WORD wSizeOfContext, LPSECURITY_ATTRIBUTES lpSecurityAttributes, HANDLE *hPort);
HRESULT WINAPI FilterCreate(LPCWSTR lpFilterName, HFILTER *hFilter);
HRESULT WINAPI FilterDetach(LPCWSTR lpFilterName, LPCWSTR lpVolumeName, LPCWSTR lpInstanceName);
HRESULT WINAPI FilterFindClose(HANDLE hFilterFind);
HRESULT WINAPI FilterFindFirst(FILTER_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned, LPHANDLE lpFilterFind);
HRESULT WINAPI FilterFindNext(HANDLE hFilterFind, FILTER_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterGetDosName(LPCWSTR lpVolumeName, LPWSTR lpDosName, DWORD dwDosNameBufferSize);
HRESULT WINAPI FilterGetInformation(HFILTER hFilter, FILTER_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterGetMessage(HANDLE hPort, PFILTER_MESSAGE_HEADER lpMessageBuffer, DWORD dwMessageBufferSize, LPOVERLAPPED lpOverlapped);
HRESULT WINAPI FilterInstanceClose(HFILTER_INSTANCE hInstance);
HRESULT WINAPI FilterInstanceCreate(LPCWSTR lpFilterName, LPCWSTR lpVolumeName, LPCWSTR lpInstanceName, HFILTER_INSTANCE *hInstance);
HRESULT WINAPI FilterInstanceFindClose(HANDLE hFilterInstanceFind);
HRESULT WINAPI FilterInstanceFindFirst(LPCWSTR lpFilterName, INSTANCE_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned, LPHANDLE lpFilterInstanceFind);
HRESULT WINAPI FilterInstanceFindNext(HANDLE hFilterInstanceFind, INSTANCE_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterInstanceGetInformation(HFILTER_INSTANCE hInstance, INSTANCE_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterLoad(LPCWSTR lpFilterName);
HRESULT WINAPI FilterReplyMessage(HANDLE hPort,PFILTER_REPLY_HEADER lpReplyBuffer,DWORD dwReplyBufferSize);
HRESULT WINAPI FilterSendMessage(HANDLE hPort, LPVOID lpInBuffer, DWORD dwInBufferSize, LPVOID lpOutBuffer, DWORD dwOutBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterUnload(LPCWSTR lpFilterName);
HRESULT WINAPI FilterVolumeFindClose(HANDLE hVolumeFind);
HRESULT WINAPI FilterVolumeFindFirst(FILTER_VOLUME_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned, PHANDLE lpVolumeFind);
HRESULT WINAPI FilterVolumeFindNext(HANDLE hVolumeFind, FILTER_VOLUME_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);
HRESULT WINAPI FilterVolumeInstanceFindClose(HANDLE hVolumeInstanceFind);
HRESULT WINAPI FilterVolumeInstanceFindFirst(LPCWSTR lpVolumeName, INSTANCE_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned, LPHANDLE lpVolumeInstanceFind);
HRESULT WINAPI FilterVolumeInstanceFindNext(HANDLE hVolumeInstanceFind, INSTANCE_INFORMATION_CLASS dwInformationClass, LPVOID lpBuffer, DWORD dwBufferSize, LPDWORD lpBytesReturned);

#ifdef __cplusplus
}
#endif

#endif

#define FLT_MGR_BASELINE \
  ((OSVER(NTDDI_VERSION) == NTDDI_WIN2K && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WIN2KSP4)) \
   || (OSVER(NTDDI_VERSION) == NTDDI_WINXP && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WINXPSP2)) \
   || (OSVER(NTDDI_VERSION) == NTDDI_WS03 && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WS03SP1)) \
   || NTDDI_VERSION >= NTDDI_VISTA)
#define FLT_MGR_AFTER_XPSP2 \
  ((OSVER(NTDDI_VERSION) == NTDDI_WIN2K && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WIN2KSP4)) \
   || (OSVER(NTDDI_VERSION) == NTDDI_WINXP && SPVER(NTDDI_VERSION) >  SPVER(NTDDI_WINXPSP2)) \
   || (OSVER(NTDDI_VERSION) == NTDDI_WS03 && SPVER(NTDDI_VERSION) >= SPVER(NTDDI_WS03SP1)) \
   || NTDDI_VERSION >= NTDDI_VISTA)
#define FLT_MGR_LONGHORN	(NTDDI_VERSION >= NTDDI_VISTA)
#define FLT_MGR_WIN7		(NTDDI_VERSION >= NTDDI_WIN7)
#define FLT_MGR_WIN8		(NTDDI_VERSION >= NTDDI_WIN8)

#endif /* WINAPI_PARTITION_DESKTOP.  */

#endif
