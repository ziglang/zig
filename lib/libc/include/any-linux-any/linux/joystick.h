/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
/*
 *  Copyright (C) 1996-2000 Vojtech Pavlik
 *
 *  Sponsored by SuSE
 */
/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or 
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */
#ifndef _LINUX_JOYSTICK_H
#define _LINUX_JOYSTICK_H



#include <linux/types.h>
#include <linux/input.h>

/*
 * Version
 */

#define JS_VERSION		0x020100

/*
 * Types and constants for reading from /dev/js
 */

#define JS_EVENT_BUTTON		0x01	/* button pressed/released */
#define JS_EVENT_AXIS		0x02	/* joystick moved */
#define JS_EVENT_INIT		0x80	/* initial state of device */

struct js_event {
	__u32 time;	/* event timestamp in milliseconds */
	__s16 value;	/* value */
	__u8 type;	/* event type */
	__u8 number;	/* axis/button number */
};

/*
 * IOCTL commands for joystick driver
 */

#define JSIOCGVERSION		_IOR('j', 0x01, __u32)				/* get driver version */

#define JSIOCGAXES		_IOR('j', 0x11, __u8)				/* get number of axes */
#define JSIOCGBUTTONS		_IOR('j', 0x12, __u8)				/* get number of buttons */
#define JSIOCGNAME(len)		_IOC(_IOC_READ, 'j', 0x13, len)			/* get identifier string */

#define JSIOCSCORR		_IOW('j', 0x21, struct js_corr)			/* set correction values */
#define JSIOCGCORR		_IOR('j', 0x22, struct js_corr)			/* get correction values */

#define JSIOCSAXMAP		_IOW('j', 0x31, __u8[ABS_CNT])			/* set axis mapping */
#define JSIOCGAXMAP		_IOR('j', 0x32, __u8[ABS_CNT])			/* get axis mapping */
#define JSIOCSBTNMAP		_IOW('j', 0x33, __u16[KEY_MAX - BTN_MISC + 1])	/* set button mapping */
#define JSIOCGBTNMAP		_IOR('j', 0x34, __u16[KEY_MAX - BTN_MISC + 1])	/* get button mapping */

/*
 * Types and constants for get/set correction
 */

#define JS_CORR_NONE		0x00	/* returns raw values */
#define JS_CORR_BROKEN		0x01	/* broken line */

struct js_corr {
	__s32 coef[8];
	__s16 prec;
	__u16 type;
};

/*
 * v0.x compatibility definitions
 */

#define JS_RETURN		sizeof(struct JS_DATA_TYPE)
#define JS_TRUE			1
#define JS_FALSE		0
#define JS_X_0			0x01
#define JS_Y_0			0x02
#define JS_X_1			0x04
#define JS_Y_1			0x08
#define JS_MAX			2

#define JS_DEF_TIMEOUT		0x1300
#define JS_DEF_CORR		0
#define JS_DEF_TIMELIMIT	10L

#define JS_SET_CAL		1
#define JS_GET_CAL		2
#define JS_SET_TIMEOUT		3
#define JS_GET_TIMEOUT		4
#define JS_SET_TIMELIMIT	5
#define JS_GET_TIMELIMIT	6
#define JS_GET_ALL		7
#define JS_SET_ALL		8

struct JS_DATA_TYPE {
	__s32 buttons;
	__s32 x;
	__s32 y;
};

struct JS_DATA_SAVE_TYPE_32 {
	__s32 JS_TIMEOUT;
	__s32 BUSY;
	__s32 JS_EXPIRETIME;
	__s32 JS_TIMELIMIT;
	struct JS_DATA_TYPE JS_SAVE;
	struct JS_DATA_TYPE JS_CORR;
};

struct JS_DATA_SAVE_TYPE_64 {
	__s32 JS_TIMEOUT;
	__s32 BUSY;
	__s64 JS_EXPIRETIME;
	__s64 JS_TIMELIMIT;
	struct JS_DATA_TYPE JS_SAVE;
	struct JS_DATA_TYPE JS_CORR;
};


#endif /* _LINUX_JOYSTICK_H */