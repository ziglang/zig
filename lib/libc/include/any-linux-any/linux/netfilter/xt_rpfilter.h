/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_RPATH_H
#define _XT_RPATH_H

#include <linux/types.h>

enum {
	XT_RPFILTER_LOOSE = 1 << 0,
	XT_RPFILTER_VALID_MARK = 1 << 1,
	XT_RPFILTER_ACCEPT_LOCAL = 1 << 2,
	XT_RPFILTER_INVERT = 1 << 3,
};

struct xt_rpfilter_info {
	__u8 flags;
};

#endif