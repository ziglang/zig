# -*- encoding: utf-8 -*-

import py, os, errno
from pypy.interpreter.error import (
    OperationError, decompose_valuefmt, get_operrcls2, new_exception_class,
    oefmt, wrap_oserror, new_import_error, get_operr_withname_error_class)


def test_decompose_valuefmt():
    assert (decompose_valuefmt("abc %s def") ==
            (("abc ", " def"), ('s',)))
    assert (decompose_valuefmt("%s%d%s") ==
            (("", "", "", ""), ('s', 'd', 's')))
    assert (decompose_valuefmt("%s%d%%%s") ==
            (("", "", "%", ""), ('s', 'd', 's')))

def test_get_operrcls2(space):
    cls, strings = get_operrcls2('abc %s def %d')
    assert strings == ("abc ", " def ", "")
    assert issubclass(cls, OperationError)
    inst = cls("w_type", strings, "hello", 42)
    assert inst._compute_value(space) == ("abc hello def 42", 16)
    cls2, strings2 = get_operrcls2('a %s b %d c')
    assert cls2 is cls     # caching
    assert strings2 == ("a ", " b ", " c")

def test_get_operr_withname_error_class(space):
    cls, strings = get_operr_withname_error_class('abc %s def %s', 'AttributeError')
    cls2, strings2 = get_operr_withname_error_class('abc %s def %s', 'AttributeError')
    assert cls2 is cls
    assert strings is strings2
    cls3, strings3 = get_operr_withname_error_class('abc %s ghi %s', 'AttributeError')
    assert cls3 is cls

def test_oefmt(space):
    operr = oefmt("w_type", "abc %s def %d", "foo", 42)
    assert isinstance(operr, OperationError)
    assert operr.w_type == "w_type"
    assert operr._w_value is None
    val = operr._compute_value(space)
    assert val == ("abc foo def 42", 14)
    operr2 = oefmt("w_type2", "a %s b %d c", "bar", 43)
    assert operr2.__class__ is operr.__class__
    operr3 = oefmt("w_type2", "a %s b %s c", "bar", "4b")
    assert operr3.__class__ is not operr.__class__

def test_oefmt_noargs(space):
    operr = oefmt(space.w_AttributeError, "no attribute 'foo'")
    operr.normalize_exception(space)
    val = operr.get_w_value(space)
    assert space.isinstance_w(val, space.w_AttributeError)
    w_repr = space.repr(val)
    assert space.text_w(w_repr) == "AttributeError(\"no attribute 'foo'\")"

def test_oefmt_T(space):
    operr = oefmt(space.w_AttributeError,
                  "'%T' object has no attribute '%s'",
                  space.wrap('foo'), 'foo')
    assert operr._compute_value(space) == ("'str' object has no attribute 'foo'", 35)
    operr = oefmt("w_type",
                  "'%T' object has no attribute '%s'",
                  space.wrap('foo'), 'foo')
    assert operr._compute_value(space) == ("'str' object has no attribute 'foo'", 35)

def test_oefmt_N(space):
    operr = oefmt(space.w_AttributeError,
                  "'%N' object has no attribute '%s'",
                  space.type(space.wrap('foo')), 'foo')
    assert operr._compute_value(space) == ("'str' object has no attribute 'foo'", 35)
    operr = oefmt("w_type",
                  "'%N' object has no attribute '%s'",
                  space.type(space.wrap('foo')), 'foo')
    assert operr._compute_value(space) == ("'str' object has no attribute 'foo'", 35)
    operr = oefmt(space.w_AttributeError,
                  "'%N' object has no attribute '%s'",
                  space.wrap('foo'), 'foo')
    assert operr._compute_value(space) == ("'?' object has no attribute 'foo'", 33)
    operr = oefmt("w_type",
                  "'%N' object has no attribute '%s'",
                  space.wrap('foo'), 'foo')
    assert operr._compute_value(space) == ("'?' object has no attribute 'foo'", 33)

def test_oefmt_R(space):
    operr = oefmt(space.w_ValueError,
                  "illegal newline value: %R", space.wrap('foo'))
    assert operr._compute_value(space) == ("illegal newline value: 'foo'", 28)
    operr = oefmt(space.w_ValueError, "illegal newline value: %R",
                  space.wrap("'PyLadies'"))
    expected = ("illegal newline value: \"'PyLadies'\"", 35)
    assert operr._compute_value(space) == expected

def test_oefmt_unicode(space):
    operr = oefmt("w_type", "abc %s", u"àèìòù")
    val = operr._compute_value(space)
    assert val == (u"abc àèìòù".encode('utf8'), 9)

