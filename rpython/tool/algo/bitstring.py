

def make_bitstring(lst):
    "NOT_RPYTHON"
    if not lst:
        return ''
    num_bits = max(lst) + 1
    num_bytes = (num_bits + 7) // 8
    entries = [0] * num_bytes
    for x in lst:
        assert x >= 0
        entries[x >> 3] |= 1 << (x & 7)
    return ''.join(map(chr, entries))

def bitcheck(bitstring, n):
    assert n >= 0
    byte_number = n >> 3
    if byte_number >= len(bitstring):
        return False
    return (ord(bitstring[byte_number]) & (1 << (n & 7))) != 0

def num_bits(bitstring):
    return len(bitstring) << 3
