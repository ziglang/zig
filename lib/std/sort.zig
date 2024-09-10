const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const math = std.math;

pub const Mode = enum { stable, unstable };

pub const block = @import("sort/block.zig").block;
pub const pdq = @import("sort/pdq.zig").pdq;
pub const pdqContext = @import("sort/pdq.zig").pdqContext;

/// Stable in-place sort. O(n) best case, O(pow(n, 2)) worst case.
/// O(1) memory (no allocator required).
/// Sorts in ascending order with respect to the given `lessThan` function.
pub fn insertion(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const Context = struct {
        items: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };
    insertionContext(0, items.len, Context{ .items = items, .sub_ctx = context });
}

/// Stable in-place sort. O(n) best case, O(pow(n, 2)) worst case.
/// O(1) memory (no allocator required).
/// `context` must have methods `swap` and `lessThan`,
/// which each take 2 `usize` parameters indicating the index of an item.
/// Sorts in ascending order with respect to `lessThan`.
pub fn insertionContext(a: usize, b: usize, context: anytype) void {
    assert(a <= b);

    var i = a + 1;
    while (i < b) : (i += 1) {
        var j = i;
        while (j > a and context.lessThan(j, j - 1)) : (j -= 1) {
            context.swap(j, j - 1);
        }
    }
}

/// Unstable in-place sort. O(n*log(n)) best case, worst case and average case.
/// O(1) memory (no allocator required).
/// Sorts in ascending order with respect to the given `lessThan` function.
pub fn heap(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const Context = struct {
        items: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };
    heapContext(0, items.len, Context{ .items = items, .sub_ctx = context });
}

/// Unstable in-place sort. O(n*log(n)) best case, worst case and average case.
/// O(1) memory (no allocator required).
/// `context` must have methods `swap` and `lessThan`,
/// which each take 2 `usize` parameters indicating the index of an item.
/// Sorts in ascending order with respect to `lessThan`.
pub fn heapContext(a: usize, b: usize, context: anytype) void {
    assert(a <= b);
    // build the heap in linear time.
    var i = a + (b - a) / 2;
    while (i > a) {
        i -= 1;
        siftDown(a, i, b, context);
    }

    // pop maximal elements from the heap.
    i = b;
    while (i > a) {
        i -= 1;
        context.swap(a, i);
        siftDown(a, a, i, context);
    }
}

fn siftDown(a: usize, target: usize, b: usize, context: anytype) void {
    var cur = target;
    while (true) {
        // When we don't overflow from the multiply below, the following expression equals (2*cur) - (2*a) + a + 1
        // The `+ a + 1` is safe because:
        //  for `a > 0` then `2a >= a + 1`.
        //  for `a = 0`, the expression equals `2*cur+1`. `2*cur` is an even number, therefore adding 1 is safe.
        var child = (math.mul(usize, cur - a, 2) catch break) + a + 1;

        // stop if we overshot the boundary
        if (!(child < b)) break;

        // `next_child` is at most `b`, therefore no overflow is possible
        const next_child = child + 1;

        // store the greater child in `child`
        if (next_child < b and context.lessThan(child, next_child)) {
            child = next_child;
        }

        // stop if the Heap invariant holds at `cur`.
        if (context.lessThan(child, cur)) break;

        // swap `cur` with the greater child,
        // move one step down, and continue sifting.
        context.swap(child, cur);
        cur = child;
    }
}

/// Use to generate a comparator function for a given type. e.g. `sort(u8, slice, {}, asc(u8))`.
pub fn asc(comptime T: type) fn (void, T, T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            return a < b;
        }
    }.inner;
}

/// Use to generate a comparator function for a given type. e.g. `sort(u8, slice, {}, desc(u8))`.
pub fn desc(comptime T: type) fn (void, T, T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            return a > b;
        }
    }.inner;
}

const asc_u8 = asc(u8);
const asc_i32 = asc(i32);
const desc_u8 = desc(u8);
const desc_i32 = desc(i32);

const sort_funcs = &[_]fn (comptime type, anytype, anytype, comptime anytype) void{
    block,
    pdq,
    insertion,
    heap,
};

