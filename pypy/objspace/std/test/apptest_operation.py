from pytest import raises

def teq(a, b):
    assert a == b
    assert type(a) is type(b)


def test_int_vs_float():
    # binary operators
    teq( 5  - 2    , 3   )
    teq( 5  - 2.0  , 3.0 )
    teq( 5.0 - 2   , 3.0 )
    teq( 5.0 - 2.0 , 3.0 )

    teq( 5   .__sub__(2  ), 3   )
    teq( 5   .__sub__(2.0), NotImplemented )
    teq( 5.0 .__sub__(2  ), 3.0 )
    teq( 5.0 .__sub__(2.0), 3.0 )

    teq( 5   .__rsub__(2  ), -3   )
    teq( 5   .__rsub__(2.0), NotImplemented )
    teq( 5.0 .__rsub__(2  ), -3.0 )
    teq( 5.0 .__rsub__(2.0), -3.0 )

    teq( 5   ** 2   , 25   )
    teq( 5   ** 2.0 , 25.0 )
    teq( 5.0 ** 2   , 25.0 )
    teq( 5.0 ** 2.0 , 25.0 )

    # pow() fails with a float argument anywhere
    raises(TypeError, pow, 5  , 3  , 100.0)
    raises(TypeError, pow, 5  , 3.0, 100  )
    raises(TypeError, pow, 5  , 3.0, 100.0)
    raises(TypeError, pow, 5.0, 3  , 100  )
    raises(TypeError, pow, 5.0, 3  , 100.0)
    raises(TypeError, pow, 5.0, 3.0, 100  )
    raises(TypeError, pow, 5.0, 3.0, 100.0)

    teq( 5 .__pow__(3.0, 100  ), NotImplemented )
    teq( 5 .__pow__(3.0, 100.0), NotImplemented )

    teq( 5 .__rpow__(3.0, 100  ), NotImplemented )
    teq( 5 .__rpow__(3.0, 100.0), NotImplemented )
