pub usingnamespace @cImport({
    @cDefine("__STDC_CONSTANT_MACROS", "");
    @cDefine("__STDC_LIMIT_MACROS", "");
    @cInclude("inttypes.h");
    @cInclude("config.h");
    @cInclude("zig_llvm.h");
});
