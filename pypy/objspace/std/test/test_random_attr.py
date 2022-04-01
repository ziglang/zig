import pytest
pytest.skip("This cannot possibly work on pypy3")
import sys
try:
    import __pypy__
except ImportError:
    pass
else:
    pytest.skip("makes no sense under pypy!")
try:
    from hypothesis import given, strategies, settings
except ImportError:
    pytest.skip("requires hypothesis")

base_initargs = strategies.sampled_from([
    ("object", (), False),
    ("type(sys)", ("fake", ), True),
    ("NewBase", (), True),
    ("OldBase", (), False),
    ("object, OldBase", (), False),
    ("type(sys), OldBase", ("fake", ), True),
    ])

attrnames = strategies.sampled_from(["a", "b", "c"])

def make_value_attr(val):
    return val, str(val)

def make_method(val):
    return (lambda self, val=val: val,
            "lambda self: %d" % val)

def make_property(val):
    return (
        property(lambda self: val, lambda self, val: None, lambda self: None),
        "property(lambda self: %d, lambda self, val: None, lambda self: None)" % val)

value_attrs = strategies.builds(make_value_attr, strategies.integers())
methods = strategies.builds(make_method, strategies.integers())
properties = strategies.builds(make_property, strategies.integers())
class_attrs = strategies.one_of(value_attrs, methods, properties)


@strategies.composite
def make_code(draw):
    baseclass, initargs, hasdict = draw(base_initargs)

    code = ["import sys", "class OldBase:pass", "class NewBase(object):pass", "class A(%s):" % baseclass]
    dct = {}
    if draw(strategies.booleans()):
        slots = draw(strategies.lists(attrnames))
        if not hasdict and draw(strategies.booleans()):
            slots.append("__dict__")
        dct["__slots__"] = slots
        code.append("    __slots__ = %s" % (slots, ))
    for name in ["a", "b", "c"]:
        if not draw(strategies.booleans()):
            continue
        dct[name], codeval = draw(class_attrs)
        code.append("    %s = %s" % (name, codeval))
    class OldBase: pass
    class NewBase(object): pass
    evaldct = {'OldBase': OldBase, 'NewBase': NewBase}
    if baseclass == 'OldBase':
        metaclass = type(OldBase)
    else:
        metaclass = type
    cls = metaclass("A", eval(baseclass+',', globals(), evaldct), dct)
    inst = cls(*initargs)
    code.append("    pass")
    code.append("a = A(*%s)" % (initargs, ))
    for attr in draw(strategies.lists(attrnames, min_size=1)):
        op = draw(strategies.sampled_from(["read", "read", "read",
                      "write", "writemeth", "writeclass", "writebase",
                      "del", "delclass"]))
        if op == "read":
            try:
                res = getattr(inst, attr)
            except AttributeError:
                code.append("raises(AttributeError, 'a.%s')" % (attr, ))
            else:
                if callable(res):
                    code.append("assert a.%s() == %s" % (attr, res()))
                else:
                    code.append("assert a.%s == %s" % (attr, res))
        elif op == "write":
            val = draw(strategies.integers())
            try:
                setattr(inst, attr, val)
            except AttributeError:
                code.append("raises(AttributeError, 'a.%s=%s')" % (attr, val))
            else:
                code.append("a.%s = %s" % (attr, val))
        elif op == "writemeth":
            val = draw(strategies.integers())
            try:
                setattr(inst, attr, lambda val=val: val)
            except AttributeError:
                code.append("raises(AttributeError, 'a.%s=0')" % (attr, ))
            else:
                code.append("a.%s = lambda : %s" % (attr, val))
        elif op == "writeclass":
            val, codeval = draw(class_attrs)
            setattr(cls, attr, val)
            code.append("A.%s = %s" % (attr, codeval))
        elif op == "writebase":
            val, codeval = draw(class_attrs)
            setattr(OldBase, attr, val)
            setattr(NewBase, attr, val)
            code.append("OldBase.%s = NewBase.%s = %s" % (attr, attr , codeval))
        elif op == "del":
            try:
                delattr(inst, attr)
            except AttributeError:
                code.append("raises(AttributeError, 'del a.%s')" % (attr, ))
            else:
                code.append("del a.%s" % (attr, ))
        elif op == "delclass":
            try:
                delattr(cls, attr)
            except AttributeError:
                code.append("raises(AttributeError, 'del A.%s')" % (attr, ))
            else:
                code.append("del A.%s" % (attr, ))
    return "\n    ".join(code)


@given(code=make_code())
#@settings(max_examples=5000)
def test_random_attrs(code, space):
    print code
    exec "if 1:\n    " + code
    space.appexec([], "():\n    " + code)
