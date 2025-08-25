/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TDH
#define _INC_TDH
#include <evntprov.h>
#include <evntcons.h>
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _EVENT_FIELD_TYPE {
  EventKeywordInformation   = 0,
  EventLevelInformation     = 1,
  EventChannelInformation   = 2,
  EventTaskInformation      = 3,
  EventOpcodeInformation    = 4,
  EventInformationMax       = 5 
} EVENT_FIELD_TYPE;

typedef struct _EVENT_MAP_ENTRY {
  ULONG OutputOffset;
  __C89_NAMELESS union {
    ULONG Value;
    ULONG InputOffset;
  };
} EVENT_MAP_ENTRY, *PEVENT_MAP_ENTRY;

typedef enum _MAP_VALUETYPE
{
  EVENTMAP_ENTRY_VALUETYPE_ULONG  = 0,
  EVENTMAP_ENTRY_VALUETYPE_STRING = 1 
} MAP_VALUETYPE;

typedef enum _MAP_FLAGS {
  EVENTMAP_INFO_FLAG_MANIFEST_VALUEMAP     = 1,
  EVENTMAP_INFO_FLAG_MANIFEST_BITMAP       = 2,
  EVENTMAP_INFO_FLAG_MANIFEST_PATTERNMAP   = 4,
  EVENTMAP_INFO_FLAG_WBEM_VALUEMAP         = 8,
  EVENTMAP_INFO_FLAG_WBEM_BITMAP           = 16,
  EVENTMAP_INFO_FLAG_WBEM_FLAG             = 32,
  EVENTMAP_INFO_FLAG_WBEM_NO_MAP           = 64 
} MAP_FLAGS;

typedef struct _EVENT_MAP_INFO {
  ULONG NameOffset;
  MAP_FLAGS Flag;
  ULONG EntryCount;
  __C89_NAMELESS union {
    MAP_VALUETYPE MapEntryValueType;
    ULONG FormatStringOffset;
  };
  EVENT_MAP_ENTRY MapEntryArray[ANYSIZE_ARRAY];
} EVENT_MAP_INFO, *PEVENT_MAP_INFO;

typedef enum _PROPERTY_FLAGS {
  PropertyStruct             = 0x1,
  PropertyParamLength        = 0x2,
  PropertyParamCount         = 0x4,
  PropertyWBEMXmlFragment    = 0x8,
  PropertyParamFixedLength   = 0x10 
} PROPERTY_FLAGS;

typedef struct _EVENT_PROPERTY_INFO {
  PROPERTY_FLAGS Flags;
  ULONG          NameOffset;
  __C89_NAMELESS union {
    struct {
      USHORT InType;
      USHORT OutType;
      ULONG  MapNameOffset;
    } nonStructType;
    struct {
      USHORT StructStartIndex;
      USHORT NumOfStructMembers;
      ULONG  padding;
    } structType;
  };
  __C89_NAMELESS union {
    USHORT count;
    USHORT countPropertyIndex;
  };
  __C89_NAMELESS union {
    USHORT length;
    USHORT lengthPropertyIndex;
  };
  ULONG          Reserved;
} EVENT_PROPERTY_INFO;

typedef enum _DECODING_SOURCE {
  DecodingSourceXMLFile   = 0,
  DecodingSourceWbem      = 1,
  DecodingSourceWPP       = 2 
} DECODING_SOURCE;

typedef enum _TDH_CONTEXT_TYPE {
  TDH_CONTEXT_WPP_TMFFILE         = 0,
  TDH_CONTEXT_WPP_TMFSEARCHPATH   = 1,
  TDH_CONTEXT_WPP_GMT             = 2,
  TDH_CONTEXT_POINTERSIZE         = 3,
  TDH_CONTEXT_MAXIMUM             = 4 
} TDH_CONTEXT_TYPE;

typedef enum _TEMPLATE_FLAGS {
  TEMPLATE_EVENT_DATA   = 1,
  TEMPLATE_USER_DATA    = 2 
} TEMPLATE_FLAGS;

typedef struct _TRACE_EVENT_INFO {
  GUID                ProviderGuid;
  GUID                EventGuid;
  EVENT_DESCRIPTOR    EventDescriptor;
  DECODING_SOURCE     DecodingSource;
  ULONG               ProviderNameOffset;
  ULONG               LevelNameOffset;
  ULONG               ChannelNameOffset;
  ULONG               KeywordsNameOffset;
  ULONG               TaskNameOffset;
  ULONG               OpcodeNameOffset;
  ULONG               EventMessageOffset;
  ULONG               ProviderMessageOffset;
  ULONG               BinaryXMLOffset;
  ULONG               BinaryXMLSize;
  ULONG               ActivityIDNameOffset;
  ULONG               RelatedActivityIDNameOffset;
  ULONG               PropertyCount;
  ULONG               TopLevelPropertyCount;
  TEMPLATE_FLAGS      Flags;
  EVENT_PROPERTY_INFO EventPropertyInfoArray[ANYSIZE_ARRAY];
} TRACE_EVENT_INFO, *PTRACE_EVENT_INFO;

