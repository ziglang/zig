extern fn check() c_int;

pub fn main() u8 {
    return @intCast(u8, check());
}
