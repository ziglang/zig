from pypy.objspace.std.test import test_typeobject
from pypy.objspace.std.longobject import W_LongObject
from rpython.rlib.rbigint import rbigint

class TestVersionedType(test_typeobject.TestTypeObject):

    def get_three_classes(self):
        space = self.space
        w_types = space.appexec([], """():
            class A(object):
                def f(self): pass
            class B(A):
                pass
            class X:
                pass
            class Y(object):
                pass
            class C(Y, X):
                pass
            return A, B, C
        """)
        return space.unpackiterable(w_types)

    def test_tag_changes(self):
        space = self.space
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        btag = w_B.version_tag()
        assert atag is not None
        assert btag is not None
        # the following assert is true only in py2 because C is an old-style
        #class
        # assert w_C.version_tag() is None
        assert atag is not btag
        w_types = space.appexec([w_A, w_B], """(A, B):
            B.g = lambda self: None
        """)
        assert w_B.version_tag() is not btag
        assert w_A.version_tag() is atag
        btag = w_B.version_tag()
        w_types = space.appexec([w_A, w_B], """(A, B):
            A.f = lambda self: None
        """)
        assert w_B.version_tag() is not btag
        assert w_A.version_tag() is not atag
        atag = w_A.version_tag()
        btag = w_B.version_tag()
        assert atag is not btag
        w_types = space.appexec([w_A, w_B], """(A, B):
            del A.f
        """)
        assert w_B.version_tag() is not btag
        assert w_A.version_tag() is not atag
        atag = w_A.version_tag()
        btag = w_B.version_tag()
        assert atag is not btag

    def test_tag_changes_when_bases_change(self):
        space = self.space
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        btag = w_B.version_tag()
        w_types = space.appexec([w_A, w_B, w_C], """(A, B, C):
            class D(object):
                pass
            B.__bases__ = (D, )
        """)
        assert w_B.version_tag() is not btag

    def test_tag_changes_only_when_dict_changes(self):
        space = self.space
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        # setting a descriptor does not change the version_tag
        w_types = space.appexec([w_A, w_B, w_C], """(A, B, C):
            A.__name__ = "hello"
        """)

        assert w_A.version_tag() is atag
        # deleting via a descriptor does not change the version_tag
        w_types = space.appexec([w_A, w_B, w_C], """(A, B, C):
            try:
                del A.__name__
            except AttributeError:
                pass
        """)
        assert w_A.version_tag() is atag

        # deleting a non-existing key does not change the version_tag
        w_types = space.appexec([w_A, w_B, w_C], """(A, B, C):
            try:
                del A.abc
            except AttributeError:
                pass
        """)
        assert w_A.version_tag() is atag

    def test_tag_changes_When_module_changes(self):
        space = self.space
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        # setting a descriptor does not change the version_tag
        w_types = space.appexec([w_A, w_B, w_C], """(A, B, C):
            A.__module__ = "hello"
        """)

        assert w_A.version_tag() is not atag



    def test_version_tag_of_builtin_types(self):
        space = self.space
        assert space.w_list.version_tag() is not None
        assert space.w_dict.version_tag() is not None
        assert space.type(space.sys).version_tag() is not None
        assert space.w_type.version_tag() is not None
        w_function = space.appexec([], """():
            def f():
                pass
            return type(f)
        """)
        assert w_function.version_tag() is not None
        assert space.w_Exception.version_tag() is not None

    def test_version_tag_of_subclasses_of_builtin_types(self):
        space = self.space
        w_types = space.appexec([], """():
            import sys
            class LIST(list):
                def f(self): pass
            class DICT(dict):
                pass
            class TYPE(type):
                pass
            class MODULE(type(sys)):
                pass
            class OBJECT(object):
                pass
            return [LIST, DICT, TYPE, MODULE, OBJECT]
        """)
        (w_LIST, w_DICT, w_TYPE, w_MODULE,
                 w_OBJECT) = space.unpackiterable(w_types)
        assert w_LIST.version_tag() is not None
        assert w_DICT.version_tag() is not None
        assert w_TYPE.version_tag() is not None
        assert w_MODULE.version_tag() is not None
        assert w_OBJECT.version_tag() is not None

    def test_version_tag_of_modules(self):
        space = self.space
        w_mod = space.appexec([], """():
            import sys
            return type(sys)
        """)
        atag = w_mod.version_tag()
        btag = w_mod.version_tag()
        assert btag is atag
        assert btag is not None

    def test_version_tag_when_changing_a_lot(self):
        space = self.space
        w_x = space.wrap("x")
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(1))
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 1

        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(2))
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 2

        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(3))
        assert w_A.version_tag() is atag
        assert space.int_w(space.getattr(w_A, w_x)) == 3

        space.setattr(w_A, w_x, space.newint(4))
        assert w_A.version_tag() is atag
        assert space.int_w(space.getattr(w_A, w_x)) == 4

    def test_no_cell_when_writing_same_value(self):
        space = self.space
        w_x = space.wrap("x")
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        w_val = space.newint(1)
        space.setattr(w_A, w_x, w_val)
        space.setattr(w_A, w_x, w_val)
        w_val1 = w_A._getdictvalue_no_unwrapping(space, "x")
        assert w_val1 is w_val

    def test_int_cells(self):
        space = self.space
        w_x = space.wrap("x")
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(1))
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 1

        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(2))
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 2
        cell = w_A._getdictvalue_no_unwrapping(space, "x")
        assert cell.intvalue == 2

        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(3))
        assert w_A.version_tag() is atag
        assert space.int_w(space.getattr(w_A, w_x)) == 3
        assert cell.intvalue == 3

        space.setattr(w_A, w_x, space.newint(4))
        assert w_A.version_tag() is atag
        assert space.int_w(space.getattr(w_A, w_x)) == 4
        assert cell.intvalue == 4

    def test_int_cell_turns_into_cell(self):
        space = self.space
        w_x = space.wrap("x")
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        space.setattr(w_A, w_x, space.newint(1))
        space.setattr(w_A, w_x, space.newint(2))
        space.setattr(w_A, w_x, space.newfloat(2.2))
        cell = w_A._getdictvalue_no_unwrapping(space, "x")
        assert space.float_w(cell.w_value) == 2.2

    def test_integer_strategy_with_w_long(self):
        space = self.space
        w_x = space.wrap("x")
        w_A, w_B, w_C = self.get_three_classes()
        atag = w_A.version_tag()
        w = W_LongObject(rbigint.fromlong(42))
        space.setattr(w_A, w_x, w)
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 42

        atag = w_A.version_tag()
        w = W_LongObject(rbigint.fromlong(43))
        space.setattr(w_A, w_x, w)
        assert w_A.version_tag() is not atag
        assert space.int_w(space.getattr(w_A, w_x)) == 43
        cell = w_A._getdictvalue_no_unwrapping(space, "x")
        assert cell.intvalue == 43

        atag = w_A.version_tag()
        w = W_LongObject(rbigint.fromlong(44))
        space.setattr(w_A, w_x, w)
        assert w_A.version_tag() is atag
        assert space.int_w(space.getattr(w_A, w_x)) == 44
        assert cell.intvalue == 44
