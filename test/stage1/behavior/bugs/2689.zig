test "slice with alignment" {
    const S = packed struct {
        a: u8,
    };

    var a: []align(8) S = undefined;
}
