import sys
import _rawffi
from _ctypes.basics import _CData, _CDataMeta, keepalive_key,\
     store_reference, ensure_objects, CArgObject
from _ctypes.array import Array, swappedorder, byteorder
from _ctypes.pointer import _Pointer
import inspect, __pypy__


def names_and_fields(self, _fields_, superclass, anonymous_fields=None):
    # _fields_: list of (name, ctype, [optional_bitfield])
    if isinstance(_fields_, tuple):
        _fields_ = list(_fields_)
    for f in _fields_:
        tp = f[1]
        if not isinstance(tp, _CDataMeta):
            raise TypeError("Expected CData subclass, got %s" % (tp,))
        if isinstance(tp, StructOrUnionMeta):
            tp._make_final()
        if len(f) == 3:
            if (not hasattr(tp, '_type_')
                or not isinstance(tp._type_, str)
                or tp._type_ not in "iIhHbBlLqQ"):
                #XXX: are those all types?
                #     we just dont get the type name
                #     in the interp level thrown TypeError
                #     from rawffi if there are more
                raise TypeError('bit fields not allowed for type ' + tp.__name__)

    all_fields = []
    for cls in reversed(inspect.getmro(superclass)):
        # The first field comes from the most base class
        all_fields.extend(getattr(cls, '_fields_', []))
    all_fields.extend(_fields_)
    names = [f[0] for f in all_fields]
    rawfields = []
    for f in all_fields:
        if len(f) > 2:
            rawfields.append((f[0], f[1]._ffishape_, f[2]))
        else:
            rawfields.append((f[0], f[1]._ffishape_))

    # hack for duplicate field names
    already_seen = set()
    names1 = names
    names = []
    for f in names1:
        if f not in already_seen:
            names.append(f)
            already_seen.add(f)
    already_seen = set()
    for i in reversed(range(len(rawfields))):
        if rawfields[i][0] in already_seen:
            rawfields[i] = (('$DUP%d$%s' % (i, rawfields[i][0]),)
                            + rawfields[i][1:])
        already_seen.add(rawfields[i][0])
    # /hack

    _set_shape(self, rawfields, self._is_union)

    fields = {}
    for i, field in enumerate(all_fields):
        name = field[0]
        value = field[1]
        is_bitfield = (len(field) == 3)
        fields[name] = Field(name,
                             self._ffistruct_.fieldoffset(name),
                             self._ffistruct_.fieldsize(name),
                             value, i, is_bitfield)

    if anonymous_fields:
        resnames = []
        for i, field in enumerate(all_fields):
            name = field[0]
            value = field[1]
            is_bitfield = (len(field) == 3)
            startpos = self._ffistruct_.fieldoffset(name)
            if name in anonymous_fields:
                for subname in value._names_:
                    resnames.append(subname)
                    subfield = getattr(value, subname)
                    relpos = startpos + subfield.offset
                    subvalue = subfield.ctype
                    fields[subname] = Field(subname,
                                            relpos, subvalue._sizeofinstances(),
                                            subvalue, i, is_bitfield,
                                            inside_anon_field=fields[name])
            else:
                resnames.append(name)
        names = resnames
    self._names_ = names
    for name, field in fields.items():
        setattr(self, name, field)


