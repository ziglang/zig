from rpython.flowspace.model import Constant
from rpython.flowspace.operation import op
from rpython.annotator import model as annmodel
from rpython.tool.pairtype import pairtype
from rpython.annotator.bookkeeper import getbookkeeper
from rpython.rlib.objectmodel import specialize
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.annlowlevel import cachedtype
from rpython.rtyper.error import TyperError


class ControllerEntry(ExtRegistryEntry):

    def compute_result_annotation(self, *args_s, **kwds_s):
        controller = self.getcontroller(*args_s, **kwds_s)
        if kwds_s:
            raise TypeError("cannot handle keyword arguments in %s" % (
                self.new,))
        s_real_obj = delegate(controller.new, *args_s)
        if s_real_obj == annmodel.s_ImpossibleValue:
            return annmodel.s_ImpossibleValue
        else:
            return SomeControlledInstance(s_real_obj, controller)

    def getcontroller(self, *args_s, **kwds_s):
        return self._controller_()

    def specialize_call(self, hop, **kwds_i):
        if hop.s_result == annmodel.s_ImpossibleValue:
            raise TyperError("object creation always raises: %s" % (
                hop.spaceop,))
        assert not kwds_i
        controller = hop.s_result.controller
        return rtypedelegate(controller.new, hop, revealargs=[],
            revealresult=True)


def controlled_instance_box(controller, obj):
    XXX  # only for special-casing by ExtRegistryEntry below

def controlled_instance_unbox(controller, obj):
    XXX  # only for special-casing by ExtRegistryEntry below

def controlled_instance_is_box(controller, obj):
    XXX  # only for special-casing by ExtRegistryEntry below


class ControllerEntryForPrebuilt(ExtRegistryEntry):

    def compute_annotation(self):
        controller = self.getcontroller()
        real_obj = controller.convert(self.instance)
        s_real_obj = self.bookkeeper.immutablevalue(real_obj)
        return SomeControlledInstance(s_real_obj, controller)

    def getcontroller(self):
        return self._controller_()


class Controller(object):
    __metaclass__ = cachedtype
    can_be_None = False

    def _freeze_(self):
        return True

    @specialize.arg(0)
    def box(self, obj):
        return controlled_instance_box(self, obj)

    @specialize.arg(0)
    def unbox(self, obj):
        return controlled_instance_unbox(self, obj)

    @specialize.arg(0)
    def is_box(self, obj):
        return controlled_instance_is_box(self, obj)

    @specialize.arg(0, 2)
    def getattr(self, obj, attr):
        return getattr(self, 'get_' + attr)(obj)

    @specialize.arg(0, 2)
    def setattr(self, obj, attr, value):
        return getattr(self, 'set_' + attr)(obj, value)


def delegate(boundmethod, *args_s):
    bk = getbookkeeper()
    s_meth = bk.immutablevalue(boundmethod)
    return bk.emulate_pbc_call(bk.position_key, s_meth, args_s,
                               callback = bk.position_key)

class BoxEntry(ExtRegistryEntry):
    _about_ = controlled_instance_box

    def compute_result_annotation(self, s_controller, s_real_obj):
        if s_real_obj == annmodel.s_ImpossibleValue:
            return annmodel.s_ImpossibleValue
        else:
            assert s_controller.is_constant()
            controller = s_controller.const
            return SomeControlledInstance(s_real_obj, controller=controller)

    def specialize_call(self, hop):
        if not isinstance(hop.r_result, ControlledInstanceRepr):
            raise TyperError("box() should return ControlledInstanceRepr,\n"
                             "got %r" % (hop.r_result,))
        hop.exception_cannot_occur()
        return hop.inputarg(hop.r_result.r_real_obj, arg=1)

class UnboxEntry(ExtRegistryEntry):
    _about_ = controlled_instance_unbox

    def compute_result_annotation(self, s_controller, s_obj):
        if s_obj == annmodel.s_ImpossibleValue:
            return annmodel.s_ImpossibleValue
        else:
            assert isinstance(s_obj, SomeControlledInstance)
            return s_obj.s_real_obj

    def specialize_call(self, hop):
        if not isinstance(hop.args_r[1], ControlledInstanceRepr):
            raise TyperError("unbox() should take a ControlledInstanceRepr,\n"
                             "got %r" % (hop.args_r[1],))
        hop.exception_cannot_occur()
        v = hop.inputarg(hop.args_r[1], arg=1)
        return hop.llops.convertvar(v, hop.args_r[1].r_real_obj, hop.r_result)

class IsBoxEntry(ExtRegistryEntry):
    _about_ = controlled_instance_is_box

    def compute_result_annotation(self, s_controller, s_obj):
        if s_obj == annmodel.s_ImpossibleValue:
            return annmodel.s_ImpossibleValue
        else:
            assert s_controller.is_constant()
            controller = s_controller.const
            result = (isinstance(s_obj, SomeControlledInstance) and
                      s_obj.controller == controller)
            return self.bookkeeper.immutablevalue(result)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        assert hop.s_result.is_constant()
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Bool, hop.s_result.const)

