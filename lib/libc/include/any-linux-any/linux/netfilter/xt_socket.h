/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_SOCKET_H
#define _XT_SOCKET_H

#include <linux/types.h>

enum {
	XT_SOCKET_TRANSPARENT = 1 << 0,
	XT_SOCKET_NOWILDCARD = 1 << 1,
	XT_SOCKET_RESTORESKMARK = 1 << 2,
};

struct xt_socket_mtinfo1 {
	__u8 flags;
};
#define XT_SOCKET_FLAGS_V1 XT_SOCKET_TRANSPARENT

struct xt_socket_mtinfo2 {
	__u8 flags;
};
#define XT_SOCKET_FLAGS_V2 (XT_SOCKET_TRANSPARENT | XT_SOCKET_NOWILDCARD)

struct xt_socket_mtinfo3 {
	__u8 flags;
};
#define XT_SOCKET_FLAGS_V3 (XT_SOCKET_TRANSPARENT \
			   | XT_SOCKET_NOWILDCARD \
			   | XT_SOCKET_RESTORESKMARK)

#endif /* _XT_SOCKET_H */