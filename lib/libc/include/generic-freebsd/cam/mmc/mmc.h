/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2014-2016 Ilya Bakulin.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Portions of this software may have been developed with reference to
 * the SD Simplified Specification.  The following disclaimer may apply:
 *
 * The following conditions apply to the release of the simplified
 * specification ("Simplified Specification") by the SD Card Association and
 * the SD Group. The Simplified Specification is a subset of the complete SD
 * Specification which is owned by the SD Card Association and the SD
 * Group. This Simplified Specification is provided on a non-confidential
 * basis subject to the disclaimers below. Any implementation of the
 * Simplified Specification may require a license from the SD Card
 * Association, SD Group, SD-3C LLC or other third parties.
 *
 * Disclaimers:
 *
 * The information contained in the Simplified Specification is presented only
 * as a standard specification for SD Cards and SD Host/Ancillary products and
 * is provided "AS-IS" without any representations or warranties of any
 * kind. No responsibility is assumed by the SD Group, SD-3C LLC or the SD
 * Card Association for any damages, any infringements of patents or other
 * right of the SD Group, SD-3C LLC, the SD Card Association or any third
 * parties, which may result from its use. No license is granted by
 * implication, estoppel or otherwise under any patent or other rights of the
 * SD Group, SD-3C LLC, the SD Card Association or any third party. Nothing
 * herein shall be construed as an obligation by the SD Group, the SD-3C LLC
 * or the SD Card Association to disclose or distribute any technical
 * information, know-how or other confidential information to any third party.
 *
 * Inspired coded in sys/dev/mmc. Thanks to Warner Losh <imp@FreeBSD.org>,
 * Bernd Walter <tisco@FreeBSD.org>, and other authors.
 */

#ifndef CAM_MMC_H
#define CAM_MMC_H

#include <dev/mmc/mmcreg.h>
/*
 * This structure describes an MMC/SD card
 */
struct mmc_params {
        uint8_t	model[40]; /* Card model */

        /* Card OCR */
        uint32_t card_ocr;

        /* OCR of the IO portion of the card */
        uint32_t io_ocr;

        /* Card CID -- raw and parsed */
        uint32_t card_cid[4];
        struct mmc_cid  cid;

        /* Card CSD -- raw */
        uint32_t card_csd[4];

        /* Card RCA */
        uint16_t card_rca;

        /* What kind of card is it */
        uint32_t card_features;
#define CARD_FEATURE_MEMORY 0x1
#define CARD_FEATURE_SDHC   0x1 << 1
#define CARD_FEATURE_SDIO   0x1 << 2
#define CARD_FEATURE_SD20   0x1 << 3
#define CARD_FEATURE_MMC    0x1 << 4
#define CARD_FEATURE_18V    0x1 << 5

        uint8_t sdio_func_count;
} __packed;

/*
 * Only one MMC card on bus is supported now.
 * If we ever want to support multiple MMC cards on the same bus,
 * mmc_xpt needs to be extended to issue new RCAs based on number
 * of already probed cards. Furthermore, retuning and high-speed
 * settings should also take all cards into account.
 */
#define MMC_PROPOSED_RCA    2
#endif