const builtin = @import("builtin");

fn retOpt() ?u32 {
    return null;
}
test {
    var cond = true;
    const opt = while (cond) {
        if (retOpt()) |opt| {
            break opt;
        }
        break 1;
    } else 2;
    _ = opt;
}
