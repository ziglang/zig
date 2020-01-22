const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    addsubiw,
    avr0,
    avr1,
    avr2,
    avr25,
    avr3,
    avr31,
    avr35,
    avr4,
    avr5,
    avr51,
    avr6,
    avrtiny,
    @"break",
    des,
    eijmpcall,
    elpm,
    elpmx,
    ijmpcall,
    jmpcall,
    lpm,
    lpmx,
    movw,
    mul,
    rmw,
    smallstack,
    special,
    spm,
    spmx,
    sram,
    tinyencoding,
    xmega,
    xmegau,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= Cpu.Feature.Set.needed_bit_count);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.addsubiw)] = .{
        .llvm_name = "addsubiw",
        .description = "Enable 16-bit register-immediate addition and subtraction instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.avr0)] = .{
        .llvm_name = "avr0",
        .description = "The device is a part of the avr0 family",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.avr1)] = .{
        .llvm_name = "avr1",
        .description = "The device is a part of the avr1 family",
        .dependencies = featureSet(&[_]Feature{
            .avr0,
            .lpm,
        }),
    };
    result[@enumToInt(Feature.avr2)] = .{
        .llvm_name = "avr2",
        .description = "The device is a part of the avr2 family",
        .dependencies = featureSet(&[_]Feature{
            .addsubiw,
            .avr1,
            .ijmpcall,
            .sram,
        }),
    };
    result[@enumToInt(Feature.avr25)] = .{
        .llvm_name = "avr25",
        .description = "The device is a part of the avr25 family",
        .dependencies = featureSet(&[_]Feature{
            .avr2,
            .@"break",
            .lpmx,
            .movw,
            .spm,
        }),
    };
    result[@enumToInt(Feature.avr3)] = .{
        .llvm_name = "avr3",
        .description = "The device is a part of the avr3 family",
        .dependencies = featureSet(&[_]Feature{
            .avr2,
            .jmpcall,
        }),
    };
    result[@enumToInt(Feature.avr31)] = .{
        .llvm_name = "avr31",
        .description = "The device is a part of the avr31 family",
        .dependencies = featureSet(&[_]Feature{
            .avr3,
            .elpm,
        }),
    };
    result[@enumToInt(Feature.avr35)] = .{
        .llvm_name = "avr35",
        .description = "The device is a part of the avr35 family",
        .dependencies = featureSet(&[_]Feature{
            .avr3,
            .@"break",
            .lpmx,
            .movw,
            .spm,
        }),
    };
    result[@enumToInt(Feature.avr4)] = .{
        .llvm_name = "avr4",
        .description = "The device is a part of the avr4 family",
        .dependencies = featureSet(&[_]Feature{
            .avr2,
            .@"break",
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    result[@enumToInt(Feature.avr5)] = .{
        .llvm_name = "avr5",
        .description = "The device is a part of the avr5 family",
        .dependencies = featureSet(&[_]Feature{
            .avr3,
            .@"break",
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    result[@enumToInt(Feature.avr51)] = .{
        .llvm_name = "avr51",
        .description = "The device is a part of the avr51 family",
        .dependencies = featureSet(&[_]Feature{
            .avr5,
            .elpm,
            .elpmx,
        }),
    };
    result[@enumToInt(Feature.avr6)] = .{
        .llvm_name = "avr6",
        .description = "The device is a part of the avr6 family",
        .dependencies = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    result[@enumToInt(Feature.avrtiny)] = .{
        .llvm_name = "avrtiny",
        .description = "The device is a part of the avrtiny family",
        .dependencies = featureSet(&[_]Feature{
            .avr0,
            .@"break",
            .sram,
            .tinyencoding,
        }),
    };
    result[@enumToInt(Feature.@"break")] = .{
        .llvm_name = "break",
        .description = "The device supports the `BREAK` debugging instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.des)] = .{
        .llvm_name = "des",
        .description = "The device supports the `DES k` encryption instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.eijmpcall)] = .{
        .llvm_name = "eijmpcall",
        .description = "The device supports the `EIJMP`/`EICALL` instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.elpm)] = .{
        .llvm_name = "elpm",
        .description = "The device supports the ELPM instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.elpmx)] = .{
        .llvm_name = "elpmx",
        .description = "The device supports the `ELPM Rd, Z[+]` instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ijmpcall)] = .{
        .llvm_name = "ijmpcall",
        .description = "The device supports `IJMP`/`ICALL`instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.jmpcall)] = .{
        .llvm_name = "jmpcall",
        .description = "The device supports the `JMP` and `CALL` instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lpm)] = .{
        .llvm_name = "lpm",
        .description = "The device supports the `LPM` instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lpmx)] = .{
        .llvm_name = "lpmx",
        .description = "The device supports the `LPM Rd, Z[+]` instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.movw)] = .{
        .llvm_name = "movw",
        .description = "The device supports the 16-bit MOVW instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mul)] = .{
        .llvm_name = "mul",
        .description = "The device supports the multiplication instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.rmw)] = .{
        .llvm_name = "rmw",
        .description = "The device supports the read-write-modify instructions: XCH, LAS, LAC, LAT",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.smallstack)] = .{
        .llvm_name = "smallstack",
        .description = "The device has an 8-bit stack pointer",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.special)] = .{
        .llvm_name = "special",
        .description = "Enable use of the entire instruction set - used for debugging",
        .dependencies = featureSet(&[_]Feature{
            .addsubiw,
            .@"break",
            .des,
            .eijmpcall,
            .elpm,
            .elpmx,
            .ijmpcall,
            .jmpcall,
            .lpm,
            .lpmx,
            .movw,
            .mul,
            .rmw,
            .spm,
            .spmx,
            .sram,
        }),
    };
    result[@enumToInt(Feature.spm)] = .{
        .llvm_name = "spm",
        .description = "The device supports the `SPM` instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.spmx)] = .{
        .llvm_name = "spmx",
        .description = "The device supports the `SPM Z+` instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sram)] = .{
        .llvm_name = "sram",
        .description = "The device has random access memory",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tinyencoding)] = .{
        .llvm_name = "tinyencoding",
        .description = "The device has Tiny core specific instruction encodings",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.xmega)] = .{
        .llvm_name = "xmega",
        .description = "The device is a part of the xmega family",
        .dependencies = featureSet(&[_]Feature{
            .avr51,
            .des,
            .eijmpcall,
            .spmx,
        }),
    };
    result[@enumToInt(Feature.xmegau)] = .{
        .llvm_name = "xmegau",
        .description = "The device is a part of the xmegau family",
        .dependencies = featureSet(&[_]Feature{
            .rmw,
            .xmega,
        }),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const at43usb320 = Cpu{
        .name = "at43usb320",
        .llvm_name = "at43usb320",
        .features = featureSet(&[_]Feature{
            .avr31,
        }),
    };
    pub const at43usb355 = Cpu{
        .name = "at43usb355",
        .llvm_name = "at43usb355",
        .features = featureSet(&[_]Feature{
            .avr3,
        }),
    };
    pub const at76c711 = Cpu{
        .name = "at76c711",
        .llvm_name = "at76c711",
        .features = featureSet(&[_]Feature{
            .avr3,
        }),
    };
    pub const at86rf401 = Cpu{
        .name = "at86rf401",
        .llvm_name = "at86rf401",
        .features = featureSet(&[_]Feature{
            .avr2,
            .lpmx,
            .movw,
        }),
    };
    pub const at90c8534 = Cpu{
        .name = "at90c8534",
        .llvm_name = "at90c8534",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90can128 = Cpu{
        .name = "at90can128",
        .llvm_name = "at90can128",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const at90can32 = Cpu{
        .name = "at90can32",
        .llvm_name = "at90can32",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90can64 = Cpu{
        .name = "at90can64",
        .llvm_name = "at90can64",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90pwm1 = Cpu{
        .name = "at90pwm1",
        .llvm_name = "at90pwm1",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90pwm161 = Cpu{
        .name = "at90pwm161",
        .llvm_name = "at90pwm161",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90pwm2 = Cpu{
        .name = "at90pwm2",
        .llvm_name = "at90pwm2",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90pwm216 = Cpu{
        .name = "at90pwm216",
        .llvm_name = "at90pwm216",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90pwm2b = Cpu{
        .name = "at90pwm2b",
        .llvm_name = "at90pwm2b",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90pwm3 = Cpu{
        .name = "at90pwm3",
        .llvm_name = "at90pwm3",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90pwm316 = Cpu{
        .name = "at90pwm316",
        .llvm_name = "at90pwm316",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90pwm3b = Cpu{
        .name = "at90pwm3b",
        .llvm_name = "at90pwm3b",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90pwm81 = Cpu{
        .name = "at90pwm81",
        .llvm_name = "at90pwm81",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const at90s1200 = Cpu{
        .name = "at90s1200",
        .llvm_name = "at90s1200",
        .features = featureSet(&[_]Feature{
            .avr0,
        }),
    };
    pub const at90s2313 = Cpu{
        .name = "at90s2313",
        .llvm_name = "at90s2313",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s2323 = Cpu{
        .name = "at90s2323",
        .llvm_name = "at90s2323",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s2333 = Cpu{
        .name = "at90s2333",
        .llvm_name = "at90s2333",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s2343 = Cpu{
        .name = "at90s2343",
        .llvm_name = "at90s2343",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s4414 = Cpu{
        .name = "at90s4414",
        .llvm_name = "at90s4414",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s4433 = Cpu{
        .name = "at90s4433",
        .llvm_name = "at90s4433",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s4434 = Cpu{
        .name = "at90s4434",
        .llvm_name = "at90s4434",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s8515 = Cpu{
        .name = "at90s8515",
        .llvm_name = "at90s8515",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90s8535 = Cpu{
        .name = "at90s8535",
        .llvm_name = "at90s8535",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const at90scr100 = Cpu{
        .name = "at90scr100",
        .llvm_name = "at90scr100",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90usb1286 = Cpu{
        .name = "at90usb1286",
        .llvm_name = "at90usb1286",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const at90usb1287 = Cpu{
        .name = "at90usb1287",
        .llvm_name = "at90usb1287",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const at90usb162 = Cpu{
        .name = "at90usb162",
        .llvm_name = "at90usb162",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const at90usb646 = Cpu{
        .name = "at90usb646",
        .llvm_name = "at90usb646",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90usb647 = Cpu{
        .name = "at90usb647",
        .llvm_name = "at90usb647",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const at90usb82 = Cpu{
        .name = "at90usb82",
        .llvm_name = "at90usb82",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const at94k = Cpu{
        .name = "at94k",
        .llvm_name = "at94k",
        .features = featureSet(&[_]Feature{
            .avr3,
            .lpmx,
            .movw,
            .mul,
        }),
    };
    pub const ata5272 = Cpu{
        .name = "ata5272",
        .llvm_name = "ata5272",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const ata5505 = Cpu{
        .name = "ata5505",
        .llvm_name = "ata5505",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const ata5790 = Cpu{
        .name = "ata5790",
        .llvm_name = "ata5790",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const ata5795 = Cpu{
        .name = "ata5795",
        .llvm_name = "ata5795",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const ata6285 = Cpu{
        .name = "ata6285",
        .llvm_name = "ata6285",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const ata6286 = Cpu{
        .name = "ata6286",
        .llvm_name = "ata6286",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const ata6289 = Cpu{
        .name = "ata6289",
        .llvm_name = "ata6289",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega103 = Cpu{
        .name = "atmega103",
        .llvm_name = "atmega103",
        .features = featureSet(&[_]Feature{
            .avr31,
        }),
    };
    pub const atmega128 = Cpu{
        .name = "atmega128",
        .llvm_name = "atmega128",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega1280 = Cpu{
        .name = "atmega1280",
        .llvm_name = "atmega1280",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega1281 = Cpu{
        .name = "atmega1281",
        .llvm_name = "atmega1281",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega1284 = Cpu{
        .name = "atmega1284",
        .llvm_name = "atmega1284",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega1284p = Cpu{
        .name = "atmega1284p",
        .llvm_name = "atmega1284p",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega1284rfr2 = Cpu{
        .name = "atmega1284rfr2",
        .llvm_name = "atmega1284rfr2",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega128a = Cpu{
        .name = "atmega128a",
        .llvm_name = "atmega128a",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega128rfa1 = Cpu{
        .name = "atmega128rfa1",
        .llvm_name = "atmega128rfa1",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega128rfr2 = Cpu{
        .name = "atmega128rfr2",
        .llvm_name = "atmega128rfr2",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const atmega16 = Cpu{
        .name = "atmega16",
        .llvm_name = "atmega16",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega161 = Cpu{
        .name = "atmega161",
        .llvm_name = "atmega161",
        .features = featureSet(&[_]Feature{
            .avr3,
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    pub const atmega162 = Cpu{
        .name = "atmega162",
        .llvm_name = "atmega162",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega163 = Cpu{
        .name = "atmega163",
        .llvm_name = "atmega163",
        .features = featureSet(&[_]Feature{
            .avr3,
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    pub const atmega164a = Cpu{
        .name = "atmega164a",
        .llvm_name = "atmega164a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega164p = Cpu{
        .name = "atmega164p",
        .llvm_name = "atmega164p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega164pa = Cpu{
        .name = "atmega164pa",
        .llvm_name = "atmega164pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega165 = Cpu{
        .name = "atmega165",
        .llvm_name = "atmega165",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega165a = Cpu{
        .name = "atmega165a",
        .llvm_name = "atmega165a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega165p = Cpu{
        .name = "atmega165p",
        .llvm_name = "atmega165p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega165pa = Cpu{
        .name = "atmega165pa",
        .llvm_name = "atmega165pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega168 = Cpu{
        .name = "atmega168",
        .llvm_name = "atmega168",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega168a = Cpu{
        .name = "atmega168a",
        .llvm_name = "atmega168a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega168p = Cpu{
        .name = "atmega168p",
        .llvm_name = "atmega168p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega168pa = Cpu{
        .name = "atmega168pa",
        .llvm_name = "atmega168pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega169 = Cpu{
        .name = "atmega169",
        .llvm_name = "atmega169",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega169a = Cpu{
        .name = "atmega169a",
        .llvm_name = "atmega169a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega169p = Cpu{
        .name = "atmega169p",
        .llvm_name = "atmega169p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega169pa = Cpu{
        .name = "atmega169pa",
        .llvm_name = "atmega169pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16a = Cpu{
        .name = "atmega16a",
        .llvm_name = "atmega16a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16hva = Cpu{
        .name = "atmega16hva",
        .llvm_name = "atmega16hva",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16hva2 = Cpu{
        .name = "atmega16hva2",
        .llvm_name = "atmega16hva2",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16hvb = Cpu{
        .name = "atmega16hvb",
        .llvm_name = "atmega16hvb",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16hvbrevb = Cpu{
        .name = "atmega16hvbrevb",
        .llvm_name = "atmega16hvbrevb",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16m1 = Cpu{
        .name = "atmega16m1",
        .llvm_name = "atmega16m1",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega16u2 = Cpu{
        .name = "atmega16u2",
        .llvm_name = "atmega16u2",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const atmega16u4 = Cpu{
        .name = "atmega16u4",
        .llvm_name = "atmega16u4",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega2560 = Cpu{
        .name = "atmega2560",
        .llvm_name = "atmega2560",
        .features = featureSet(&[_]Feature{
            .avr6,
        }),
    };
    pub const atmega2561 = Cpu{
        .name = "atmega2561",
        .llvm_name = "atmega2561",
        .features = featureSet(&[_]Feature{
            .avr6,
        }),
    };
    pub const atmega2564rfr2 = Cpu{
        .name = "atmega2564rfr2",
        .llvm_name = "atmega2564rfr2",
        .features = featureSet(&[_]Feature{
            .avr6,
        }),
    };
    pub const atmega256rfr2 = Cpu{
        .name = "atmega256rfr2",
        .llvm_name = "atmega256rfr2",
        .features = featureSet(&[_]Feature{
            .avr6,
        }),
    };
    pub const atmega32 = Cpu{
        .name = "atmega32",
        .llvm_name = "atmega32",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega323 = Cpu{
        .name = "atmega323",
        .llvm_name = "atmega323",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega324a = Cpu{
        .name = "atmega324a",
        .llvm_name = "atmega324a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega324p = Cpu{
        .name = "atmega324p",
        .llvm_name = "atmega324p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega324pa = Cpu{
        .name = "atmega324pa",
        .llvm_name = "atmega324pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega325 = Cpu{
        .name = "atmega325",
        .llvm_name = "atmega325",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3250 = Cpu{
        .name = "atmega3250",
        .llvm_name = "atmega3250",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3250a = Cpu{
        .name = "atmega3250a",
        .llvm_name = "atmega3250a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3250p = Cpu{
        .name = "atmega3250p",
        .llvm_name = "atmega3250p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3250pa = Cpu{
        .name = "atmega3250pa",
        .llvm_name = "atmega3250pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega325a = Cpu{
        .name = "atmega325a",
        .llvm_name = "atmega325a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega325p = Cpu{
        .name = "atmega325p",
        .llvm_name = "atmega325p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega325pa = Cpu{
        .name = "atmega325pa",
        .llvm_name = "atmega325pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega328 = Cpu{
        .name = "atmega328",
        .llvm_name = "atmega328",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega328p = Cpu{
        .name = "atmega328p",
        .llvm_name = "atmega328p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega329 = Cpu{
        .name = "atmega329",
        .llvm_name = "atmega329",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3290 = Cpu{
        .name = "atmega3290",
        .llvm_name = "atmega3290",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3290a = Cpu{
        .name = "atmega3290a",
        .llvm_name = "atmega3290a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3290p = Cpu{
        .name = "atmega3290p",
        .llvm_name = "atmega3290p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega3290pa = Cpu{
        .name = "atmega3290pa",
        .llvm_name = "atmega3290pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega329a = Cpu{
        .name = "atmega329a",
        .llvm_name = "atmega329a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega329p = Cpu{
        .name = "atmega329p",
        .llvm_name = "atmega329p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega329pa = Cpu{
        .name = "atmega329pa",
        .llvm_name = "atmega329pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32a = Cpu{
        .name = "atmega32a",
        .llvm_name = "atmega32a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32c1 = Cpu{
        .name = "atmega32c1",
        .llvm_name = "atmega32c1",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32hvb = Cpu{
        .name = "atmega32hvb",
        .llvm_name = "atmega32hvb",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32hvbrevb = Cpu{
        .name = "atmega32hvbrevb",
        .llvm_name = "atmega32hvbrevb",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32m1 = Cpu{
        .name = "atmega32m1",
        .llvm_name = "atmega32m1",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32u2 = Cpu{
        .name = "atmega32u2",
        .llvm_name = "atmega32u2",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const atmega32u4 = Cpu{
        .name = "atmega32u4",
        .llvm_name = "atmega32u4",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega32u6 = Cpu{
        .name = "atmega32u6",
        .llvm_name = "atmega32u6",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega406 = Cpu{
        .name = "atmega406",
        .llvm_name = "atmega406",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega48 = Cpu{
        .name = "atmega48",
        .llvm_name = "atmega48",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega48a = Cpu{
        .name = "atmega48a",
        .llvm_name = "atmega48a",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega48p = Cpu{
        .name = "atmega48p",
        .llvm_name = "atmega48p",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega48pa = Cpu{
        .name = "atmega48pa",
        .llvm_name = "atmega48pa",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega64 = Cpu{
        .name = "atmega64",
        .llvm_name = "atmega64",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega640 = Cpu{
        .name = "atmega640",
        .llvm_name = "atmega640",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega644 = Cpu{
        .name = "atmega644",
        .llvm_name = "atmega644",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega644a = Cpu{
        .name = "atmega644a",
        .llvm_name = "atmega644a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega644p = Cpu{
        .name = "atmega644p",
        .llvm_name = "atmega644p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega644pa = Cpu{
        .name = "atmega644pa",
        .llvm_name = "atmega644pa",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega644rfr2 = Cpu{
        .name = "atmega644rfr2",
        .llvm_name = "atmega644rfr2",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega645 = Cpu{
        .name = "atmega645",
        .llvm_name = "atmega645",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6450 = Cpu{
        .name = "atmega6450",
        .llvm_name = "atmega6450",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6450a = Cpu{
        .name = "atmega6450a",
        .llvm_name = "atmega6450a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6450p = Cpu{
        .name = "atmega6450p",
        .llvm_name = "atmega6450p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega645a = Cpu{
        .name = "atmega645a",
        .llvm_name = "atmega645a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega645p = Cpu{
        .name = "atmega645p",
        .llvm_name = "atmega645p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega649 = Cpu{
        .name = "atmega649",
        .llvm_name = "atmega649",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6490 = Cpu{
        .name = "atmega6490",
        .llvm_name = "atmega6490",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6490a = Cpu{
        .name = "atmega6490a",
        .llvm_name = "atmega6490a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega6490p = Cpu{
        .name = "atmega6490p",
        .llvm_name = "atmega6490p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega649a = Cpu{
        .name = "atmega649a",
        .llvm_name = "atmega649a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega649p = Cpu{
        .name = "atmega649p",
        .llvm_name = "atmega649p",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega64a = Cpu{
        .name = "atmega64a",
        .llvm_name = "atmega64a",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega64c1 = Cpu{
        .name = "atmega64c1",
        .llvm_name = "atmega64c1",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega64hve = Cpu{
        .name = "atmega64hve",
        .llvm_name = "atmega64hve",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega64m1 = Cpu{
        .name = "atmega64m1",
        .llvm_name = "atmega64m1",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega64rfr2 = Cpu{
        .name = "atmega64rfr2",
        .llvm_name = "atmega64rfr2",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const atmega8 = Cpu{
        .name = "atmega8",
        .llvm_name = "atmega8",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega8515 = Cpu{
        .name = "atmega8515",
        .llvm_name = "atmega8515",
        .features = featureSet(&[_]Feature{
            .avr2,
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    pub const atmega8535 = Cpu{
        .name = "atmega8535",
        .llvm_name = "atmega8535",
        .features = featureSet(&[_]Feature{
            .avr2,
            .lpmx,
            .movw,
            .mul,
            .spm,
        }),
    };
    pub const atmega88 = Cpu{
        .name = "atmega88",
        .llvm_name = "atmega88",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega88a = Cpu{
        .name = "atmega88a",
        .llvm_name = "atmega88a",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega88p = Cpu{
        .name = "atmega88p",
        .llvm_name = "atmega88p",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega88pa = Cpu{
        .name = "atmega88pa",
        .llvm_name = "atmega88pa",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega8a = Cpu{
        .name = "atmega8a",
        .llvm_name = "atmega8a",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega8hva = Cpu{
        .name = "atmega8hva",
        .llvm_name = "atmega8hva",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const atmega8u2 = Cpu{
        .name = "atmega8u2",
        .llvm_name = "atmega8u2",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const attiny10 = Cpu{
        .name = "attiny10",
        .llvm_name = "attiny10",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny102 = Cpu{
        .name = "attiny102",
        .llvm_name = "attiny102",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny104 = Cpu{
        .name = "attiny104",
        .llvm_name = "attiny104",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny11 = Cpu{
        .name = "attiny11",
        .llvm_name = "attiny11",
        .features = featureSet(&[_]Feature{
            .avr1,
        }),
    };
    pub const attiny12 = Cpu{
        .name = "attiny12",
        .llvm_name = "attiny12",
        .features = featureSet(&[_]Feature{
            .avr1,
        }),
    };
    pub const attiny13 = Cpu{
        .name = "attiny13",
        .llvm_name = "attiny13",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny13a = Cpu{
        .name = "attiny13a",
        .llvm_name = "attiny13a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny15 = Cpu{
        .name = "attiny15",
        .llvm_name = "attiny15",
        .features = featureSet(&[_]Feature{
            .avr1,
        }),
    };
    pub const attiny1634 = Cpu{
        .name = "attiny1634",
        .llvm_name = "attiny1634",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const attiny167 = Cpu{
        .name = "attiny167",
        .llvm_name = "attiny167",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const attiny20 = Cpu{
        .name = "attiny20",
        .llvm_name = "attiny20",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny22 = Cpu{
        .name = "attiny22",
        .llvm_name = "attiny22",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const attiny2313 = Cpu{
        .name = "attiny2313",
        .llvm_name = "attiny2313",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny2313a = Cpu{
        .name = "attiny2313a",
        .llvm_name = "attiny2313a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny24 = Cpu{
        .name = "attiny24",
        .llvm_name = "attiny24",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny24a = Cpu{
        .name = "attiny24a",
        .llvm_name = "attiny24a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny25 = Cpu{
        .name = "attiny25",
        .llvm_name = "attiny25",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny26 = Cpu{
        .name = "attiny26",
        .llvm_name = "attiny26",
        .features = featureSet(&[_]Feature{
            .avr2,
            .lpmx,
        }),
    };
    pub const attiny261 = Cpu{
        .name = "attiny261",
        .llvm_name = "attiny261",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny261a = Cpu{
        .name = "attiny261a",
        .llvm_name = "attiny261a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny28 = Cpu{
        .name = "attiny28",
        .llvm_name = "attiny28",
        .features = featureSet(&[_]Feature{
            .avr1,
        }),
    };
    pub const attiny4 = Cpu{
        .name = "attiny4",
        .llvm_name = "attiny4",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny40 = Cpu{
        .name = "attiny40",
        .llvm_name = "attiny40",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny4313 = Cpu{
        .name = "attiny4313",
        .llvm_name = "attiny4313",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny43u = Cpu{
        .name = "attiny43u",
        .llvm_name = "attiny43u",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny44 = Cpu{
        .name = "attiny44",
        .llvm_name = "attiny44",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny44a = Cpu{
        .name = "attiny44a",
        .llvm_name = "attiny44a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny45 = Cpu{
        .name = "attiny45",
        .llvm_name = "attiny45",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny461 = Cpu{
        .name = "attiny461",
        .llvm_name = "attiny461",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny461a = Cpu{
        .name = "attiny461a",
        .llvm_name = "attiny461a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny48 = Cpu{
        .name = "attiny48",
        .llvm_name = "attiny48",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny5 = Cpu{
        .name = "attiny5",
        .llvm_name = "attiny5",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const attiny828 = Cpu{
        .name = "attiny828",
        .llvm_name = "attiny828",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny84 = Cpu{
        .name = "attiny84",
        .llvm_name = "attiny84",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny84a = Cpu{
        .name = "attiny84a",
        .llvm_name = "attiny84a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny85 = Cpu{
        .name = "attiny85",
        .llvm_name = "attiny85",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny861 = Cpu{
        .name = "attiny861",
        .llvm_name = "attiny861",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny861a = Cpu{
        .name = "attiny861a",
        .llvm_name = "attiny861a",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny87 = Cpu{
        .name = "attiny87",
        .llvm_name = "attiny87",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny88 = Cpu{
        .name = "attiny88",
        .llvm_name = "attiny88",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const attiny9 = Cpu{
        .name = "attiny9",
        .llvm_name = "attiny9",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const atxmega128a1 = Cpu{
        .name = "atxmega128a1",
        .llvm_name = "atxmega128a1",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega128a1u = Cpu{
        .name = "atxmega128a1u",
        .llvm_name = "atxmega128a1u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128a3 = Cpu{
        .name = "atxmega128a3",
        .llvm_name = "atxmega128a3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega128a3u = Cpu{
        .name = "atxmega128a3u",
        .llvm_name = "atxmega128a3u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128a4u = Cpu{
        .name = "atxmega128a4u",
        .llvm_name = "atxmega128a4u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128b1 = Cpu{
        .name = "atxmega128b1",
        .llvm_name = "atxmega128b1",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128b3 = Cpu{
        .name = "atxmega128b3",
        .llvm_name = "atxmega128b3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128c3 = Cpu{
        .name = "atxmega128c3",
        .llvm_name = "atxmega128c3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega128d3 = Cpu{
        .name = "atxmega128d3",
        .llvm_name = "atxmega128d3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega128d4 = Cpu{
        .name = "atxmega128d4",
        .llvm_name = "atxmega128d4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega16a4 = Cpu{
        .name = "atxmega16a4",
        .llvm_name = "atxmega16a4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega16a4u = Cpu{
        .name = "atxmega16a4u",
        .llvm_name = "atxmega16a4u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega16c4 = Cpu{
        .name = "atxmega16c4",
        .llvm_name = "atxmega16c4",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega16d4 = Cpu{
        .name = "atxmega16d4",
        .llvm_name = "atxmega16d4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega16e5 = Cpu{
        .name = "atxmega16e5",
        .llvm_name = "atxmega16e5",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega192a3 = Cpu{
        .name = "atxmega192a3",
        .llvm_name = "atxmega192a3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega192a3u = Cpu{
        .name = "atxmega192a3u",
        .llvm_name = "atxmega192a3u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega192c3 = Cpu{
        .name = "atxmega192c3",
        .llvm_name = "atxmega192c3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega192d3 = Cpu{
        .name = "atxmega192d3",
        .llvm_name = "atxmega192d3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega256a3 = Cpu{
        .name = "atxmega256a3",
        .llvm_name = "atxmega256a3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega256a3b = Cpu{
        .name = "atxmega256a3b",
        .llvm_name = "atxmega256a3b",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega256a3bu = Cpu{
        .name = "atxmega256a3bu",
        .llvm_name = "atxmega256a3bu",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega256a3u = Cpu{
        .name = "atxmega256a3u",
        .llvm_name = "atxmega256a3u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega256c3 = Cpu{
        .name = "atxmega256c3",
        .llvm_name = "atxmega256c3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega256d3 = Cpu{
        .name = "atxmega256d3",
        .llvm_name = "atxmega256d3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega32a4 = Cpu{
        .name = "atxmega32a4",
        .llvm_name = "atxmega32a4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega32a4u = Cpu{
        .name = "atxmega32a4u",
        .llvm_name = "atxmega32a4u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega32c4 = Cpu{
        .name = "atxmega32c4",
        .llvm_name = "atxmega32c4",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega32d4 = Cpu{
        .name = "atxmega32d4",
        .llvm_name = "atxmega32d4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega32e5 = Cpu{
        .name = "atxmega32e5",
        .llvm_name = "atxmega32e5",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega32x1 = Cpu{
        .name = "atxmega32x1",
        .llvm_name = "atxmega32x1",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega384c3 = Cpu{
        .name = "atxmega384c3",
        .llvm_name = "atxmega384c3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega384d3 = Cpu{
        .name = "atxmega384d3",
        .llvm_name = "atxmega384d3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega64a1 = Cpu{
        .name = "atxmega64a1",
        .llvm_name = "atxmega64a1",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega64a1u = Cpu{
        .name = "atxmega64a1u",
        .llvm_name = "atxmega64a1u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64a3 = Cpu{
        .name = "atxmega64a3",
        .llvm_name = "atxmega64a3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega64a3u = Cpu{
        .name = "atxmega64a3u",
        .llvm_name = "atxmega64a3u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64a4u = Cpu{
        .name = "atxmega64a4u",
        .llvm_name = "atxmega64a4u",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64b1 = Cpu{
        .name = "atxmega64b1",
        .llvm_name = "atxmega64b1",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64b3 = Cpu{
        .name = "atxmega64b3",
        .llvm_name = "atxmega64b3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64c3 = Cpu{
        .name = "atxmega64c3",
        .llvm_name = "atxmega64c3",
        .features = featureSet(&[_]Feature{
            .xmegau,
        }),
    };
    pub const atxmega64d3 = Cpu{
        .name = "atxmega64d3",
        .llvm_name = "atxmega64d3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega64d4 = Cpu{
        .name = "atxmega64d4",
        .llvm_name = "atxmega64d4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const atxmega8e5 = Cpu{
        .name = "atxmega8e5",
        .llvm_name = "atxmega8e5",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avr1 = Cpu{
        .name = "avr1",
        .llvm_name = "avr1",
        .features = featureSet(&[_]Feature{
            .avr1,
        }),
    };
    pub const avr2 = Cpu{
        .name = "avr2",
        .llvm_name = "avr2",
        .features = featureSet(&[_]Feature{
            .avr2,
        }),
    };
    pub const avr25 = Cpu{
        .name = "avr25",
        .llvm_name = "avr25",
        .features = featureSet(&[_]Feature{
            .avr25,
        }),
    };
    pub const avr3 = Cpu{
        .name = "avr3",
        .llvm_name = "avr3",
        .features = featureSet(&[_]Feature{
            .avr3,
        }),
    };
    pub const avr31 = Cpu{
        .name = "avr31",
        .llvm_name = "avr31",
        .features = featureSet(&[_]Feature{
            .avr31,
        }),
    };
    pub const avr35 = Cpu{
        .name = "avr35",
        .llvm_name = "avr35",
        .features = featureSet(&[_]Feature{
            .avr35,
        }),
    };
    pub const avr4 = Cpu{
        .name = "avr4",
        .llvm_name = "avr4",
        .features = featureSet(&[_]Feature{
            .avr4,
        }),
    };
    pub const avr5 = Cpu{
        .name = "avr5",
        .llvm_name = "avr5",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
    pub const avr51 = Cpu{
        .name = "avr51",
        .llvm_name = "avr51",
        .features = featureSet(&[_]Feature{
            .avr51,
        }),
    };
    pub const avr6 = Cpu{
        .name = "avr6",
        .llvm_name = "avr6",
        .features = featureSet(&[_]Feature{
            .avr6,
        }),
    };
    pub const avrtiny = Cpu{
        .name = "avrtiny",
        .llvm_name = "avrtiny",
        .features = featureSet(&[_]Feature{
            .avrtiny,
        }),
    };
    pub const avrxmega1 = Cpu{
        .name = "avrxmega1",
        .llvm_name = "avrxmega1",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega2 = Cpu{
        .name = "avrxmega2",
        .llvm_name = "avrxmega2",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega3 = Cpu{
        .name = "avrxmega3",
        .llvm_name = "avrxmega3",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega4 = Cpu{
        .name = "avrxmega4",
        .llvm_name = "avrxmega4",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega5 = Cpu{
        .name = "avrxmega5",
        .llvm_name = "avrxmega5",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega6 = Cpu{
        .name = "avrxmega6",
        .llvm_name = "avrxmega6",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const avrxmega7 = Cpu{
        .name = "avrxmega7",
        .llvm_name = "avrxmega7",
        .features = featureSet(&[_]Feature{
            .xmega,
        }),
    };
    pub const m3000 = Cpu{
        .name = "m3000",
        .llvm_name = "m3000",
        .features = featureSet(&[_]Feature{
            .avr5,
        }),
    };
};

/// All avr CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.at43usb320,
    &cpu.at43usb355,
    &cpu.at76c711,
    &cpu.at86rf401,
    &cpu.at90c8534,
    &cpu.at90can128,
    &cpu.at90can32,
    &cpu.at90can64,
    &cpu.at90pwm1,
    &cpu.at90pwm161,
    &cpu.at90pwm2,
    &cpu.at90pwm216,
    &cpu.at90pwm2b,
    &cpu.at90pwm3,
    &cpu.at90pwm316,
    &cpu.at90pwm3b,
    &cpu.at90pwm81,
    &cpu.at90s1200,
    &cpu.at90s2313,
    &cpu.at90s2323,
    &cpu.at90s2333,
    &cpu.at90s2343,
    &cpu.at90s4414,
    &cpu.at90s4433,
    &cpu.at90s4434,
    &cpu.at90s8515,
    &cpu.at90s8535,
    &cpu.at90scr100,
    &cpu.at90usb1286,
    &cpu.at90usb1287,
    &cpu.at90usb162,
    &cpu.at90usb646,
    &cpu.at90usb647,
    &cpu.at90usb82,
    &cpu.at94k,
    &cpu.ata5272,
    &cpu.ata5505,
    &cpu.ata5790,
    &cpu.ata5795,
    &cpu.ata6285,
    &cpu.ata6286,
    &cpu.ata6289,
    &cpu.atmega103,
    &cpu.atmega128,
    &cpu.atmega1280,
    &cpu.atmega1281,
    &cpu.atmega1284,
    &cpu.atmega1284p,
    &cpu.atmega1284rfr2,
    &cpu.atmega128a,
    &cpu.atmega128rfa1,
    &cpu.atmega128rfr2,
    &cpu.atmega16,
    &cpu.atmega161,
    &cpu.atmega162,
    &cpu.atmega163,
    &cpu.atmega164a,
    &cpu.atmega164p,
    &cpu.atmega164pa,
    &cpu.atmega165,
    &cpu.atmega165a,
    &cpu.atmega165p,
    &cpu.atmega165pa,
    &cpu.atmega168,
    &cpu.atmega168a,
    &cpu.atmega168p,
    &cpu.atmega168pa,
    &cpu.atmega169,
    &cpu.atmega169a,
    &cpu.atmega169p,
    &cpu.atmega169pa,
    &cpu.atmega16a,
    &cpu.atmega16hva,
    &cpu.atmega16hva2,
    &cpu.atmega16hvb,
    &cpu.atmega16hvbrevb,
    &cpu.atmega16m1,
    &cpu.atmega16u2,
    &cpu.atmega16u4,
    &cpu.atmega2560,
    &cpu.atmega2561,
    &cpu.atmega2564rfr2,
    &cpu.atmega256rfr2,
    &cpu.atmega32,
    &cpu.atmega323,
    &cpu.atmega324a,
    &cpu.atmega324p,
    &cpu.atmega324pa,
    &cpu.atmega325,
    &cpu.atmega3250,
    &cpu.atmega3250a,
    &cpu.atmega3250p,
    &cpu.atmega3250pa,
    &cpu.atmega325a,
    &cpu.atmega325p,
    &cpu.atmega325pa,
    &cpu.atmega328,
    &cpu.atmega328p,
    &cpu.atmega329,
    &cpu.atmega3290,
    &cpu.atmega3290a,
    &cpu.atmega3290p,
    &cpu.atmega3290pa,
    &cpu.atmega329a,
    &cpu.atmega329p,
    &cpu.atmega329pa,
    &cpu.atmega32a,
    &cpu.atmega32c1,
    &cpu.atmega32hvb,
    &cpu.atmega32hvbrevb,
    &cpu.atmega32m1,
    &cpu.atmega32u2,
    &cpu.atmega32u4,
    &cpu.atmega32u6,
    &cpu.atmega406,
    &cpu.atmega48,
    &cpu.atmega48a,
    &cpu.atmega48p,
    &cpu.atmega48pa,
    &cpu.atmega64,
    &cpu.atmega640,
    &cpu.atmega644,
    &cpu.atmega644a,
    &cpu.atmega644p,
    &cpu.atmega644pa,
    &cpu.atmega644rfr2,
    &cpu.atmega645,
    &cpu.atmega6450,
    &cpu.atmega6450a,
    &cpu.atmega6450p,
    &cpu.atmega645a,
    &cpu.atmega645p,
    &cpu.atmega649,
    &cpu.atmega6490,
    &cpu.atmega6490a,
    &cpu.atmega6490p,
    &cpu.atmega649a,
    &cpu.atmega649p,
    &cpu.atmega64a,
    &cpu.atmega64c1,
    &cpu.atmega64hve,
    &cpu.atmega64m1,
    &cpu.atmega64rfr2,
    &cpu.atmega8,
    &cpu.atmega8515,
    &cpu.atmega8535,
    &cpu.atmega88,
    &cpu.atmega88a,
    &cpu.atmega88p,
    &cpu.atmega88pa,
    &cpu.atmega8a,
    &cpu.atmega8hva,
    &cpu.atmega8u2,
    &cpu.attiny10,
    &cpu.attiny102,
    &cpu.attiny104,
    &cpu.attiny11,
    &cpu.attiny12,
    &cpu.attiny13,
    &cpu.attiny13a,
    &cpu.attiny15,
    &cpu.attiny1634,
    &cpu.attiny167,
    &cpu.attiny20,
    &cpu.attiny22,
    &cpu.attiny2313,
    &cpu.attiny2313a,
    &cpu.attiny24,
    &cpu.attiny24a,
    &cpu.attiny25,
    &cpu.attiny26,
    &cpu.attiny261,
    &cpu.attiny261a,
    &cpu.attiny28,
    &cpu.attiny4,
    &cpu.attiny40,
    &cpu.attiny4313,
    &cpu.attiny43u,
    &cpu.attiny44,
    &cpu.attiny44a,
    &cpu.attiny45,
    &cpu.attiny461,
    &cpu.attiny461a,
    &cpu.attiny48,
    &cpu.attiny5,
    &cpu.attiny828,
    &cpu.attiny84,
    &cpu.attiny84a,
    &cpu.attiny85,
    &cpu.attiny861,
    &cpu.attiny861a,
    &cpu.attiny87,
    &cpu.attiny88,
    &cpu.attiny9,
    &cpu.atxmega128a1,
    &cpu.atxmega128a1u,
    &cpu.atxmega128a3,
    &cpu.atxmega128a3u,
    &cpu.atxmega128a4u,
    &cpu.atxmega128b1,
    &cpu.atxmega128b3,
    &cpu.atxmega128c3,
    &cpu.atxmega128d3,
    &cpu.atxmega128d4,
    &cpu.atxmega16a4,
    &cpu.atxmega16a4u,
    &cpu.atxmega16c4,
    &cpu.atxmega16d4,
    &cpu.atxmega16e5,
    &cpu.atxmega192a3,
    &cpu.atxmega192a3u,
    &cpu.atxmega192c3,
    &cpu.atxmega192d3,
    &cpu.atxmega256a3,
    &cpu.atxmega256a3b,
    &cpu.atxmega256a3bu,
    &cpu.atxmega256a3u,
    &cpu.atxmega256c3,
    &cpu.atxmega256d3,
    &cpu.atxmega32a4,
    &cpu.atxmega32a4u,
    &cpu.atxmega32c4,
    &cpu.atxmega32d4,
    &cpu.atxmega32e5,
    &cpu.atxmega32x1,
    &cpu.atxmega384c3,
    &cpu.atxmega384d3,
    &cpu.atxmega64a1,
    &cpu.atxmega64a1u,
    &cpu.atxmega64a3,
    &cpu.atxmega64a3u,
    &cpu.atxmega64a4u,
    &cpu.atxmega64b1,
    &cpu.atxmega64b3,
    &cpu.atxmega64c3,
    &cpu.atxmega64d3,
    &cpu.atxmega64d4,
    &cpu.atxmega8e5,
    &cpu.avr1,
    &cpu.avr2,
    &cpu.avr25,
    &cpu.avr3,
    &cpu.avr31,
    &cpu.avr35,
    &cpu.avr4,
    &cpu.avr5,
    &cpu.avr51,
    &cpu.avr6,
    &cpu.avrtiny,
    &cpu.avrxmega1,
    &cpu.avrxmega2,
    &cpu.avrxmega3,
    &cpu.avrxmega4,
    &cpu.avrxmega5,
    &cpu.avrxmega6,
    &cpu.avrxmega7,
    &cpu.m3000,
};
