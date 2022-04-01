
from rpython.rlib import rutf8
from rpython.rlib.rstring import StringBuilder, UnicodeBuilder
from rpython.rlib.unicodedata import unicodedb_5_2_0 as unicodedb

l = ["u" * 100 + str(i) for i in range(100)]
u_l = [unicode("u" * 100 + str(i)) for i in range(100)]

def descr_upper(s):
    builder = rutf8.Utf8StringBuilder(len(s))
    for ch in rutf8.Utf8StringIterator(s):
        ch = unicodedb.toupper(ch)
        builder.append_code(ch)
    return builder.build()
descr_upper._dont_inline_ = True

def descr_upper_s(s):
    builder = StringBuilder(len(s))
    for i in range(len(s)):
        ch = s[i]
        builder.append(chr(unicodedb.toupper(ord(ch))))
    return builder.build()

def descr_upper_u(s):
    builder = UnicodeBuilder(len(s))
    for ch in s:
        builder.append(unichr(unicodedb.toupper(ord(ch))))
    return builder.build()

def main(argv):
    res_l = ["foo"]
    res_l_2 = [u"foo"]
    if len(argv) > 2 and argv[2] == "s":
        for i in range(int(argv[1])):
            res_l[0] = descr_upper_s(l[i % 100])
    elif len(argv) > 2 and argv[2] == "u":
        for i in range(int(argv[1])):
            res_l_2[0] = descr_upper_u(u_l[i % 100])
    else:
        for i in range(int(argv[1])):
            res_l[0] = descr_upper(l[i % 100])
    return 0

def target(*args):
    return main
