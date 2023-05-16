/*
 * Copyright (c) 2007 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef _OSTHERMALNOTIFICATION_H_
#define _OSTHERMALNOTIFICATION_H_

#include <sys/cdefs.h>
#include <Availability.h>

/*
**  OSThermalNotification.h
**  
**  Notification mechanism to alert registered tasks when device thermal conditions
**  reach certain thresholds. Notifications are triggered in both directions
**  so clients can manage their memory usage more and less aggressively.
**
*/

__BEGIN_DECLS

/* Define pressure levels usable by OSThermalPressureLevel */
typedef enum {
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
	kOSThermalPressureLevelNominal = 0,
	kOSThermalPressureLevelModerate,
	kOSThermalPressureLevelHeavy,
	kOSThermalPressureLevelTrapping,
	kOSThermalPressureLevelSleeping
#else
	kOSThermalPressureLevelNominal = 0,
	kOSThermalPressureLevelLight = 10,
	kOSThermalPressureLevelModerate = 20,
	kOSThermalPressureLevelHeavy = 30,
	kOSThermalPressureLevelTrapping = 40,
	kOSThermalPressureLevelSleeping = 50
#endif
} OSThermalPressureLevel;

/*
 ** External notify(3) string for thermal pressure level notification
 */
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_7_0)
extern const char * const kOSThermalNotificationPressureLevelName;


#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && \
	__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_2_0

typedef enum {
	OSThermalNotificationLevelAny      = -1,
	OSThermalNotificationLevelNormal   =  0,
} OSThermalNotificationLevel;

extern OSThermalNotificationLevel _OSThermalNotificationLevelForBehavior(int) __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_4_2);
extern void _OSThermalNotificationSetLevelForBehavior(int, int) __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_4_2);

enum {
	kOSThermalMitigationNone,
	kOSThermalMitigation70PercentTorch,
	kOSThermalMitigation70PercentBacklight,
	kOSThermalMitigation50PercentTorch,
	kOSThermalMitigation50PercentBacklight,
	kOSThermalMitigationDisableTorch,
	kOSThermalMitigation25PercentBacklight,
	kOSThermalMitigationDisableMapsHalo,
	kOSThermalMitigationAppTerminate,
	kOSThermalMitigationDeviceRestart,
	kOSThermalMitigationThermalTableReady,
	kOSThermalMitigationCount
};

#define OSThermalNotificationLevel70PercentTorch _OSThermalNotificationLevelForBehavior(kOSThermalMitigation70PercentTorch)
#define OSThermalNotificationLevel70PercentBacklight _OSThermalNotificationLevelForBehavior(kOSThermalMitigation70PercentBacklight)
#define OSThermalNotificationLevel50PercentTorch _OSThermalNotificationLevelForBehavior(kOSThermalMitigation50PercentTorch)
#define OSThermalNotificationLevel50PercentBacklight _OSThermalNotificationLevelForBehavior(kOSThermalMitigation50PercentBacklight)
#define OSThermalNotificationLevelDisableTorch _OSThermalNotificationLevelForBehavior(kOSThermalMitigationDisableTorch)
#define OSThermalNotificationLevel25PercentBacklight _OSThermalNotificationLevelForBehavior(kOSThermalMitigation25PercentBacklight)
#define OSThermalNotificationLevelDisableMapsHalo _OSThermalNotificationLevelForBehavior(kOSThermalMitigationDisableMapsHalo)
#define OSThermalNotificationLevelAppTerminate _OSThermalNotificationLevelForBehavior(kOSThermalMitigationAppTerminate)
#define OSThermalNotificationLevelDeviceRestart _OSThermalNotificationLevelForBehavior(kOSThermalMitigationDeviceRestart)

/* Backwards compatibility */
#define OSThermalNotificationLevelWarning OSThermalNotificationLevel70PercentBacklight
#define OSThermalNotificationLevelUrgent OSThermalNotificationLevelAppTerminate
#define OSThermalNotificationLevelCritical OSThermalNotificationLevelDeviceRestart

/*
** Simple polling interface to detect current thermal level
*/
__OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_2_0)
extern OSThermalNotificationLevel OSThermalNotificationCurrentLevel(void);

/*
** External notify(3) string for manual notification setup
*/
__OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_2_0)
extern const char * const kOSThermalNotificationName;

/*
** External notify(3) string for alerting user of a thermal condition
*/
__OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_6_0)
extern const char * const kOSThermalNotificationAlert;

/*
** External notify(3) string for notifying system the options taken to resolve thermal condition
*/
__OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_6_0)
extern const char * const kOSThermalNotificationDecision;

#endif // __IPHONE_OS_VERSION_MIN_REQUIRED

__END_DECLS

#endif /* _OSTHERMALNOTIFICATION_H_ */