/*
 * Copyright (c) 2021-22 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
#ifndef _GRAFTDMG_UN_
#define _GRAFTDMG_UN_

#include <sys/_types/_u_int8_t.h>
#include <sys/_types/_u_int64_t.h>
#include <sys/_types/_u_int32_t.h>

#define GRAFTDMG_SECURE_BOOT_CRYPTEX_ARGS_VERSION 1
#define MAX_GRAFT_ARGS_SIZE 512

/* Flag values for secure_boot_cryptex_args.sbc_flags */
#define SBC_PRESERVE_MOUNT              0x0001  /* Preserve underlying mount until shutdown */
#define SBC_ALTERNATE_SHARED_REGION     0x0002  /* Binaries within should use alternate shared region */
#define SBC_SYSTEM_CONTENT              0x0004  /* Cryptex contains system content */
#define SBC_PANIC_ON_AUTHFAIL           0x0008  /* On failure to authenticate, panic */
#define SBC_STRICT_AUTH                 0x0010  /* Strict authentication mode */
#define SBC_PRESERVE_GRAFT              0x0020  /* Preserve graft itself until unmount */

typedef struct secure_boot_cryptex_args {
	u_int32_t sbc_version;
	u_int32_t sbc_4cc;
	int sbc_authentic_manifest_fd;
	int sbc_user_manifest_fd;
	int sbc_payload_fd;
	u_int64_t sbc_flags;
} __attribute__((aligned(4), packed))  secure_boot_cryptex_args_t;

typedef union graft_args {
	u_int8_t max_size[MAX_GRAFT_ARGS_SIZE];
	secure_boot_cryptex_args_t sbc_args;
} graftdmg_args_un;

#endif /* _GRAFTDMG_UN_ */