const T = extern struct {
    a: usize = 1,
    b: u32 = 0,
    c: [4]u16 = .{ 2, 3, 4, 5 },
};
const S = extern struct {
    a: usize = 1,
    b: T = .{},
    c: [4]u8 = .{ 2, 3, 4, 5 },
};
var mem1: [2]S = .{ .{}, .{} };
const mem2: [2]S = .{ .{}, .{} };
comptime {
    const ptr1: [*]usize = @ptrCast(&mem1);
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const slice1: []usize = ptr1[0..len1];
    _ = ptr1[slice1.len + 1 ..];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const ptr2: [*]const u32 = @ptrCast(ptr1[2..]);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const slice2: []const u32 = ptr2[0..len2];
    _ = ptr2[slice2.len + 1 ..];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const ptr3: [*]u8 = @ptrCast(ptr2[1..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const slice3: []u8 = ptr3[0..len3];
    _ = ptr3[slice3.len + 1 ..];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const ptr4: [*]const u16 = @ptrCast(&mem4[0].b.c[2]);
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const slice4: []const u16 = ptr4[0..len4];
    _ = ptr4[slice4.len + 1 ..];
}
comptime {
    var mem5: comptime_int = 0;
    const ptr5: [*]comptime_int = @ptrCast(&mem5);
    const slice5: []comptime_int = ptr5[0..1];
    _ = ptr5[slice5.len + 1 ..];
}
comptime {
    const ptr1: [*]usize = @ptrCast(&mem1);
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const slice1: []usize = ptr1[0..len1];
    _ = ptr1[0 .. slice1.len + 1];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const ptr2: [*]const u32 = @ptrCast(ptr1[2..]);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const slice2: []const u32 = ptr2[0..len2];
    _ = ptr2[0 .. slice2.len + 1];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const ptr3: [*]u8 = @ptrCast(ptr2[1..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const slice3: []u8 = ptr3[0..len3];
    _ = ptr3[0 .. slice3.len + 1];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const ptr4: [*]const u16 = @ptrCast(&mem4[0].b.c[2]);
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const slice4: []const u16 = ptr4[0..len4];
    _ = ptr4[0 .. slice4.len + 1];
}
comptime {
    var mem5: comptime_int = 0;
    const ptr5: [*]comptime_int = @ptrCast(&mem5);
    const slice5: []comptime_int = ptr5[0..1];
    _ = ptr5[0 .. slice5.len + 1];
}
comptime {
    const ptr1: [*]usize = @ptrCast(&mem1);
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const slice1: []usize = ptr1[0..len1];
    _ = ptr1[0..slice1.len :0];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const ptr2: [*]const u32 = @ptrCast(ptr1[2..]);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const slice2: []const u32 = ptr2[0..len2];
    _ = ptr2[0..slice2.len :0];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const ptr3: [*]u8 = @ptrCast(ptr2[1..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const slice3: []u8 = ptr3[0..len3];
    _ = ptr3[0..slice3.len :0];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const ptr4: [*]const u16 = @ptrCast(&mem4[0].b.c[2]);
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const slice4: []const u16 = ptr4[0..len4];
    _ = ptr4[0..slice4.len :0];
}
comptime {
    var mem5: comptime_int = 0;
    const ptr5: [*]comptime_int = @ptrCast(&mem5);
    const slice5: []comptime_int = ptr5[0..1];
    _ = ptr5[0..slice5.len :0];
}
// The following features/tests will become the responsibility of `@ptrCast`.
comptime {
    var mem6: comptime_int = 0;
    const ptr6: [*]type = @ptrCast(&mem6);
    _ = ptr6[0..1];
}
comptime {
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const ptr1: *const [len1 + 1]usize = @ptrCast(&mem1);
    _ = ptr1[len1 + 1 ..];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const ptr2: *const [len2 + 1]u32 = @ptrCast(ptr1[2..]);
    _ = ptr2[len2 + 1 ..];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const ptr3: *const [len3 + 1]u8 = @ptrCast(ptr2[1..]);
    _ = ptr3[len3 + 1 ..];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const ptr4: *const [len4 + 1]u16 = @ptrCast(&mem4[0].b.c[2]);
    _ = ptr4[len4 + 1 ..];
}
comptime {
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const ptr1: *const [len1 + 1]usize = @ptrCast(&mem1);
    _ = ptr1[0 .. len1 + 1];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const ptr2: *const [len2 + 1]u32 = @ptrCast(ptr1[2..]);
    _ = ptr2[0 .. len2 + 1];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const ptr3: *const [len3 + 1]u8 = @ptrCast(ptr2[1..]);
    _ = ptr3[0 .. len3 + 1];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const ptr4: *const [len4 + 1]u16 = @ptrCast(&mem4[0].b.c[2]);
    _ = ptr4[0 .. len4 + 1];
}
comptime {
    const len1: usize = (2 * @sizeOf(S)) / @sizeOf(usize);
    const ptr1: *const [len1 + 1]usize = @ptrCast(&mem1);
    _ = ptr1[0..len1 :0];
}
comptime {
    const ptr1: [*]const usize = @ptrCast(&mem2);
    const len2: usize = ((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) / @sizeOf(u32);
    const ptr2: *const [len2 + 1]u32 = @ptrCast(ptr1[2..]);
    _ = ptr2[0..len2 :0];
}
comptime {
    var mem3: [2]S = .{ .{}, .{} };
    const ptr1: [*]usize = @ptrCast(&mem3);
    const ptr2: [*]u32 = @ptrCast(ptr1[2..]);
    const len3: usize = (((2 * @sizeOf(S)) - 2 * @sizeOf(usize)) - @sizeOf(u32)) / @sizeOf(u8);
    const ptr3: *const [len3 + 1]u8 = @ptrCast(ptr2[1..]);
    _ = ptr3[0..len3 :0];
}
comptime {
    const mem4: [2]S = .{ .{}, .{} };
    const len4: usize = ((2 * @sizeOf(S)) - (@offsetOf(S, "b") + @offsetOf(T, "c") + (2 * @sizeOf(u16)))) / @sizeOf(u16);
    const ptr4: *const [len4 + 1]u16 = @ptrCast(&mem4[0].b.c[2]);
    _ = ptr4[0..len4 :0];
}

// error
//
// :17:25: error: slice start index out of bounds of containing declaration: start 11, length 10
// :24:25: error: slice start index out of bounds of containing declaration: start 17, length 16
// :33:25: error: slice start index out of bounds of containing declaration: start 61, length 60
// :40:25: error: slice start index out of bounds of containing declaration: start 29, length 28
// :46:25: error: slice start index out of bounds of containing declaration: start 2, length 1
// :52:30: error: slice end index out of bounds of containing declaration: end 11, length 10
// :59:30: error: slice end index out of bounds of containing declaration: end 17, length 16
// :68:30: error: slice end index out of bounds of containing declaration: end 61, length 60
// :75:30: error: slice end index out of bounds of containing declaration: end 29, length 28
// :81:30: error: slice end index out of bounds of containing declaration: end 2, length 1
// :87:29: error: slice sentinel index out of bounds of containing declaration: index 10, length 10
// :94:29: error: slice sentinel index out of bounds of containing declaration: index 16, length 16
// :103:29: error: slice sentinel index out of bounds of containing declaration: index 60, length 60
// :110:29: error: slice sentinel index out of bounds of containing declaration: index 28, length 28
// :116:29: error: slice sentinel index out of bounds of containing declaration: index 1, length 1
// :122:13: error: cannot reinterpret memory of type 'comptime_int' as element type 'type'
// :127:9: error: invalid reference: stated length 11, actual length 10
// :133:9: error: invalid reference: stated length 17, actual length 16
// :141:9: error: invalid reference: stated length 61, actual length 60
// :147:9: error: invalid reference: stated length 29, actual length 28
// :152:9: error: invalid reference: stated length 11, actual length 10
// :158:9: error: invalid reference: stated length 17, actual length 16
// :166:9: error: invalid reference: stated length 61, actual length 60
// :172:9: error: invalid reference: stated length 29, actual length 28
// :177:9: error: invalid reference: stated length 11, actual length 10
// :183:9: error: invalid reference: stated length 17, actual length 16
// :191:9: error: invalid reference: stated length 61, actual length 60
// :197:9: error: invalid reference: stated length 29, actual length 28
