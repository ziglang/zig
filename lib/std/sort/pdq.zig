const std = @import("../std.zig");
const sort = std.sort;
const mem = std.mem;
const math = std.math;
const testing = std.testing;

/// Unstable in-place sort. Sorts in ascending order with respect to `lessThanFn`.
/// Computational complexity: O(n) best case, O(n*log(n)) worst case and average case.
/// Memory complexity: O(log(n)) (no allocator required).
pub fn pdq(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) void {
    const Context = struct {
        items: [*]T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
        }

        pub fn swap(ctx: @This(), a: usize, b: usize) void {
            return mem.swap(T, &ctx.items[a], &ctx.items[b]);
        }
    };
    pdqContext(0, items.len, Context{ .items = items.ptr, .sub_ctx = context });
}

const Hint = enum {
    increasing,
    decreasing,
    unknown,
};

/// Unstable in-place sort. Sorts in ascending order with respect to `lessThan`.
/// `context` must have methods `swap` and `lessThan`, with the following signatures:
/// ```
/// pub fn swap(self: Context, lhs: usize, rhs: usize) void
/// pub fn lessThan(self: Context, lhs: usize, rhs: usize) bool
/// ```
/// `lhs` and `rhs` represent the indexes of the elements.
///
/// Computational complexity: O(n) best case, O(n*log(n)) worst case and average case.
/// Memory complexity: O(log(n)) (no allocator required).
pub fn pdqContext(a: usize, b: usize, context: anytype) void {
    // slices of up to this length get sorted using insertion sort.
    const max_insertion = 24;
    // number of allowed imbalanced partitions before switching to heap sort.
    const max_limit = std.math.floorPowerOfTwo(usize, b - a) + 1;

    // set upper bound on stack memory usage.
    const Range = struct { a: usize, b: usize, limit: usize };
    const stack_size = math.log2(math.maxInt(usize) + 1);
    var stack: [stack_size]Range = undefined;
    var range = Range{ .a = a, .b = b, .limit = max_limit };
    var top: usize = 0;

    while (true) {
        var was_balanced = true;
        var was_partitioned = true;

        while (true) {
            const len = range.b - range.a;

            // very short slices get sorted using insertion sort.
            if (len <= max_insertion) {
                break sort.insertionContext(range.a, range.b, context);
            }

            // if too many bad pivot choices were made, simply fall back to heapsort in order to
            // guarantee O(n*log(n)) worst-case.
            if (range.limit == 0) {
                break sort.heapContext(range.a, range.b, context);
            }

            // if the last partitioning was imbalanced, try breaking patterns in the slice by shuffling
            // some elements around. Hopefully we'll choose a better pivot this time.
            if (!was_balanced) {
                breakPatterns(range.a, range.b, context);
                range.limit -= 1;
            }

            // choose a pivot and try guessing whether the slice is already sorted.
            var pivot: usize = 0;
            var hint = chosePivot(range.a, range.b, &pivot, context);

            if (hint == .decreasing) {
                // The maximum number of swaps was performed, so items are likely
                // in reverse order. Reverse it to make sorting faster.
                reverseRange(range.a, range.b, context);
                pivot = (range.b - 1) - (pivot - range.a);
                hint = .increasing;
            }

            // if the last partitioning was decently balanced and didn't shuffle elements, and if pivot
            // selection predicts the slice is likely already sorted...
            if (was_balanced and was_partitioned and hint == .increasing) {
                // try identifying several out-of-order elements and shifting them to correct
                // positions. If the slice ends up being completely sorted, we're done.
                if (partialInsertionSort(range.a, range.b, context)) break;
            }

            // if the chosen pivot is equal to the predecessor, then it's the smallest element in the
            // slice. Partition the slice into elements equal to and elements greater than the pivot.
            // This case is usually hit when the slice contains many duplicate elements.
            if (range.a > a and !context.lessThan(range.a - 1, pivot)) {
                range.a = partitionEqual(range.a, range.b, pivot, context);
                continue;
            }

            // partition the slice.
            var mid = pivot;
            was_partitioned = partition(range.a, range.b, &mid, context);

            const left_len = mid - range.a;
            const right_len = range.b - mid;
            const balanced_threshold = len / 8;
            if (left_len < right_len) {
                was_balanced = left_len >= balanced_threshold;
                stack[top] = .{ .a = range.a, .b = mid, .limit = range.limit };
                top += 1;
                range.a = mid + 1;
            } else {
                was_balanced = right_len >= balanced_threshold;
                stack[top] = .{ .a = mid + 1, .b = range.b, .limit = range.limit };
                top += 1;
                range.b = mid;
            }
        }

        top = math.sub(usize, top, 1) catch break;
        range = stack[top];
    }
}

