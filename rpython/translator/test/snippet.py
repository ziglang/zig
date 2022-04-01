"""Snippets for translation

This module holds various snippets, to be used by translator
unittests.

We define argument types as default arguments to the snippet
functions.
"""

numtype = (int, float)
anytype = (int, float, str)
seqtype = (list, tuple)

def if_then_else(cond=anytype, x=anytype, y=anytype):
    if cond:
        return x
    else:
        return y

def my_gcd(a=numtype, b=numtype):
    r = a % b
    while r:
        a = b
        b = r
        r = a % b
    return b

def is_perfect_number(n=int):
    div = 1
    sum = 0
    while div < n:
        if n % div == 0:
            sum += div
        div += 1
    return n == sum

def my_bool(x=int):
    return not not x

def my_contains(seq=seqtype, elem=anytype):
    return elem in seq

def is_one_or_two(n=int):
    return n in [1, 2]

def two_plus_two():
    """Array test"""
    array = [0] * 3
    array[0] = 2
    array[1] = 2
    array[2] = array[0] + array[1]
    return array[2]

def get_set_del_slice(l=list):
    del l[:1]
    del l[-1:]
    del l[2:4]
    l[:1] = [3]
    l[-1:] = [9]
    l[2:4] = [8,11]
    return l[:2], l[5:], l[3:5]

def sieve_of_eratosthenes():
    """Sieve of Eratosthenes

    This one is from an infamous benchmark, "The Great Computer
    Language Shootout".

    URL is: http://www.bagley.org/~doug/shootout/
    """
    flags = [True] * (8192+1)
    count = 0
    i = 2
    while i <= 8192:
        if flags[i]:
            k = i + i
            while k <= 8192:
                flags[k] = False
                k = k + i
            count = count + 1
        i = i + 1
    return count

def simple_func(i=numtype):
    return i + 1

def while_func(i=numtype):
    total = 0
    while i > 0:
        total = total + i
        i = i - 1
    return total

def nested_whiles(i=int, j=int):
    s = ''
    z = 5
    while z > 0:
        z = z - 1
        u = i
        while u < j:
            u = u + 1
            s = s + '.'
        s = s + '!'
    return s

def poor_man_range(i=int):
    lst = []
    while i > 0:
        i = i - 1
        lst.append(i)
    lst.reverse()
    return lst

def poor_man_rev_range(i=int):
    lst = []
    while i > 0:
        i = i - 1
        lst += [i]
    return lst

def simple_id(x=anytype):
    return x

def branch_id(cond=anytype, a=anytype, b=anytype):
    while 1:
        if cond:
            return a
        else:
            return b

def builtinusage():
    return pow(2, 2)

def yast(lst=seqtype):
    total = 0
    for z in lst:
        total = total + z
    return total

def time_waster(n=int):
    """Arbitrary test function"""
    i = 0
    x = 1
    while i < n:
        j = 0
        while j <= i:
            j = j + 1
            x = x + (i & j)
        i = i + 1
    return x

def half_of_n(n=int):
    """Slice test"""
    i = 0
    lst = range(n)
    while lst:
        lst = lst[1:-1]
        i = i + 1
    return i

def int_id(x=int):
    i = 0
    while i < x:
        i = i + 1
    return i

def greet(target=str):
    """String test"""
    hello = "hello"
    return hello + target

def choose_last():
    """For loop test"""
    set = ["foo", "bar", "spam", "egg", "python"]
    choice = ""
    for choice in set:
        pass
    return choice

def poly_branch(x=int):
    if x:
        y = [1,2,3]
    else:
        y = ['a','b','c']

    z = y
    return z*2

def s_and(x=anytype, y=anytype):
    if x and y:
        return 'yes'
    else:
        return 'no'

def break_continue(x=numtype):
    result = []
    i = 0
    while 1:
        i = i + 1
        try:
            if i&1:
                continue
            if i >= x:
                break
        finally:
            result.append(i)
        i = i + 1
    return result

def reverse_3(lst=seqtype):
    try:
        a, b, c = lst
    except:
        return 0, 0, 0
    return c, b, a

