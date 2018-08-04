# This is the _load_config_used definition needed for /guard:cf tests.

        .section .rdata,"dr"
.globl _load_config_used
_load_config_used:
        .long 256
        .fill 124, 1, 0
        .quad __guard_fids_table
        .quad __guard_fids_count
        .long __guard_flags
        .fill 128, 1, 0
