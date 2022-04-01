import sys
from contextlib import contextmanager
import signal
from collections import OrderedDict

from rpython.translator.translator import TranslationContext
from rpython.annotator.model import (
    SomeInteger, SomeString, SomeChar, SomeUnicodeString, SomeUnicodeCodePoint)
from rpython.annotator.dictdef import DictKey, DictValue
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem import rdict
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rlib.objectmodel import r_dict
from rpython.rlib.rarithmetic import r_int, r_uint, r_longlong, r_ulonglong

import py
from hypothesis import settings
from hypothesis.strategies import (
    builds, sampled_from, binary, just, integers, text, characters, tuples)
from hypothesis.stateful import GenericStateMachine, run_state_machine_as_test

def ann2strategy(s_value):
    if isinstance(s_value, SomeChar):
        return builds(chr, integers(min_value=0, max_value=255))
    elif isinstance(s_value, SomeString):
        if s_value.can_be_None:
            return binary() | just(None)
        else:
            return binary()
    elif isinstance(s_value, SomeUnicodeCodePoint):
        return characters()
    elif isinstance(s_value, SomeUnicodeString):
        if s_value.can_be_None:
            return text() | just(None)
        else:
            return text()
    elif isinstance(s_value, SomeInteger):
        return integers(min_value=~sys.maxint, max_value=sys.maxint)
    else:
        raise TypeError("Cannot convert annotation %s to a strategy" % s_value)


if hasattr(signal, 'alarm'):
    @contextmanager
    def signal_timeout(n):
        """A flaky context manager that throws an exception if the body of the
        `with` block runs for longer than `n` seconds.
        """
        def handler(signum, frame):
            raise RuntimeError('timeout')
        signal.signal(signal.SIGALRM, handler)
        signal.alarm(n)
        try:
            yield
        finally:
            signal.alarm(0)
else:
    @contextmanager
    def signal_timeout(n):
        yield


