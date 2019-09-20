    .section    .tls,"dw"
    .byte       0xaa

    .section    .tls$ZZZ,"dw"
    .byte       0xff

    .globl      _tls_index
    .data
_tls_index:
    .int        0