class Field(object):
    def __init__(self, name, offset, size, ctype, num, is_bitfield,
                 inside_anon_field=None):
        self.__dict__['name'] = name
        self.__dict__['offset'] = offset
        self.__dict__['size'] = size
        self.__dict__['ctype'] = ctype
        self.__dict__['num'] = num
        self.__dict__['is_bitfield'] = is_bitfield
        self.__dict__['inside_anon_field'] = inside_anon_field

    def __setattr__(self, name, value):
        raise AttributeError(name)

    def __repr__(self):
        return "<Field '%s' offset=%d size=%d>" % (self.name, self.offset,
                                                   self.size)

    def __get__(self, obj, cls=None):
        if obj is None:
            return self
        if self.inside_anon_field is not None:
            return getattr(self.inside_anon_field.__get__(obj), self.name)
        if self.is_bitfield:
            # bitfield member, use direct access
            return obj._buffer.__getattr__(self.name)
        elif not isinstance(obj, _CData):
            raise(TypeError, 'not a ctype instance') 
        else:
            fieldtype = self.ctype
            offset = self.num
            suba = obj._subarray(fieldtype, self.name)
            return fieldtype._CData_output(suba, obj, offset)

    def __set__(self, obj, value):
        if self.inside_anon_field is not None:
            setattr(self.inside_anon_field.__get__(obj), self.name, value)
            return
        fieldtype = self.ctype
        cobj = fieldtype.from_param(value)
        key = keepalive_key(self.num)
        if issubclass(fieldtype, _Pointer) and isinstance(cobj, Array):
            # if our value is an Array we need the whole thing alive
            store_reference(obj, key, cobj)
        elif ensure_objects(cobj) is not None:
            store_reference(obj, key, cobj._objects)
        arg = cobj._get_buffer_value()
        if fieldtype._fficompositesize_ is not None:
            from ctypes import memmove
            dest = obj._buffer.fieldaddress(self.name)
            memmove(dest, arg, fieldtype._fficompositesize_)
        elif not isinstance(obj, _CData):
            raise(TypeError, 'not a ctype instance') 
        else:
            obj._buffer.__setattr__(self.name, arg)



def _set_shape(tp, rawfields, is_union=False):
    tp._ffistruct_ = _rawffi.Structure(rawfields, is_union,
                                      getattr(tp, '_pack_', 0))
    tp._ffiargshape_ = tp._ffishape_ = (tp._ffistruct_, 1)
    tp._fficompositesize_ = tp._ffistruct_.size


def struct_setattr(self, name, value):
    if name == '_fields_':
        if self.__dict__.get('_fields_', None) is not None:
            raise AttributeError("_fields_ is final")
        if self in [f[1] for f in value]:
            raise AttributeError("Structure or union cannot contain itself")
        if self._ffiargtype is not None:
            raise NotImplementedError("Too late to set _fields_: we already "
                        "said to libffi that the structure type %s is opaque"
                        % (self,))
        names_and_fields(
            self,
            value, self.__bases__[0],
            self.__dict__.get('_anonymous_', None))
        _CDataMeta.__setattr__(self, '_fields_', value)
        return
    _CDataMeta.__setattr__(self, name, value)