class BaseTestRDict(BaseRtypingTest):
    def test_dict_creation(self):
        def createdict(i):
            d = self.newdict()
            d['hello'] = i
            return d['hello']

        res = self.interpret(createdict, [42])
        assert res == 42

    def test_dict_getitem_setitem(self):
        def func(i):
            d = self.newdict()
            d['hello'] = i
            d['world'] = i + 1
            return d['hello'] * d['world']
        res = self.interpret(func, [6])
        assert res == 42

    def test_dict_getitem_keyerror(self):
        def func(i):
            d = self.newdict()
            d['hello'] = i
            try:
                return d['world']
            except KeyError:
                return 0
        res = self.interpret(func, [6])
        assert res == 0

    def test_dict_del_simple(self):
        def func(i):
            d = self.newdict()
            d['hello'] = i
            d['world'] = i + 1
            del d['hello']
            return len(d)
        res = self.interpret(func, [6])
        assert res == 1

    def test_dict_clear(self):
        def func(i):
            d = self.newdict()
            d['abc'] = i
            d['def'] = i+1
            d.clear()
            d['ghi'] = i+2
            return ('abc' not in d and 'def' not in d
                    and d['ghi'] == i+2 and len(d) == 1)
        res = self.interpret(func, [7])
        assert res == True

    def test_empty_strings(self):
        def func(i):
            d = self.newdict()
            d[''] = i
            del d['']
            try:
                d['']
                return 0
            except KeyError:
                pass
            return 1
        res = self.interpret(func, [6])
        assert res == 1

        def func(i):
            d = self.newdict()
            d[''] = i
            del d['']
            d[''] = i + 1
            return len(d)
        res = self.interpret(func, [6])
        assert res == 1

    def test_dict_bool(self):
        def func(i):
            if i:
                d = self.newdict()
            else:
                d = self.newdict()
                d[i] = i+1
            if d:
                return i
            else:
                return i+1
        assert self.interpret(func, [42]) == 43
        assert self.interpret(func, [0]) == 0

    def test_contains(self):
        def func(x, y):
            d = self.newdict()
            d[x] = x+1
            return y in d
        assert self.interpret(func, [42, 0]) == False
        assert self.interpret(func, [42, 42]) == True

    def test_contains_2(self):
        d = self.newdict()
        d['5'] = None
        d['7'] = None
        def func(x):
            return chr(x) in d
        assert self.interpret(func, [ord('5')]) == True
        assert self.interpret(func, [ord('6')]) == False

        def func(n):
            return str(n) in d
        assert self.interpret(func, [512]) == False

    def test_dict_iteration(self):
        def func(i, j):
            d = self.newdict()
            d['hello'] = i
            d['world'] = j
            k = 1
            for key in d:
                k = k * d[key]
            return k
        res = self.interpret(func, [6, 7])
        assert res == 42

    def test_dict_itermethods(self):
        def func():
            d = self.newdict()
            d['hello'] = 6
            d['world'] = 7
            k1 = k2 = k3 = 1
            for key in d.iterkeys():
                k1 = k1 * d[key]
            for value in d.itervalues():
                k2 = k2 * value
            for key, value in d.iteritems():
                assert d[key] == value
                k3 = k3 * value
            return k1 + k2 + k3
        res = self.interpret(func, [])
        assert res == 42 + 42 + 42

    def test_dict_get(self):
        def func():
            dic = self.newdict()
            x1 = dic.get('hi', 42)
            dic['blah'] = 1 # XXX this triggers type determination
            x2 = dic.get('blah', 2)
            return x1 * 10 + x2
        res = self.interpret(func, ())
        assert res == 421

    def test_dict_get_no_second_arg(self):
        def func():
            dic = self.newdict()
            x1 = dic.get('hi', 'a')
            x2 = dic.get('blah')
            return (x1 == 'a') * 10 + (x2 is None)
            return x1 * 10 + x2
        res = self.interpret(func, ())
        assert res == 11

    def test_dict_get_empty(self):
        def func():
            # this time without writing to the dict
            dic = self.newdict()
            x1 = dic.get('hi', 42)
            x2 = dic.get('blah', 2)
            return x1 * 10 + x2
        res = self.interpret(func, ())
        assert res == 422

    def test_dict_setdefault(self):
        def f():
            d = self.newdict()
            d.setdefault('a', 2)
            return d['a']
        res = self.interpret(f, ())
        assert res == 2

        def f():
            d = self.newdict()
            d.setdefault('a', 2)
            x = d.setdefault('a', -3)
            return x
        res = self.interpret(f, ())
        assert res == 2

    def test_dict_copy(self):
        def func():
            dic = self.newdict()
            dic['a'] = 1
            dic['b'] = 2
            d2 = dic.copy()
            ok = 1
            for key in d2:
                if dic[key] != d2[key]:
                    ok = 0
            ok &= len(dic) == len(d2)
            d2['c'] = 3
            ok &= len(dic) == len(d2) - 1
            return ok
        res = self.interpret(func, ())
        assert res == 1

    def test_dict_update(self):
        def func():
            dic = self.newdict()
            dic['ab'] = 1000
            dic['b'] = 200
            d2 = self.newdict()
            d2['b'] = 30
            d2['cb'] = 4
            dic.update(d2)
            ok = len(dic) == 3
            sum = ok
            for key in dic:
                sum += dic[key]
            return sum
        res = self.interpret(func, ())
        assert res == 1035

    def test_dict_keys(self):
        def func():
            dic = self.newdict()
            dic[' 4'] = 1000
            dic[' 8'] = 200
            keys = dic.keys()
            return ord(keys[0][1]) + ord(keys[1][1]) - 2*ord('0') + len(keys)
        res = self.interpret(func, ())#, view=True)
        assert res == 14

    def test_list_dict(self):
        def func():
            dic = self.newdict()
            dic[' 4'] = 1000
            dic[' 8'] = 200
            keys = list(dic)
            return ord(keys[0][1]) + ord(keys[1][1]) - 2*ord('0') + len(keys)
        res = self.interpret(func, ())#, view=True)
        assert res == 14

    def test_dict_inst_keys(self):
        class Empty:
            pass
        class A(Empty):
            pass
        def func():
            dic0 = self.newdict()
            dic0[Empty()] = 2
            dic = self.newdict()
            dic[A()] = 1
            dic[A()] = 2
            keys = dic.keys()
            return (isinstance(keys[1], A))*2+(isinstance(keys[0],A))
        res = self.interpret(func, [])
        assert res == 3

    def test_dict_inst_iterkeys(self):
        class Empty:
            pass
        class A(Empty):
            pass
        def func():
            dic0 = self.newdict()
            dic0[Empty()] = 2
            dic = self.newdict()
            dic[A()] = 1
            dic[A()] = 2
            a = 0
            for k in dic.iterkeys():
                a += isinstance(k, A)
            return a
        res = self.interpret(func, [])
        assert res == 2

    def test_dict_values(self):
        def func():
            dic = self.newdict()
            dic[' 4'] = 1000
            dic[' 8'] = 200
            values = dic.values()
            return values[0] + values[1] + len(values)
        res = self.interpret(func, ())
        assert res == 1202

    def test_dict_inst_values(self):
        class A:
            pass
        def func():
            dic = self.newdict()
            dic[1] = A()
            dic[2] = A()
            vals = dic.values()
            return (isinstance(vals[1], A))*2+(isinstance(vals[0],A))
        res = self.interpret(func, [])
        assert res == 3

    def test_dict_inst_itervalues(self):
        class A:
            pass
        def func():
            dic = self.newdict()
            dic[1] = A()
            dic[2] = A()
            a = 0
            for v in dic.itervalues():
                a += isinstance(v, A)
            return a
        res = self.interpret(func, [])
        assert res == 2

    def test_dict_inst_items(self):
        class Empty:
            pass
        class A:
            pass
        class B(Empty):
            pass
        def func():
            dic0 = self.newdict()
            dic0[Empty()] = A()
            dic = self.newdict()
            dic[B()] = A()
            dic[B()] = A()
            items = dic.items()
            b = 0
            a = 0
            for k, v in items:
                b += isinstance(k, B)
                a += isinstance(v, A)
            return 3*b+a
        res = self.interpret(func, [])
        assert res == 8

    def test_dict_inst_iteritems(self):
        class Empty:
            pass
        class A:
            pass
        class B(Empty):
            pass
        def func():
            dic0 = self.newdict()
            dic0[Empty()] = A()
            dic = self.newdict()
            dic[B()] = A()
            dic[B()] = A()
            b = 0
            a = 0
            for k, v in dic.iteritems():
                b += isinstance(k, B)
                a += isinstance(v, A)
            return 3*b+a
        res = self.interpret(func, [])
        assert res == 8

    def test_dict_items(self):
        def func():
            dic = self.newdict()
            dic[' 4'] = 1000
            dic[' 8'] = 200
            items = dic.items()
            res = len(items)
            for key, value in items:
                res += ord(key[1]) - ord('0') + value
            return res
        res = self.interpret(func, ())
        assert res == 1214

    def test_dict_contains(self):
        def func():
            dic = self.newdict()
            dic[' 4'] = 1000
            dic[' 8'] = 200
            return ' 4' in dic and ' 9' not in dic
        res = self.interpret(func, ())
        assert res is True

    def test_dict_contains_with_constant_dict(self):
        dic = self.newdict()
        dic['4'] = 1000
        dic['8'] = 200
        def func(i):
            return chr(i) in dic
        res = self.interpret(func, [ord('4')])
        assert res is True
        res = self.interpret(func, [1])
        assert res is False

    def test_dict_or_none(self):
        class A:
            pass
        def negate(d):
            return not d
        def func(n):
            a = A()
            a.d = None
            if n > 0:
                a.d = self.newdict()
                a.d[str(n)] = 1
                a.d["42"] = 2
                del a.d["42"]
            return negate(a.d)
        res = self.interpret(func, [10])
        assert res is False
        res = self.interpret(func, [0])
        assert res is True
        res = self.interpret(func, [42])
        assert res is True

    def test_int_dict(self):
        def func(a, b):
            dic = self.newdict()
            dic[12] = 34
            dic[a] = 1000
            return dic.get(b, -123)
        res = self.interpret(func, [12, 12])
        assert res == 1000
        res = self.interpret(func, [12, 13])
        assert res == -123
        res = self.interpret(func, [524, 12])
        assert res == 34
        res = self.interpret(func, [524, 524])
        assert res == 1000
        res = self.interpret(func, [524, 1036])
        assert res == -123



    def test_id_instances_keys(self):
        class A:
            pass
        class B(A):
            pass
        def f():
            a = A()
            b = B()
            d = self.newdict()
            d[b] = 7
            d[a] = 3
            return len(d) + d[a] + d[b]
        res = self.interpret(f, [])
        assert res == 12

    def test_captured_get(self):
        d = self.newdict()
        d[1] = 2
        get = d.get
        def f():
            return get(1, 3)+get(2, 4)
        res = self.interpret(f, [])
        assert res == 6

        def g(h):
            return h(1, 3)
        def f():
            return g(get)

        res = self.interpret(f, [])
        assert res == 2

    def test_specific_obscure_bug(self):
        class A: pass
        class B: pass   # unrelated kinds of instances
        def f():
            lst = [A()]
            res1 = A() in lst
            d2 = self.newdict()
            d2[B()] = None
            d2[B()] = None
            return res1+len(d2)
        res = self.interpret(f, [])
        assert res == 2

    def test_identity_hash_is_fast(self):
        class A(object):
            pass

        def f():
            d = self.newdict()
            d[A()] = 1
            return d

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        r_dict = rtyper.getrepr(s)
        assert not hasattr(r_dict.lowleveltype.TO.entries.TO.OF, "f_hash")

    def test_r_dict_can_be_fast(self):
        def myeq(n, m):
            return n == m
        def myhash(n):
            return ~n
        def f():
            d = self.new_r_dict(myeq, myhash, simple_hash_eq=True)
            d[5] = 7
            d[12] = 19
            return d

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        r_dict = rtyper.getrepr(s)
        assert not hasattr(r_dict.lowleveltype.TO.entries.TO.OF, "f_hash")

    def test_tuple_dict(self):
        def f(i):
            d = self.newdict()
            d[(1, 4.5, (str(i), 2), 2)] = 4
            d[(1, 4.5, (str(i), 2), 3)] = 6
            return d[(1, 4.5, (str(i), 2), i)]

        res = self.interpret(f, [2])
        assert res == f(2)

    def test_dict_of_dict(self):
        def f(n):
            d = self.newdict()
            d[5] = d
            d[6] = self.newdict()
            return len(d[n])

        res = self.interpret(f, [5])
        assert res == 2
        res = self.interpret(f, [6])
        assert res == 0

    def test_cls_dict(self):
        class A(object):
            pass

        class B(A):
            pass

        def f(i):
            d = self.newdict()
            d[A] = 3
            d[B] = 4
            if i:
                cls = A
            else:
                cls = B
            return d[cls]

        res = self.interpret(f, [1])
        assert res == 3
        res = self.interpret(f, [0])
        assert res == 4

    def test_prebuilt_cls_dict(self):
        class A(object):
            pass

        class B(A):
            pass

        d = self.newdict()
        d[(A, 3)] = 3
        d[(B, 0)] = 4

        def f(i):
            if i:
                cls = A
            else:
                cls = B
            try:
                return d[cls, i]
            except KeyError:
                return -99

        res = self.interpret(f, [0])
        assert res == 4
        res = self.interpret(f, [3])
        assert res == 3
        res = self.interpret(f, [10])
        assert res == -99

    def test_access_in_try(self):
        def f(d):
            try:
                return d[2]
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            d = self.newdict()
            d[1] = n
            d[2] = 2*n
            return f(d)
        res = self.interpret(g, [3])
        assert res == 6

    def test_access_in_try_set(self):
        def f(d):
            try:
                d[2] = 77
            except ZeroDivisionError:
                return 42
            return -1
        def g(n):
            d = self.newdict()
            d[1] = n
            f(d)
            return d[2]
        res = self.interpret(g, [3])
        assert res == 77

    def test_resize_during_iteration(self):
        def func():
            d = self.newdict()
            d[5] = 1
            d[6] = 2
            d[7] = 3
            try:
                for key, value in d.iteritems():
                    d[key^16] = value*2
            except RuntimeError:
                pass
            total = 0
            for key in d:
                total += key
            return total
        res = self.interpret(func, [])
        assert 5 + 6 + 7 <= res <= 5 + 6 + 7 + (5^16) + (6^16) + (7^16)

    def test_change_during_iteration(self):
        def func():
            d = self.newdict()
            d['a'] = 1
            d['b'] = 2
            for key in d:
                d[key] = 42
            return d['a']
        assert self.interpret(func, []) == 42

    def test_dict_of_floats(self):
        d = self.newdict()
        d[3.0] = 42
        d[3.1] = 43
        d[3.2] = 44
        d[3.3] = 45
        d[3.4] = 46
        def fn(f):
            return d[f]

        res = self.interpret(fn, [3.0])
        assert res == 42

    def test_dict_of_r_uint(self):
        for r_t in [r_uint, r_longlong, r_ulonglong]:
            if r_t is r_int:
                continue    # for 64-bit platforms: skip r_longlong
            d = self.newdict()
            d[r_t(2)] = 3
            d[r_t(4)] = 5
            def fn(x, y):
                d[r_t(x)] = 123
                return d[r_t(y)]
            res = self.interpret(fn, [4, 2])
            assert res == 3
            res = self.interpret(fn, [3, 3])
            assert res == 123

    def test_dict_popitem(self):
        def func():
            d = self.newdict()
            d[5] = 2
            d[6] = 3
            k1, v1 = d.popitem()
            assert len(d) == 1
            k2, v2 = d.popitem()
            try:
                d.popitem()
            except KeyError:
                pass
            else:
                assert 0, "should have raised KeyError"
            assert len(d) == 0
            return k1*1000 + v1*100 + k2*10 + v2

        res = self.interpret(func, [])
        assert res in [5263, 6352]

    def test_dict_pop(self):
        def f(n, default):
            d = self.newdict()
            d[2] = 3
            d[4] = 5
            if default == -1:
                try:
                    x = d.pop(n)
                except KeyError:
                    x = -1
            else:
                x = d.pop(n, default)
            return x * 10 + len(d)
        res = self.interpret(f, [2, -1])
        assert res == 31
        res = self.interpret(f, [3, -1])
        assert res == -8
        res = self.interpret(f, [2, 5])
        assert res == 31

    def test_dict_pop_instance(self):
        class A(object):
            pass
        def f(n):
            d = self.newdict()
            d[2] = A()
            x = d.pop(n, None)
            if x is None:
                return 12
            else:
                return 15
        res = self.interpret(f, [2])
        assert res == 15
        res = self.interpret(f, [700])
        assert res == 12

    def test_dict_but_not_with_char_keys(self):
        def func(i):
            d = self.newdict()
            d['h'] = i
            try:
                return d['hello']
            except KeyError:
                return 0
        res = self.interpret(func, [6])
        assert res == 0

    def test_dict_valid_resize(self):
        # see if we find our keys after resize
        def func():
            d = self.newdict()
            # fill it up
            for i in range(10):
                d[str(i)] = 0
            # delete again
            for i in range(10):
                del d[str(i)]
            res = 0
        # if it does not crash, we are fine. It crashes if you forget the hash field.
        self.interpret(func, [])

    # ____________________________________________________________

    def test_dict_of_addresses(self):
        from rpython.rtyper.lltypesystem import llmemory
        TP = lltype.Struct('x')
        a = lltype.malloc(TP, flavor='raw', immortal=True)
        b = lltype.malloc(TP, flavor='raw', immortal=True)

        def func(i):
            d = self.newdict()
            d[llmemory.cast_ptr_to_adr(a)] = 123
            d[llmemory.cast_ptr_to_adr(b)] = 456
            if i > 5:
                key = llmemory.cast_ptr_to_adr(a)
            else:
                key = llmemory.cast_ptr_to_adr(b)
            return d[key]

        assert self.interpret(func, [3]) == 456

    def test_prebuilt_list_of_addresses(self):
        from rpython.rtyper.lltypesystem import llmemory

        TP = lltype.Struct('x', ('y', lltype.Signed))
        a = lltype.malloc(TP, flavor='raw', immortal=True)
        b = lltype.malloc(TP, flavor='raw', immortal=True)
        c = lltype.malloc(TP, flavor='raw', immortal=True)
        a_a = llmemory.cast_ptr_to_adr(a)
        a0 = llmemory.cast_ptr_to_adr(a)
        assert a_a is not a0
        assert a_a == a0
        a_b = llmemory.cast_ptr_to_adr(b)
        a_c = llmemory.cast_ptr_to_adr(c)

        d = self.newdict()
        d[a_a] = 3
        d[a_b] = 4
        d[a_c] = 5
        d[a0] = 8

        def func(i):
            if i == 0:
                ptr = a
            else:
                ptr = b
            return d[llmemory.cast_ptr_to_adr(ptr)]

        py.test.raises(TypeError, self.interpret, func, [0])

    def test_dict_of_voidp(self):
        def func():
            d = self.newdict()
            handle = lltype.nullptr(rffi.VOIDP.TO)
            # Use a negative key, so the dict implementation uses
            # the value as a marker for empty entries
            d[-1] = handle
            return len(d)

        assert self.interpret(func, []) == 1
        from rpython.translator.c.test.test_genc import compile
        f = compile(func, [])
        res = f()
        assert res == 1

    def test_dict_with_SHORT_keys(self):
        def func(x):
            d = self.newdict()
            d[rffi.cast(rffi.SHORT, 42)] = 123
            d[rffi.cast(rffi.SHORT, -43)] = 321
            return d[rffi.cast(rffi.SHORT, x)]

        assert self.interpret(func, [42]) == 123
        assert self.interpret(func, [2**16 - 43]) == 321

    def test_dict_with_bool_keys(self):
        def func(x):
            d = self.newdict()
            d[False] = 123
            d[True] = 321
            return d[x == 42]

        assert self.interpret(func, [5]) == 123
        assert self.interpret(func, [42]) == 321

    def test_memoryerror_should_not_insert(self):
        # This shows a misbehaviour that also exists in CPython 2.7, but not
        # any more in CPython 3.3.  The behaviour is that even if a dict
        # insertion raises MemoryError, the new item is still inserted.
        # If we catch the MemoryError, we can keep inserting new items until
        # the dict table is completely full.  Then the next insertion loops
        # forever.  This test only checks that after a MemoryError the
        # new item was not inserted.
        def _check_small_range(self, n):
            if n >= 128:
                raise MemoryError
            return range(n)
        original_check_range = lltype._array._check_range
        try:
            lltype._array._check_range = _check_small_range
            #
            def do_insert(d, i):
                d[i] = i
            def func():
                d = self.newdict()
                i = 0
                while True:
                    try:
                        do_insert(d, i)
                    except MemoryError:
                        return (i in d)
                    i += 1
            res = self.interpret(func, [])
            assert res == 0
            #
        finally:
            lltype._array._check_range = original_check_range

    def test_dict_with_none_key(self):
        def func(i):
            d = self.newdict()
            d[None] = i
            return d[None]
        res = self.interpret(func, [42])
        assert res == 42

    def test_externalvsinternal(self):
        class A: pass
        class B: pass
        class C: pass
        class D: pass
        def func():
            d1 = self.newdict();  d1[A()] = B()
            d2 = self.newdict2(); d2[C()] = D()
            return (d1, d2)
        res = self.interpret(func, [])
        assert lltype.typeOf(res.item0) == lltype.typeOf(res.item1)

    def test_r_dict(self):
        class FooError(Exception):
            pass
        def myeq(n, m):
            return n == m
        def myhash(n):
            if n < 0:
                raise FooError
            return -n
        def f(n):
            d = self.new_r_dict(myeq, myhash)
            for i in range(10):
                d[i] = i*i
            try:
                value1 = d[n]
            except FooError:
                value1 = 99
            try:
                value2 = n in d
            except FooError:
                value2 = 99
            try:
                value3 = d[-n]
            except FooError:
                value3 = 99
            try:
                value4 = (-n) in d
            except FooError:
                value4 = 99
            return (value1 * 1000000 +
                    value2 * 10000 +
                    value3 * 100 +
                    value4)
        res = self.interpret(f, [5])
        assert res == 25019999

    def test_r_dict_popitem_hash(self):
        def deq(n, m):
            return n == m
        def dhash(n):
            return ~n
        def func():
            d = self.new_r_dict(deq, dhash)
            d[5] = 2
            d[6] = 3
            k1, v1 = d.popitem()
            assert len(d) == 1
            k2, v2 = d.popitem()
            try:
                d.popitem()
            except KeyError:
                pass
            else:
                assert 0, "should have raised KeyError"
            assert len(d) == 0
            return k1*1000 + v1*100 + k2*10 + v2

        res = self.interpret(func, [])
        assert res in [5263, 6352]

    def test_prebuilt_r_dict(self):
        def deq(n, m):
            return (n & 3) == (m & 3)
        def dhash(n):
            return n & 3
        d = self.new_r_dict(deq, dhash)
        d[0x123] = "abcd"
        d[0x231] = "efgh"
        def func():
            return d[0x348973] + d[0x12981]

        res = self.interpret(func, [])
        res = self.ll_to_string(res)
        assert res == "abcdefgh"


