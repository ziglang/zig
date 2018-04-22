// A series of functional helpers
const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;

pub fn map(comptime listType: type, comptime outType: type, func: fn (listType)outType, list: []const listType, buffer: []outType) []outType {
    assert(buffer.len >= list.len);
    for (list) |item, i| {
        buffer[i] = func(item);
    }
    return buffer[0..list.len];
}

// You have to free the result
pub fn mapAlloc(comptime listType: type, comptime outType: type, func: fn (listType)outType, list: []const listType, allocator: &mem.Allocator) ![]outType {
    var buf = try allocator.alloc(outType, list.len);
    return map(listType, outType, func, list, buf);
}

test "functional.map" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    assert(mem.eql(i32, try mapAlloc(i32, i32, test_pow, ([]i32{ 1, 4, 5, 2, 8 })[0..], &direct_allocator.allocator), []i32{ 1, 16, 25, 4, 64 }));
}

pub fn filter(comptime listType: type, func: fn(listType)bool, list: []const listType, buffer: []listType) []listType {
    // You have to be prepared that the reduce will match all
    assert(buffer.len >= list.len);
    var count : usize = 0;
    for (list) |item, i| {
        if (func(item)) {
            buffer[count] = item;
            count += 1;
        }
    }
    return buffer[0..count];
}

// You have to free the result
pub fn filterAlloc(comptime listType: type, func: fn (listType)bool, list: []const listType, allocator: &mem.Allocator) ![]listType {
    // We can't know how much to allocate so we will over allocate
    // Then shrink to prevent annoyance for developer
    var buf = try allocator.alloc(listType, list.len);
    var out = filter(listType, func, list, buf);
    // Actual size we needed
    return allocator.shrink(listType, buf, out.len);
}

test "functional.filter" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    assert(mem.eql(i32, try filterAlloc(i32, test_is_even, ([]i32{ 1, 4, 5, 2, 8 })[0..], &direct_allocator.allocator), []i32{ 4, 2, 8 }));
}

pub fn reduce(comptime listType: type, func: fn(listType, listType)listType, list: []const listType) listType {
    var out : listType = list[0];
    for (list[1..]) |item| {
        out = func(out, item);
    }
    return out;
}

test "functional.reduce" {
    assert(reduce(i32, test_add, ([]i32{ 1, 3, 14 })[0..]) == 42);
}

fn test_is_even(a: i32)bool {
    return @rem(a, 2) == 0;
}

fn test_add(a: i32, b: i32)i32 { 
    return a * b;
}

fn test_pow(a: i32) i32 {
    return a * a;
}