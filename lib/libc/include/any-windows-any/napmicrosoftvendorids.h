/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef NAPMICROSOFTVENDORIDS_H
#define NAPMICROSOFTVENDORIDS_H

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifdef __cplusplus
extern "C" {
#endif

  __MINGW_ATTRIB_UNUSED static UINT32 MicrosoftVendorId = 0x137;
  __MINGW_ATTRIB_UNUSED static UINT32 NapSystemId = 0x00013700;
  __MINGW_ATTRIB_UNUSED static UINT32 NapDhcpEnforcementId = 0x00013701;
  __MINGW_ATTRIB_UNUSED static UINT32 NapRasEnforcementId = 0x00013702;
  __MINGW_ATTRIB_UNUSED static UINT32 NapIpsecEnforcementId = 0x00013703;
  __MINGW_ATTRIB_UNUSED static UINT32 Nap8021xEnforcementId = 0x00013704;
  __MINGW_ATTRIB_UNUSED static UINT32 NapAnywhereAccessEnforcementId = 0x00013705;
  __MINGW_ATTRIB_UNUSED static UINT32 NapIsaEnforcementId = 0x00013706;
  __MINGW_ATTRIB_UNUSED static UINT32 NapEapEnforcementId = 0x00013707;
  __MINGW_ATTRIB_UNUSED static UINT32 NapOutOfBoxSystemHealthId = 0x00013780;
  __MINGW_ATTRIB_UNUSED static UINT32 NapSmsSystemHealthId = 0x00013781;
  __MINGW_ATTRIB_UNUSED static UINT32 NapFCSv1SystemHealthId = 0x00013782;
  __MINGW_ATTRIB_UNUSED static UINT32 NapFCSv2SystemHealthId = 0x00013783;
  __MINGW_ATTRIB_UNUSED static UINT32 NapTpmSystemHealthId = 0x00013784;

#ifdef __cplusplus
}
#endif
#endif

#endif
