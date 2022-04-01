from rpython.annotator import model as annmodel
from rpython.annotator.exception import standardexceptions
from rpython.rtyper.llannotation import SomePtr
from rpython.rtyper.rclass import (
    ll_issubclass, ll_type, ll_cast_to_object, getclassrepr, getinstancerepr)

class UnknownException(Exception):
    pass


class ExceptionData(object):
    """Public information for the code generators to help with exceptions."""

    standardexceptions = standardexceptions

    def __init__(self, rtyper):
        # (NB. rclass identifies 'Exception' and 'object')
        r_type = rtyper.rootclass_repr
        r_instance = getinstancerepr(rtyper, None)
        r_type.setup()
        r_instance.setup()
        self.r_exception_type = r_type
        self.r_exception_value = r_instance
        self.lltype_of_exception_type = r_type.lowleveltype
        self.lltype_of_exception_value = r_instance.lowleveltype
        self.rtyper = rtyper

    def finish(self, rtyper):
        bk = rtyper.annotator.bookkeeper
        for cls in self.standardexceptions:
            classdef = bk.getuniqueclassdef(cls)
            getclassrepr(rtyper, classdef).setup()

    def get_standard_ll_exc_instance(self, rtyper, clsdef):
        r_inst = getinstancerepr(rtyper, clsdef)
        example = r_inst.get_reusable_prebuilt_instance()
        example = ll_cast_to_object(example)
        return example

    def get_standard_ll_exc_instance_by_class(self, exceptionclass):
        if exceptionclass not in self.standardexceptions:
            raise UnknownException(exceptionclass)
        clsdef = self.rtyper.annotator.bookkeeper.getuniqueclassdef(
            exceptionclass)
        return self.get_standard_ll_exc_instance(self.rtyper, clsdef)

    def make_helpers(self, rtyper):
        # create helper functionptrs
        self.fn_exception_match  = self.make_exception_matcher(rtyper)
        self.fn_type_of_exc_inst = self.make_type_of_exc_inst(rtyper)

    def make_exception_matcher(self, rtyper):
        # ll_exception_matcher(real_exception_vtable, match_exception_vtable)
        s_typeptr = SomePtr(self.lltype_of_exception_type)
        helper_fn = rtyper.annotate_helper_fn(ll_issubclass, [s_typeptr, s_typeptr])
        return helper_fn

    def make_type_of_exc_inst(self, rtyper):
        # ll_type_of_exc_inst(exception_instance) -> exception_vtable
        s_excinst = SomePtr(self.lltype_of_exception_value)
        helper_fn = rtyper.annotate_helper_fn(ll_type, [s_excinst])
        return helper_fn
