from _tkinter.tclobj import FromTclString, AsObj

def test_encoding_mess_from_tcl_string():
    # cesu-8 mess
    assert FromTclString(b'string\xed\xa0\xbd\xed\xb2\xbb') == 'string\U0001f4bb'
