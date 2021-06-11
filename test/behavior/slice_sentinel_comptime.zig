test "comptime slice-sentinel in bounds (unterminated)" {
    // array
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..3 :'d'];
    }

    // ptr_array
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..3 :'d'];
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..3 :'d'];
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast([*]u8, &buf);
        const slice = target[0..3 :'d'];
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..3 :'d'];
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast([*c]u8, &buf);
        const slice = target[0..3 :'d'];
    }

    // slice
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..3 :'d'];
    }
}

test "comptime slice-sentinel in bounds (end,unterminated)" {
    // array
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        const slice = target[0..13 :0xff];
    }

    // ptr_array
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target = &buf;
        const slice = target[0..13 :0xff];
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..13 :0xff];
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*]u8 = @ptrCast([*]u8, &buf);
        const slice = target[0..13 :0xff];
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..13 :0xff];
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: [*c]u8 = @ptrCast([*c]u8, &buf);
        const slice = target[0..13 :0xff];
    }

    // slice
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{0xff} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..13 :0xff];
    }
}

test "comptime slice-sentinel in bounds (terminated)" {
    // array
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..3 :'d'];
    }

    // ptr_array
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..3 :'d'];
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..3 :'d'];
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast([*]u8, &buf);
        const slice = target[0..3 :'d'];
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..3 :'d'];
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast([*c]u8, &buf);
        const slice = target[0..3 :'d'];
    }

    // slice
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..3 :'d'];
    }
}

test "comptime slice-sentinel in bounds (on target sentinel)" {
    // array
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..14 :0];
    }

    // ptr_array
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..14 :0];
    }

    // vector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..14 :0];
    }

    // vector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast([*]u8, &buf);
        const slice = target[0..14 :0];
    }

    // cvector_ConstPtrSpecialBaseArray
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..14 :0];
    }

    // cvector_ConstPtrSpecialRef
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast([*c]u8, &buf);
        const slice = target[0..14 :0];
    }

    // slice
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..14 :0];
    }
}