const context_sort_funcs = &[_]fn (usize, usize, anytype) void{
    // blockContext,
    pdqContext,
    insertionContext,
    heapContext,
};

const IdAndValue = struct {
    id: usize,
    value: i32,

    fn lessThan(context: void, a: IdAndValue, b: IdAndValue) bool {
        _ = context;
        return a.value < b.value;
    }
};

test "stable sort" {
    const expected = [_]IdAndValue{
        IdAndValue{ .id = 0, .value = 0 },
        IdAndValue{ .id = 1, .value = 0 },
        IdAndValue{ .id = 2, .value = 0 },
        IdAndValue{ .id = 0, .value = 1 },
        IdAndValue{ .id = 1, .value = 1 },
        IdAndValue{ .id = 2, .value = 1 },
        IdAndValue{ .id = 0, .value = 2 },
        IdAndValue{ .id = 1, .value = 2 },
        IdAndValue{ .id = 2, .value = 2 },
    };

    var cases = [_][9]IdAndValue{
        [_]IdAndValue{
            IdAndValue{ .id = 0, .value = 0 },
            IdAndValue{ .id = 0, .value = 1 },
            IdAndValue{ .id = 0, .value = 2 },
            IdAndValue{ .id = 1, .value = 0 },
            IdAndValue{ .id = 1, .value = 1 },
            IdAndValue{ .id = 1, .value = 2 },
            IdAndValue{ .id = 2, .value = 0 },
            IdAndValue{ .id = 2, .value = 1 },
            IdAndValue{ .id = 2, .value = 2 },
        },
        [_]IdAndValue{
            IdAndValue{ .id = 0, .value = 2 },
            IdAndValue{ .id = 0, .value = 1 },
            IdAndValue{ .id = 0, .value = 0 },
            IdAndValue{ .id = 1, .value = 2 },
            IdAndValue{ .id = 1, .value = 1 },
            IdAndValue{ .id = 1, .value = 0 },
            IdAndValue{ .id = 2, .value = 2 },
            IdAndValue{ .id = 2, .value = 1 },
            IdAndValue{ .id = 2, .value = 0 },
        },
    };

    for (&cases) |*case| {
        block(IdAndValue, (case.*)[0..], {}, IdAndValue.lessThan);
        for (case.*, 0..) |item, i| {
            try testing.expect(item.id == expected[i].id);
            try testing.expect(item.value == expected[i].value);
        }
    }
}

test "stable sort fuzz testing" {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();
    const test_case_count = 10;

    for (0..test_case_count) |_| {
        const array_size = random.intRangeLessThan(usize, 0, 1000);
        const array = try testing.allocator.alloc(IdAndValue, array_size);
        defer testing.allocator.free(array);
        // Value is a small random numbers to create collisions.
        // Id is a  reverse index to make sure sorting function only uses provided `lessThan`.
        for (array, 0..) |*item, index| {
            item.* = .{
                .value = random.intRangeLessThan(i32, 0, 100),
                .id = array_size - index,
            };
        }
        block(IdAndValue, array, {}, IdAndValue.lessThan);
        if (array_size > 0) {
            for (array[0 .. array_size - 1], array[1..]) |x, y| {
                try testing.expect(x.value <= y.value);
                if (x.value == y.value) {
                    try testing.expect(x.id > y.id);
                }
            }
        }
    }
}

