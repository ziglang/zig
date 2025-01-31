comptime {
    var byte: u8 = 255;
    byte += 1;
}

// test_error=overflow of integer type 'u8' with value '256'