def finallys(lst=seqtype):
    x = 1
    try:
        x = 2
        try:
            x = 3
            a, = lst
            x = 4
        except KeyError:
            return 5
        except ValueError:
            return 6
        b, = lst
        x = 7
    finally:
        x = 8
    return x

def finally2(o, k):
    try:
        o[k] += 1
    finally:
        o[-1] = 'done'

def bare_raise(o, ignore):
    try:
        return o[5]
    except:
        if not ignore:
            raise

def factorial(n=int):
    if n <= 1:
        return 1
    else:
        return n * factorial(n-1)

def factorial2(n=int):   # analysed in a different order
    if n > 1:
        return n * factorial2(n-1)
    else:
        return 1

def _append_five(lst):
    lst += [5]

def call_five():
    a = []
    _append_five(a)
    return a

def _append_six(lst):
    lst += [6]

def call_five_six():
    a = []
    _append_five(a)
    _append_six(a)
    return a

def call_unpack_56():
    a = call_five_six()
    return len(a), a[0], a[1]

def forty_two():
    return 42

def never_called():
    return "booo"

def constant_result():
    if forty_two():
        return "yadda"
    else:
        return never_called()

class CallablePrebuiltConstant(object):
    def __call__(self):
        return 42

callable_prebuilt_constant = CallablePrebuiltConstant()

def call_cpbc():
    return callable_prebuilt_constant()


class E1(Exception):
    pass

class E2(Exception):
    pass

def raise_choose(n):
    if n == 1:
        raise E1
    elif n == 2:
        raise E2
    elif n == -1:
        raise Exception
    return 0

def try_raise_choose(n=int):
    try:
        raise_choose(n)
    except E1:
        return 1
    except E2:
        return 2
    except Exception:
        return -1
    return 0

def do_try_raise_choose():
    r = []
    for n in [-1,0,1,2]:
        r.append(try_raise_choose(n))
    return r


# INHERITANCE / CLASS TESTS
class C(object): pass

def build_instance():
    c = C()
    return c

def set_attr():
    c = C()
    c.a = 1
    c.a = 2
    return c.a

def merge_setattr(x):
    if x:
        c = C()
        c.a = 1
    else:
        c = C()
    return c.a

class D(C): pass
class E(C): pass

def inheritance1():
    d = D()
    d.stuff = ()
    e = E()
    e.stuff = -12
    e.stuff = 3
    lst = [d, e]
    return d.stuff, e.stuff


def inheritance2():
    d = D()
    d.stuff = (-12, -12)
    e = E()
    e.stuff = (3, 12.3)
    return _getstuff(d), _getstuff(e)

class F:
    pass
class G(F):
    def m(self, x):
        return self.m2(x)
    def m2(self, x):
        return D(), x
class H(F):
    def m(self, y):
        self.attr = 1
        return E(), y

def knownkeysdict(b=anytype):
    if b:
        d = {'a': 0}
        d['b'] = b
        d['c'] = 'world'
    else:
        d = {'b': -123}
    return d['b']

def generaldict(key=str, value=int, key2=str, value2=int):
    d = {key: value}
    d[key2] = value2
    return d[key or key2]

def prime(n=int):
    return len([i for i in range(1,n+1) if n%i==0]) == 2

class A0:
    pass
class A1(A0):
    clsattr = 123
class A2(A1):
    clsattr = 456
class A3(A2):
    clsattr = 789
class A4(A3):
    pass
class A5(A0):
    clsattr = 101112

def classattribute(flag=int):
    if flag == 1:
        x = A1()
    elif flag == 2:
        x = A2()
    elif flag == 3:
        x = A3()
    elif flag == 4:
        x = A4()
    else:
        x = A5()
    return x.clsattr


class Z:
    def my_method(self):
        return self.my_attribute

class WithInit:
    def __init__(self, n):
        self.a = n

class WithMoreInit(WithInit):
    def __init__(self, n, m):
        WithInit.__init__(self, n)
        self.b = m

