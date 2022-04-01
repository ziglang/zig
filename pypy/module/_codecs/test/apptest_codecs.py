import _codecs

def test_lone_low_surrogate_utf16():
    data = '\udc02'.encode('utf-16', 'surrogatepass')
    decode = _codecs.utf_16_ex_decode
    (result, consumed, bo) = decode(data, 'surrogatepass', False)
    assert result == '\uDC02'

def test_lone_low_surrogate_utf16le():
    data = '\udc02'.encode('utf-16-le', 'surrogatepass')
    decode = _codecs.utf_16_le_decode
    (result, consumed) = decode(data, 'surrogatepass', False)
    assert result == '\uDC02'
