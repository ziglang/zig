// Modes for dlopen()

/// Bind function calls lazily.
pub const RTLD_LAZY = 1;

/// Bind function calls immediately.
pub const RTLD_NOW = 2;

/// Allow global searches in object.
pub const RTLD_GLOBAL = 0x100;

/// Opposite of RTLD_GLOBAL, and the default.
pub const RTLD_LOCAL = 0x000;

/// Trace loaded objects and exit.
pub const RTLD_TRACE = 0x200;

pub const DT_UNKNOWN = 0;
pub const DT_FIFO = 1;
pub const DT_CHR = 2;
pub const DT_DIR = 4;
pub const DT_BLK = 6;
pub const DT_REG = 8;
pub const DT_LNK = 10;
pub const DT_SOCK = 12;