def simple_method(v=anytype):
    z = Z()
    z.my_attribute = v
    return z.my_method()

def with_init(v=int):
    z = WithInit(v)
    return z.a

def with_more_init(v=int, w=bool):
    z = WithMoreInit(v, w)
    if z.b:
        return z.a
    else:
        return -z.a

global_z = Z()
global_z.my_attribute = 42

def global_instance():
    return global_z.my_method()

def call_Z_my_method(z):
    return z.my_method

def somepbc_simplify():
    z = Z()
    call_Z_my_method(global_z)
    call_Z_my_method(z)

class ClassWithMethods:
    def cm(cls, x):
        return x
    cm = classmethod(cm)

    def sm(x):
        return x
    sm = staticmethod(sm)


global_c = C()
global_c.a = 1

def global_newstyle_instance():
    return global_c

global_rl = []
global_rl.append(global_rl)

def global_recursive_list():
    return global_rl

class MI_A(object):
    a = 1
class MI_B(MI_A):
    b = 2
class MI_C(MI_A):
    c = 3
class MI_D(MI_B, MI_C):
    d = 4

def multiple_inheritance():
    i = MI_D()
    return i.a + i.b + i.c + i.d

class CBase(object):
    pass
class CSub1(CBase):
    def m(self):
        self.x = 42
        return self.x
class CSub2(CBase):
    def m(self):
        self.x = 'world'
        return self.x

def methodcall_is_precise(cond):
    if cond:
        x = CSub1()
        x.m()
    else:
        x = CSub2()
        x.m()
    return CSub1().m()


def flow_type_info(i):
    if isinstance(i, int):
        a = i + 1
    else:
        a = len(str(i))
    return a

def flow_usertype_info(ob):
    if isinstance(ob, WithInit):
        return ob
    else:
        return WithMoreInit(1, 2)

def star_args0(*args):
    return args[0] / 2

def call_star_args0(z):
    return star_args0(z)

def star_args1(a, *args):
    return a + args[0] / 2

def call_star_args1(z):
    return star_args1(z, 20)

def star_args1def(a=4, *args):
    if args:
        return a + args[0] / 2
    else:
        return a*3

def call_star_args1def(z):
    a = star_args1def(z, 22)
    b = star_args1def(5)
    c = star_args1def()
    return a+b+c

def star_args(x, y, *args):
    return x + args[0]

def call_star_args(z):
    return star_args(z, 5, 10, 15, 20)

def call_star_args_multiple(z):
    a = star_args(z, 5, 10)
    b = star_args(z, 5, 10, 15)
    c = star_args(z, 5, 10, 15, 20)
    return a+b+c

def default_args(x, y=2, z=3L):
    return x+y+z

def call_default_args(u):
    return default_args(111, u)

def default_and_star_args(x, y=2, z=3, *more):
    return x+y+z+len(more)

def call_default_and_star_args(u):
    return (default_and_star_args(111, u),
            default_and_star_args(-1000, -2000, -3000, -4000, -5000))

def call_with_star(z):
    return default_args(-20, *z)

def call_with_keyword(z):
    return default_args(-20, z=z)

def call_very_complex(z, args, kwds):
    return default_args(-20, z=z, *args, **kwds)

def powerset(setsize=int):
    """Powerset

    This one is from a Philippine Pythonista Hangout, an modified
    version of Andy Sy's code.

    list.append is modified to list concatenation, and powerset
    is pre-allocated and stored, instead of printed.

    URL is: http://lists.free.net.ph/pipermail/python/2002-November/
    """
    set = range(setsize)
    maxcardinality = pow(2, setsize)
    bitmask = 0L
    powerset = [None] * maxcardinality
    ptr = 0
    while bitmask < maxcardinality:
        bitpos = 1L
        index = 0
        subset = []
        while bitpos < maxcardinality:
            if bitpos & bitmask:
                subset = subset + [set[index]]
            index += 1
            bitpos <<= 1
        powerset[ptr] = subset
        ptr += 1
        bitmask += 1
    return powerset

