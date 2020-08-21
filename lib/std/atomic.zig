// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
pub const Stack = @import("atomic/stack.zig").Stack;
pub const Queue = @import("atomic/queue.zig").Queue;
pub const Int = @import("atomic/int.zig").Int;

test "std.atomic" {
    _ = @import("atomic/stack.zig");
    _ = @import("atomic/queue.zig");
    _ = @import("atomic/int.zig");
}
