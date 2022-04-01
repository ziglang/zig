# -*- coding: utf-8 -*-
import py
import pytest
from pypy.interpreter.argument import (Arguments as RegularArguments, ArgErr, ArgErrUnknownKwds,
        ArgErrMultipleValues, ArgErrMissing, ArgErrTooMany, ArgErrTooManyMethod,
        ArgErrPosonlyAsKwds)
from pypy.interpreter.signature import Signature
from pypy.interpreter.error import OperationError

class Arguments(RegularArguments):
    def __init__(self, space, args_w, keywords=None, keywords_w=None,
                 w_stararg=None, w_starstararg=None,
                 methodcall=False, fnname_parens=None):
        if keywords:
            keyword_names_w = [space.newtext(name) for name in keywords]
        else:
            keyword_names_w = None
        if isinstance(w_starstararg, dict):
            w_starstararg = {space.newtext(name) if isinstance(name, str) else name: value for name, value in w_starstararg.iteritems()}
        RegularArguments.__init__(self, space, args_w, keyword_names_w, keywords_w,
                w_stararg, w_starstararg, methodcall, fnname_parens)

    @property
    def keywords(self):
        return [self.space.text_w(w_name) for w_name in self.keyword_names_w]


class TestSignature(object):
    def test_helpers(self):
        sig = Signature(["a", "b", "c"], None, None)
        assert sig.num_argnames() == 3
        assert not sig.has_vararg()
        assert not sig.has_kwarg()
        assert sig.scope_length() == 3
        assert sig.getallvarnames() == ["a", "b", "c"]
        sig = Signature(["a", "b", "c"], "c", None)
        assert sig.num_argnames() == 3
        assert sig.has_vararg()
        assert not sig.has_kwarg()
        assert sig.scope_length() == 4
        assert sig.getallvarnames() == ["a", "b", "c", "c"]
        sig = Signature(["a", "b", "c"], None, "c")
        assert sig.num_argnames() == 3
        assert not sig.has_vararg()
        assert sig.has_kwarg()
        assert sig.scope_length() == 4
        assert sig.getallvarnames() == ["a", "b", "c", "c"]
        sig = Signature(["a", "b", "c", "kwonly"], "d", "e", 1)
        assert sig.num_argnames() == 3
        assert sig.has_vararg()
        assert sig.has_kwarg()
        assert sig.scope_length() == 6
        assert sig.getallvarnames() == ["a", "b", "c", "kwonly", "d", "e"]

    def test_eq(self):
        sig1 = Signature(["a", "b", "c"], "d", "c")
        sig2 = Signature(["a", "b", "c"], "d", "c")
        assert sig1 == sig2


    def test_find_argname(self):
        sig = Signature(["a", "b", "c", "kwonly"], None, None, 1)
        assert sig.find_argname("a") == 0
        assert sig.find_argname("b") == 1
        assert sig.find_argname("c") == 2
        assert sig.find_argname("d") == -1
        assert sig.find_argname("kwonly") == 3

    def test_posonly(self):
        sig = Signature(["x", "y", "z", "a", "b", "c"], posonlyargcount=3)
        # posonly come first
        assert sig.find_argname("x") == 0
        assert sig.find_argname("y") == 1
        assert sig.find_argname("z") == 2
        assert sig.find_argname("a") == 3
        assert sig.find_argname("b") == 4
        assert sig.find_argname("c") == 5
        assert sig.find_argname("d") == -1


class dummy_wrapped_dict(dict):
    def __nonzero__(self):
        raise NotImplementedError

class kwargsdict(dict):
    pass

class W_Uni(object):
    def __init__(self, s):
        self._utf8 = s

    def eq_w(self, w_other):
        return self._utf8 == w_other._utf8

    __eq__ = eq_w

    def __ne__(self, other):
        return not self == other

    def __hash__(self):
        return hash(self._utf8)

    def eq_unwrapped(self, other):
        return self._utf8 == other

    def __repr__(self):
        return "W_Uni(%r)" % (self._utf8, )


