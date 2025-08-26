/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_LED_H
#define _XT_LED_H

#include <linux/types.h>

struct xt_led_info {
	char id[27];        /* Unique ID for this trigger in the LED class */
	__u8 always_blink;  /* Blink even if the LED is already on */
	__u32 delay;        /* Delay until LED is switched off after trigger */

	/* Kernel data used in the module */
	void *internal_data __attribute__((aligned(8)));
};

#endif /* _XT_LED_H */