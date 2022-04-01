from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rlib.rdynload import DLLHANDLE, dlsym, dlclose

from pypy.interpreter.error import oefmt

from pypy.module._cffi_backend.parse_c_type import (
    _CFFI_OPCODE_T, GLOBAL_S, CDL_INTCONST_S, STRUCT_UNION_S, FIELD_S,
    ENUM_S, TYPENAME_S, ll_set_cdl_realize_global_int)
from pypy.module._cffi_backend.realize_c_type import getop
from pypy.module._cffi_backend.lib_obj import W_LibObject
from pypy.module._cffi_backend import cffi_opcode, cffi1_module, misc

class W_DlOpenLibObject(W_LibObject):

    def __init__(self, ffi, w_filename, flags):
        space = ffi.space
        fname, handle, autoclose = misc.dlopen_w(space, w_filename, flags)
        W_LibObject.__init__(self, ffi, fname)
        self.libhandle = handle
        if autoclose:
            self.register_finalizer(space)

    def _finalize_(self):
        h = self.libhandle
        if h != rffi.cast(DLLHANDLE, 0):
            self.libhandle = rffi.cast(DLLHANDLE, 0)
            dlclose(h)

    def cdlopen_fetch(self, name):
        if not self.libhandle:
            raise oefmt(self.ffi.w_FFIError, "library '%s' has been closed",
                        self.libname)
        try:
            cdata = dlsym(self.libhandle, name)
            found = bool(cdata)
        except KeyError:
            found = False
        if not found:
            raise oefmt(self.ffi.w_FFIError,
                        "symbol '%s' not found in library '%s'",
                        name, self.libname)
        return rffi.cast(rffi.CCHARP, cdata)

    def cdlopen_close(self):
        libhandle = self.libhandle
        self.libhandle = rffi.cast(DLLHANDLE, 0)

        if not libhandle:
            return
        self.may_unregister_rpython_finalizer(self.ffi.space)

        # Clear the dict to force further accesses to do cdlopen_fetch()
        # again, and fail because the library was closed.  Note that the
        # JIT may have elided some accesses, and so has addresses as
        # constants.  We could work around it with a quasi-immutable flag
        # but unsure it's worth it.
        self.dict_w.clear()

        if dlclose(libhandle) < 0:
            raise oefmt(self.ffi.w_FFIError, "error closing library '%s'",
                        self.libname)


class StringDecoder:
    def __init__(self, ffi, string):
        self.ffi = ffi
        self.string = string
        self.pos = 0

    def next_4bytes(self):
        pos = self.pos
        src = ord(self.string[pos])
        if src >= 0x80:
            src -= 0x100
        src = ((src << 24) |
               (ord(self.string[pos + 1]) << 16) |
               (ord(self.string[pos + 2]) << 8 ) |
               (ord(self.string[pos + 3])      ))
        self.pos = pos + 4
        return src

    def next_opcode(self):
        return rffi.cast(_CFFI_OPCODE_T, self.next_4bytes())

    def next_name(self):
        frm = self.pos
        i = self.string.find('\x00', frm)
        if i < 0:
            i = len(self.string)
        self.pos = i + 1
        p = rffi.str2charp(self.string[frm : i])
        self.ffi._finalizer.free_mems.append(p)
        return p


def allocate(ffi, nbytes):
    nbytes = llmemory.raw_malloc_usage(nbytes)
    if not we_are_translated():
        nbytes *= 2   # hack to account for the fact that raw_malloc_usage()
                      # returns an approximation, ignoring padding and alignment
    p = lltype.malloc(rffi.CCHARP.TO, nbytes, flavor='raw', zero=True)
    ffi._finalizer.free_mems.append(p)
    return p

@specialize.arg(1)
def allocate_array(ffi, OF, nitems):
    nbytes = llmemory.raw_malloc_usage(rffi.sizeof(OF))
    p = allocate(ffi, nitems * nbytes)
    return rffi.cast(rffi.CArrayPtr(OF), p)