class DummySpace(object):
    class sys:
        defaultencoding = 'utf-8'

    UnicodeObjectCls = W_Uni

    def newtuple(self, items):
        return tuple(items)

    def is_true(self, obj):
        if isinstance(obj, dummy_wrapped_dict):
            return bool(dict(obj))
        return bool(obj)

    def fixedview(self, it):
        return list(it)

    def listview(self, it):
        return list(it)

    def unpackiterable(self, it):
        return list(it)

    def view_as_kwargs(self, x):
        if len(x) == 0:
            return [], []
        return None, None

    def newdict(self, kwargs=False):
        if kwargs:
            return kwargsdict()
        return {}

    def newlist(self, l=[]):
        return l

    def setitem(self, obj, key, value):
        obj[key] = value
    setitem_str = setitem

    def getitem(self, obj, key):
        return obj[key]

    def finditem_str(self, obj, key):
        return obj.get(key, None)

    def wrap(self, obj):
        return obj

    def newtext(self, s, _=-1):
        return W_Uni(s)

    def text_w(self, s):
        if not isinstance(s, W_Uni):
            raise OperationError(self.w_TypeError, '%s is not a str' % s)
        return s._utf8

    def utf8_w(self, s):
        return s._utf8

    def str(self, obj):
        if type(obj) is W_Uni:
            return obj
        return W_Uni(str(obj))

    def len(self, x):
        return len(x)

    def len_w(self, obj):
        if type(obj) is W_Uni:
            return len(obj._utf8)
        return len(obj)

    def int_w(self, x, allow_conversion=True):
        return x

    def eq_w(self, x, y):
        return x == y

    def isinstance(self, obj, cls):
        return isinstance(obj, cls)
    isinstance_w = isinstance

    def exception_match(self, w_type1, w_type2):
        return issubclass(w_type1, w_type2)

    def call_method(self, obj, name, *args):
        try:
            method = getattr(obj, name)
        except AttributeError:
            raise OperationError(AttributeError, name)
        return method(*args)

    def lookup_in_type(self, cls, name):
        return getattr(cls, name)

    def get_and_call_function(self, w_descr, w_obj, *args):
        return w_descr.__get__(w_obj)(*args)

    def type(self, obj):
        class Type:
            def getname(self, space):
                return type(obj).__name__
            name = type(obj).__name__
        return Type()


    w_TypeError = TypeError
    w_AttributeError = AttributeError
    w_UnicodeEncodeError = UnicodeEncodeError
    w_dict = dict
    w_str = str

