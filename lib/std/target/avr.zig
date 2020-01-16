const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_addsubiw = Feature{
    .name = "addsubiw",
    .llvm_name = "addsubiw",
    .description = "Enable 16-bit register-immediate addition and subtraction instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_break = Feature{
    .name = "break",
    .llvm_name = "break",
    .description = "The device supports the `BREAK` debugging instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_des = Feature{
    .name = "des",
    .llvm_name = "des",
    .description = "The device supports the `DES k` encryption instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_eijmpcall = Feature{
    .name = "eijmpcall",
    .llvm_name = "eijmpcall",
    .description = "The device supports the `EIJMP`/`EICALL` instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_elpm = Feature{
    .name = "elpm",
    .llvm_name = "elpm",
    .description = "The device supports the ELPM instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_elpmx = Feature{
    .name = "elpmx",
    .llvm_name = "elpmx",
    .description = "The device supports the `ELPM Rd, Z[+]` instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ijmpcall = Feature{
    .name = "ijmpcall",
    .llvm_name = "ijmpcall",
    .description = "The device supports `IJMP`/`ICALL`instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_jmpcall = Feature{
    .name = "jmpcall",
    .llvm_name = "jmpcall",
    .description = "The device supports the `JMP` and `CALL` instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lpm = Feature{
    .name = "lpm",
    .llvm_name = "lpm",
    .description = "The device supports the `LPM` instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lpmx = Feature{
    .name = "lpmx",
    .llvm_name = "lpmx",
    .description = "The device supports the `LPM Rd, Z[+]` instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_movw = Feature{
    .name = "movw",
    .llvm_name = "movw",
    .description = "The device supports the 16-bit MOVW instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mul = Feature{
    .name = "mul",
    .llvm_name = "mul",
    .description = "The device supports the multiplication instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rmw = Feature{
    .name = "rmw",
    .llvm_name = "rmw",
    .description = "The device supports the read-write-modify instructions: XCH, LAS, LAC, LAT",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_spm = Feature{
    .name = "spm",
    .llvm_name = "spm",
    .description = "The device supports the `SPM` instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_spmx = Feature{
    .name = "spmx",
    .llvm_name = "spmx",
    .description = "The device supports the `SPM Z+` instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sram = Feature{
    .name = "sram",
    .llvm_name = "sram",
    .description = "The device has random access memory",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_smallstack = Feature{
    .name = "smallstack",
    .llvm_name = "smallstack",
    .description = "The device has an 8-bit stack pointer",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_tinyencoding = Feature{
    .name = "tinyencoding",
    .llvm_name = "tinyencoding",
    .description = "The device has Tiny core specific instruction encodings",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_addsubiw,
    &feature_break,
    &feature_des,
    &feature_eijmpcall,
    &feature_elpm,
    &feature_elpmx,
    &feature_ijmpcall,
    &feature_jmpcall,
    &feature_lpm,
    &feature_lpmx,
    &feature_movw,
    &feature_mul,
    &feature_rmw,
    &feature_spm,
    &feature_spmx,
    &feature_sram,
    &feature_smallstack,
    &feature_tinyencoding,
};

pub const cpu_at43usb320 = Cpu{
    .name = "at43usb320",
    .llvm_name = "at43usb320",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at43usb355 = Cpu{
    .name = "at43usb355",
    .llvm_name = "at43usb355",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at76c711 = Cpu{
    .name = "at76c711",
    .llvm_name = "at76c711",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at86rf401 = Cpu{
    .name = "at86rf401",
    .llvm_name = "at86rf401",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
    },
};

pub const cpu_at90c8534 = Cpu{
    .name = "at90c8534",
    .llvm_name = "at90c8534",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90can128 = Cpu{
    .name = "at90can128",
    .llvm_name = "at90can128",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90can32 = Cpu{
    .name = "at90can32",
    .llvm_name = "at90can32",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90can64 = Cpu{
    .name = "at90can64",
    .llvm_name = "at90can64",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm1 = Cpu{
    .name = "at90pwm1",
    .llvm_name = "at90pwm1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm161 = Cpu{
    .name = "at90pwm161",
    .llvm_name = "at90pwm161",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm2 = Cpu{
    .name = "at90pwm2",
    .llvm_name = "at90pwm2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm216 = Cpu{
    .name = "at90pwm216",
    .llvm_name = "at90pwm216",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm2b = Cpu{
    .name = "at90pwm2b",
    .llvm_name = "at90pwm2b",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm3 = Cpu{
    .name = "at90pwm3",
    .llvm_name = "at90pwm3",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm316 = Cpu{
    .name = "at90pwm316",
    .llvm_name = "at90pwm316",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm3b = Cpu{
    .name = "at90pwm3b",
    .llvm_name = "at90pwm3b",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90pwm81 = Cpu{
    .name = "at90pwm81",
    .llvm_name = "at90pwm81",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90s1200 = Cpu{
    .name = "at90s1200",
    .llvm_name = "at90s1200",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_at90s2313 = Cpu{
    .name = "at90s2313",
    .llvm_name = "at90s2313",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s2323 = Cpu{
    .name = "at90s2323",
    .llvm_name = "at90s2323",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s2333 = Cpu{
    .name = "at90s2333",
    .llvm_name = "at90s2333",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s2343 = Cpu{
    .name = "at90s2343",
    .llvm_name = "at90s2343",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s4414 = Cpu{
    .name = "at90s4414",
    .llvm_name = "at90s4414",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s4433 = Cpu{
    .name = "at90s4433",
    .llvm_name = "at90s4433",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s4434 = Cpu{
    .name = "at90s4434",
    .llvm_name = "at90s4434",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s8515 = Cpu{
    .name = "at90s8515",
    .llvm_name = "at90s8515",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90s8535 = Cpu{
    .name = "at90s8535",
    .llvm_name = "at90s8535",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_at90scr100 = Cpu{
    .name = "at90scr100",
    .llvm_name = "at90scr100",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90usb1286 = Cpu{
    .name = "at90usb1286",
    .llvm_name = "at90usb1286",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90usb1287 = Cpu{
    .name = "at90usb1287",
    .llvm_name = "at90usb1287",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90usb162 = Cpu{
    .name = "at90usb162",
    .llvm_name = "at90usb162",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_at90usb646 = Cpu{
    .name = "at90usb646",
    .llvm_name = "at90usb646",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90usb647 = Cpu{
    .name = "at90usb647",
    .llvm_name = "at90usb647",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_at90usb82 = Cpu{
    .name = "at90usb82",
    .llvm_name = "at90usb82",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_at94k = Cpu{
    .name = "at94k",
    .llvm_name = "at94k",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
        &feature_mul,
    },
};

pub const cpu_ata5272 = Cpu{
    .name = "ata5272",
    .llvm_name = "ata5272",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_ata5505 = Cpu{
    .name = "ata5505",
    .llvm_name = "ata5505",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_ata5790 = Cpu{
    .name = "ata5790",
    .llvm_name = "ata5790",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_ata5795 = Cpu{
    .name = "ata5795",
    .llvm_name = "ata5795",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_ata6285 = Cpu{
    .name = "ata6285",
    .llvm_name = "ata6285",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_ata6286 = Cpu{
    .name = "ata6286",
    .llvm_name = "ata6286",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_ata6289 = Cpu{
    .name = "ata6289",
    .llvm_name = "ata6289",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega103 = Cpu{
    .name = "atmega103",
    .llvm_name = "atmega103",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_atmega128 = Cpu{
    .name = "atmega128",
    .llvm_name = "atmega128",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega1280 = Cpu{
    .name = "atmega1280",
    .llvm_name = "atmega1280",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega1281 = Cpu{
    .name = "atmega1281",
    .llvm_name = "atmega1281",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega1284 = Cpu{
    .name = "atmega1284",
    .llvm_name = "atmega1284",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega1284p = Cpu{
    .name = "atmega1284p",
    .llvm_name = "atmega1284p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega1284rfr2 = Cpu{
    .name = "atmega1284rfr2",
    .llvm_name = "atmega1284rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega128a = Cpu{
    .name = "atmega128a",
    .llvm_name = "atmega128a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega128rfa1 = Cpu{
    .name = "atmega128rfa1",
    .llvm_name = "atmega128rfa1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega128rfr2 = Cpu{
    .name = "atmega128rfr2",
    .llvm_name = "atmega128rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16 = Cpu{
    .name = "atmega16",
    .llvm_name = "atmega16",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega161 = Cpu{
    .name = "atmega161",
    .llvm_name = "atmega161",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
        &feature_mul,
        &feature_spm,
    },
};

pub const cpu_atmega162 = Cpu{
    .name = "atmega162",
    .llvm_name = "atmega162",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega163 = Cpu{
    .name = "atmega163",
    .llvm_name = "atmega163",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
        &feature_mul,
        &feature_spm,
    },
};

pub const cpu_atmega164a = Cpu{
    .name = "atmega164a",
    .llvm_name = "atmega164a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega164p = Cpu{
    .name = "atmega164p",
    .llvm_name = "atmega164p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega164pa = Cpu{
    .name = "atmega164pa",
    .llvm_name = "atmega164pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega165 = Cpu{
    .name = "atmega165",
    .llvm_name = "atmega165",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega165a = Cpu{
    .name = "atmega165a",
    .llvm_name = "atmega165a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega165p = Cpu{
    .name = "atmega165p",
    .llvm_name = "atmega165p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega165pa = Cpu{
    .name = "atmega165pa",
    .llvm_name = "atmega165pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega168 = Cpu{
    .name = "atmega168",
    .llvm_name = "atmega168",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega168a = Cpu{
    .name = "atmega168a",
    .llvm_name = "atmega168a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega168p = Cpu{
    .name = "atmega168p",
    .llvm_name = "atmega168p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega168pa = Cpu{
    .name = "atmega168pa",
    .llvm_name = "atmega168pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega169 = Cpu{
    .name = "atmega169",
    .llvm_name = "atmega169",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega169a = Cpu{
    .name = "atmega169a",
    .llvm_name = "atmega169a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega169p = Cpu{
    .name = "atmega169p",
    .llvm_name = "atmega169p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega169pa = Cpu{
    .name = "atmega169pa",
    .llvm_name = "atmega169pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16a = Cpu{
    .name = "atmega16a",
    .llvm_name = "atmega16a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16hva = Cpu{
    .name = "atmega16hva",
    .llvm_name = "atmega16hva",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16hva2 = Cpu{
    .name = "atmega16hva2",
    .llvm_name = "atmega16hva2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16hvb = Cpu{
    .name = "atmega16hvb",
    .llvm_name = "atmega16hvb",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16hvbrevb = Cpu{
    .name = "atmega16hvbrevb",
    .llvm_name = "atmega16hvbrevb",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16m1 = Cpu{
    .name = "atmega16m1",
    .llvm_name = "atmega16m1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega16u2 = Cpu{
    .name = "atmega16u2",
    .llvm_name = "atmega16u2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_atmega16u4 = Cpu{
    .name = "atmega16u4",
    .llvm_name = "atmega16u4",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega2560 = Cpu{
    .name = "atmega2560",
    .llvm_name = "atmega2560",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega2561 = Cpu{
    .name = "atmega2561",
    .llvm_name = "atmega2561",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega2564rfr2 = Cpu{
    .name = "atmega2564rfr2",
    .llvm_name = "atmega2564rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega256rfr2 = Cpu{
    .name = "atmega256rfr2",
    .llvm_name = "atmega256rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32 = Cpu{
    .name = "atmega32",
    .llvm_name = "atmega32",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega323 = Cpu{
    .name = "atmega323",
    .llvm_name = "atmega323",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega324a = Cpu{
    .name = "atmega324a",
    .llvm_name = "atmega324a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega324p = Cpu{
    .name = "atmega324p",
    .llvm_name = "atmega324p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega324pa = Cpu{
    .name = "atmega324pa",
    .llvm_name = "atmega324pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega325 = Cpu{
    .name = "atmega325",
    .llvm_name = "atmega325",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3250 = Cpu{
    .name = "atmega3250",
    .llvm_name = "atmega3250",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3250a = Cpu{
    .name = "atmega3250a",
    .llvm_name = "atmega3250a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3250p = Cpu{
    .name = "atmega3250p",
    .llvm_name = "atmega3250p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3250pa = Cpu{
    .name = "atmega3250pa",
    .llvm_name = "atmega3250pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega325a = Cpu{
    .name = "atmega325a",
    .llvm_name = "atmega325a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega325p = Cpu{
    .name = "atmega325p",
    .llvm_name = "atmega325p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega325pa = Cpu{
    .name = "atmega325pa",
    .llvm_name = "atmega325pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega328 = Cpu{
    .name = "atmega328",
    .llvm_name = "atmega328",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega328p = Cpu{
    .name = "atmega328p",
    .llvm_name = "atmega328p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega329 = Cpu{
    .name = "atmega329",
    .llvm_name = "atmega329",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3290 = Cpu{
    .name = "atmega3290",
    .llvm_name = "atmega3290",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3290a = Cpu{
    .name = "atmega3290a",
    .llvm_name = "atmega3290a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3290p = Cpu{
    .name = "atmega3290p",
    .llvm_name = "atmega3290p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega3290pa = Cpu{
    .name = "atmega3290pa",
    .llvm_name = "atmega3290pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega329a = Cpu{
    .name = "atmega329a",
    .llvm_name = "atmega329a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega329p = Cpu{
    .name = "atmega329p",
    .llvm_name = "atmega329p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega329pa = Cpu{
    .name = "atmega329pa",
    .llvm_name = "atmega329pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32a = Cpu{
    .name = "atmega32a",
    .llvm_name = "atmega32a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32c1 = Cpu{
    .name = "atmega32c1",
    .llvm_name = "atmega32c1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32hvb = Cpu{
    .name = "atmega32hvb",
    .llvm_name = "atmega32hvb",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32hvbrevb = Cpu{
    .name = "atmega32hvbrevb",
    .llvm_name = "atmega32hvbrevb",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32m1 = Cpu{
    .name = "atmega32m1",
    .llvm_name = "atmega32m1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32u2 = Cpu{
    .name = "atmega32u2",
    .llvm_name = "atmega32u2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_atmega32u4 = Cpu{
    .name = "atmega32u4",
    .llvm_name = "atmega32u4",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega32u6 = Cpu{
    .name = "atmega32u6",
    .llvm_name = "atmega32u6",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega406 = Cpu{
    .name = "atmega406",
    .llvm_name = "atmega406",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega48 = Cpu{
    .name = "atmega48",
    .llvm_name = "atmega48",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega48a = Cpu{
    .name = "atmega48a",
    .llvm_name = "atmega48a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega48p = Cpu{
    .name = "atmega48p",
    .llvm_name = "atmega48p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega48pa = Cpu{
    .name = "atmega48pa",
    .llvm_name = "atmega48pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64 = Cpu{
    .name = "atmega64",
    .llvm_name = "atmega64",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega640 = Cpu{
    .name = "atmega640",
    .llvm_name = "atmega640",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega644 = Cpu{
    .name = "atmega644",
    .llvm_name = "atmega644",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega644a = Cpu{
    .name = "atmega644a",
    .llvm_name = "atmega644a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega644p = Cpu{
    .name = "atmega644p",
    .llvm_name = "atmega644p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega644pa = Cpu{
    .name = "atmega644pa",
    .llvm_name = "atmega644pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega644rfr2 = Cpu{
    .name = "atmega644rfr2",
    .llvm_name = "atmega644rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega645 = Cpu{
    .name = "atmega645",
    .llvm_name = "atmega645",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6450 = Cpu{
    .name = "atmega6450",
    .llvm_name = "atmega6450",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6450a = Cpu{
    .name = "atmega6450a",
    .llvm_name = "atmega6450a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6450p = Cpu{
    .name = "atmega6450p",
    .llvm_name = "atmega6450p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega645a = Cpu{
    .name = "atmega645a",
    .llvm_name = "atmega645a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega645p = Cpu{
    .name = "atmega645p",
    .llvm_name = "atmega645p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega649 = Cpu{
    .name = "atmega649",
    .llvm_name = "atmega649",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6490 = Cpu{
    .name = "atmega6490",
    .llvm_name = "atmega6490",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6490a = Cpu{
    .name = "atmega6490a",
    .llvm_name = "atmega6490a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega6490p = Cpu{
    .name = "atmega6490p",
    .llvm_name = "atmega6490p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega649a = Cpu{
    .name = "atmega649a",
    .llvm_name = "atmega649a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega649p = Cpu{
    .name = "atmega649p",
    .llvm_name = "atmega649p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64a = Cpu{
    .name = "atmega64a",
    .llvm_name = "atmega64a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64c1 = Cpu{
    .name = "atmega64c1",
    .llvm_name = "atmega64c1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64hve = Cpu{
    .name = "atmega64hve",
    .llvm_name = "atmega64hve",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64m1 = Cpu{
    .name = "atmega64m1",
    .llvm_name = "atmega64m1",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega64rfr2 = Cpu{
    .name = "atmega64rfr2",
    .llvm_name = "atmega64rfr2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega8 = Cpu{
    .name = "atmega8",
    .llvm_name = "atmega8",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega8515 = Cpu{
    .name = "atmega8515",
    .llvm_name = "atmega8515",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
        &feature_mul,
        &feature_spm,
    },
};

pub const cpu_atmega8535 = Cpu{
    .name = "atmega8535",
    .llvm_name = "atmega8535",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
        &feature_movw,
        &feature_mul,
        &feature_spm,
    },
};

pub const cpu_atmega88 = Cpu{
    .name = "atmega88",
    .llvm_name = "atmega88",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega88a = Cpu{
    .name = "atmega88a",
    .llvm_name = "atmega88a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega88p = Cpu{
    .name = "atmega88p",
    .llvm_name = "atmega88p",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega88pa = Cpu{
    .name = "atmega88pa",
    .llvm_name = "atmega88pa",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega8a = Cpu{
    .name = "atmega8a",
    .llvm_name = "atmega8a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega8hva = Cpu{
    .name = "atmega8hva",
    .llvm_name = "atmega8hva",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atmega8u2 = Cpu{
    .name = "atmega8u2",
    .llvm_name = "atmega8u2",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny10 = Cpu{
    .name = "attiny10",
    .llvm_name = "attiny10",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny102 = Cpu{
    .name = "attiny102",
    .llvm_name = "attiny102",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny104 = Cpu{
    .name = "attiny104",
    .llvm_name = "attiny104",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny11 = Cpu{
    .name = "attiny11",
    .llvm_name = "attiny11",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
    },
};

pub const cpu_attiny12 = Cpu{
    .name = "attiny12",
    .llvm_name = "attiny12",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
    },
};

pub const cpu_attiny13 = Cpu{
    .name = "attiny13",
    .llvm_name = "attiny13",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny13a = Cpu{
    .name = "attiny13a",
    .llvm_name = "attiny13a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny15 = Cpu{
    .name = "attiny15",
    .llvm_name = "attiny15",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
    },
};

pub const cpu_attiny1634 = Cpu{
    .name = "attiny1634",
    .llvm_name = "attiny1634",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny167 = Cpu{
    .name = "attiny167",
    .llvm_name = "attiny167",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny20 = Cpu{
    .name = "attiny20",
    .llvm_name = "attiny20",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny22 = Cpu{
    .name = "attiny22",
    .llvm_name = "attiny22",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_attiny2313 = Cpu{
    .name = "attiny2313",
    .llvm_name = "attiny2313",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny2313a = Cpu{
    .name = "attiny2313a",
    .llvm_name = "attiny2313a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny24 = Cpu{
    .name = "attiny24",
    .llvm_name = "attiny24",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny24a = Cpu{
    .name = "attiny24a",
    .llvm_name = "attiny24a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny25 = Cpu{
    .name = "attiny25",
    .llvm_name = "attiny25",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny26 = Cpu{
    .name = "attiny26",
    .llvm_name = "attiny26",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
        &feature_lpmx,
    },
};

pub const cpu_attiny261 = Cpu{
    .name = "attiny261",
    .llvm_name = "attiny261",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny261a = Cpu{
    .name = "attiny261a",
    .llvm_name = "attiny261a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny28 = Cpu{
    .name = "attiny28",
    .llvm_name = "attiny28",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
    },
};

pub const cpu_attiny4 = Cpu{
    .name = "attiny4",
    .llvm_name = "attiny4",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny40 = Cpu{
    .name = "attiny40",
    .llvm_name = "attiny40",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny4313 = Cpu{
    .name = "attiny4313",
    .llvm_name = "attiny4313",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny43u = Cpu{
    .name = "attiny43u",
    .llvm_name = "attiny43u",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny44 = Cpu{
    .name = "attiny44",
    .llvm_name = "attiny44",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny44a = Cpu{
    .name = "attiny44a",
    .llvm_name = "attiny44a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny45 = Cpu{
    .name = "attiny45",
    .llvm_name = "attiny45",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny461 = Cpu{
    .name = "attiny461",
    .llvm_name = "attiny461",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny461a = Cpu{
    .name = "attiny461a",
    .llvm_name = "attiny461a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny48 = Cpu{
    .name = "attiny48",
    .llvm_name = "attiny48",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny5 = Cpu{
    .name = "attiny5",
    .llvm_name = "attiny5",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_attiny828 = Cpu{
    .name = "attiny828",
    .llvm_name = "attiny828",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny84 = Cpu{
    .name = "attiny84",
    .llvm_name = "attiny84",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny84a = Cpu{
    .name = "attiny84a",
    .llvm_name = "attiny84a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny85 = Cpu{
    .name = "attiny85",
    .llvm_name = "attiny85",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny861 = Cpu{
    .name = "attiny861",
    .llvm_name = "attiny861",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny861a = Cpu{
    .name = "attiny861a",
    .llvm_name = "attiny861a",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny87 = Cpu{
    .name = "attiny87",
    .llvm_name = "attiny87",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny88 = Cpu{
    .name = "attiny88",
    .llvm_name = "attiny88",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_attiny9 = Cpu{
    .name = "attiny9",
    .llvm_name = "attiny9",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_atxmega128a1 = Cpu{
    .name = "atxmega128a1",
    .llvm_name = "atxmega128a1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128a1u = Cpu{
    .name = "atxmega128a1u",
    .llvm_name = "atxmega128a1u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128a3 = Cpu{
    .name = "atxmega128a3",
    .llvm_name = "atxmega128a3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128a3u = Cpu{
    .name = "atxmega128a3u",
    .llvm_name = "atxmega128a3u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128a4u = Cpu{
    .name = "atxmega128a4u",
    .llvm_name = "atxmega128a4u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128b1 = Cpu{
    .name = "atxmega128b1",
    .llvm_name = "atxmega128b1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128b3 = Cpu{
    .name = "atxmega128b3",
    .llvm_name = "atxmega128b3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128c3 = Cpu{
    .name = "atxmega128c3",
    .llvm_name = "atxmega128c3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128d3 = Cpu{
    .name = "atxmega128d3",
    .llvm_name = "atxmega128d3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega128d4 = Cpu{
    .name = "atxmega128d4",
    .llvm_name = "atxmega128d4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega16a4 = Cpu{
    .name = "atxmega16a4",
    .llvm_name = "atxmega16a4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega16a4u = Cpu{
    .name = "atxmega16a4u",
    .llvm_name = "atxmega16a4u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega16c4 = Cpu{
    .name = "atxmega16c4",
    .llvm_name = "atxmega16c4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega16d4 = Cpu{
    .name = "atxmega16d4",
    .llvm_name = "atxmega16d4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega16e5 = Cpu{
    .name = "atxmega16e5",
    .llvm_name = "atxmega16e5",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega192a3 = Cpu{
    .name = "atxmega192a3",
    .llvm_name = "atxmega192a3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega192a3u = Cpu{
    .name = "atxmega192a3u",
    .llvm_name = "atxmega192a3u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega192c3 = Cpu{
    .name = "atxmega192c3",
    .llvm_name = "atxmega192c3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega192d3 = Cpu{
    .name = "atxmega192d3",
    .llvm_name = "atxmega192d3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256a3 = Cpu{
    .name = "atxmega256a3",
    .llvm_name = "atxmega256a3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256a3b = Cpu{
    .name = "atxmega256a3b",
    .llvm_name = "atxmega256a3b",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256a3bu = Cpu{
    .name = "atxmega256a3bu",
    .llvm_name = "atxmega256a3bu",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256a3u = Cpu{
    .name = "atxmega256a3u",
    .llvm_name = "atxmega256a3u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256c3 = Cpu{
    .name = "atxmega256c3",
    .llvm_name = "atxmega256c3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega256d3 = Cpu{
    .name = "atxmega256d3",
    .llvm_name = "atxmega256d3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32a4 = Cpu{
    .name = "atxmega32a4",
    .llvm_name = "atxmega32a4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32a4u = Cpu{
    .name = "atxmega32a4u",
    .llvm_name = "atxmega32a4u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32c4 = Cpu{
    .name = "atxmega32c4",
    .llvm_name = "atxmega32c4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32d4 = Cpu{
    .name = "atxmega32d4",
    .llvm_name = "atxmega32d4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32e5 = Cpu{
    .name = "atxmega32e5",
    .llvm_name = "atxmega32e5",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega32x1 = Cpu{
    .name = "atxmega32x1",
    .llvm_name = "atxmega32x1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega384c3 = Cpu{
    .name = "atxmega384c3",
    .llvm_name = "atxmega384c3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega384d3 = Cpu{
    .name = "atxmega384d3",
    .llvm_name = "atxmega384d3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64a1 = Cpu{
    .name = "atxmega64a1",
    .llvm_name = "atxmega64a1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64a1u = Cpu{
    .name = "atxmega64a1u",
    .llvm_name = "atxmega64a1u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64a3 = Cpu{
    .name = "atxmega64a3",
    .llvm_name = "atxmega64a3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64a3u = Cpu{
    .name = "atxmega64a3u",
    .llvm_name = "atxmega64a3u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64a4u = Cpu{
    .name = "atxmega64a4u",
    .llvm_name = "atxmega64a4u",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64b1 = Cpu{
    .name = "atxmega64b1",
    .llvm_name = "atxmega64b1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64b3 = Cpu{
    .name = "atxmega64b3",
    .llvm_name = "atxmega64b3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64c3 = Cpu{
    .name = "atxmega64c3",
    .llvm_name = "atxmega64c3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_rmw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64d3 = Cpu{
    .name = "atxmega64d3",
    .llvm_name = "atxmega64d3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega64d4 = Cpu{
    .name = "atxmega64d4",
    .llvm_name = "atxmega64d4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_atxmega8e5 = Cpu{
    .name = "atxmega8e5",
    .llvm_name = "atxmega8e5",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avr1 = Cpu{
    .name = "avr1",
    .llvm_name = "avr1",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
    },
};

pub const cpu_avr2 = Cpu{
    .name = "avr2",
    .llvm_name = "avr2",
    .dependencies = &[_]*const Feature {
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_avr25 = Cpu{
    .name = "avr25",
    .llvm_name = "avr25",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_avr3 = Cpu{
    .name = "avr3",
    .llvm_name = "avr3",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_avr31 = Cpu{
    .name = "avr31",
    .llvm_name = "avr31",
    .dependencies = &[_]*const Feature {
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_ijmpcall,
    },
};

pub const cpu_avr35 = Cpu{
    .name = "avr35",
    .llvm_name = "avr35",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
    },
};

pub const cpu_avr4 = Cpu{
    .name = "avr4",
    .llvm_name = "avr4",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avr5 = Cpu{
    .name = "avr5",
    .llvm_name = "avr5",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avr51 = Cpu{
    .name = "avr51",
    .llvm_name = "avr51",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avr6 = Cpu{
    .name = "avr6",
    .llvm_name = "avr6",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrtiny = Cpu{
    .name = "avrtiny",
    .llvm_name = "avrtiny",
    .dependencies = &[_]*const Feature {
        &feature_sram,
        &feature_break,
        &feature_tinyencoding,
    },
};

pub const cpu_avrxmega1 = Cpu{
    .name = "avrxmega1",
    .llvm_name = "avrxmega1",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega2 = Cpu{
    .name = "avrxmega2",
    .llvm_name = "avrxmega2",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega3 = Cpu{
    .name = "avrxmega3",
    .llvm_name = "avrxmega3",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega4 = Cpu{
    .name = "avrxmega4",
    .llvm_name = "avrxmega4",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega5 = Cpu{
    .name = "avrxmega5",
    .llvm_name = "avrxmega5",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega6 = Cpu{
    .name = "avrxmega6",
    .llvm_name = "avrxmega6",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_avrxmega7 = Cpu{
    .name = "avrxmega7",
    .llvm_name = "avrxmega7",
    .dependencies = &[_]*const Feature {
        &feature_spmx,
        &feature_des,
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_elpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_elpmx,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_eijmpcall,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpu_m3000 = Cpu{
    .name = "m3000",
    .llvm_name = "m3000",
    .dependencies = &[_]*const Feature {
        &feature_lpmx,
        &feature_jmpcall,
        &feature_lpm,
        &feature_sram,
        &feature_addsubiw,
        &feature_movw,
        &feature_ijmpcall,
        &feature_break,
        &feature_spm,
        &feature_mul,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_at43usb320,
    &cpu_at43usb355,
    &cpu_at76c711,
    &cpu_at86rf401,
    &cpu_at90c8534,
    &cpu_at90can128,
    &cpu_at90can32,
    &cpu_at90can64,
    &cpu_at90pwm1,
    &cpu_at90pwm161,
    &cpu_at90pwm2,
    &cpu_at90pwm216,
    &cpu_at90pwm2b,
    &cpu_at90pwm3,
    &cpu_at90pwm316,
    &cpu_at90pwm3b,
    &cpu_at90pwm81,
    &cpu_at90s1200,
    &cpu_at90s2313,
    &cpu_at90s2323,
    &cpu_at90s2333,
    &cpu_at90s2343,
    &cpu_at90s4414,
    &cpu_at90s4433,
    &cpu_at90s4434,
    &cpu_at90s8515,
    &cpu_at90s8535,
    &cpu_at90scr100,
    &cpu_at90usb1286,
    &cpu_at90usb1287,
    &cpu_at90usb162,
    &cpu_at90usb646,
    &cpu_at90usb647,
    &cpu_at90usb82,
    &cpu_at94k,
    &cpu_ata5272,
    &cpu_ata5505,
    &cpu_ata5790,
    &cpu_ata5795,
    &cpu_ata6285,
    &cpu_ata6286,
    &cpu_ata6289,
    &cpu_atmega103,
    &cpu_atmega128,
    &cpu_atmega1280,
    &cpu_atmega1281,
    &cpu_atmega1284,
    &cpu_atmega1284p,
    &cpu_atmega1284rfr2,
    &cpu_atmega128a,
    &cpu_atmega128rfa1,
    &cpu_atmega128rfr2,
    &cpu_atmega16,
    &cpu_atmega161,
    &cpu_atmega162,
    &cpu_atmega163,
    &cpu_atmega164a,
    &cpu_atmega164p,
    &cpu_atmega164pa,
    &cpu_atmega165,
    &cpu_atmega165a,
    &cpu_atmega165p,
    &cpu_atmega165pa,
    &cpu_atmega168,
    &cpu_atmega168a,
    &cpu_atmega168p,
    &cpu_atmega168pa,
    &cpu_atmega169,
    &cpu_atmega169a,
    &cpu_atmega169p,
    &cpu_atmega169pa,
    &cpu_atmega16a,
    &cpu_atmega16hva,
    &cpu_atmega16hva2,
    &cpu_atmega16hvb,
    &cpu_atmega16hvbrevb,
    &cpu_atmega16m1,
    &cpu_atmega16u2,
    &cpu_atmega16u4,
    &cpu_atmega2560,
    &cpu_atmega2561,
    &cpu_atmega2564rfr2,
    &cpu_atmega256rfr2,
    &cpu_atmega32,
    &cpu_atmega323,
    &cpu_atmega324a,
    &cpu_atmega324p,
    &cpu_atmega324pa,
    &cpu_atmega325,
    &cpu_atmega3250,
    &cpu_atmega3250a,
    &cpu_atmega3250p,
    &cpu_atmega3250pa,
    &cpu_atmega325a,
    &cpu_atmega325p,
    &cpu_atmega325pa,
    &cpu_atmega328,
    &cpu_atmega328p,
    &cpu_atmega329,
    &cpu_atmega3290,
    &cpu_atmega3290a,
    &cpu_atmega3290p,
    &cpu_atmega3290pa,
    &cpu_atmega329a,
    &cpu_atmega329p,
    &cpu_atmega329pa,
    &cpu_atmega32a,
    &cpu_atmega32c1,
    &cpu_atmega32hvb,
    &cpu_atmega32hvbrevb,
    &cpu_atmega32m1,
    &cpu_atmega32u2,
    &cpu_atmega32u4,
    &cpu_atmega32u6,
    &cpu_atmega406,
    &cpu_atmega48,
    &cpu_atmega48a,
    &cpu_atmega48p,
    &cpu_atmega48pa,
    &cpu_atmega64,
    &cpu_atmega640,
    &cpu_atmega644,
    &cpu_atmega644a,
    &cpu_atmega644p,
    &cpu_atmega644pa,
    &cpu_atmega644rfr2,
    &cpu_atmega645,
    &cpu_atmega6450,
    &cpu_atmega6450a,
    &cpu_atmega6450p,
    &cpu_atmega645a,
    &cpu_atmega645p,
    &cpu_atmega649,
    &cpu_atmega6490,
    &cpu_atmega6490a,
    &cpu_atmega6490p,
    &cpu_atmega649a,
    &cpu_atmega649p,
    &cpu_atmega64a,
    &cpu_atmega64c1,
    &cpu_atmega64hve,
    &cpu_atmega64m1,
    &cpu_atmega64rfr2,
    &cpu_atmega8,
    &cpu_atmega8515,
    &cpu_atmega8535,
    &cpu_atmega88,
    &cpu_atmega88a,
    &cpu_atmega88p,
    &cpu_atmega88pa,
    &cpu_atmega8a,
    &cpu_atmega8hva,
    &cpu_atmega8u2,
    &cpu_attiny10,
    &cpu_attiny102,
    &cpu_attiny104,
    &cpu_attiny11,
    &cpu_attiny12,
    &cpu_attiny13,
    &cpu_attiny13a,
    &cpu_attiny15,
    &cpu_attiny1634,
    &cpu_attiny167,
    &cpu_attiny20,
    &cpu_attiny22,
    &cpu_attiny2313,
    &cpu_attiny2313a,
    &cpu_attiny24,
    &cpu_attiny24a,
    &cpu_attiny25,
    &cpu_attiny26,
    &cpu_attiny261,
    &cpu_attiny261a,
    &cpu_attiny28,
    &cpu_attiny4,
    &cpu_attiny40,
    &cpu_attiny4313,
    &cpu_attiny43u,
    &cpu_attiny44,
    &cpu_attiny44a,
    &cpu_attiny45,
    &cpu_attiny461,
    &cpu_attiny461a,
    &cpu_attiny48,
    &cpu_attiny5,
    &cpu_attiny828,
    &cpu_attiny84,
    &cpu_attiny84a,
    &cpu_attiny85,
    &cpu_attiny861,
    &cpu_attiny861a,
    &cpu_attiny87,
    &cpu_attiny88,
    &cpu_attiny9,
    &cpu_atxmega128a1,
    &cpu_atxmega128a1u,
    &cpu_atxmega128a3,
    &cpu_atxmega128a3u,
    &cpu_atxmega128a4u,
    &cpu_atxmega128b1,
    &cpu_atxmega128b3,
    &cpu_atxmega128c3,
    &cpu_atxmega128d3,
    &cpu_atxmega128d4,
    &cpu_atxmega16a4,
    &cpu_atxmega16a4u,
    &cpu_atxmega16c4,
    &cpu_atxmega16d4,
    &cpu_atxmega16e5,
    &cpu_atxmega192a3,
    &cpu_atxmega192a3u,
    &cpu_atxmega192c3,
    &cpu_atxmega192d3,
    &cpu_atxmega256a3,
    &cpu_atxmega256a3b,
    &cpu_atxmega256a3bu,
    &cpu_atxmega256a3u,
    &cpu_atxmega256c3,
    &cpu_atxmega256d3,
    &cpu_atxmega32a4,
    &cpu_atxmega32a4u,
    &cpu_atxmega32c4,
    &cpu_atxmega32d4,
    &cpu_atxmega32e5,
    &cpu_atxmega32x1,
    &cpu_atxmega384c3,
    &cpu_atxmega384d3,
    &cpu_atxmega64a1,
    &cpu_atxmega64a1u,
    &cpu_atxmega64a3,
    &cpu_atxmega64a3u,
    &cpu_atxmega64a4u,
    &cpu_atxmega64b1,
    &cpu_atxmega64b3,
    &cpu_atxmega64c3,
    &cpu_atxmega64d3,
    &cpu_atxmega64d4,
    &cpu_atxmega8e5,
    &cpu_avr1,
    &cpu_avr2,
    &cpu_avr25,
    &cpu_avr3,
    &cpu_avr31,
    &cpu_avr35,
    &cpu_avr4,
    &cpu_avr5,
    &cpu_avr51,
    &cpu_avr6,
    &cpu_avrtiny,
    &cpu_avrxmega1,
    &cpu_avrxmega2,
    &cpu_avrxmega3,
    &cpu_avrxmega4,
    &cpu_avrxmega5,
    &cpu_avrxmega6,
    &cpu_avrxmega7,
    &cpu_m3000,
};
