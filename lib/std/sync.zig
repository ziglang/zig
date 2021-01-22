// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std.zig");
const root = @import("root");

pub const atomic = @import("./atomic.zig");
pub const futex = @import("./sync/futex.zig");
pub const primitives = @import("./sync/primitives.zig");

pub usingnamespace if (@hasDecl(root, "sync"))
    root.sync
else if (std.builtin.single_threaded)
    primitives.debug
else if (std.io.mode == .evented)
    primitives.with(futex.event)
else
    primitives.with(futex.os);

test "" {
    _ = atomic;
    _ = futex;
    _ = primitives;
}