test "sort" {
    const u8cases = [_][]const []const u8{
        &[_][]const u8{
            "",
            "",
        },
        &[_][]const u8{
            "a",
            "a",
        },
        &[_][]const u8{
            "az",
            "az",
        },
        &[_][]const u8{
            "za",
            "az",
        },
        &[_][]const u8{
            "asdf",
            "adfs",
        },
        &[_][]const u8{
            "one",
            "eno",
        },
    };

    const i32cases = [_][]const []const i32{
        &[_][]const i32{
            &[_]i32{},
            &[_]i32{},
        },
        &[_][]const i32{
            &[_]i32{1},
            &[_]i32{1},
        },
        &[_][]const i32{
            &[_]i32{ 0, 1 },
            &[_]i32{ 0, 1 },
        },
        &[_][]const i32{
            &[_]i32{ 1, 0 },
            &[_]i32{ 0, 1 },
        },
        &[_][]const i32{
            &[_]i32{ 1, -1, 0 },
            &[_]i32{ -1, 0, 1 },
        },
        &[_][]const i32{
            &[_]i32{ 2, 1, 3 },
            &[_]i32{ 1, 2, 3 },
        },
        &[_][]const i32{
            &[_]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 55, 32, 39, 58, 21, 88, 43, 22, 59 },
            &[_]i32{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 21, 22, 32, 39, 43, 55, 58, 59, 88 },
        },
    };

    inline for (sort_funcs) |sortFn| {
        for (u8cases) |case| {
            var buf: [20]u8 = undefined;
            const slice = buf[0..case[0].len];
            @memcpy(slice, case[0]);
            sortFn(u8, slice, {}, asc_u8);
            try testing.expect(mem.eql(u8, slice, case[1]));
        }

        for (i32cases) |case| {
            var buf: [20]i32 = undefined;
            const slice = buf[0..case[0].len];
            @memcpy(slice, case[0]);
            sortFn(i32, slice, {}, asc_i32);
            try testing.expect(mem.eql(i32, slice, case[1]));
        }
    }
}

test "sort descending" {
    const rev_cases = [_][]const []const i32{
        &[_][]const i32{
            &[_]i32{},
            &[_]i32{},
        },
        &[_][]const i32{
            &[_]i32{1},
            &[_]i32{1},
        },
        &[_][]const i32{
            &[_]i32{ 0, 1 },
            &[_]i32{ 1, 0 },
        },
        &[_][]const i32{
            &[_]i32{ 1, 0 },
            &[_]i32{ 1, 0 },
        },
        &[_][]const i32{
            &[_]i32{ 1, -1, 0 },
            &[_]i32{ 1, 0, -1 },
        },
        &[_][]const i32{
            &[_]i32{ 2, 1, 3 },
            &[_]i32{ 3, 2, 1 },
        },
    };

    inline for (sort_funcs) |sortFn| {
        for (rev_cases) |case| {
            var buf: [8]i32 = undefined;
            const slice = buf[0..case[0].len];
            @memcpy(slice, case[0]);
            sortFn(i32, slice, {}, desc_i32);
            try testing.expect(mem.eql(i32, slice, case[1]));
        }
    }
}

test "sort with context in the middle of a slice" {
    const Context = struct {
        items: []i32,

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return ctx.items[a] < ctx.items[b];
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(i32, &ctx.items[a], &ctx.items[b]);
        }
    };

    const i32cases = [_][]const []const i32{
        &[_][]const i32{
            &[_]i32{ 0, 1, 8, 3, 6, 5, 4, 2, 9, 7, 10, 55, 32, 39, 58, 21, 88, 43, 22, 59 },
            &[_]i32{ 50, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 21, 22, 32, 39, 43, 55, 58, 59, 88 },
        },
    };

    const ranges = [_]struct { start: usize, end: usize }{
        .{ .start = 10, .end = 20 },
        .{ .start = 1, .end = 11 },
        .{ .start = 3, .end = 7 },
    };

    inline for (context_sort_funcs) |sortFn| {
        for (i32cases) |case| {
            for (ranges) |range| {
                var buf: [20]i32 = undefined;
                const slice = buf[0..case[0].len];
                @memcpy(slice, case[0]);
                sortFn(range.start, range.end, Context{ .items = slice });
                try testing.expectEqualSlices(i32, case[1][range.start..range.end], slice[range.start..range.end]);
            }
        }
    }
}

test "sort fuzz testing" {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();
    const test_case_count = 10;

    inline for (sort_funcs) |sortFn| {
        for (0..test_case_count) |_| {
            const array_size = random.intRangeLessThan(usize, 0, 1000);
            const array = try testing.allocator.alloc(i32, array_size);
            defer testing.allocator.free(array);
            // populate with random data
            for (array) |*item| {
                item.* = random.intRangeLessThan(i32, 0, 100);
            }
            sortFn(i32, array, {}, asc_i32);
            try testing.expect(isSorted(i32, array, {}, asc_i32));
        }
    }
}

