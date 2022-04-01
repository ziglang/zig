class AppTestSum:

    def test_sum(self):
        raises(TypeError, sum, [b'a', b'c'], b'')
        raises(TypeError, sum, [bytearray(b'a'), bytearray(b'b')],
                bytearray(b''))
        raises(TypeError, sum, [[1], [2], [3]])
        raises(TypeError, sum, [{2:3}])
        raises(TypeError, sum, [{2:3}]*2, {2:3})
