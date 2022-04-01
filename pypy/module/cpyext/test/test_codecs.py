# encoding: iso-8859-15
from pypy.module.cpyext.test.test_api import BaseApiTest
from rpython.rtyper.lltypesystem import rffi
from pypy.module.cpyext.codecs import (
    PyCodec_IncrementalEncoder, PyCodec_IncrementalDecoder,
    PyCodec_Encoder, PyCodec_Decoder)
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase

class TestCodecs(BaseApiTest):
    def test_incremental(self, space):
        utf8 = rffi.str2charp('utf-8')
        w_encoder = PyCodec_IncrementalEncoder(space, utf8, None)
        w_encoded = space.call_method(w_encoder, 'encode', space.wrap(u'späm'))
        w_decoder = PyCodec_IncrementalDecoder(space, utf8, None)
        w_decoded = space.call_method(w_decoder, 'decode', w_encoded)
        assert space.utf8_w(w_decoded) == u'späm'.encode("utf-8")
        rffi.free_charp(utf8)

    def test_encoder_decoder(self, space):
        utf8 = rffi.str2charp('utf-8')
        w_encoder = PyCodec_Encoder(space, utf8)
        w_decoder = PyCodec_Decoder(space, utf8)
        rffi.free_charp(utf8)
        space.appexec([w_encoder, w_decoder], r"""(encoder, decoder):
            assert encoder(u"\u1234") == (b"\xe1\x88\xb4", 1)
            assert decoder(b"\xe1\x88\xb4") == (u"\u1234", 3)
        """)

class AppTestUnicodeObject(AppTestCpythonExtensionBase):
    def test_encode_decode(self):
        module = self.import_extension('foo', [
            ("encode", "METH_VARARGS",
             """
                PyObject *obj=NULL;
                const char *encoding=NULL;
                const char *errors=NULL;
                if (!PyArg_ParseTuple(args, "Os|s:foo.encode", &obj, &encoding, &errors))
                    return NULL;
                return PyCodec_Encode(obj, encoding, errors);
            """),
            ("decode", "METH_VARARGS",
             """
                PyObject *obj=NULL;
                const char *encoding=NULL;
                const char *errors=NULL;
                if (!PyArg_ParseTuple(args, "Os|s:foo.decode", &obj, &encoding, &errors))
                    return NULL;
                return PyCodec_Decode(obj, encoding, errors);
            """),])
        assert module.decode(b'abc', 'latin-1') == 'abc'
        assert module.encode('abc', 'latin-1') == b'abc'
        assert module.decode(b'abc', 'latin-1', 'strict') == 'abc'
        assert module.encode('abc', 'latin-1', 'strict') == b'abc'
