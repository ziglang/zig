import os

class AppTestPartialEvaluation:
    spaceconfig = dict(usemodules=['_multibytecodec', '_codecs'])

    def setup_class(cls):
        cls.w_myfile = cls.space.wrap(os.path.dirname(__file__))

    def test_callback_None_index(self):
        import _multibytecodec, _codecs
        codec = _multibytecodec.__getcodec('cp932')
        def myreplace(exc):
            return ('x', None)
        _codecs.register_error("test.cjktest", myreplace)
        raises(TypeError, codec.encode, '\udeee', 'test.cjktest')

    def test_callback_backward_index(self):
        import _multibytecodec, _codecs
        codec = _multibytecodec.__getcodec('cp932')
        def myreplace(exc):
            if myreplace.limit > 0:
                myreplace.limit -= 1
                return ('REPLACED', 0)
            else:
                return ('TERMINAL', exc.end)
        myreplace.limit = 3
        _codecs.register_error("test.cjktest", myreplace)
        assert (codec.encode('abcd' + '\udeee' + 'efgh', 'test.cjktest') == 
                (b'abcdREPLACEDabcdREPLACEDabcdREPLACEDabcdTERMINALefgh', 9))

    def test_callback_forward_index(self):
        import _multibytecodec, _codecs
        codec = _multibytecodec.__getcodec('cp932')
        def myreplace(exc):
            return ('REPLACED', exc.end + 2)
        _codecs.register_error("test.cjktest", myreplace)
        assert (codec.encode('abcd' + '\udeee' + 'efgh', 'test.cjktest') == 
                                     (b'abcdREPLACEDgh', 9))

    def _test_incrementalencoder(self):
        import _multibytecodec, _codecs, _io
        with open(self.myfile + '/shift_jis.txt', 'rb') as fid:
            uni_str =  fid.read()
        with open(self.myfile + '/shift_jis-utf8.txt', 'rb') as fid:
            utf8str =  fid.read()
        UTF8Reader = _codecs.lookup('utf-8').streamreader
        for sizehint in [None] + list(range(1, 33)) + \
                        [64, 128, 256, 512, 1024]:
            istream = UTF8Reader(_io.BytesIO(utf8str))
            ostream = _io.BytesIO()
            codec = _multibytecodec.__getcodec('cp932')
            print(dir(codec))
            encoder = codec.incrementalencoder()
            while 1:
                if sizehint is not None:
                    data = istream.read(sizehint)
                else:
                    data = istream.read()

                if not data:
                    break
                e = encoder.encode(data)
                ostream.write(e)
            assert ostream.getvalue() == uni_str
