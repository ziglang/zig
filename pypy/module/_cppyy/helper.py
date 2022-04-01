import sys
from rpython.rlib import rstring


#- type name manipulations --------------------------------------------------
def remove_const(name):
    tmplt_start = name.find("<")
    tmplt_stop  = name.rfind(">")
    if 0 <= tmplt_start and 0 <= tmplt_stop:
        # only replace const qualifying the class name, not in the template parameters
        return "".join([x.strip(" ") for x in rstring.split(name[:tmplt_start], "const")])+\
                     name[tmplt_start:tmplt_stop]+\
                     "".join([x.strip(" ") for x in rstring.split(name[tmplt_stop:], "const")])
    else:
        return "".join([x.strip(" ") for x in rstring.split(name, "const")])

def compound(name):
    name = remove_const(name)
    if name.endswith("]"):                       # array type?
        return "[]"
    i = _find_qualifier_index(name)
    return "".join(name[i:].split(" "))

def array_size(name):
    name = remove_const(name)
    if name.endswith("]"):                       # array type?
        idx = name.rfind("[")
        if 0 < idx:
            end = len(name)-1                    # len rather than -1 for rpython
            if 0 < end and (idx+1) < end:        # guarantee non-neg for rpython
                return int(name[idx+1:end])
    return -1

def _find_qualifier_index(name):
    i = len(name)
    # search from the back; note len(name) > 0 (so rtyper can use uint)
    for i in range(len(name) - 1, 0, -1):
        c = name[i]
        if c.isalnum() or c in ['_', '>', ']', ')']:
            break
    return i + 1

def clean_type(name):
    # can't strip const early b/c name could be a template ...
    i = _find_qualifier_index(name)
    name = name[:i].strip(" ")

    idx = -1
    if name.endswith("]"):                       # array type?
        idx = name.rfind("[")
        if 0 < idx:
            name = name[:idx]
    elif name.endswith(">"):                     # template type?
        idx = name.find("<")
        if 0 < idx:      # always true, but just so that the translater knows
            n1 = remove_const(name[:idx])
            name = "".join([n1, name[idx:]])
    else:
        name = remove_const(name)
        name = name[:_find_qualifier_index(name)]
    return name.strip(' ')


#- operator mappings --------------------------------------------------------
_operator_mappings = {}

def map_operator_name(space, cppname, nargs, result_type):
    from pypy.module._cppyy import capi

    if cppname[0:8] == "operator":
        op = cppname[8:].strip(' ')

        # look for known mapping
        try:
            return _operator_mappings[op]
        except KeyError:
            pass

        # return-type dependent mapping
        if op == "[]":
            if result_type.find("const") != 0:
                cpd = compound(result_type)
                if cpd and cpd[len(cpd)-1] == "&":
                    return "__setitem__"
            return "__getitem__"

        # a couple more cases that depend on whether args were given

        if op == "*":   # dereference (not python) vs. multiplication
            return nargs and "__mul__" or "__deref__"

        if op == "+":   # unary positive vs. binary addition
            return nargs and  "__add__" or "__pos__"

        if op == "-":   # unary negative vs. binary subtraction
            return nargs and "__sub__" or "__neg__"

        if op == "++":  # prefix v.s. postfix increment (not python)
            return nargs and "__postinc__" or "__preinc__"

        if op == "--":  # prefix v.s. postfix decrement (not python)
            return nargs and "__postdec__" or "__predec__"

        # operator could have been a conversion using a typedef (this lookup
        # is put at the end only as it is unlikely and may trigger unwanted
        # errors in class loaders in the backend, because a typical operator
        # name is illegal as a class name)
        true_op = capi.c_resolve_name(space, op)

        try:
            return _operator_mappings[true_op]
        except KeyError:
            pass

    # might get here, as not all operator methods handled (although some with
    # no python equivalent, such as new, delete, etc., are simply retained)
    # TODO: perhaps absorb or "pythonify" these operators?
    return cppname

CPPYY__div__  = "__div__"
CPPYY__idiv__ = "__idiv__"
CPPYY__long__ = "__long__"
CPPYY__bool__ = "__nonzero__"

# _operator_mappings["[]"]  = "__setitem__"      # depends on return type
# _operator_mappings["+"]   = "__add__"          # depends on # of args (see __pos__)
# _operator_mappings["-"]   = "__sub__"          # id. (eq. __neg__)
# _operator_mappings["*"]   = "__mul__"          # double meaning in C++

# _operator_mappings["[]"]  = "__getitem__"      # depends on return type
_operator_mappings["()"]  = "__call__"
_operator_mappings["/"]   = CPPYY__div__
_operator_mappings["%"]   = "__mod__"
_operator_mappings["**"]  = "__pow__"            # not C++
_operator_mappings["<<"]  = "__lshift__"
_operator_mappings[">>"]  = "__rshift__"
_operator_mappings["&"]   = "__and__"
_operator_mappings["|"]   = "__or__"
_operator_mappings["^"]   = "__xor__"
_operator_mappings["~"]   = "__inv__"
_operator_mappings["!"]   = "__nonzero__"
_operator_mappings["+="]  = "__iadd__"
_operator_mappings["-="]  = "__isub__"
_operator_mappings["*="]  = "__imul__"
_operator_mappings["/="]  = CPPYY__idiv__
_operator_mappings["%="]  = "__imod__"
_operator_mappings["**="] = "__ipow__"
_operator_mappings["<<="] = "__ilshift__"
_operator_mappings[">>="] = "__irshift__"
_operator_mappings["&="]  = "__iand__"
_operator_mappings["|="]  = "__ior__"
_operator_mappings["^="]  = "__ixor__"
_operator_mappings["=="]  = "__eq__"
_operator_mappings["!="]  = "__ne__"
_operator_mappings[">"]   = "__gt__"
_operator_mappings["<"]   = "__lt__"
_operator_mappings[">="]  = "__ge__"
_operator_mappings["<="]  = "__le__"

# the following type mappings are "exact"
_operator_mappings["const char*"] = "__str__"
_operator_mappings["int"]         = "__int__"
_operator_mappings["long"]        = CPPYY__long__
_operator_mappings["double"]      = "__float__"

# the following type mappings are "okay"; the assumption is that they
# are not mixed up with the ones above or between themselves (and if
# they are, that it is done consistently)
_operator_mappings["char*"]              = "__str__"
_operator_mappings["short"]              = "__int__"
_operator_mappings["unsigned short"]     = "__int__"
_operator_mappings["unsigned int"]       = CPPYY__long__
_operator_mappings["unsigned long"]      = CPPYY__long__
_operator_mappings["long long"]          = CPPYY__long__
_operator_mappings["unsigned long long"] = CPPYY__long__
_operator_mappings["float"]              = "__float__"

_operator_mappings["bool"] = CPPYY__bool__

# the following are not python, but useful to expose
_operator_mappings["->"]  = "__follow__"
_operator_mappings["="]   = "__assign__"

# a bundle of operators that have no equivalent and are left "as-is" for now:
_operator_mappings["&&"]       = "&&"
_operator_mappings["||"]       = "||"
_operator_mappings["new"]      = "new"
_operator_mappings["delete"]   = "delete"
_operator_mappings["new[]"]    = "new[]"
_operator_mappings["delete[]"] = "delete[]"
