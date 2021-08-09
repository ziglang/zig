/*
 * Copyright (c) 2000-2004, 2012-2016 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*!
 *       @header kern_control.h
 *       This header defines an API to communicate between a kernel
 *       extension and a process outside of the kernel.
 */

#ifndef KPI_KERN_CONTROL_H
#define KPI_KERN_CONTROL_H


#include <sys/appleapiopts.h>
#include <sys/_types/_u_char.h>
#include <sys/_types/_u_int16_t.h>
#include <sys/_types/_u_int32_t.h>

/*
 * Define Controller event subclass, and associated events.
 * Subclass of KEV_SYSTEM_CLASS
 */

/*!
 *       @defined KEV_CTL_SUBCLASS
 *   @discussion The kernel event subclass for kernel control events.
 */
#define KEV_CTL_SUBCLASS        2

/*!
 *       @defined KEV_CTL_REGISTERED
 *   @discussion The event code indicating a new controller was
 *       registered. The data portion will contain a ctl_event_data.
 */
#define KEV_CTL_REGISTERED      1       /* a new controller appears */

/*!
 *       @defined KEV_CTL_DEREGISTERED
 *   @discussion The event code indicating a controller was unregistered.
 *       The data portion will contain a ctl_event_data.
 */
#define KEV_CTL_DEREGISTERED    2       /* a controller disappears */

/*!
 *       @struct ctl_event_data
 *       @discussion This structure is used for KEV_CTL_SUBCLASS kernel
 *               events.
 *       @field ctl_id The kernel control id.
 *       @field ctl_unit The kernel control unit.
 */
struct ctl_event_data {
	u_int32_t   ctl_id;             /* Kernel Controller ID */
	u_int32_t   ctl_unit;
};

/*
 * Controls destined to the Controller Manager.
 */

/*!
 *       @defined CTLIOCGCOUNT
 *   @discussion The CTLIOCGCOUNT ioctl can be used to determine the
 *       number of kernel controllers registered.
 */
#define CTLIOCGCOUNT    _IOR('N', 2, int)               /* get number of control structures registered */

/*!
 *       @defined CTLIOCGINFO
 *   @discussion The CTLIOCGINFO ioctl can be used to convert a kernel
 *       control name to a kernel control id.
 */
#define CTLIOCGINFO     _IOWR('N', 3, struct ctl_info)  /* get id from name */


/*!
 *       @defined MAX_KCTL_NAME
 *   @discussion Kernel control names must be no longer than
 *       MAX_KCTL_NAME.
 */
#define MAX_KCTL_NAME   96

/*
 * Controls destined to the Controller Manager.
 */

/*!
 *       @struct ctl_info
 *       @discussion This structure is used with the CTLIOCGINFO ioctl to
 *               translate from a kernel control name to a control id.
 *       @field ctl_id The kernel control id, filled out upon return.
 *       @field ctl_name The kernel control name to find.
 */
struct ctl_info {
	u_int32_t   ctl_id;                             /* Kernel Controller ID  */
	char        ctl_name[MAX_KCTL_NAME];            /* Kernel Controller Name (a C string) */
};


/*!
 *       @struct sockaddr_ctl
 *       @discussion The controller address structure is used to establish
 *               contact between a user client and a kernel controller. The
 *               sc_id/sc_unit uniquely identify each controller. sc_id is a
 *               unique identifier assigned to the controller. The identifier can
 *               be assigned by the system at registration time or be a 32-bit
 *               creator code obtained from Apple Computer. sc_unit is a unit
 *               number for this sc_id, and is privately used by the kernel
 *               controller to identify several instances of the controller.
 *       @field sc_len The length of the structure.
 *       @field sc_family AF_SYSTEM.
 *       @field ss_sysaddr AF_SYS_KERNCONTROL.
 *       @field sc_id Controller unique identifier.
 *       @field sc_unit Kernel controller private unit number.
 *       @field sc_reserved Reserved, must be set to zero.
 */
struct sockaddr_ctl {
	u_char      sc_len;     /* depends on size of bundle ID string */
	u_char      sc_family;  /* AF_SYSTEM */
	u_int16_t   ss_sysaddr; /* AF_SYS_KERNCONTROL */
	u_int32_t   sc_id;      /* Controller unique identifier  */
	u_int32_t   sc_unit;    /* Developer private unit number */
	u_int32_t   sc_reserved[5];
};



#endif /* KPI_KERN_CONTROL_H */