class TestArgumentsNormal(object):

    def test_create(self):
        space = DummySpace()
        args_w = []
        args = Arguments(space, args_w)
        assert args.arguments_w is args_w
        assert args.keyword_names_w is None
        assert args.keywords_w is None

        assert args.firstarg() is None

        args = Arguments(space, args_w, w_stararg=["*"],
                         w_starstararg={"k": 1})
        assert args.arguments_w == ["*"]
        assert args.keywords == ["k"]
        assert args.keywords_w == [1]

        assert args.firstarg() == "*"

    def test_prepend(self):
        space = DummySpace()
        args = Arguments(space, ["0"])
        args1 = args.prepend("thingy")
        assert args1 is not args
        assert args1.arguments_w == ["thingy", "0"]
        assert args1.keyword_names_w is args.keyword_names_w
        assert args1.keywords_w is args.keywords_w

    def test_fixedunpacked(self):
        space = DummySpace()

        args = Arguments(space, [], ["k"], [1])
        py.test.raises(ValueError, args.fixedunpack, 1)

        args = Arguments(space, ["a", "b"])
        py.test.raises(ValueError, args.fixedunpack, 0)
        py.test.raises(ValueError, args.fixedunpack, 1)
        py.test.raises(ValueError, args.fixedunpack, 3)
        py.test.raises(ValueError, args.fixedunpack, 4)

        assert args.fixedunpack(2) == ['a', 'b']

    def test_match0(self):
        space = DummySpace()
        args = Arguments(space, [])
        l = []
        args._match_signature(None, l, Signature([]))
        assert len(l) == 0
        l = [None, None]
        args = Arguments(space, [])
        py.test.raises(ArgErr, args._match_signature, None, l, Signature(["a"]))
        args = Arguments(space, [])
        py.test.raises(ArgErr, args._match_signature, None, l, Signature(["a"], "*"))
        args = Arguments(space, [])
        l = [None]
        args._match_signature(None, l, Signature(["a"]), defaults_w=[1])
        assert l == [1]
        args = Arguments(space, [])
        l = [None]
        args._match_signature(None, l, Signature([], "*"))
        assert l == [()]
        args = Arguments(space, [])
        l = [None]
        args._match_signature(None, l, Signature([], None, "**"))
        assert l == [{}]
        args = Arguments(space, [])
        l = [None, None]
        py.test.raises(ArgErr, args._match_signature, 41, l, Signature([]))
        args = Arguments(space, [])
        l = [None]
        args._match_signature(1, l, Signature(["a"]))
        assert l == [1]
        args = Arguments(space, [])
        l = [None]
        args._match_signature(1, l, Signature([], "*"))
        assert l == [(1,)]

    def test_match4(self):
        space = DummySpace()
        values = [4, 5, 6, 7]
        for havefirstarg in [0, 1]:
            for i in range(len(values)-havefirstarg):
                arglist = values[havefirstarg:i+havefirstarg]
                starargs = tuple(values[i+havefirstarg:])
                if havefirstarg:
                    firstarg = values[0]
                else:
                    firstarg = None
                args = Arguments(space, arglist, w_stararg=starargs)
                l = [None, None, None, None]
                args._match_signature(firstarg, l, Signature(["a", "b", "c", "d"]))
                assert l == [4, 5, 6, 7]
                args = Arguments(space, arglist, w_stararg=starargs)
                l = [None, None, None, None, None, None]
                py.test.raises(ArgErr, args._match_signature, firstarg, l, Signature(["a"]))
                args = Arguments(space, arglist, w_stararg=starargs)
                l = [None, None, None, None, None, None]
                py.test.raises(ArgErr, args._match_signature, firstarg, l, Signature(["a", "b", "c", "d", "e"]))
                args = Arguments(space, arglist, w_stararg=starargs)
                l = [None, None, None, None, None, None]
                py.test.raises(ArgErr, args._match_signature, firstarg, l, Signature(["a", "b", "c", "d", "e"], "*"))
                l = [None, None, None, None, None]
                args = Arguments(space, arglist, w_stararg=starargs)
                args._match_signature(firstarg, l, Signature(["a", "b", "c", "d", "e"]), defaults_w=[1])
                assert l == [4, 5, 6, 7, 1]
                for j in range(len(values)):
                    l = [None] * (j + 1)
                    args = Arguments(space, arglist, w_stararg=starargs)
                    args._match_signature(firstarg, l, Signature(["a", "b", "c", "d", "e"][:j], "*"))
                    assert l == values[:j] + [tuple(values[j:])]
                l = [None, None, None, None, None]
                args = Arguments(space, arglist, w_stararg=starargs)
                args._match_signature(firstarg, l, Signature(["a", "b", "c", "d"], None, "**"))
                assert l == [4, 5, 6, 7, {}]

    def test_match_kwds(self):
        space = DummySpace()
        for i in range(3):
            kwds = [("c", 3)]
            kwds_w = dict(kwds[:i])
            keywords = kwds_w.keys()
            keywords_w = kwds_w.values()
            w_kwds = dummy_wrapped_dict(kwds[i:])
            if i == 2:
                w_kwds = None
            assert len(keywords) == len(keywords_w)
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c"]), defaults_w=[4])
            assert l == [1, 2, 3]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "b1", "c"]), defaults_w=[4, 5])
            assert l == [1, 2, 4, 3]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c", "d"]), defaults_w=[4, 5])
            assert l == [1, 2, 3, 5]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            py.test.raises(ArgErr, args._match_signature, None, l,
                           Signature(["c", "b", "a", "d"]), defaults_w=[4, 5])
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            py.test.raises(ArgErr, args._match_signature, None, l,
                           Signature(["a", "b", "c1", "d"]), defaults_w=[4, 5])
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None]
            args._match_signature(None, l, Signature(["a", "b"], None, "**"))
            assert l == [1, 2, {space.newtext('c'): 3}]

    def test_match_kwds2(self):
        space = DummySpace()
        kwds = [("c", 3), ('d', 4)]
        for i in range(4):
            kwds_w = dict(kwds[:i])
            keywords = kwds_w.keys()
            keywords_w = kwds_w.values()
            w_kwds = dummy_wrapped_dict(kwds[i:])
            if i == 3:
                w_kwds = None
            args = Arguments(space, [1, 2], keywords, keywords_w, w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c"], None, "**"))
            assert l == [1, 2, 3, {space.newtext('d'): 4}]

    def test_match_kwds_creates_kwdict(self):
        space = DummySpace()
        kwds = [("c", 3), ('d', 4)]
        for i in range(4):
            kwds_w = dict(kwds[:i])
            keywords = kwds_w.keys()
            keywords_w = kwds_w.values()
            w_kwds = dummy_wrapped_dict(kwds[i:])
            if i == 3:
                w_kwds = None
            args = Arguments(space, [1, 2], keywords, keywords_w, w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c"], None, "**"))
            assert l == [1, 2, 3, {space.newtext('d'): 4}]
            assert isinstance(l[-1], kwargsdict)

    def test_duplicate_kwds(self):
        space = DummySpace()
        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], ["a"], [1], w_starstararg={"a": 2}, fnname_parens="foo()")
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "foo() got multiple values for keyword argument 'a'"

    def test_starstararg_wrong_type(self):
        space = DummySpace()
        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], ["a"], [1], w_starstararg="hello", fnname_parens="bar()")
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "bar() argument after ** must be a mapping, not str"

    def test_unwrap_error(self):
        space = DummySpace()
        valuedummy = object()
        with py.test.raises(OperationError) as excinfo:
            Arguments(space, [], ["a"], [1], w_starstararg={None: 1}, fnname_parens="f1()")
        assert excinfo.value.w_type is TypeError
        assert excinfo.value._w_value is None

    def test_blindargs(self):
        space = DummySpace()
        kwds = [("a", 3), ('b', 4)]
        for i in range(4):
            kwds_w = dict(kwds[:i])
            keywords = kwds_w.keys()
            keywords_w = kwds_w.values()
            w_kwds = dict(kwds[i:])
            if i == 3:
                w_kwds = None
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:],
                             w_starstararg=w_kwds)
            l = [None, None, None]
            args._match_signature(None, l, Signature(["a", "b"], None, "**"), blindargs=2)
            assert l == [1, 2, {space.newtext('a'): 3, space.newtext('b'): 4}]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:],
                             w_starstararg=w_kwds)
            l = [None, None, None]
            py.test.raises(ArgErrUnknownKwds, args._match_signature, None, l,
                           Signature(["a", "b"]), blindargs=2)

    def test_args_parsing(self):
        space = DummySpace()
        args = Arguments(space, [])

        calls = []

        def _match_signature(w_firstarg, scope_w, signature,
                             defaults_w=None, w_kw_defs=None, blindargs=0):
            defaults_w = [] if defaults_w is None else defaults_w
            calls.append((w_firstarg, scope_w, signature.argnames, signature.has_vararg(),
                          signature.has_kwarg(), defaults_w, w_kw_defs, blindargs))
        args._match_signature = _match_signature

        scope_w = args.parse_obj(None, "foo", Signature(["a", "b"], None, None))
        assert len(calls) == 1
        assert calls[0] == (None, [None, None], ["a", "b"], False, False,
                            [], None, 0)
        assert calls[0][1] is scope_w
        calls = []

        scope_w = args.parse_obj(None, "foo", Signature(["a", "b"], "args", None),
                                 blindargs=1)
        assert len(calls) == 1
        assert calls[0] == (None, [None, None, None], ["a", "b"], True, False,
                            [], None, 1)
        calls = []

        scope_w = args.parse_obj(None, "foo", Signature(["a", "b"], "args", "kw"),
                             defaults_w=['x', 'y'])
        assert len(calls) == 1
        assert calls[0] == (None, [None, None, None, None], ["a", "b"],
                            True, True,
                            ["x", "y"], None, 0)
        calls = []

        scope_w = args.parse_obj("obj", "foo", Signature(["a", "b"], "args", "kw"),
                             defaults_w=['x', 'y'], blindargs=1)
        assert len(calls) == 1
        assert calls[0] == ("obj", [None, None, None, None], ["a", "b"],
                            True, True,
                            ["x", "y"], None, 1)

        class FakeArgErr(ArgErr):

            def getmsg(self):
                return "msg"

        def _match_signature(*args):
            raise FakeArgErr()
        args._match_signature = _match_signature

        with pytest.raises(OperationError) as excinfo:
            args.parse_obj("obj", "foo",
                           Signature(["a", "b"], None, None))
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "foo() msg"


    def test_args_parsing_into_scope(self):
        space = DummySpace()
        args = Arguments(space, [])

        calls = []

        def _match_signature(w_firstarg, scope_w, signature,
                             defaults_w=None, w_kw_defs=None, blindargs=0):
            defaults_w = [] if defaults_w is None else defaults_w
            calls.append((w_firstarg, scope_w, signature.argnames, signature.has_vararg(),
                          signature.has_kwarg(), defaults_w, w_kw_defs, blindargs))
        args._match_signature = _match_signature

        scope_w = [None, None]
        args.parse_into_scope(None, scope_w, "foo", Signature(["a", "b"], None, None))
        assert len(calls) == 1
        assert calls[0] == (None, scope_w, ["a", "b"], False, False,
                            [], None, 0)
        assert calls[0][1] is scope_w
        calls = []

        scope_w = [None, None, None, None]
        args.parse_into_scope(None, scope_w, "foo", Signature(["a", "b"], "args", "kw"),
                              defaults_w=['x', 'y'])
        assert len(calls) == 1
        assert calls[0] == (None, scope_w, ["a", "b"],
                            True, True,
                            ["x", "y"], None, 0)
        calls = []

        scope_w = [None, None, None, None]
        args.parse_into_scope("obj", scope_w, "foo", Signature(["a", "b"],
                                                      "args", "kw"),
                              defaults_w=['x', 'y'])
        assert len(calls) == 1
        assert calls[0] == ("obj", scope_w, ["a", "b"],
                            True, True,
                            ["x", "y"], None, 0)

        class FakeArgErr(ArgErr):

            def getmsg(self):
                return "msg"

        def _match_signature(*args):
            raise FakeArgErr()
        args._match_signature = _match_signature


        with pytest.raises(OperationError) as excinfo:
            args.parse_into_scope("obj", [None, None], "foo",
                                  Signature(["a", "b"], None, None))
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "foo() msg"

    def test_topacked_frompacked(self):
        space = DummySpace()
        args = Arguments(space, [1], ['a', 'b'], [2, 3])
        w_args, w_kwds = args.topacked()
        assert w_args == (1,)
        assert w_kwds == {space.newtext('a'): 2, space.newtext('b'): 3}
        args1 = Arguments.frompacked(space, w_args, w_kwds)
        assert args.arguments_w == [1]
        assert set(args.keywords) == set(['a', 'b'])
        assert args.keywords_w[args.keywords.index('a')] == 2
        assert args.keywords_w[args.keywords.index('b')] == 3

        args = Arguments(space, [1])
        w_args, w_kwds = args.topacked()
        assert w_args == (1, )
        assert not w_kwds

    def test_starstarargs_special(self):
        class kwargs(object):
            def __init__(self, k, v):
                self.k = k
                self.v = v
        class MyDummySpace(DummySpace):
            def view_as_kwargs(self, kw):
                if isinstance(kw, kwargs):
                    return [W_Uni(n) for n in kw.k], kw.v
                return None, None
        space = MyDummySpace()
        for i in range(3):
            kwds = [("c", 3)]
            kwds_w = dict(kwds[:i])
            keywords = kwds_w.keys()
            keywords_w = kwds_w.values()
            rest = dict(kwds[i:])
            w_kwds = kwargs(rest.keys(), rest.values())
            if i == 2:
                w_kwds = None
            assert len(keywords) == len(keywords_w)
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c"]), defaults_w=[4])
            assert l == [1, 2, 3]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "b1", "c"]), defaults_w=[4, 5])
            assert l == [1, 2, 4, 3]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            args._match_signature(None, l, Signature(["a", "b", "c", "d"]), defaults_w=[4, 5])
            assert l == [1, 2, 3, 5]
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            py.test.raises(ArgErr, args._match_signature, None, l,
                           Signature(["c", "b", "a", "d"]), defaults_w=[4, 5])
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None, None]
            py.test.raises(ArgErr, args._match_signature, None, l,
                           Signature(["a", "b", "c1", "d"]), defaults_w=[4, 5])
            args = Arguments(space, [1, 2], keywords[:], keywords_w[:], w_starstararg=w_kwds)
            l = [None, None, None]
            args._match_signature(None, l, Signature(["a", "b"], None, "**"))
            assert l == [1, 2, {space.newtext('c'): 3}]
        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], ["a"],
                      [1], w_starstararg=kwargs(["a"], [2]))
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "got multiple values for keyword argument 'a'"

        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], ["a"],
                      [1], w_starstararg=kwargs(["a"], [2]), fnname_parens="foo()")
        assert excinfo.value.w_type is TypeError
        assert space.text_w(excinfo.value.get_w_value(space)) == "foo() got multiple values for keyword argument 'a'"

    def test_posonly(self):
        space = DummySpace()
        sig = Signature(["x", "y", "z", "a", "b", "c"], posonlyargcount=3)

        args = Arguments(space, [1, 2, 3, 4, 5, 6])
        l = [None] * 6
        args._match_signature(None, l, sig)
        assert l == [1, 2, 3, 4, 5, 6]

        args = Arguments(space, [1, 2, 3, 4, 5], ["c"], [6])
        l = [None] * 6
        args._match_signature(None, l, sig)
        assert l == [1, 2, 3, 4, 5, 6]


    def test_kwonly_order_of_scope(self):
        space = DummySpace()
        # def __init__(self, *args, obj=None, name=None): ...
        #                           |-> kwonly
        sig = Signature(['self', 'obj', 'name'], 'args', None, 2, 0)

        # __init__("fake_self", *("abc, ))
        args = Arguments(space, ["abc"], [], [])
        scope = args.parse_obj("fake_self", "__init__", sig, None, {"obj": 'None1', "name": 'None2'})
        # *args always go last
        assert scope == ['fake_self', 'None1', 'None2', ('abc', )]

    def test_posonly(self):
        space = DummySpace()
        sig = Signature(["x", "y", "z", "a", "b", "c"], posonlyargcount=3)

        args = Arguments(space, [1, 2, 3, 4, 5, 6])
        l = [None] * 6
        args._match_signature(None, l, sig)
        assert l == [1, 2, 3, 4, 5, 6]

        args = Arguments(space, [1, 2, 3, 4, 5], ["c"], [6])
        l = [None] * 6
        args._match_signature(None, l, sig)
        assert l == [1, 2, 3, 4, 5, 6]

    def test_posonly_kwargs(self):
        space = DummySpace()
        sig = Signature(["x", "y", "z", "a", "b", "c"], kwargname="kwargs", posonlyargcount=3)
        args = Arguments(space, [1, 2, 3, 4, 5, 6], ["x"], [7])
        l = [None] * 7
        args._match_signature(None, l, sig)
        assert l == [1, 2, 3, 4, 5, 6, {space.newtext('x'): 7}]