/// Returns the index of an element in `items` returning `.eq` when given to `compareFn`.
/// - If there are multiple such elements, returns the index of any one of them.
/// - If there are no such elements, returns `null`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`:
/// ```
/// [0]                                                   [len]
/// ┌───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┐
/// │.lt│.lt│ \ \ │.lt│.eq│.eq│ \ \ │.eq│.gt│.gt│ \ \ │.gt│
/// └───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┘
/// ├─────────────────┼─────────────────┼─────────────────┤
///  ↳ zero or more    ↳ zero or more    ↳ zero or more
///                   ├─────────────────┤
///                    ↳ if not null, returned
///                      index is in this range
/// ```
///
/// `O(log n)` time complexity.
///
/// See also: `lowerBound, `upperBound`, `partitionPoint`, `equalRange`.
pub fn binarySearch(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) ?usize {
    var low: usize = 0;
    var high: usize = items.len;

    while (low < high) {
        // Avoid overflowing in the midpoint calculation
        const mid = low + (high - low) / 2;
        switch (compareFn(context, items[mid])) {
            .eq => return mid,
            .gt => low = mid + 1,
            .lt => high = mid,
        }
    }
    return null;
}

test binarySearch {
    const S = struct {
        fn orderU32(context: u32, item: u32) std.math.Order {
            return std.math.order(context, item);
        }
        fn orderI32(context: i32, item: i32) std.math.Order {
            return std.math.order(context, item);
        }
        fn orderLength(context: usize, item: []const u8) std.math.Order {
            return std.math.order(context, item.len);
        }
    };
    const R = struct {
        b: i32,
        e: i32,

        fn r(b: i32, e: i32) @This() {
            return .{ .b = b, .e = e };
        }

        fn order(context: i32, item: @This()) std.math.Order {
            if (context < item.b) {
                return .lt;
            } else if (context > item.e) {
                return .gt;
            } else {
                return .eq;
            }
        }
    };

    try std.testing.expectEqual(null, binarySearch(u32, &[_]u32{}, @as(u32, 1), S.orderU32));
    try std.testing.expectEqual(0, binarySearch(u32, &[_]u32{1}, @as(u32, 1), S.orderU32));
    try std.testing.expectEqual(null, binarySearch(u32, &[_]u32{0}, @as(u32, 1), S.orderU32));
    try std.testing.expectEqual(null, binarySearch(u32, &[_]u32{1}, @as(u32, 0), S.orderU32));
    try std.testing.expectEqual(4, binarySearch(u32, &[_]u32{ 1, 2, 3, 4, 5 }, @as(u32, 5), S.orderU32));
    try std.testing.expectEqual(0, binarySearch(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 2), S.orderU32));
    try std.testing.expectEqual(1, binarySearch(i32, &[_]i32{ -7, -4, 0, 9, 10 }, @as(i32, -4), S.orderI32));
    try std.testing.expectEqual(3, binarySearch(i32, &[_]i32{ -100, -25, 2, 98, 99, 100 }, @as(i32, 98), S.orderI32));
    try std.testing.expectEqual(null, binarySearch(R, &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, @as(i32, -45), R.order));
    try std.testing.expectEqual(2, binarySearch(R, &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, @as(i32, 10), R.order));
    try std.testing.expectEqual(1, binarySearch(R, &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, @as(i32, -20), R.order));
    try std.testing.expectEqual(2, binarySearch([]const u8, &[_][]const u8{ "", "abc", "1234", "vwxyz" }, @as(usize, 4), S.orderLength));
}

