const std = @import("std.zig");
const assert = std.debug.assert;
const sort = std.sort;
const mem = std.mem;
const math = std.math;
const testing = std.testing;

/// A convenient wrapper for nthElementContext that finds the nth smallest
/// element in a slice and places it at items[n].
///
/// This function modifies the order of the other elements in the slice. After execution,
/// all elements before items[n] will be less than or equal to items[n], and all
/// elements after items[n] will be greater than or equal to items[n].
///
/// This is a high-level wrapper that creates the necessary context for the
/// core nthElementContext implementation.
///
/// Parameters:
/// - T: The type of the elements in the slice.
/// - items: The slice of items to select from. The order of elements will be modified.
/// - n: The 0-based index of the element to find (e.g., 0 for the smallest, items.len - 1 for the largest).
/// - context: A user-provided context that will be passed to lessThanFn.
/// - lessThanFn: The comparison function that defines the ordering of elements.
pub fn nthElement(
    comptime T: type,
    items: []T,
    n: usize,
    context: anytype,
    comptime lessThanFn: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
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
    nthElementContext(n, 0, items.len, Context{ .items = items, .sub_ctx = context });
}

/// The core implementation of the nth-element search algorithm (Introselect).
/// It finds the element that would be at index a + n if the sub-slice [a..b) were sorted.
///
/// This function operates on a sub-slice of a collection managed by the context
/// and modifies the slice in-place. After execution, the nth smallest element is
/// guaranteed to be at index a + n, with all preceding elements being less than or
/// equal to it, and all succeeding elements being greater than or equal to it.
///
/// The algorithm is a hybrid:
/// 1.  Quicksort-like partitioning: It uses a recursive partitioning strategy
///     to narrow down the search space.
/// 2.  Insertion Sort: For very small sub-slices, it switches to insertion sort,
///     which is more efficient for small inputs.
/// 3.  Heapsort Fallback: To guard against worst-case O(n^2) performance on
///     pathological inputs, it tracks recursion depth.
///     If the depth limit is exceeded, it switches to heapSelectContext, which
///     has a guaranteed O(n log n) worst-case time complexity.
///
/// Parameters:
/// - n: The 0-based index of the element to find, relative to the start of the sub-slice.
/// - a: The starting index of the sub-slice to search within.
/// - b: The exclusive end index of the sub-slice.
/// - context: An object providing lessThan(i, j) and swap(i, j) methods.
pub fn nthElementContext(n: usize, a: usize, b: usize, context: anytype) void {
    // very short slices get sorted using insertion sort.
    const max_insertion = 8;
    assert(a < b);
    const len = b - a;
    assert(n < len);
    var left: usize = a;
    var right: usize = b;
    var depth_limit: usize = math.log2_int(usize, len) * 2; // This is what C++ std::nth_element does.
    while (right > left) {
        if (right - left <= max_insertion) {
            sort.insertionContext(left, right, context);
            break;
        }
        if (depth_limit == 0) {
            heapSelectContext(n - (left - a), left, right, context);
            break;
        }
        depth_limit -= 1;
        var pivot: usize = 0;
        chosePivot(left, right, &pivot, context);
        // if the chosen pivot is equal to the predecessor, then it's the smallest element in the
        // slice. Partition the slice into elements equal to and elements greater than the pivot.
        // This case is usually hit when the slice contains many duplicate elements.
        if (left > a and !context.lessThan(left - 1, pivot)) {
            left = partitionEqual(left, right, pivot, context);
            continue;
        }
        partition(left, right, &pivot, context);
        const target = a + n;
        if (pivot == target) {
            break;
        } else if (pivot > target) {
            right = pivot;
        } else {
            left = pivot + 1;
        }
    }
}

/// A convenient wrapper for `heapSelectContext`. It creates the appropriate
/// context for a given slice and less-than function. After execution, the
/// nth smallest element of `items` will be at `items[n]`.
///
/// Parameters:
/// - T: The type of the elements in the slice.
/// - items: The slice of items to select from.
/// - n: The 0-based index of the element to find (0 for smallest, 1 for 2nd smallest, etc.).
/// - context: A user-provided context to be passed to `lessThanFn`.
/// - lessThanFn: The comparison function.
pub fn heapSelect(
    comptime T: type,
    items: []T,
    n: usize,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), lhs: T, rhs: T) bool,
) void {
    // A local struct to adapt the user's slice and functions to the
    // index-based interface required by `heapSelectContext`.
    const Context = struct {
        items: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), i: usize, j: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[i], ctx.items[j]);
        }

        pub fn swap(ctx: @This(), i: usize, j: usize) void {
            return mem.swap(T, &ctx.items[i], &ctx.items[j]);
        }
    };

    // Create an instance of the context and call the core selection function.
    heapSelectContext(n, 0, items.len, Context{ .items = items, .sub_ctx = context });
}

