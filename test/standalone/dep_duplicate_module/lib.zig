const std = @import("std");
const mod = @import("mod");

export fn work(x: u32) u32 {
    return mod.double(x);
}
