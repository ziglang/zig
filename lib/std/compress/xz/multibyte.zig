const Multibyte = packed struct(u8) {
    value: u7,
    more: bool,
};

pub fn readInt(reader: anytype) !u64 {
    const max_size = 9;

    var chunk = try reader.readStruct(Multibyte);
    var num: u64 = chunk.value;
    var i: u6 = 0;

    while (chunk.more) {
        chunk = try reader.readStruct(Multibyte);
        i += 1;
        if (i >= max_size or @bitCast(u8, chunk) == 0x00)
            return error.CorruptInput;

        num |= @as(u64, chunk.value) << (i * 7);
    }

    return num;
}
