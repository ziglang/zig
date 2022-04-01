#include <stddef.h>
#include <Python.h>
#include "structmember.h" // for PyMemberDef
#include "hpy.h"
#include "hpy/runtime/ctx_type.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif

static int
sig2flags(HPyFunc_Signature sig)
{
    switch(sig) {
        case HPyFunc_VARARGS:  return METH_VARARGS;
        case HPyFunc_KEYWORDS: return METH_VARARGS | METH_KEYWORDS;
        case HPyFunc_NOARGS:   return METH_NOARGS;
        case HPyFunc_O:        return METH_O;
        default:               return -1;
    }
}

static inline int
is_bf_slot(HPyDef* def)
{
    return def->kind == HPyDef_Kind_Slot && (
        def->slot.slot == HPy_bf_getbuffer || def->slot.slot == HPy_bf_releasebuffer);
}

static HPy_ssize_t
HPyDef_count(HPyDef *defs[], HPyDef_Kind kind)
{
    HPy_ssize_t res = 0;
    if (defs == NULL)
        return res;
    for(int i=0; defs[i] != NULL; i++)
        if (defs[i]->kind == kind && !is_bf_slot(defs[i]))
            res++;
    return res;
}

static void
legacy_slots_count(PyType_Slot slots[], HPy_ssize_t *slot_count,
                   PyMethodDef **method_defs, PyMemberDef **member_defs,
                   PyGetSetDef **getset_defs)
{
    *slot_count = 0;
    *method_defs = NULL;
    *member_defs = NULL;
    *getset_defs = NULL;
    if (slots == NULL)
        return;
    for(int i=0; slots[i].slot != 0; i++)
        switch(slots[i].slot) {
        case Py_tp_methods:
            *method_defs = (PyMethodDef *)slots[i].pfunc;
            break;
        case Py_tp_members:
            *member_defs = (PyMemberDef *)slots[i].pfunc;
            break;
        case Py_tp_getset:
            *getset_defs = (PyGetSetDef *)slots[i].pfunc;
            break;
        default:
            (*slot_count)++;
            break;
        }
}

static int
hpy_slot_to_cpy_slot(HPySlot_Slot src)
{
    switch (src) {
        case HPy_tp_destroy: return Py_tp_dealloc;
        default: return src;   /* same numeric value by default */
    }
}


/*
 * Create a PyMethodDef which contains:
 *     1. All HPyMeth contained in hpyspec->defines
 *     2. All the PyMethodDef contained inside legacy_methods
 *
 * Notes:
 *     - This function is also called from ctx_module.c.
 *     - This malloc()s a result which will never be freed. Too bad
 */
_HPy_HIDDEN PyMethodDef *
create_method_defs(HPyDef *hpydefs[], PyMethodDef *legacy_methods)
{
    HPy_ssize_t hpymeth_count = HPyDef_count(hpydefs, HPyDef_Kind_Meth);
    // count the legacy methods
    HPy_ssize_t legacy_count = 0;
    if (legacy_methods != NULL) {
        while (legacy_methods[legacy_count].ml_name != NULL)
            legacy_count++;
    }
    HPy_ssize_t total_count = hpymeth_count + legacy_count;

    // allocate&fill the result
    PyMethodDef *result = PyMem_Calloc(total_count+1, sizeof(PyMethodDef));
    if (result == NULL) {
        PyErr_NoMemory();
        return NULL;
    }
    // copy the HPy methods
    int dst_idx = 0;
    if (hpydefs != NULL) {
        for(int i=0; hpydefs[i] != NULL; i++) {
            HPyDef *src = hpydefs[i];
            if (src->kind != HPyDef_Kind_Meth)
                continue;
            PyMethodDef *dst = &result[dst_idx++];
            dst->ml_name = src->meth.name;
            dst->ml_meth = src->meth.cpy_trampoline;
            dst->ml_flags = sig2flags(src->meth.signature);
            if (dst->ml_flags == -1) {
                PyMem_Free(result);
                PyErr_SetString(PyExc_ValueError,
                                "Unsupported HPyMeth signature");
                return NULL;
            }
            dst->ml_doc = src->meth.doc;
        }
    }
    // copy the legacy methods
    for(int i=0; i<legacy_count; i++)
        result[dst_idx++] = legacy_methods[i];
    result[dst_idx++] = (PyMethodDef){NULL, NULL, 0, NULL};
    if (dst_idx != total_count + 1)
        Py_FatalError("bogus count in create_method_defs");
    return result;
}