class TestRDict(BaseTestRDict):
    @staticmethod
    def newdict():
        return {}

    @staticmethod
    def newdict2():
        return {}

    @staticmethod
    def new_r_dict(myeq, myhash, force_non_null=False, simple_hash_eq=False):
        return r_dict(myeq, myhash, force_non_null=force_non_null, simple_hash_eq=simple_hash_eq)

    def test_two_dicts_with_different_value_types(self):
        def func(i):
            d1 = {}
            d1['hello'] = i + 1
            d2 = {}
            d2['world'] = d1
            return d2['world']['hello']
        res = self.interpret(func, [5])
        assert res == 6

    def test_type_erase(self):
        class A(object):
            pass
        class B(object):
            pass

        def f():
            d = {}
            d[A()] = B()
            d2 = {}
            d2[B()] = A()
            return d, d2

        t = TranslationContext()
        s = t.buildannotator().build_types(f, [])
        rtyper = t.buildrtyper()
        rtyper.specialize()

        s_AB_dic = s.items[0]
        s_BA_dic = s.items[1]

        r_AB_dic = rtyper.getrepr(s_AB_dic)
        r_BA_dic = rtyper.getrepr(s_BA_dic)

        assert r_AB_dic.lowleveltype == r_BA_dic.lowleveltype


    def test_opt_dummykeymarker(self):
        def f():
            d = {"hello": None}
            d["world"] = None
            return "hello" in d, d
        res = self.interpret(f, [])
        assert res.item0 == True
        DICT = lltype.typeOf(res.item1).TO
        assert not hasattr(DICT.entries.TO.OF, 'f_valid')   # strs have a dummy

    def test_opt_dummyvaluemarker(self):
        def f(n):
            d = {-5: "abcd"}
            d[123] = "def"
            return len(d[n]), d
        res = self.interpret(f, [-5])
        assert res.item0 == 4
        DICT = lltype.typeOf(res.item1).TO
        assert not hasattr(DICT.entries.TO.OF, 'f_valid')   # strs have a dummy

    def test_opt_nonnegint_dummy(self):
        def f(n):
            d = {n: 12}
            d[-87] = 24
            del d[n]
            return len(d.copy()), d[-87], d
        res = self.interpret(f, [5])
        assert res.item0 == 1
        assert res.item1 == 24
        DICT = lltype.typeOf(res.item2).TO
        assert not hasattr(DICT.entries.TO.OF, 'f_valid')# nonneg int: dummy -1

    def test_opt_no_dummy(self):
        def f(n):
            d = {n: 12}
            d[-87] = -24
            del d[n]
            return len(d.copy()), d[-87], d
        res = self.interpret(f, [5])
        assert res.item0 == 1
        assert res.item1 == -24
        DICT = lltype.typeOf(res.item2).TO
        assert hasattr(DICT.entries.TO.OF, 'f_valid')    # no dummy available

    def test_opt_boolean_has_no_dummy(self):
        def f(n):
            d = {n: True}
            d[-87] = True
            del d[n]
            return len(d.copy()), d[-87], d
        res = self.interpret(f, [5])
        assert res.item0 == 1
        assert res.item1 is True
        DICT = lltype.typeOf(res.item2).TO
        assert hasattr(DICT.entries.TO.OF, 'f_valid')    # no dummy available

    def test_opt_multiple_identical_dicts(self):
        def f(n):
            s = "x" * n
            d1 = {s: 12}
            d2 = {s: 24}
            d3 = {s: 36}
            d1["a"] = d2[s]   # 24
            d3[s] += d1["a"]  # 60
            d2["bc"] = d3[s]  # 60
            return d2["bc"], d1, d2, d3
        res = self.interpret(f, [5])
        assert res.item0 == 60
        # all three dicts should use the same low-level type
        assert lltype.typeOf(res.item1) == lltype.typeOf(res.item2)
        assert lltype.typeOf(res.item1) == lltype.typeOf(res.item3)

    def test_nonnull_hint(self):
        def eq(a, b):
            return a == b
        def rhash(a):
            return 3

        def func(i):
            d = r_dict(eq, rhash, force_non_null=True)
            if not i:
                d[None] = i
            else:
                d[str(i)] = i
            return "12" in d, d

        llres = self.interpret(func, [12])
        assert llres.item0 == 1
        DICT = lltype.typeOf(llres.item1)
        assert sorted(DICT.TO.entries.TO.OF._flds) == ['f_hash', 'key', 'value']


