"""
How does this work ? The hash is computed from a list which contains all the
information specific to a type. The hard work is to build the list
(_array_descr_walk). The list is built as follows:
     * If the dtype is builtin (no fields, no subarray), then the list
     contains 6 items which uniquely define one dtype (_array_descr_builtin)
     * If the dtype is a compound array, one walk on each field. For each
     field, we append title, names, offset to the final list used for
     hashing, and then append the list recursively built for each
     corresponding dtype (_array_descr_walk_fields)
     * If the dtype is a subarray, one adds the shape tuple to the list, and
     then append the list recursively built for each corresponding dtype
     (_array_descr_walk_subarray)
"""
from pypy.interpreter.error import OperationError, oefmt
from pypy.module.micronumpy import types, boxes, support, constants as NPY

def _normalize_byteorder(descr):
    return NPY.NATBYTE if descr.is_native() else NPY.OPPBYTE

def _array_descr_builtin(space, descr):
    nbyteorder = _normalize_byteorder(descr)

    # For builtin type, hash relies on : kind + byeorder + flags +
    # type_num + elsize + alignment
    nt = space.newtext
    ni = space.newint
    return [nt(descr.kind), nt(nbyteorder), ni(descr.flags), 
                           ni(descr.elsize), ni(descr.alignment)]

def _array_descr_walk_fields(space, names, fields):
    from pypy.module.micronumpy.descriptor import W_Dtype
    res = []
    for key, title in names:
        # For each field, add the key, descr, offset
        try:
            value = fields[key]
        except KeyError:
            raise oefmt(space.w_SystemError,
                        "(Hash) names and fields inconsistent")
        if not isinstance(key, str):
            raise oefmt(space.w_SystemError,
                        "(Hash) key of dtype dict not a string ???")
        if not isinstance(value, tuple):
            raise oefmt(space.w_SystemError,
                        "(Hash) value of dtype dict not a dtype ???")
        if len(value) < 2:
            raise oefmt(space.w_SystemError,
                        "(Hash) Less than 2 items in dtype dict ???")
        res.append(space.newtext(key))
        if not isinstance(value[1], W_Dtype):
            raise oefmt(space.w_SystemError,
                        "(Hash) item in compound dtype tuple not a descr ???")
        
        sub_res = _array_descr_walk(space, value[1])
        for v in sub_res:
            res.append(v)
        if not isinstance(value[0], int):
            raise oefmt(space.w_SystemError,
                        "(Hash) item in compound dtype tuple not an int ???")
        res.append(space.newint(value[0]))
        if title:
            res.append(space.newtext(title))
    return res

def _array_descr_walk_subarray(space, descr):
    # Add shape and descr itself to the list of object to hash
    # descr.shape will always be a sequence in micronumpy, in
    # numpy it can be an int
    res = []
    for item in descr.shape:
        res.append(space.newint(item))
    sub_res = _array_descr_walk(space, descr.subdtype)
    for v in sub_res:
        res.append(v)

def _array_descr_walk(space, descr):
    """Root function to walk into a dtype. May be called recursively
    """
    if descr.fields:
        return _array_descr_walk_fields(space, descr.names, descr.fields)
    if descr.subdtype:
        return _array_descr_walk_subarray(space, descr.subdtype)
    return _array_descr_builtin(space, descr)
     


