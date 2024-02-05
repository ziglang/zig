const builtin = @import("builtin");

test "comptime slice-sentinel in bounds (unterminated)" {
    // array
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // ptr_array
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @as([*]u8, @ptrCast(&buf));
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @as([*c]u8, @ptrCast(&buf));
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // slice
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }
}

test "comptime slice-sentinel in bounds (end,unterminated)" {
    // array
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // ptr_array
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target = &buf;
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*]u8 = @as([*]u8, @ptrCast(&buf));
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*c]u8 = @as([*c]u8, @ptrCast(&buf));
        const slice = target[0..13 :0xff];
        _ = slice;
    }

    // slice
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..13 :0xff];
        _ = slice;
    }
}

test "comptime slice-sentinel in bounds (terminated)" {
    // array
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // ptr_array
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @as([*]u8, @ptrCast(&buf));
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @as([*c]u8, @ptrCast(&buf));
        const slice = target[0..3 :'d'];
        _ = slice;
    }

    // slice
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..3 :'d'];
        _ = slice;
    }
}

test "comptime slice-sentinel in bounds (on target sentinel)" {
    // array
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..14 :0];
        _ = slice;
    }

    // ptr_array
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @as([*]u8, @ptrCast(&buf));
        const slice = target[0..14 :0];
        _ = slice;
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @as([*c]u8, @ptrCast(&buf));
        const slice = target[0..14 :0];
        _ = slice;
    }

    // slice
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }
}
