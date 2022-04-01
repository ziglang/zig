
from rpython.rlib import rutf8

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.error import OperationError, oefmt
from pypy.module._multibytecodec import c_codecs
from pypy.module._codecs.interp_codecs import CodecState


class MultibyteCodec(W_Root):
    def __init__(self, name, codec):
        self.name = name
        self.codec = codec

    @unwrap_spec(input='bufferstr', errors="text_or_none")
    def decode(self, space, input, errors=None):
        if errors is None:
            errors = 'strict'
        state = space.fromcache(CodecState)
        #
        try:
            utf8_output = c_codecs.decode(self.codec, input, errors,
                                     state.decode_error_handler, self.name)
        except c_codecs.EncodeDecodeError as e:
            raise wrap_unicodedecodeerror(space, e, input, self.name)
        except RuntimeError:
            raise wrap_runtimeerror(space)
        lgt = rutf8.codepoints_in_utf8(utf8_output)
        return space.newtuple([space.newutf8(utf8_output, lgt),
                               space.newint(len(input))])

    @unwrap_spec(errors="text_or_none")
    def encode(self, space, w_input, errors=None):
        if errors is None:
            errors = 'strict'
        state = space.fromcache(CodecState)
        input, length = space.utf8_len_w(w_input)
        #
        try:
            output = c_codecs.encode(self.codec, input, length, errors,
                                     state.encode_error_handler, self.name)
        except c_codecs.EncodeDecodeError as e:
            raise wrap_unicodeencodeerror(space, e, input, length,
                                          self.name)
        except RuntimeError:
            raise wrap_runtimeerror(space)
        return space.newtuple([space.newbytes(output),
                               space.newint(length)])


MultibyteCodec.typedef = TypeDef(
    'MultibyteCodec',
    decode = interp2app(MultibyteCodec.decode),
    encode = interp2app(MultibyteCodec.encode),
    )
MultibyteCodec.typedef.acceptable_as_base_class = False


@unwrap_spec(name='text')
def getcodec(space, name):
    try:
        codec = c_codecs.getcodec(name)
    except KeyError:
        raise oefmt(space.w_LookupError, "no such codec is supported.")
    return MultibyteCodec(name, codec)


def wrap_unicodedecodeerror(space, e, input, name):
    return OperationError(
        space.w_UnicodeDecodeError,
        space.newtuple([
            space.newtext(name),
            space.newbytes(input),
            space.newint(e.start),
            space.newint(e.end),
            space.newtext(e.reason)]))

def wrap_unicodeencodeerror(space, e, input, inputlen, name):
    assert inputlen >= 0
    raise OperationError(
        space.w_UnicodeEncodeError,
        space.newtuple([
            space.newtext(name),
            space.newutf8(input, inputlen),
            space.newint(e.start),
            space.newint(e.end),
            space.newtext(e.reason)]))

def wrap_runtimeerror(space):
    raise oefmt(space.w_RuntimeError, "internal codec error")
