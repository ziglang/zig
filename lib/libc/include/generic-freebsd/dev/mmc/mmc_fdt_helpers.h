/*
 * Copyright 2019 Emmanuel Vadot <manu@freebsd.org>
 * Copyright (c) 2017 Ian Lepore <ian@freebsd.org> All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _MMC_FDT_HELPERS_H_
#define	_MMC_FDT_HELPERS_H_

#include <dev/gpio/gpiobusvar.h>
#include <dev/ofw/ofw_bus.h>

#include <dev/extres/regulator/regulator.h>

#include <dev/mmc/mmc_helpers.h>

#define mmc_fdt_helper mmc_helper /* For backwards compatibility */

typedef void (*mmc_fdt_cd_handler)(device_t dev, bool present);

int mmc_fdt_parse(device_t dev, phandle_t node, struct mmc_helper *helper, struct mmc_host *host);
int mmc_fdt_gpio_setup(device_t dev, phandle_t node, struct mmc_helper *helper, mmc_fdt_cd_handler handler);
void mmc_fdt_gpio_teardown(struct mmc_helper *helper);
bool mmc_fdt_gpio_get_present(struct mmc_helper *helper);
bool mmc_fdt_gpio_get_readonly(struct mmc_helper *helper);
void mmc_fdt_set_power(struct mmc_helper *helper, enum mmc_power_mode power_mode);

#endif