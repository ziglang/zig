# this is some common infrastructure for code that needs to walk all virtuals
# at a specific instruction. It is used by resume and unroll.

class VirtualVisitor(object):
    def visit_not_virtual(self, value):
        raise NotImplementedError("abstract base class")

    def visit_virtual(self, descr, fielddescrs):
        raise NotImplementedError("abstract base class")

    def visit_vstruct(self, typedescr, fielddescrs):
        raise NotImplementedError("abstract base class")

    def visit_varray(self, arraydescr):
        raise NotImplementedError("abstract base class")

    def visit_varraystruct(self, arraydescr, fielddescrs):
        raise NotImplementedError("abstract base class")

    def visit_vrawbuffer(self, func, size, offsets, descrs):
        raise NotImplementedError("abstract base class")

    def visit_vrawslice(self, offset):
        raise NotImplementedError("abstract base class")

    def visit_vstrplain(self, is_unicode=False):
        raise NotImplementedError("abstract base class")

    def visit_vstrconcat(self, is_unicode=False):
        raise NotImplementedError("abstract base class")

    def visit_vstrslice(self, is_unicode=False):
        raise NotImplementedError("abstract base class")

    def register_virtual_fields(self, virtualbox, fieldboxes):
        raise NotImplementedError("abstract base class")

    def already_seen_virtual(self, virtualbox):
        raise NotImplementedError("abstract base class")
