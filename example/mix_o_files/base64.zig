const base64 = @import("std").base64;

export fn decode_base_64(dest_ptr: &u8, dest_len: usize, source_ptr: &const u8, source_len: usize) -> usize {
    const src = source_ptr[0..source_len];
    const dest = dest_ptr[0..dest_len];
    const decoded_size = base64.calcDecodedSizeExactUnsafe(src, base64.standard_pad_char);
    base64.decodeExactUnsafe(dest[0..decoded_size], src, base64.standard_alphabet_unsafe);
    return decoded_size;
}