static PyMemberDef *
create_member_defs(HPyDef *hpydefs[], PyMemberDef *legacy_members, HPy_ssize_t base_member_offset)
{
    HPy_ssize_t hpymember_count = HPyDef_count(hpydefs, HPyDef_Kind_Member);
    // count the legacy members
    HPy_ssize_t legacy_count = 0;
    if (legacy_members != NULL) {
        while (legacy_members[legacy_count].name != NULL)
            legacy_count++;
    }
    HPy_ssize_t total_count = hpymember_count + legacy_count;

    // allocate&fill the result
    PyMemberDef *result = PyMem_Calloc(total_count+1, sizeof(PyMemberDef));
    if (result == NULL) {
        PyErr_NoMemory();
        return NULL;
    }
    // copy the HPy members
    int dst_idx = 0;
    if (hpydefs != NULL) {
        for(int i=0; hpydefs[i] != NULL; i++) {
            HPyDef *src = hpydefs[i];
            if (src->kind != HPyDef_Kind_Member)
                continue;
            PyMemberDef *dst = &result[dst_idx++];
            /* for Python <= 3.6 compatibility, we need to remove the 'const'
               qualifier from src->member.{name,doc} */
            dst->name = (char *)src->member.name;
            dst->type = src->member.type;
            dst->offset = src->member.offset + base_member_offset;
            dst->doc = (char *)src->member.doc;
            if (src->member.readonly)
                dst->flags = READONLY;
            else
                dst->flags = 0; // read-write
        }
    }
    // copy the legacy members
    for(int i=0; i<legacy_count; i++)
        result[dst_idx++] = legacy_members[i];
    result[dst_idx++] = (PyMemberDef){NULL};
    if (dst_idx != total_count + 1)
        Py_FatalError("bogus count in create_member_defs");
    return result;
}

static PyGetSetDef *
create_getset_defs(HPyDef *hpydefs[], PyGetSetDef *legacy_getsets)
{
    HPy_ssize_t hpygetset_count = HPyDef_count(hpydefs, HPyDef_Kind_GetSet);
    // count the legacy members
    HPy_ssize_t legacy_count = 0;
    if (legacy_getsets != NULL) {
        while (legacy_getsets[legacy_count].name != NULL)
            legacy_count++;
    }
    HPy_ssize_t total_count = hpygetset_count + legacy_count;

    // allocate&fill the result
    PyGetSetDef *result = PyMem_Calloc(total_count+1, sizeof(PyGetSetDef));
    if (result == NULL) {
        PyErr_NoMemory();
        return NULL;
    }
    // copy the HPy members
    int dst_idx = 0;
    if (hpydefs != NULL) {
        for(int i=0; hpydefs[i] != NULL; i++) {
            HPyDef *src = hpydefs[i];
            if (src->kind != HPyDef_Kind_GetSet)
                continue;
            PyGetSetDef *dst = &result[dst_idx++];
            /* for Python <= 3.6 compatibility, we need to remove the 'const'
               qualifier from src->getset.{name,doc} */
            dst->name = (char *)src->getset.name;
            dst->get = src->getset.getter_cpy_trampoline;
            dst->set = src->getset.setter_cpy_trampoline;
            dst->doc = (char *)src->getset.doc;
            dst->closure = src->getset.closure;
        }
    }
    // copy the legacy members
    for(int i=0; i<legacy_count; i++)
        result[dst_idx++] = legacy_getsets[i];
    result[dst_idx++] = (PyGetSetDef){NULL};
    if (dst_idx != total_count + 1)
        Py_FatalError("bogus count in create_getset_defs");
    return result;
}

