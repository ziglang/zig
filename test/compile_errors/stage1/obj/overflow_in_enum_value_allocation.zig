const Moo = enum(u8) {
    Last = 255,
    Over,
};
pub fn main() void {
  var y = Moo.Last;
  _ = y;
}

// overflow in enum value allocation
//
// tmp.zig:3:5: error: enumeration value 256 too large for type 'u8'
