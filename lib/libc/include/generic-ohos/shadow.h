#ifndef _SHADOW_H
#define _SHADOW_H

#ifdef __cplusplus
extern "C" {
#endif

#define	__NEED_FILE
#define __NEED_size_t

#include <bits/alltypes.h>

#define	SHADOW "/etc/shadow"

struct spwd {
	char *sp_namp;
	char *sp_pwdp;
	long sp_lstchg;
	long sp_min;
	long sp_max;
	long sp_warn;
	long sp_inact;
	long sp_expire;
	unsigned long sp_flag;
};

#ifdef __cplusplus
}
#endif

#endif
