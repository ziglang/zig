const std = @import("std");
const math = std.math;
const common = @import("common.zig");
const FloatStream = @import("FloatStream.zig");
const isEightDigits = @import("common.zig").isEightDigits;
const mantissaType = common.mantissaType;

// Arbitrary-precision decimal class for fallback algorithms.
//
// This is only used if the fast-path (native floats) and
// the Eisel-Lemire algorithm are unable to unambiguously
// determine the float.
//
// The technique used is "Simple Decimal Conversion", developed
// by Nigel Tao and Ken Thompson. A detailed description of the
// algorithm can be found in "ParseNumberF64 by Simple Decimal Conversion",
// available online: <https://nigeltao.github.io/blog/2020/parse-number-f64-simple.html>.
//
// Big-decimal implementation. We do not use the big.Int routines since we only require a maximum
// fixed region of memory. Further, we require only a small subset of operations.
//
// This accepts a floating point parameter and will generate a Decimal which can correctly parse
// the input with sufficient accuracy. Internally this means either a u64 mantissa (f16, f32 or f64)
// or a u128 mantissa (f128).
pub fn Decimal(comptime T: type) type {
    const MantissaT = mantissaType(T);
    std.debug.assert(MantissaT == u64 or MantissaT == u128);

    return struct {
        const Self = @This();

        /// The maximum number of digits required to unambiguously round a float.
        ///
        /// For a double-precision IEEE-754 float, this required 767 digits,
        /// so we store the max digits + 1.
        ///
        /// We can exactly represent a float in base `b` from base 2 if
        /// `b` is divisible by 2. This function calculates the exact number of
        /// digits required to exactly represent that float.
        ///
        /// According to the "Handbook of Floating Point Arithmetic",
        /// for IEEE754, with emin being the min exponent, p2 being the
        /// precision, and b being the base, the number of digits follows as:
        ///
        /// `−emin + p2 + ⌊(emin + 1) log(2, b) − log(1 − 2^(−p2), b)⌋`
        ///
        /// For f32, this follows as:
        ///     emin = -126
        ///     p2 = 24
        ///
        /// For f64, this follows as:
        ///     emin = -1022
        ///     p2 = 53
        ///
        /// For f128, this follows as:
        ///     emin = -16383
        ///     p2 = 112
        ///
        /// In Python:
        ///     `-emin + p2 + math.floor((emin+ 1)*math.log(2, b)-math.log(1-2**(-p2), b))`
        pub const max_digits = if (MantissaT == u64) 768 else 11564;
        /// The max digits that can be exactly represented in a 64-bit integer.
        pub const max_digits_without_overflow = if (MantissaT == u64) 19 else 38;
        pub const decimal_point_range = if (MantissaT == u64) 2047 else 32767;
        pub const min_exponent = if (MantissaT == u64) -324 else -4966;
        pub const max_exponent = if (MantissaT == u64) 310 else 4934;
        pub const max_decimal_digits = if (MantissaT == u64) 18 else 37;

        /// The number of significant digits in the decimal.
        num_digits: usize,
        /// The offset of the decimal point in the significant digits.
        decimal_point: i32,
        /// If the number of significant digits stored in the decimal is truncated.
        truncated: bool,
        /// buffer of the raw digits, in the range [0, 9].
        digits: [max_digits]u8,

        pub fn new() Self {
            return .{
                .num_digits = 0,
                .decimal_point = 0,
                .truncated = false,
                .digits = [_]u8{0} ** max_digits,
            };
        }

        /// Append a digit to the buffer
        pub fn tryAddDigit(self: *Self, digit: u8) void {
            if (self.num_digits < max_digits) {
                self.digits[self.num_digits] = digit;
            }
            self.num_digits += 1;
        }

        /// Trim trailing zeroes from the buffer
        pub fn trim(self: *Self) void {
            // All of the following calls to `Self::trim` can't panic because:
            //
            //  1. `parse_decimal` sets `num_digits` to a max of `max_digits`.
            //  2. `right_shift` sets `num_digits` to `write_index`, which is bounded by `num_digits`.
            //  3. `left_shift` `num_digits` to a max of `max_digits`.
            //
            // Trim is only called in `right_shift` and `left_shift`.
            std.debug.assert(self.num_digits <= max_digits);
            while (self.num_digits != 0 and self.digits[self.num_digits - 1] == 0) {
                self.num_digits -= 1;
            }
        }

        pub fn round(self: *Self) MantissaT {
            if (self.num_digits == 0 or self.decimal_point < 0) {
                return 0;
            } else if (self.decimal_point > max_decimal_digits) {
                return math.maxInt(MantissaT);
            }

            const dp = @as(usize, @intCast(self.decimal_point));
            var n: MantissaT = 0;

            var i: usize = 0;
            while (i < dp) : (i += 1) {
                n *= 10;
                if (i < self.num_digits) {
                    n += @as(MantissaT, self.digits[i]);
                }
            }

            var round_up = false;
            if (dp < self.num_digits) {
                round_up = self.digits[dp] >= 5;
                if (self.digits[dp] == 5 and dp + 1 == self.num_digits) {
                    round_up = self.truncated or ((dp != 0) and (1 & self.digits[dp - 1] != 0));
                }
            }
            if (round_up) {
                n += 1;
            }
            return n;
        }

        /// Computes decimal * 2^shift.
        pub fn leftShift(self: *Self, shift: usize) void {
            if (self.num_digits == 0) {
                return;
            }
            const num_new_digits = self.numberOfDigitsLeftShift(shift);
            var read_index = self.num_digits;
            var write_index = self.num_digits + num_new_digits;
            var n: MantissaT = 0;
            while (read_index != 0) {
                read_index -= 1;
                write_index -= 1;
                n += math.shl(MantissaT, self.digits[read_index], shift);

                const quotient = n / 10;
                const remainder = n - (10 * quotient);
                if (write_index < max_digits) {
                    self.digits[write_index] = @as(u8, @intCast(remainder));
                } else if (remainder > 0) {
                    self.truncated = true;
                }
                n = quotient;
            }
            while (n > 0) {
                write_index -= 1;

                const quotient = n / 10;
                const remainder = n - (10 * quotient);
                if (write_index < max_digits) {
                    self.digits[write_index] = @as(u8, @intCast(remainder));
                } else if (remainder > 0) {
                    self.truncated = true;
                }
                n = quotient;
            }

            self.num_digits += num_new_digits;
            if (self.num_digits > max_digits) {
                self.num_digits = max_digits;
            }
            self.decimal_point += @as(i32, @intCast(num_new_digits));
            self.trim();
        }

        /// Computes decimal * 2^-shift.
        pub fn rightShift(self: *Self, shift: usize) void {
            var read_index: usize = 0;
            var write_index: usize = 0;
            var n: MantissaT = 0;
            while (math.shr(MantissaT, n, shift) == 0) {
                if (read_index < self.num_digits) {
                    n = (10 * n) + self.digits[read_index];
                    read_index += 1;
                } else if (n == 0) {
                    return;
                } else {
                    while (math.shr(MantissaT, n, shift) == 0) {
                        n *= 10;
                        read_index += 1;
                    }
                    break;
                }
            }

            self.decimal_point -= @as(i32, @intCast(read_index)) - 1;
            if (self.decimal_point < -decimal_point_range) {
                self.num_digits = 0;
                self.decimal_point = 0;
                self.truncated = false;
                return;
            }

            const mask = math.shl(MantissaT, 1, shift) - 1;
            while (read_index < self.num_digits) {
                const new_digit = @as(u8, @intCast(math.shr(MantissaT, n, shift)));
                n = (10 * (n & mask)) + self.digits[read_index];
                read_index += 1;
                self.digits[write_index] = new_digit;
                write_index += 1;
            }
            while (n > 0) {
                const new_digit = @as(u8, @intCast(math.shr(MantissaT, n, shift)));
                n = 10 * (n & mask);
                if (write_index < max_digits) {
                    self.digits[write_index] = new_digit;
                    write_index += 1;
                } else if (new_digit > 0) {
                    self.truncated = true;
                }
            }
            self.num_digits = write_index;
            self.trim();
        }

        /// Parse a bit integer representation of the float as a decimal.
        // We do not verify underscores in this path since these will have been verified
        // via parse.parseNumber so can assume the number is well-formed.
        // This code-path does not have to handle hex-floats since these will always be handled via another
        // function prior to this.
        pub fn parse(s: []const u8) Self {
            var d = Self.new();
            var stream = FloatStream.init(s);

            stream.skipChars("0_");
            while (stream.scanDigit(10)) |digit| {
                d.tryAddDigit(digit);
            }

            if (stream.firstIs(".")) {
                stream.advance(1);
                const marker = stream.offsetTrue();

                // Skip leading zeroes
                if (d.num_digits == 0) {
                    stream.skipChars("0");
                }

                while (stream.hasLen(8) and d.num_digits + 8 < max_digits) {
                    const v = stream.readU64Unchecked();
                    if (!isEightDigits(v)) {
                        break;
                    }
                    std.mem.writeInt(u64, d.digits[d.num_digits..][0..8], v - 0x3030_3030_3030_3030, .little);
                    d.num_digits += 8;
                    stream.advance(8);
                }

                while (stream.scanDigit(10)) |digit| {
                    d.tryAddDigit(digit);
                }
                d.decimal_point = @as(i32, @intCast(marker)) - @as(i32, @intCast(stream.offsetTrue()));
            }
            if (d.num_digits != 0) {
                // Ignore trailing zeros if any
                var n_trailing_zeros: usize = 0;
                var i = stream.offsetTrue() - 1;
                while (true) {
                    if (s[i] == '0') {
                        n_trailing_zeros += 1;
                    } else if (s[i] != '.') {
                        break;
                    }

                    i -= 1;
                    if (i == 0) break;
                }
                d.decimal_point += @as(i32, @intCast(n_trailing_zeros));
                d.num_digits -= n_trailing_zeros;
                d.decimal_point += @as(i32, @intCast(d.num_digits));
                if (d.num_digits > max_digits) {
                    d.truncated = true;
                    d.num_digits = max_digits;
                }
            }
            if (stream.firstIsLower("e")) {
                stream.advance(1);
                var neg_exp = false;
                if (stream.firstIs("-")) {
                    neg_exp = true;
                    stream.advance(1);
                } else if (stream.firstIs("+")) {
                    stream.advance(1);
                }
                var exp_num: i32 = 0;
                while (stream.scanDigit(10)) |digit| {
                    if (exp_num < 0x10000) {
                        exp_num = 10 * exp_num + digit;
                    }
                }
                d.decimal_point += if (neg_exp) -exp_num else exp_num;
            }

            var i = d.num_digits;
            while (i < max_digits_without_overflow) : (i += 1) {
                d.digits[i] = 0;
            }

            return d;
        }

        // Compute the number decimal digits introduced by a base-2 shift. This is performed
        // by storing the leading digits of 1/2^i = 5^i and using these along with the cut-off
        // value to quickly determine the decimal shift from binary.
        //
        // See also https://github.com/golang/go/blob/go1.15.3/src/strconv/decimal.go#L163 for
        // another description of the method.
        pub fn numberOfDigitsLeftShift(self: *Self, shift: usize) usize {
            const ShiftCutoff = struct {
                delta: u8,
                cutoff: []const u8,
            };

            // Leading digits of 1/2^i = 5^i.
            //
            // ```
            // import math
            //
            // bits = 128
            // for i in range(bits):
            //     log2 = math.log(2)/math.log(10)
            //     print(f'.{{ .delta = {int(log2*i+1)}, .cutoff = "{5**i}" }}, // {2**i}')
            // ```
            const pow2_to_pow5_table = [_]ShiftCutoff{
                .{ .delta = 0, .cutoff = "" },
                .{ .delta = 1, .cutoff = "5" }, // 2
                .{ .delta = 1, .cutoff = "25" }, // 4
                .{ .delta = 1, .cutoff = "125" }, // 8
                .{ .delta = 2, .cutoff = "625" }, // 16
                .{ .delta = 2, .cutoff = "3125" }, // 32
                .{ .delta = 2, .cutoff = "15625" }, // 64
                .{ .delta = 3, .cutoff = "78125" }, // 128
                .{ .delta = 3, .cutoff = "390625" }, // 256
                .{ .delta = 3, .cutoff = "1953125" }, // 512
                .{ .delta = 4, .cutoff = "9765625" }, // 1024
                .{ .delta = 4, .cutoff = "48828125" }, // 2048
                .{ .delta = 4, .cutoff = "244140625" }, // 4096
                .{ .delta = 4, .cutoff = "1220703125" }, // 8192
                .{ .delta = 5, .cutoff = "6103515625" }, // 16384
                .{ .delta = 5, .cutoff = "30517578125" }, // 32768
                .{ .delta = 5, .cutoff = "152587890625" }, // 65536
                .{ .delta = 6, .cutoff = "762939453125" }, // 131072
                .{ .delta = 6, .cutoff = "3814697265625" }, // 262144
                .{ .delta = 6, .cutoff = "19073486328125" }, // 524288
                .{ .delta = 7, .cutoff = "95367431640625" }, // 1048576
                .{ .delta = 7, .cutoff = "476837158203125" }, // 2097152
                .{ .delta = 7, .cutoff = "2384185791015625" }, // 4194304
                .{ .delta = 7, .cutoff = "11920928955078125" }, // 8388608
                .{ .delta = 8, .cutoff = "59604644775390625" }, // 16777216
                .{ .delta = 8, .cutoff = "298023223876953125" }, // 33554432
                .{ .delta = 8, .cutoff = "1490116119384765625" }, // 67108864
                .{ .delta = 9, .cutoff = "7450580596923828125" }, // 134217728
                .{ .delta = 9, .cutoff = "37252902984619140625" }, // 268435456
                .{ .delta = 9, .cutoff = "186264514923095703125" }, // 536870912
                .{ .delta = 10, .cutoff = "931322574615478515625" }, // 1073741824
                .{ .delta = 10, .cutoff = "4656612873077392578125" }, // 2147483648
                .{ .delta = 10, .cutoff = "23283064365386962890625" }, // 4294967296
                .{ .delta = 10, .cutoff = "116415321826934814453125" }, // 8589934592
                .{ .delta = 11, .cutoff = "582076609134674072265625" }, // 17179869184
                .{ .delta = 11, .cutoff = "2910383045673370361328125" }, // 34359738368
                .{ .delta = 11, .cutoff = "14551915228366851806640625" }, // 68719476736
                .{ .delta = 12, .cutoff = "72759576141834259033203125" }, // 137438953472
                .{ .delta = 12, .cutoff = "363797880709171295166015625" }, // 274877906944
                .{ .delta = 12, .cutoff = "1818989403545856475830078125" }, // 549755813888
                .{ .delta = 13, .cutoff = "9094947017729282379150390625" }, // 1099511627776
                .{ .delta = 13, .cutoff = "45474735088646411895751953125" }, // 2199023255552
                .{ .delta = 13, .cutoff = "227373675443232059478759765625" }, // 4398046511104
                .{ .delta = 13, .cutoff = "1136868377216160297393798828125" }, // 8796093022208
                .{ .delta = 14, .cutoff = "5684341886080801486968994140625" }, // 17592186044416
                .{ .delta = 14, .cutoff = "28421709430404007434844970703125" }, // 35184372088832
                .{ .delta = 14, .cutoff = "142108547152020037174224853515625" }, // 70368744177664
                .{ .delta = 15, .cutoff = "710542735760100185871124267578125" }, // 140737488355328
                .{ .delta = 15, .cutoff = "3552713678800500929355621337890625" }, // 281474976710656
                .{ .delta = 15, .cutoff = "17763568394002504646778106689453125" }, // 562949953421312
                .{ .delta = 16, .cutoff = "88817841970012523233890533447265625" }, // 1125899906842624
                .{ .delta = 16, .cutoff = "444089209850062616169452667236328125" }, // 2251799813685248
                .{ .delta = 16, .cutoff = "2220446049250313080847263336181640625" }, // 4503599627370496
                .{ .delta = 16, .cutoff = "11102230246251565404236316680908203125" }, // 9007199254740992
                .{ .delta = 17, .cutoff = "55511151231257827021181583404541015625" }, // 18014398509481984
                .{ .delta = 17, .cutoff = "277555756156289135105907917022705078125" }, // 36028797018963968
                .{ .delta = 17, .cutoff = "1387778780781445675529539585113525390625" }, // 72057594037927936
                .{ .delta = 18, .cutoff = "6938893903907228377647697925567626953125" }, // 144115188075855872
                .{ .delta = 18, .cutoff = "34694469519536141888238489627838134765625" }, // 288230376151711744
                .{ .delta = 18, .cutoff = "173472347597680709441192448139190673828125" }, // 576460752303423488
                .{ .delta = 19, .cutoff = "867361737988403547205962240695953369140625" }, // 1152921504606846976
                .{ .delta = 19, .cutoff = "4336808689942017736029811203479766845703125" }, // 2305843009213693952
                .{ .delta = 19, .cutoff = "21684043449710088680149056017398834228515625" }, // 4611686018427387904
                .{ .delta = 19, .cutoff = "108420217248550443400745280086994171142578125" }, // 9223372036854775808
                .{ .delta = 20, .cutoff = "542101086242752217003726400434970855712890625" }, // 18446744073709551616
                .{ .delta = 20, .cutoff = "2710505431213761085018632002174854278564453125" }, // 36893488147419103232
                .{ .delta = 20, .cutoff = "13552527156068805425093160010874271392822265625" }, // 73786976294838206464
                .{ .delta = 21, .cutoff = "67762635780344027125465800054371356964111328125" }, // 147573952589676412928
                .{ .delta = 21, .cutoff = "338813178901720135627329000271856784820556640625" }, // 295147905179352825856
                .{ .delta = 21, .cutoff = "1694065894508600678136645001359283924102783203125" }, // 590295810358705651712
                .{ .delta = 22, .cutoff = "8470329472543003390683225006796419620513916015625" }, // 1180591620717411303424
                .{ .delta = 22, .cutoff = "42351647362715016953416125033982098102569580078125" }, // 2361183241434822606848
                .{ .delta = 22, .cutoff = "211758236813575084767080625169910490512847900390625" }, // 4722366482869645213696
                .{ .delta = 22, .cutoff = "1058791184067875423835403125849552452564239501953125" }, // 9444732965739290427392
                .{ .delta = 23, .cutoff = "5293955920339377119177015629247762262821197509765625" }, // 18889465931478580854784
                .{ .delta = 23, .cutoff = "26469779601696885595885078146238811314105987548828125" }, // 37778931862957161709568
                .{ .delta = 23, .cutoff = "132348898008484427979425390731194056570529937744140625" }, // 75557863725914323419136
                .{ .delta = 24, .cutoff = "661744490042422139897126953655970282852649688720703125" }, // 151115727451828646838272
                .{ .delta = 24, .cutoff = "3308722450212110699485634768279851414263248443603515625" }, // 302231454903657293676544
                .{ .delta = 24, .cutoff = "16543612251060553497428173841399257071316242218017578125" }, // 604462909807314587353088
                .{ .delta = 25, .cutoff = "82718061255302767487140869206996285356581211090087890625" }, // 1208925819614629174706176
                .{ .delta = 25, .cutoff = "413590306276513837435704346034981426782906055450439453125" }, // 2417851639229258349412352
                .{ .delta = 25, .cutoff = "2067951531382569187178521730174907133914530277252197265625" }, // 4835703278458516698824704
                .{ .delta = 25, .cutoff = "10339757656912845935892608650874535669572651386260986328125" }, // 9671406556917033397649408
                .{ .delta = 26, .cutoff = "51698788284564229679463043254372678347863256931304931640625" }, // 19342813113834066795298816
                .{ .delta = 26, .cutoff = "258493941422821148397315216271863391739316284656524658203125" }, // 38685626227668133590597632
                .{ .delta = 26, .cutoff = "1292469707114105741986576081359316958696581423282623291015625" }, // 77371252455336267181195264
                .{ .delta = 27, .cutoff = "6462348535570528709932880406796584793482907116413116455078125" }, // 154742504910672534362390528
                .{ .delta = 27, .cutoff = "32311742677852643549664402033982923967414535582065582275390625" }, // 309485009821345068724781056
                .{ .delta = 27, .cutoff = "161558713389263217748322010169914619837072677910327911376953125" }, // 618970019642690137449562112
                .{ .delta = 28, .cutoff = "807793566946316088741610050849573099185363389551639556884765625" }, // 1237940039285380274899124224
                .{ .delta = 28, .cutoff = "4038967834731580443708050254247865495926816947758197784423828125" }, // 2475880078570760549798248448
                .{ .delta = 28, .cutoff = "20194839173657902218540251271239327479634084738790988922119140625" }, // 4951760157141521099596496896
                .{ .delta = 28, .cutoff = "100974195868289511092701256356196637398170423693954944610595703125" }, // 9903520314283042199192993792
                .{ .delta = 29, .cutoff = "504870979341447555463506281780983186990852118469774723052978515625" }, // 19807040628566084398385987584
                .{ .delta = 29, .cutoff = "2524354896707237777317531408904915934954260592348873615264892578125" }, // 39614081257132168796771975168
                .{ .delta = 29, .cutoff = "12621774483536188886587657044524579674771302961744368076324462890625" }, // 79228162514264337593543950336
                .{ .delta = 30, .cutoff = "63108872417680944432938285222622898373856514808721840381622314453125" }, // 158456325028528675187087900672
                .{ .delta = 30, .cutoff = "315544362088404722164691426113114491869282574043609201908111572265625" }, // 316912650057057350374175801344
                .{ .delta = 30, .cutoff = "1577721810442023610823457130565572459346412870218046009540557861328125" }, // 633825300114114700748351602688
                .{ .delta = 31, .cutoff = "7888609052210118054117285652827862296732064351090230047702789306640625" }, // 1267650600228229401496703205376
                .{ .delta = 31, .cutoff = "39443045261050590270586428264139311483660321755451150238513946533203125" }, // 2535301200456458802993406410752
                .{ .delta = 31, .cutoff = "197215226305252951352932141320696557418301608777255751192569732666015625" }, // 5070602400912917605986812821504
                .{ .delta = 32, .cutoff = "986076131526264756764660706603482787091508043886278755962848663330078125" }, // 10141204801825835211973625643008
                .{ .delta = 32, .cutoff = "4930380657631323783823303533017413935457540219431393779814243316650390625" }, // 20282409603651670423947251286016
                .{ .delta = 32, .cutoff = "24651903288156618919116517665087069677287701097156968899071216583251953125" }, // 40564819207303340847894502572032
                .{ .delta = 32, .cutoff = "123259516440783094595582588325435348386438505485784844495356082916259765625" }, // 81129638414606681695789005144064
                .{ .delta = 33, .cutoff = "616297582203915472977912941627176741932192527428924222476780414581298828125" }, // 162259276829213363391578010288128
                .{ .delta = 33, .cutoff = "3081487911019577364889564708135883709660962637144621112383902072906494140625" }, // 324518553658426726783156020576256
                .{ .delta = 33, .cutoff = "15407439555097886824447823540679418548304813185723105561919510364532470703125" }, // 649037107316853453566312041152512
                .{ .delta = 34, .cutoff = "77037197775489434122239117703397092741524065928615527809597551822662353515625" }, // 1298074214633706907132624082305024
                .{ .delta = 34, .cutoff = "385185988877447170611195588516985463707620329643077639047987759113311767578125" }, // 2596148429267413814265248164610048
                .{ .delta = 34, .cutoff = "1925929944387235853055977942584927318538101648215388195239938795566558837890625" }, // 5192296858534827628530496329220096
                .{ .delta = 35, .cutoff = "9629649721936179265279889712924636592690508241076940976199693977832794189453125" }, // 10384593717069655257060992658440192
                .{ .delta = 35, .cutoff = "48148248609680896326399448564623182963452541205384704880998469889163970947265625" }, // 20769187434139310514121985316880384
                .{ .delta = 35, .cutoff = "240741243048404481631997242823115914817262706026923524404992349445819854736328125" }, // 41538374868278621028243970633760768
                .{ .delta = 35, .cutoff = "1203706215242022408159986214115579574086313530134617622024961747229099273681640625" }, // 83076749736557242056487941267521536
                .{ .delta = 36, .cutoff = "6018531076210112040799931070577897870431567650673088110124808736145496368408203125" }, // 166153499473114484112975882535043072
                .{ .delta = 36, .cutoff = "30092655381050560203999655352889489352157838253365440550624043680727481842041015625" }, // 332306998946228968225951765070086144
                .{ .delta = 36, .cutoff = "150463276905252801019998276764447446760789191266827202753120218403637409210205078125" }, // 664613997892457936451903530140172288
                .{ .delta = 37, .cutoff = "752316384526264005099991383822237233803945956334136013765601092018187046051025390625" }, // 1329227995784915872903807060280344576
                .{ .delta = 37, .cutoff = "3761581922631320025499956919111186169019729781670680068828005460090935230255126953125" }, // 2658455991569831745807614120560689152
                .{ .delta = 37, .cutoff = "18807909613156600127499784595555930845098648908353400344140027300454676151275634765625" }, // 5316911983139663491615228241121378304
                .{ .delta = 38, .cutoff = "94039548065783000637498922977779654225493244541767001720700136502273380756378173828125" }, // 10633823966279326983230456482242756608
                .{ .delta = 38, .cutoff = "470197740328915003187494614888898271127466222708835008603500682511366903781890869140625" }, // 21267647932558653966460912964485513216
                .{ .delta = 38, .cutoff = "2350988701644575015937473074444491355637331113544175043017503412556834518909454345703125" }, // 42535295865117307932921825928971026432
                .{ .delta = 38, .cutoff = "11754943508222875079687365372222456778186655567720875215087517062784172594547271728515625" }, // 85070591730234615865843651857942052864
                .{ .delta = 39, .cutoff = "58774717541114375398436826861112283890933277838604376075437585313920862972736358642578125" }, // 170141183460469231731687303715884105728
            };

            std.debug.assert(shift < pow2_to_pow5_table.len);
            const x = pow2_to_pow5_table[shift];

            // Compare leading digits of current to check if lexicographically less than cutoff.
            for (x.cutoff, 0..) |p5, i| {
                if (i >= self.num_digits) {
                    return x.delta - 1;
                } else if (self.digits[i] == p5 - '0') { // digits are stored as integers
                    continue;
                } else if (self.digits[i] < p5 - '0') {
                    return x.delta - 1;
                } else {
                    return x.delta;
                }
                return x.delta;
            }
            return x.delta;
        }
    };
}
