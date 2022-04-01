from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper import rclass


Size2Type = [None] * 100
Type2Size = {}

def get_size(TYPE):
    try:
        return Type2Size[TYPE]
    except KeyError:
        size = len(Size2Type)
        Size2Type.append(TYPE)
        Type2Size[TYPE] = size
        return size

TokenToField = [None] * 100
FieldToToken = {}

def get_field_token(STRUCT, fieldname):
    try:
        return FieldToToken[STRUCT, fieldname]
    except KeyError:
        token = (len(TokenToField), get_size(getattr(STRUCT, fieldname)))
        TokenToField.append((STRUCT, fieldname))
        FieldToToken[STRUCT, fieldname] = token
        return token
get_field_token(rclass.OBJECT, 'typeptr')     # force the index 1 for this
