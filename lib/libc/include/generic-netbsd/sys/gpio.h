/* $NetBSD: gpio.h,v 1.16 2018/05/19 13:59:06 thorpej Exp $ */
/*	$OpenBSD: gpio.h,v 1.7 2008/11/26 14:51:20 mbalmer Exp $	*/
/*
 * Copyright (c) 2009, 2011 Marc Balmer <marc@msys.ch>
 * Copyright (c) 2004 Alexander Yurchenko <grange@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _SYS_GPIO_H_
#define _SYS_GPIO_H_

#include <sys/ioccom.h>
#include <sys/time.h>

/* GPIO pin states */
#define GPIO_PIN_LOW		0x00	/* low level (logical 0) */
#define GPIO_PIN_HIGH		0x01	/* high level (logical 1) */

/* Max name length of a pin */
#define GPIOMAXNAME		64

/* GPIO pin configuration flags */
#define GPIO_PIN_INPUT		0x00000001	/* input direction */
#define GPIO_PIN_OUTPUT		0x00000002	/* output direction */
#define GPIO_PIN_INOUT		0x00000004	/* bi-directional */
#define GPIO_PIN_OPENDRAIN	0x00000008	/* open-drain output */
#define GPIO_PIN_PUSHPULL	0x00000010	/* push-pull output */
#define GPIO_PIN_TRISTATE	0x00000020	/* output disabled */
#define GPIO_PIN_PULLUP		0x00000040	/* internal pull-up enabled */
#define GPIO_PIN_PULLDOWN	0x00000080	/* internal pull-down enabled */
#define GPIO_PIN_INVIN		0x00000100	/* invert input */
#define GPIO_PIN_INVOUT		0x00000200	/* invert output */
#define GPIO_PIN_USER		0x00000400	/* user != 0 can access */
#define GPIO_PIN_PULSATE	0x00000800	/* pulsate in hardware */
#define GPIO_PIN_SET		0x00008000	/* set for securelevel access */
#define GPIO_PIN_ALT0		0x00010000	/* alternate function 0 */
#define GPIO_PIN_ALT1		0x00020000	/* alternate function 1 */
#define GPIO_PIN_ALT2		0x00040000	/* alternate function 2 */
#define GPIO_PIN_ALT3		0x00080000	/* alternate function 3 */
#define GPIO_PIN_ALT4		0x00100000	/* alternate function 4 */
#define GPIO_PIN_ALT5		0x00200000	/* alternate function 5 */
#define GPIO_PIN_ALT6		0x00400000	/* alternate function 6 */
#define GPIO_PIN_ALT7		0x00800000	/* alternate function 7 */

#define	GPIO_PIN_HWCAPS		(GPIO_PIN_INPUT | GPIO_PIN_OUTPUT | \
				 GPIO_PIN_INOUT | GPIO_PIN_OPENDRAIN | \
				 GPIO_PIN_PUSHPULL | GPIO_PIN_TRISTATE | \
				 GPIO_PIN_PULLUP | GPIO_PIN_PULLDOWN | \
				 GPIO_PIN_PULSATE | GPIO_PIN_ALT0 | \
				 GPIO_PIN_ALT1 | GPIO_PIN_ALT2 | \
				 GPIO_PIN_ALT3 | GPIO_PIN_ALT4 | \
				 GPIO_PIN_ALT5 | GPIO_PIN_ALT6 | \
				 GPIO_PIN_ALT7)

/* GPIO interrupt flags */
#define	GPIO_INTR_POS_EDGE	0x00000001	/* interrupt on rising edge */
#define	GPIO_INTR_NEG_EDGE	0x00000002	/* interrupt on falling edge */
#define	GPIO_INTR_DOUBLE_EDGE	0x00000004	/* interrupt on both edges */
#define	GPIO_INTR_HIGH_LEVEL	0x00000008	/* interrupt on high level */
#define	GPIO_INTR_LOW_LEVEL	0x00000010	/* interrupt on low level */
#define	GPIO_INTR_MPSAFE	0x80000000	/* MP-safe handling */

#define	GPIO_INTR_EDGE_MASK	(GPIO_INTR_POS_EDGE | \
				 GPIO_INTR_NEG_EDGE | \
				 GPIO_INTR_DOUBLE_EDGE)
#define	GPIO_INTR_LEVEL_MASK	(GPIO_INTR_HIGH_LEVEL | \
				 GPIO_INTR_LOW_LEVEL)
#define	GPIO_INTR_MODE_MASK	(GPIO_INTR_EDGE_MASK | \
				 GPIO_INTR_LEVEL_MASK)

/* GPIO controller description */
struct gpio_info {
	int gpio_npins;		/* total number of pins available */
};

/* GPIO pin request (read/write/toggle) */
struct gpio_req {
	char		gp_name[GPIOMAXNAME];	/* pin name */
	int		gp_pin;			/* pin number */
	int		gp_value;		/* value */
};

/* GPIO pin configuration */
struct gpio_set {
	char	gp_name[GPIOMAXNAME];
	int	gp_pin;
	int	gp_caps;
	int	gp_flags;
	char	gp_name2[GPIOMAXNAME];	/* new name */
};

/* Attach device drivers that use GPIO pins */
struct gpio_attach {
	char		ga_dvname[16];	/* device name */
	int		ga_offset;	/* pin number */
	uint32_t	ga_mask;	/* binary mask */
	uint32_t	ga_flags;	/* driver dependent flags */
};

/* gpio(4) API */
#define GPIOINFO		_IOR('G', 0, struct gpio_info)
#define GPIOSET			_IOWR('G', 5, struct gpio_set)
#define GPIOUNSET		_IOWR('G', 6, struct gpio_set)
#define GPIOREAD		_IOWR('G', 7, struct gpio_req)
#define GPIOWRITE		_IOWR('G', 8, struct gpio_req)
#define GPIOTOGGLE		_IOWR('G', 9, struct gpio_req)
#define GPIOATTACH		_IOWR('G', 10, struct gpio_attach)

#ifdef COMPAT_50
/* Old structure to attach/detach devices */
struct gpio_attach50 {
	char		ga_dvname[16];	/* device name */
	int		ga_offset;	/* pin number */
	uint32_t	ga_mask;	/* binary mask */
};

/* GPIO pin control (old API) */
struct gpio_pin_ctl {
	int gp_pin;		/* pin number */
	int gp_caps;		/* pin capabilities (read-only) */
	int gp_flags;		/* pin configuration flags */
};

/* GPIO pin operation (read/write/toggle) (old API) */
struct gpio_pin_op {
	int gp_pin;		/* pin number */
	int gp_value;		/* value */
};

/* the old API */
#define GPIOPINREAD		_IOWR('G', 1, struct gpio_pin_op)
#define GPIOPINWRITE		_IOWR('G', 2, struct gpio_pin_op)
#define GPIOPINTOGGLE		_IOWR('G', 3, struct gpio_pin_op)
#define GPIOPINCTL		_IOWR('G', 4, struct gpio_pin_ctl)
#define GPIOATTACH50		_IOWR('G', 10, struct gpio_attach50)
#define GPIODETACH50		_IOWR('G', 11, struct gpio_attach50)
#define GPIODETACH		_IOWR('G', 11, struct gpio_attach)
#endif	/* COMPAT_50 */

#endif	/* !_SYS_GPIO_H_ */