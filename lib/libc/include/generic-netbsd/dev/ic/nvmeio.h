/*	$NetBSD: nvmeio.h,v 1.4 2021/11/10 17:19:30 msaitoh Exp $	*/

/*-
 * Copyright (C) 2012-2013 Intel Corporation
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
 *
 * $FreeBSD: head/sys/dev/nvme/nvme.h 329824 2018-02-22 13:32:31Z wma $
 */

#ifndef __NVMEIO_H__
#define __NVMEIO_H__

#include <sys/endian.h>
#include <sys/ioccom.h>
#include <dev/ic/nvmereg.h>

#define	NVME_PASSTHROUGH_CMD		_IOWR('n', 0, struct nvme_pt_command)

#define	nvme_completion_is_error(cpl)					\
	((NVME_CQE_SC((cpl)->flags) != NVME_CQE_SC_SUCCESS)   		\
	    || (NVME_CQE_SCT((cpl)->flags) != NVME_CQE_SCT_GENERIC))

struct nvme_pt_command {

	/*
	 * cmd is used to specify a passthrough command to a controller or
	 *  namespace.
	 *
	 * The following fields from cmd may be specified by the caller:
	 *	* opcode
	 *	* nsid (namespace id) - for admin commands only
	 *	* cdw10-cdw15
	 *
	 * Remaining fields must be set to 0 by the caller.
	 */
	struct nvme_sqe		cmd;

	/*
	 * cpl returns completion status for the passthrough command
	 *  specified by cmd.
	 *
	 * The following fields will be filled out by the driver, for
	 *  consumption by the caller:
	 *	* cdw0
	 *	* flags (except for phase)
	 *
	 * Remaining fields will be set to 0 by the driver.
	 */
	struct nvme_cqe		cpl;

	/* buf is the data buffer associated with this passthrough command. */
	void			*buf;

	/*
	 * len is the length of the data buffer associated with this
	 *  passthrough command.
	 */
	uint32_t		len;

	/*
	 * is_read = 1 if the passthrough command will read data into the
	 *  supplied buffer from the controller.
	 *
	 * is_read = 0 if the passthrough command will write data from the
	 *  supplied buffer to the controller.
	 */
	uint32_t		is_read;

	/*
	 * timeout (unit: ms)
	 *
	 * 0: use default timeout value
	 */
	uint32_t		timeout;
};

/* Endianness conversion functions for NVMe structs */
static __inline void
nvme_le128toh(uint64_t v[2])
{
#if _BYTE_ORDER != _LITTLE_ENDIAN
	uint64_t t;

	t = le64toh(v[0]);
	v[0] = le64toh(v[1]);
	v[1] = t;
#endif
}

static __inline void
nvme_namespace_format_swapbytes(struct nvm_namespace_format *format)
{

#if _BYTE_ORDER != _LITTLE_ENDIAN
	format->ms = le16toh(format->ms);
#endif
}

static __inline void
nvme_identify_namespace_swapbytes(struct nvm_identify_namespace *identify)
{
#if _BYTE_ORDER != _LITTLE_ENDIAN
	u_int i;

	identify->nsze = le64toh(identify->nsze);
	identify->ncap = le64toh(identify->ncap);
	identify->nuse = le64toh(identify->nuse);
	identify->nawun = le16toh(identify->nawun);
	identify->nawupf = le16toh(identify->nawupf);
	identify->nacwu = le16toh(identify->nacwu);
	identify->nabsn = le16toh(identify->nabsn);
	identify->nabo = le16toh(identify->nabo);
	identify->nabspf = le16toh(identify->nabspf);
	identify->noiob = le16toh(identify->noiob);
	for (i = 0; i < __arraycount(identify->lbaf); i++)
		nvme_namespace_format_swapbytes(&identify->lbaf[i]);
#endif
}

static __inline void
nvme_identify_psd_swapbytes(struct nvm_identify_psd *psd)
{

#if _BYTE_ORDER != _LITTLE_ENDIAN
	psd->mp = le16toh(psd->mp);
	psd->enlat = le32toh(psd->enlat);
	psd->exlat = le32toh(psd->exlat);
	psd->idlp = le16toh(psd->idlp);
	psd->actp = le16toh(psd->actp);
	psd->ap = le16toh(psd->ap);
#endif
}

static __inline void
nvme_identify_controller_swapbytes(struct nvm_identify_controller *identify)
{
#if _BYTE_ORDER != _LITTLE_ENDIAN
	u_int i;

	identify->vid = le16toh(identify->vid);
	identify->ssvid = le16toh(identify->ssvid);
	identify->cntlid = le16toh(identify->cntlid);
	identify->ver = le32toh(identify->ver);
	identify->rtd3r = le32toh(identify->rtd3r);
	identify->rtd3e = le32toh(identify->rtd3e);
	identify->oaes = le32toh(identify->oaes);
	identify->ctrattr = le32toh(identify->ctrattr);
	identify->oacs = le16toh(identify->oacs);
	identify->wctemp = le16toh(identify->wctemp);
	identify->cctemp = le16toh(identify->cctemp);
	identify->mtfa = le16toh(identify->mtfa);
	identify->hmpre = le32toh(identify->hmpre);
	identify->hmmin = le32toh(identify->hmmin);
	nvme_le128toh(identify->untncap.tnvmcap);
	nvme_le128toh(identify->untncap.unvmcap);
	identify->rpmbs = le32toh(identify->rpmbs);
	identify->edstt = le16toh(identify->edstt);
	identify->kas = le16toh(identify->kas);
	identify->hctma = le16toh(identify->hctma);
	identify->mntmt = le16toh(identify->mntmt);
	identify->mxtmt = le16toh(identify->mxtmt);
	identify->sanicap = le32toh(identify->sanicap);
	identify->maxcmd = le16toh(identify->maxcmd);
	identify->nn = le32toh(identify->nn);
	identify->oncs = le16toh(identify->oncs);
	identify->fuses = le16toh(identify->fuses);
	identify->awun = le16toh(identify->awun);
	identify->awupf = le16toh(identify->awupf);
	identify->acwu = le16toh(identify->acwu);
	identify->sgls = le32toh(identify->sgls);
	for (i = 0; i < __arraycount(identify->psd); i++)
		nvme_identify_psd_swapbytes(&identify->psd[i]);
#endif
}

#endif /* __NVMEIO_H__ */