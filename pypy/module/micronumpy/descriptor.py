import string
from pypy.interpreter.argument import Arguments
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import (TypeDef, GetSetProperty,
                                      interp_attrproperty, interp_attrproperty_w)
from rpython.annotator.model import SomeChar
from rpython.rlib import jit
from rpython.rlib.objectmodel import (
        specialize, we_are_translated, enforceargs)
from rpython.rlib.rarithmetic import r_longlong, r_ulonglong, ovfcheck
from pypy.module.micronumpy import types, boxes, support, constants as NPY
from .base import W_NDimArray
from pypy.module.micronumpy.appbridge import get_appbridge_cache
from pypy.module.micronumpy.converters import byteorder_converter
from pypy.module.micronumpy.hashdescr import _array_descr_walk


def decode_w_dtype(space, w_dtype):
    if space.is_none(w_dtype):
        return None
    if isinstance(w_dtype, W_Dtype):
        return w_dtype
    return space.interp_w(
        W_Dtype, space.call_function(space.gettypefor(W_Dtype), w_dtype))

@jit.unroll_safe
def dtype_agreement(space, w_arr_list, shape, out=None):
    """ agree on dtype from a list of arrays. if out is allocated,
    use it's dtype, otherwise allocate a new one with agreed dtype
    """
    from .casting import find_result_type

    if not space.is_none(out):
        return out
    arr_w = [w_arr for w_arr in w_arr_list if not space.is_none(w_arr)]
    dtype = find_result_type(space, arr_w, [])
    assert dtype is not None
    out = W_NDimArray.from_shape(space, shape, dtype)
    return out

def byteorder_w(space, w_str):
    order = space.text_w(w_str)
    if len(order) != 1:
        raise oefmt(space.w_ValueError,
                "endian is not 1-char string in Numpy dtype unpickling")
    endian = order[0]
    if endian not in (NPY.LITTLE, NPY.BIG, NPY.NATIVE, NPY.IGNORE):
        raise oefmt(space.w_ValueError, "Invalid byteorder %s", endian)
    return endian



