export fn invalidBreak() u8 {
    const result: u8 = label: {
        break :label 256;
    };
    return result;
}

// error
//
// :3:22: error: type 'u8' cannot represent integer value '256'
