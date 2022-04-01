from dotviewer.msgstruct import *


def test_message():
    yield checkmsg, 'A'
    yield checkmsg, 'B', 123, "hello", -128, -129
    yield checkmsg, 'C', "x" * 12345 + "y"
    yield checkmsg, 'D',  2147483647,  2147483648,  2147483649,  2147483647000
    yield checkmsg, 'E', -2147483647, -2147483648, -2147483649, -2147483647000
    yield (checkmsg, 'F',) + tuple(range(9999))

def checkmsg(*args):
    encoded = message(*args)
    assert decodemessage(encoded[:-1]) == (None, encoded[:-1])
    assert decodemessage(encoded) == (args, '')
    assert decodemessage(encoded + 'FooBar') == (args, 'FooBar')
