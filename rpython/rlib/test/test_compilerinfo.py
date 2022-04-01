from rpython.rlib.compilerinfo import get_compiler_info
from rpython.translator.c.test.test_genc import compile


def test_untranslated():
    assert get_compiler_info() == "(untranslated)"

def fn(index):
    cc = get_compiler_info()
    if index < len(cc):
        return ord(cc[index])
    return 0

def test_compiled():
    fn2 = compile(fn, [int])
    lst = []
    index = 0
    while True:
        c = fn2(index)
        if c == 0:
            break
        lst.append(chr(c))
        index += 1
    s = ''.join(lst)
    print s
    assert s.startswith('MSC ') or s.startswith('GCC ')
