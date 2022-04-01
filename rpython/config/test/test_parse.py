from rpython.config.parse import parse_info


def test_parse_new_format():
    assert (parse_info("[foo]\n"
                       "    bar = True\n")
            == {'foo.bar': True})
    
    assert (parse_info("[objspace]\n"
                       "    x = 'hello'\n"
                       "[translation]\n"
                       "    bar = 42\n"
                       "    [egg]\n"
                       "        something = None\n"
                       "    foo = True\n")
            == {
        'translation.foo': True,
        'translation.bar': 42,
        'translation.egg.something': None,
        'objspace.x': 'hello',
        })

    assert parse_info("simple = 43\n") == {'simple': 43}


def test_parse_old_format():
    assert (parse_info("                          objspace.allworkingmodules: True\n"
                       "                    objspace.disable_call_speedhacks: False\n"
                       "                                 objspace.extmodules: None\n"
                       "                        objspace.std.prebuiltintfrom: -5\n")
            == {
        'objspace.allworkingmodules': True,
        'objspace.disable_call_speedhacks': False,
        'objspace.extmodules': None,
        'objspace.std.prebuiltintfrom': -5,
        })
