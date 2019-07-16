/*
 *  Header for the Device Driver Interface - User Interface library
 *
 *  Copyright 2007 Marcel Partap
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_WINDDIUI_H
#define __WINE_WINDDIUI_H

#include <compstui.h>

#ifdef __cplusplus
extern "C" {
#endif

#if (NTDDI_VERSION >= NTDDI_WINXP)
typedef struct _DOCEVENT_FILTER {
    UINT    cbSize;
    UINT    cElementsAllocated;
    UINT    cElementsNeeded;
    UINT    cElementsReturned;
    DWORD   aDocEventCall[ANYSIZE_ARRAY];
} DOCEVENT_FILTER, *PDOCEVENT_FILTER;
typedef struct _DOCEVENT_CREATEDCPRE {
    PWSTR       pszDriver;
    PWSTR       pszDevice;
    PDEVMODEW   pdm;
    WINBOOL     bIC;
} DOCEVENT_CREATEDCPRE, *PDCEVENT_CREATEDCPRE;
typedef struct _DOCEVENT_ESCAPE {
    int    iEscape;
    int    cjInput;
    PVOID  pvInData;
} DOCEVENT_ESCAPE, *PDOCEVENT_ESCAPE;
#endif
#define DOCUMENTEVENT_FIRST         1
#define DOCUMENTEVENT_CREATEDCPRE   1
#define DOCUMENTEVENT_CREATEDCPOST  2
#define DOCUMENTEVENT_RESETDCPRE    3
#define DOCUMENTEVENT_RESETDCPOST   4
#define DOCUMENTEVENT_STARTDOC      5
#define DOCUMENTEVENT_STARTDOCPRE   5
#define DOCUMENTEVENT_STARTPAGE     6
#define DOCUMENTEVENT_ENDPAGE       7
#define DOCUMENTEVENT_ENDDOC        8
#define DOCUMENTEVENT_ENDDOCPRE     8
#define DOCUMENTEVENT_ABORTDOC      9
#define DOCUMENTEVENT_DELETEDC     10
#define DOCUMENTEVENT_ESCAPE       11
#define DOCUMENTEVENT_ENDDOCPOST   12
#define DOCUMENTEVENT_STARTDOCPOST 13
#if (NTDDI_VERSION >= NTDDI_VISTA)
#define DOCUMENTEVENT_QUERYFILTER 14
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTSEQUENCEPRE              1
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTPRE                      2
#define DOCUMENTEVENT_XPS_ADDFIXEDPAGEEPRE                         3
#define DOCUMENTEVENT_XPS_ADDFIXEDPAGEPOST                         4
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTPOST                     5
#define DOCUMENTEVENT_XPS_CANCELJOB                                6
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTSEQUENCEPRINTTICKETPRE   7
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTPRINTTICKETPRE           8
#define DOCUMENTEVENT_XPS_ADDFIXEDPAGEPRINTTICKETPRE               9
#define DOCUMENTEVENT_XPS_ADDFIXEDPAGEPRINTTICKETPOST             10
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTPRINTTICKETPOST         11
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTSEQUENCEPRINTTICKETPOST 12
#define DOCUMENTEVENT_XPS_ADDFIXEDDOCUMENTSEQUENCEPOST            13
#define DOCUMENTEVENT_LAST 15
#elif (NTDDI_VERSION >= NTDDI_WINXP)
#define DOCUMENTEVENT_QUERYFILTER  14
#define DOCUMENTEVENT_LAST         15
#else
#define DOCUMENTEVENT_LAST 14
#endif
#define DOCUMENTEVENT_SPOOLED 0x10000
#define DOCUMENTEVENT_SUCCESS     1
#define DOCUMENTEVENT_UNSUPPORTED 0
#define DOCUMENTEVENT_FAILURE    -1
#define DOCUMENTEVENT_EVENT(iX) (LOWORD(iX))
#define DOCUMENTEVENT_FLAGS(iX) (HIWORD(iX))

int WINAPI DrvDocumentEvent(HANDLE,HDC,int,ULONG,PVOID,ULONG,PVOID);

#define DRIVER_EVENT_INITIALIZE 1
#define DRIVER_EVENT_DELETE 2

#define PRINTER_EVENT_ADD_CONNECTION 1
#define PRINTER_EVENT_DELETE_CONNECTION 2
#define PRINTER_EVENT_INITIALIZE 3
#define PRINTER_EVENT_DELETE 4
#define PRINTER_EVENT_CACHE_REFRESH 5
#define PRINTER_EVENT_CACHE_DELETE 6
#define PRINTER_EVENT_ATTRIBUTES_CHANGED 7

#define PRINTER_EVENT_FLAG_NO_UI 1

WINBOOL WINAPI DrvDriverEvent(DWORD, DWORD, LPBYTE, LPARAM);
WINBOOL WINAPI DrvPrinterEvent(LPWSTR, INT, DWORD, LPARAM);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* __WINE_WINDDIUI_H */
