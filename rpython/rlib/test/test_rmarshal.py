import py
import marshal
from rpython.rlib.rmarshal import *
from rpython.annotator import model as annmodel
from rpython.rlib.rarithmetic import LONG_BIT
from rpython.rlib.rfloat import formatd

types_that_can_be_none = [
    [int],
    annmodel.SomeString(can_be_None=True),
    annmodel.s_None,
    {int: int},
    ]


def test_marshaller():
    buf = []
    get_marshaller(int)(buf, 5)
    assert marshal.loads(''.join(buf)) == 5

    buf = []
    get_marshaller(int)(buf, -555)
    assert marshal.loads(''.join(buf)) == -555

    buf = []
    get_marshaller(float)(buf, 3.25)
    assert marshal.loads(''.join(buf)) == 3.25

    buf = []
    get_marshaller(str)(buf, "hello, world")
    assert marshal.loads(''.join(buf)) == "hello, world"

    buf = []
    get_marshaller(bool)(buf, False)
    assert marshal.loads(''.join(buf)) is False

    buf = []
    get_marshaller(bool)(buf, True)
    assert marshal.loads(''.join(buf)) is True

    buf = []
    get_marshaller(r_longlong)(buf, r_longlong(0x12380000007))
    assert marshal.loads(''.join(buf)) == 0x12380000007

    buf = []
    get_marshaller(r_longlong)(buf, r_longlong(-0x12380000007))
    assert marshal.loads(''.join(buf)) == -0x12380000007

    if LONG_BIT > 32:
        buf = []
        get_marshaller(int)(buf, -0x12340000007)
        assert marshal.loads(''.join(buf)) == -0x12340000007

    buf = []
    get_marshaller([int])(buf, [2, 5, -7])
    assert marshal.loads(''.join(buf)) == [2, 5, -7]

    buf = []
    get_marshaller((int, float, (str, ())))(buf, (7, -1.5, ("foo", ())))
    assert marshal.loads(''.join(buf)) == (7, -1.5, ("foo", ()))

    buf = []
    get_marshaller({int: str})(buf, {2: "foo", -3: "bar"})
    assert marshal.loads(''.join(buf)) == {2: "foo", -3: "bar"}

    for typ in types_that_can_be_none:
        buf = []
        get_marshaller(typ)(buf, None)
        assert marshal.loads(''.join(buf)) is None


def test_unmarshaller():
    buf = 'i\x05\x00\x00\x00'
    assert get_unmarshaller(int)(buf) == 5

    buf = 'i\x00\xf0\xff\xff'
    assert get_unmarshaller(int)(buf) == -4096

    buf = 'f\x043.25'
    assert get_unmarshaller(float)(buf) == 3.25

    buf = 's\x0c\x00\x00\x00hello, world'
    assert get_unmarshaller(str)(buf) == "hello, world"

    buf = 's\x01\x00\x00\x00X'
    assert get_unmarshaller(annmodel.SomeChar())(buf) == "X"

    buf = 'i\x05\x00\x00\x00'
    py.test.raises(ValueError, get_unmarshaller(str), buf)

    buf = 'F'
    assert get_unmarshaller(bool)(buf) is False

    buf = 'T'
    assert get_unmarshaller(bool)(buf) is True

    buf = 'I\x07\x00\x00\x80\x23\x01\x00\x00'
    assert get_unmarshaller(r_longlong)(buf) == 0x12380000007

    buf = 'I\x00\x00\x01\x83\x80\x00\x00\x97'
    assert get_unmarshaller(r_longlong)(buf) == -7566046822028738560L

    if LONG_BIT > 32:
        buf = 'I\x07\x00\x00\x80\x23\x01\x00\x00'
        assert get_unmarshaller(int)(buf) == 0x12380000007

        buf = 'I\x00\x00\x01\x83\x80\x00\x00\x97'
        assert get_unmarshaller(int)(buf) == -7566046822028738560

    buf = ('[\x03\x00\x00\x00i\x02\x00\x00\x00i\x05\x00\x00\x00'
           'i\xf9\xff\xff\xff')
    assert get_unmarshaller([int])(buf) == [2, 5, -7]

    buf = ('(\x02\x00\x00\x00i\x07\x00\x00\x00(\x02\x00\x00\x00'
           's\x03\x00\x00\x00foo(\x00\x00\x00\x00')
    res = get_unmarshaller((int, (str, ())))(buf)
    assert res == (7, ("foo", ()))

    buf = ('{i\xfb\xff\xff\xffs\x03\x00\x00\x00bar'
           'i\x06\x00\x00\x00s\x00\x00\x00\x000')
    res = get_unmarshaller({int: str})(buf)
    assert res == {-5: "bar", 6: ""}

    for typ in types_that_can_be_none:
        buf = 'N'
        assert get_unmarshaller(typ)(buf) is None


