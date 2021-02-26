// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//! Epoch reference times in terms of their difference from
//! UTC 1970-01-01 in seconds.

/// Jan 01, 1970 AD
pub const posix = 0;
/// Jan 01, 1980 AD
pub const dos = 315532800;
/// Jan 01, 2001 AD
pub const ios = 978307200;
/// Nov 17, 1858 AD
pub const openvms = -3506716800;
/// Jan 01, 1900 AD
pub const zos = -2208988800;
/// Jan 01, 1601 AD
pub const windows = -11644473600;
/// Jan 01, 1978 AD
pub const amiga = 252460800;
/// Dec 31, 1967 AD
pub const pickos = -63244800;
/// Jan 06, 1980 AD
pub const gps = 315964800;
/// Jan 01, 0001 AD
pub const clr = -62135769600;

pub const unix = posix;
pub const android = posix;
pub const os2 = dos;
pub const bios = dos;
pub const vfat = dos;
pub const ntfs = windows;
pub const ntp = zos;
pub const jbase = pickos;
pub const aros = amiga;
pub const morphos = amiga;
pub const brew = gps;
pub const atsc = gps;
pub const go = clr;
