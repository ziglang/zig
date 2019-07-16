/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef BDAIFACE_ENUMS_H
#define BDAIFACE_ENUMS_H

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
  enum SmartCardStatusType {
  CardInserted = 0,
  CardRemoved,
  CardError,
  CardDataChanged,
  CardFirmwareUpgrade
} SmartCardStatusType;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
 enum SmartCardAssociationType {
  NotAssociated = 0,
  Associated,
  AssociationUnknown
} SmartCardAssociationType;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
 enum LocationCodeSchemeType {
  SCTE_18 = 0
} LocationCodeSchemeType;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
  enum EntitlementType {
  Entitled = 0,
  NotEntitled,
  TechnicalFailure
} EntitlementType;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
  enum UICloseReasonType {
  NotReady = 0,
  UserClosed,
  SystemClosed,
  DeviceClosed,
  ErrorClosed
} UICloseReasonType;

typedef
#ifdef __WIDL__
  [v1_enum]
#endif
  enum BDA_DrmPairingError {
  BDA_DrmPairing_Succeeded = 0,
  BDA_DrmPairing_HardwareFailure,
  BDA_DrmPairing_NeedRevocationData,
  BDA_DrmPairing_NeedIndiv,
  BDA_DrmPairing_Other,
  BDA_DrmPairing_DrmInitFailed,
  BDA_DrmPairing_DrmNotPaired,
  BDA_DrmPairing_DrmRePairSoon,
  BDA_DrmPairing_Aborted,
  BDA_DrmPairing_NeedSDKUpdate
} BDA_DrmPairingError;

typedef struct EALocationCodeType {
  LocationCodeSchemeType LocationCodeScheme;
  BYTE state_code;
  BYTE county_subdivision;
  WORD county_code;
} EALocationCodeType;

typedef struct SmartCardApplication {
  ApplicationTypeType ApplicationType;
  USHORT ApplicationVersion;
  BSTR pbstrApplicationName;
  BSTR pbstrApplicationURL;
} SmartCardApplication;

#endif
#endif
