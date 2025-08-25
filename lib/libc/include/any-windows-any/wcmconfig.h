/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WCMCONFIG
#define _INC_WCMCONFIG
#if (_WIN32_WINNT >= 0x0600)

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0013 {
  dataTypeByte = 1,
  dataTypeSByte = 2,
  dataTypeUInt16 = 3,
  dataTypeInt16 = 4,
  dataTypeUInt32 = 5,
  dataTypeInt32 = 6,
  dataTypeUInt64 = 7,
  dataTypeInt64 = 8,
  dataTypeBoolean = 11,
  dataTypeString = 12,
  dataTypeFlagArray = 0x8000
} WcmDataType;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0020 {
  ReadOnlyAccess = 1,
  ReadWriteAccess = 2
} WcmNamespaceAccess;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0003 {
  SharedEnumeration = 1,
  UserEnumeration = 2,
  AllEnumeration = ( SharedEnumeration | UserEnumeration )
} WcmNamespaceEnumerationFlags;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0016 {
  restrictionFacetMaxLength = 0x1,
  restrictionFacetEnumeration = 0x2,
  restrictionFacetMaxInclusive = 0x4,
  restrictionFacetMinInclusive = 0x8
} WcmRestrictionFacets;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0014 {
  settingTypeScalar = 1,
  settingTypeComplex = 2,
  settingTypeList = 3
} WcmSettingType;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0002 {
  OfflineMode = 1,
  OnlineMode = 2
} WcmTargetMode;

typedef enum __MIDL___MIDL_itf_wcmconfig_0000_0000_0019 {
  UnknownStatus = 0,
  UserRegistered = 1,
  UserUnregistered = 2,
  UserLoaded = 3,
  UserUnloaded = 4
} WcmUserStatus;

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WCMCONFIG*/