class Action(object):
    def __init__(self, method, args):
        self.method = method
        self.args = args

    def execute(self, space):
        getattr(space, self.method)(*self.args)

    def __repr__(self):
        return "space.%s(%s)" % (self.method, ', '.join(map(repr, self.args)))

class PseudoRTyper:
    cache_dummy_values = {}

# XXX: None keys crash the test, but translation sort-of allows it
keytypes_s = [
    SomeString(), SomeInteger(), SomeChar(),
    SomeUnicodeString(), SomeUnicodeCodePoint()]
st_keys = sampled_from(keytypes_s)
st_values = sampled_from(keytypes_s + [SomeString(can_be_None=True)])

class MappingSpace(object):
    def __init__(self, s_key, s_value):
        from rpython.rtyper.rtuple import TupleRepr

        self.s_key = s_key
        self.s_value = s_value
        rtyper = PseudoRTyper()
        r_key = s_key.rtyper_makerepr(rtyper)
        r_value = s_value.rtyper_makerepr(rtyper)
        dictrepr = self.MappingRepr(rtyper, r_key, r_value,
                        DictKey(None, s_key),
                        DictValue(None, s_value))
        dictrepr.setup()
        self.l_dict = self.newdict(dictrepr)
        self.reference = OrderedDict()
        self.ll_key = r_key.convert_const
        self.ll_value = r_value.convert_const
        self.removed_keys = []
        r_tuple = TupleRepr(rtyper, [r_key, r_value])
        self.TUPLE = r_tuple.lowleveltype

    def setitem(self, key, value):
        ll_key = self.ll_key(key)
        ll_value = self.ll_value(value)
        self.ll_setitem(self.l_dict, ll_key, ll_value)
        self.reference[key] = value
        assert self.ll_contains(self.l_dict, ll_key)

    def delitem(self, key):
        ll_key = self.ll_key(key)
        self.ll_delitem(self.l_dict, ll_key)
        del self.reference[key]
        assert not self.ll_contains(self.l_dict, ll_key)
        self.removed_keys.append(key)

    def move_to_end(self, key, last=True):
        "For test_rordereddict"

    def move_to_first(self, key):
        self.move_to_end(key, last=False)

    def copydict(self):
        self.l_dict = self.ll_copy(self.l_dict)
        assert self.ll_len(self.l_dict) == len(self.reference)

    def cleardict(self):
        self.ll_clear(self.l_dict)
        for key in self.reference:
            self.removed_keys.append(key)
        self.reference.clear()
        assert self.ll_len(self.l_dict) == 0

    def popitem(self):
        try:
            ll_tuple = self.ll_popitem(self.TUPLE, self.l_dict)
        except KeyError:
            assert len(self.reference) == 0
        else:
            ll_key = ll_tuple.item0
            ll_value = ll_tuple.item1
            for key, value in self.reference.iteritems():
                if self.ll_key(key) == ll_key:
                    assert self.ll_value(value) == ll_value
                    del self.reference[key]
                    self.removed_keys.append(key)
                    break
            else:
                raise AssertionError("popitem() returned unexpected key")

    def removeindex(self):
        pass     # overridden in test_rordereddict

    def fullcheck(self):
        assert self.ll_len(self.l_dict) == len(self.reference)
        for key, value in self.reference.iteritems():
            assert (self.ll_getitem(self.l_dict, self.ll_key(key)) ==
                self.ll_value(value))
        for key in self.removed_keys:
            if key not in self.reference:
                try:
                    self.ll_getitem(self.l_dict, self.ll_key(key))
                except KeyError:
                    pass
                else:
                    raise AssertionError("removed key still shows up")

