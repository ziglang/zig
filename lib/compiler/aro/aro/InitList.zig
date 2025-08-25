//! Sparsely populated list of used indexes.
//! Used for detecting duplicate initializers.
const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Diagnostics = @import("Diagnostics.zig");
const Parser = @import("Parser.zig");
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const TokenIndex = Tree.TokenIndex;
const Node = Tree.Node;

const Item = struct {
    list: InitList,
    index: u64,

    fn order(_: void, a: Item, b: Item) std.math.Order {
        return std.math.order(a.index, b.index);
    }
};

const InitList = @This();

list: std.ArrayList(Item) = .empty,
node: Node.OptIndex = .null,
tok: TokenIndex = 0,

/// Deinitialize freeing all memory.
pub fn deinit(il: *InitList, gpa: Allocator) void {
    for (il.list.items) |*item| item.list.deinit(gpa);
    il.list.deinit(gpa);
    il.* = undefined;
}

/// Find item at index, create new if one does not exist.
pub fn find(il: *InitList, gpa: Allocator, index: u64) !*InitList {
    const items = il.list.items;
    var left: usize = 0;
    var right: usize = items.len;

    // Append new value to empty list
    if (il.list.items.len == 0) {
        const item = try il.list.addOne(gpa);
        item.* = .{
            .list = .{},
            .index = index,
        };
        return &item.list;
    } else if (il.list.items[il.list.items.len - 1].index < index) {
        // Append a new value to the end of the list.
        const new = try il.list.addOne(gpa);
        new.* = .{
            .list = .{},
            .index = index,
        };
        return &new.list;
    }

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (std.math.order(index, items[mid].index)) {
            .eq => return &items[mid].list,
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    // Insert a new value into a sorted position.
    try il.list.insert(gpa, left, .{
        .list = .{},
        .index = index,
    });
    return &il.list.items[left].list;
}

test "basic usage" {
    const gpa = testing.allocator;
    var il: InitList = .{};
    defer il.deinit(gpa);

    {
        var item = try il.find(gpa, 0);
        var i: usize = 1;
        while (i < 5) : (i += 1) {
            item = try item.find(gpa, i);
        }
    }

    {
        const failing = testing.failing_allocator;
        var item = try il.find(failing, 0);
        var i: usize = 1;
        while (i < 5) : (i += 1) {
            item = try item.find(failing, i);
        }
    }
}