/// Returns the index of the first element in `items` that is greater than or equal to `context`,
/// as determined by `compareFn`. If no such element exists, returns `items.len`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`:
/// ```
/// [0]                                                   [len]
/// ┌───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┐
/// │.lt│.lt│ \ \ │.lt│.eq│.eq│ \ \ │.eq│.gt│.gt│ \ \ │.gt│
/// └───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┘
/// ├─────────────────┼─────────────────┼─────────────────┤
///  ↳ zero or more    ↳ zero or more    ↳ zero or more
///                   ├───┤
///                    ↳ returned index
/// ```
///
/// `O(log n)` time complexity.
///
/// See also: `binarySearch`, `upperBound`, `partitionPoint`, `equalRange`.
pub fn lowerBound(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) usize {
    const S = struct {
        fn predicate(ctx: @TypeOf(context), item: T) bool {
            return compareFn(ctx, item).invert() == .lt;
        }
    };
    return partitionPoint(T, items, context, S.predicate);
}

test lowerBound {
    const S = struct {
        fn compareU32(context: u32, item: u32) std.math.Order {
            return std.math.order(context, item);
        }
        fn compareI32(context: i32, item: i32) std.math.Order {
            return std.math.order(context, item);
        }
        fn compareF32(context: f32, item: f32) std.math.Order {
            return std.math.order(context, item);
        }
    };
    const R = struct {
        val: i32,

        fn r(val: i32) @This() {
            return .{ .val = val };
        }

        fn compareFn(context: i32, item: @This()) std.math.Order {
            return std.math.order(context, item.val);
        }
    };

    try std.testing.expectEqual(0, lowerBound(u32, &[_]u32{}, @as(u32, 0), S.compareU32));
    try std.testing.expectEqual(0, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 0), S.compareU32));
    try std.testing.expectEqual(0, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 2), S.compareU32));
    try std.testing.expectEqual(2, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 5), S.compareU32));
    try std.testing.expectEqual(2, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(6, lowerBound(u32, &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(2, lowerBound(u32, &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(5, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 64), S.compareU32));
    try std.testing.expectEqual(6, lowerBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 100), S.compareU32));
    try std.testing.expectEqual(2, lowerBound(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 5), S.compareI32));
    try std.testing.expectEqual(1, lowerBound(f32, &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, @as(f32, -33.4), S.compareF32));
    try std.testing.expectEqual(2, lowerBound(R, &[_]R{ R.r(-100), R.r(-40), R.r(-10), R.r(30) }, @as(i32, -20), R.compareFn));
}

/// Returns the index of the first element in `items` that is greater than `context`, as determined
/// by `compareFn`. If no such element exists, returns `items.len`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`:
/// ```
/// [0]                                                   [len]
/// ┌───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┐
/// │.lt│.lt│ \ \ │.lt│.eq│.eq│ \ \ │.eq│.gt│.gt│ \ \ │.gt│
/// └───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┘
/// ├─────────────────┼─────────────────┼─────────────────┤
///  ↳ zero or more    ↳ zero or more    ↳ zero or more
///                                     ├───┤
///                                      ↳ returned index
/// ```
///
/// `O(log n)` time complexity.
///
/// See also: `binarySearch`, `lowerBound`, `partitionPoint`, `equalRange`.
pub fn upperBound(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) usize {
    const S = struct {
        fn predicate(ctx: @TypeOf(context), item: T) bool {
            return compareFn(ctx, item).invert() != .gt;
        }
    };
    return partitionPoint(T, items, context, S.predicate);
}

test upperBound {
    const S = struct {
        fn compareU32(context: u32, item: u32) std.math.Order {
            return std.math.order(context, item);
        }
        fn compareI32(context: i32, item: i32) std.math.Order {
            return std.math.order(context, item);
        }
        fn compareF32(context: f32, item: f32) std.math.Order {
            return std.math.order(context, item);
        }
    };
    const R = struct {
        val: i32,

        fn r(val: i32) @This() {
            return .{ .val = val };
        }

        fn compareFn(context: i32, item: @This()) std.math.Order {
            return std.math.order(context, item.val);
        }
    };

    try std.testing.expectEqual(0, upperBound(u32, &[_]u32{}, @as(u32, 0), S.compareU32));
    try std.testing.expectEqual(0, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 0), S.compareU32));
    try std.testing.expectEqual(1, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 2), S.compareU32));
    try std.testing.expectEqual(2, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 5), S.compareU32));
    try std.testing.expectEqual(6, upperBound(u32, &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(6, upperBound(u32, &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(3, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 8), S.compareU32));
    try std.testing.expectEqual(6, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 64), S.compareU32));
    try std.testing.expectEqual(6, upperBound(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 100), S.compareU32));
    try std.testing.expectEqual(2, upperBound(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 5), S.compareI32));
    try std.testing.expectEqual(1, upperBound(f32, &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, @as(f32, -33.4), S.compareF32));
    try std.testing.expectEqual(2, upperBound(R, &[_]R{ R.r(-100), R.r(-40), R.r(-10), R.r(30) }, @as(i32, -20), R.compareFn));
}

