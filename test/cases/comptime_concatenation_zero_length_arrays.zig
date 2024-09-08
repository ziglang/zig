export const a: [0]u8 = wtf() ++ [0]u8{};
fn wtf() [0]u8 {
    return [0]u8 // newline on purpose
    {};
}

// compile
//