def test_llinterp_marshal():
    from rpython.rtyper.test.test_llinterp import interpret
    marshaller1 = get_marshaller([(int, str, float)])
    marshaller2 = get_marshaller([(int, str, int)])
    def f():
        buf = []
        marshaller1(buf, [(5, "hello", -0.5), (7, "world", 1E100)])
        marshaller2(buf, [(5, "hello", 1)])
        return ''.join(buf)
    res = interpret(f, [])
    res = ''.join(res.chars)
    if LONG_BIT == 32:
        assert res == ('[\x02\x00\x00\x00(\x03\x00\x00\x00i\x05\x00\x00\x00'
                       's\x05\x00\x00\x00hellof\x04-0.5(\x03\x00\x00\x00'
                       'i\x07\x00\x00\x00s\x05\x00\x00\x00world'
                       'f\x061e+100'
                       '[\x01\x00\x00\x00(\x03\x00\x00\x00i\x05\x00\x00\x00'
                       's\x05\x00\x00\x00helloi\x01\x00\x00\x00')
    else:
        assert res == ('[\x02\x00\x00\x00(\x03\x00\x00\x00'
                       'I\x05\x00\x00\x00\x00\x00\x00\x00'
                       's\x05\x00\x00\x00hellof\x04-0.5(\x03\x00\x00\x00'
                       'I\x07\x00\x00\x00\x00\x00\x00\x00'
                       's\x05\x00\x00\x00world'
                       'f\x061e+100'
                       '[\x01\x00\x00\x00(\x03\x00\x00\x00'
                       'I\x05\x00\x00\x00\x00\x00\x00\x00'
                       's\x05\x00\x00\x00hello'
                       'I\x01\x00\x00\x00\x00\x00\x00\x00')

def test_llinterp_unmarshal():
    from rpython.rtyper.test.test_llinterp import interpret
    unmarshaller = get_unmarshaller([(int, str, float)])
    buf = ('[\x02\x00\x00\x00(\x03\x00\x00\x00i\x05\x00\x00\x00'
           's\x05\x00\x00\x00hellof\x04-0.5(\x03\x00\x00\x00'
           'i\x07\x00\x00\x00s\x05\x00\x00\x00world'
           'f\x061e+100')
    def f():
        result = ''
        for num, string, fval in unmarshaller(buf):
            result += '%d=%s/%s;' % (num, string, formatd(fval, 'g', 17))
        return result
    res = interpret(f, [])
    res = ''.join(res.chars)
    assert res == '5=hello/-0.5;7=world/1e+100;'

def test_stat_result():
    import os
    from rpython.translator.c.test.test_genc import compile
    from rpython.rlib.rposix_stat import s_StatResult
    marshal_stat_result = get_marshaller(s_StatResult)
    unmarshal_stat_result = get_unmarshaller(s_StatResult)
    def f(path):
        st = os.stat(path)
        buf = []
        marshal_stat_result(buf, st)
        buf = ''.join(buf)
        st2 = unmarshal_stat_result(buf)
        assert st2.st_mode == st.st_mode
        assert st2[9] == st[9]
        return buf
    fn = compile(f, [str])
    res = fn('.')
    st = os.stat('.')
    sttuple = marshal.loads(res)
    assert sttuple[0] == st[0]
    assert sttuple[1] == st[1]
    assert sttuple[2] == st[2]
    assert sttuple[3] == st[3]
    assert sttuple[4] == st[4]
    assert sttuple[5] == st[5]
    assert len(sttuple) == 10

def test_longlong():
    # get_loader for (r_longolong, nonneg=True) used to return
    # load_int_nonneg on 32-bit, instead of load_longlong.
    for nonneg in [True, False]:
        s_longlong = annmodel.SomeInteger(knowntype=r_longlong, nonneg=nonneg)
        load = get_loader(s_longlong)
        loader = Loader("I\x01\x23\x45\x67\x89\xab\xcd\x0e")
        res = load(loader)
        assert res == 0x0ecdab8967452301
