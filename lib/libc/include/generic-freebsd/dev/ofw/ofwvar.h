/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2005 Peter Grehan
 * Copyright (c) 2008 Nathan Whitehorn
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _DEV_OFW_OFWVAR_H_
#define	_DEV_OFW_OFWVAR_H_

/*
 * An Open Firmware client implementation is declared with a kernel object and
 * an associated method table, similar to a device driver.
 *
 * e.g.
 *
 * static ofw_method_t fdt_methods[] = {
 *	OFWMETHOD(ofw_init,		fdt_init),
 *	OFWMETHOD(ofw_finddevice,	fdt_finddevice),
 *  ...
 *	OFWMETHOD(ofw_nextprop,		fdt_nextprop),
 *	{ 0, 0 }
 * };
 *
 * static ofw_def_t ofw_fdt = {
 *	"ofw_fdt",
 *	fdt_methods,
 *	sizeof(fdt_softc),	// or 0 if no softc
 * };
 *
 * OFW_DEF(ofw_fdt);
 */

#include <sys/kobj.h>

struct ofw_kobj {
	/*
	 * An OFW instance is a kernel object.
	 */
	KOBJ_FIELDS;

	/*
	 * Utility elements that an instance may use
	 */
	struct mtx	ofw_mtx;	/* available for instance use */
	void		*ofw_iptr;	/* instance data pointer */

	/*
	 * Opaque data that can be overlaid with an instance-private
	 * structure.  OFW code can test that this is large enough at
	 * compile time with a sizeof() test againt it's softc.  There
	 * is also a run-time test when the MMU kernel object is
	 * registered.
	 */
#define	OFW_OPAQUESZ	64
	u_int		ofw_opaque[OFW_OPAQUESZ];
};

typedef struct ofw_kobj		*ofw_t;
typedef struct kobj_class	ofw_def_t;

#define	ofw_method_t	kobj_method_t
#define	OFWMETHOD	KOBJMETHOD

#define	OFW_DEF(name)	DATA_SET(ofw_set, name)

#endif /* _DEV_OFW_OFWVAR_H_ */