def ffiobj_init(ffi, module_name, version, types, w_globals,
                w_struct_unions, w_enums, w_typenames, w_includes):
    space = ffi.space

    # xxx force ll2ctypes conversion here.  This appears to be needed,
    # otherwise ll2ctypes explodes.  I don't want to know :-(
    rffi.cast(lltype.Signed, ffi.ctxobj)

    if version == -1 and not types:
        return
    if not (cffi1_module.VERSION_MIN <= version <= cffi1_module.VERSION_MAX):
        raise oefmt(space.w_ImportError,
            "cffi out-of-line Python module '%s' has unknown version %s",
            module_name, hex(version))

    if types:
        # unpack a string of 4-byte entries into an array of _cffi_opcode_t
        n = len(types) // 4
        ntypes = allocate_array(ffi, _CFFI_OPCODE_T, n)
        decoder = StringDecoder(ffi, types)
        for i in range(n):
            ntypes[i] = decoder.next_opcode()
        ffi.ctxobj.ctx.c_types = ntypes
        rffi.setintfield(ffi.ctxobj.ctx, 'c_num_types', n)
        ffi.cached_types = [None] * n

    if w_globals is not None:
        # unpack a tuple alternating strings and ints, each two together
        # describing one global_s entry with no specified address or size.
        # The int is only used with integer constants.
        globals_w = space.fixedview(w_globals)
        n = len(globals_w) // 2
        size = n * rffi.sizeof(GLOBAL_S) + n * rffi.sizeof(CDL_INTCONST_S)
        p = allocate(ffi, size)
        nglobs = rffi.cast(rffi.CArrayPtr(GLOBAL_S), p)
        p = rffi.ptradd(p, llmemory.raw_malloc_usage(n * rffi.sizeof(GLOBAL_S)))
        nintconsts = rffi.cast(rffi.CArrayPtr(CDL_INTCONST_S), p)
        for i in range(n):
            decoder = StringDecoder(ffi, space.bytes_w(globals_w[i * 2]))
            nglobs[i].c_type_op = decoder.next_opcode()
            nglobs[i].c_name = decoder.next_name()
            op = getop(nglobs[i].c_type_op)
            if op == cffi_opcode.OP_CONSTANT_INT or op == cffi_opcode.OP_ENUM:
                w_integer = globals_w[i * 2 + 1]
                ll_set_cdl_realize_global_int(nglobs[i])
                bigint = space.bigint_w(w_integer)
                ullvalue = bigint.ulonglongmask()
                rffi.setintfield(nintconsts[i], 'neg', int(bigint.sign <= 0))
                rffi.setintfield(nintconsts[i], 'value', ullvalue)
        ffi.ctxobj.ctx.c_globals = nglobs
        rffi.setintfield(ffi.ctxobj.ctx, 'c_num_globals', n)

    if w_struct_unions is not None:
        # unpack a tuple of struct/unions, each described as a sub-tuple;
        # the item 0 of each sub-tuple describes the struct/union, and
        # the items 1..N-1 describe the fields, if any
        struct_unions_w = space.fixedview(w_struct_unions)
        n = len(struct_unions_w)
        nftot = 0     # total number of fields
        for i in range(n):
            nftot += space.len_w(struct_unions_w[i]) - 1
        nstructs = allocate_array(ffi, STRUCT_UNION_S, n)
        nfields = allocate_array(ffi, FIELD_S, nftot)
        nf = 0
        for i in range(n):
            # 'desc' is the tuple of strings (desc_struct, desc_field_1, ..)
            desc = space.fixedview(struct_unions_w[i])
            nf1 = len(desc) - 1
            decoder = StringDecoder(ffi, space.bytes_w(desc[0]))
            rffi.setintfield(nstructs[i], 'c_type_index', decoder.next_4bytes())
            flags = decoder.next_4bytes()
            rffi.setintfield(nstructs[i], 'c_flags', flags)
            nstructs[i].c_name = decoder.next_name()
            if flags & (cffi_opcode.F_OPAQUE | cffi_opcode.F_EXTERNAL):
                rffi.setintfield(nstructs[i], 'c_size', -1)
                rffi.setintfield(nstructs[i], 'c_alignment', -1)
                rffi.setintfield(nstructs[i], 'c_first_field_index', -1)
                rffi.setintfield(nstructs[i], 'c_num_fields', 0)
                assert nf1 == 0
            else:
                rffi.setintfield(nstructs[i], 'c_size', -2)
                rffi.setintfield(nstructs[i], 'c_alignment', -2)
                rffi.setintfield(nstructs[i], 'c_first_field_index', nf)
                rffi.setintfield(nstructs[i], 'c_num_fields', nf1)
            for j in range(nf1):
                decoder = StringDecoder(ffi, space.bytes_w(desc[j + 1]))
                # this 'decoder' is for one of the other strings beyond
                # the first one, describing one field each
                type_op = decoder.next_opcode()
                nfields[nf].c_field_type_op = type_op
                rffi.setintfield(nfields[nf], 'c_field_offset', -1)
                if getop(type_op) != cffi_opcode.OP_NOOP:
                    field_size = decoder.next_4bytes()
                else:
                    field_size = -1
                rffi.setintfield(nfields[nf], 'c_field_size', field_size)
                nfields[nf].c_name = decoder.next_name()
                nf += 1
        assert nf == nftot
        ffi.ctxobj.ctx.c_struct_unions = nstructs
        ffi.ctxobj.ctx.c_fields = nfields
        rffi.setintfield(ffi.ctxobj.ctx, 'c_num_struct_unions', n)

    if w_enums:
        # unpack a tuple of strings, each of which describes one enum_s entry
        enums_w = space.fixedview(w_enums)
        n = len(enums_w)
        nenums = allocate_array(ffi, ENUM_S, n)
        for i in range(n):
            decoder = StringDecoder(ffi, space.bytes_w(enums_w[i]))
            rffi.setintfield(nenums[i], 'c_type_index', decoder.next_4bytes())
            rffi.setintfield(nenums[i], 'c_type_prim', decoder.next_4bytes())
            nenums[i].c_name = decoder.next_name()
            nenums[i].c_enumerators = decoder.next_name()
        ffi.ctxobj.ctx.c_enums = nenums
        rffi.setintfield(ffi.ctxobj.ctx, 'c_num_enums', n)

    if w_typenames:
        # unpack a tuple of strings, each of which describes one typename_s
        # entry
        typenames_w = space.fixedview(w_typenames)
        n = len(typenames_w)
        ntypenames = allocate_array(ffi, TYPENAME_S, n)
        for i in range(n):
            decoder = StringDecoder(ffi, space.bytes_w(typenames_w[i]))
            rffi.setintfield(ntypenames[i],'c_type_index',decoder.next_4bytes())
            ntypenames[i].c_name = decoder.next_name()
        ffi.ctxobj.ctx.c_typenames = ntypenames
        rffi.setintfield(ffi.ctxobj.ctx, 'c_num_typenames', n)

    if w_includes:
        from pypy.module._cffi_backend.ffi_obj import W_FFIObject
        #
        for w_parent_ffi in space.fixedview(w_includes):
            parent_ffi = space.interp_w(W_FFIObject, w_parent_ffi)
            ffi.included_ffis_libs.append((parent_ffi, None))
