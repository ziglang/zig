import py
from rpython.rlib.signature import signature, finishsigs, FieldSpec, ClassSpec
from rpython.rlib import types
from rpython.annotator import model
from rpython.rtyper.llannotation import SomePtr
from rpython.annotator.signature import SignatureError
from rpython.translator.translator import TranslationContext, graphof
from rpython.rtyper.lltypesystem import rstr
from rpython.rtyper.annlowlevel import LowLevelAnnotatorPolicy


def annotate_at(f, policy=None):
    t = TranslationContext()
    t.config.translation.check_str_without_nul = True
    a = t.buildannotator(policy=policy)
    a.annotate_helper(f, [model.s_ImpossibleValue]*f.__code__.co_argcount, policy=policy)
    return a

def sigof(a, f):
    # returns [param1, param2, ..., ret]
    g = graphof(a.translator, f)
    return [a.binding(v) for v in g.startblock.inputargs] + [a.binding(g.getreturnvar())]

def getsig(f, policy=None):
    a = annotate_at(f, policy=policy)
    return sigof(a, f)

def check_annotator_fails(caller):
    exc = py.test.raises(model.AnnotatorError, annotate_at, caller).value
    assert caller.__name__ in str(exc)


def test_bookkeeping():
    @signature('x', 'y', returns='z')
    def f(a, b):
        return a + len(b)
    f.foo = 'foo'
    assert f._signature_ == (('x', 'y'), 'z')
    assert f.__name__ == 'f'
    assert f.foo == 'foo'
    assert f(1, 'hello') == 6

def test_basic():
    @signature(types.int(), types.str(), returns=types.char())
    def f(a, b):
        return b[a]
    assert getsig(f) == [model.SomeInteger(), model.SomeString(), model.SomeChar()]

def test_arg_errors():
    @signature(types.int(), types.str(), returns=types.int())
    def f(a, b):
        return a + len(b)
    @check_annotator_fails
    def ok_for_body(): # would give no error without signature
        f(2.0, 'b')
    @check_annotator_fails
    def bad_for_body(): # would give error inside 'f' body, instead errors at call
        f('a', 'b')

def test_return():
    @signature(returns=types.str())
    def f():
        return 'a'
    assert getsig(f) == [model.SomeString()]

    @signature(types.str(), returns=types.str())
    def f(x):
        return x
    def g():
        return f('a')
    a = annotate_at(g)
    assert sigof(a, f) == [model.SomeString(), model.SomeString()]

def test_return_errors():
    @check_annotator_fails
    @signature(returns=types.int())
    def int_not_char():
        return 'a'

    @check_annotator_fails
    @signature(types.str(), returns=types.int())
    def str_to_int(s):
        return s

    @signature(returns=types.str())
    def str_not_None():
        return None
    @check_annotator_fails
    def caller_of_str_not_None():
        return str_not_None()

@py.test.mark.xfail
def test_return_errors_xfail():
    @check_annotator_fails
    @signature(returns=types.str())
    def str_not_None():
        return None


def test_none():
    @signature(returns=types.none())
    def f():
        pass
    assert getsig(f) == [model.s_None]

def test_float():
    @signature(types.longfloat(), types.singlefloat(), returns=types.float())
    def f(a, b):
        return 3.0
    assert getsig(f) == [model.SomeLongFloat(), model.SomeSingleFloat(), model.SomeFloat()]

def test_unicode():
    @signature(types.unicode(), returns=types.int())
    def f(u):
        return len(u)
    assert getsig(f) == [model.SomeUnicodeString(), model.SomeInteger()]

def test_str0():
    @signature(types.unicode0(), returns=types.str0())
    def f(u):
        return 'str'
    assert getsig(f) == [model.SomeUnicodeString(no_nul=True),
                         model.SomeString(no_nul=True)]

def test_ptr():
    policy = LowLevelAnnotatorPolicy()
    @signature(types.ptr(rstr.STR), returns=types.none())
    def f(buf):
        pass
    argtype = getsig(f, policy=policy)[0]
    assert isinstance(argtype, SomePtr)
    assert argtype.ll_ptrtype.TO == rstr.STR

    def g():
        f(rstr.mallocstr(10))
    getsig(g, policy=policy)


def test_list():
    @signature(types.list(types.int()), returns=types.int())
    def f(a):
        return len(a)
    argtype = getsig(f)[0]
    assert isinstance(argtype, model.SomeList)
    item = argtype.listdef.listitem
    assert item.s_value == model.SomeInteger()
    assert item.resized == True

    @check_annotator_fails
    def ok_for_body():
        f(['a'])
    @check_annotator_fails
    def bad_for_body():
        f('a')

    @signature(returns=types.list(types.char()))
    def ff():
        return ['a']
    @check_annotator_fails
    def mutate_broader():
        ff()[0] = 'abc'
    @check_annotator_fails
    def mutate_unrelated():
        ff()[0] = 1
    @check_annotator_fails
    @signature(types.list(types.char()), returns=types.int())
    def mutate_in_body(l):
        l[0] = 'abc'
        return len(l)

    def can_append():
        l = ff()
        l.append('b')
    getsig(can_append)

def test_array():
    @signature(returns=types.array(types.int()))
    def f():
        return [1]
    rettype = getsig(f)[0]
    assert isinstance(rettype, model.SomeList)
    item = rettype.listdef.listitem
    assert item.s_value == model.SomeInteger()
    assert item.resized == False

    def try_append():
        l = f()
        l.append(2)
    check_annotator_fails(try_append)

