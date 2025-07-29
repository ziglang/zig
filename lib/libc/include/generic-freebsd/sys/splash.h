/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 Beckhoff Automation GmbH & Co. KG
 *
 */

#ifndef _SYS_SPLASH_H_
#define	_SYS_SPLASH_H_

#include <sys/types.h>

struct splash_info {
	uint32_t si_width;
	uint32_t si_height;
	uint32_t si_depth;
};

#endif	/* _SYS_SPLASH_H_ */