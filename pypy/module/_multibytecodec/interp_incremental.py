from rpython.rtyper.lltypesystem import lltype
from rpython.rlib import rutf8
from pypy.module._multibytecodec import c_codecs
from pypy.module._multibytecodec.interp_multibytecodec import (
    MultibyteCodec, wrap_unicodedecodeerror, wrap_runtimeerror,
    wrap_unicodeencodeerror)
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from pypy.module._codecs.interp_codecs import CodecState


class MultibyteIncrementalBase(W_Root):
    def __init__(self, space, errors):
        if errors is None:
            errors = 'strict'
        self.space = space
        self.errors = errors
        w_codec = space.getattr(self, space.newtext("codec"))
        codec = space.interp_w(MultibyteCodec, w_codec)
        self.codec = codec.codec
        self.name = codec.name
        self._initialize()
        self.register_finalizer(space)

    def _finalize_(self):
        self._free()

    def reset_w(self):
        self._free()
        self._initialize()

    def fget_errors(self, space):
        return space.newtext(self.errors)

    def fset_errors(self, space, w_errors):
        self.errors = space.text_w(w_errors)


class MultibyteIncrementalDecoder(MultibyteIncrementalBase):

    def _initialize(self):
        self.decodebuf = c_codecs.pypy_cjk_dec_new(self.codec)
        self.pending = ""

    def _free(self):
        self.pending = None
        if self.decodebuf:
            c_codecs.pypy_cjk_dec_free(self.decodebuf)
            self.decodebuf = lltype.nullptr(c_codecs.DECODEBUF_P.TO)

    @unwrap_spec(object='bufferstr', final=int)
    def decode_w(self, object, final=0):
        final = bool(final)
        space = self.space
        state = space.fromcache(CodecState)
        if len(self.pending) > 0:
            object = self.pending + object
        try:
            output = c_codecs.decodeex(self.decodebuf, object, self.errors,
                                       state.decode_error_handler, self.name,
                                       get_ignore_error(final))
        except c_codecs.EncodeDecodeError as e:
            raise wrap_unicodedecodeerror(space, e, object, self.name)
        except RuntimeError:
            raise wrap_runtimeerror(space)
        pos = c_codecs.pypy_cjk_dec_inbuf_consumed(self.decodebuf)
        assert 0 <= pos <= len(object)
        self.pending = object[pos:]
        lgt = rutf8.codepoints_in_utf8(output)
        return space.newutf8(output, lgt)


@unwrap_spec(errors="text_or_none")
def mbidecoder_new(space, w_subtype, errors=None):
    r = space.allocate_instance(MultibyteIncrementalDecoder, w_subtype)
    r.__init__(space, errors)
    return r

MultibyteIncrementalDecoder.typedef = TypeDef(
    'MultibyteIncrementalDecoder',
    __new__ = interp2app(mbidecoder_new),
    decode  = interp2app(MultibyteIncrementalDecoder.decode_w),
    reset   = interp2app(MultibyteIncrementalDecoder.reset_w),
    errors  = GetSetProperty(MultibyteIncrementalDecoder.fget_errors,
                             MultibyteIncrementalDecoder.fset_errors),
)


class MultibyteIncrementalEncoder(MultibyteIncrementalBase):

    def _initialize(self):
        self.encodebuf = c_codecs.pypy_cjk_enc_new(self.codec)
        self.pending = ""
        self.pending_len = 0

    def _free(self):
        self.pending = None
        if self.encodebuf:
            c_codecs.pypy_cjk_enc_free(self.encodebuf)
            self.encodebuf = lltype.nullptr(c_codecs.ENCODEBUF_P.TO)

    @unwrap_spec(final=bool)
    def encode_w(self, space, w_object, final=False):
        utf8data, length = space.utf8_len_w(w_object)
        space = self.space
        state = space.fromcache(CodecState)
        if len(self.pending) > 0:
            utf8data = self.pending + utf8data
            length += self.pending_len
        try:
            output = c_codecs.encodeex(self.encodebuf, utf8data, length,
                                       self.errors,
                                       state.encode_error_handler, self.name,
                                       get_ignore_error(final))
        except c_codecs.EncodeDecodeError as e:
            raise wrap_unicodeencodeerror(space, e, utf8data, length,
                                          self.name)
        except RuntimeError:
            raise wrap_runtimeerror(space)
        pos = c_codecs.pypy_cjk_enc_inbuf_consumed(self.encodebuf)
        assert 0 <= pos <= length
        # scan the utf8 string until we hit pos
        i = 0
        stop = length - pos
        self.pending_len = stop
        if stop > 0:
            while pos > 0:
                i = rutf8.next_codepoint_pos(utf8data, i)
                pos -= 1
            self.pending = utf8data[i:]
        else:
            self.pending = ""
        return space.newbytes(output)


@unwrap_spec(errors="text_or_none")
def mbiencoder_new(space, w_subtype, errors=None):
    r = space.allocate_instance(MultibyteIncrementalEncoder, w_subtype)
    r.__init__(space, errors)
    return r

MultibyteIncrementalEncoder.typedef = TypeDef(
    'MultibyteIncrementalEncoder',
    __new__ = interp2app(mbiencoder_new),
    encode  = interp2app(MultibyteIncrementalEncoder.encode_w),
    reset   = interp2app(MultibyteIncrementalEncoder.reset_w),
    errors  = GetSetProperty(MultibyteIncrementalEncoder.fget_errors,
                             MultibyteIncrementalEncoder.fset_errors),
)


def get_ignore_error(final):
    if final:
        return 0    # don't ignore any error
    else:
        return c_codecs.MBERR_TOOFEW