const TestContext = struct {
    data: [*]usize,
    pub fn swap(self: @This(), lhs: usize, rhs: usize) void {
        std.mem.swap(usize, &self.data[lhs], &self.data[rhs]);
    }
    pub fn lessThan(self: @This(), lhs: usize, rhs: usize) bool {
        return self.data[lhs] < self.data[rhs];
    }
    pub fn testPdq(comptime data: []const usize, expected: []const usize) !void {
        var actual = data[0..].*;
        pdqContext(0, actual.len, TestContext{ .data = &actual });
        try testing.expectEqualSlices(usize, expected, &actual);
    }
};
test "pdqContext empty" {
    try TestContext.testPdq(&.{}, &.{});
}
test "pdqContext already partitioned" {
    try TestContext.testPdq(&.{0}, &.{0});
    try TestContext.testPdq(&.{ 0, 1 }, &.{ 0, 1 });
    try TestContext.testPdq(&.{ 0, 1, 2, 3, 4, 5, 6, 7 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7 });
    // pdq changes strategy depending on the number of elements, so we need to use long lists
    try TestContext.testPdq(&.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 });
    try TestContext.testPdq(&.{ 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 30, 30 }, &.{ 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 30, 30 });
    try TestContext.testPdq(&.{ 7, 6, 5, 4, 3, 2, 1, 0 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7 });
}
test pdqContext {
    try TestContext.testPdq(&.{ 1, 0 }, &.{ 0, 1 });
    try TestContext.testPdq(&.{ 1, 2, 2, 1, 1 }, &.{ 1, 1, 1, 2, 2 });
    try TestContext.testPdq(&.{ 3, 5, 1, 2, 7, 6, 4 }, &.{ 1, 2, 3, 4, 5, 6, 7 });
    // pdq changes strategy depending on the number of elements, so we need to use long lists
    try TestContext.testPdq(&.{ 3, 5, 1, 2, 7, 6, 4, 5, 1, 2, 1, 2, 7, 6, 4, 5, 1, 2, 3, 5, 1, 2, 7, 6, 4, 5, 1, 2, 1, 2, 7, 6, 4, 5, 1, 2 }, &.{ 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7 });
    try TestContext.testPdq(&.{ 7, 6, 5, 4, 3, 2, 1, 0 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7 });
    try TestContext.testPdq(&.{ 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 }, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 });
    try TestContext.testPdq(&.{ 30, 30, 29, 29, 28, 28, 27, 27, 26, 26, 25, 25, 24, 24, 23, 23, 22, 22, 21, 21, 20, 20, 19, 19, 18, 18, 17, 17, 16, 16, 15, 15, 14, 14, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0 }, &.{ 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 30, 30 });
}

/// partitions `items[a..b]` into elements smaller than `items[pivot.*]`,
/// followed by elements greater than or equal to `items[pivot.*]`.
///
/// sets the new pivot.
/// returns `true` if already partitioned.
fn partition(a: usize, b: usize, pivot: *usize, context: anytype) bool {
    std.debug.assert(a < b);

    // move pivot to the first place
    context.swap(a, pivot.*);
    const Helper = struct {
        i: usize,
        j: usize,
        target: usize,
        context: @TypeOf(context),

        fn converge(self: *@This()) bool {
            self.i += 1;
            self.j -= 1;
            while (self.i <= self.j and self.context.lessThan(self.i, self.target)) self.i += 1;
            while (self.i <= self.j and !self.context.lessThan(self.j, self.target)) self.j -= 1;
            return self.i > self.j;
        }
    };

    var helper: Helper = .{
        .i = a,
        .j = b,
        .target = a,
        .context = context,
    };

    defer {
        // put pivot back in the middle
        context.swap(helper.j, helper.target);
        pivot.* = helper.j;
    }

    // check if items are already partitioned (no item to swap)
    if (helper.converge()) return true;

    while (true) {
        helper.context.swap(helper.i, helper.j);
        if (helper.converge()) return false;
    }
}

