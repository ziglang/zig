/*	$NetBSD: pciio.h,v 1.5 2016/09/24 23:12:54 mrg Exp $	*/

/*
 * Copyright 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DEV_PCI_PCIIO_H_
#define	_DEV_PCI_PCIIO_H_

/*
 * User -> kernel interface for PCI bus access.
 */

#include <sys/ioccom.h>

/*
 * pciio_cfgreg:
 *
 *	Representation of a PCI config space register.
 */
struct pciio_cfgreg {
	u_int	 reg;	/* offset into PCI configuration space */
	uint32_t val;	/* value of the register */
};

/*
 * Read and write PCI configuration space registers on a
 * specific device.
 */
#define	PCI_IOC_CFGREAD		_IOWR('P', 0, struct pciio_cfgreg)
#define	PCI_IOC_CFGWRITE	 _IOW('P', 1, struct pciio_cfgreg)

/*
 * pciio_bdf_cfgreg:
 *
 *	Like pciio_cfgreg, except for any bus/dev/func within
 *	a given PCI domain.
 */
struct pciio_bdf_cfgreg {
	u_int	bus;
	u_int	device;
	u_int	function;
	struct pciio_cfgreg cfgreg;
};

/*
 * Read and write PCI configuration space registers on any
 * device within a given PCI domain.
 */
#define	PCI_IOC_BDF_CFGREAD	_IOWR('P', 2, struct pciio_bdf_cfgreg)
#define	PCI_IOC_BDF_CFGWRITE	 _IOW('P', 3, struct pciio_bdf_cfgreg)

/*
 * pciio_businfo:
 *
 *	Information for a PCI bus (autoconfiguration node) instance.
 */
struct pciio_businfo {
	u_int	busno;		/* bus number */
	u_int	maxdevs;	/* max devices on bus */
};

#define	PCI_IOC_BUSINFO		 _IOR('P', 4, struct pciio_businfo)

/*
 * pciio_drvname:
 *
 *      Driver info for a PCI device (autoconfiguration node) instance.
 */

/* The old drvname must be run on the correct bus. */
#define PCI_IO_DRVNAME_LEN	16
struct pciio_drvname {
	u_int	device;				/* in: device number */
	u_int	function;			/* in: function number */
	char	name[PCI_IO_DRVNAME_LEN];
};
#define	PCI_IOC_DRVNAME		_IOWR('P', 5, struct pciio_drvname)

struct pciio_drvnameonbus {
	u_int	bus;				/* in: (autoconf) bus number */
	u_int	device;				/* in: device number */
	u_int	function;			/* in: function number */
	char	name[PCI_IO_DRVNAME_LEN];
};
#define	PCI_IOC_DRVNAMEONBUS	_IOWR('P', 5, struct pciio_drvnameonbus)


#endif /* _DEV_PCI_PCIIO_H_ */