
""" simple non-constant constant. Ie constant which does not get annotated as constant
"""

from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.flowspace.model import Constant
from rpython.annotator.model import not_const

class NonConstant(object):
    def __init__(self, _constant):
        self.__dict__['constant'] = _constant

    def __getattr__(self, attr):
        return getattr(self.__dict__['constant'], attr)

    def __setattr__(self, attr, value):
        setattr(self.__dict__['constant'], attr, value)

    def __nonzero__(self):
        return bool(self.__dict__['constant'])

    def __eq__(self, other):
        return self.__dict__['constant'] == other

    def __add__(self, other):
        return self.__dict__['constant'] + other

    def __radd__(self, other):
        return other + self.__dict__['constant']

    def __mul__(self, other):
        return self.__dict__['constant'] * other

class EntryNonConstant(ExtRegistryEntry):
    _about_ = NonConstant

    def compute_result_annotation(self, s_arg):
        return not_const(s_arg)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.inputarg(hop.r_result, arg=0)