class W_Dtype(W_Root):
    _immutable_fields_ = [
        "itemtype?", "w_box_type", "byteorder?", "names?", "fields?",
        "elsize?", "alignment?", "shape?", "subdtype?", "base?", "flags?"]

    @enforceargs(byteorder=SomeChar())
    def __init__(self, itemtype, w_box_type, byteorder=NPY.NATIVE, names=[],
                 fields={}, elsize=-1, shape=[], subdtype=None):
        self.itemtype = itemtype
        self.w_box_type = w_box_type
        if itemtype.get_element_size() == 1 or isinstance(itemtype, types.ObjectType):
            byteorder = NPY.IGNORE
        self.byteorder = byteorder
        self.names = names
        self.fields = fields
        if elsize < 0:
            elsize = itemtype.get_element_size()
        self.elsize = elsize
        self.shape = shape
        self.subdtype = subdtype
        self.flags = 0
        self.metadata = None
        if isinstance(itemtype, types.ObjectType):
            self.flags = NPY.OBJECT_DTYPE_FLAGS
        if not subdtype:
            self.base = self
            self.alignment = itemtype.get_element_size()
        else:
            self.base = subdtype.base
            self.alignment = subdtype.itemtype.get_element_size()

    @property
    def num(self):
        return self.itemtype.num

    @property
    def kind(self):
        return self.itemtype.kind

    @property
    def char(self):
        return self.itemtype.char

    def __repr__(self):
        if self.fields:
            return '<DType %r>' % self.fields
        return '<DType %r>' % self.itemtype

    @specialize.argtype(1)
    def box(self, value):
        if self.is_record():
            raise oefmt(self.itemtype.space.w_NotImplementedError,
                "cannot box a value into a 'record' dtype, this is a bug please report it")
        return self.itemtype.box(value)

    @specialize.argtype(1, 2)
    def box_complex(self, real, imag):
        return self.itemtype.box_complex(real, imag)

    def coerce(self, space, w_item):
        return self.itemtype.coerce(space, self, w_item)

    def is_bool(self):
        return self.kind == NPY.GENBOOLLTR

    def is_signed(self):
        return self.kind == NPY.SIGNEDLTR

    def is_unsigned(self):
        return self.kind == NPY.UNSIGNEDLTR

    def is_int(self):
        return (self.kind == NPY.SIGNEDLTR or self.kind == NPY.UNSIGNEDLTR or
                self.kind == NPY.GENBOOLLTR)

    def is_float(self):
        return self.kind == NPY.FLOATINGLTR

    def is_complex(self):
        return self.kind == NPY.COMPLEXLTR

    def is_number(self):
        return self.is_int() or self.is_float() or self.is_complex()

    def is_str(self):
        return self.num == NPY.STRING

    def is_unicode(self):
        return self.num == NPY.UNICODE

    def is_object(self):
        return self.num == NPY.OBJECT

    def is_str_or_unicode(self):
        return self.num == NPY.STRING or self.num == NPY.UNICODE

    def is_flexible(self):
        return self.is_str_or_unicode() or self.num == NPY.VOID

    def is_record(self):
        return bool(self.fields)

    def is_native(self):
        # Use ord() to ensure that self.byteorder is a char and JITs properly
        return ord(self.byteorder) in (ord(NPY.NATIVE), ord(NPY.NATBYTE))

    def as_signed(self, space):
        """Convert from an unsigned integer dtype to its signed partner"""
        if self.is_unsigned():
            return num2dtype(space, self.num - 1)
        else:
            return self

    def as_unsigned(self, space):
        """Convert from a signed integer dtype to its unsigned partner"""
        if self.is_signed():
            return num2dtype(space, self.num + 1)
        else:
            return self

    def get_float_dtype(self, space):
        assert self.is_complex()
        dtype = get_dtype_cache(space).component_dtypes[self.num]
        if self.byteorder == NPY.OPPBYTE:
            dtype = dtype.descr_newbyteorder(space)
        assert dtype.is_float()
        return dtype

    def getformat(self, stringbuilder):
        # adapted from _buffer_format_string in multiarray/buffer.c
        # byte-order not supported yet
        if self.is_record():
            #subs = sorted(self.fields.items(), key=lambda (k,v): v[0])
            subs = []
            for name in self.fields:
                offset, dtyp = self.fields[name]
                i = 0
                for i in range(len(subs)):
                    if offset < subs[i][0]:
                        break
                else:
                    i = len(subs)
                subs.insert(i, (offset, dtyp, name))
            start = 0
            stringbuilder.append('T{')
            for s in subs:
                stringbuilder.append('x' * (s[0] - start))
                start = s[0] + s[1].elsize
                s[1].getformat(stringbuilder)
                stringbuilder.append(':')
                stringbuilder.append(s[2])
                stringbuilder.append(':')
            stringbuilder.append('}')
        else:
            if self.byteorder == NPY.OPPBYTE:
                raise oefmt(self.itemtype.space.w_NotImplementedError,
                                 "non-native byte order not supported yet")
            # even if not, NumPy adds a '=', '@', for 'i' types
            stringbuilder.append(self.char)

    def get_name(self):
        name = self.w_box_type.getname(self.itemtype.space)
        if name.endswith('_'):
            name = name[:-1]
        return name

    def descr_get_name(self, space, quote=False):
        if quote:
            name = "'" + self.get_name() + "'"
        else:
            name = self.get_name()
        if self.is_flexible() and self.elsize != 0:
            return space.newtext(name + str(self.elsize * 8))
        return space.newtext(name)

    def descr_get_str(self, space, ignore='|', simple=True):
        if not simple and self.fields and len(self.fields) > 0:
            return self.descr_get_descr(space)
        total = 0
        for s in self.shape:
            total += s
        if not simple and total > 0:
            return space.newtuple(
                [space.newtext(self.subdtype.get_str(ignore='')), 
                 space.newtuple([space.newint(s) for s in self.shape]),
                ])
        return space.newtext(self.get_str(ignore=ignore))

    def get_str(self, ignore='|'):
        basic = self.kind
        endian = self.byteorder
        size = self.elsize
        if endian == NPY.NATIVE:
            endian = NPY.NATBYTE
        elif endian == NPY.IGNORE:
            endian = ignore
        if self.num == NPY.UNICODE:
            size >>= 2
        if self.num == NPY.OBJECT:
            return "%s%s" %(endian, basic)
        return "%s%s%s" % (endian, basic, size)

    def descr_get_descr(self, space, style='descr', force_dict=False):
        simple = False
        if style == 'descr':
            simple = True
        if not self.is_record():
            return space.newlist([space.newtuple([space.newtext(""),
                                                  self.descr_get_str(space, simple=simple)])])
        elif (self.alignment > 1 and not style.startswith('descr')) or force_dict:
            # we need to force a sorting order for the keys,
            # so return a string instead of a dict. Also, numpy formats
            # the lists without spaces between elements, so we cannot simply
            # do str(names)
            names = ["'names':["]
            formats = ["'formats':["]
            offsets = ["'offsets':["]
            titles = ["'titles':["]
            use_titles = False
            show_offsets = False
            offsets_n = []
            total = 0
            for name, title in self.names:
                offset, subdtype = self.fields[name]
                if subdtype.is_record():
                    substr = [space.text_w(space.str(subdtype.descr_get_descr(
                                                space, style='descr_subdtype'))), ","]
                elif subdtype.subdtype is not None:
                    substr = ["(", space.text_w(space.str(
                        subdtype.subdtype.descr_get_descr(space, style='descr_subdtype'))),
                        ', ',
                        space.text_w(space.repr(space.newtuple([space.newint(s) for s in subdtype.shape]))),
                        "),"]
                else:
                    substr = ["'", subdtype.get_str(ignore=''), "',"]
                formats += substr
                offsets += [str(offset),  ',']
                names += ["'", name, "',"]
                titles += ["'", str(title), "',"]
                if title is not None:
                    use_titles = True
                if total != offset:
                    show_offsets = True
                total += subdtype.elsize
                # make sure offsets_n is sorted
                i = 0
                for i in range(len(offsets_n)):
                    if offset < offsets_n[i]:
                        break
                offsets_n.insert(i, offset)
            total = 0
            for i in range(len(offsets_n)):
                if offsets_n[i] != self.alignment * i:
                    show_offsets = True
            if use_titles and not show_offsets: 
                return self.descr_get_descr(space, style='descr')
            # replace the last , with a ]
            formats[-1] = formats[-1][:-1] + ']'
            offsets[-1] = offsets[-1][:-1] + ']'
            names[-1] = names[-1][:-1] + ']'
            titles[-1] = titles[-1][:-1] + ']'
            if self.alignment < 2 or style.endswith('subdtype'):
                suffix = "}"
            elif style == 'str':
                suffix = ", 'aligned':True}"
            elif style == 'substr':
                suffix = '}'
            else:
                suffix = "}, align=True"
            s_as_list = ['{'] + names + [', '] + formats + [', '] + offsets + [', ']
            if use_titles:
                s_as_list += titles + [', ']
                    
            s_as_list += ["'itemsize':", str(self.elsize), suffix]
            return space.newtext(''.join(s_as_list))
        else:
            descr = []
            total = 0
            for name, title in self.names:
                offset, subdtype = self.fields[name]
                show_offsets = False
                if total != offset and len(subdtype.shape) < 1:
                    # whoops, need to use other format
                    return self.descr_get_descr(space, style=style + '_subdtype', force_dict=True)
                total += subdtype.elsize
                ignore = '|'
                if title:
                    subdescr = [space.newtuple([space.newtext(title), space.newtext(name)])]
                    ignore = ''
                else:
                    subdescr = [space.newtext(name)]
                if subdtype.is_record():
                    subdescr.append(subdtype.descr_get_descr(space, style))
                elif subdtype.subdtype is not None:
                    subdescr.append(subdtype.subdtype.descr_get_str(space, simple=False))
                else:
                    subdescr.append(subdtype.descr_get_str(space, ignore=ignore, simple=False))
                if subdtype.shape != []:
                    subdescr.append(subdtype.descr_get_shape(space))
                descr.append(space.newtuple(subdescr[:]))
            if self.alignment >= 0 and not style.endswith('subdtype'):
                return space.newtext(space.text_w(space.repr(space.newlist(descr))) + ', align=True')
            return space.newlist(descr)

    def descr_get_hasobject(self, space):
        return space.newbool(self.is_object())

    def descr_get_isbuiltin(self, space):
        if self.fields is None:
            return space.newint(1)
        return space.newint(0)

    def descr_get_isnative(self, space):
        return space.newbool(self.is_native())

    def descr_get_base(self, space):
        return self.base

    def descr_get_subdtype(self, space):
        if self.subdtype is None:
            return space.w_None
        return space.newtuple([self.subdtype,
                               self.descr_get_shape(space)])

    def descr_get_shape(self, space):
        return space.newtuple([space.newint(dim) for dim in self.shape])

    def descr_get_flags(self, space):
        return space.newint(self.flags)

    def descr_get_fields(self, space):
        if not self.fields:
            return space.w_None
        w_fields = space.newdict()
        for name, title in self.names:
            offset, subdtype = self.fields[name]
            if title is not None:
                w_nt = space.newtuple([space.newtext(name), space.newtext(title)]) 
                space.setitem(w_fields, w_nt,
                          space.newtuple([subdtype, space.newint(offset)]))
            else:
                space.setitem(w_fields, space.newtext(name),
                          space.newtuple([subdtype, space.newint(offset)]))
        return w_fields

    def descr_get_names(self, space):
        if not self.fields:
            return space.w_None
        return space.newtuple([space.newtext(name[0]) for name in self.names])

    def descr_set_names(self, space, w_names):
        if not self.fields:
            raise oefmt(space.w_ValueError, "there are no fields defined")
        if not space.issequence_w(w_names) or \
                space.len_w(w_names) != len(self.names):
            raise oefmt(space.w_ValueError,
                        "must replace all names at once "
                        "with a sequence of length %d",
                        len(self.names))
        names = []
        names_w = space.fixedview(w_names)
        for i in range(len(names_w)):
            w_name = names_w[i]
            title = self.names[i][1]
            if not space.isinstance_w(w_name, space.w_text):
                raise oefmt(space.w_ValueError,
                            "item #%d of names is of type %T and not string",
                            len(names), w_name)
            names.append((space.text_w(w_name), title))
        fields = {}
        for i in range(len(self.names)):
            if names[i][0] in fields:
                raise oefmt(space.w_ValueError, "Duplicate field names given.")
            fields[names[i][0]] = self.fields[self.names[i][0]]
            if self.names[i][1] is not None:
                fields[self.names[i][1]] = self.fields[self.names[i][0]]
        self.fields = fields
        self.names = names

    def descr_del_names(self, space):
        raise oefmt(space.w_AttributeError, 
            "Cannot delete dtype names attribute")

    def descr_get_metadata(self, space):
        if self.metadata is None:
            return space.w_None
        return self.metadata

    def descr_set_metadata(self, space, w_metadata):
        if w_metadata is None:
            return
        if not space.isinstance_w(w_metadata, space.w_dict):
            raise oefmt(space.w_TypeError, "argument 4 must be dict, not str")
        self.metadata = w_metadata

    def descr_del_metadata(self, space):
        self.metadata = None

    def eq(self, space, w_other):
        w_other = space.call_function(space.gettypefor(W_Dtype), w_other)
        if space.is_w(self, w_other):
            return True
        if isinstance(w_other, W_Dtype):
            if self.is_object() and w_other.is_object():
                # ignore possible 'record' unions
                # created from dtype(('O', spec))
                return True
            return space.eq_w(self.descr_reduce(space),
                              w_other.descr_reduce(space))
        return False

    def descr_eq(self, space, w_other):
        return space.newbool(self.eq(space, w_other))

    def descr_ne(self, space, w_other):
        return space.newbool(not self.eq(space, w_other))

    def descr_le(self, space, w_other):
        from .casting import can_cast_to
        w_other = as_dtype(space, w_other)
        return space.newbool(can_cast_to(self, w_other))

    def descr_ge(self, space, w_other):
        from .casting import can_cast_to
        w_other = as_dtype(space, w_other)
        return space.newbool(can_cast_to(w_other, self))

    def descr_lt(self, space, w_other):
        from .casting import can_cast_to
        w_other = as_dtype(space, w_other)
        return space.newbool(can_cast_to(self, w_other) and not self.eq(space, w_other))

    def descr_gt(self, space, w_other):
        from .casting import can_cast_to
        w_other = as_dtype(space, w_other)
        return space.newbool(can_cast_to(w_other, self) and not self.eq(space, w_other))

    def descr_hash(self, space):
        tl = _array_descr_walk(space, self)
        return space.hash(space.newtuple(tl[:]))

    def descr_str(self, space):
        if self.fields:
            r = self.descr_get_descr(space, style='str')
            name = space.text_w(space.str(self.w_box_type))
            if name != "<type 'numpy.void'>":
                boxname = space.str(self.w_box_type)
                r = space.newtuple([self.w_box_type, r])
            return space.str(r)
        elif self.subdtype is not None:
            return space.str(space.newtuple([
                self.subdtype.descr_get_str(space),
                self.descr_get_shape(space)]))
        else:
            if self.is_flexible():
                return self.descr_get_str(space)
            else:
                return self.descr_get_name(space)

    def descr_repr(self, space):
        if isinstance(self.itemtype, types.CharType):
            return space.newtext("dtype('S1')")
        if self.fields:
            r = self.descr_get_descr(space, style='repr')
            name = space.text_w(space.str(self.w_box_type))
            if name != "<type 'numpy.void'>":
                r = space.newtuple([self.w_box_type, r])
        elif self.subdtype is not None:
            r = space.newtuple([self.subdtype.descr_get_str(space),
                                self.descr_get_shape(space)])
        else:
            if self.is_flexible():
                if self.byteorder != NPY.IGNORE:
                    byteorder = NPY.NATBYTE if self.is_native() else NPY.OPPBYTE
                else:
                    byteorder = ''
                size = self.elsize
                if self.num == NPY.UNICODE:
                    size >>= 2
                r = space.newtext("'" + byteorder + self.char + str(size) + "'")
            else:
                r = self.descr_get_name(space, quote=True)
        if space.isinstance_w(r, space.w_text):
            return space.newtext("dtype(%s)" % space.text_w(r))
        return space.newtext("dtype(%s)" % space.text_w(space.repr(r)))

    def descr_getitem(self, space, w_item):
        if not self.fields:
            raise oefmt(space.w_KeyError, "There are no fields in dtype %s.",
                        self.get_name())
        if space.isinstance_w(w_item, space.w_text):
            item = space.text_w(w_item)
        elif space.isinstance_w(w_item, space.w_bytes):
            item = space.bytes_w(w_item)   # XXX should it be supported?
        elif space.isinstance_w(w_item, space.w_int):
            indx = space.int_w(w_item)
            try:
                item,title = self.names[indx]
            except IndexError:
                raise oefmt(space.w_IndexError,
                    "Field index %d out of range.", indx)
        else:
            raise oefmt(space.w_ValueError,
                "Field key must be an integer, string, or unicode.")
        try:
            return self.fields[item][1]
        except KeyError:
            raise oefmt(space.w_KeyError,
                "Field named '%s' not found.", item)

    def descr_len(self, space):
        if not self.fields:
            return space.newint(0)
        return space.newint(len(self.fields))

    def runpack_str(self, space, s):
        if self.is_str_or_unicode():
            return self.coerce(space, space.newbytes(s))
        return self.itemtype.runpack_str(space, s, self.is_native())

    def store(self, arr, i, offset, value):
        return self.itemtype.store(arr, i, offset, value, self.is_native())

    def read(self, arr, i, offset):
        return self.itemtype.read(arr, i, offset, self)

    def read_bool(self, arr, i, offset):
        return self.itemtype.read_bool(arr, i, offset, self)

    def descr_reduce(self, space):
        w_class = space.type(self)
        builder_args = space.newtuple([
            space.newbytes("%s%d" % (self.kind, self.elsize)),
            space.newint(0), space.newint(1)])

        version = space.newint(3)
        endian = self.byteorder
        if endian == NPY.NATIVE:
            endian = NPY.NATBYTE
        subdescr = self.descr_get_subdtype(space)
        names = self.descr_get_names(space)
        values = self.descr_get_fields(space)
        if self.is_flexible():
            w_size = space.newint(self.elsize)
            if self.alignment > 2:
                w_alignment = space.newint(self.alignment)
            else:
                w_alignment = space.newint(1)
        else:
            w_size = space.newint(-1)
            w_alignment = space.newint(-1)
        w_flags = space.newint(self.flags)

        data = space.newtuple([version, space.newbytes(endian), subdescr,
                               names, values, w_size, w_alignment, w_flags])
        return space.newtuple([w_class, builder_args, data])

    def descr_setstate(self, space, w_data):
        if self.fields is None and not isinstance(self.itemtype, types.VoidType):  
            # if builtin dtype (but not w_voiddtype)
            return space.w_None

        version = space.int_w(space.getitem(w_data, space.newint(0)))
        if version != 3:
            raise oefmt(space.w_ValueError,
                        "can't handle version %d of numpy.dtype pickle",
                        version)

        endian = byteorder_w(space, space.getitem(w_data, space.newint(1)))
        if endian == NPY.NATBYTE:
            endian = NPY.NATIVE

        w_subarray = space.getitem(w_data, space.newint(2))
        w_names = space.getitem(w_data, space.newint(3))
        w_fields = space.getitem(w_data, space.newint(4))
        size = space.int_w(space.getitem(w_data, space.newint(5)))
        alignment = space.int_w(space.getitem(w_data, space.newint(6)))
        if alignment < 2:
            alignment = -1
        flags = space.int_w(space.getitem(w_data, space.newint(7)))

        if (w_names == space.w_None) != (w_fields == space.w_None):
            raise oefmt(space.w_ValueError, "inconsistent fields and names in Numpy dtype unpickling")

        self.byteorder = endian
        self.shape = []
        self.subdtype = None
        self.base = self

        if w_subarray != space.w_None:
            if not space.isinstance_w(w_subarray, space.w_tuple) or \
                    space.len_w(w_subarray) != 2:
                raise oefmt(space.w_ValueError,
                            "incorrect subarray in __setstate__")
            subdtype, w_shape = space.fixedview(w_subarray)
            assert isinstance(subdtype, W_Dtype)
            if not support.issequence_w(space, w_shape):
                self.shape = [space.int_w(w_shape)]
            else:
                self.shape = [space.int_w(w_s) for w_s in space.fixedview(w_shape)]
            self.subdtype = subdtype
            self.base = subdtype.base

        if w_names != space.w_None:
            self.names = []
            self.fields = {}
            for w_name in space.fixedview(w_names):
                # XXX what happens if there is a title in the pickled dtype?
                name = space.bytes_w(w_name)
                value = space.getitem(w_fields, w_name)

                dtype = space.getitem(value, space.newint(0))
                offset = space.int_w(space.getitem(value, space.newint(1)))
                self.names.append((name, None))
                assert isinstance(dtype, W_Dtype)
                self.fields[name] = offset, dtype
            self.itemtype = types.RecordType(space)

        if self.is_flexible():
            self.elsize = size
            self.alignment = alignment
        self.flags = flags

    @unwrap_spec(new_order='text')
    def descr_newbyteorder(self, space, new_order=NPY.SWAP):
        newendian = byteorder_converter(space, new_order)
        endian = self.byteorder
        if endian != NPY.IGNORE:
            if newendian == NPY.SWAP:
                endian = NPY.OPPBYTE if self.is_native() else NPY.NATBYTE
            elif newendian != NPY.IGNORE:
                endian = newendian
        fields = self.fields
        if fields is None:
            fields = {}
        return W_Dtype(self.itemtype,
                       self.w_box_type, byteorder=endian, elsize=self.elsize,
                       names=self.names, fields=fields,
                       shape=self.shape, subdtype=self.subdtype)


