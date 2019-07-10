/*
 * upssvc.h
 *
 * UPS service interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __UPSSVC_H
#define __UPSSVC_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_APCUPS_)
#define UPSAPI
#else
#define UPSAPI DECLSPEC_IMPORT
#endif


#define UPS_ONLINE                        1
#define UPS_ONBATTERY                     2
#define UPS_LOWBATTERY                    4
#define UPS_NOCOMM                        8
#define UPS_CRITICAL                      16

UPSAPI
VOID
NTAPI
UPSCancelWait(VOID);

UPSAPI
DWORD
NTAPI
UPSGetState(VOID);

#define UPS_INITUNKNOWNERROR              0
#define UPS_INITOK                        1
#define UPS_INITNOSUCHDRIVER              2
#define UPS_INITBADINTERFACE              3
#define UPS_INITREGISTRYERROR             4
#define UPS_INITCOMMOPENERROR             5
#define UPS_INITCOMMSETUPERROR            6

UPSAPI
DWORD
NTAPI
UPSInit(VOID);

UPSAPI
VOID
NTAPI
UPSStop(VOID);

UPSAPI
VOID
NTAPI
UPSTurnOff(
  IN DWORD  aTurnOffDelay);

UPSAPI
VOID
NTAPI
UPSWaitForStateChange(
  IN DWORD  aCurrentState,
  IN DWORD  anInterval);

#ifdef __cplusplus
}
#endif

#endif /* __UPSSVC_H */
