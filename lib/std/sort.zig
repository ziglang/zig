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
    var prng = std.Random.DefaultPrng.init(0x12345678);
    const random = prng.random();
    const test_case_count = 10;

    inline for (sort_funcs) |sortFn| {
        var i: usize = 0;
        while (i < test_case_count) : (i += 1) {
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

/// Returns the index of an element in `items` equal to `key`.
/// If there are multiple such elements, returns the index of any one of them.
/// If there are no such elements, returns `null`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`.
///
/// O(log n) complexity.
pub fn binarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), key: @TypeOf(key), mid_item: T) math.Order,
) ?usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (compareFn(context, key, items[mid])) {
            .eq => return mid,
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    return null;
}

test binarySearch {
    const S = struct {
        fn order_u32(context: void, lhs: u32, rhs: u32) math.Order {
            _ = context;
            return math.order(lhs, rhs);
        }
        fn order_i32(context: void, lhs: i32, rhs: i32) math.Order {
            _ = context;
            return math.order(lhs, rhs);
        }
    };
    try testing.expectEqual(
        @as(?usize, null),
        binarySearch(u32, @as(u32, 1), &[_]u32{}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        binarySearch(u32, @as(u32, 1), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        binarySearch(u32, @as(u32, 1), &[_]u32{0}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, null),
        binarySearch(u32, @as(u32, 0), &[_]u32{1}, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 4),
        binarySearch(u32, @as(u32, 5), &[_]u32{ 1, 2, 3, 4, 5 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 0),
        binarySearch(u32, @as(u32, 2), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.order_u32),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        binarySearch(i32, @as(i32, -4), &[_]i32{ -7, -4, 0, 9, 10 }, {}, S.order_i32),
    );
    try testing.expectEqual(
        @as(?usize, 3),
        binarySearch(i32, @as(i32, 98), &[_]i32{ -100, -25, 2, 98, 99, 100 }, {}, S.order_i32),
    );
    const R = struct {
        b: i32,
        e: i32,

        fn r(b: i32, e: i32) @This() {
            return @This(){ .b = b, .e = e };
        }

        fn order(context: void, key: i32, mid_item: @This()) math.Order {
            _ = context;

            if (key < mid_item.b) {
                return .lt;
            }

            if (key > mid_item.e) {
                return .gt;
            }

            return .eq;
        }
    };
    try testing.expectEqual(
        @as(?usize, null),
        binarySearch(R, @as(i32, -45), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 2),
        binarySearch(R, @as(i32, 10), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
    try testing.expectEqual(
        @as(?usize, 1),
        binarySearch(R, @as(i32, -20), &[_]R{ R.r(-100, -50), R.r(-40, -20), R.r(-10, 20), R.r(30, 40) }, {}, R.order),
    );
}

/// Returns the index of the first element in `items` greater than or equal to `key`,
/// or `items.len` if all elements are less than `key`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`.
///
/// O(log n) complexity.
pub fn lowerBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        const mid = left + (right - left) / 2;
        if (lessThan(context, items[mid], key)) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return left;
}

test lowerBound {
    const S = struct {
        fn lower_u32(context: void, lhs: u32, rhs: u32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_i32(context: void, lhs: i32, rhs: i32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_f32(context: void, lhs: f32, rhs: f32) bool {
            _ = context;
            return lhs < rhs;
        }
    };

    try testing.expectEqual(
        @as(usize, 0),
        lowerBound(u32, @as(u32, 0), &[_]u32{}, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 0),
        lowerBound(u32, @as(u32, 0), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 0),
        lowerBound(u32, @as(u32, 2), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        lowerBound(u32, @as(u32, 5), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        lowerBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        lowerBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        lowerBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 5),
        lowerBound(u32, @as(u32, 64), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        lowerBound(u32, @as(u32, 100), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        lowerBound(i32, @as(i32, 5), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(usize, 1),
        lowerBound(f32, @as(f32, -33.4), &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, {}, S.lower_f32),
    );
}

/// Returns the index of the first element in `items` greater than `key`,
/// or `items.len` if all elements are less than or equal to `key`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`.
///
/// O(log n) complexity.
pub fn upperBound(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        const mid = (right + left) / 2;
        if (!lessThan(context, key, items[mid])) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return left;
}

test upperBound {
    const S = struct {
        fn lower_u32(context: void, lhs: u32, rhs: u32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_i32(context: void, lhs: i32, rhs: i32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_f32(context: void, lhs: f32, rhs: f32) bool {
            _ = context;
            return lhs < rhs;
        }
    };

    try testing.expectEqual(
        @as(usize, 0),
        upperBound(u32, @as(u32, 0), &[_]u32{}, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 0),
        upperBound(u32, @as(u32, 0), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 1),
        upperBound(u32, @as(u32, 2), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        upperBound(u32, @as(u32, 5), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        upperBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 7, 7, 7, 7, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        upperBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 8, 8, 8, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 3),
        upperBound(u32, @as(u32, 8), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        upperBound(u32, @as(u32, 64), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 6),
        upperBound(u32, @as(u32, 100), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(usize, 2),
        upperBound(i32, @as(i32, 5), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(usize, 1),
        upperBound(f32, @as(f32, -33.4), &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, {}, S.lower_f32),
    );
}

/// Returns a tuple of the lower and upper indices in `items` between which all elements are equal to `key`.
/// If no element in `items` is equal to `key`, both indices are the
/// index of the first element in `items` greater than `key`.
/// If no element in `items` is greater than `key`, both indices equal `items.len`.
///
/// `items` must be sorted in ascending order with respect to `compareFn`.
///
/// O(log n) complexity.
///
/// See also: `lowerBound` and `upperBound`.
pub fn equalRange(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) bool,
) struct { usize, usize } {
    return .{
        lowerBound(T, key, items, context, lessThan),
        upperBound(T, key, items, context, lessThan),
    };
}

test equalRange {
    const S = struct {
        fn lower_u32(context: void, lhs: u32, rhs: u32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_i32(context: void, lhs: i32, rhs: i32) bool {
            _ = context;
            return lhs < rhs;
        }
        fn lower_f32(context: void, lhs: f32, rhs: f32) bool {
            _ = context;
            return lhs < rhs;
        }
    };

    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 0, 0 }),
        equalRange(i32, @as(i32, 0), &[_]i32{}, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 0, 0 }),
        equalRange(i32, @as(i32, 0), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 0, 1 }),
        equalRange(i32, @as(i32, 2), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 2, 2 }),
        equalRange(i32, @as(i32, 5), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 2, 3 }),
        equalRange(i32, @as(i32, 8), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 5, 6 }),
        equalRange(i32, @as(i32, 64), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 6, 6 }),
        equalRange(i32, @as(i32, 100), &[_]i32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 2, 6 }),
        equalRange(i32, @as(i32, 8), &[_]i32{ 2, 4, 8, 8, 8, 8, 15, 22 }, {}, S.lower_i32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 2, 2 }),
        equalRange(u32, @as(u32, 5), &[_]u32{ 2, 4, 8, 16, 32, 64 }, {}, S.lower_u32),
    );
    try testing.expectEqual(
        @as(struct { usize, usize }, .{ 1, 1 }),
        equalRange(f32, @as(f32, -33.4), &[_]f32{ -54.2, -26.7, 0.0, 56.55, 100.1, 322.0 }, {}, S.lower_f32),
    );
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