/// Returns the index of the partition point of `items` in relation to the given predicate.
/// - If all elements of `items` satisfy the predicate the returned value is `items.len`.
///
/// `items` must contain a prefix for which all elements satisfy the predicate,
/// and beyond which none of the elements satisfy the predicate:
/// ```
/// [0]                                          [len]
/// ┌────┬────┬─/ /─┬────┬─────┬─────┬─/ /─┬─────┐
/// │true│true│ \ \ │true│false│false│ \ \ │false│
/// └────┴────┴─/ /─┴────┴─────┴─────┴─/ /─┴─────┘
/// ├────────────────────┼───────────────────────┤
///  ↳ zero or more       ↳ zero or more
///                      ├─────┤
///                       ↳ returned index
/// ```
///
/// `O(log n)` time complexity.
///
/// See also: `binarySearch`, `lowerBound, `upperBound`, `equalRange`.
pub fn partitionPoint(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime predicate: fn (@TypeOf(context), T) bool,
) usize {
    var low: usize = 0;
    var high: usize = items.len;

    while (low < high) {
        const mid = low + (high - low) / 2;
        if (predicate(context, items[mid])) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return low;
}

test partitionPoint {
    const S = struct {
        fn lowerU32(context: u32, item: u32) bool {
            return item < context;
        }
        fn lowerI32(context: i32, item: i32) bool {
            return item < context;
        }
        fn lowerF32(context: f32, item: f32) bool {
            return item < context;
        }
        fn lowerEqU32(context: u32, item: u32) bool {
            return item <= context;
        }
        fn lowerEqI32(context: i32, item: i32) bool {
            return item <= context;
        }
        fn lowerEqF32(context: f32, item: f32) bool {
            return item <= context;
        }
        fn isEven(_: void, item: u8) bool {
            return item % 2 == 0;
        }
    };

    try std.testing.expectEqual(0, partitionPoint(u32, &[_]u32{}, @as(u32, 0), S.lowerU32));
    try std.testing.expectEqual(0, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 0), S.lowerU32));
    try std.testing.expectEqual(0, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 2), S.lowerU32));
    try std.testing.expectEqual(2, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 5), S.lowerU32));
    try std.testing.expectEqual(2, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 8), S.lowerU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, @as(u32, 8), S.lowerU32));
    try std.testing.expectEqual(2, partitionPoint(u32, &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, @as(u32, 8), S.lowerU32));
    try std.testing.expectEqual(5, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 64), S.lowerU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 100), S.lowerU32));
    try std.testing.expectEqual(2, partitionPoint(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 5), S.lowerI32));
    try std.testing.expectEqual(1, partitionPoint(f32, &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, @as(f32, -33.4), S.lowerF32));
    try std.testing.expectEqual(0, partitionPoint(u32, &[_]u32{}, @as(u32, 0), S.lowerEqU32));
    try std.testing.expectEqual(0, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 0), S.lowerEqU32));
    try std.testing.expectEqual(1, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 2), S.lowerEqU32));
    try std.testing.expectEqual(2, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 5), S.lowerEqU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, @as(u32, 8), S.lowerEqU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, @as(u32, 8), S.lowerEqU32));
    try std.testing.expectEqual(3, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 8), S.lowerEqU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 64), S.lowerEqU32));
    try std.testing.expectEqual(6, partitionPoint(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 100), S.lowerEqU32));
    try std.testing.expectEqual(2, partitionPoint(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 5), S.lowerEqI32));
    try std.testing.expectEqual(1, partitionPoint(f32, &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, @as(f32, -33.4), S.lowerEqF32));
    try std.testing.expectEqual(4, partitionPoint(u8, &[_]u8{ 0, 50, 14, 2, 5, 71 }, {}, S.isEven));
}