# ____________________________________________________________

class SomeControlledInstance(annmodel.SomeObject):

    def __init__(self, s_real_obj, controller):
        self.s_real_obj = s_real_obj
        self.controller = controller
        self.knowntype = controller.knowntype

    def can_be_none(self):
        return self.controller.can_be_None

    def noneify(self):
        return SomeControlledInstance(self.s_real_obj, self.controller)

    def rtyper_makerepr(self, rtyper):
        return ControlledInstanceRepr(rtyper, self.s_real_obj, self.controller)

    def rtyper_makekey(self):
        real_key = self.s_real_obj.rtyper_makekey()
        return self.__class__, real_key, self.controller

    def getattr(self, s_attr):
        assert s_attr.is_constant()
        ctrl = self.controller
        return delegate(ctrl.getattr, self.s_real_obj, s_attr)

    def setattr(self, s_attr, s_value):
        assert s_attr.is_constant()
        ctrl = self.controller
        return delegate(ctrl.setattr, self.s_real_obj, s_attr, s_value)

    def bool(self):
        ctrl = self.controller
        return delegate(ctrl.bool, self.s_real_obj)

    def simple_call(self, *args_s):
        return delegate(self.controller.call, self.s_real_obj, *args_s)


class __extend__(pairtype(SomeControlledInstance, annmodel.SomeObject)):

    def getitem((s_cin, s_key)):
        return delegate(s_cin.controller.getitem, s_cin.s_real_obj, s_key)

    def setitem((s_cin, s_key), s_value):
        delegate(s_cin.controller.setitem, s_cin.s_real_obj, s_key, s_value)

    def delitem((s_cin, s_key)):
        delegate(s_cin.controller.delitem, s_cin.s_real_obj, s_key)


class __extend__(pairtype(SomeControlledInstance, SomeControlledInstance)):

    def union((s_cin1, s_cin2)):
        if s_cin1.controller is not s_cin2.controller:
            raise annmodel.UnionError("different controller!")
        return SomeControlledInstance(annmodel.unionof(s_cin1.s_real_obj,
                                                       s_cin2.s_real_obj),
                                      s_cin1.controller)

class ControlledInstanceRepr(Repr):

    def __init__(self, rtyper, s_real_obj, controller):
        self.rtyper = rtyper
        self.s_real_obj = s_real_obj
        self.r_real_obj = rtyper.getrepr(s_real_obj)
        self.controller = controller
        self.lowleveltype = self.r_real_obj.lowleveltype

    def convert_const(self, value):
        real_value = self.controller.convert(value)
        return self.r_real_obj.convert_const(real_value)

    def reveal(self, r):
        if r is not self:
            raise TyperError("expected %r, got %r" % (self, r))
        return self.s_real_obj, self.r_real_obj

    def rtype_getattr(self, hop):
        return rtypedelegate(self.controller.getattr, hop)

    def rtype_setattr(self, hop):
        return rtypedelegate(self.controller.setattr, hop)

    def rtype_bool(self, hop):
        return rtypedelegate(self.controller.bool, hop)

    def rtype_simple_call(self, hop):
        return rtypedelegate(self.controller.call, hop)


class __extend__(pairtype(ControlledInstanceRepr, Repr)):

    def rtype_getitem((r_controlled, r_key), hop):
        return rtypedelegate(r_controlled.controller.getitem, hop)

    def rtype_setitem((r_controlled, r_key), hop):
        return rtypedelegate(r_controlled.controller.setitem, hop)

    def rtype_delitem((r_controlled, r_key), hop):
        return rtypedelegate(r_controlled.controller.delitem, hop)


def rtypedelegate(callable, hop, revealargs=[0], revealresult=False):
    bk = hop.rtyper.annotator.bookkeeper
    c_meth = Constant(callable)
    s_meth = bk.immutablevalue(callable)
    hop2 = hop.copy()
    for index in revealargs:
        r_controlled = hop2.args_r[index]
        if not isinstance(r_controlled, ControlledInstanceRepr):
            raise TyperError("args_r[%d] = %r, expected ControlledInstanceRepr"
                             % (index, r_controlled))
        s_new, r_new = r_controlled.s_real_obj, r_controlled.r_real_obj
        hop2.args_s[index], hop2.args_r[index] = s_new, r_new
        v = hop2.args_v[index]
        if isinstance(v, Constant):
            real_value = r_controlled.controller.convert(v.value)
            hop2.args_v[index] = Constant(real_value)
    if revealresult:
        r_controlled = hop2.r_result
        if not isinstance(r_controlled, ControlledInstanceRepr):
            raise TyperError("r_result = %r, expected ControlledInstanceRepr"
                             % (r_controlled,))
        s_new, r_new = r_controlled.s_real_obj, r_controlled.r_real_obj
        hop2.s_result, hop2.r_result = s_new, r_new
    hop2.v_s_insertfirstarg(c_meth, s_meth)
    spaceop = op.simple_call(*hop2.args_v)
    spaceop.result = hop2.spaceop.result
    hop2.spaceop = spaceop
    return hop2.dispatch()