test partition {
    const helper = struct {
        pub fn call(comptime data: []const usize, pivot: usize, expected_pivot: usize) !void {
            var actual = data[0..].*;
            var actual_pivot = pivot;
            const already_partitioned = partition(
                0,
                data.len,
                &actual_pivot,
                TestContext{ .data = &actual },
            );
            try testing.expectEqual(expected_pivot, actual_pivot);
            try testing.expect(!already_partitioned);
            for (actual[0..actual_pivot]) |v| {
                try testing.expect(v < data[pivot]);
            }
            for (actual[actual_pivot..]) |v| {
                try testing.expect(v >= data[pivot]);
            }
        }
    }.call;
    try helper(&.{ 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 }, 2, 7);
    try helper(&.{ 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 }, 9, 4);
    try helper(&.{ 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 }, 0, 5);
    //try helper(&.{ 2, 1, 1, 1, 3, 3 }, 0, 3);
    try helper(&.{ 1, 1, 1, 3, 3, 2 }, 5, 3);
    //try helper(&.{ 1, 0 }, 0, 1);
}
test "partition already partitioned" {
    const helper = struct {
        pub fn call(comptime data: []const usize, pivot: usize) !void {
            var actual = data[0..].*;
            var actual_pivot = pivot;
            const already_partitioned = partition(
                0,
                data.len,
                &actual_pivot,
                TestContext{ .data = &actual },
            );
            try testing.expectEqual(pivot, actual_pivot);
            try testing.expect(already_partitioned);
            try testing.expectEqualSlices(usize, data, &actual);
        }
    }.call;
    try helper(&.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 0);
    try helper(&.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 2);
    try helper(&.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 9);
    try helper(&.{ 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 }, 0);
    try helper(&.{ 0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 }, 4);
    try helper(&.{ 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, 18);
}

/// Partitions items into elements equal to `items[pivot]`
/// followed by elements greater than `items[pivot]`.
/// Returns the index to first element that is greater than `items[pivot]`,
/// or `b` if no item is greater than `items[pivot]`.
/// It is assumed that `items[a..b]` does not contain elements smaller than `items[pivot]`.
fn partitionEqual(a: usize, b: usize, pivot: usize, context: anytype) usize {
    std.debug.assert(a < b);

    // move pivot to the first place
    context.swap(a, pivot);

    var i = a;
    var j = b;

    while (true) {
        i += 1;
        j -= 1;
        while (i <= j and !context.lessThan(a, i)) i += 1;

        // Since `context.lessThan(a, a) == false`, `j` can never
        // go out of bounds.
        while (context.lessThan(a, j)) j -= 1;

        if (i > j) return i;
        context.swap(i, j);
    }
}
test partitionEqual {
    const helper = struct {
        pub fn call(comptime data: []const usize, pivot: usize, expected_first_greater: usize) !void {
            var actual = data[0..].*;
            const actual_first_greater = partitionEqual(
                0,
                data.len,
                pivot,
                TestContext{ .data = &actual },
            );
            try testing.expectEqual(expected_first_greater, actual_first_greater);
            for (actual[0..expected_first_greater]) |v| {
                try testing.expect(v == data[pivot]);
            }
            for (actual[expected_first_greater..]) |v| {
                try testing.expect(v > data[pivot]);
            }
        }
    }.call;
    try helper(&.{ 4, 2 }, 1, 1);
    try helper(&.{ 2, 2, 4, 3, 2 }, 0, 3);
    try helper(&.{ 4, 2, 2, 4, 3, 2 }, 5, 3);
}
test "partitionEqual already partitioned" {
    const helper = struct {
        pub fn call(comptime data: []const usize, pivot: usize, expected_first_greater: usize) !void {
            var actual = data[0..].*;
            const actual_first_greater = partitionEqual(
                0,
                data.len,
                pivot,
                TestContext{ .data = &actual },
            );
            try testing.expectEqual(expected_first_greater, actual_first_greater);
            for (actual[0..actual_first_greater]) |v| {
                try testing.expect(v == data[pivot]);
            }
            for (actual[actual_first_greater..]) |v| {
                try testing.expect(v > data[pivot]);
            }
        }
    }.call;
    try helper(&.{ 2, 3 }, 0, 1);
    try helper(&.{ 2, 2, 2 }, 0, 3);
    try helper(&.{ 2, 2, 2 }, 1, 3);
    try helper(&.{ 2, 2, 2 }, 2, 3);
    try helper(&.{ 2, 2, 2, 3, 4, 4 }, 0, 3);
    try helper(&.{ 2, 2, 2, 3, 4, 4 }, 1, 3);
}

/// partially sorts a slice by shifting several out-of-order elements around.
///
/// returns `true` if the slice is sorted at the end. This function is `O(n)` worst-case.
fn partialInsertionSort(a: usize, b: usize, context: anytype) bool {
    @branchHint(.cold);

    // maximum number of adjacent out-of-order pairs that will get shifted
    const max_steps = 5;
    // if the slice is shorter than this, don't shift any elements
    const shortest_shifting = 50;

    var i = a + 1;
    for (0..max_steps) |_| {
        // find the next pair of adjacent out-of-order elements.
        while (i < b and !context.lessThan(i, i - 1)) i += 1;

        // are we done?
        if (i == b) return true;

        // don't shift elements on short arrays, that has a performance cost.
        if (b - a < shortest_shifting) return false;

        // swap the found pair of elements. This puts them in correct order.
        context.swap(i, i - 1);

        // shift the smaller element to the left.
        if (i - a >= 2) {
            var j = i - 1;
            while (j >= 1) : (j -= 1) {
                if (!context.lessThan(j, j - 1)) break;
                context.swap(j, j - 1);
            }
        }

        // shift the greater element to the right.
        if (b - i >= 2) {
            var j = i + 1;
            while (j < b) : (j += 1) {
                if (!context.lessThan(j, j - 1)) break;
                context.swap(j, j - 1);
            }
        }
    }

    return false;
}

fn breakPatterns(a: usize, b: usize, context: anytype) void {
    @branchHint(.cold);

    const len = b - a;
    if (len < 8) return;

    var rand = @as(u64, @intCast(len));
    const modulus = math.ceilPowerOfTwoAssert(u64, len);

    var i = a + (len / 4) * 2 - 1;
    while (i <= a + (len / 4) * 2 + 1) : (i += 1) {
        // xorshift64
        rand ^= rand << 13;
        rand ^= rand >> 7;
        rand ^= rand << 17;

        var other = @as(usize, @intCast(rand & (modulus - 1)));
        if (other >= len) other -= len;
        context.swap(i, a + other);
    }
}

/// chooses a pivot in `items[a..b]`.
/// swaps likely_sorted when `items[a..b]` seems to be already sorted.
fn chosePivot(a: usize, b: usize, pivot: *usize, context: anytype) Hint {
    // minimum length for using the Tukey's ninther method
    const shortest_ninther = 50;
    // max_swaps is the maximum number of swaps allowed in this function
    const max_swaps = 4 * 3;

    const len = b - a;
    const i = a + len / 4 * 1;
    const j = a + len / 4 * 2;
    const k = a + len / 4 * 3;
    var swaps: usize = 0;

    if (len >= 8) {
        if (len >= shortest_ninther) {
            // find medians in the neighborhoods of `i`, `j` and `k`
            sort3(i - 1, i, i + 1, &swaps, context);
            sort3(j - 1, j, j + 1, &swaps, context);
            sort3(k - 1, k, k + 1, &swaps, context);
        }

        // find the median among `i`, `j` and `k` and stores it in `j`
        sort3(i, j, k, &swaps, context);
    }

    pivot.* = j;
    return switch (swaps) {
        0 => .increasing,
        max_swaps => .decreasing,
        else => .unknown,
    };
}

fn sort3(a: usize, b: usize, c: usize, swaps: *usize, context: anytype) void {
    if (context.lessThan(b, a)) {
        swaps.* += 1;
        context.swap(b, a);
    }

    if (context.lessThan(c, b)) {
        swaps.* += 1;
        context.swap(c, b);
    }

    if (context.lessThan(b, a)) {
        swaps.* += 1;
        context.swap(b, a);
    }
}

fn reverseRange(a: usize, b: usize, context: anytype) void {
    var i = a;
    var j = b - 1;
    while (i < j) {
        context.swap(i, j);
        i += 1;
        j -= 1;
    }
}
