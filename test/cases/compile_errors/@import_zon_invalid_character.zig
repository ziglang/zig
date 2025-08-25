export fn entry() void {
    const f: u8 = @import("zon/invalid_character.zon");
    _ = f;
}

// error
// imports=zon/invalid_character.zon
//
// invalid_character.zon:1:3: error: invalid escape character: 'a'