class MappingSM(GenericStateMachine):
    def __init__(self):
        self.space = None

    def st_setitem(self):
        return builds(Action,
            just('setitem'), tuples(self.st_keys, self.st_values))

    def st_updateitem(self):
        return builds(Action,
            just('setitem'),
            tuples(sampled_from(self.space.reference), self.st_values))

    def st_delitem(self):
        return builds(Action,
            just('delitem'), tuples(sampled_from(self.space.reference)))

    def st_move_to_end(self):
        return builds(Action,
            just('move_to_end'), tuples(sampled_from(self.space.reference)))

    def st_move_to_first(self):
        return builds(Action,
            just('move_to_first'),
                tuples(sampled_from(self.space.reference)))

    def steps(self):
        if not self.space:
            return builds(Action, just('setup'), tuples(st_keys, st_values))
        global_actions = [Action('copydict', ()), Action('cleardict', ()),
                          Action('popitem', ()), Action('removeindex', ())]
        if self.space.reference:
            return (
                self.st_setitem() | sampled_from(global_actions) |
                self.st_updateitem() | self.st_delitem() |
                self.st_move_to_end() | self.st_move_to_first())
        else:
            return (self.st_setitem() | sampled_from(global_actions))

    def execute_step(self, action):
        if action.method == 'setup':
            self.space = self.Space(*action.args)
            self.st_keys = ann2strategy(self.space.s_key)
            self.st_values = ann2strategy(self.space.s_value)
            return
        with signal_timeout(10):  # catches infinite loops
            action.execute(self.space)

    def teardown(self):
        if self.space:
            self.space.fullcheck()


class DictSpace(MappingSpace):
    MappingRepr = rdict.DictRepr
    ll_getitem = staticmethod(rdict.ll_dict_getitem)
    ll_setitem = staticmethod(rdict.ll_dict_setitem)
    ll_delitem = staticmethod(rdict.ll_dict_delitem)
    ll_len = staticmethod(rdict.ll_dict_len)
    ll_contains = staticmethod(rdict.ll_contains)
    ll_copy = staticmethod(rdict.ll_copy)
    ll_clear = staticmethod(rdict.ll_clear)
    ll_popitem = staticmethod(rdict.ll_popitem)

    def newdict(self, repr):
        return rdict.ll_newdict(repr.DICT)

class DictSM(MappingSM):
    Space = DictSpace

def test_hypothesis():
    run_state_machine_as_test(
        DictSM, settings(max_examples=500, stateful_step_count=100))