static PyType_Slot *
create_slot_defs(HPyType_Spec *hpyspec, HPy_ssize_t base_member_offset)
{
    HPy_ssize_t hpyslot_count = HPyDef_count(hpyspec->defines, HPyDef_Kind_Slot);
    // add the legacy slots
    HPy_ssize_t legacy_slot_count = 0;
    PyMethodDef *legacy_method_defs = NULL;
    PyMemberDef *legacy_member_defs = NULL;
    PyGetSetDef *legacy_getset_defs = NULL;
    legacy_slots_count(hpyspec->legacy_slots, &legacy_slot_count,
                       &legacy_method_defs, &legacy_member_defs,
                       &legacy_getset_defs);

    // add slots to hold Py_tp_doc, Py_tp_methods, Py_tp_members, Py_tp_getset
    hpyslot_count += 3;
    if (hpyspec->doc != NULL) hpyslot_count++;

    // allocate the result PyType_Slot array
    HPy_ssize_t total_slot_count = hpyslot_count + legacy_slot_count;
    PyType_Slot *result = PyMem_Calloc(total_slot_count+1, sizeof(PyType_Slot));
    if (result == NULL) {
        PyErr_NoMemory();
        return NULL;
    }

    // fill the result with non-meth, non-member, non-getset slots
    int dst_idx = 0;
    if (hpyspec->defines != NULL) {
        for (int i = 0; hpyspec->defines[i] != NULL; i++) {
            HPyDef *src = hpyspec->defines[i];
            if (src->kind != HPyDef_Kind_Slot || is_bf_slot(src))
                continue;
            PyType_Slot *dst = &result[dst_idx++];
            dst->slot = hpy_slot_to_cpy_slot(src->slot.slot);
            dst->pfunc = src->slot.cpy_trampoline;
        }
    }

    // add a slot for the doc string if present
    if (hpyspec->doc != NULL) {
        result[dst_idx++] = (PyType_Slot){Py_tp_doc, (void *) hpyspec->doc};
    }

    // add the legacy slots (non-methods, non-members, non-getsets)
    if (hpyspec->legacy_slots != NULL) {
        PyType_Slot *legacy_slots = (PyType_Slot *)hpyspec->legacy_slots;
        for (int i = 0; legacy_slots[i].slot != 0; i++) {
            PyType_Slot *src = &legacy_slots[i];
            if (src->slot == Py_tp_methods || src->slot == Py_tp_members ||
                src->slot == Py_tp_getset)
                continue;
            PyType_Slot *dst = &result[dst_idx++];
            *dst = *src;
        }
    }

    // add the "real" methods
    PyMethodDef *pymethods = create_method_defs(hpyspec->defines, legacy_method_defs);
    if (pymethods == NULL) {
        PyMem_Free(result);
        return NULL;
    }
    result[dst_idx++] = (PyType_Slot){Py_tp_methods, pymethods};

    // add the "real" members
    PyMemberDef *pymembers = create_member_defs(hpyspec->defines, legacy_member_defs, base_member_offset);
    if (pymembers == NULL) {
        PyMem_Free(pymethods);
        PyMem_Free(result);
        return NULL;
    }
    result[dst_idx++] = (PyType_Slot){Py_tp_members, pymembers};

    // add the "real" getsets
    PyGetSetDef *pygetsets = create_getset_defs(hpyspec->defines, legacy_getset_defs);
    if (pygetsets == NULL) {
        PyMem_Free(pymembers);
        PyMem_Free(pymethods);
        PyMem_Free(result);
        return NULL;
    }
    result[dst_idx++] = (PyType_Slot){Py_tp_getset, pygetsets};

    // add the NULL sentinel at the end
    result[dst_idx++] = (PyType_Slot){0, NULL};
    if (dst_idx != total_slot_count + 1)
        Py_FatalError("bogus slot count in create_slot_defs");
    return result;
}

// XXX: This is a hack to work-around the missing Py_bf_getbuffer and
// Py_bf_releasebuffer before 3.9. We shouldn't use it on 3.9+.
static PyBufferProcs*
create_buffer_procs(HPyType_Spec *hpyspec)
{
    PyBufferProcs *buffer_procs = NULL;
    if (hpyspec->defines != NULL) {
        for (int i = 0; hpyspec->defines[i] != NULL; i++) {
            HPyDef *src = hpyspec->defines[i];
            if (src->kind != HPyDef_Kind_Slot)
                continue;
            switch (src->slot.slot) {
                case HPy_bf_getbuffer:
                    if (buffer_procs == NULL) {
                        buffer_procs = PyMem_Calloc(1, sizeof(PyBufferProcs));
                        if (buffer_procs == NULL) {
                            PyErr_NoMemory();
                            return NULL;
                        }
                    }
                    buffer_procs->bf_getbuffer = src->slot.cpy_trampoline;
                    break;
                case HPy_bf_releasebuffer:
                    if (buffer_procs == NULL) {
                        buffer_procs = PyMem_Calloc(1, sizeof(PyBufferProcs));
                        if (buffer_procs == NULL) {
                            PyErr_NoMemory();
                            return NULL;
                        }
                    }
                    buffer_procs->bf_releasebuffer = src->slot.cpy_trampoline;
                    break;
                default:
                    break;
            }
        }
    }
    return buffer_procs;
}