def test_dict():
    @signature(returns=types.dict(types.str(), types.int()))
    def f():
        return {'a': 1, 'b': 2}
    rettype = getsig(f)[0]
    assert isinstance(rettype, model.SomeDict)
    assert rettype.dictdef.dictkey.s_value   == model.SomeString()
    assert rettype.dictdef.dictvalue.s_value == model.SomeInteger()


def test_instance():
    class C1(object):
        pass
    class C2(C1):
        pass
    class C3(C2):
        pass
    @signature(types.instance(C3), returns=types.instance(C2))
    def f(x):
        assert isinstance(x, C2)
        return x
    argtype, rettype = getsig(f)
    assert isinstance(argtype, model.SomeInstance)
    assert argtype.classdef.classdesc.pyobj == C3
    assert isinstance(rettype, model.SomeInstance)
    assert rettype.classdef.classdesc.pyobj == C2

    @check_annotator_fails
    def ok_for_body():
        f(C2())
    @check_annotator_fails
    def bad_for_body():
        f(C1())
    @check_annotator_fails
    def ok_for_body():
        f(None)

def test_instance_or_none():
    class C1(object):
        pass
    class C2(C1):
        pass
    class C3(C2):
        pass
    @signature(types.instance(C3, can_be_None=True), returns=types.instance(C2, can_be_None=True))
    def f(x):
        assert isinstance(x, C2) or x is None
        return x
    argtype, rettype = getsig(f)
    assert isinstance(argtype, model.SomeInstance)
    assert argtype.classdef.classdesc.pyobj == C3
    assert argtype.can_be_None
    assert isinstance(rettype, model.SomeInstance)
    assert rettype.classdef.classdesc.pyobj == C2
    assert rettype.can_be_None

    @check_annotator_fails
    def ok_for_body():
        f(C2())
    @check_annotator_fails
    def bad_for_body():
        f(C1())


def test_self():
    @finishsigs
    class C(object):
        @signature(types.self(), types.self(), returns=types.none())
        def f(self, other):
            pass
    class D1(C):
        pass
    class D2(C):
        pass

    def g():
        D1().f(D2())
    a = annotate_at(g)

    argtype = sigof(a, C.__dict__['f'])[0]
    assert isinstance(argtype, model.SomeInstance)
    assert argtype.classdef.classdesc.pyobj == C

def test_self_error():
    class C(object):
        @signature(types.self(), returns=types.none())
        def incomplete_sig_meth(self):
            pass

    exc = py.test.raises(SignatureError, annotate_at, C.incomplete_sig_meth).value
    assert 'incomplete_sig_meth' in str(exc)
    assert 'finishsigs' in str(exc)

def test_any_as_argument():
    @signature(types.any(), types.int(), returns=types.float())
    def f(x, y):
        return x + y
    @signature(types.int(), returns=types.float())
    def g(x):
        return f(x, x)
    sig = getsig(g)
    assert sig == [model.SomeInteger(), model.SomeFloat()]

    @signature(types.float(), returns=types.float())
    def g(x):
        return f(x, 4)
    sig = getsig(g)
    assert sig == [model.SomeFloat(), model.SomeFloat()]

    @signature(types.str(), returns=types.int())
    def cannot_add_string(x):
        return f(x, 2)
    exc = py.test.raises(model.AnnotatorError, annotate_at, cannot_add_string).value
    assert 'Blocked block' in str(exc)

def test_return_any():
    @signature(types.int(), returns=types.any())
    def f(x):
        return x
    sig = getsig(f)
    assert sig == [model.SomeInteger(), model.SomeInteger()]

    @signature(types.str(), returns=types.any())
    def cannot_add_string(x):
        return f(3) + x
    exc = py.test.raises(model.AnnotatorError, annotate_at, cannot_add_string).value
    assert 'Blocked block' in str(exc)
    assert 'cannot_add_string' in str(exc)



@py.test.mark.xfail
def test_class_basic():
    class C(object):
        _fields_ = ClassSpec({'x': FieldSpec(types.int)})

    def wrong_type():
        c = C()
        c.x = 'a'
    check_annotator_fails(wrong_type)

    def bad_field():
        c = C()
        c.y = 3
    check_annotator_fails(bad_field)


@py.test.mark.xfail
def test_class_shorthand():
    class C1(object):
        _fields_ = {'x': FieldSpec(types.int)}
    def wrong_type_1():
        c = C1()
        c.x = 'a'
    check_annotator_fails(wrong_type_1)

    class C2(object):
        _fields_ = ClassSpec({'x': types.int})
    def wrong_type_2():
        c = C2()
        c.x = 'a'
    check_annotator_fails(wrong_type_1)


@py.test.mark.xfail
def test_class_inherit():
    class C(object):
        _fields_ = ClassSpec({'x': FieldSpec(types.int)})

    class C1(object):
        _fields_ = ClassSpec({'y': FieldSpec(types.int)})

    class C2(object):
        _fields_ = ClassSpec({'y': FieldSpec(types.int)}, inherit=True)

    def no_inherit():
        c = C1()
        c.x = 3
    check_annotator_fails(no_inherit)

    def good():
        c = C2()
        c.x = 3
    annotate_at(good)

    def wrong_type():
        c = C2()
        c.x = 'a'
    check_annotator_fails(wrong_type)