def test_oefmt_utf8(space):
    arg = u"àèìòù".encode('utf-8')
    operr = oefmt("w_type", "abc %8", arg)
    val = operr._compute_value(space)
    assert val == (u"abc àèìòù".encode('utf8'), 9)
    #
    # if the arg is a byte string and we specify '%s', then we
    # also get utf-8 encoding.  This should be the common case
    # nowadays with utf-8 byte strings being common in the RPython
    # sources of PyPy.
    operr = oefmt("w_type", "abc %s", arg)
    val = operr._compute_value(space)
    assert val == (u"abc àèìòù".encode('utf8'), 9)
    #
    # if the byte string is not valid utf-8, then don't crash
    arg = '\xe9'
    operr = oefmt("w_type", "abc %8", arg)
    val = operr._compute_value(space)


def test_errorstr(space):
    operr = OperationError(space.w_ValueError, space.wrap("message"))
    assert operr.errorstr(space) == "ValueError: message"
    assert operr.errorstr(space, use_repr=True) == (
        "ValueError: ValueError('message')")
    operr = OperationError(space.w_ValueError, space.w_None)
    assert operr.errorstr(space) == "ValueError"
    operr = OperationError(space.w_ValueError,
        space.newtuple([space.wrap(6), space.wrap(7)]))
    assert operr.errorstr(space) == "ValueError: (6, 7)"
    operr = OperationError(space.w_UnicodeDecodeError,
        space.newtuple([
            space.wrap('unicodeescape'),
            space.newbytes(r'\\x'),
            space.newint(0),
            space.newint(2),
            space.wrap(r'truncated \\xXX escape')]))
    assert operr.errorstr(space) == (
        "UnicodeDecodeError: 'unicodeescape' codec can't decode "
        "bytes in position 0-1: truncated \\\\xXX escape")

def test_wrap_oserror():
    class FakeSpace:
        w_OSError = [OSError]
        w_EnvironmentError = [EnvironmentError]
        w_None = None
        def wrap(self, obj, lgt=-1):
            return [obj]
        newint = newtext = newfilename = wrap
        def call_function(self, exc, w_errno, w_msg, w_filename=None, *args):
            return (exc, w_errno, w_msg, w_filename)
    space = FakeSpace()
    #
    e = wrap_oserror(space, OSError(errno.EBADF, "foobar"))
    assert isinstance(e, OperationError)
    assert e.w_type == [OSError]
    assert e.get_w_value(space) == ([OSError], [errno.EBADF],
                                    [os.strerror(errno.EBADF)], None)
    #
    e = wrap_oserror(space, OSError(errno.EBADF, "foobar"),
                     filename="test.py",
                     w_exception_class=space.w_EnvironmentError)
    assert isinstance(e, OperationError)
    assert e.w_type == [EnvironmentError]
    assert e.get_w_value(space) == ([EnvironmentError], [errno.EBADF],
                                    [os.strerror(errno.EBADF)],
                                    ["test.py"])
    #
    e = wrap_oserror(space, OSError(errno.EBADF, "foobar"),
                     filename="test.py",
                     w_exception_class=[SystemError])
    assert isinstance(e, OperationError)
    assert e.w_type == [SystemError]
    assert e.get_w_value(space) == ([SystemError], [errno.EBADF],
                                    [os.strerror(errno.EBADF)],
                                    ["test.py"])

def test_new_exception(space):
    w_error = new_exception_class(space, '_socket.error')
    assert w_error.getname(space) == u'error'
    assert space.text_w(space.repr(w_error)) == "<class '_socket.error'>"
    operr = OperationError(w_error, space.wrap("message"))
    assert operr.match(space, w_error)
    assert operr.match(space, space.w_Exception)

    # subclass of ValueError
    w_error = new_exception_class(space, 'error', space.w_ValueError)
    operr = OperationError(w_error, space.wrap("message"))
    assert operr.match(space, w_error)
    assert operr.match(space, space.w_ValueError)

    # subclass of (ValueError, TypeError)
    w_bases = space.newtuple([space.w_ValueError, space.w_TypeError])
    w_error = new_exception_class(space, 'error', w_bases)
    operr = OperationError(w_error, space.wrap("message"))
    assert operr.match(space, w_error)
    assert operr.match(space, space.w_ValueError)
    assert operr.match(space, space.w_TypeError)

def test_import_error(space):
    w_exc = new_import_error(
        space, space.wrap(u'msg'), space.wrap(u'name'), space.wrap(u'path'))
    assert space.getattr(w_exc, space.wrap(u'name')).unwrap(space) == u'name'
    assert space.getattr(w_exc, space.wrap(u'path')).unwrap(space) == u'path'