static int check_unknown_params(HPyType_SpecParam *params, const char *name)
{
    if (params == NULL)
        return 0;

    int found_base = 0, found_basestuple = 0;
    for (HPyType_SpecParam *p = params; p->kind != 0; p++) {
        switch (p->kind) {
            case HPyType_SpecParam_Base:
                found_base++;
                break;
            case HPyType_SpecParam_BasesTuple:
                found_basestuple++;
                break;

            default:
                PyErr_Format(PyExc_TypeError,
                    "unknown HPyType_SpecParam specification for '%s'",
                    name);
                return -1;
        }
    }
    if (found_basestuple > 1) {
        PyErr_SetString(PyExc_TypeError,
            "multiple specifications of HPyType_SpecParam_BasesTuple");
        return -1;
    }
    if (found_base && found_basestuple) {
        PyErr_SetString(PyExc_TypeError,
            "cannot specify both HPyType_SpecParam_Base and "
            "HPytype_SpecParam_BasesTuple");
        return -1;
    }
    return 0;
}

static int check_legacy_consistent(HPyType_Spec *hpyspec)
{
    if (hpyspec->legacy_slots && !hpyspec->legacy) {
        PyErr_SetString(PyExc_TypeError,
            "cannot specify .legacy_slots without setting .legacy=true");
        return -1;
    }
    if (hpyspec->flags & HPy_TPFLAGS_INTERNAL_PURE) {
        PyErr_SetString(PyExc_TypeError,
            "HPy_TPFLAGS_INTERNAL_PURE should not be used directly,"
            " set .legacy=true instead");
        return -1;
    }
    return 0;
}


static int check_inheritance_constraints(PyTypeObject *tp)
{
    int tp_pure = tp->tp_flags & HPy_TPFLAGS_INTERNAL_PURE;
    int tp_base_pure = tp->tp_base->tp_flags & HPy_TPFLAGS_INTERNAL_PURE;
    if (tp_pure) {
        // Pure types may inherit from:
        //
        // * pure types, or
        // * PyBaseObject_Type, or
        // * other builtin or legacy types as long as long as they do not
        //   access the struct layout (e.g. by using HPy_AsStruct or defining
        //   a deallocator with HPy_tp_destroy).
        //
        // It would be nice to relax these restrictions or check them here.
        // See https://github.com/hpyproject/hpy/issues/169 for details.
    }
    else {
        if (tp_base_pure) {
            PyErr_SetString(PyExc_TypeError,
                "A legacy type should not inherit its memory layout from a"
                " pure type");
            return -1;
        }
    }
    return 0;
}

static PyObject *build_bases_from_params(HPyType_SpecParam *params)
{
    if (params == NULL)
        return NULL;

    PyObject *tup;
    int found_base = 0;
    for (HPyType_SpecParam *p = params; p->kind != 0; p++) {
        switch (p->kind) {
            case HPyType_SpecParam_Base:
                /* count the base entries (multiple entries are fine) */
                found_base++;
                break;
            case HPyType_SpecParam_BasesTuple:
                /* if there is instead a complete base tuple, just return it */
                /* we increment the reference count of the tuple here to match
                   the reference counting on the tuple we create below when
                   there is no HPyType_SpecParam_BasesTuple */
                tup = _h2py(p->object);
                Py_INCREF(tup);
                return tup;
        }
    }
    if (found_base == 0)
        return NULL;

    tup = PyTuple_New(found_base);
    if (tup == NULL)
        return NULL;

    found_base = 0;
    for (HPyType_SpecParam *p = params; p->kind != 0; p++) {
        if (p->kind == HPyType_SpecParam_Base) {
            PyObject *base = _h2py(p->object);
            Py_INCREF(base);
            PyTuple_SET_ITEM(tup, found_base, base);
            found_base++;
        }
    }
    return tup;
}

