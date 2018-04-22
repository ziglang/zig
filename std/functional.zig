// A series of functional helpers
const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;

// Maps all of an arrays items to a function
// Returning the composition of each item with the function as a new array
pub fn map(func: var, list: []const @ArgType(@typeOf(func), 0), buffer: []@typeOf(func).ReturnType) []@typeOf(func).ReturnType {
    assert(buffer.len >= list.len);
    for (list) |item, i| {
        buffer[i] = func(item);
    }
    return buffer[0..list.len];
}

// Maps all of an arrays items to a function
// Returning the composition of each item with the function as a new array
// You have to free the result
pub fn mapAlloc(func: var, list: []const @ArgType(@typeOf(func), 0), allocator: &mem.Allocator) ![]@typeOf(func).ReturnType {
    var buf = try allocator.alloc(@typeOf(func).ReturnType, list.len);
    return map(func, list, buf);
}

test "functional.map" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    assert(mem.eql(i32, try mapAlloc(test_pow, ([]i32{ 1, 4, 5, 2, 8 })[0..], &direct_allocator.allocator), []i32{ 1, 16, 25, 4, 64 }));
}

// Returns a new array including items only where the filter function returned true
pub fn filter(func: var, list: []const @ArgType(@typeOf(func), 0), buffer: []@ArgType(@typeOf(func), 0)) []@ArgType(@typeOf(func), 0) {
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

// Returns a new array including items only where the filter function returned true
// You have to free the result
pub fn filterAlloc(func: var, list: []const @ArgType(@typeOf(func), 0), allocator: &mem.Allocator) ![]@ArgType(@typeOf(func), 0) {
    // We can't know how much to allocate so we will over allocate
    // Then shrink to prevent annoyance for developer
    var buf = try allocator.alloc(@ArgType(@typeOf(func), 0), list.len);
    var out = filter(func, list, buf);
    // Actual size we needed
    return allocator.shrink(@ArgType(@typeOf(func), 0), buf, out.len);
}

test "functional.filter" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    assert(mem.eql(i32, try filterAlloc(test_is_even, ([]i32{ 1, 4, 5, 2, 8 })[0..], &direct_allocator.allocator), []i32{ 4, 2, 8 }));
}

// Reduces all the items in the array to a singular value according the the function
pub fn reduce(func: var, list: []const @typeOf(func).ReturnType) @typeOf(func).ReturnType {
    var out = list[0];
    for (list[1..]) |item| {
        out = func(out, item);
    }
    return out;
}

test "functional.reduce" {
    assert(reduce(test_add, ([]i32{ 1, 3, 14 })[0..]) == 42);
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