def harmonic(n):
    result = 0.0
    for i in range(n, 0, -1):
        result += 1.0 / n
    return result


# --------------------(Currently) Non runnable Functions ---------------------

def _somebug1(n=int):
    l = []
    v = l.append
    while n:
        l[7] = 5 # raises an exception
        break
    return v

def _getstuff(x):
    return x.stuff

# --------------------(Currently) Non compilable Functions ---------------------

class BadInit(object):
    def update(self, k):
        self.k = 1
    def __init__(self, v):
        return
        self.update(**{'k':v})
    def read(self):
        return self.k

global_bi = BadInit(1)

def global_badinit():
    return global_bi.read()

def _attrs():
    def b(): pass
    b.f = 4
    b.g = 5
    return b.f + b.g

def _methodcall1(cond):
    if cond:
        x = G()
    else:
        x = H()
    return x.m(42)

def func1():
    pass

def func2():
    pass

def mergefunctions(cond):
    if cond:
        x = func1
    else:
        x = func2
    return x

def func_producing_exception():
    raise ValueError("this might e.g. block the caller")

def funccallsex():
    return func_producing_exception()


def func_arg_unpack():
    a,b = 3, "hello"
    return a

class APBC:
    def __init__(self):
        self.answer = 42

apbc = APBC()
apbc.answer = 7

def preserve_pbc_attr_on_instance(cond):
    if cond:
        x = APBC()
    else:
        x = apbc
    return x.answer


class APBCS(object):
    __slots__ = ['answer']
    def __init__(self):
        self.answer = 42

apbcs = APBCS()
apbcs.answer = 7

def preserve_pbc_attr_on_instance_with_slots(cond):
    if cond:
        x = APBCS()
    else:
        x = apbcs
    return x.answer


def is_and_knowntype(x):
    if x is None:
        return x
    else:
        return None

def isinstance_and_knowntype(x):
    if isinstance(x, APBC):
        return x
    else:
        return apbc

def simple_slice(x):
    return x[:10]

def simple_iter(x):
    return iter(x)

def simple_zip(x,y):
    return zip(x,y)

def dict_copy(d):
    return d.copy()

def dict_update(x):
    d = {x:x}
    d.update({1:2})
    return d

def dict_keys():
    d = {"a" : 1}
    return d.keys()

def dict_keys2():
    d = {"a" : 1}
    keys = d.keys()
    d["123"] = 12
    return keys

def dict_values():
    d = {"a" : "a"}
    return d.values()

def dict_values2():
    d = {54312 : "a"}
    values = d.values()
    d[1] = "12"
    return values

def dict_items():
    d = {'a' : 1}
    return d.items()

class Exc(Exception):
    pass

def exception_deduction0(x):
    pass

def exception_deduction():
    try:
        exception_deduction0(2)
    except Exc as e:
        return e
    return Exc()


def always_raising(x):
    raise ValueError

def witness(x):
    pass

def exception_deduction_with_raise1(x):
    try:
        exception_deduction0(2)
        if x:
            raise Exc()
    except Exc as e:
        witness(e)
        return e
    return Exc()

def exception_deduction_with_raise2(x):
    try:
        exception_deduction0(2)
        if x:
            raise Exc
    except Exc as e:
        witness(e)
        return e
    return Exc()

def exception_deduction_with_raise3(x):
    try:
        exception_deduction0(2)
        if x:
            raise Exc, Exc()
    except Exc as e:
        witness(e)
        return e
    return Exc()

def slice_union(x):
    if x:
        return slice(1)
    else:
        return slice(0, 10, 2)

def exception_deduction_we_are_dumb():
    a = 1
    try:
        exception_deduction0(2)
    except Exc as e:
        a += 1
        return e
    return Exc()

class Exc2(Exception):
    pass

def nested_exception_deduction():
    try:
        exception_deduction0(1)
    except Exc as e:
        try:
            exception_deduction0(2)
        except Exc2 as f:
            return (e, f)
        return (e, Exc2())
    return (Exc(), Exc2())

class Exc3(Exception):
    def m(self):
        return 1