_HPy_HIDDEN HPy
ctx_Type_FromSpec(HPyContext *ctx, HPyType_Spec *hpyspec,
                  HPyType_SpecParam *params)
{
    if (check_unknown_params(params, hpyspec->name) < 0) {
        return HPy_NULL;
    }
    if (check_legacy_consistent(hpyspec) < 0) {
        return HPy_NULL;
    }
    PyType_Spec *spec = PyMem_Calloc(1, sizeof(PyType_Spec));
    if (spec == NULL) {
        PyErr_NoMemory();
        return HPy_NULL;
    }
    int basicsize;
    HPy_ssize_t base_member_offset;
    unsigned long flags = hpyspec->flags;
    if (hpyspec->legacy != 0) {
        basicsize = hpyspec->basicsize;
        base_member_offset = 0;
        flags &= ~HPy_TPFLAGS_INTERNAL_PURE;
    }
    else {
        // HPyPure_PyObject_HEAD_SIZE ensures that the custom struct is
        // correctly aligned.
        if (hpyspec->basicsize != 0) {
            basicsize = hpyspec->basicsize + HPyPure_PyObject_HEAD_SIZE;
            base_member_offset = HPyPure_PyObject_HEAD_SIZE;
        }
        else {
            // If basicsize is 0, it is inherited from the parent type.
            // Calling HPy_AsStruct on an inherited type only makes sense if
            // the parent type is already an HPy extension type.
            basicsize = 0;
            base_member_offset = 0;
        }
        flags |= HPy_TPFLAGS_INTERNAL_PURE;
    }
    spec->name = hpyspec->name;
    spec->basicsize = basicsize;
    spec->flags = flags;
    spec->itemsize = hpyspec->itemsize;
    spec->slots = create_slot_defs(hpyspec, base_member_offset);
    if (spec->slots == NULL) {
        PyMem_Free(spec);
        return HPy_NULL;
    }
    PyObject *bases = build_bases_from_params(params);
    if (PyErr_Occurred()) {
        PyMem_Free(spec->slots);
        PyMem_Free(spec);
        return HPy_NULL;
    }
    PyObject *result = PyType_FromSpecWithBases(spec, bases);
    /* note that we do NOT free the memory which was allocated by
       create_method_defs, because that one is referenced internally by
       CPython (which probably assumes it's statically allocated) */
    Py_XDECREF(bases);
    PyMem_Free(spec->slots);
    PyMem_Free(spec);
    if (result == NULL) {
        return HPy_NULL;
    }
    PyBufferProcs* buffer_procs = create_buffer_procs(hpyspec);
    if (buffer_procs) {
        ((PyTypeObject*)result)->tp_as_buffer = buffer_procs;
    } else {
        if (PyErr_Occurred()) {
            Py_DECREF(result);
            return HPy_NULL;
        }
    }
    if (check_inheritance_constraints((PyTypeObject *) result) < 0) {
        Py_DECREF(result);
        return HPy_NULL;
    }
    return _py2h(result);
}

_HPy_HIDDEN HPy
ctx_New(HPyContext *ctx, HPy h_type, void **data)
{
    PyTypeObject *tp = (PyTypeObject*) _h2py(h_type);
    assert(tp != NULL);
    if (!PyType_Check(tp)) {
        PyErr_SetString(PyExc_TypeError, "HPy_New arg 1 must be a type");
        return HPy_NULL;
    }

    PyObject *result = PyObject_New(PyObject, tp);
    if (!result)
        return HPy_NULL;
#if PY_VERSION_HEX < 0x03080000
    // Workaround for Python issue 35810; no longer necessary in Python 3.8
    // TODO: Remove this workaround once we no longer support Python versions older than 3.8
    Py_INCREF(tp);
#endif

    if (tp->tp_flags & HPy_TPFLAGS_INTERNAL_PURE) {
        // For pure HPy custom types, we return a pointer to only the custom
        // struct data, without the hidden PyObject header.
        *data = (void*) ((char*) result + HPyPure_PyObject_HEAD_SIZE);
    }
    else {
        *data = (void*) result;
    }
    return _py2h(result);
}

_HPy_HIDDEN HPy
ctx_Type_GenericNew(HPyContext *ctx, HPy h_type, HPy *args, HPy_ssize_t nargs, HPy kw)
{
    PyObject *tp = _h2py(h_type);
    assert(tp != NULL);
    if (!PyType_Check(tp)) {
        PyErr_SetString(PyExc_TypeError, "HPy_Type_GenericNew arg 1 must be a type");
        return HPy_NULL;
    }

    PyObject *res = ((PyTypeObject*) tp)->tp_alloc((PyTypeObject*) tp, 0);
    return _py2h(res);
}

_HPy_HIDDEN void*
ctx_AsStruct(HPyContext *ctx, HPy h)
{
    return (void *) ((char *) _h2py(h) + HPyPure_PyObject_HEAD_SIZE);
}

_HPy_HIDDEN void*
ctx_AsStructLegacy(HPyContext *ctx, HPy h)
{
    return _h2py(h);
}
