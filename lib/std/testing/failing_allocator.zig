// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const mem = std.mem;

/// Allocator that fails after N allocations, useful for making sure out of
/// memory conditions are handled correctly.
///
/// To use this, first initialize it and get an allocator with
///
/// `const failing_allocator = &FailingAllocator.init(<allocator>,
///                                                   <fail_index>).allocator;`
///
/// Then use `failing_allocator` anywhere you would have used a
/// different allocator.
pub const FailingAllocator = struct {
    allocator: mem.Allocator,
    index: usize,
    fail_index: usize,
    internal_allocator: *mem.Allocator,
    allocated_bytes: usize,
    freed_bytes: usize,
    allocations: usize,
    deallocations: usize,

    /// `fail_index` is the number of successful allocations you can
    /// expect from this allocator. The next allocation will fail.
    /// For example, if this is called with `fail_index` equal to 2,
    /// the following test will pass:
    ///
    /// var a = try failing_alloc.create(i32);
    /// var b = try failing_alloc.create(i32);
    /// testing.expectError(error.OutOfMemory, failing_alloc.create(i32));
    pub fn init(allocator: *mem.Allocator, fail_index: usize) FailingAllocator {
        return FailingAllocator{
            .internal_allocator = allocator,
            .fail_index = fail_index,
            .index = 0,
            .allocated_bytes = 0,
            .freed_bytes = 0,
            .allocations = 0,
            .deallocations = 0,
            .allocator = mem.Allocator{
                .allocFn = alloc,
                .resizeFn = resize,
            },
        };
    }

    fn alloc(
        allocator: *std.mem.Allocator,
        len: usize,
        ptr_align: u29,
        len_align: u29,
        return_address: usize,
    ) error{OutOfMemory}![]u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.allocFn(self.internal_allocator, len, ptr_align, len_align, return_address);
        self.allocated_bytes += result.len;
        self.allocations += 1;
        self.index += 1;
        return result;
    }

    fn resize(
        allocator: *std.mem.Allocator,
        old_mem: []u8,
        old_align: u29,
        new_len: usize,
        len_align: u29,
        ra: usize,
    ) error{OutOfMemory}!usize {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        const r = self.internal_allocator.resizeFn(self.internal_allocator, old_mem, old_align, new_len, len_align, ra) catch |e| {
            std.debug.assert(new_len > old_mem.len);
            return e;
        };
        if (new_len == 0) {
            self.deallocations += 1;
            self.freed_bytes += old_mem.len;
        } else if (r < old_mem.len) {
            self.freed_bytes += old_mem.len - r;
        } else {
            self.allocated_bytes += r - old_mem.len;
        }
        return r;
    }
};
