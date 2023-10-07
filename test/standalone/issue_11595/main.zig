extern fn check() c_int;

pub fn main() u8 {
    return @as(u8, @intCast(check()));
}