class TestErrorHandling(object):
    def test_missing_args(self):
        err = ArgErrMissing(['a'], True)
        s = err.getmsg()
        assert s == "missing 1 required positional argument: 'a'"

        err = ArgErrMissing(['a', 'b'], True)
        s = err.getmsg()
        assert s == "missing 2 required positional arguments: 'a' and 'b'"

        err = ArgErrMissing(['a', 'b', 'c'], True)
        s = err.getmsg()
        assert s == "missing 3 required positional arguments: 'a', 'b', and 'c'"

        err = ArgErrMissing(['a'], False)
        s = err.getmsg()
        assert s == "missing 1 required keyword-only argument: 'a'"

    def test_too_many(self):
        sig0 = Signature([], None, None)
        err = ArgErrTooMany(sig0, 0, 1, 0)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 was given"

        err = ArgErrTooMany(sig0, 0, 2, 0)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 2 were given"

        sig1 = Signature(['a'], None, None)
        err = ArgErrTooMany(sig1, 0, 2, 0)
        s = err.getmsg()
        assert s == "takes 1 positional argument but 2 were given"

        sig2 = Signature(['a', 'b'], None, None)
        err = ArgErrTooMany(sig2, 0, 3, 0)
        s = err.getmsg()
        assert s == "takes 2 positional arguments but 3 were given"

        err = ArgErrTooMany(sig2, 1, 3, 0)
        s = err.getmsg()
        assert s == "takes from 1 to 2 positional arguments but 3 were given"

        err = ArgErrTooMany(sig0, 0, 1, 1)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 positional argument (and 1 keyword-only argument) were given"

        err = ArgErrTooMany(sig0, 0, 2, 1)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 2 positional arguments (and 1 keyword-only argument) were given"

        err = ArgErrTooMany(sig0, 0, 1, 2)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 positional argument (and 2 keyword-only arguments) were given"

    def test_too_many_method(self):
        sig0 = Signature([], None, None)
        err = ArgErrTooManyMethod(sig0, 0, 1, 0)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 was given. Did you forget 'self' in the function definition?"

        err = ArgErrTooManyMethod(sig0, 0, 2, 0)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 2 were given"

        sig1 = Signature(['self'], None, None)
        err = ArgErrTooManyMethod(sig1, 0, 2, 0)
        s = err.getmsg()
        assert s == "takes 1 positional argument but 2 were given"

        sig1 = Signature(['a'], None, None)
        err = ArgErrTooManyMethod(sig1, 0, 2, 0)
        s = err.getmsg()
        assert s == "takes 1 positional argument but 2 were given. Did you forget 'self' in the function definition?"

        sig2 = Signature(['a', 'b'], None, None)
        err = ArgErrTooManyMethod(sig2, 0, 3, 0)
        s = err.getmsg()
        assert s == "takes 2 positional arguments but 3 were given. Did you forget 'self' in the function definition?"

        err = ArgErrTooManyMethod(sig2, 1, 3, 0)
        s = err.getmsg()
        assert s == "takes from 1 to 2 positional arguments but 3 were given. Did you forget 'self' in the function definition?"

        err = ArgErrTooManyMethod(sig0, 0, 1, 1)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 positional argument (and 1 keyword-only argument) were given. Did you forget 'self' in the function definition?"

        err = ArgErrTooManyMethod(sig0, 0, 2, 1)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 2 positional arguments (and 1 keyword-only argument) were given"

        err = ArgErrTooManyMethod(sig0, 0, 1, 2)
        s = err.getmsg()
        assert s == "takes 0 positional arguments but 1 positional argument (and 2 keyword-only arguments) were given. Did you forget 'self' in the function definition?"

    def test_bad_type_for_star(self):
        space = self.space
        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], w_stararg=space.wrap(42), fnname_parens="f1()")
        msg = space.text_w(excinfo.value.get_w_value(space))
        assert msg == "f1() argument after * must be an iterable, not int"
        with pytest.raises(OperationError) as excinfo:
            Arguments(space, [], w_starstararg=space.wrap(42), fnname_parens="f2()")
        msg = space.text_w(excinfo.value.get_w_value(space))
        assert msg == "f2() argument after ** must be a mapping, not int"

    def test_dont_count_default_arguments(self):
        space = self.space
        msg = space.unwrap(space.appexec([], """():
            def f1(*, c): pass
            try:
                f1(4)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 0 positional arguments but 1 was given'
        #
        msg = space.unwrap(space.appexec([], """():
            def f1(*, c=8): pass
            try:
                f1(4)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 0 positional arguments but 1 was given'
        #
        msg = space.unwrap(space.appexec([], """():
            def f1(a, b, *, c): pass
            try:
                f1(4, 5, 6)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 2 positional arguments but 3 were given'
        #
        msg = space.unwrap(space.appexec([], """():
            def f1(*, c): pass
            try:
                f1(6, c=7)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 0 positional arguments but 1 positional argument (and 1 keyword-only argument) were given'
        #
        msg = space.unwrap(space.appexec([], """():
            def f1(*, c, d=8, e=9): pass
            try:
                f1(6, 2, c=7, d=8)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 0 positional arguments but 2 positional arguments (and 2 keyword-only arguments) were given'
        #
        msg = space.unwrap(space.appexec([], """():
            def f1(*, c, d=8, e=9, **kwds): pass
            try:
                f1(6, 2, c=7, d=8, morestuff=9)
            except TypeError as e:
                return str(e)
        """))
        assert msg == 'f1() takes 0 positional arguments but 2 positional arguments (and 2 keyword-only arguments) were given'

    def test_unknown_keywords(self):
        space = DummySpace()
        err = ArgErrUnknownKwds(space, 1, [space.newtext('a'), space.newtext('b')], [0])
        s = err.getmsg()
        assert s == "got an unexpected keyword argument 'b'"
        err = ArgErrUnknownKwds(space, 1, [space.newtext('a'), space.newtext('b')], [1])
        s = err.getmsg()
        assert s == "got an unexpected keyword argument 'a'"
        err = ArgErrUnknownKwds(space, 2, [space.newtext('a'), space.newtext('b')], [0])
        s = err.getmsg()
        assert s == "got 2 unexpected keyword arguments"

    def test_multiple_values(self):
        err = ArgErrMultipleValues('bla')
        s = err.getmsg()
        assert s == "got multiple values for argument 'bla'"

    def test_posonly_error(self):
        space = DummySpace()
        sig = Signature(["x", "y", "z"], posonlyargcount=3)

        with pytest.raises(ArgErrPosonlyAsKwds) as info:
            args = Arguments(space, [1, 2, 3, 4, 5], ["x"], [6])
            l = [None] * 6
            args._match_signature(None, l, sig)
        assert info.value.getmsg() == "got a positional-only argument passed as keyword argument: 'x'"

        with pytest.raises(ArgErrPosonlyAsKwds) as info:
            args = Arguments(space, [1, 2, 3, 4, 5], ["x", "z"], [6, 7])
            l = [None] * 6
            args._match_signature(None, l, sig)
        assert info.value.getmsg() == "got some positional-only arguments passed as keyword arguments: 'x, z'"

class AppTestArgument:
    @pytest.mark.pypy_only
    def test_error_message(self):
        exc = raises(TypeError, (lambda a, b=2: 0), b=3)
        assert str(exc.value) == "<lambda>() missing 1 required positional argument: 'a'"
        exc = raises(TypeError, (lambda: 0), b=3)
        assert str(exc.value) == "<lambda>() got an unexpected keyword argument 'b'"
        exc = raises(TypeError, (lambda a, b: 0), 1, 2, 3, a=1)
        assert str(exc.value) == "<lambda>() got multiple values for argument 'a'"
        exc = raises(TypeError, (lambda a, b=1: 0), 1, 2, 3, a=1)
        assert str(exc.value) == "<lambda>() got multiple values for argument 'a'"
        exc = raises(TypeError, (lambda a, **kw: 0), 1, 2, 3)
        assert str(exc.value) == "<lambda>() takes 1 positional argument but 3 were given"
        exc = raises(TypeError, (lambda a, b=1, **kw: 0), 1, 2, 3)
        assert str(exc.value) == "<lambda>() takes from 1 to 2 positional arguments but 3 were given"
        exc = raises(TypeError, (lambda a, b, c=3, **kw: 0), 1)
        assert str(exc.value) == "<lambda>() missing 1 required positional argument: 'b'"
        exc = raises(TypeError, (lambda a, b, **kw: 0), 1)
        assert str(exc.value) == "<lambda>() missing 1 required positional argument: 'b'"
        exc = raises(TypeError, (lambda a, b, c=3, **kw: 0), a=1)
        assert str(exc.value) == "<lambda>() missing 1 required positional argument: 'b'"
        exc = raises(TypeError, (lambda a, b, **kw: 0), a=1)
        assert str(exc.value) == "<lambda>() missing 1 required positional argument: 'b'"
        exc = raises(TypeError, '(lambda *, a: 0)()')
        assert str(exc.value) == "<lambda>() missing 1 required keyword-only argument: 'a'"
        exc = raises(TypeError, '(lambda *, a=1, b: 0)(a=1)')
        assert str(exc.value) == "<lambda>() missing 1 required keyword-only argument: 'b'"
        exc = raises(TypeError, '(lambda *, kw: 0)(1, kw=3)')
        assert str(exc.value) == "<lambda>() takes 0 positional arguments but 1 positional argument (and 1 keyword-only argument) were given"

    @pytest.mark.pypy_only
    def test_error_message_method(self):
        class A(object):
            def f0():
                pass
            def f1(a):
                pass
        exc = raises(TypeError, lambda : A().f0())
        assert exc.value.args[0] == "f0() takes 0 positional arguments but 1 was given. Did you forget 'self' in the function definition?"
        exc = raises(TypeError, lambda : A().f1(1))
        assert exc.value.args[0] == "f1() takes 1 positional argument but 2 were given. Did you forget 'self' in the function definition?"
        def f0():
            pass
        exc = raises(TypeError, f0, 1)
        # does not contain the warning about missing self
        assert exc.value.args[0] == "f0() takes 0 positional arguments but 1 was given"

    def test_error_message_module_function(self):
        import operator # use countOf because it's defined at applevel
        exc = raises(TypeError, lambda : operator.countOf(1, 2, 3))
        # does not contain the warning
        # 'Did you forget 'self' in the function definition?'
        assert 'self' not in str(exc.value)

    @pytest.mark.pypy_only
    def test_error_message_bound_method(self):
        class A(object):
            def f0():
                pass
            def f1(a):
                pass
        m0 = A().f0
        exc = raises(TypeError, lambda : m0())
        assert exc.value.args[0] == "f0() takes 0 positional arguments but 1 was given. Did you forget 'self' in the function definition?"
        m1 = A().f1
        exc = raises(TypeError, lambda : m1(1))
        assert exc.value.args[0] == "f1() takes 1 positional argument but 2 were given. Did you forget 'self' in the function definition?"


    def test_unicode_keywords(self):
        def f(**kwargs):
            assert kwargs["美"] == 42
        f(**{"美" : 42})
        #
        def f(x): pass
        e = raises(TypeError, "f(**{'ü' : 19})")
        assert e.value.args[0] == "f() got an unexpected keyword argument 'ü'"

    def test_starstarargs_dict_subclass(self):
        def f(**kwargs):
            return kwargs
        class DictSubclass(dict):
            def __iter__(self):
                yield 'x'
        # CPython, as an optimization, looks directly into dict internals when
        # passing one via **kwargs.
        x =DictSubclass()
        assert f(**x) == {}
        x['a'] = 1
        assert f(**x) == {'a': 1}

    def test_starstarargs_module_dict(self):
        def f(**kwargs):
            return kwargs
        assert f(**globals()) == globals()

    def test_cpython_issue4806(self):
        def broken():
            raise TypeError("myerror")
        def g(*args):
            pass
        try:
            g(*(broken() for i in range(1)))
        except TypeError as e:
            assert str(e) == "myerror"
        else:
            assert False, "Expected TypeError"

    def test_call_iter_dont_eat_typeerror(self):
        # same as test_cpython_issue4806, not only for generators
        # (only for 3.x, on CPython 2.7 this case still eats the
        # TypeError and replaces it with "argument after * ...")
        class X:
            def __iter__(self):
                raise TypeError("myerror")
        def f():
            pass
        e = raises(TypeError, "f(*42)")
        assert str(e.value).endswith(
            "f() argument after * must be an iterable, not int")
        e = raises(TypeError, "f(*X())")
        assert str(e.value) == "myerror"

    def test_keyword_arg_after_keywords_dict(self):
        """
        def f(x, y):
            return (x, y)
        assert f(**{'x': 5}, y=6) == (5, 6)
        """

    def test_error_message_kwargs(self):
        def f(x, y):
            pass
        e = raises(TypeError, "f(y=2, **{3: 5}, x=6)")
        assert "f() keywords must be strings" in str(e.value)
        e = raises(TypeError, "f(y=2, **{'x': 5}, x=6)")
        # CPython figures out the name here, by peeking around in the stack in
        # BUILD_MAP_UNPACK_WITH_CALL. we don't, too messy
        assert "got multiple values for keyword argument 'x'" in str(e.value)

    def test_dict_subclass_with_weird_getitem(self):
        # issue 2435: bug-to-bug compatibility with cpython. for a subclass of
        # dict, just ignore the __getitem__ and behave like ext_do_call in ceval.c
        # which just uses the underlying dict
        class d(dict):
            def __getitem__(self, key):
                return key

        for key in ["foo", u"foo"]:
            q = d()
            q[key] = "bar"

            def test(**kwargs):
                return kwargs
            assert test(**q) == {"foo": "bar"}

    def test_issue2996_1(self): """
        class Class:
            def method(*args, a_parameter=None, **kwargs):
                pass
        Class().method(**{'a_parameter': 4})
        """

    def test_issue2996_2(self): """
        class Foo:
            def methhh(*args, offset=42):
                return args, offset
        foo = Foo()
        assert foo.methhh(**{}) == ((foo,), 42)
        """