typedef struct _PROPERTY_DATA_DESCRIPTOR {
  ULONGLONG PropertyName;
  ULONG     ArrayIndex;
  ULONG     Reserved;
} PROPERTY_DATA_DESCRIPTOR, *PPROPERTY_DATA_DESCRIPTOR;

typedef struct _TRACE_PROVIDER_INFO {
  GUID  ProviderGuid;
  ULONG SchemaSource;
  ULONG ProviderNameOffset;
} TRACE_PROVIDER_INFO;

typedef struct _PROVIDER_ENUMERATION_INFO {
  ULONG               NumberOfProviders;
  ULONG               Padding;
  TRACE_PROVIDER_INFO TraceProviderInfoArray[ANYSIZE_ARRAY];
} PROVIDER_ENUMERATION_INFO, *PPROVIDER_ENUMERATION_INFO;

typedef struct _PROVIDER_FIELD_INFO {
  ULONG     NameOffset;
  ULONG     DescriptionOffset;
  ULONGLONG Value;
} PROVIDER_FIELD_INFO;

typedef struct _PROVIDER_FIELD_INFOARRAY {
  ULONG               NumberOfElements;
  EVENT_FIELD_TYPE    FieldType;
  PROVIDER_FIELD_INFO FieldInfoArray[ANYSIZE_ARRAY];
} PROVIDER_FIELD_INFOARRAY, *PPROVIDER_FIELD_INFOARRAY;

typedef struct _TDH_CONTEXT {
  ULONGLONG        ParameterValue;
  TDH_CONTEXT_TYPE ParameterType;
  ULONG            ParameterSize;
} TDH_CONTEXT, *PTDH_CONTEXT;

ULONG __stdcall TdhEnumerateProviderFieldInformation(
  LPGUID pGuid,
  EVENT_FIELD_TYPE EventFieldType,
  PPROVIDER_FIELD_INFOARRAY pBuffer,
  ULONG *pBufferSize
);

ULONG __stdcall TdhEnumerateProviders(
  PPROVIDER_ENUMERATION_INFO pBuffer,
  ULONG *pBufferSize
);

ULONG __stdcall TdhGetEventInformation(
  PEVENT_RECORD pEvent,
  ULONG TdhContextCount,
  PTDH_CONTEXT pTdhContext,
  PTRACE_EVENT_INFO pBuffer,
  ULONG *pBufferSize
);

ULONG __stdcall TdhGetEventMapInformation(
  PEVENT_RECORD pEvent,
  LPWSTR pMapName,
  PEVENT_MAP_INFO pBuffer,
  ULONG *pBufferSize
);

ULONG __stdcall TdhGetProperty(
  PEVENT_RECORD pEvent,
  ULONG TdhContextCount,
  PTDH_CONTEXT pTdhContext,
  ULONG PropertyDataCount,
  PPROPERTY_DATA_DESCRIPTOR pPropertyData,
  ULONG BufferSize,
  PBYTE pBuffer
);

ULONG __stdcall TdhGetPropertySize(
  PEVENT_RECORD pEvent,
  ULONG TdhContextCount,
  PTDH_CONTEXT pTdhContext,
  ULONG PropertyDataCount,
  PPROPERTY_DATA_DESCRIPTOR pPropertyData,
  ULONG *pPropertySize
);

ULONG __stdcall TdhQueryProviderFieldInformation(
  LPGUID pGuid,
  ULONGLONG EventFieldValue,
  EVENT_FIELD_TYPE EventFieldType,
  PPROVIDER_FIELD_INFOARRAY pBuffer,
  ULONG *pBufferSize
);

#if (_WIN32_WINNT >= 0x0601)
typedef struct _PROVIDER_FILTER_INFO {
  UCHAR               Id;
  UCHAR               Version;
  ULONG               MessageOffset;
  ULONG               Reserved;
  ULONG               PropertyCount;
  EVENT_PROPERTY_INFO EventPropertyInfoArray[ANYSIZE_ARRAY];
} PROVIDER_FILTER_INFO, *PPROVIDER_FILTER_INFO;
#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_TDH*/
