export fn invalidRuntimeThen(cond: bool) u0 {
    const invalid: u16 = 256;
    const result: u8 = if (cond) invalid else 0;
    return result;
}

export fn invalidComptimeThen() u0 {
    const invalid: u16 = 256;
    const result: u8 = if (true) invalid else 0;
    return result;
}

export fn invalidRuntimeElse(cond: bool) u0 {
    const invalid: u16 = 256;
    const result: u8 = if (cond) 0 else invalid;
    return result;
}

export fn invalidComptimeElse() u0 {
    const invalid: u16 = 256;
    const result: u8 = if (false) 0 else invalid;
    return result;
}

// error
// backend=stage2
// target=native
//
// :3:34: error: type 'u8' cannot represent integer value '256'
// :9:34: error: type 'u8' cannot represent integer value '256'
// :15:41: error: type 'u8' cannot represent integer value '256'
// :21:42: error: type 'u8' cannot represent integer value '256'
