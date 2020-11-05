/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _PRNPTNTV_H_
#define _PRNPTNTV_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

DECLARE_HANDLE(HPTPROVIDER);

#define PRINTTICKET_ISTREAM_APIS 1

#define S_PT_NO_CONFLICT 0x00040001
#define S_PT_CONFLICT_RESOLVED 0x00040002

#define E_PRINTTICKET_FORMAT 0x80040003
#define E_PRINTCAPABILITIES_FORMAT 0x80040004
#define E_DELTA_PRINTTICKET_FORMAT 0x80040005
#define E_PRINTDEVICECAPABILITIES_FORMAT 0x80040006

typedef enum tagEDefaultDevmodeType {
  kUserDefaultDevmode,
  kPrinterDefaultDevmode
} EDefaultDevmodeType;

typedef enum {
  kPTPageScope,
  kPTDocumentScope,
  kPTJobScope
} EPrintTicketScope;

HRESULT WINAPI PTQuerySchemaVersionSupport(PCWSTR pszPrinterName, DWORD *pMaxVersion);
HRESULT WINAPI PTOpenProvider(PCWSTR pszPrinterName, DWORD dwVersion, HPTPROVIDER *phProvider);
HRESULT WINAPI PTOpenProviderEx(PCWSTR pszPrinterName, DWORD dwMaxVersion, DWORD dwPrefVersion, HPTPROVIDER *phProvider, DWORD *pUsedVersion);
HRESULT WINAPI PTCloseProvider(HPTPROVIDER hProvider);
HRESULT WINAPI PTReleaseMemory(PVOID pBuffer);
HRESULT WINAPI PTGetPrintCapabilities(HPTPROVIDER hProvider, IStream *pPrintTicket, IStream *pCapabilities, BSTR *pbstrErrorMessage);
HRESULT WINAPI PTGetPrintDeviceCapabilities(HPTPROVIDER hProvider, IStream *pPrintTicket, IStream *pDeviceCapabilities, BSTR *pbstrErrorMessage);
HRESULT WINAPI PTGetPrintDeviceResources(HPTPROVIDER hProvider, LPCWSTR pszLocaleName, IStream *pPrintTicket, IStream *pDeviceResources, BSTR *pbstrErrorMessage);
HRESULT WINAPI PTMergeAndValidatePrintTicket(HPTPROVIDER hProvider, IStream *pBaseTicket, IStream *pDeltaTicket, EPrintTicketScope scope, IStream *pResultTicket, BSTR *pbstrErrorMessage);
HRESULT WINAPI PTConvertPrintTicketToDevMode(HPTPROVIDER hProvider, IStream *pPrintTicket, EDefaultDevmodeType baseDevmodeType, EPrintTicketScope scope, ULONG *pcbDevmode, PDEVMODE *ppDevmode, BSTR *pbstrErrorMessage);
HRESULT WINAPI PTConvertDevModeToPrintTicket(HPTPROVIDER hProvider, ULONG cbDevmode, PDEVMODE pDevmode, EPrintTicketScope scope, IStream *pPrintTicket);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* _PRNPTNTV_H_ */
