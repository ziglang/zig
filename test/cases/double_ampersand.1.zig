pub fn main() void {
    const a = true;
    const b = false;
    _ = a & &b;
}

// error
//
// :4:11: error: incompatible types: 'bool' and '*const bool'
// :4:9: note: type 'bool' here
// :4:13: note: type '*const bool' here
