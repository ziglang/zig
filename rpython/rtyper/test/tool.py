import py
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.test.test_llinterp import gengraph, interpret, interpret_raises

class BaseRtypingTest(object):
    FLOAT_PRECISION = 8

    @staticmethod
    def gengraph(func, argtypes=[], viewbefore='auto', policy=None,
             backendopt=False, config=None):
        return gengraph(func, argtypes, viewbefore, policy,
                        backendopt=backendopt, config=config)

    @staticmethod
    def interpret(fn, args, **kwds):
        return interpret(fn, args, **kwds)

    @staticmethod
    def interpret_raises(exc, fn, args, **kwds):
        return interpret_raises(exc, fn, args, **kwds)

    @staticmethod
    def float_eq(x, y):
        return x == y

    @classmethod
    def float_eq_approx(cls, x, y):
        maxError = 10**-cls.FLOAT_PRECISION
        if abs(x-y) < maxError:
            return True

        if abs(y) > abs(x):
            relativeError = abs((x - y) / y)
        else:
            relativeError = abs((x - y) / x)

        return relativeError < maxError

    @staticmethod
    def is_of_type(x, type_):
        return type(x) is type_

    @staticmethod
    def _skip_llinterpreter(reason):
        py.test.skip("lltypesystem doesn't support %s, yet" % reason)

    @staticmethod
    def ll_to_string(s):
        if not s:
            return None
        return ''.join(s.chars)

    @staticmethod
    def ll_to_unicode(s):
        return u''.join(s.chars)

    @staticmethod
    def string_to_ll(s):
        from rpython.rtyper.lltypesystem.rstr import STR, mallocstr
        if s is None:
            return lltype.nullptr(STR)
        p = mallocstr(len(s))
        for i in range(len(s)):
            p.chars[i] = s[i]
        return p

    @staticmethod
    def unicode_to_ll(s):
        from rpython.rtyper.lltypesystem.rstr import UNICODE, mallocunicode
        if s is None:
            return lltype.nullptr(UNICODE)
        p = mallocunicode(len(s))
        for i in range(len(s)):
            p.chars[i] = s[i]
        return p

    @staticmethod
    def ll_to_list(l):
        r = []
        items = l.ll_items()
        for i in range(l.ll_length()):
            r.append(items[i])
        return r

    @staticmethod
    def ll_unpack_tuple(t, length):
        return tuple([getattr(t, 'item%d' % i) for i in range(length)])

    @staticmethod
    def get_callable(fnptr):
        return fnptr._obj._callable

    @staticmethod
    def class_name(value):
        return ''.join(value.super.typeptr.name.chars)

    @staticmethod
    def read_attr(value, attr_name):
        value = value._obj
        while value is not None:
            attr = getattr(value, "inst_" + attr_name, None)
            if attr is None:
                value = value._parentstructure()
            else:
                return attr
        raise AttributeError()

    @staticmethod
    def is_of_instance_type(val):
        T = lltype.typeOf(val)
        return isinstance(T, lltype.Ptr) and isinstance(T.TO, lltype.GcStruct)
