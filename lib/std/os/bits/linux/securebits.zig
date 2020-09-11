// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

fn issecure_mask(comptime x: comptime_int) comptime_int {
    return 1 << x;
}

pub const SECUREBITS_DEFAULT = 0x00000000;

pub const SECURE_NOROOT = 0;
pub const SECURE_NOROOT_LOCKED = 1;

pub const SECBIT_NOROOT = issecure_mask(SECURE_NOROOT);
pub const SECBIT_NOROOT_LOCKED = issecure_mask(SECURE_NOROOT_LOCKED);

pub const SECURE_NO_SETUID_FIXUP = 2;
pub const SECURE_NO_SETUID_FIXUP_LOCKED = 3;

pub const SECBIT_NO_SETUID_FIXUP = issecure_mask(SECURE_NO_SETUID_FIXUP);
pub const SECBIT_NO_SETUID_FIXUP_LOCKED = issecure_mask(SECURE_NO_SETUID_FIXUP_LOCKED);

pub const SECURE_KEEP_CAPS = 4;
pub const SECURE_KEEP_CAPS_LOCKED = 5;

pub const SECBIT_KEEP_CAPS = issecure_mask(SECURE_KEEP_CAPS);
pub const SECBIT_KEEP_CAPS_LOCKED = issecure_mask(SECURE_KEEP_CAPS_LOCKED);

pub const SECURE_NO_CAP_AMBIENT_RAISE = 6;
pub const SECURE_NO_CAP_AMBIENT_RAISE_LOCKED = 7;

pub const SECBIT_NO_CAP_AMBIENT_RAISE = issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE);
pub const SECBIT_NO_CAP_AMBIENT_RAISE_LOCKED = issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE_LOCKED);

pub const SECURE_ALL_BITS = issecure_mask(SECURE_NOROOT) |
    issecure_mask(SECURE_NO_SETUID_FIXUP) |
    issecure_mask(SECURE_KEEP_CAPS) |
    issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE);
pub const SECURE_ALL_LOCKS = SECURE_ALL_BITS << 1;