@specialize.arg(2)
def dtype_from_list(space, w_lst, simple, alignment, offsets=None, itemsize=0):
    lst_w = space.listview(w_lst)
    fields = {}
    use_supplied_offsets = True
    if offsets is None:
        use_supplied_offsets = False
        offsets = [0] * len(lst_w)
    maxalign = alignment 
    fldnames = [''] * len(lst_w)
    subdtypes = [None] * len(lst_w)
    titles = [None] * len(lst_w)
    total = 0
    for i in range(len(lst_w)):
        w_elem = lst_w[i]
        if simple:
            subdtype = make_new_dtype(space, space.gettypefor(W_Dtype), w_elem,
                                    maxalign)
            fldnames[i] = 'f%d' % i
        else:
            w_shape = space.newtuple([])
            if space.len_w(w_elem) == 3:
                w_fldname, w_flddesc, w_shape = space.fixedview(w_elem)
                if not support.issequence_w(space, w_shape):
                    w_shape = space.newtuple([w_shape])
            else:
                w_fldname, w_flddesc = space.fixedview(w_elem, 2)
            subdtype = make_new_dtype(space, space.gettypefor(W_Dtype),
                                    w_flddesc, maxalign, w_shape=w_shape)
            if space.isinstance_w(w_fldname, space.w_tuple):
                fldlist = space.listview(w_fldname)
                fldnames[i] = space.text_w(fldlist[0])
                if space.is_w(fldlist[1], space.w_None):
                    titles[i] = None
                else:
                    titles[i] = space.text_w(fldlist[1])
                if len(fldlist) != 2:
                    raise oefmt(space.w_TypeError, "data type not understood")
            elif space.isinstance_w(w_fldname, space.w_text): 
                fldnames[i] = space.text_w(w_fldname)
            else:
                raise oefmt(space.w_TypeError, "data type not understood")
            if fldnames[i] == '':
                fldnames[i] = 'f%d' % i
        assert isinstance(subdtype, W_Dtype)
        if alignment >= 0:
            maxalign = max(subdtype.alignment, maxalign)
            delta = subdtype.alignment
            # Set offset to the next power-of-two above delta
            delta = (delta + maxalign -1) & (-maxalign)
            if not use_supplied_offsets:
                if delta > offsets[i]:
                    for j in range(i):
                        offsets[j+1] = delta + offsets[j]
                if  i + 1 < len(offsets) and offsets[i + 1] == 0:
                    offsets[i + 1] = offsets[i] + max(delta, subdtype.elsize)
                # sanity check
                if offsets[i] % maxalign:
                    offsets[i] = ((offsets[i] // maxalign) + 1) * maxalign
        elif not use_supplied_offsets:
            if  i + 1 < len(offsets) and offsets[i + 1] == 0:
                offsets[i+1] = offsets[i] + subdtype.elsize
        subdtypes[i] = subdtype
        if use_supplied_offsets:
            sz = subdtype.elsize
        else:
            sz = max(maxalign, subdtype.elsize)
        if offsets[i] + sz > total:
            total = offsets[i] + sz
    # padding?
    if alignment >= 0 and total % maxalign:
        total = total // maxalign * maxalign + maxalign
    names = []
    for i in range(len(subdtypes)):
        subdtype = subdtypes[i]
        assert isinstance(subdtype, W_Dtype)
        if alignment >=0 and subdtype.is_record():
            subdtype.alignment = maxalign
        if fldnames[i] in fields:
            raise oefmt(space.w_ValueError, "two fields with the same name")
        if maxalign > 1 and offsets[i] % subdtype.alignment:
            raise oefmt(space.w_ValueError, "offset %d for NumPy dtype with "
                    "fields is not divisible by the field alignment %d "
                    "with align=True", offsets[i], maxalign)
        fields[fldnames[i]] = offsets[i], subdtype
        if titles[i] is not None:
            if titles[i] in fields:
                raise oefmt(space.w_ValueError, "two fields with the same name")
            fields[titles[i]] = offsets[i], subdtype
        names.append((fldnames[i], titles[i]))
    if itemsize > 1:
        if total > itemsize:
            raise oefmt(space.w_ValueError,
                     "NumPy dtype descriptor requires %d bytes, cannot"
                     " override to smaller itemsize of %d", total, itemsize)
        if alignment >= 0 and itemsize % maxalign:
            raise oefmt(space.w_ValueError,
                    "NumPy dtype descriptor requires alignment of %d bytes, "
                    "which is not divisible into the specified itemsize %d",
                    maxalign, itemsize) 
        total = itemsize
    retval = W_Dtype(types.RecordType(space), space.gettypefor(boxes.W_VoidBox),
                   names=names, fields=fields, elsize=total)
    if alignment >=0:
        retval.alignment = maxalign
    else:
        retval.alignment = -1
    retval.flags |= NPY.NEEDS_PYAPI
    return retval

def _get_val_or_none(space, w_dict, key):
    w_key = space.newtext(key)
    try:
        w_val = space.getitem(w_dict, w_key)
    except OperationError as e:
        if e.match(space, space.w_KeyError):
            return None
        else:
            raise
    return w_val

def _get_list_or_none(space, w_dict, key):
    w_val = _get_val_or_none(space, w_dict, key)
    if w_val is None:
        return None
    if space.isinstance_w(w_val, space.w_set):
        raise oefmt(space.w_TypeError, "'set' object does not support indexing")
    return space.listview(w_val)

def _usefields(space, w_dict, align):
    # Only for testing, a shortened version of the real _usefields
    allfields = []
    for fname_w in space.unpackiterable(w_dict):
        obj = _get_list_or_none(space, w_dict, space.text_w(fname_w))
        num = space.int_w(obj[1])
        if align:
            alignment = 0
        else:
            alignment = -1
        format = dtype_from_spec(space, obj[0], alignment=alignment)
        if len(obj) > 2:
            title = obj[2]
        else:
            title = space.w_None
        allfields.append((fname_w, format, num, title))
    #allfields.sort(key=lambda x: x[2])
    names   = [space.newtuple([x[0], x[3]]) for x in allfields]
    formats = [x[1] for x in allfields]
    offsets = [x[2] for x in allfields]
    aslist = []
    if align:
        alignment = 0
    else:
        alignment = -1
    for i in range(len(names)):
        aslist.append(space.newtuple([names[i], formats[i]]))
    return dtype_from_list(space, space.newlist(aslist), False, alignment, offsets=offsets)
    
def dtype_from_dict(space, w_dict, alignment):
    from pypy.objspace.std.dictmultiobject import W_DictMultiObject
    assert isinstance(w_dict, W_DictMultiObject)
    names_w = _get_list_or_none(space, w_dict, 'names')
    formats_w = _get_list_or_none(space, w_dict, 'formats') 
    offsets_w = _get_list_or_none(space, w_dict, 'offsets')
    titles_w = _get_list_or_none(space, w_dict, 'titles')
    metadata_w = _get_val_or_none(space, w_dict, 'metadata')
    aligned_w = _get_val_or_none(space, w_dict, 'aligned')
    itemsize_w = _get_val_or_none(space, w_dict, 'itemsize')
    if names_w is None or formats_w is None:
        try:
            return get_appbridge_cache(space).call_method(space,
                'numpy.core._internal', '_usefields', Arguments(space, 
                                [w_dict, space.newbool(alignment >= 0)]))
        except OperationError as e:
            if e.match(space, space.w_ImportError):
                return _usefields(space, w_dict, alignment >= 0)
            raise
    n = len(names_w)
    if (n != len(formats_w) or 
        (offsets_w is not None and n != len(offsets_w)) or
        (titles_w is not None and n != len(titles_w))):
        raise oefmt(space.w_ValueError, "'names', 'formats', 'offsets', and "
            "'titles' dicct entries must have the same length")
    if aligned_w is not None:
        if space.isinstance_w(aligned_w, space.w_bool) and space.is_true(aligned_w):
            if alignment < 0:
                alignment = 0 
        else:
            raise oefmt(space.w_ValueError,
                    "NumPy dtype descriptor includes 'aligned' entry, "
                    "but its value is neither True nor False");
    if offsets_w is None:
        offsets = None
    else:
        offsets = [space.int_w(i) for i in offsets_w]
    if titles_w is not None:
        _names_w = []
        for i in range(min(len(names_w), len(titles_w))):
            _names_w.append(space.newtuple([names_w[i], titles_w[i]]))
        names_w = _names_w
    aslist = []
    if itemsize_w is None:
        itemsize = 0
    else:
        itemsize = space.int_w(itemsize_w)
    for i in range(min(len(names_w), len(formats_w))):
        aslist.append(space.newtuple([names_w[i], formats_w[i]]))
    retval = dtype_from_list(space, space.newlist(aslist), False, alignment,
                             offsets=offsets, itemsize=itemsize)
    if metadata_w is not None:
        retval.descr_set_metadata(space, metadata_w)
    retval.flags |= NPY.NEEDS_PYAPI
    return retval 

def dtype_from_spec(space, w_spec, alignment):

    w_lst = w_spec
    try:
        w_lst = get_appbridge_cache(space).call_method(space,
            'numpy.core._internal', '_commastring', Arguments(space, [w_spec]))
    except OperationError as e:
        if not e.match(space, space.w_ImportError):
            raise
        # handle only simple cases for testing
        if space.isinstance_w(w_spec, space.w_text):
            spec = [s.strip() for s in space.text_w(w_spec).split(',')]
            w_lst = space.newlist([space.newtext(s) for s in spec]) 
    if not space.isinstance_w(w_lst, space.w_list) or space.len_w(w_lst) < 1:
        raise oefmt(space.w_RuntimeError,
                    "_commastring is not returning a list with len >= 1")
    if space.len_w(w_lst) == 1:
        return descr__new__(space, space.gettypefor(W_Dtype),
                            space.getitem(w_lst, space.newint(0)), align=alignment>0)
    else:
        try:
            return dtype_from_list(space, w_lst, True, alignment)
        except OperationError as e:
            if e.match(space, space.w_TypeError):
                return dtype_from_list(space, w_lst, False, alignment)
            raise

def _check_for_commastring(s):
    if s[0] in string.digits or s[0] in '<>=|' and s[1] in string.digits:
        return True
    if s[0] == '(' and s[1] == ')' or s[0] in '<>=|' and s[1] == '(' and s[2] == ')':
        return True
    sqbracket = 0
    for c in s:
        if c == ',':
            if sqbracket == 0:
                return True
        elif c == '[':
            sqbracket += 1
        elif c == ']':
            sqbracket -= 1
    return False

def _set_metadata_and_copy(space, w_metadata, dtype, copy=False):
    cache = get_dtype_cache(space)
    assert isinstance(dtype, W_Dtype)
    if copy or (dtype in cache.builtin_dtypes and w_metadata is not None):
        dtype = W_Dtype(dtype.itemtype, dtype.w_box_type, dtype.byteorder)
    if w_metadata is not None:
        dtype.descr_set_metadata(space, w_metadata)
    return dtype

def _get_shape(space, w_shape):
    if w_shape is None:
        return None
    if space.isinstance_w(w_shape, space.w_int):
        dim = space.int_w(w_shape)
        if dim == 1:
            return None
        return [dim]
    shape_w = space.fixedview(w_shape)
    if len(shape_w) < 1:
        return None
    elif space.isinstance_w(shape_w[0], space.w_tuple):
        # (base_dtype, new_dtype) dtype spectification
        return None
    shape = []
    for w_dim in shape_w:
        try:
            dim = space.int_w(w_dim)
        except OperationError as e:
            if e.match(space, space.w_OverflowError):
                raise oefmt(space.w_ValueError, "invalid shape in fixed-type tuple.")
            else:
                raise
        if dim > 0x7fffffff:
            raise oefmt(space.w_ValueError, "invalid shape in fixed-type tuple: "
                      "dimension does not fit into a C int.")
        elif dim < 0:
            raise oefmt(space.w_ValueError, "invalid shape in fixed-type tuple: "
                  "dimension smaller than zero.")
        shape.append(dim)
    return shape

@unwrap_spec(align=bool, copy=bool)
def descr__new__(space, w_subtype, w_dtype, align=False, copy=False,
                 w_shape=None, w_metadata=None):
    if align:
        alignment = 0
    else:
        alignment = -1
    return make_new_dtype(space, w_subtype, w_dtype, alignment, copy=copy,
                          w_shape=w_shape, w_metadata=w_metadata)

def make_new_dtype(space, w_subtype, w_dtype, alignment, copy=False, w_shape=None, w_metadata=None):
    cache = get_dtype_cache(space)
    shape = _get_shape(space, w_shape)
    if shape is not None:
        subdtype = make_new_dtype(space, w_subtype, w_dtype, alignment, copy, w_metadata=w_metadata)
        assert isinstance(subdtype, W_Dtype)
        try:
            size = support.product(shape)
            size = ovfcheck(size * subdtype.elsize)
        except OverflowError:
            raise oefmt(space.w_ValueError, "invalid shape in fixed-type tuple: "
                  "dtype size in bytes must fit into a C int.")
        if size > 0x7fffffff:
            raise oefmt(space.w_ValueError, "invalid shape in fixed-type tuple: "
                  "dtype size in bytes must fit into a C int.")
        
        return _set_metadata_and_copy(space, w_metadata,
               W_Dtype(types.VoidType(space), space.gettypefor(boxes.W_VoidBox),
                       shape=shape, subdtype=subdtype, elsize=size))
    elif w_shape is not None and not space.isinstance_w(w_shape, space.w_int):
        spec = space.listview(w_shape)
        if len(spec) > 0:
            # this is (base_dtype, new_dtype) so just make it a union by setting both
            # parts' offset to 0
            w_dtype1 = make_new_dtype(space, w_subtype, w_shape, alignment)
            assert isinstance(w_dtype, W_Dtype)
            assert isinstance(w_dtype1, W_Dtype)
            if (w_dtype.elsize != 0 and w_dtype1.elsize != 0 and 
                    w_dtype1.elsize != w_dtype.elsize):
                raise oefmt(space.w_ValueError,
                    'mismatch in size of old and new data-descriptor')
            retval = W_Dtype(w_dtype.itemtype, w_dtype.w_box_type,
                    names=w_dtype1.names[:], fields=w_dtype1.fields.copy(),
                    elsize=w_dtype1.elsize)
            return retval
    if space.is_none(w_dtype):
        return cache.w_float64dtype
    if space.isinstance_w(w_dtype, w_subtype):
        return w_dtype
    if space.isinstance_w(w_dtype, space.w_unicode):
        name = space.text_w(w_dtype)
        if _check_for_commastring(name):
            return _set_metadata_and_copy(space, w_metadata,
                                dtype_from_spec(space, w_dtype, alignment))
        cname = name[1:] if name[0] == NPY.OPPBYTE else name
        try:
            dtype = cache.dtypes_by_name[cname]
        except KeyError:
            pass
        else:
            if name[0] == NPY.OPPBYTE:
                dtype = dtype.descr_newbyteorder(space)
            return dtype
        if name[0] in 'VSUca' or name[0] in '<>=|' and name[1] in 'VSUca':
            return variable_dtype(space, name)
        raise oefmt(space.w_TypeError, 'data type "%s" not understood', name)
    elif space.isinstance_w(w_dtype, space.w_list):
        return _set_metadata_and_copy( space, w_metadata,
                        dtype_from_list(space, w_dtype, False, alignment), copy)
    elif space.isinstance_w(w_dtype, space.w_tuple):
        w_dtype0 = space.getitem(w_dtype, space.newint(0))
        w_dtype1 = space.getitem(w_dtype, space.newint(1))
        # create a new dtype object
        l_side = make_new_dtype(space, w_subtype, w_dtype0, alignment, copy)
        assert isinstance(l_side, W_Dtype)
        if l_side.elsize == 0 and space.isinstance_w(w_dtype1, space.w_int):
            #(flexible_dtype, itemsize)
            name = "%s%d" % (l_side.kind, space.int_w(w_dtype1))
            retval = make_new_dtype(space, w_subtype, space.newtext(name), alignment, copy)
            return _set_metadata_and_copy(space, w_metadata, retval, copy)
        elif (space.isinstance_w(w_dtype1, space.w_int) or
                space.isinstance_w(w_dtype1, space.w_tuple) or 
                space.isinstance_w(w_dtype1, space.w_list) or 
                isinstance(w_dtype1, W_NDimArray)):
            #(fixed_dtype, shape) or (base_dtype, new_dtype)
            retval = make_new_dtype(space, w_subtype, l_side, alignment,
                                    copy, w_shape=w_dtype1)
            return _set_metadata_and_copy(space, w_metadata, retval, copy)
    elif space.isinstance_w(w_dtype, space.w_dict):
        return _set_metadata_and_copy(space, w_metadata,
                dtype_from_dict(space, w_dtype, alignment), copy)
    for dtype in cache.builtin_dtypes:
        if dtype.num in cache.alternate_constructors and \
                w_dtype in cache.alternate_constructors[dtype.num]:
            return _set_metadata_and_copy(space, w_metadata, dtype, copy)
        if w_dtype is dtype.w_box_type:
            return _set_metadata_and_copy(space, w_metadata, dtype, copy)
        if space.isinstance_w(w_dtype, space.w_type) and \
           space.issubtype_w(w_dtype, dtype.w_box_type):
            return _set_metadata_and_copy( space, w_metadata,
                            W_Dtype(dtype.itemtype, w_dtype, elsize=0), copy)
    if space.isinstance_w(w_dtype, space.w_type):
        return _set_metadata_and_copy(space, w_metadata, cache.w_objectdtype, copy)
    raise oefmt(space.w_TypeError, "data type not understood")


W_Dtype.typedef = TypeDef("numpy.dtype",
    __new__ = interp2app(descr__new__),

    type = interp_attrproperty_w("w_box_type", cls=W_Dtype),
    kind = interp_attrproperty("kind", cls=W_Dtype, wrapfn="newtext"),
    char = interp_attrproperty("char", cls=W_Dtype, wrapfn="newtext"),
    num = interp_attrproperty("num", cls=W_Dtype, wrapfn="newint"),
    byteorder = interp_attrproperty("byteorder", cls=W_Dtype, wrapfn="newtext"),
    itemsize = interp_attrproperty("elsize", cls=W_Dtype, wrapfn="newint"),
    alignment = interp_attrproperty("alignment", cls=W_Dtype, wrapfn="newint"),

    name = GetSetProperty(W_Dtype.descr_get_name),
    str = GetSetProperty(W_Dtype.descr_get_str),
    descr = GetSetProperty(W_Dtype.descr_get_descr),
    hasobject = GetSetProperty(W_Dtype.descr_get_hasobject),
    isbuiltin = GetSetProperty(W_Dtype.descr_get_isbuiltin),
    isnative = GetSetProperty(W_Dtype.descr_get_isnative),
    base = GetSetProperty(W_Dtype.descr_get_base),
    subdtype = GetSetProperty(W_Dtype.descr_get_subdtype),
    shape = GetSetProperty(W_Dtype.descr_get_shape),
    fields = GetSetProperty(W_Dtype.descr_get_fields),
    names = GetSetProperty(W_Dtype.descr_get_names,
                           W_Dtype.descr_set_names,
                           W_Dtype.descr_del_names),
    metadata = GetSetProperty(W_Dtype.descr_get_metadata,
                           #W_Dtype.descr_set_metadata,
                           #W_Dtype.descr_del_metadata,
                            ),
    flags = GetSetProperty(W_Dtype.descr_get_flags),

    __eq__ = interp2app(W_Dtype.descr_eq),
    __ne__ = interp2app(W_Dtype.descr_ne),
    __lt__ = interp2app(W_Dtype.descr_lt),
    __le__ = interp2app(W_Dtype.descr_le),
    __gt__ = interp2app(W_Dtype.descr_gt),
    __ge__ = interp2app(W_Dtype.descr_ge),
    __hash__ = interp2app(W_Dtype.descr_hash),
    __str__= interp2app(W_Dtype.descr_str),
    __repr__ = interp2app(W_Dtype.descr_repr),
    __getitem__ = interp2app(W_Dtype.descr_getitem),
    __len__ = interp2app(W_Dtype.descr_len),
    __reduce__ = interp2app(W_Dtype.descr_reduce),
    __setstate__ = interp2app(W_Dtype.descr_setstate),
    newbyteorder = interp2app(W_Dtype.descr_newbyteorder),
)
W_Dtype.typedef.acceptable_as_base_class = False


def variable_dtype(space, name):
    if name[0] in '<>=|':
        name = name[1:]
    char = name[0]
    if len(name) == 1:
        size = 0
    else:
        try:
            size = int(name[1:])
        except ValueError:
            raise oefmt(space.w_TypeError, "data type not understood")
    if char == NPY.CHARLTR and size == 0:
        return W_Dtype(
            types.CharType(space),
            elsize=1,
            w_box_type=space.gettypefor(boxes.W_StringBox))
    elif char == NPY.STRINGLTR or char == NPY.STRINGLTR2:
        return new_string_dtype(space, size)
    elif char == NPY.UNICODELTR:
        return new_unicode_dtype(space, size)
    elif char == NPY.VOIDLTR:
        return new_void_dtype(space, size)
    raise oefmt(space.w_TypeError, 'data type "%s" not understood', name)


def new_string_dtype(space, size):
    return W_Dtype(
        types.StringType(space),
        elsize=size,
        w_box_type=space.gettypefor(boxes.W_StringBox),
    )


def new_unicode_dtype(space, size):
    itemtype = types.UnicodeType(space)
    return W_Dtype(
        itemtype,
        elsize=size * itemtype.get_element_size(),
        w_box_type=space.gettypefor(boxes.W_UnicodeBox),
    )


def new_void_dtype(space, size):
    return W_Dtype(
        types.VoidType(space),
        elsize=size,
        w_box_type=space.gettypefor(boxes.W_VoidBox),
    )


class DtypeCache(object):
    def __init__(self, space):
        self.w_booldtype = W_Dtype(
            types.Bool(space),
            w_box_type=space.gettypefor(boxes.W_BoolBox),
        )
        self.w_int8dtype = W_Dtype(
            types.Int8(space),
            w_box_type=space.gettypefor(boxes.W_Int8Box),
        )
        self.w_uint8dtype = W_Dtype(
            types.UInt8(space),
            w_box_type=space.gettypefor(boxes.W_UInt8Box),
        )
        self.w_int16dtype = W_Dtype(
            types.Int16(space),
            w_box_type=space.gettypefor(boxes.W_Int16Box),
        )
        self.w_uint16dtype = W_Dtype(
            types.UInt16(space),
            w_box_type=space.gettypefor(boxes.W_UInt16Box),
        )
        self.w_int32dtype = W_Dtype(
            types.Int32(space),
            w_box_type=space.gettypefor(boxes.W_Int32Box),
        )
        self.w_uint32dtype = W_Dtype(
            types.UInt32(space),
            w_box_type=space.gettypefor(boxes.W_UInt32Box),
        )
        self.w_longdtype = W_Dtype(
            types.Long(space),
            w_box_type=space.gettypefor(boxes.W_LongBox),
        )
        self.w_ulongdtype = W_Dtype(
            types.ULong(space),
            w_box_type=space.gettypefor(boxes.W_ULongBox),
        )
        self.w_int64dtype = W_Dtype(
            types.Int64(space),
            w_box_type=space.gettypefor(boxes.W_Int64Box),
        )
        self.w_uint64dtype = W_Dtype(
            types.UInt64(space),
            w_box_type=space.gettypefor(boxes.W_UInt64Box),
        )
        self.w_float32dtype = W_Dtype(
            types.Float32(space),
            w_box_type=space.gettypefor(boxes.W_Float32Box),
        )
        self.w_float64dtype = W_Dtype(
            types.Float64(space),
            w_box_type=space.gettypefor(boxes.W_Float64Box),
        )
        self.w_floatlongdtype = W_Dtype(
            types.FloatLong(space),
            w_box_type=space.gettypefor(boxes.W_FloatLongBox),
        )
        self.w_complex64dtype = W_Dtype(
            types.Complex64(space),
            w_box_type=space.gettypefor(boxes.W_Complex64Box),
        )
        self.w_complex128dtype = W_Dtype(
            types.Complex128(space),
            w_box_type=space.gettypefor(boxes.W_Complex128Box),
        )
        self.w_complexlongdtype = W_Dtype(
            types.ComplexLong(space),
            w_box_type=space.gettypefor(boxes.W_ComplexLongBox),
        )
        self.w_stringdtype = W_Dtype(
            types.StringType(space),
            elsize=0,
            w_box_type=space.gettypefor(boxes.W_StringBox),
        )
        self.w_unicodedtype = W_Dtype(
            types.UnicodeType(space),
            elsize=0,
            w_box_type=space.gettypefor(boxes.W_UnicodeBox),
        )
        self.w_voiddtype = W_Dtype(
            types.VoidType(space),
            elsize=0,
            w_box_type=space.gettypefor(boxes.W_VoidBox),
        )
        self.w_float16dtype = W_Dtype(
            types.Float16(space),
            w_box_type=space.gettypefor(boxes.W_Float16Box),
        )
        self.w_objectdtype = W_Dtype(
            types.ObjectType(space),
            w_box_type=space.gettypefor(boxes.W_ObjectBox),
        )
        aliases = {
            NPY.BOOL:        ['bool_', 'bool8'],
            NPY.BYTE:        ['byte'],
            NPY.UBYTE:       ['ubyte'],
            NPY.SHORT:       ['short'],
            NPY.USHORT:      ['ushort'],
            NPY.LONG:        ['int'],
            NPY.ULONG:       ['uint'],
            NPY.LONGLONG:    ['longlong'],
            NPY.ULONGLONG:   ['ulonglong'],
            NPY.FLOAT:       ['single'],
            NPY.DOUBLE:      ['float', 'double'],
            NPY.LONGDOUBLE:  ['longdouble', 'longfloat'],
            NPY.CFLOAT:      ['csingle'],
            NPY.CDOUBLE:     ['complex', 'cfloat', 'cdouble'],
            NPY.CLONGDOUBLE: ['clongdouble', 'clongfloat'],
            NPY.STRING:      ['string_', 'str'],
            NPY.UNICODE:     ['unicode_'],
            NPY.OBJECT:      ['object_'],
        }
        self.alternate_constructors = {
            NPY.BOOL:     [space.w_bool],
            NPY.LONG:     [space.w_int,
                           space.gettypefor(boxes.W_IntegerBox),
                           space.gettypefor(boxes.W_SignedIntegerBox)],
            NPY.ULONG:    [space.gettypefor(boxes.W_UnsignedIntegerBox)],
            NPY.LONGLONG: [space.w_int],
            NPY.DOUBLE:   [space.w_float,
                           space.gettypefor(boxes.W_NumberBox),
                           space.gettypefor(boxes.W_FloatingBox)],
            NPY.CDOUBLE:  [space.w_complex,
                           space.gettypefor(boxes.W_ComplexFloatingBox)],
            NPY.STRING:   [space.w_bytes,
                           space.gettypefor(boxes.W_CharacterBox)],
            NPY.UNICODE:  [space.w_unicode],
            NPY.VOID:     [space.gettypefor(boxes.W_GenericBox)],
                           #space.w_buffer,  # XXX no buffer in space
            NPY.OBJECT:   [space.gettypefor(boxes.W_ObjectBox),
                           space.w_object],
        }
        float_dtypes = [self.w_float16dtype, self.w_float32dtype,
                        self.w_float64dtype, self.w_floatlongdtype]
        complex_dtypes = [self.w_complex64dtype, self.w_complex128dtype,
                          self.w_complexlongdtype]
        self.component_dtypes = {
            NPY.CFLOAT:      self.w_float32dtype,
            NPY.CDOUBLE:     self.w_float64dtype,
            NPY.CLONGDOUBLE: self.w_floatlongdtype,
        }
        integer_dtypes = [
            self.w_int8dtype, self.w_uint8dtype,
            self.w_int16dtype, self.w_uint16dtype,
            self.w_int32dtype, self.w_uint32dtype,
            self.w_longdtype, self.w_ulongdtype,
            self.w_int64dtype, self.w_uint64dtype]
        self.builtin_dtypes = ([self.w_booldtype] + integer_dtypes +
            float_dtypes + complex_dtypes + [
                self.w_stringdtype, self.w_unicodedtype, self.w_voiddtype,
                self.w_objectdtype,
            ])
        self.integer_dtypes = integer_dtypes
        self.float_dtypes = float_dtypes
        self.complex_dtypes = complex_dtypes
        self.float_dtypes_by_num_bytes = sorted(
            (dtype.elsize, dtype)
            for dtype in float_dtypes
        )
        self.dtypes_by_num = {}
        self.dtypes_by_name = {}
        # we reverse, so the stuff with lower numbers override stuff with
        # higher numbers
        # However, Long/ULong always take precedence over Intxx
        for dtype in reversed(
                [self.w_longdtype, self.w_ulongdtype] + self.builtin_dtypes):
            dtype.fields = None  # mark these as builtin
            self.dtypes_by_num[dtype.num] = dtype
            self.dtypes_by_name[dtype.get_name()] = dtype
            for can_name in [dtype.kind + str(dtype.elsize),
                             dtype.char]:
                self.dtypes_by_name[can_name] = dtype
                self.dtypes_by_name[NPY.NATBYTE + can_name] = dtype
                self.dtypes_by_name[NPY.NATIVE + can_name] = dtype
                self.dtypes_by_name[NPY.IGNORE + can_name] = dtype
            if dtype.num in aliases:
                for alias in aliases[dtype.num]:
                    self.dtypes_by_name[alias] = dtype
        if self.w_longdtype.elsize == self.w_int32dtype.elsize:
            intp_dtype = self.w_int32dtype
            uintp_dtype = self.w_uint32dtype
        else:
            intp_dtype = self.w_longdtype
            uintp_dtype = self.w_ulongdtype
        self.dtypes_by_name['p'] = self.dtypes_by_name['intp'] = intp_dtype
        self.dtypes_by_name['P'] = self.dtypes_by_name['uintp'] = uintp_dtype

        typeinfo_full = {
            'LONGLONG': self.w_int64dtype,
            'SHORT': self.w_int16dtype,
            'VOID': self.w_voiddtype,
            'UBYTE': self.w_uint8dtype,
            'UINTP': self.w_ulongdtype,
            'ULONG': self.w_ulongdtype,
            'LONG': self.w_longdtype,
            'UNICODE': self.w_unicodedtype,
            #'OBJECT',
            'ULONGLONG': self.w_uint64dtype,
            'STRING': self.w_stringdtype,
            'CFLOAT': self.w_complex64dtype,
            'CDOUBLE': self.w_complex128dtype,
            'CLONGDOUBLE': self.w_complexlongdtype,
            #'DATETIME',
            'UINT': self.w_uint32dtype,
            'INTP': self.w_longdtype,
            'HALF': self.w_float16dtype,
            'BYTE': self.w_int8dtype,
            #'TIMEDELTA',
            'INT': self.w_int32dtype,
            'DOUBLE': self.w_float64dtype,
            'LONGDOUBLE': self.w_floatlongdtype,
            'USHORT': self.w_uint16dtype,
            'FLOAT': self.w_float32dtype,
            'BOOL': self.w_booldtype,
            'OBJECT': self.w_objectdtype,
        }

        typeinfo_partial = {
            'Generic': boxes.W_GenericBox,
            'Character': boxes.W_CharacterBox,
            'Flexible': boxes.W_FlexibleBox,
            'Inexact': boxes.W_InexactBox,
            'Integer': boxes.W_IntegerBox,
            'SignedInteger': boxes.W_SignedIntegerBox,
            'UnsignedInteger': boxes.W_UnsignedIntegerBox,
            'ComplexFloating': boxes.W_ComplexFloatingBox,
            'Number': boxes.W_NumberBox,
            'Floating': boxes.W_FloatingBox
        }
        w_typeinfo = space.newdict()
        for k, v in typeinfo_partial.iteritems():
            space.setitem(w_typeinfo, space.newtext(k), space.gettypefor(v))
        for k, dtype in typeinfo_full.iteritems():
            itembits = dtype.elsize * 8
            if k in ('INTP', 'UINTP'):
                char = getattr(NPY, k + 'LTR')
            else:
                char = dtype.char
            items_w = [space.newtext(char),
                       space.newint(dtype.num),
                       space.newint(itembits),
                       space.newint(dtype.itemtype.get_element_size())]
            if dtype.is_int():
                if dtype.is_bool():
                    w_maxobj = space.newint(1)
                    w_minobj = space.newint(0)
                elif dtype.is_signed():
                    w_maxobj = space.newint(r_longlong((1 << (itembits - 1))
                                            - 1))
                    w_minobj = space.newint(r_longlong(-1) << (itembits - 1))
                else:
                    w_maxobj = space.newint(r_ulonglong(1 << itembits) - 1)
                    w_minobj = space.newint(0)
                items_w = items_w + [w_maxobj, w_minobj]
            items_w = items_w + [dtype.w_box_type]
            space.setitem(w_typeinfo, space.newtext(k), space.newtuple(items_w))
        self.w_typeinfo = w_typeinfo


def get_dtype_cache(space):
    return space.fromcache(DtypeCache)

@jit.elidable
def num2dtype(space, num):
    return get_dtype_cache(space).dtypes_by_num[num]

def as_dtype(space, w_arg, allow_None=True):
    from pypy.module.micronumpy.casting import scalar2dtype
    # roughly equivalent to CNumPy's PyArray_DescrConverter2
    if not allow_None and space.is_none(w_arg):
        raise TypeError("Cannot create dtype from None here")
    if isinstance(w_arg, W_NDimArray):
        return w_arg.get_dtype()
    elif is_scalar_w(space, w_arg):
        result = scalar2dtype(space, w_arg)
        return result
    else:
        return space.interp_w(W_Dtype,
            space.call_function(space.gettypefor(W_Dtype), w_arg))

def is_scalar_w(space, w_arg):
    return (isinstance(w_arg, boxes.W_GenericBox) or
            space.isinstance_w(w_arg, space.w_int) or
            space.isinstance_w(w_arg, space.w_float) or
            space.isinstance_w(w_arg, space.w_complex) or
            space.isinstance_w(w_arg, space.w_bool))
