const base64 = @import("std").base64;

export fn decode_base_64(dest_ptr: &u8, dest_len: usize, source_ptr: &const u8, source_len: usize) -> usize {
    const src = source_ptr[0...source_len];
    const dest = dest_ptr[0...dest_len];
    return base64.decode(dest, src).len;
}
