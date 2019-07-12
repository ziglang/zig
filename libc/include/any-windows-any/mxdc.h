/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _MXDC_H_
#define _MXDC_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#include <pshpack1.h>

  typedef enum tagMxdcS0PageEnums {
    MXDC_RESOURCE_TTF = 0,
    MXDC_RESOURCE_JPEG = 1,
    MXDC_RESOURCE_PNG = 2,
    MXDC_RESOURCE_TIFF = 3,
    MXDC_RESOURCE_WDP = 4,
    MXDC_RESOURCE_DICTIONARY = 5,
    MXDC_RESOURCE_ICC_PROFILE = 6,
    MXDC_RESOURCE_JPEG_THUMBNAIL = 7,
    MXDC_RESOURCE_PNG_THUMBNAIL = 8,
    MXDC_RESOURCE_MAX
  } MXDC_S0_PAGE_ENUMS;

#if NTDDI_VERSION >= 0x06000100
  typedef enum tagMxdcLandscapeRotationEnums {
    MXDC_LANDSCAPE_ROTATE_NONE = 0,
    MXDC_LANDSCAPE_ROTATE_COUNTERCLOCKWISE_90_DEGREES = 90,
    MXDC_LANDSCAPE_ROTATE_COUNTERCLOCKWISE_270_DEGREES = -90
  } MXDC_LANDSCAPE_ROTATION_ENUMS;

  typedef enum tagMxdcImageTypeEnums {
    MXDC_IMAGETYPE_JPEGHIGH_COMPRESSION = 1,
    MXDC_IMAGETYPE_JPEGMEDIUM_COMPRESSION = 2,
    MXDC_IMAGETYPE_JPEGLOW_COMPRESSION = 3,
    MXDC_IMAGETYPE_PNG = 4
  } MXDC_IMAGE_TYPE_ENUMS;
#endif

  typedef struct tagMxdcEscapeHeader {
    ULONG cbInput;
    ULONG cbOutput;
    ULONG opCode;
  } MXDC_ESCAPE_HEADER_T, *P_MXDC_ESCAPE_HEADER_T;

  typedef struct tagMxdcGetFileNameData {
    ULONG cbOutput;
    wchar_t wszData[1];
  } MXDC_GET_FILENAME_DATA_T, *P_MXDC_GET_FILENAME_DATA_T;

  typedef struct tagMxdcS0PageData {
    DWORD dwSize;
    BYTE bData[1];
  } MXDC_S0PAGE_DATA_T, *P_MXDC_S0PAGE_DATA_T;

  typedef struct tagMxdcXpsS0PageResource {
    DWORD dwSize;
    DWORD dwResourceType;
    BYTE szUri[MAX_PATH];
    DWORD dwDataSize;
    BYTE bData[1];
  } MXDC_XPS_S0PAGE_RESOURCE_T, *P_MXDC_XPS_S0PAGE_RESOURCE_T;

  typedef struct tagMxdcPrintTicketPassthrough {
    DWORD dwDataSize;
    BYTE bData[1];
  } MXDC_PRINTTICKET_DATA_T, *P_MXDC_PRINTTICKET_DATA_T;

  typedef struct tagMxdcPrintTicketEscape {
    MXDC_ESCAPE_HEADER_T mxdcEscape;
    MXDC_PRINTTICKET_DATA_T printTicketData;
  } MXDC_PRINTTICKET_ESCAPE_T, *P_MXDC_PRINTTICKET_ESCAPE_T;

  typedef struct tagMxdcS0PagePassthroughEscape {
    MXDC_ESCAPE_HEADER_T mxdcEscape;
    MXDC_S0PAGE_DATA_T xpsS0PageData;
  } MXDC_S0PAGE_PASSTHROUGH_ESCAPE_T, *P_MXDC_S0PAGE_PASSTHROUGH_ESCAPE_T;

  typedef struct tagMxdcS0PageResourceEscape {
    MXDC_ESCAPE_HEADER_T mxdcEscape;
    MXDC_XPS_S0PAGE_RESOURCE_T xpsS0PageResourcePassthrough;
  } MXDC_S0PAGE_RESOURCE_ESCAPE_T, *P_MXDC_S0PAGE_RESOURCE_ESCAPE_T;

#include <poppack.h>

#define MXDC_ESCAPE 4122

#define MXDCOP_GET_FILENAME 14
#define MXDCOP_PRINTTICKET_FIXED_DOC_SEQ 22
#define MXDCOP_PRINTTICKET_FIXED_DOC 24
#define MXDCOP_PRINTTICKET_FIXED_PAGE 26
#define MXDCOP_SET_S0PAGE 28
#define MXDCOP_SET_S0PAGE_RESOURCE 30
#define MXDCOP_SET_XPSPASSTHRU_MODE 32

#if NTDDI_VERSION >= 0x06000100
#define MXDC_IMAGEABLE_AREA_PROP_NAME_WSTR (L"MxdcImageableArea")
#define MXDC_IMAGE_COMPRESSION_TYPE_PROP_NAME_WSTR (L"MxdcImageCompressionType")
#define MXDC_DOTS_PER_INCH_PROP_NAME_WSTR (L"MxdcDotsPerInch")
#define MXDC_LANDSCAPE_ROTATION_PROP_NAME_WSTR (L"MxdcLandscapeRotation")
#endif

#if NTDDI_VERSION >= 0x06000100
  HRESULT WINAPI MxdcGetPDEVAdjustment (HANDLE hPrinter, ULONG cbDevMode, const DEVMODE *pDevMode, ULONG cbIn, const VOID *pvIn, ULONG cbPrintPropertiesCollection, PrintPropertiesCollection *pPrintPropertiesCollection);
#endif

#ifdef __cplusplus
}
#endif

#endif
#endif
