/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WSDAPI
#define _INC_WSDAPI
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef struct IWSDAsyncResult IWSDAsyncResult;
typedef struct IWSDServiceProxy IWSDServiceProxy;
typedef struct IWSDEndpointProxy IWSDEndpointProxy;

typedef struct IWSDMessageParameters IWSDMessageParameters;
typedef struct IWSDServiceMessaging IWSDServiceMessaging;

typedef struct _WSD_EVENT WSD_EVENT;
typedef struct _WSD_SOAP_FAULT_SUBCODE WSD_SOAP_FAULT_SUBCODE;
typedef struct _WSD_LOCALIZED_STRING_LIST WSD_LOCALIZED_STRING_LIST;
typedef struct _WSD_URI_LIST WSD_URI_LIST;
typedef struct _WSD_NAME_LIST WSD_NAME_LIST;
typedef struct _WSD_SERVICE_METADATA_LIST WSD_SERVICE_METADATA_LIST;
typedef struct _WSD_PROBE_MATCH_LIST WSD_PROBE_MATCH_LIST;

typedef struct _WSDXML_NAME WSDXML_NAME;
typedef struct _WSDXML_ELEMENT WSDXML_ELEMENT;
typedef struct _WSDXML_NODE WSDXML_NODE;
typedef struct _WSDXML_ATTRIBUTE WSDXML_ATTRIBUTE;
typedef struct _WSDXML_PREFIX_MAPPING WSDXML_PREFIX_MAPPING;
typedef struct _WSDXML_ELEMENT_LIST WSDXML_ELEMENT_LIST;
typedef struct _WSDXML_TYPE WSDXML_TYPE;
typedef struct _WSD_METADATA_SECTION_LIST WSD_METADATA_SECTION_LIST;
typedef struct _WSD_METADATA_SECTION WSD_METADATA_SECTION;
typedef struct _WSD_ENDPOINT_REFERENCE_LIST WSD_ENDPOINT_REFERENCE_LIST;

#ifdef __cplusplus
}
#endif

#include <wsdtypes.h>
#include <wsdbase.h>
#include <wsdxmldom.h>
#include <wsdxml.h>
#include <wsdhost.h>
#include <wsdutil.h>
#include <wsdclient.h>
#include <wsddisco.h>
#include <wsdattachment.h>

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WSDAPI*/
