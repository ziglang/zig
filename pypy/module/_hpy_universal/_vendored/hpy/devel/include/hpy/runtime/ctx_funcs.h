#ifndef HPY_RUNTIME_CTX_FUNCS_H
#define HPY_RUNTIME_CTX_FUNCS_H

// This file contains the prototypes for all the functions defined in
// hpy/devel/src/runtime/ctx_*.c

#include "hpy.h"

// ctx_bytes.c
_HPy_HIDDEN HPy ctx_Bytes_FromStringAndSize(HPyContext *ctx, const char *v,
                                            HPy_ssize_t len);

// ctx_call.c
_HPy_HIDDEN HPy ctx_CallTupleDict(HPyContext *ctx, HPy callable, HPy args, HPy kw);

// ctx_err.c
_HPy_HIDDEN int ctx_Err_Occurred(HPyContext *ctx);

// ctx_listbuilder.c
_HPy_HIDDEN HPyListBuilder ctx_ListBuilder_New(HPyContext *ctx,
                                               HPy_ssize_t initial_size);
_HPy_HIDDEN void ctx_ListBuilder_Set(HPyContext *ctx, HPyListBuilder builder,
                                     HPy_ssize_t index, HPy h_item);
_HPy_HIDDEN HPy ctx_ListBuilder_Build(HPyContext *ctx, HPyListBuilder builder);
_HPy_HIDDEN void ctx_ListBuilder_Cancel(HPyContext *ctx, HPyListBuilder builder);

// ctx_module.c
_HPy_HIDDEN HPy ctx_Module_Create(HPyContext *ctx, HPyModuleDef *hpydef);

// ctx_object.c
_HPy_HIDDEN void ctx_Dump(HPyContext *ctx, HPy h);
_HPy_HIDDEN int ctx_TypeCheck(HPyContext *ctx, HPy h_obj, HPy h_type);
_HPy_HIDDEN int ctx_Is(HPyContext *ctx, HPy h_obj, HPy h_other);
_HPy_HIDDEN HPy ctx_GetItem_i(HPyContext *ctx, HPy obj, HPy_ssize_t idx);
_HPy_HIDDEN HPy ctx_GetItem_s(HPyContext *ctx, HPy obj, const char *key);
_HPy_HIDDEN int ctx_SetItem_i(HPyContext *ctx, HPy obj, HPy_ssize_t idx, HPy value);
_HPy_HIDDEN int ctx_SetItem_s(HPyContext *ctx, HPy obj, const char *key, HPy value);

// ctx_tracker.c
_HPy_HIDDEN HPyTracker ctx_Tracker_New(HPyContext *ctx, HPy_ssize_t size);
_HPy_HIDDEN int ctx_Tracker_Add(HPyContext *ctx, HPyTracker ht, HPy h);
_HPy_HIDDEN void ctx_Tracker_ForgetAll(HPyContext *ctx, HPyTracker ht);
_HPy_HIDDEN void ctx_Tracker_Close(HPyContext *ctx, HPyTracker ht);

// ctx_tuplebuilder.c
_HPy_HIDDEN HPyTupleBuilder ctx_TupleBuilder_New(HPyContext *ctx,
                                                 HPy_ssize_t initial_size);
_HPy_HIDDEN void ctx_TupleBuilder_Set(HPyContext *ctx, HPyTupleBuilder builder,
                                      HPy_ssize_t index, HPy h_item);
_HPy_HIDDEN HPy ctx_TupleBuilder_Build(HPyContext *ctx, HPyTupleBuilder builder);
_HPy_HIDDEN void ctx_TupleBuilder_Cancel(HPyContext *ctx,
                                         HPyTupleBuilder builder);

// ctx_tuple.c
_HPy_HIDDEN HPy ctx_Tuple_FromArray(HPyContext *ctx, HPy items[], HPy_ssize_t n);

// ctx_type.c
_HPy_HIDDEN void* ctx_AsStruct(HPyContext *ctx, HPy h);
_HPy_HIDDEN void* ctx_AsStructLegacy(HPyContext *ctx, HPy h);
_HPy_HIDDEN HPy ctx_Type_FromSpec(HPyContext *ctx, HPyType_Spec *hpyspec,
                                  HPyType_SpecParam *params);
_HPy_HIDDEN HPy ctx_New(HPyContext *ctx, HPy h_type, void **data);
_HPy_HIDDEN HPy ctx_Type_GenericNew(HPyContext *ctx, HPy h_type, HPy *args,
                                    HPy_ssize_t nargs, HPy kw);

#endif /* HPY_RUNTIME_CTX_FUNCS_H */