/// heapSelectContext finds the nth smallest element within a slice defined by indices [a, b).
/// The result (the nth smallest element) will be placed at index `a + n` of the underlying
/// collection managed by the context.
///
/// This function modifies the order of elements in the slice.
///
/// Parameters:
/// - n: The 0-based index of the element to find in the sorted version of the slice (0 for smallest, 1 for 2nd smallest, etc.).
/// - a: The starting index of the slice.
/// - b: The exclusive end index of the slice.
/// - context: An object with `lessThan(i, j)` and `swap(i, j)` methods.
pub fn heapSelectContext(n: usize, a: usize, b: usize, context: anytype) void {
    assert(a < b);
    const len = b - a;
    assert(n < len);
    const n_largest = len - n;
    // build the heap in linear time.
    var i = a + (b - a) / 2;
    while (i > a) {
        i -= 1;
        siftDown(a, i, b, context);
    }

    var heap_end = b;
    i = 0;
    while (i < n_largest - 1) : (i += 1) {
        heap_end -= 1;
        context.swap(a, heap_end);
        siftDown(a, a, heap_end, context);
    }

    // After the loop, the root of the heap (at index `a`) is the nth smallest element.
    // We swap it into the correct position `a + n`.
    if (len > 0) {
        context.swap(a, a + n);
    }
}

/// Calculates the median of a slice using the nthElement function.
/// For slices with an odd number of elements, it returns the middle element.
/// For slices with an even number of elements, it returns the mean of the two central elements.
/// The result from integer types is rounded towards zero, while for floating-point types it is the exact mean.
/// This function modifies the order of elements in the slice.
pub fn median(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (context: @TypeOf(context), lhs: T, rhs: T) bool,
) T {
    const len = items.len;
    assert(len > 0); // Ensure the slice is not empty.
    const mid = len / 2;
    if (len % 2 == 1) {
        nthElement(T, items, mid, context, lessThanFn);
        return items[mid];
    }
    nthElement(T, items, mid - 1, context, lessThanFn);
    const lower_median = items[mid - 1];
    var upper_median = items[mid];
    var i = mid + 1;
    while (i < len) : (i += 1) {
        if (lessThanFn(context, items[i], upper_median)) {
            upper_median = items[i];
        }
    }
    return switch (@typeInfo(T)) {
        .int => @divTrunc((lower_median + upper_median), 2),
        .float => (lower_median + upper_median) / 2,
        else => @compileError("Unsupported type for median: " ++ @typeName(T)),
    };
}

/// partitions `items[a..b]` into elements smaller than `items[pivot]`,
/// followed by elements greater than or equal to `items[pivot]`.
///
/// sets the new pivot.
fn partition(a: usize, b: usize, pivot: *usize, context: anytype) void {
    // move pivot to the first place
    context.swap(a, pivot.*);
    var i = a + 1;
    var j = b - 1;
    while (true) {
        while (i <= j and context.lessThan(i, a)) i += 1;
        while (i <= j and !context.lessThan(j, a)) j -= 1;
        if (i > j) break;
        context.swap(i, j);
        i += 1;
        j -= 1;
    }
    context.swap(j, a);
    pivot.* = j;
}

/// partitions items into elements equal to `items[pivot]`
/// followed by elements greater than `items[pivot]`.
///
/// it assumed that `items[a..b]` does not contain elements smaller than the `items[pivot]`.
fn partitionEqual(a: usize, b: usize, pivot: usize, context: anytype) usize {
    // move pivot to the first place
    context.swap(a, pivot);

    var i = a + 1;
    var j = b - 1;

    while (true) {
        while (i <= j and !context.lessThan(a, i)) i += 1;
        while (i <= j and context.lessThan(a, j)) j -= 1;
        if (i > j) break;

        context.swap(i, j);
        i += 1;
        j -= 1;
    }

    return i;
}

