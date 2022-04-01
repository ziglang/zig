from _collections import deque
import gc

#from  AppTestW_IterObjectApp
def test_user_iter():
    class C(object):
        def __next__(self):
            raise StopIteration
        def __iter__(self):
            return self
    assert list(C()) == []

def test_iter_getitem():
    class C(object):
        def __getitem__(self, i):
            return range(2)[i]
    assert list(C()) == list(range(2))

def test_iter_fail_noseq():
    class C(object):
        pass
    raises(TypeError,
                      iter,
                      C())

#from AppTest_IterObject
def test_no_len_on_list_iter():
    iterable = [1,2,3,4]
    raises(TypeError, len, iter(iterable))

def test_list_iter_setstate():
    iterable = iter([1,2,3,4])
    assert next(iterable) == 1
    iterable.__setstate__(0)
    assert next(iterable) == 1
    iterable.__setstate__(-100)
    assert next(iterable) == 1
    raises(TypeError, iterable.__setstate__, '0')

def test_reversed_iter_setstate():
    iterable = reversed([1,2,3,4])
    assert next(iterable) == 4
    iterable.__setstate__(0)
    assert next(iterable) == 1
    iterable.__setstate__(2)
    next(iterable); next(iterable)
    assert next(iterable) == 1
    iterable.__setstate__(3)
    assert next(iterable) == 4
    iterable.__setstate__(-1)
    raises(StopIteration, next, iterable)
    #
    iterable = reversed([1,2,3,4])
    iterable.__setstate__(-100)
    raises(StopIteration, next, iterable)
    #
    iterable = reversed([1,2,3,4])
    iterable.__setstate__(100)
    assert next(iterable) == 4
    assert next(iterable) == 3

def test_forward_iter_reduce():
    T = "abc"
    iterable = iter(T)
    assert iterable.__reduce__() == (iter, (T, ), 0)
    assert next(iterable) == "a"
    assert iterable.__reduce__() == (iter, (T, ), 1)
    assert next(iterable) == "b"
    assert iterable.__reduce__() == (iter, (T, ), 2)
    assert next(iterable) == "c"
    assert iterable.__reduce__() == (iter, (T, ), 3)
    raises(StopIteration, next, iterable)
    assert (iterable.__reduce__() == (iter, ((), )) or   # pypy
            iterable.__reduce__() == (iter, ("", )))     # cpython

def test_reversed_iter_reduce():
    T = [1, 2, 3, 4]
    iterable = reversed(T)
    assert iterable.__reduce__() == (reversed, (T, ), 3)
    assert next(iterable) == 4
    assert iterable.__reduce__() == (reversed, (T, ), 2)
    assert next(iterable) == 3
    assert iterable.__reduce__() == (reversed, (T, ), 1)
    assert next(iterable) == 2
    assert iterable.__reduce__() == (reversed, (T, ), 0)
    assert next(iterable) == 1
    assert iterable.__reduce__() == (reversed, (T, ), -1)
    raises(StopIteration, next, iterable)
    assert (iterable.__reduce__() == (iter, ((), )) or   # pypy
            iterable.__reduce__() == (iter, ([], )))     # cpython

def test_no_len_on_tuple_iter():
    iterable = (1,2,3,4)
    raises(TypeError, len, iter(iterable))

def test_no_len_on_deque_iter():
    iterable = deque([1,2,3,4])
    raises(TypeError, len, iter(iterable))

def test_no_len_on_reversed():
    it = reversed("foobar")
    raises(TypeError, len, it)

def test_no_len_on_reversed_seqiter():
    # this one fails on CPython.  See http://bugs.python.org/issue3689
    it = reversed([5,6,7])
    raises(TypeError, len, it)

def test_no_len_on_UserList_iter():
    class UserList(object):
        def __init__(self, i):
            self.i = i
        def __getitem__(self, i):
            return range(self.i)[i]
    iterable = UserList([1,2,3,4])
    raises(TypeError, len, iter(iterable))

def test_no_len_on_UserList_iter_reversed():
    class UserList(object):
        def __init__(self, i):
            self.i = i
        def __getitem__(self, i):
            return range(self.i)[i]
    iterable = UserList([1,2,3,4])
    raises(TypeError, len, iter(iterable))
    raises(TypeError, reversed, iterable)

def test_no_len_on_UserList_reversed():
    iterable = [1,2,3,4]
    raises(TypeError, len, reversed(iterable))

def test_reversed_frees_empty():
    for typ in list, str:
        free = [False]
        class U(typ):
            def __del__(self):
                free[0] = True
        r = reversed(U())
        raises(StopIteration, next, r)
        gc.collect(); gc.collect(); gc.collect()
        assert free[0]

def test_reversed_mutation():
    n = 10
    d = list(range(n))
    it = reversed(d)
    next(it)
    next(it)
    assert it.__length_hint__() == n-2
    d.append(n)
    assert it.__length_hint__() == n-2
    d[1:] = []
    assert it.__length_hint__() == 0
    assert list(it) == []
    d.extend(range(20))
    assert it.__length_hint__() == 0

def test_no_len_on_set_iter():
    iterable = set([1,2,3,4])
    raises(TypeError, len, iter(iterable))

def test_no_len_on_xrange():
    iterable = range(10)
    raises(TypeError, len, iter(iterable))

def test_contains():
    logger = []

    class Foo(object):

        def __init__(self, value, name=None):
            self.value = value
            self.name = name or value

        def __repr__(self):
            return '<Foo %s>' % self.name

        def __eq__(self, other):
            logger.append((self, other))
            return self.value == other.value

    foo1, foo2, foo3 = Foo(1), Foo(2), Foo(3)
    foo42 = Foo(42)
    foo_list = [foo1, foo2, foo3]
    foo42 in (x for x in foo_list)
    logger_copy = logger[:]  # prevent re-evaluation during pytest error print
    assert logger_copy == [(foo1, foo42), (foo2, foo42), (foo3, foo42)]

    del logger[:]
    foo2_bis = Foo(2, '2 bis')
    foo2_bis in (x for x in foo_list)
    logger_copy = logger[:]  # prevent re-evaluation during pytest error print
    assert logger_copy == [(foo1, foo2_bis), (foo2, foo2_bis)]