/// Returns a tuple of the lower and upper indices in `items` between which all
/// elements return `.eq` when given to `compareFn`.
/// - If no element in `items` returns `.eq`, both indices are the
/// index of the first element in `items` returning `.gt`.
/// - If no element in `items` returns `.gt`, both indices equal `items.len`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`:
/// ```
/// [0]                                                   [len]
/// ┌───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┬───┬───┬─/ /─┬───┐
/// │.lt│.lt│ \ \ │.lt│.eq│.eq│ \ \ │.eq│.gt│.gt│ \ \ │.gt│
/// └───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┴───┴───┴─/ /─┴───┘
/// ├─────────────────┼─────────────────┼─────────────────┤
///  ↳ zero or more    ↳ zero or more    ↳ zero or more
///                   ├─────────────────┤
///                    ↳ returned range
/// ```
///
/// `O(log n)` time complexity.
///
/// See also: `binarySearch`, `lowerBound, `upperBound`, `partitionPoint`.
pub fn equalRange(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) struct { usize, usize } {
    return .{
        lowerBound(T, items, context, compareFn),
        upperBound(T, items, context, compareFn),
    };
}

test equalRange {
    const S = struct {
        fn orderU32(context: u32, item: u32) std.math.Order {
            return std.math.order(context, item);
        }
        fn orderI32(context: i32, item: i32) std.math.Order {
            return std.math.order(context, item);
        }
        fn orderF32(context: f32, item: f32) std.math.Order {
            return std.math.order(context, item);
        }
        fn orderLength(context: usize, item: []const u8) std.math.Order {
            return std.math.order(context, item.len);
        }
    };

    try std.testing.expectEqual(.{ 0, 0 }, equalRange(i32, &[_]i32{}, @as(i32, 0), S.orderI32));
    try std.testing.expectEqual(.{ 0, 0 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 0), S.orderI32));
    try std.testing.expectEqual(.{ 0, 1 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 2), S.orderI32));
    try std.testing.expectEqual(.{ 2, 2 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 5), S.orderI32));
    try std.testing.expectEqual(.{ 2, 3 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 8), S.orderI32));
    try std.testing.expectEqual(.{ 5, 6 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 64), S.orderI32));
    try std.testing.expectEqual(.{ 6, 6 }, equalRange(i32, &[_]i32{ 2, 4, 8, 16, 32, 64 }, @as(i32, 100), S.orderI32));
    try std.testing.expectEqual(.{ 2, 6 }, equalRange(i32, &[_]i32{ 2, 4, 8, 8, 8, 8, 15, 22 }, @as(i32, 8), S.orderI32));
    try std.testing.expectEqual(.{ 2, 2 }, equalRange(u32, &[_]u32{ 2, 4, 8, 16, 32, 64 }, @as(u32, 5), S.orderU32));
    try std.testing.expectEqual(.{ 1, 1 }, equalRange(f32, &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, @as(f32, -33.4), S.orderF32));
    try std.testing.expectEqual(.{ 3, 5 }, equalRange(
        []const u8,
        &[_][]const u8{ "Mars", "Venus", "Earth", "Saturn", "Uranus", "Mercury", "Jupiter", "Neptune" },
        @as(usize, 6),
        S.orderLength,
    ));
}

pub fn argMin(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) ?usize {
    if (items.len == 0) {
        return null;
    }

    var smallest = items[0];
    var smallest_index: usize = 0;
    for (items[1..], 0..) |item, i| {
        if (lessThan(context, item, smallest)) {
            smallest = item;
            smallest_index = i + 1;
        }
    }

    return smallest_index;
}

