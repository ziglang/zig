
from __future__ import absolute_import

import types
from rpython.annotator.model import (
    SomeBool, SomeInteger, SomeString, SomeFloat, SomeList, SomeDict, s_None,
    SomeObject, SomeInstance, SomeTuple, unionof, SomeUnicodeString, SomeType,
    AnnotatorError)
from rpython.annotator.listdef import ListDef
from rpython.annotator.dictdef import DictDef
from rpython.rtyper import extregistry

_annotation_cache = {}

def _annotation_key(t):
    from rpython.rtyper import extregistry
    if isinstance(t, list):
        assert len(t) == 1
        return ('list', _annotation_key(t[0]))
    elif isinstance(t, dict):
        assert len(t.keys()) == 1
        return ('dict', _annotation_key(t.items()[0]))
    elif isinstance(t, tuple):
        return tuple([_annotation_key(i) for i in t])
    elif extregistry.is_registered(t):
        # XXX do we want to do something in this case?
        return t
    return t

def annotation(t, bookkeeper=None):
    if bookkeeper is None:
        key = _annotation_key(t)
        try:
            return _annotation_cache[key]
        except KeyError:
            t = _compute_annotation(t, bookkeeper)
            _annotation_cache[key] = t
            return t
    return _compute_annotation(t, bookkeeper)


def _validate_annotation_size(t):
    try:
        _ = iter(t)
    except TypeError:  # if it's not an iterable, just return
        return t       # (size does not matter)
    if isinstance(t, tuple):  # we accept tuples with any length, because
        return t              # their in-memory representation is predictable
    if len(t) > 1:
        raise TypeError("Cannot specify multiple types in a %s (try using tuple)", type(t))


def _compute_annotation(t, bookkeeper=None):
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rtyper.llannotation import lltype_to_annotation
    _validate_annotation_size(t)
    if isinstance(t, SomeObject):
        return t
    elif isinstance(t, lltype.LowLevelType):
        return lltype_to_annotation(t)
    elif isinstance(t, list):
        return SomeList(
                ListDef(bookkeeper, annotation(t[0]),
                        mutated=True, resized=True))
    elif isinstance(t, tuple):
        return SomeTuple(tuple([annotation(i) for i in t]))
    elif isinstance(t, dict):
        return SomeDict(
                DictDef(bookkeeper,
                        annotation(t.keys()[0]), annotation(t.values()[0])))
    elif type(t) is types.NoneType:
        return s_None
    elif extregistry.is_registered(t):
        entry = extregistry.lookup(t)
        entry.bookkeeper = bookkeeper
        return entry.compute_result_annotation()
    else:
        return annotationoftype(t, bookkeeper)

def annotationoftype(t, bookkeeper=False):
    from rpython.rtyper import extregistry

    """The most precise SomeValue instance that contains all
    objects of type t."""
    assert isinstance(t, (type, types.ClassType))
    if t is bool:
        return SomeBool()
    elif t is int:
        return SomeInteger()
    elif t is float:
        return SomeFloat()
    elif issubclass(t, str): # py.lib uses annotated str subclasses
        return SomeString()
    elif t is unicode:
        return SomeUnicodeString()
    elif t is types.NoneType:
        return s_None
    elif bookkeeper and extregistry.is_registered_type(t):
        return (extregistry.lookup_type(t)
                .compute_annotation_bk(bookkeeper))
    elif t is type:
        return SomeType()
    elif bookkeeper and not hasattr(t, '_freeze_'):
        return SomeInstance(bookkeeper.getuniqueclassdef(t))
    else:
        raise TypeError("Annotation of type %r not supported" % (t,))

class Sig(object):

    def __init__(self, *argtypes):
        self.argtypes = argtypes

    def __call__(self, funcdesc, inputcells):
        from rpython.rlib.objectmodel import NOT_CONSTANT
        from rpython.rtyper.lltypesystem import lltype
        args_s = []
        from rpython.annotator import model as annmodel
        for i, argtype in enumerate(self.argtypes):
            if isinstance(argtype, (types.FunctionType, types.MethodType)):
                argtype = argtype(*inputcells)
            if argtype is lltype.Void:
                # XXX the mapping between Void and annotation
                # is not quite well defined
                s_input = inputcells[i]
                assert isinstance(s_input, (annmodel.SomePBC, annmodel.SomeNone))
                assert s_input.is_constant()
                args_s.append(s_input)
            elif argtype is None:
                args_s.append(inputcells[i])     # no change
            elif argtype is NOT_CONSTANT:
                from rpython.annotator.model import not_const
                args_s.append(not_const(inputcells[i]))
            else:
                args_s.append(annotation(argtype, bookkeeper=funcdesc.bookkeeper))
        if len(inputcells) != len(args_s):
            raise SignatureError("%r: expected %d args, got %d" % (funcdesc,
                                                              len(args_s),
                                                              len(inputcells)))
        for i, (s_arg, s_input) in enumerate(zip(args_s, inputcells)):
            s_input = unionof(s_input, s_arg)
            if not s_arg.contains(s_input):
                raise SignatureError("%r argument %d:\n"
                                "expected %s,\n"
                                "     got %s" % (funcdesc, i+1,
                                             s_arg,
                                             s_input))
        inputcells[:] = args_s

class SignatureError(AnnotatorError):
    pass

def finish_type(paramtype, bookkeeper, func):
    from rpython.rlib.types import SelfTypeMarker, AnyTypeMarker
    if isinstance(paramtype, SomeObject):
        return paramtype
    elif isinstance(paramtype, SelfTypeMarker):
        raise SignatureError("%r argument declared as annotation.types.self(); class needs decorator rlib.signature.finishsigs()" % (func,))
    elif isinstance(paramtype, AnyTypeMarker):
        return None
    else:
        return paramtype(bookkeeper)

def enforce_signature_args(funcdesc, paramtypes, actualtypes):
    assert len(paramtypes) == len(actualtypes)
    params_s = [finish_type(paramtype, funcdesc.bookkeeper, funcdesc.pyobj) for paramtype in paramtypes]
    for i, (s_param, s_actual) in enumerate(zip(params_s, actualtypes)):
        if s_param is None: # can be anything
            continue
        if not s_param.contains(s_actual):
            raise SignatureError("%r argument %d:\n"
                            "expected %s,\n"
                            "     got %s" % (funcdesc, i+1, s_param, s_actual))
    for i, s_param in enumerate(params_s):
        if s_param is None:
            continue
        actualtypes[i] = s_param

def enforce_signature_return(funcdesc, sigtype, inferredtype):
    s_sigret = finish_type(sigtype, funcdesc.bookkeeper, funcdesc.pyobj)
    if s_sigret is not None and not s_sigret.contains(inferredtype):
        raise SignatureError("%r return value:\n"
                        "expected %s,\n"
                        "     got %s" % (funcdesc, s_sigret, inferredtype))
    return s_sigret
