# -*- coding: utf-8 -*-
import py
from rpython.annotator.argument import ArgumentsForTranslation, rawshape
from rpython.flowspace.argument import Signature, CallSpec

class MockArgs(ArgumentsForTranslation):
    def newtuple(self, items):
        return tuple(items)

    def unpackiterable(self, it):
        return list(it)


class TestArgumentsForTranslation(object):

    def test_prepend(self):
        args = MockArgs(["0"])
        args1 = args.prepend("thingy")
        assert args1 is not args
        assert args1.arguments_w == ["thingy", "0"]
        assert args1.keywords == args.keywords

    def test_fixedunpacked(self):
        args = MockArgs([], {"k": 1})
        py.test.raises(ValueError, args.fixedunpack, 1)

        args = MockArgs(["a", "b"])
        py.test.raises(ValueError, args.fixedunpack, 0)
        py.test.raises(ValueError, args.fixedunpack, 1)
        py.test.raises(ValueError, args.fixedunpack, 3)
        py.test.raises(ValueError, args.fixedunpack, 4)

        assert args.fixedunpack(2) == ['a', 'b']

    def test_unmatch_signature(self):
        args = MockArgs([1, 2, 3])
        sig = Signature(['a', 'b', 'c'], None, None)
        data = args.match_signature(sig, [])
        new_args = args.unmatch_signature(sig, data)
        assert args.unpack() == new_args.unpack()

        args = MockArgs([1])
        sig = Signature(['a', 'b', 'c'], None, None)
        data = args.match_signature(sig, [2, 3])
        new_args = args.unmatch_signature(sig, data)
        assert args.unpack() == new_args.unpack()

        args = MockArgs([1, 2, 3, 4, 5])
        sig = Signature(['a', 'b', 'c'], 'r', None)
        data = args.match_signature(sig, [])
        new_args = args.unmatch_signature(sig, data)
        assert args.unpack() == new_args.unpack()

        args = MockArgs([1], {'c': 3, 'b': 2})
        sig = Signature(['a', 'b', 'c'], None, None)
        data = args.match_signature(sig, [])
        new_args = args.unmatch_signature(sig, data)
        assert args.unpack() == new_args.unpack()

        args = MockArgs([1], {'c': 5})
        sig = Signature(['a', 'b', 'c'], None, None)
        data = args.match_signature(sig, [2, 3])
        new_args = args.unmatch_signature(sig, data)
        assert args.unpack() == new_args.unpack()

    def test_rawshape(self):
        args = MockArgs([1, 2, 3])
        assert rawshape(args) == (3, (), False)

        args = MockArgs([1, 2, 3, 4, 5])
        assert rawshape(args) == (5, (), False)

        args = MockArgs([1], {'c': 3, 'b': 2})
        assert rawshape(args) == (1, ('b', 'c'), False)

        args = MockArgs([1], {'c': 5})
        assert rawshape(args) == (1, ('c', ), False)

        args = MockArgs([1], {'c': 5, 'd': 7})
        assert rawshape(args) == (1, ('c', 'd'), False)

        args = MockArgs([1, 2, 3, 4, 5], {'e': 5, 'd': 7})
        assert rawshape(args) == (5, ('d', 'e'), False)

    def test_stararg_flowspace_variable(self):
        var = object()
        shape = ((2, ('g', ), True), [1, 2, 9, var])
        args = MockArgs([1, 2], {'g': 9}, w_stararg=var)
        assert args.flatten() == shape

        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

    def test_fromshape(self):
        shape = ((3, (), False), [1, 2, 3])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((1, (), False), [1])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((5, (), False), [1, 2, 3, 4, 5])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((1, ('b', 'c'), False), [1, 2, 3])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((1, ('c', ), False), [1, 5])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((1, ('c', 'd'), False), [1, 5, 7])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape

        shape = ((5, ('d', 'e'), False), [1, 2, 3, 4, 5, 7, 5])
        args = MockArgs.fromshape(*shape)
        assert args.flatten() == shape
