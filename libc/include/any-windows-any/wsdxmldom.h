/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef __WSDXMLDOM_H__
#define __WSDXMLDOM_H__

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

typedef struct _WSDXML_TYPE {
  const WCHAR *Uri;
  const BYTE *Table;
} WSDXML_TYPE;

typedef struct _WSDXML_NAMESPACE {
  const WCHAR *Uri;
  const WCHAR *PreferredPrefix;
  struct _WSDXML_NAME *Names;
  WORD NamesCount;
  WORD Encoding;
} WSDXML_NAMESPACE;

typedef struct _WSDXML_NAME {
  WSDXML_NAMESPACE *Space;
  WCHAR *LocalName;
} WSDXML_NAME;

typedef struct _WSDXML_PREFIX_MAPPING {
  DWORD Refs;
  struct _WSDXML_PREFIX_MAPPING *Next;
  WSDXML_NAMESPACE *Space;
  WCHAR *Prefix;
} WSDXML_PREFIX_MAPPING;

typedef struct _WSDXML_ATTRIBUTE {
  struct _WSDXML_ELEMENT *Element;
  struct _WSDXML_ATTRIBUTE *Next;
  WSDXML_NAME *Name;
  WCHAR *Value;
} WSDXML_ATTRIBUTE;

typedef struct _WSDXML_NODE {
  enum {
    ElementType,
    TextType
  } Type;
  struct _WSDXML_ELEMENT *Parent;
  struct _WSDXML_NODE *Next;
} WSDXML_NODE;

typedef struct _WSDXML_ELEMENT {
  WSDXML_NODE Node;
  WSDXML_NAME *Name;
  WSDXML_ATTRIBUTE *FirstAttribute;
  WSDXML_NODE *FirstChild;
  WSDXML_PREFIX_MAPPING *PrefixMappings;
} WSDXML_ELEMENT;

typedef struct _WSDXML_TEXT {
  WSDXML_NODE Node;
  WCHAR *Text;
} WSDXML_TEXT;

typedef struct _WSDXML_ELEMENT_LIST {
  struct _WSDXML_ELEMENT_LIST *Next;
  WSDXML_ELEMENT *Element;
} WSDXML_ELEMENT_LIST;

#endif
#endif
