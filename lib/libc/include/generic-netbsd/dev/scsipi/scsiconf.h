/*	$NetBSD: scsiconf.h,v 1.58 2012/04/20 20:23:21 bouyer Exp $	*/

/*-
 * Copyright (c) 1998, 1999, 2004 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum; by Jason R. Thorpe of the Numerical Aerospace
 * Simulation Facility, NASA Ames Research Center.
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

/*
 * Originally written by Julian Elischer (julian@tfs.com)
 * for TRW Financial Systems for use under the MACH(2.5) operating system.
 *
 * TRW Financial Systems, in accordance with their agreement with Carnegie
 * Mellon University, makes this software available to CMU to distribute
 * or use in any manner that they see fit as long as this message is kept with
 * the software. For this reason TFS also grants any other persons or
 * organisations permission to use or modify this software.
 *
 * TFS supplies this software to be publicly redistributed
 * on the understanding that TFS is not responsible for the correct
 * functioning of this software in any circumstances.
 *
 * Ported to run under 386BSD by Julian Elischer (julian@tfs.com) Sept 1992
 */

#ifndef _DEV_SCSIPI_SCSICONF_H_
#define _DEV_SCSIPI_SCSICONF_H_

#include <dev/scsipi/scsipiconf.h>

int	scsiprint(void *, const char *);

struct scsibus_softc {
	device_t sc_dev;
	struct scsipi_channel *sc_channel;	/* our scsipi_channel */
	int	sc_flags;
};

/* sc_flags */
#define	SCSIBUSF_OPEN	0x00000001	/* bus is open */

/* SCSI subtypes for struct scsipi_bustype */
#define SCSIPI_BUSTYPE_SCSI_PSCSI       0 /* parallel SCSI */
#define SCSIPI_BUSTYPE_SCSI_FC          1 /* Fiber channel */
#define SCSIPI_BUSTYPE_SCSI_SAS         2 /* SAS */
#define SCSIPI_BUSTYPE_SCSI_USB         3 /* USB */

extern const struct scsipi_bustype scsi_bustype;
extern const struct scsipi_bustype scsi_fc_bustype;
extern const struct scsipi_bustype scsi_sas_bustype;
extern const struct scsipi_bustype scsi_usb_bustype;

int	scsi_change_def(struct scsipi_periph *, int);
void	scsi_kill_pending(struct scsipi_periph *);
void	scsi_print_addr(struct scsipi_periph *);
int	scsi_probe_bus(struct scsibus_softc *, int, int);
void	scsi_scsipi_cmd(struct scsipi_xfer *);
void	scsi_async_event_xfer_mode(struct scsipi_channel *, void *);
void	scsi_fc_sas_async_event_xfer_mode(struct scsipi_channel *, void *);

#endif /* _DEV_SCSIPI_SCSICONF_H_ */