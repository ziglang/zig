import math

# code to deal with special values (infinities, NaNs, ...)
#
# The special types can be:
ST_NINF    = 0         # negative infinity
ST_NEG     = 1         # negative finite number (nonzero)
ST_NZERO   = 2         # -0.
ST_PZERO   = 3         # +0.
ST_POS     = 4         # positive finite number (nonzero)
ST_PINF    = 5         # positive infinity
ST_NAN     = 6         # Not a Number

def special_type(d):
    if math.isnan(d):
        return ST_NAN
    elif math.isinf(d):
        if d > 0.0:
            return ST_PINF
        else:
            return ST_NINF
    else:
        if d != 0.0:
            if d > 0.0:
                return ST_POS
            else:
                return ST_NEG
        else:
            if math.copysign(1., d) == 1.:
                return ST_PZERO
            else:
                return ST_NZERO


P   = math.pi
P14 = 0.25 * math.pi
P12 = 0.5 * math.pi
P34 = 0.75 * math.pi
INF = 1e200 * 1e200
N   = INF / INF
U   = -9.5426319407711027e33   # unlikely value, used as placeholder
Z   = 0.0    # defined here instead of in the tuples below, because of a bug
             # in pypy releases < 1.5
NAN = N

def build_table(lst):
    table = []
    assert len(lst) == 49
    it = iter(lst)
    for j in range(7):
        row = []
        for i in range(7):
            (x, y) = it.next()
            row.append((x, y))
        table.append(row)
    return table

acos_special_values = build_table([
    (P34,INF), (P,INF), (P,INF), (P,-INF), (P,-INF), (P34,-INF), (N,INF),
    (P12,INF), (U,U),   (U,U),   (U,U),    (U,U),    (P12,-INF), (N,N),
    (P12,INF), (U,U),   (P12,Z), (P12,-Z), (U,U),    (P12,-INF), (P12,N),
    (P12,INF), (U,U),   (P12,Z), (P12,-Z), (U,U),    (P12,-INF), (P12,N),
    (P12,INF), (U,U),   (U,U),   (U,U),    (U,U),    (P12,-INF), (N,N),
    (P14,INF), (Z,INF), (Z,INF), (Z,-INF), (Z,-INF), (P14,-INF), (N,INF),
    (N,INF),   (N,N),   (N,N),   (N,N),    (N,N),    (N,-INF),   (N,N),
    ])

