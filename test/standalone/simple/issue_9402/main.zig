const FILE = extern struct {
    dummy_field: u8,
};

extern fn _ftelli64([*c]FILE) i64;
extern fn _fseeki64([*c]FILE, i64, c_int) c_int;

pub export fn main(argc: c_int, argv: **u8) c_int {
    _ = argv;
    _ = argc;
    _ = _ftelli64(null);
    _ = _fseeki64(null, 123, 2);
    return 0;
}
