const high_bit = 1 << @typeInfo(usize).Int.bits - 1;

/// UEFI Specification, Version 2.8, Appendix D
pub const success: usize = 0;

pub const load_error: usize = high_bit | 1;
pub const invalid_parameter: usize = high_bit | 2;
pub const unsupported: usize = high_bit | 3;
pub const bad_buffer_size: usize = high_bit | 4;
pub const buffer_too_small: usize = high_bit | 5;
pub const not_ready: usize = high_bit | 6;
pub const device_error: usize = high_bit | 7;
pub const write_protected: usize = high_bit | 8;
pub const out_of_resources: usize = high_bit | 9;
pub const volume_corrupted: usize = high_bit | 10;
pub const volume_full: usize = high_bit | 11;
pub const no_media: usize = high_bit | 12;
pub const media_changed: usize = high_bit | 13;
pub const not_found: usize = high_bit | 14;
pub const access_denied: usize = high_bit | 15;
pub const no_response: usize = high_bit | 16;
pub const no_mapping: usize = high_bit | 17;
pub const timeout: usize = high_bit | 18;
pub const not_started: usize = high_bit | 19;
pub const already_started: usize = high_bit | 20;
pub const aborted: usize = high_bit | 21;
pub const icmp_error: usize = high_bit | 22;
pub const tftp_error: usize = high_bit | 23;
pub const protocol_error: usize = high_bit | 24;
pub const incompatible_version: usize = high_bit | 25;
pub const security_violation: usize = high_bit | 26;
pub const crc_error: usize = high_bit | 27;
pub const end_of_media: usize = high_bit | 28;
pub const end_of_file: usize = high_bit | 31;
pub const invalid_language: usize = high_bit | 32;
pub const compromised_data: usize = high_bit | 33;
pub const ip_address_conflict: usize = high_bit | 34;
pub const http_error: usize = high_bit | 35;

pub const warn_unknown_glyph: usize = 1;
pub const warn_delete_failure: usize = 2;
pub const warn_write_failure: usize = 3;
pub const warn_buffer_too_small: usize = 4;
pub const warn_stale_data: usize = 5;
pub const warn_file_system: usize = 6;
pub const warn_reset_required: usize = 7;