class Exc4(Exc3):
    def m(self):
        return 1

class Sp:
    def o(self):
        raise Exc3

class Mod:
    def __init__(self, s):
        self.s = s

    def p(self):
        s = self.s
        try:
            s.o()
        except Exc3 as e:
            return e.m()
        return 0

class Mod3:
    def __init__(self, s):
        self.s = s

    def p(self):
        s = self.s
        try:
            s.o()
        except Exc4 as e1:
            return e1.m()
        except Exc3 as e2:
            try:
                return e2.m()
            except Exc4 as e3:
                return e3.m()
        return 0


mod = Mod(Sp())
mod3 = Mod3(Sp())

def exc_deduction_our_exc_plus_others():
    return mod.p()

def exc_deduction_our_excs_plus_others():
    return mod3.p()



def call_two_funcs_but_one_can_only_raise(n):
    fn = [witness, always_raising][n]
    return fn(n)


# constant instances with __init__ vs. __new__

class Thing1:

    def __init__(self):
        self.thingness = 1

thing1 = Thing1()

def one_thing1():
    return thing1


class Thing2(long):
    def __new__(t, v):
        return long.__new__(t, v * 2)

thing2 = Thing2(2)

def one_thing2():
    return thing2

# propagation of fresh instances through attributes

class Stk:
    def __init__(self):
        self.itms = []

    def push(self, v):
        self.itms.append(v)

class EC:

    def __init__(self):
        self.stk = Stk()

    def enter(self, f):
        self.stk.push(f)

def propagation_of_fresh_instances_through_attrs(x):
    e = EC()
    e.enter(x)

# same involving recursion


class R:
    def __init__(self, n):
        if n > 0:
            self.r = R(n-1)
        else:
            self.r = None
        self.n = n
        if self.r:
            self.m = self.r.n
        else:
            self.m = -1

def make_r(n):
    return R(n)

class B:
    pass

class Even(B):
    def __init__(self, n):
        if n > 0:
            self.x = [Odd(n-1)]
            self.y = self.x[0].x
        else:
            self.x = []
            self.y = []

class Odd(B):
    def __init__(self, n):
        self.x = [Even(n-1)]
        self.y = self.x[0].x

def make_eo(n):
    if n % 2 == 0:
        return Even(n)
    else:
        return Odd(n)


# shows that we care about the expanded structure in front of changes to attributes involving only
# instances rev numbers

class Box:
    pass

class Box2:
    pass

class Box3(Box2):
    pass

def flow_rev_numbers(n):
    bx3 = Box3()
    bx3.x = 1
    bx = Box()
    bx.bx3 = bx3
    if n > 0:
        z = bx.bx3.x
        if n > 0:
            bx2 = Box2()
            bx2.x = 3
        return z
    raise Exception


from rpython.rlib.rarithmetic import ovfcheck

def add_func(i=numtype):
    try:
        return ovfcheck(i + 1)
    except OverflowError:
        raise

from sys import maxint

def div_func(i=numtype):
    try:
        return ovfcheck((-maxint-1) // i)
    except (OverflowError, ZeroDivisionError):
        raise

def mul_func(x=numtype, y=numtype):
    try:
        return ovfcheck(x * y)
    except OverflowError:
        raise

def mod_func(i=numtype):
    try:
        return ovfcheck((-maxint-1) % i)
    except OverflowError:
        raise
    except ZeroDivisionError:
        raise

def rshift_func(i=numtype):
    try:
        return (-maxint-1) >> i
    except ValueError:
        raise

class hugelmugel(OverflowError):
    pass

def hugo(a, b, c):pass

def lshift_func(i=numtype):
    try:
        hugo(2, 3, 5)
        return ovfcheck((-maxint-1) << i)
    except (hugelmugel, OverflowError, StandardError, ValueError):
        raise

def unary_func(i=numtype):
    try:
        return ovfcheck(-i), ovfcheck(abs(i-1))
    except:
        raise
    # XXX it would be nice to get it right without an exception
    # handler at all, but then we need to do much harder parsing