acosh_special_values = build_table([
    (INF,-P34), (INF,-P), (INF,-P), (INF,P), (INF,P), (INF,P34), (INF,N),
    (INF,-P12), (U,U),    (U,U),    (U,U),   (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (Z,-P12), (Z,P12), (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (Z,-P12), (Z,P12), (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (U,U),    (U,U),   (U,U),   (INF,P12), (N,N),
    (INF,-P14), (INF,-Z), (INF,-Z), (INF,Z), (INF,Z), (INF,P14), (INF,N),
    (INF,N),    (N,N),    (N,N),    (N,N),   (N,N),   (INF,N),   (N,N),
    ])

asinh_special_values = build_table([
    (-INF,-P14), (-INF,-Z), (-INF,-Z),(-INF,Z), (-INF,Z), (-INF,P14), (-INF,N),
    (-INF,-P12), (U,U),     (U,U),    (U,U),    (U,U),    (-INF,P12), (N,N),
    (-INF,-P12), (U,U),     (-Z,-Z),  (-Z,Z),   (U,U),    (-INF,P12), (N,N),
    (INF,-P12),  (U,U),     (Z,-Z),   (Z,Z),    (U,U),    (INF,P12),  (N,N),
    (INF,-P12),  (U,U),     (U,U),    (U,U),    (U,U),    (INF,P12),  (N,N),
    (INF,-P14),  (INF,-Z),  (INF,-Z), (INF,Z),  (INF,Z),  (INF,P14),  (INF,N),
    (INF,N),     (N,N),     (N,-Z),   (N,Z),    (N,N),    (INF,N),    (N,N),
    ])

atanh_special_values = build_table([
    (-Z,-P12), (-Z,-P12), (-Z,-P12), (-Z,P12), (-Z,P12), (-Z,P12), (-Z,N),
    (-Z,-P12), (U,U),     (U,U),     (U,U),    (U,U),    (-Z,P12), (N,N),
    (-Z,-P12), (U,U),     (-Z,-Z),   (-Z,Z),   (U,U),    (-Z,P12), (-Z,N),
    (Z,-P12),  (U,U),     (Z,-Z),    (Z,Z),    (U,U),    (Z,P12),  (Z,N),
    (Z,-P12),  (U,U),     (U,U),     (U,U),    (U,U),    (Z,P12),  (N,N),
    (Z,-P12),  (Z,-P12),  (Z,-P12),  (Z,P12),  (Z,P12),  (Z,P12),  (Z,N),
    (Z,-P12),  (N,N),     (N,N),     (N,N),    (N,N),    (Z,P12),  (N,N),
    ])

log_special_values = build_table([
    (INF,-P34), (INF,-P), (INF,-P),  (INF,P),  (INF,P), (INF,P34), (INF,N),
    (INF,-P12), (U,U),    (U,U),     (U,U),    (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (-INF,-P), (-INF,P), (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (-INF,-Z), (-INF,Z), (U,U),   (INF,P12), (N,N),
    (INF,-P12), (U,U),    (U,U),     (U,U),    (U,U),   (INF,P12), (N,N),
    (INF,-P14), (INF,-Z), (INF,-Z),  (INF,Z),  (INF,Z), (INF,P14), (INF,N),
    (INF,N),    (N,N),    (N,N),     (N,N),    (N,N),   (INF,N),   (N,N),
    ])

sqrt_special_values = build_table([
    (INF,-INF), (Z,-INF), (Z,-INF), (Z,INF), (Z,INF), (INF,INF), (N,INF),
    (INF,-INF), (U,U),    (U,U),    (U,U),   (U,U),   (INF,INF), (N,N),
    (INF,-INF), (U,U),    (Z,-Z),   (Z,Z),   (U,U),   (INF,INF), (N,N),
    (INF,-INF), (U,U),    (Z,-Z),   (Z,Z),   (U,U),   (INF,INF), (N,N),
    (INF,-INF), (U,U),    (U,U),    (U,U),   (U,U),   (INF,INF), (N,N),
    (INF,-INF), (INF,-Z), (INF,-Z), (INF,Z), (INF,Z), (INF,INF), (INF,N),
    (INF,-INF), (N,N),    (N,N),    (N,N),   (N,N),   (INF,INF), (N,N),
    ])

exp_special_values = build_table([
    (Z,Z),   (U,U), (Z,-Z),   (Z,Z),   (U,U), (Z,Z),   (Z,Z),
    (N,N),   (U,U), (U,U),    (U,U),   (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (1.,-Z),  (1.,Z),  (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (1.,-Z),  (1.,Z),  (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (U,U),    (U,U),   (U,U), (N,N),   (N,N),
    (INF,N), (U,U), (INF,-Z), (INF,Z), (U,U), (INF,N), (INF,N),
    (N,N),   (N,N), (N,-Z),   (N,Z),   (N,N), (N,N),   (N,N),
    ])

cosh_special_values = build_table([
    (INF,N), (U,U), (INF,Z),  (INF,-Z), (U,U), (INF,N), (INF,N),
    (N,N),   (U,U), (U,U),    (U,U),    (U,U), (N,N),   (N,N),
    (N,Z),   (U,U), (1.,Z),   (1.,-Z),  (U,U), (N,Z),   (N,Z),
    (N,Z),   (U,U), (1.,-Z),  (1.,Z),   (U,U), (N,Z),   (N,Z),
    (N,N),   (U,U), (U,U),    (U,U),    (U,U), (N,N),   (N,N),
    (INF,N), (U,U), (INF,-Z), (INF,Z),  (U,U), (INF,N), (INF,N),
    (N,N),   (N,N), (N,Z),    (N,Z),    (N,N), (N,N),   (N,N),
    ])

sinh_special_values = build_table([
    (INF,N), (U,U), (-INF,-Z), (-INF,Z), (U,U), (INF,N), (INF,N),
    (N,N),   (U,U), (U,U),     (U,U),    (U,U), (N,N),   (N,N),
    (Z,N),   (U,U), (-Z,-Z),   (-Z,Z),   (U,U), (Z,N),   (Z,N),
    (Z,N),   (U,U), (Z,-Z),    (Z,Z),    (U,U), (Z,N),   (Z,N),
    (N,N),   (U,U), (U,U),     (U,U),    (U,U), (N,N),   (N,N),
    (INF,N), (U,U), (INF,-Z),  (INF,Z),  (U,U), (INF,N), (INF,N),
    (N,N),   (N,N), (N,-Z),    (N,Z),    (N,N), (N,N),   (N,N),
    ])

tanh_special_values = build_table([
    (-1.,Z), (U,U), (-1.,-Z), (-1.,Z), (U,U), (-1.,Z), (-1.,Z),
    (N,N),   (U,U), (U,U),    (U,U),   (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (-Z,-Z),  (-Z,Z),  (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (Z,-Z),   (Z,Z),   (U,U), (N,N),   (N,N),
    (N,N),   (U,U), (U,U),    (U,U),   (U,U), (N,N),   (N,N),
    (1.,Z),  (U,U), (1.,-Z),  (1.,Z),  (U,U), (1.,Z),  (1.,Z),
    (N,N),   (N,N), (N,-Z),   (N,Z),   (N,N), (N,N),   (N,N),
    ])

rect_special_values = build_table([
    (INF,N), (U,U), (-INF,Z), (-INF,-Z), (U,U), (INF,N), (INF,N),
    (N,N),   (U,U), (U,U),    (U,U),     (U,U), (N,N),   (N,N),
    (Z,Z),   (U,U), (-Z,Z),   (-Z,-Z),   (U,U), (Z,Z),   (Z,Z),
    (Z,Z),   (U,U), (Z,-Z),   (Z,Z),     (U,U), (Z,Z),   (Z,Z),
    (N,N),   (U,U), (U,U),    (U,U),     (U,U), (N,N),   (N,N),
    (INF,N), (U,U), (INF,-Z), (INF,Z),   (U,U), (INF,N), (INF,N),
    (N,N),   (N,N), (N,Z),    (N,Z),     (N,N), (N,N),   (N,N),
    ])

assert math.copysign(1., acosh_special_values[5][2][1]) == -1.
