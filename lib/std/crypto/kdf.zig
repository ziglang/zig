// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! A Key Derivation Function (KDF) is intended to turn a weak, human generated password into a
//! strong key, suitable for cryptographic uses. It does this by salting and stretching the
//! password. Salting injects non-secret random data, so that identical passwords will be converted
//! into unique keys. Stretching applies a deliberately slow hashing function to frustrate
//! brute-force guessing.

pub const pbkdf2 = @import("pbkdf2.zig").pbkdf2;

test "kdf" {
    _ = @import("pbkdf2.zig");
}
