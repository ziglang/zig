# Naked C++ pointers carry no useful size or layout information, but often
# such information is externnally available. Low level views are arrays with
# a few more methods allowing such information to be set. Afterwards, it is
# simple to pass these views on to e.g. numpy (w/o the need to copy).

from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty, interp_attrproperty_w
from pypy.interpreter.baseobjspace import W_Root

from rpython.rtyper.lltypesystem import rffi
from rpython.rlib.rarithmetic import intmask

from pypy.module._rawffi.interp_array import W_ArrayInstance
from pypy.module._rawffi.interp_rawffi import segfault_exception
from pypy.module._cppyy import capi


class W_LowLevelView(W_ArrayInstance):
    def __init__(self, space, shape, length, address):
        assert address   # if not address, base class will allocate memory
        W_ArrayInstance.__init__(self, space, shape, length, address)

    @unwrap_spec(args_w='args_w')
    def reshape(self, space, args_w):
        # llviews are only created from non-zero addresses, so we only need
        # to adjust length and shape

        nargs = len(args_w)
        if nargs == 0:
            raise oefmt(space.w_TypeError, "reshape expects a tuple argument")

        newshape_w = args_w
        if nargs != 1 or not space.isinstance_w(args_w[0], space.w_tuple) or \
               not space.len_w(args_w[0]) == 1:
            raise oefmt(space.w_TypeError,
                "tuple object of length 1 expected, received %T", args_w[0])

        w_shape = args_w[0]

        # shape in W_ArrayInstance-speak is somewhat different from what
        # e.g. numpy thinks of it: self.shape contains the info (itemcode,
        # size, etc.) of a single entry; length is user-facing shape
        self.length = space.int_w(space.getitem(w_shape, space.newint(0)))


W_LowLevelView.typedef = TypeDef(
    'LowLevelView',
    __repr__    = interp2app(W_LowLevelView.descr_repr),
    __setitem__ = interp2app(W_LowLevelView.descr_setitem),
    __getitem__ = interp2app(W_LowLevelView.descr_getitem),
    __len__     = interp2app(W_LowLevelView.getlength),
    buffer      = GetSetProperty(W_LowLevelView.getbuffer),
    shape       = interp_attrproperty_w('shape', W_LowLevelView),
    free        = interp2app(W_LowLevelView.free),
    byptr       = interp2app(W_LowLevelView.byptr),
    itemaddress = interp2app(W_LowLevelView.descr_itemaddress),
    reshape     = interp2app(W_LowLevelView.reshape),
)
W_LowLevelView.typedef.acceptable_as_base_class = False


class W_ArrayOfInstances(W_Root):
    _attrs_ = ['converter', 'baseaddress', 'clssize', 'length']
    _immutable_fields_ = ['converter', 'baseaddress', 'clssize']

    def __init__(self, space, clsdecl, address, length, dimensions):
        from pypy.module._cppyy import converter
        name = clsdecl.name
        self.clssize = int(intmask(capi.c_size_of_klass(space, clsdecl)))
        if dimensions:
            name = name + '[' + dimensions[0] + ']'
            for num in dimensions:
                self.clssize *= int(num)
        dimensions = ':'.join(dimensions)
        self.converter   = converter.get_converter(space, name, dimensions)
        self.baseaddress = address
        self.length      = length

    @unwrap_spec(idx=int)
    def getitem(self, space, idx):
        if not self.baseaddress:
            raise segfault_exception(space, "accessing elements of freed array")
        if idx >= self.length or idx < 0:
            raise OperationError(space.w_IndexError, space.w_None)
        itemaddress = rffi.cast(rffi.LONG, self.baseaddress)+idx*self.clssize
        return self.converter.from_memory(space, space.w_None, itemaddress)

    def getlength(self, space):
        return space.newint(self.length)

    def setlength(self, space, w_length):
        self.length = space.int_w(w_length)

W_ArrayOfInstances.typedef = TypeDef(
    'ArrayOfInstances',
    __getitem__ = interp2app(W_ArrayOfInstances.getitem),
    __len__     = interp2app(W_ArrayOfInstances.getlength),
    size        = GetSetProperty(W_ArrayOfInstances.getlength, W_ArrayOfInstances.setlength),
)
W_ArrayOfInstances.typedef.acceptable_as_base_class = False
