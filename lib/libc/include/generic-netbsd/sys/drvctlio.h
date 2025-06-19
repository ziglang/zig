/* $NetBSD: drvctlio.h,v 1.7 2008/05/31 13:24:57 freza Exp $ */

/*-
 * Copyright (c) 2006 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

/* This interface is experimental and may change. */

#ifndef _SYS_DRVCTLIO_H_ 
#define _SYS_DRVCTLIO_H_ 

#include <prop/proplib.h>
#include <sys/ioccom.h>

#define DRVCTLDEV "/dev/drvctl"

struct devdetachargs {
	char devname[16];
};

struct devlistargs {
	char l_devname[16];
	char (*l_childname)[16];
	size_t l_children;
};

enum devpmflags {
	DEVPM_F_SUBTREE = 0x1
};

struct devpmargs {
	char devname[16];
	uint32_t flags;
};

struct devrescanargs {
	char busname[16];
	char ifattr[16];
	unsigned int numlocators;
	int *locators;
};

#define DRVDETACHDEV _IOW('D', 123, struct devdetachargs)
#define DRVRESCANBUS _IOW('D', 124, struct devrescanargs)
#define	DRVCTLCOMMAND _IOWR('D', 125, struct plistref)
#define DRVRESUMEDEV _IOW('D', 126, struct devpmargs)
#define DRVLISTDEV _IOWR('D', 127, struct devlistargs)
#define DRVGETEVENT _IOR('D', 128, struct plistref)
#define DRVSUSPENDDEV _IOW('D', 129, struct devpmargs)

/*
 * DRVCTLCOMMAND documentation
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *
 * Generic ioctl that takes a dictionary as an argument (specifies the
 * command and arguments) and returns a dictionary with the results.
 *
 * Command arguments are structured like so:
 *
 * <dict>
 *	<key>drvctl-command</key>
 *	<string>...</string>
 *	<!-- optional arguments -->
 *	<key>drvctl-arguments</key>
 *	<dict>
 *		<!-- arguments vary with command -->
 *	</dict>
 * </dict>
 *
 * Results are returned like so:
 *
 * <dict>
 *	<key>drvctl-error</key>
 *	<!-- 0 == success, otherwise an errno value -->
 *	<integer>...</integer>
 *	<!-- optional additional error message -->
 *	<key>drvctl-error-message</key>
 *	<string>...</string>
 *	<!-- optional results dictionary -->
 *	<key>drvctl-result-data</key>
 *	<dict>
 *		<!-- results vary with command -->
 *	</dict>
 * </dict>
 *
 *
 * Commands recognized by DRVCTLCOMMAND
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *
 * get-properties
 *
 * Arguments:
 *
 *	<dict>
 *		<key>device-name</key>
 *		<string>...</string>
 *	</dict>
 *
 * Results:
 *	<dict>
 *		<!-- contents of device's properties dictionary -->
 *	</dict>
 */

#endif /* _SYS_DRVCTLIO_H_ */