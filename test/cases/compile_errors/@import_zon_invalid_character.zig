pub fn main() void {
    const f = @import("zon/invalid_character.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/invalid_character.zon
//
// invalid_character.zon:1:3: error: invalid escape character: 'a'
