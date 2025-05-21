/*        $NetBSD: netbsd-dm.h,v 1.10 2019/12/06 16:46:14 tkusumi Exp $      */

/*
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Adam Hamsik.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __NETBSD_DM_H__
#define __NETBSD_DM_H__

#include <sys/ioccom.h>
#include <prop/proplib.h>

#define DM_IOCTL 0xfd

#define DM_IOCTL_CMD 0

#define NETBSD_DM_IOCTL       _IOWR(DM_IOCTL, DM_IOCTL_CMD, struct plistref)


/*
 * DM-ioctl dictionary.
 *
 * This contains general information about dm device.
 *
 * <dict>
 *     <key>command</key>
 *     <string>...</string>
 *
 *     <key>event_nr</key>
 *     <integer>...</integer>
 *
 *     <key>name</key>
 *     <string>...</string>
 *
 *     <key>uuid</key>
 *     <string>...</string>
 *
 *     <key>dev</key>
 *     <integer></integer>
 *
 *     <key>flags</key>
 *     <integer></integer>
 *
 *     <key>version</key>
 *      <array>
 *       <integer>...</integer>
 *       <integer>...</integer>
 *       <integer>...</integer>
 *      </array>
 *
 *      <key>cmd_data</key>
 *       <array>
 *        <!-- See below for command
 *             specific dictionaries -->
 *       </array>
 * </dict>
 *
 * Available commands from _cmd_data_v4.
 *
 * create, reload, remove, remove_all, suspend,
 * resume, info, deps, rename, version, status,
 * table, waitevent, names, clear, mknodes,
 * targets, message, setgeometry
 *
 */

/*
 * DM_LIST_VERSIONS == "targets" command dictionary entry.
 * Lists all available targets with their version.
 *
 * <array>
 *   <dict>
 *    <key>name<key>
 *    <string>...</string>
 *
 *    <key>version</key>
 *      <array>
 *       <integer>...</integer>
 *       <integer>...</integer>
 *       <integer>...</integer>
 *      </array>
 *   </dict>
 * </array>
 *
 */

/*
 * DM_DEV_LIST == "names"
 * Request list of device-mapper created devices from kernel.
 *
 * <array>
 *   <dict>
 *    <key>name<key>
 *    <string>...</string>
 *
 *    <key>dev</key>
 *    <integer>...</integer>
 *   </dict>
 * </array>
 *
 * dev is uint64_t
 *
 */

 /*
  * DM_DEV_RENAME == "rename"
  * Rename device to string.
  *
  * <array>
  *    <string>...</string>
  * </array>
  *
  */

 /*
  * DM_DEV_STATUS == "info, mknodes"
  * Will change fields DM_IOCTL_OPEN, DM_IOCTL_DEV in received dictionary,
  * with dm device values with name or uuid from list.
  *
  */

 /*
  * DM_TABLE_STATUS == "status,table"
  * Request list of device-mapper created devices from kernel.
  *
  * <array>
  *   <dict>
  *    <key>type<key>
  *    <string>...</string>
  *
  *    <key>start</key>
  *    <integer>...</integer>
  *
  *    <key>length</key>
  *    <integer>...</integer>
  *
  *    <key>params</key>
  *    <string>...</string>
  *   </dict>
  * </array>
  *
  * params is string which contains {device} {parameters}
  *
  */

 /*
  * DM_TABLE_DEPS == "deps"
  * Request list active table device dependencies.
  *
  * This command is also run to get dm-device
  * dependencies for existing real block device.
  *
  * eg. vgcreate calls DM_TABLE_DEPS
  *
  * <array>
  *   <integer>...</integer>
  * </array>
  *
  */


#define DM_IOCTL_COMMAND      "command"
#define DM_IOCTL_VERSION      "version"
#define DM_IOCTL_OPEN         "open_count"
#define DM_IOCTL_MINOR        "minor"
#define DM_IOCTL_NAME         "name"
#define DM_IOCTL_UUID         "uuid"
#define DM_IOCTL_TARGET_COUNT "target_count"
#define DM_IOCTL_EVENT        "event_nr"
#define DM_IOCTL_FLAGS        "flags"
#define DM_IOCTL_CMD_DATA     "cmd_data"

#define DM_TARGETS_NAME       "name"
#define DM_TARGETS_VERSION    "ver"

#define DM_DEV_NEWNAME        "newname"
#define DM_DEV_NAME           "name"
#define DM_DEV_DEV            "dev"

#define DM_TABLE_TYPE         "type"
#define DM_TABLE_START        "start"
#define DM_TABLE_STAT         "status"
#define DM_TABLE_LENGTH       "length"
#define DM_TABLE_PARAMS       "params"
//#ifndef __LIB_DEVMAPPER__
//#define DM_TABLE_DEPS         "deps"
//#endif

/* Status bits */
/* IO mode of device */
#define DM_READONLY_FLAG	(1 << 0) /* In/Out *//* to kernel/from kernel */
#define DM_SUSPEND_FLAG		(1 << 1) /* In/Out */
/* XXX. This flag is undocumented. */
#define DM_EXISTS_FLAG          (1 << 2) /* In/Out */
/* Minor number is persistent */
#define DM_PERSISTENT_DEV_FLAG	(1 << 3) /* In */

/*
 * Flag passed into ioctl STATUS command to get table information
 * rather than current status.
 */
#define DM_STATUS_TABLE_FLAG	(1 << 4) /* In */

/*
 * Flags that indicate whether a table is present in either of
 * the two table slots that a device has.
 */
#define DM_ACTIVE_PRESENT_FLAG   (1 << 5) /* Out */
#define DM_INACTIVE_PRESENT_FLAG (1 << 6) /* Out */

/*
 * Indicates that the buffer passed in wasn't big enough for the
 * results.
 */
#define DM_BUFFER_FULL_FLAG	(1 << 8) /* Out */

/*
 * This flag is now ignored.
 */
#define DM_SKIP_BDGET_FLAG	(1 << 9) /* In */

/*
 * Set this to avoid attempting to freeze any filesystem when suspending.
 */
#define DM_SKIP_LOCKFS_FLAG	(1 << 10) /* In */

/*
 * Set this to suspend without flushing queued ios.
 */
#define DM_NOFLUSH_FLAG		(1 << 11) /* In */

/*
 * If set, any table information returned will relate to the inactive
 * table instead of the live one.  Always check DM_INACTIVE_PRESENT_FLAG
 * is set before using the data returned.
 */
#define DM_QUERY_INACTIVE_TABLE_FLAG    (1 << 12) /* In */

#endif /* __NETBSD_DM_H__ */