pub const panic = @compileError("");

pub export fn entry() usize {
    @setRuntimeSafety(false);
    var u: usize = 0;
    {
        u += 1;
    }
    if (u == 0) {
        u += 1;
    }
    while (u == 0) {
        u += 1;
    }
    for (0..u) |_| {
        u += 1;
    }
    defer {
        u += 1;
    }
    switch (u) {
        else => {
            u += 1;
        },
    }
    if (@as(error{}!usize, u)) |_| {
        u += 1;
    } else |e| switch (e) {
        else => {
            u += 1;
        },
    }
    return u;
}

// compile
// output_mode=Obj
