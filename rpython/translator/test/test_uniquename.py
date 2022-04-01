from rpython.translator.gensupp import NameManager

def test_unique():
    m = NameManager()
    sn = m.seennames
    check = [
        m.uniquename('something0'),
        m.uniquename('something', with_number=True),
        m.uniquename('something', with_number=True),
        m.uniquename('something2', with_number=True),
        m.uniquename('something1'),
        m.uniquename('something1_1'),
        ]
    assert check == ['something0', 'something0_1', 'something1',
                     'something2_0', 'something1_1', 'something1_1_1']
