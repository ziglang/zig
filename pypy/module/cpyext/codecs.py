from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.api import cpython_api, PyObject, CONST_STRING
from pypy.module._codecs import interp_codecs

@cpython_api([CONST_STRING, CONST_STRING], PyObject)
def PyCodec_IncrementalEncoder(space, encoding, errors):
    w_codec = interp_codecs.lookup_codec(space, rffi.charp2str(encoding))
    if errors:
        w_errors = space.newtext(rffi.charp2str(errors))
        return space.call_method(w_codec, "incrementalencoder", w_errors)
    else:
        return space.call_method(w_codec, "incrementalencoder")

@cpython_api([CONST_STRING, CONST_STRING], PyObject)
def PyCodec_IncrementalDecoder(space, encoding, errors):
    w_codec = interp_codecs.lookup_codec(space, rffi.charp2str(encoding))
    if errors:
        w_errors = space.newtext(rffi.charp2str(errors))
        return space.call_method(w_codec, "incrementaldecoder", w_errors)
    else:
        return space.call_method(w_codec, "incrementaldecoder")

@cpython_api([CONST_STRING], PyObject)
def PyCodec_Encoder(space, encoding):
    w_codec = interp_codecs.lookup_codec(space, rffi.charp2str(encoding))
    return space.getitem(w_codec, space.newint(0))

@cpython_api([CONST_STRING], PyObject)
def PyCodec_Decoder(space, encoding):
    w_codec = interp_codecs.lookup_codec(space, rffi.charp2str(encoding))
    return space.getitem(w_codec, space.newint(1))

@cpython_api([PyObject, CONST_STRING, CONST_STRING], PyObject)
def PyCodec_Encode(space, w_object, encoding, errors):
    """Generic codec based encoding API.

    object is passed through the encoder function found for the given
    encoding using the error handling method defined by errors.  errors may
    be NULL to use the default method defined for the codec.  Raises a
    LookupError if no encoder can be found."""
    w_encoding = space.newtext(rffi.charp2str(encoding))
    if errors:
        w_errors = space.newtext(rffi.charp2str(errors))
        return space.call_method(w_object, "encode", w_encoding, w_errors)
    else:
        return space.call_method(w_object, "encode", w_encoding)
        

@cpython_api([PyObject, CONST_STRING, CONST_STRING], PyObject)
def PyCodec_Decode(space, w_object, encoding, errors):
    """Generic codec based decoding API.

    object is passed through the decoder function found for the given
    encoding using the error handling method defined by errors.  errors may
    be NULL to use the default method defined for the codec.  Raises a
    LookupError if no encoder can be found."""
    w_encoding = space.newtext(rffi.charp2str(encoding))
    if errors:
        w_errors = space.newtext(rffi.charp2str(errors))
        return space.call_method(w_object, "decode", w_encoding, w_errors)
    else:
        return space.call_method(w_object, "decode", w_encoding)