/// chooses a pivot in `items[a..b]`.
/// It's modeled directly after the `chosePivot` function in `std.sort`.
fn chosePivot(a: usize, b: usize, pivot: *usize, context: anytype) void {
    // minimum length for using the Tukey's ninther method
    const shortest_ninther = 50;
    const len = b - a;
    const i = a + len / 4 * 1;
    const j = a + len / 4 * 2;
    const k = a + len / 4 * 3;

    if (len >= 8) {
        if (len >= shortest_ninther) {
            // find medians in the neighborhoods of `i`, `j` and `k`
            sort3(i - 1, i, i + 1, context);
            sort3(j - 1, j, j + 1, context);
            sort3(k - 1, k, k + 1, context);
        }

        // find the median among `i`, `j` and `k` and stores it in `j`
        sort3(i, j, k, context);
    }

    pivot.* = j;
}

fn sort3(a: usize, b: usize, c: usize, context: anytype) void {
    if (context.lessThan(b, a)) {
        context.swap(b, a);
    }

    if (context.lessThan(c, b)) {
        context.swap(c, b);
    }

    if (context.lessThan(b, a)) {
        context.swap(b, a);
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

// Tests

const select_funcs = &[_]fn (comptime type, anytype, anytype, anytype, comptime anytype) void{
    nthElement,
    heapSelect,
};

const context_select_funcs = &[_]fn (usize, usize, usize, anytype) void{
    nthElementContext,
    heapSelectContext,
};

test "select" {
    const asc_u8 = sort.asc(u8);
    const asc_i32 = sort.asc(i32);

    const u8cases = [_][]const []const u8{
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

    inline for (select_funcs) |selectFn| {
        for (u8cases) |case| {
            var buf: [20]u8 = undefined;
            const slice = buf[0..case[0].len];
            const mid = slice.len / 2;
            @memcpy(slice, case[0]);
            selectFn(u8, slice, mid, {}, asc_u8);
            try testing.expectEqual(slice[mid], case[1][mid]);
        }

        for (i32cases) |case| {
            var buf: [20]i32 = undefined;
            const slice = buf[0..case[0].len];
            const mid = slice.len / 2;
            @memcpy(slice, case[0]);
            selectFn(i32, slice, mid, {}, asc_i32);
            try testing.expectEqual(slice[mid], case[1][mid]);
        }
    }
}

test "select descending" {
    const desc_i32 = sort.desc(i32);

    const rev_cases = [_][]const []const i32{
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

    inline for (select_funcs) |selectFn| {
        for (rev_cases) |case| {
            var buf: [8]i32 = undefined;
            const slice = buf[0..case[0].len];
            const mid = slice.len / 2;
            @memcpy(slice, case[0]);
            selectFn(i32, slice, mid, {}, desc_i32);
            try testing.expectEqual(slice[mid], case[1][mid]);
        }
    }
}

test "median odd length" {
    var items = [_]i32{ 1, 3, 2, 5, 4 }; // sorted: 1, 2, 3, 4, 5 -> median 3
    const m = median(i32, &items, {}, sort.asc(i32));
    try testing.expectEqual(3, m);
}

test "median even length" {
    var items = [_]u32{ 1, 3, 2, 5, 4, 6 }; // sorted: 1, 2, 3, 4, 5, 6 -> median (3+4)/2 = 3.5
    const m = median(u32, &items, {}, sort.asc(u32));
    try testing.expectEqual(3, m);
}

test "median even length negative" {
    var items = [_]i32{ -1, -3, -2, -5, -4, -6 }; // sorted: 1, 2, 3, 4, 5, 6 -> median (3+4)/2 = 3.5
    const m = median(i32, &items, {}, sort.asc(i32));
    try testing.expectEqual(-3, m);
}

test "median odd length float" {
    var items = [_]f64{ 1.1, 3.3, 2.2, 5.5, 4.4 }; // sorted: 1.1, 2.2, 3.3, 4.4, 5.5 -> median 3.3
    const m = median(f64, &items, {}, sort.asc(f64));
    try testing.expectEqual(3.3, m);
}

test "median even length float" {
    var items = [_]f32{ 1.1, 3.3, 2.2, 5.5, 4.4, 6.6 }; // sorted: 1.1, 2.2, 3.3, 4.4, 5.5, 6.6 -> median (3.3+4.4)/2 = 3.85
    const m = median(f32, &items, {}, sort.asc(f32));
    try testing.expectApproxEqRel(3.85, m, 0.00001);
}