class StructOrUnionMeta(_CDataMeta):
    def __new__(self, name, cls, typedict):
        res = type.__new__(self, name, cls, typedict)
        if hasattr(res, '_swappedbytes_') and '_fields_' in typedict:
            # Activate the stdlib ctypes._swapped_meta.__setattr__ to convert fields
            tmp = res._fields_
            delattr(res, '_fields_')
            setattr(res, '_fields_', tmp)
        if "_abstract_" in typedict:
            return res
        cls = cls or (object,)
        if isinstance(cls[0], StructOrUnionMeta):
            cls[0]._make_final()
        if '_pack_' in typedict:
            if not 0 <= typedict['_pack_'] < 2**31:
                raise ValueError("_pack_ must be a non-negative integer")
        if '_fields_' in typedict:
            if not hasattr(typedict.get('_anonymous_', []), '__iter__'):
                raise TypeError("Anonymous field must be iterable")
            for item in typedict.get('_anonymous_', []):
                if item not in dict(typedict['_fields_']):
                    raise AttributeError("Anonymous field not found")
            names_and_fields(
                res,
                typedict['_fields_'], cls[0],
                typedict.get('_anonymous_', None))
        return res

    def _make_final(self):
        if self is StructOrUnion:
            return
        if '_fields_' not in self.__dict__:
            self._fields_ = []  # As a side-effet, this also sets the ffishape.

    __setattr__ = struct_setattr

    def _is_abstract(self):
        return False

    def from_address(self, address):
        instance = StructOrUnion.__new__(self)
        if isinstance(address, _rawffi.StructureInstance):
            address = address.buffer
        # fix the address: turn it into as unsigned, in case it is negative
        address = address & (sys.maxsize * 2 + 1)
        instance.__dict__['_buffer'] = self._ffistruct_.fromaddress(address)
        return instance

    def _sizeofinstances(self):
        if not hasattr(self, '_ffistruct_'):
            return 0
        return self._ffistruct_.size

    def _alignmentofinstances(self):
        return self._ffistruct_.alignment

    def from_param(self, value):
        if isinstance(value, tuple):
            try:
                value = self(*value)
            except Exception as e:
                # XXX CPython does not even respect the exception type
                raise RuntimeError("(%s) %s: %s" % (self.__name__, type(e), e))
        return _CDataMeta.from_param(self, value)

    def _CData_output(self, resarray, base=None, index=-1):
        res = StructOrUnion.__new__(self)
        ffistruct = self._ffistruct_.fromaddress(resarray.buffer)
        res.__dict__['_buffer'] = ffistruct
        res.__dict__['_base'] = base
        res.__dict__['_index'] = index
        return res

    def _CData_retval(self, resbuffer):
        res = StructOrUnion.__new__(self)
        res.__dict__['_buffer'] = resbuffer
        res.__dict__['_base'] = None
        res.__dict__['_index'] = -1
        return res

    def _getformat(self):
        if self._is_union or hasattr(self, '_pack_'):
            return "B"
        if hasattr(self, '_swappedbytes_'):
            bo = swappedorder[sys.byteorder]
        else:
            bo = byteorder[sys.byteorder]
        flds = []
        cum_size = 0
        for name, obj in self._fields_:
            padding = self._ffistruct_.fieldoffset(name) - cum_size
            if padding:
                flds.append('%dx' % padding)
            flds.append(obj._getformat())
            flds.append(':')
            flds.append(name)
            flds.append(':')
            cum_size += self._ffistruct_.fieldsize(name)
        return 'T{' + ''.join(flds) + '}'

class StructOrUnion(_CData, metaclass=StructOrUnionMeta):

    def __new__(cls, *args, **kwds):
        from _ctypes import union
        if ('_abstract_' in cls.__dict__ or cls is Structure
                                         or cls is union.Union):
            raise TypeError("abstract class")
        if hasattr(cls, '_swappedbytes_'):
            names_and_fields(cls, cls._fields_, _CData, cls.__dict__.get('_anonymous_', None))
        self = super(_CData, cls).__new__(cls)
        if hasattr(cls, '_ffistruct_'):
            self.__dict__['_buffer'] = self._ffistruct_(autofree=True)
        return self

    def __init__(self, *args, **kwds):
        type(self)._make_final()
        if len(args) > len(self._names_):
            raise TypeError("too many initializers")
        for name, arg in zip(self._names_, args):
            if name in kwds:
                raise TypeError("duplicate value for argument %r" % (
                    name,))
            self.__setattr__(name, arg)
        for name, arg in kwds.items():
            self.__setattr__(name, arg)
    _init_no_arg_ = __init__

    def _subarray(self, fieldtype, name):
        """Return a _rawffi array of length 1 whose address is the same as
        the address of the field 'name' of self."""
        address = self._buffer.fieldaddress(name)
        A = _rawffi.Array(fieldtype._ffishape_)
        return A.fromaddress(address, 1)

    def _get_buffer_for_param(self):
        return self

    def _get_buffer_value(self):
        return self._buffer.buffer

    def _copy_to(self, addr):
        from ctypes import memmove
        origin = self._get_buffer_value()
        memmove(addr, origin, self._fficompositesize_)

    def _to_ffi_param(self):
        # Do not copy, like CPython
        return self._buffer

    def __buffer__(self, flags):
        fmt = type(self)._getformat()
        itemsize = type(self)._sizeofinstances()
        return __pypy__.newmemoryview(memoryview(self._buffer), itemsize, fmt, ())

class StructureMeta(StructOrUnionMeta):
    _is_union = False


class Structure(StructOrUnion, metaclass=StructureMeta):
    pass