test argMin {
    try testing.expectEqual(@as(?usize, null), argMin(i32, &[_]i32{}, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMin(i32, &[_]i32{1}, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMin(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 3), argMin(i32, &[_]i32{ 9, 3, 8, 2, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMin(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMin(i32, &[_]i32{ -10, 1, 10 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 3), argMin(i32, &[_]i32{ 6, 3, 5, 7, 6 }, {}, desc_i32));
}

pub fn min(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) ?T {
    const i = argMin(T, items, context, lessThan) orelse return null;
    return items[i];
}

test min {
    try testing.expectEqual(@as(?i32, null), min(i32, &[_]i32{}, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 1), min(i32, &[_]i32{1}, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 1), min(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 2), min(i32, &[_]i32{ 9, 3, 8, 2, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 1), min(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, -10), min(i32, &[_]i32{ -10, 1, 10 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 7), min(i32, &[_]i32{ 6, 3, 5, 7, 6 }, {}, desc_i32));
}

pub fn argMax(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) ?usize {
    if (items.len == 0) {
        return null;
    }

    var biggest = items[0];
    var biggest_index: usize = 0;
    for (items[1..], 0..) |item, i| {
        if (lessThan(context, biggest, item)) {
            biggest = item;
            biggest_index = i + 1;
        }
    }

    return biggest_index;
}

test argMax {
    try testing.expectEqual(@as(?usize, null), argMax(i32, &[_]i32{}, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMax(i32, &[_]i32{1}, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 4), argMax(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMax(i32, &[_]i32{ 9, 3, 8, 2, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 0), argMax(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 2), argMax(i32, &[_]i32{ -10, 1, 10 }, {}, asc_i32));
    try testing.expectEqual(@as(?usize, 1), argMax(i32, &[_]i32{ 6, 3, 5, 7, 6 }, {}, desc_i32));
}

pub fn max(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) ?T {
    const i = argMax(T, items, context, lessThan) orelse return null;
    return items[i];
}

test max {
    try testing.expectEqual(@as(?i32, null), max(i32, &[_]i32{}, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 1), max(i32, &[_]i32{1}, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 5), max(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 9), max(i32, &[_]i32{ 9, 3, 8, 2, 5 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 1), max(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 10), max(i32, &[_]i32{ -10, 1, 10 }, {}, asc_i32));
    try testing.expectEqual(@as(?i32, 3), max(i32, &[_]i32{ 6, 3, 5, 7, 6 }, {}, desc_i32));
}

pub fn isSorted(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) bool {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        if (lessThan(context, items[i], items[i - 1])) {
            return false;
        }
    }

    return true;
}

test isSorted {
    try testing.expect(isSorted(i32, &[_]i32{}, {}, asc_i32));
    try testing.expect(isSorted(i32, &[_]i32{10}, {}, asc_i32));
    try testing.expect(isSorted(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, asc_i32));
    try testing.expect(isSorted(i32, &[_]i32{ -10, 1, 1, 1, 10 }, {}, asc_i32));

    try testing.expect(isSorted(i32, &[_]i32{}, {}, desc_i32));
    try testing.expect(isSorted(i32, &[_]i32{-20}, {}, desc_i32));
    try testing.expect(isSorted(i32, &[_]i32{ 3, 2, 1, 0, -1 }, {}, desc_i32));
    try testing.expect(isSorted(i32, &[_]i32{ 10, -10 }, {}, desc_i32));

    try testing.expect(isSorted(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, asc_i32));
    try testing.expect(isSorted(i32, &[_]i32{ 1, 1, 1, 1, 1 }, {}, desc_i32));

    try testing.expectEqual(false, isSorted(i32, &[_]i32{ 5, 4, 3, 2, 1 }, {}, asc_i32));
    try testing.expectEqual(false, isSorted(i32, &[_]i32{ 1, 2, 3, 4, 5 }, {}, desc_i32));

    try testing.expect(isSorted(u8, "abcd", {}, asc_u8));
    try testing.expect(isSorted(u8, "zyxw", {}, desc_u8));

    try testing.expectEqual(false, isSorted(u8, "abcd", {}, desc_u8));
    try testing.expectEqual(false, isSorted(u8, "zyxw", {}, asc_u8));

    try testing.expect(isSorted(u8, "ffff", {}, asc_u8));
    try testing.expect(isSorted(u8, "ffff", {}, desc_u8));
}
