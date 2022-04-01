import _operator

def bin(x):
    """Return the binary representation of an integer.

    >>> bin(2796202)
    '0b1010101010101010101010'

    """
    value = _operator.index(x)
    return value.__format__("#b")

def oct(x):
    """Return the octal representation of an integer.

    >>> oct(342391)
    '0o1234567'

    """
    x = _operator.index(x)
    return x.__format__("#o")

def hex(x):
    """Return the hexadecimal representation of an integer.

    >>> hex(12648430)
    '0xc0ffee'

    """
    x = _operator.index(x)
    return x.__format__("#x")
