/*
 * Copyright (c) 2014 The FreeBSD Foundation
 * Copyright (c) 2018 Andrew Turner
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */
#ifndef _SYS_EFI_MAP_H_
#define _SYS_EFI_MAP_H_

#include <sys/efi.h>
#include <machine/metadata.h>

struct efi_map_header;

typedef void (*efi_map_entry_cb)(struct efi_md *, void *argp);

void efi_map_foreach_entry(struct efi_map_header *efihdr, efi_map_entry_cb cb,
    void *argp);

void efi_map_add_entries(struct efi_map_header *efihdr);
void efi_map_exclude_entries(struct efi_map_header *efihdr);
void efi_map_print_entries(struct efi_map_header *efihdr);

#endif /* !_SYS_EFI_MAP_H_ */