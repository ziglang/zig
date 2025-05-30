const AddOneBit = math.AddOneBit;
const AsSignedness = math.AsSignedness;
const cast = math.cast;
const ChangeScalar = math.ChangeScalar;
const checkExpected = math.checkExpected;
const Compare = math.Compare;
const DoubleBits = math.DoubleBits;
const fmax = math.fmax;
const fmin = math.fmin;
const Gpr = math.Gpr;
const imax = math.imax;
const inf = math.inf;
const Log2Int = math.Log2Int;
const math = @import("math.zig");
const nan = math.nan;
const Scalar = math.Scalar;
const sign = math.sign;
const splat = math.splat;
const Sse = math.Sse;
const tmin = math.tmin;

fn binary(comptime op: anytype, comptime opts: struct { compare: Compare = .relaxed }) type {
    return struct {
        // noinline so that `mem_lhs` and `mem_rhs` are on the stack
        noinline fn testArgKinds(
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Gpr,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            _: Sse,
            comptime Type: type,
            comptime imm_lhs: Type,
            mem_lhs: Type,
            comptime imm_rhs: Type,
            mem_rhs: Type,
        ) !void {
            const expected = comptime op(Type, imm_lhs, imm_rhs);
            var reg_lhs = mem_lhs;
            var reg_rhs = mem_rhs;
            _ = .{ &reg_lhs, &reg_rhs };
            try checkExpected(expected, op(Type, reg_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, reg_lhs, mem_rhs), opts.compare);
            try checkExpected(expected, op(Type, reg_lhs, imm_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, mem_rhs), opts.compare);
            try checkExpected(expected, op(Type, mem_lhs, imm_rhs), opts.compare);
            try checkExpected(expected, op(Type, imm_lhs, reg_rhs), opts.compare);
            try checkExpected(expected, op(Type, imm_lhs, mem_rhs), opts.compare);
        }
        // noinline for a more helpful stack trace
        noinline fn testArgs(comptime Type: type, comptime imm_lhs: Type, comptime imm_rhs: Type) !void {
            try testArgKinds(
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                undefined,
                Type,
                imm_lhs,
                imm_lhs,
                imm_rhs,
                imm_rhs,
            );
        }
        fn testInts() !void {
            try testArgs(i1, 0x0, -0x1);
            try testArgs(u1, 0x1, 0x1);
            try testArgs(i2, 0x0, -0x2);
            try testArgs(u2, 0x2, 0x1);
            try testArgs(i3, 0x1, -0x3);
            try testArgs(u3, 0x6, 0x1);
            try testArgs(i4, 0x6, 0x3);
            try testArgs(u4, 0x8, 0x5);
            try testArgs(i5, -0x9, -0xd);
            try testArgs(u5, 0x5, 0x13);
            try testArgs(i7, 0x34, 0x1d);
            try testArgs(u7, 0x31, 0x56);
            try testArgs(i8, -0x57, -0x70);
            try testArgs(u8, 0x12, 0xd6);
            try testArgs(i9, -0x8a, -0xa0);
            try testArgs(u9, 0xf8, 0x95);
            try testArgs(i15, -0x790, 0x116f);
            try testArgs(u15, 0x548b, 0x4cd6);
            try testArgs(i16, -0x2d17, -0x5c17);
            try testArgs(u16, 0xadc0, 0xb223);
            try testArgs(i17, 0xe543, 0xaad5);
            try testArgs(u17, 0x9515, 0xa3c1);
            try testArgs(i31, -0x28858a2f, 0x369e917a);
            try testArgs(u31, 0x32bab794, 0x75464e7f);
            try testArgs(i32, 0x79e74e44, 0x61fe4ab1);
            try testArgs(u32, 0xc82f8e2, 0x5dde37e2);
            try testArgs(i33, -0xa4cbaa13, -0x4d20ee61);
            try testArgs(u33, 0x17461d437, 0x16cbc228f);
            try testArgs(i63, 0x333220e16b1e53fb, 0x121a0d970a5a4504);
            try testArgs(u63, 0x2dcd94e2ae4aa2af, 0x5f401e6e287a4dd7);
            try testArgs(i64, 0x17e6bb7d8d430410, 0x760d42736f4b445c);
            try testArgs(u64, 0x430970421452be50, 0xb4b5e96f4183b5fc);
            try testArgs(i65, 0xb4477484679a6576, 0x21c9a3100d35de49);
            try testArgs(u65, 0x1b7ffa914193a316, 0x6751268790308460);
            try testArgs(i95, 0xd573e2100686f5df03aa29f, 0x4f7c921eb980b43a554b763);
            try testArgs(u95, 0x62791162d2740f3ae84a9fcf, 0x1b6e66ae70bb9785a2118ecc);
            try testArgs(i96, -0x6dc72375264ab887ea6073d5, 0x357ca705a600e94f6dd114c9);
            try testArgs(u96, 0x77867877aae9bc90b2b57ce7, 0xd9a5352eb86061b67a61b212);
            try testArgs(i97, 0x76f421e0ccfc6e7531c03ad5, 0x6775cdacdfca5455771c0dae);
            try testArgs(u97, 0xaeb79499018e490b6aa2a5fc, 0x6cf53b08068cf25bdc307606);
            try testArgs(i127, -0xc6de705251f892f8ba6a4f10aee0c7, -0x1598d3c6fd635ec0796a584af7479027);
            try testArgs(u127, 0x5b3ec94f88a61621be2f745e90153390, 0x72456ad6a7ef886decf13195a50ca4d6);
            try testArgs(i128, -0x44570544f745b89beb111016359577d5, -0x48904e59a05caede0974f916efba61a0);
            try testArgs(u128, 0x3b14f670f6ac712d087a9ec7b15394d2, 0x19b69cb71a6763a9dc5baec5bb818450);
            try testArgs(i129, 0xd58a765abb324106d83362db47fc374d, 0x548642028e222abf2ee21a1999a8ac5f);
            try testArgs(u129, 0x1144fb18eba36e437bc45a73bbe25f10e, 0xdc7cb5f65f5127b00a842adf3f5a5231);
            try testArgs(i159, 0x3121c6ae74c46679386f2051ee0520d9264e01cf, -0x34fec2cf28ce549281a5dc79f7ed834483f418af);
            try testArgs(u159, 0x2e479684775f86a8ff1a9c6fab9022b18a6f6be4, 0x63c77ea3d97ad2c715fd13db972e678fefe3efba);
            try testArgs(i160, 0x1e55924219aa114ef8d2b3193d09ae7849a3e551, -0x13f1ff6a62e562f7b78559f032bb05b2e2d15748);
            try testArgs(u160, 0x8ed3d206fcc59350cf23dcd9e042eb36bcc63e52, 0xc88e1c5a42abf98aee0a3479e7f4fe88ab53b6f2);
            try testArgs(i161, -0xd3d6885c0df36bd513aca744561684d12a62f044, 0xa519d3c4a7ea2e4768d840ec8641995689de6116);
            try testArgs(u161, 0x10b4afdfa36471c77a2b629ef85e1289b798161b, 0x15e89da33c31ec01adf6921b8d13bc943f139fba2);
            try testArgs(i191, 0x2436122b85c017733d9d28347544298d148223e1d9cbf0a2, 0x46b80688a0e0b59e66628940772893fcce258d3da7c0193);
            try testArgs(u191, 0x3d00a8da821de44f98fa70d298bda9e25f99d8f54936d09f, 0x4ad4440686be966599985094f16e364c961503214ff86519);
            try testArgs(i192, 0x124d0580271a71745f842e3a81d8cb6154c7f6f4b8b0cf39, -0x5bae9d7d471e609f1570a3f9805b80c4d672a086d44107eb);
            try testArgs(u192, 0x3b882677dc62d5c76cc942bea0d2f72925ff0a9e234d7ce9, 0x5d7825e3f2254bf214257ebe84716dc88fde6c9563218ac4);
            try testArgs(i193, 0x9c143db83d19c8fff1c23f3c93b103eaf8be02910a1cbe5, 0xcfa1059ba12508d2ff3ef9763ce8224eb1d0a0f22def289d);
            try testArgs(u193, 0x635890f170da79117490445db595c1f2bb5a5cf640abc8e8, 0xdb5a2a6a3c6db7f43949123f0886cb93bbbed2d5dd7690e);
            try testArgs(i223, -0x25e4a8d454e5957a9906a66a0c02ad53e727e3e18ca4b8be98561306, 0x8d6d3977afce56a5dffc537de19d4c73f2e5603699373d010e51d10);
            try testArgs(u223, 0x5721636a3c6d271fe9eb08420d29454775666266801a7d23d61075be, 0x7e573fd8dcbd6dc780d13b61d5255cae790ea697d1c9a5479fa51ee);
            try testArgs(i224, 0x51f97aaa96493aaed2677294bfde0715d69d961fef97a557ae9dbc84, 0x306d9305e2d5162dd0ce0454d2daaa54879b11a77386bb03e779a23e);
            try testArgs(u224, 0xdc7eb2070c048b6fd22d6df97b3ef5e9fc5f28d8d229710333defecd, 0x475662887f29712bc927fae9de37cd842d883682a26e653d7b3f2ed9);
            try testArgs(i225, -0x9b3dba4fe2026e8d90d9be4b8b2334034d2ae23569c4e1a3a311925d, -0x2ae4c074cff2da1e7fcab269ce6da7f4a9f763062f97526c0b4abf34);
            try testArgs(u225, 0xb36dd536afb070e9be7fba5eaf548fe741182cabaf9f9510f86b3ffb, 0x1f35e5728f29e2566afd9a325beaf17ebf5f894e744825bdd56bb12d0);
            try testArgs(i255, 0x2db696171e4045e17cb2a96763ff2728b459e5bf9ade6e9cd118bbc4f91aca89, -0x1580d80086052560091fe42077ce66c45d7e93173f74327f44fec7b63ed9f2aa);
            try testArgs(u255, 0x392b3639141d03da49d576fd0ce498e1bafb8fc032604e68e91e589f6d2a05a3, 0x46f60e500f01bdbe18f71fb8dbef0395245a94f55421637ca50eb8922a751977);
            try testArgs(i256, -0x2f3c22cb1d12628b2eccd705f1526d8a91258183742d9521bdc97d943591d87c, -0x864d3ef8b592e041289dbb54def60ceee798673138aa750a5efdaffcd42b62d);
            try testArgs(u256, 0x25776f0ce5f3c6761eec99ace965f9162e9416e4d4e298674e5723b64e443528, 0xb1ee7fd2efaddd5d25eea49bde34e53c40d59221757f17d53d9a4c9ab7eca3f5);
            try testArgs(i257, 0xd599706e1a09217f1f698520993d2b62ee877a4150bd8db6e5546657900dc7ce, 0x51d0faef82bb0878a4fd4331dcaec6ed57156acc2377c7e301eca6989e897346);
            try testArgs(u257, 0xb0d42105facc0db629c5a65d6e975d25163841051efb1e187b70015f8c9e22ba, 0xf0eb6d0529e15fac6e97e850f50b7bf5056c9010345884926bf056590ddf3187);
            try testArgs(i511, 0x23c07fa26fea1595de6e368cb42d05696562d8fb05a2aab6b304c443275071a31684a369f69f30fd53223017669dcf8157f7ff1bcda05ad28dcf46c92f7f2bd5, 0x44884ae45727d2c249b280cbb6795f237015f1082ade12167c52f0318422b3ae9c1753263011878e3fa4fce0db683efdd249e325188a40ccb959bd6bf050fbf);
            try testArgs(u511, 0x642d98a41a7cc71dab7845c2c568696d0d77733c266846019756937cc29382d46074c8eb86502f4855c35f6354e51d98c41674166a9a7385ab94b0c7a63f58c0, 0x3cc5230f530a12c8cae29654e55a6d7cd26fe7606beed5c9a8fef443b107bf18dd8cc034683b47a213a3a885abd7048188713e8e7b9157145cd24748e256f5b7);
            try testArgs(i512, -0x4b6d88a77e2a42d67daada905d16c6045b4dd57e608a0482f45531781d4994e2a6b71ad41a106b2dfc76e60aebd9e1d357b24b8d6889de3cf3e58ff3a48f54aa, -0x2e28e1b21ec33fd5dd9b1fbdc312e32884208b549ce0ca1661ca1150a6bd43363d4d186aa8ac70ad0595b44b5279ff070df8bd0b51095c62c8c499bfcaa7494c);
            try testArgs(u512, 0xf40ad922664478a7b71a5676fc49434a45ba86975cef377c8321159cd880b67cd543fcca70187d5912675c0bc1fa4129cb470f280cde56ac4ec848ca589f143f, 0xe20a8110780ff05718adc173677ff0579126576f1fc3857ac41d6b7d5334d93134181af15ce2d35224d2e5c63384f33e331b16ecbc6db44edbb4074134d23e97);
            try testArgs(i513, 0x55a556c6b6605897ffb7a791bdf309d5edb879f2841d1bba37006cdd0e7d00d971c85def024e28b7a17e53f3bcf5a5d5c43e780c6d13d67de1ca7b8f05deddfb, 0x53f475716443b38792e618ce109cec641aa351ce2e258a99153820c5522a4acc7f2b5b4ecd0000bcbe5a410bbee200576f6ff17ce7e8b7d1f0752390d1bb9b3f);
            try testArgs(u513, 0x1e4e15bc406c558c14f48b83090647d7f2254fa571eac7f8aad8edb76a90547f7854bd6315e50ad44ea93034db9fab450a584b53abf8537e31d39cd706a31eaa7, 0x1d348de8124b72ca1d0e382501024c9e1b0f6fc16c5cd4a86aef2731bd39c29173749afe94bb2992ea805148fe0d96abdc5980b2143bd81419c1e40bf81b2496f);
            try testArgs(i1023, -0x37781a6086d9310e4cdb24f5f374736e32af53c9545298aa53fe17854f73052cd808f658efacea622c59adb51af4d2dd636521ca2717acc43389c975505b7543da2c62f33c3152907f13b1ffa5b9881b33acec3cab1d8e33c2239ea6835277c474629a9157f8acd7c1d83076c2e75a48a8d3a94067e801c51057e47e09f0be14, 0x39ad04132dec8b795b98fd7cd085605ce8354655633068ee485d9dc78853feb922a54a3df6209989d1137e4ea8b0ad2cae48b21df2e0c04feeca56d2551f12782312a6ae483ffff466ff78446ebd4d47a61c1cba2603a62b44a72800060dda7eec8bc9060b8c5533afa7946bd38e93fddb863392500c22616dd4ae4932f20fe4);
            try testArgs(u1023, 0x6e14a9d998a9ef7ac77b6fe08225fcc176e687685736e0e32c9e6b8fe96e9a7b14b3318310e945f7f84128455075eedb4a7b7736185f58e5640688c5d3b47d785338a0b70e77f4d237fd85f7820f3ebe6eb30f5a71231e813a70d6c76963d66291f271cd6f462ce685a0270ec5f6e856340f91d7597cd2b779566fe3ff4d4a98, 0x211eafbd449691e390d14dd34cb9c4d32627ecbec485d4a0a7cca1b28bd81d2153a7a75c2f62c4c3c7f198740cfe65dfa3c86156aa0b6d22757fd07f4070ddd50e334782f045a58b96c5a8f04b4615968501e9b5e801c475bdc034919c9e9df6df3cbbd59bacfa9409b21c3365d10e132d75958774c6244446127b043d155ec4);
            try testArgs(i1024, 0xa6bd15fd4c529a24e4d727c5c0db9422ed7038ba23944b2b54ffc8d3731e2ffc19e12d885010fb10d208ea045e2a4cfec32d190f221bd453ec73fcecc03e37fd70be3fba3945c881cb9bce69f3f6ad9a6ee0d42a393b3669d1ca518d0b7b06a2c47978f22bc1db8802ef6ce29ea51b48256c6fed82e04355665f9d27ff485b, -0x69f258c2a86e97161ce2e683801591976a8e5a71b88605450961ee271637e6c2fee13459c29d42d4c5fb408f80236d3b2db34752e307fee6cbce2e5088adc817902a5adbbba72c8be84b9f8af5ce0fac464cae61cff9cbbe3a8dcdbec0af855b2e6c2c19fbe4f01baec9ca28b78bd7d383281c71d81da74fd0a2c8a5b754ee57);
            try testArgs(u1024, 0x111e0a4e0c61ab3c5229154539ddb010542cb528533b4ea13813d8dbbaca7de395aac3c22dae1bd9db8bf9005ea9ef3df253aefabdce060a93e60da6edc3b1b2d78aead4647e7a589b66aa53fb953742b71f823b539150918df0fe781ee4d00279e4da9995804391bb19504de2f108f7d6ba14d624fa175842bd429f638de8f9, 0xcf9160dcb7ed13a738f7c8b2a17ca2fe84f53620a50f6a948698c4efca88392dc104ef5d26f19c82c8f770f727585702cc8d1c4cc2bba9e691e61b055d98cd636347a7c50b3bd2b2f5dfa416dadbdd76c111d45598c93ef729588cf998a55260cfe94d376ec4e8dc132afa42b66b68bc826c50169f9f4fc798cf7e8f29df639a);
            try testArgs(i1025, 0xef2102c2cab6ad6bf2f2ba09c154440e65acc56cb14c5221a12b12404f7eafefeab4537f70cc10afb945e93c935223ffd3146911021666fd68fcaa494ded54ce66d2832b1d82b0654f24f1183bbc3ee45eb15c424a74ad41f22c7009b86cb404ac3b810445679417d7e0c5d5f4e88dec7c90352afa367004facbc1d668ab0a7, 0xc7743d3a52bad9bed0d24dbeaac4f27f4790ee14e984484f7ee077e6285394f046f2ba6d3a9c6e0aea1c07de98741a88669a035ec4d9755130fe96414223486e89d710a743ca2c2b53871fdb4851d90a595111d8d12e6732e4b580e235218edee3bc56fca3de99bc5f9a37c9dbc9a8ca5aaba710ec5e498b58b239a1be56915b);
            try testArgs(u1025, 0x1dea81169800bac2f3afcf3be5dbd2d8eefbace8a24a2da0a383a928d1109459f34028be4413119f1af00ad90ce4d63064016dc1cee5b783c79c1998a0a49de21c4db71d432273576503589fc966c7ec2d730fa9bc4c5ff3128a82653ab8149528de67804718e39722f89b91c75d012ea41c642c889f0db95c882a9790a5e922f, 0x156fe02946ab9069a644dcc1f2b1afa04ee88ab1de19575a2715abf4a52bf374d297fdf78455ccdb87a934d3d818d774b63865eaedfdad3c56a56b8fcc62703c391aedf16cf770af06d7d205f93778c012df54fe5290084e1cd2bbec86a2f295cdce69a2cd774e064580f3c9cfae60d17b12f610e86566e68d5183d706c8ad8af);
        }
        fn testFloats() !void {
            @setEvalBranchQuota(21_700);

            try testArgs(f16, -nan(f16), -nan(f16));
            try testArgs(f16, -nan(f16), -inf(f16));
            try testArgs(f16, -nan(f16), -fmax(f16));
            try testArgs(f16, -nan(f16), -1e1);
            try testArgs(f16, -nan(f16), -1e0);
            try testArgs(f16, -nan(f16), -1e-1);
            try testArgs(f16, -nan(f16), -fmin(f16));
            try testArgs(f16, -nan(f16), -tmin(f16));
            try testArgs(f16, -nan(f16), -0.0);
            try testArgs(f16, -nan(f16), 0.0);
            try testArgs(f16, -nan(f16), tmin(f16));
            try testArgs(f16, -nan(f16), fmin(f16));
            try testArgs(f16, -nan(f16), 1e-1);
            try testArgs(f16, -nan(f16), 1e0);
            try testArgs(f16, -nan(f16), 1e1);
            try testArgs(f16, -nan(f16), fmax(f16));
            try testArgs(f16, -nan(f16), inf(f16));
            try testArgs(f16, -nan(f16), nan(f16));

            try testArgs(f16, -inf(f16), -nan(f16));
            try testArgs(f16, -inf(f16), -inf(f16));
            try testArgs(f16, -inf(f16), -fmax(f16));
            try testArgs(f16, -inf(f16), -1e1);
            try testArgs(f16, -inf(f16), -1e0);
            try testArgs(f16, -inf(f16), -1e-1);
            try testArgs(f16, -inf(f16), -fmin(f16));
            try testArgs(f16, -inf(f16), -tmin(f16));
            try testArgs(f16, -inf(f16), -0.0);
            try testArgs(f16, -inf(f16), 0.0);
            try testArgs(f16, -inf(f16), tmin(f16));
            try testArgs(f16, -inf(f16), fmin(f16));
            try testArgs(f16, -inf(f16), 1e-1);
            try testArgs(f16, -inf(f16), 1e0);
            try testArgs(f16, -inf(f16), 1e1);
            try testArgs(f16, -inf(f16), fmax(f16));
            try testArgs(f16, -inf(f16), inf(f16));
            try testArgs(f16, -inf(f16), nan(f16));

            try testArgs(f16, -fmax(f16), -nan(f16));
            try testArgs(f16, -fmax(f16), -inf(f16));
            try testArgs(f16, -fmax(f16), -fmax(f16));
            try testArgs(f16, -fmax(f16), -1e1);
            try testArgs(f16, -fmax(f16), -1e0);
            try testArgs(f16, -fmax(f16), -1e-1);
            try testArgs(f16, -fmax(f16), -fmin(f16));
            try testArgs(f16, -fmax(f16), -tmin(f16));
            try testArgs(f16, -fmax(f16), -0.0);
            try testArgs(f16, -fmax(f16), 0.0);
            try testArgs(f16, -fmax(f16), tmin(f16));
            try testArgs(f16, -fmax(f16), fmin(f16));
            try testArgs(f16, -fmax(f16), 1e-1);
            try testArgs(f16, -fmax(f16), 1e0);
            try testArgs(f16, -fmax(f16), 1e1);
            try testArgs(f16, -fmax(f16), fmax(f16));
            try testArgs(f16, -fmax(f16), inf(f16));
            try testArgs(f16, -fmax(f16), nan(f16));

            try testArgs(f16, -1e1, -nan(f16));
            try testArgs(f16, -1e1, -inf(f16));
            try testArgs(f16, -1e1, -fmax(f16));
            try testArgs(f16, -1e1, -1e1);
            try testArgs(f16, -1e1, -1e0);
            try testArgs(f16, -1e1, -1e-1);
            try testArgs(f16, -1e1, -fmin(f16));
            try testArgs(f16, -1e1, -tmin(f16));
            try testArgs(f16, -1e1, -0.0);
            try testArgs(f16, -1e1, 0.0);
            try testArgs(f16, -1e1, tmin(f16));
            try testArgs(f16, -1e1, fmin(f16));
            try testArgs(f16, -1e1, 1e-1);
            try testArgs(f16, -1e1, 1e0);
            try testArgs(f16, -1e1, 1e1);
            try testArgs(f16, -1e1, fmax(f16));
            try testArgs(f16, -1e1, inf(f16));
            try testArgs(f16, -1e1, nan(f16));

            try testArgs(f16, -1e0, -nan(f16));
            try testArgs(f16, -1e0, -inf(f16));
            try testArgs(f16, -1e0, -fmax(f16));
            try testArgs(f16, -1e0, -1e1);
            try testArgs(f16, -1e0, -1e0);
            try testArgs(f16, -1e0, -1e-1);
            try testArgs(f16, -1e0, -fmin(f16));
            try testArgs(f16, -1e0, -tmin(f16));
            try testArgs(f16, -1e0, -0.0);
            try testArgs(f16, -1e0, 0.0);
            try testArgs(f16, -1e0, tmin(f16));
            try testArgs(f16, -1e0, fmin(f16));
            try testArgs(f16, -1e0, 1e-1);
            try testArgs(f16, -1e0, 1e0);
            try testArgs(f16, -1e0, 1e1);
            try testArgs(f16, -1e0, fmax(f16));
            try testArgs(f16, -1e0, inf(f16));
            try testArgs(f16, -1e0, nan(f16));

            try testArgs(f16, -1e-1, -nan(f16));
            try testArgs(f16, -1e-1, -inf(f16));
            try testArgs(f16, -1e-1, -fmax(f16));
            try testArgs(f16, -1e-1, -1e1);
            try testArgs(f16, -1e-1, -1e0);
            try testArgs(f16, -1e-1, -1e-1);
            try testArgs(f16, -1e-1, -fmin(f16));
            try testArgs(f16, -1e-1, -tmin(f16));
            try testArgs(f16, -1e-1, -0.0);
            try testArgs(f16, -1e-1, 0.0);
            try testArgs(f16, -1e-1, tmin(f16));
            try testArgs(f16, -1e-1, fmin(f16));
            try testArgs(f16, -1e-1, 1e-1);
            try testArgs(f16, -1e-1, 1e0);
            try testArgs(f16, -1e-1, 1e1);
            try testArgs(f16, -1e-1, fmax(f16));
            try testArgs(f16, -1e-1, inf(f16));
            try testArgs(f16, -1e-1, nan(f16));

            try testArgs(f16, -fmin(f16), -nan(f16));
            try testArgs(f16, -fmin(f16), -inf(f16));
            try testArgs(f16, -fmin(f16), -fmax(f16));
            try testArgs(f16, -fmin(f16), -1e1);
            try testArgs(f16, -fmin(f16), -1e0);
            try testArgs(f16, -fmin(f16), -1e-1);
            try testArgs(f16, -fmin(f16), -fmin(f16));
            try testArgs(f16, -fmin(f16), -tmin(f16));
            try testArgs(f16, -fmin(f16), -0.0);
            try testArgs(f16, -fmin(f16), 0.0);
            try testArgs(f16, -fmin(f16), tmin(f16));
            try testArgs(f16, -fmin(f16), fmin(f16));
            try testArgs(f16, -fmin(f16), 1e-1);
            try testArgs(f16, -fmin(f16), 1e0);
            try testArgs(f16, -fmin(f16), 1e1);
            try testArgs(f16, -fmin(f16), fmax(f16));
            try testArgs(f16, -fmin(f16), inf(f16));
            try testArgs(f16, -fmin(f16), nan(f16));

            try testArgs(f16, -tmin(f16), -nan(f16));
            try testArgs(f16, -tmin(f16), -inf(f16));
            try testArgs(f16, -tmin(f16), -fmax(f16));
            try testArgs(f16, -tmin(f16), -1e1);
            try testArgs(f16, -tmin(f16), -1e0);
            try testArgs(f16, -tmin(f16), -1e-1);
            try testArgs(f16, -tmin(f16), -fmin(f16));
            try testArgs(f16, -tmin(f16), -tmin(f16));
            try testArgs(f16, -tmin(f16), -0.0);
            try testArgs(f16, -tmin(f16), 0.0);
            try testArgs(f16, -tmin(f16), tmin(f16));
            try testArgs(f16, -tmin(f16), fmin(f16));
            try testArgs(f16, -tmin(f16), 1e-1);
            try testArgs(f16, -tmin(f16), 1e0);
            try testArgs(f16, -tmin(f16), 1e1);
            try testArgs(f16, -tmin(f16), fmax(f16));
            try testArgs(f16, -tmin(f16), inf(f16));
            try testArgs(f16, -tmin(f16), nan(f16));

            try testArgs(f16, -0.0, -nan(f16));
            try testArgs(f16, -0.0, -inf(f16));
            try testArgs(f16, -0.0, -fmax(f16));
            try testArgs(f16, -0.0, -1e1);
            try testArgs(f16, -0.0, -1e0);
            try testArgs(f16, -0.0, -1e-1);
            try testArgs(f16, -0.0, -fmin(f16));
            try testArgs(f16, -0.0, -tmin(f16));
            try testArgs(f16, -0.0, -0.0);
            try testArgs(f16, -0.0, 0.0);
            try testArgs(f16, -0.0, tmin(f16));
            try testArgs(f16, -0.0, fmin(f16));
            try testArgs(f16, -0.0, 1e-1);
            try testArgs(f16, -0.0, 1e0);
            try testArgs(f16, -0.0, 1e1);
            try testArgs(f16, -0.0, fmax(f16));
            try testArgs(f16, -0.0, inf(f16));
            try testArgs(f16, -0.0, nan(f16));

            try testArgs(f16, 0.0, -nan(f16));
            try testArgs(f16, 0.0, -inf(f16));
            try testArgs(f16, 0.0, -fmax(f16));
            try testArgs(f16, 0.0, -1e1);
            try testArgs(f16, 0.0, -1e0);
            try testArgs(f16, 0.0, -1e-1);
            try testArgs(f16, 0.0, -fmin(f16));
            try testArgs(f16, 0.0, -tmin(f16));
            try testArgs(f16, 0.0, -0.0);
            try testArgs(f16, 0.0, 0.0);
            try testArgs(f16, 0.0, tmin(f16));
            try testArgs(f16, 0.0, fmin(f16));
            try testArgs(f16, 0.0, 1e-1);
            try testArgs(f16, 0.0, 1e0);
            try testArgs(f16, 0.0, 1e1);
            try testArgs(f16, 0.0, fmax(f16));
            try testArgs(f16, 0.0, inf(f16));
            try testArgs(f16, 0.0, nan(f16));

            try testArgs(f16, tmin(f16), -nan(f16));
            try testArgs(f16, tmin(f16), -inf(f16));
            try testArgs(f16, tmin(f16), -fmax(f16));
            try testArgs(f16, tmin(f16), -1e1);
            try testArgs(f16, tmin(f16), -1e0);
            try testArgs(f16, tmin(f16), -1e-1);
            try testArgs(f16, tmin(f16), -fmin(f16));
            try testArgs(f16, tmin(f16), -tmin(f16));
            try testArgs(f16, tmin(f16), -0.0);
            try testArgs(f16, tmin(f16), 0.0);
            try testArgs(f16, tmin(f16), tmin(f16));
            try testArgs(f16, tmin(f16), fmin(f16));
            try testArgs(f16, tmin(f16), 1e-1);
            try testArgs(f16, tmin(f16), 1e0);
            try testArgs(f16, tmin(f16), 1e1);
            try testArgs(f16, tmin(f16), fmax(f16));
            try testArgs(f16, tmin(f16), inf(f16));
            try testArgs(f16, tmin(f16), nan(f16));

            try testArgs(f16, fmin(f16), -nan(f16));
            try testArgs(f16, fmin(f16), -inf(f16));
            try testArgs(f16, fmin(f16), -fmax(f16));
            try testArgs(f16, fmin(f16), -1e1);
            try testArgs(f16, fmin(f16), -1e0);
            try testArgs(f16, fmin(f16), -1e-1);
            try testArgs(f16, fmin(f16), -fmin(f16));
            try testArgs(f16, fmin(f16), -tmin(f16));
            try testArgs(f16, fmin(f16), -0.0);
            try testArgs(f16, fmin(f16), 0.0);
            try testArgs(f16, fmin(f16), tmin(f16));
            try testArgs(f16, fmin(f16), fmin(f16));
            try testArgs(f16, fmin(f16), 1e-1);
            try testArgs(f16, fmin(f16), 1e0);
            try testArgs(f16, fmin(f16), 1e1);
            try testArgs(f16, fmin(f16), fmax(f16));
            try testArgs(f16, fmin(f16), inf(f16));
            try testArgs(f16, fmin(f16), nan(f16));

            try testArgs(f16, 1e-1, -nan(f16));
            try testArgs(f16, 1e-1, -inf(f16));
            try testArgs(f16, 1e-1, -fmax(f16));
            try testArgs(f16, 1e-1, -1e1);
            try testArgs(f16, 1e-1, -1e0);
            try testArgs(f16, 1e-1, -1e-1);
            try testArgs(f16, 1e-1, -fmin(f16));
            try testArgs(f16, 1e-1, -tmin(f16));
            try testArgs(f16, 1e-1, -0.0);
            try testArgs(f16, 1e-1, 0.0);
            try testArgs(f16, 1e-1, tmin(f16));
            try testArgs(f16, 1e-1, fmin(f16));
            try testArgs(f16, 1e-1, 1e-1);
            try testArgs(f16, 1e-1, 1e0);
            try testArgs(f16, 1e-1, 1e1);
            try testArgs(f16, 1e-1, fmax(f16));
            try testArgs(f16, 1e-1, inf(f16));
            try testArgs(f16, 1e-1, nan(f16));

            try testArgs(f16, 1e0, -nan(f16));
            try testArgs(f16, 1e0, -inf(f16));
            try testArgs(f16, 1e0, -fmax(f16));
            try testArgs(f16, 1e0, -1e1);
            try testArgs(f16, 1e0, -1e0);
            try testArgs(f16, 1e0, -1e-1);
            try testArgs(f16, 1e0, -fmin(f16));
            try testArgs(f16, 1e0, -tmin(f16));
            try testArgs(f16, 1e0, -0.0);
            try testArgs(f16, 1e0, 0.0);
            try testArgs(f16, 1e0, tmin(f16));
            try testArgs(f16, 1e0, fmin(f16));
            try testArgs(f16, 1e0, 1e-1);
            try testArgs(f16, 1e0, 1e0);
            try testArgs(f16, 1e0, 1e1);
            try testArgs(f16, 1e0, fmax(f16));
            try testArgs(f16, 1e0, inf(f16));
            try testArgs(f16, 1e0, nan(f16));

            try testArgs(f16, 1e1, -nan(f16));
            try testArgs(f16, 1e1, -inf(f16));
            try testArgs(f16, 1e1, -fmax(f16));
            try testArgs(f16, 1e1, -1e1);
            try testArgs(f16, 1e1, -1e0);
            try testArgs(f16, 1e1, -1e-1);
            try testArgs(f16, 1e1, -fmin(f16));
            try testArgs(f16, 1e1, -tmin(f16));
            try testArgs(f16, 1e1, -0.0);
            try testArgs(f16, 1e1, 0.0);
            try testArgs(f16, 1e1, tmin(f16));
            try testArgs(f16, 1e1, fmin(f16));
            try testArgs(f16, 1e1, 1e-1);
            try testArgs(f16, 1e1, 1e0);
            try testArgs(f16, 1e1, 1e1);
            try testArgs(f16, 1e1, fmax(f16));
            try testArgs(f16, 1e1, inf(f16));
            try testArgs(f16, 1e1, nan(f16));

            try testArgs(f16, fmax(f16), -nan(f16));
            try testArgs(f16, fmax(f16), -inf(f16));
            try testArgs(f16, fmax(f16), -fmax(f16));
            try testArgs(f16, fmax(f16), -1e1);
            try testArgs(f16, fmax(f16), -1e0);
            try testArgs(f16, fmax(f16), -1e-1);
            try testArgs(f16, fmax(f16), -fmin(f16));
            try testArgs(f16, fmax(f16), -tmin(f16));
            try testArgs(f16, fmax(f16), -0.0);
            try testArgs(f16, fmax(f16), 0.0);
            try testArgs(f16, fmax(f16), tmin(f16));
            try testArgs(f16, fmax(f16), fmin(f16));
            try testArgs(f16, fmax(f16), 1e-1);
            try testArgs(f16, fmax(f16), 1e0);
            try testArgs(f16, fmax(f16), 1e1);
            try testArgs(f16, fmax(f16), fmax(f16));
            try testArgs(f16, fmax(f16), inf(f16));
            try testArgs(f16, fmax(f16), nan(f16));

            try testArgs(f16, inf(f16), -nan(f16));
            try testArgs(f16, inf(f16), -inf(f16));
            try testArgs(f16, inf(f16), -fmax(f16));
            try testArgs(f16, inf(f16), -1e1);
            try testArgs(f16, inf(f16), -1e0);
            try testArgs(f16, inf(f16), -1e-1);
            try testArgs(f16, inf(f16), -fmin(f16));
            try testArgs(f16, inf(f16), -tmin(f16));
            try testArgs(f16, inf(f16), -0.0);
            try testArgs(f16, inf(f16), 0.0);
            try testArgs(f16, inf(f16), tmin(f16));
            try testArgs(f16, inf(f16), fmin(f16));
            try testArgs(f16, inf(f16), 1e-1);
            try testArgs(f16, inf(f16), 1e0);
            try testArgs(f16, inf(f16), 1e1);
            try testArgs(f16, inf(f16), fmax(f16));
            try testArgs(f16, inf(f16), inf(f16));
            try testArgs(f16, inf(f16), nan(f16));

            try testArgs(f16, nan(f16), -nan(f16));
            try testArgs(f16, nan(f16), -inf(f16));
            try testArgs(f16, nan(f16), -fmax(f16));
            try testArgs(f16, nan(f16), -1e1);
            try testArgs(f16, nan(f16), -1e0);
            try testArgs(f16, nan(f16), -1e-1);
            try testArgs(f16, nan(f16), -fmin(f16));
            try testArgs(f16, nan(f16), -tmin(f16));
            try testArgs(f16, nan(f16), -0.0);
            try testArgs(f16, nan(f16), 0.0);
            try testArgs(f16, nan(f16), tmin(f16));
            try testArgs(f16, nan(f16), fmin(f16));
            try testArgs(f16, nan(f16), 1e-1);
            try testArgs(f16, nan(f16), 1e0);
            try testArgs(f16, nan(f16), 1e1);
            try testArgs(f16, nan(f16), fmax(f16));
            try testArgs(f16, nan(f16), inf(f16));
            try testArgs(f16, nan(f16), nan(f16));

            try testArgs(f32, -nan(f32), -nan(f32));
            try testArgs(f32, -nan(f32), -inf(f32));
            try testArgs(f32, -nan(f32), -fmax(f32));
            try testArgs(f32, -nan(f32), -1e1);
            try testArgs(f32, -nan(f32), -1e0);
            try testArgs(f32, -nan(f32), -1e-1);
            try testArgs(f32, -nan(f32), -fmin(f32));
            try testArgs(f32, -nan(f32), -tmin(f32));
            try testArgs(f32, -nan(f32), -0.0);
            try testArgs(f32, -nan(f32), 0.0);
            try testArgs(f32, -nan(f32), tmin(f32));
            try testArgs(f32, -nan(f32), fmin(f32));
            try testArgs(f32, -nan(f32), 1e-1);
            try testArgs(f32, -nan(f32), 1e0);
            try testArgs(f32, -nan(f32), 1e1);
            try testArgs(f32, -nan(f32), fmax(f32));
            try testArgs(f32, -nan(f32), inf(f32));
            try testArgs(f32, -nan(f32), nan(f32));

            try testArgs(f32, -inf(f32), -nan(f32));
            try testArgs(f32, -inf(f32), -inf(f32));
            try testArgs(f32, -inf(f32), -fmax(f32));
            try testArgs(f32, -inf(f32), -1e1);
            try testArgs(f32, -inf(f32), -1e0);
            try testArgs(f32, -inf(f32), -1e-1);
            try testArgs(f32, -inf(f32), -fmin(f32));
            try testArgs(f32, -inf(f32), -tmin(f32));
            try testArgs(f32, -inf(f32), -0.0);
            try testArgs(f32, -inf(f32), 0.0);
            try testArgs(f32, -inf(f32), tmin(f32));
            try testArgs(f32, -inf(f32), fmin(f32));
            try testArgs(f32, -inf(f32), 1e-1);
            try testArgs(f32, -inf(f32), 1e0);
            try testArgs(f32, -inf(f32), 1e1);
            try testArgs(f32, -inf(f32), fmax(f32));
            try testArgs(f32, -inf(f32), inf(f32));
            try testArgs(f32, -inf(f32), nan(f32));

            try testArgs(f32, -fmax(f32), -nan(f32));
            try testArgs(f32, -fmax(f32), -inf(f32));
            try testArgs(f32, -fmax(f32), -fmax(f32));
            try testArgs(f32, -fmax(f32), -1e1);
            try testArgs(f32, -fmax(f32), -1e0);
            try testArgs(f32, -fmax(f32), -1e-1);
            try testArgs(f32, -fmax(f32), -fmin(f32));
            try testArgs(f32, -fmax(f32), -tmin(f32));
            try testArgs(f32, -fmax(f32), -0.0);
            try testArgs(f32, -fmax(f32), 0.0);
            try testArgs(f32, -fmax(f32), tmin(f32));
            try testArgs(f32, -fmax(f32), fmin(f32));
            try testArgs(f32, -fmax(f32), 1e-1);
            try testArgs(f32, -fmax(f32), 1e0);
            try testArgs(f32, -fmax(f32), 1e1);
            try testArgs(f32, -fmax(f32), fmax(f32));
            try testArgs(f32, -fmax(f32), inf(f32));
            try testArgs(f32, -fmax(f32), nan(f32));

            try testArgs(f32, -1e1, -nan(f32));
            try testArgs(f32, -1e1, -inf(f32));
            try testArgs(f32, -1e1, -fmax(f32));
            try testArgs(f32, -1e1, -1e1);
            try testArgs(f32, -1e1, -1e0);
            try testArgs(f32, -1e1, -1e-1);
            try testArgs(f32, -1e1, -fmin(f32));
            try testArgs(f32, -1e1, -tmin(f32));
            try testArgs(f32, -1e1, -0.0);
            try testArgs(f32, -1e1, 0.0);
            try testArgs(f32, -1e1, tmin(f32));
            try testArgs(f32, -1e1, fmin(f32));
            try testArgs(f32, -1e1, 1e-1);
            try testArgs(f32, -1e1, 1e0);
            try testArgs(f32, -1e1, 1e1);
            try testArgs(f32, -1e1, fmax(f32));
            try testArgs(f32, -1e1, inf(f32));
            try testArgs(f32, -1e1, nan(f32));

            try testArgs(f32, -1e0, -nan(f32));
            try testArgs(f32, -1e0, -inf(f32));
            try testArgs(f32, -1e0, -fmax(f32));
            try testArgs(f32, -1e0, -1e1);
            try testArgs(f32, -1e0, -1e0);
            try testArgs(f32, -1e0, -1e-1);
            try testArgs(f32, -1e0, -fmin(f32));
            try testArgs(f32, -1e0, -tmin(f32));
            try testArgs(f32, -1e0, -0.0);
            try testArgs(f32, -1e0, 0.0);
            try testArgs(f32, -1e0, tmin(f32));
            try testArgs(f32, -1e0, fmin(f32));
            try testArgs(f32, -1e0, 1e-1);
            try testArgs(f32, -1e0, 1e0);
            try testArgs(f32, -1e0, 1e1);
            try testArgs(f32, -1e0, fmax(f32));
            try testArgs(f32, -1e0, inf(f32));
            try testArgs(f32, -1e0, nan(f32));

            try testArgs(f32, -1e-1, -nan(f32));
            try testArgs(f32, -1e-1, -inf(f32));
            try testArgs(f32, -1e-1, -fmax(f32));
            try testArgs(f32, -1e-1, -1e1);
            try testArgs(f32, -1e-1, -1e0);
            try testArgs(f32, -1e-1, -1e-1);
            try testArgs(f32, -1e-1, -fmin(f32));
            try testArgs(f32, -1e-1, -tmin(f32));
            try testArgs(f32, -1e-1, -0.0);
            try testArgs(f32, -1e-1, 0.0);
            try testArgs(f32, -1e-1, tmin(f32));
            try testArgs(f32, -1e-1, fmin(f32));
            try testArgs(f32, -1e-1, 1e-1);
            try testArgs(f32, -1e-1, 1e0);
            try testArgs(f32, -1e-1, 1e1);
            try testArgs(f32, -1e-1, fmax(f32));
            try testArgs(f32, -1e-1, inf(f32));
            try testArgs(f32, -1e-1, nan(f32));

            try testArgs(f32, -fmin(f32), -nan(f32));
            try testArgs(f32, -fmin(f32), -inf(f32));
            try testArgs(f32, -fmin(f32), -fmax(f32));
            try testArgs(f32, -fmin(f32), -1e1);
            try testArgs(f32, -fmin(f32), -1e0);
            try testArgs(f32, -fmin(f32), -1e-1);
            try testArgs(f32, -fmin(f32), -fmin(f32));
            try testArgs(f32, -fmin(f32), -tmin(f32));
            try testArgs(f32, -fmin(f32), -0.0);
            try testArgs(f32, -fmin(f32), 0.0);
            try testArgs(f32, -fmin(f32), tmin(f32));
            try testArgs(f32, -fmin(f32), fmin(f32));
            try testArgs(f32, -fmin(f32), 1e-1);
            try testArgs(f32, -fmin(f32), 1e0);
            try testArgs(f32, -fmin(f32), 1e1);
            try testArgs(f32, -fmin(f32), fmax(f32));
            try testArgs(f32, -fmin(f32), inf(f32));
            try testArgs(f32, -fmin(f32), nan(f32));

            try testArgs(f32, -tmin(f32), -nan(f32));
            try testArgs(f32, -tmin(f32), -inf(f32));
            try testArgs(f32, -tmin(f32), -fmax(f32));
            try testArgs(f32, -tmin(f32), -1e1);
            try testArgs(f32, -tmin(f32), -1e0);
            try testArgs(f32, -tmin(f32), -1e-1);
            try testArgs(f32, -tmin(f32), -fmin(f32));
            try testArgs(f32, -tmin(f32), -tmin(f32));
            try testArgs(f32, -tmin(f32), -0.0);
            try testArgs(f32, -tmin(f32), 0.0);
            try testArgs(f32, -tmin(f32), tmin(f32));
            try testArgs(f32, -tmin(f32), fmin(f32));
            try testArgs(f32, -tmin(f32), 1e-1);
            try testArgs(f32, -tmin(f32), 1e0);
            try testArgs(f32, -tmin(f32), 1e1);
            try testArgs(f32, -tmin(f32), fmax(f32));
            try testArgs(f32, -tmin(f32), inf(f32));
            try testArgs(f32, -tmin(f32), nan(f32));

            try testArgs(f32, -0.0, -nan(f32));
            try testArgs(f32, -0.0, -inf(f32));
            try testArgs(f32, -0.0, -fmax(f32));
            try testArgs(f32, -0.0, -1e1);
            try testArgs(f32, -0.0, -1e0);
            try testArgs(f32, -0.0, -1e-1);
            try testArgs(f32, -0.0, -fmin(f32));
            try testArgs(f32, -0.0, -tmin(f32));
            try testArgs(f32, -0.0, -0.0);
            try testArgs(f32, -0.0, 0.0);
            try testArgs(f32, -0.0, tmin(f32));
            try testArgs(f32, -0.0, fmin(f32));
            try testArgs(f32, -0.0, 1e-1);
            try testArgs(f32, -0.0, 1e0);
            try testArgs(f32, -0.0, 1e1);
            try testArgs(f32, -0.0, fmax(f32));
            try testArgs(f32, -0.0, inf(f32));
            try testArgs(f32, -0.0, nan(f32));

            try testArgs(f32, 0.0, -nan(f32));
            try testArgs(f32, 0.0, -inf(f32));
            try testArgs(f32, 0.0, -fmax(f32));
            try testArgs(f32, 0.0, -1e1);
            try testArgs(f32, 0.0, -1e0);
            try testArgs(f32, 0.0, -1e-1);
            try testArgs(f32, 0.0, -fmin(f32));
            try testArgs(f32, 0.0, -tmin(f32));
            try testArgs(f32, 0.0, -0.0);
            try testArgs(f32, 0.0, 0.0);
            try testArgs(f32, 0.0, tmin(f32));
            try testArgs(f32, 0.0, fmin(f32));
            try testArgs(f32, 0.0, 1e-1);
            try testArgs(f32, 0.0, 1e0);
            try testArgs(f32, 0.0, 1e1);
            try testArgs(f32, 0.0, fmax(f32));
            try testArgs(f32, 0.0, inf(f32));
            try testArgs(f32, 0.0, nan(f32));

            try testArgs(f32, tmin(f32), -nan(f32));
            try testArgs(f32, tmin(f32), -inf(f32));
            try testArgs(f32, tmin(f32), -fmax(f32));
            try testArgs(f32, tmin(f32), -1e1);
            try testArgs(f32, tmin(f32), -1e0);
            try testArgs(f32, tmin(f32), -1e-1);
            try testArgs(f32, tmin(f32), -fmin(f32));
            try testArgs(f32, tmin(f32), -tmin(f32));
            try testArgs(f32, tmin(f32), -0.0);
            try testArgs(f32, tmin(f32), 0.0);
            try testArgs(f32, tmin(f32), tmin(f32));
            try testArgs(f32, tmin(f32), fmin(f32));
            try testArgs(f32, tmin(f32), 1e-1);
            try testArgs(f32, tmin(f32), 1e0);
            try testArgs(f32, tmin(f32), 1e1);
            try testArgs(f32, tmin(f32), fmax(f32));
            try testArgs(f32, tmin(f32), inf(f32));
            try testArgs(f32, tmin(f32), nan(f32));

            try testArgs(f32, fmin(f32), -nan(f32));
            try testArgs(f32, fmin(f32), -inf(f32));
            try testArgs(f32, fmin(f32), -fmax(f32));
            try testArgs(f32, fmin(f32), -1e1);
            try testArgs(f32, fmin(f32), -1e0);
            try testArgs(f32, fmin(f32), -1e-1);
            try testArgs(f32, fmin(f32), -fmin(f32));
            try testArgs(f32, fmin(f32), -tmin(f32));
            try testArgs(f32, fmin(f32), -0.0);
            try testArgs(f32, fmin(f32), 0.0);
            try testArgs(f32, fmin(f32), tmin(f32));
            try testArgs(f32, fmin(f32), fmin(f32));
            try testArgs(f32, fmin(f32), 1e-1);
            try testArgs(f32, fmin(f32), 1e0);
            try testArgs(f32, fmin(f32), 1e1);
            try testArgs(f32, fmin(f32), fmax(f32));
            try testArgs(f32, fmin(f32), inf(f32));
            try testArgs(f32, fmin(f32), nan(f32));

            try testArgs(f32, 1e-1, -nan(f32));
            try testArgs(f32, 1e-1, -inf(f32));
            try testArgs(f32, 1e-1, -fmax(f32));
            try testArgs(f32, 1e-1, -1e1);
            try testArgs(f32, 1e-1, -1e0);
            try testArgs(f32, 1e-1, -1e-1);
            try testArgs(f32, 1e-1, -fmin(f32));
            try testArgs(f32, 1e-1, -tmin(f32));
            try testArgs(f32, 1e-1, -0.0);
            try testArgs(f32, 1e-1, 0.0);
            try testArgs(f32, 1e-1, tmin(f32));
            try testArgs(f32, 1e-1, fmin(f32));
            try testArgs(f32, 1e-1, 1e-1);
            try testArgs(f32, 1e-1, 1e0);
            try testArgs(f32, 1e-1, 1e1);
            try testArgs(f32, 1e-1, fmax(f32));
            try testArgs(f32, 1e-1, inf(f32));
            try testArgs(f32, 1e-1, nan(f32));

            try testArgs(f32, 1e0, -nan(f32));
            try testArgs(f32, 1e0, -inf(f32));
            try testArgs(f32, 1e0, -fmax(f32));
            try testArgs(f32, 1e0, -1e1);
            try testArgs(f32, 1e0, -1e0);
            try testArgs(f32, 1e0, -1e-1);
            try testArgs(f32, 1e0, -fmin(f32));
            try testArgs(f32, 1e0, -tmin(f32));
            try testArgs(f32, 1e0, -0.0);
            try testArgs(f32, 1e0, 0.0);
            try testArgs(f32, 1e0, tmin(f32));
            try testArgs(f32, 1e0, fmin(f32));
            try testArgs(f32, 1e0, 1e-1);
            try testArgs(f32, 1e0, 1e0);
            try testArgs(f32, 1e0, 1e1);
            try testArgs(f32, 1e0, fmax(f32));
            try testArgs(f32, 1e0, inf(f32));
            try testArgs(f32, 1e0, nan(f32));

            try testArgs(f32, 1e1, -nan(f32));
            try testArgs(f32, 1e1, -inf(f32));
            try testArgs(f32, 1e1, -fmax(f32));
            try testArgs(f32, 1e1, -1e1);
            try testArgs(f32, 1e1, -1e0);
            try testArgs(f32, 1e1, -1e-1);
            try testArgs(f32, 1e1, -fmin(f32));
            try testArgs(f32, 1e1, -tmin(f32));
            try testArgs(f32, 1e1, -0.0);
            try testArgs(f32, 1e1, 0.0);
            try testArgs(f32, 1e1, tmin(f32));
            try testArgs(f32, 1e1, fmin(f32));
            try testArgs(f32, 1e1, 1e-1);
            try testArgs(f32, 1e1, 1e0);
            try testArgs(f32, 1e1, 1e1);
            try testArgs(f32, 1e1, fmax(f32));
            try testArgs(f32, 1e1, inf(f32));
            try testArgs(f32, 1e1, nan(f32));

            try testArgs(f32, fmax(f32), -nan(f32));
            try testArgs(f32, fmax(f32), -inf(f32));
            try testArgs(f32, fmax(f32), -fmax(f32));
            try testArgs(f32, fmax(f32), -1e1);
            try testArgs(f32, fmax(f32), -1e0);
            try testArgs(f32, fmax(f32), -1e-1);
            try testArgs(f32, fmax(f32), -fmin(f32));
            try testArgs(f32, fmax(f32), -tmin(f32));
            try testArgs(f32, fmax(f32), -0.0);
            try testArgs(f32, fmax(f32), 0.0);
            try testArgs(f32, fmax(f32), tmin(f32));
            try testArgs(f32, fmax(f32), fmin(f32));
            try testArgs(f32, fmax(f32), 1e-1);
            try testArgs(f32, fmax(f32), 1e0);
            try testArgs(f32, fmax(f32), 1e1);
            try testArgs(f32, fmax(f32), fmax(f32));
            try testArgs(f32, fmax(f32), inf(f32));
            try testArgs(f32, fmax(f32), nan(f32));

            try testArgs(f32, inf(f32), -nan(f32));
            try testArgs(f32, inf(f32), -inf(f32));
            try testArgs(f32, inf(f32), -fmax(f32));
            try testArgs(f32, inf(f32), -1e1);
            try testArgs(f32, inf(f32), -1e0);
            try testArgs(f32, inf(f32), -1e-1);
            try testArgs(f32, inf(f32), -fmin(f32));
            try testArgs(f32, inf(f32), -tmin(f32));
            try testArgs(f32, inf(f32), -0.0);
            try testArgs(f32, inf(f32), 0.0);
            try testArgs(f32, inf(f32), tmin(f32));
            try testArgs(f32, inf(f32), fmin(f32));
            try testArgs(f32, inf(f32), 1e-1);
            try testArgs(f32, inf(f32), 1e0);
            try testArgs(f32, inf(f32), 1e1);
            try testArgs(f32, inf(f32), fmax(f32));
            try testArgs(f32, inf(f32), inf(f32));
            try testArgs(f32, inf(f32), nan(f32));

            try testArgs(f32, nan(f32), -nan(f32));
            try testArgs(f32, nan(f32), -inf(f32));
            try testArgs(f32, nan(f32), -fmax(f32));
            try testArgs(f32, nan(f32), -1e1);
            try testArgs(f32, nan(f32), -1e0);
            try testArgs(f32, nan(f32), -1e-1);
            try testArgs(f32, nan(f32), -fmin(f32));
            try testArgs(f32, nan(f32), -tmin(f32));
            try testArgs(f32, nan(f32), -0.0);
            try testArgs(f32, nan(f32), 0.0);
            try testArgs(f32, nan(f32), tmin(f32));
            try testArgs(f32, nan(f32), fmin(f32));
            try testArgs(f32, nan(f32), 1e-1);
            try testArgs(f32, nan(f32), 1e0);
            try testArgs(f32, nan(f32), 1e1);
            try testArgs(f32, nan(f32), fmax(f32));
            try testArgs(f32, nan(f32), inf(f32));
            try testArgs(f32, nan(f32), nan(f32));

            try testArgs(f64, -nan(f64), -nan(f64));
            try testArgs(f64, -nan(f64), -inf(f64));
            try testArgs(f64, -nan(f64), -fmax(f64));
            try testArgs(f64, -nan(f64), -1e1);
            try testArgs(f64, -nan(f64), -1e0);
            try testArgs(f64, -nan(f64), -1e-1);
            try testArgs(f64, -nan(f64), -fmin(f64));
            try testArgs(f64, -nan(f64), -tmin(f64));
            try testArgs(f64, -nan(f64), -0.0);
            try testArgs(f64, -nan(f64), 0.0);
            try testArgs(f64, -nan(f64), tmin(f64));
            try testArgs(f64, -nan(f64), fmin(f64));
            try testArgs(f64, -nan(f64), 1e-1);
            try testArgs(f64, -nan(f64), 1e0);
            try testArgs(f64, -nan(f64), 1e1);
            try testArgs(f64, -nan(f64), fmax(f64));
            try testArgs(f64, -nan(f64), inf(f64));
            try testArgs(f64, -nan(f64), nan(f64));

            try testArgs(f64, -inf(f64), -nan(f64));
            try testArgs(f64, -inf(f64), -inf(f64));
            try testArgs(f64, -inf(f64), -fmax(f64));
            try testArgs(f64, -inf(f64), -1e1);
            try testArgs(f64, -inf(f64), -1e0);
            try testArgs(f64, -inf(f64), -1e-1);
            try testArgs(f64, -inf(f64), -fmin(f64));
            try testArgs(f64, -inf(f64), -tmin(f64));
            try testArgs(f64, -inf(f64), -0.0);
            try testArgs(f64, -inf(f64), 0.0);
            try testArgs(f64, -inf(f64), tmin(f64));
            try testArgs(f64, -inf(f64), fmin(f64));
            try testArgs(f64, -inf(f64), 1e-1);
            try testArgs(f64, -inf(f64), 1e0);
            try testArgs(f64, -inf(f64), 1e1);
            try testArgs(f64, -inf(f64), fmax(f64));
            try testArgs(f64, -inf(f64), inf(f64));
            try testArgs(f64, -inf(f64), nan(f64));

            try testArgs(f64, -fmax(f64), -nan(f64));
            try testArgs(f64, -fmax(f64), -inf(f64));
            try testArgs(f64, -fmax(f64), -fmax(f64));
            try testArgs(f64, -fmax(f64), -1e1);
            try testArgs(f64, -fmax(f64), -1e0);
            try testArgs(f64, -fmax(f64), -1e-1);
            try testArgs(f64, -fmax(f64), -fmin(f64));
            try testArgs(f64, -fmax(f64), -tmin(f64));
            try testArgs(f64, -fmax(f64), -0.0);
            try testArgs(f64, -fmax(f64), 0.0);
            try testArgs(f64, -fmax(f64), tmin(f64));
            try testArgs(f64, -fmax(f64), fmin(f64));
            try testArgs(f64, -fmax(f64), 1e-1);
            try testArgs(f64, -fmax(f64), 1e0);
            try testArgs(f64, -fmax(f64), 1e1);
            try testArgs(f64, -fmax(f64), fmax(f64));
            try testArgs(f64, -fmax(f64), inf(f64));
            try testArgs(f64, -fmax(f64), nan(f64));

            try testArgs(f64, -1e1, -nan(f64));
            try testArgs(f64, -1e1, -inf(f64));
            try testArgs(f64, -1e1, -fmax(f64));
            try testArgs(f64, -1e1, -1e1);
            try testArgs(f64, -1e1, -1e0);
            try testArgs(f64, -1e1, -1e-1);
            try testArgs(f64, -1e1, -fmin(f64));
            try testArgs(f64, -1e1, -tmin(f64));
            try testArgs(f64, -1e1, -0.0);
            try testArgs(f64, -1e1, 0.0);
            try testArgs(f64, -1e1, tmin(f64));
            try testArgs(f64, -1e1, fmin(f64));
            try testArgs(f64, -1e1, 1e-1);
            try testArgs(f64, -1e1, 1e0);
            try testArgs(f64, -1e1, 1e1);
            try testArgs(f64, -1e1, fmax(f64));
            try testArgs(f64, -1e1, inf(f64));
            try testArgs(f64, -1e1, nan(f64));

            try testArgs(f64, -1e0, -nan(f64));
            try testArgs(f64, -1e0, -inf(f64));
            try testArgs(f64, -1e0, -fmax(f64));
            try testArgs(f64, -1e0, -1e1);
            try testArgs(f64, -1e0, -1e0);
            try testArgs(f64, -1e0, -1e-1);
            try testArgs(f64, -1e0, -fmin(f64));
            try testArgs(f64, -1e0, -tmin(f64));
            try testArgs(f64, -1e0, -0.0);
            try testArgs(f64, -1e0, 0.0);
            try testArgs(f64, -1e0, tmin(f64));
            try testArgs(f64, -1e0, fmin(f64));
            try testArgs(f64, -1e0, 1e-1);
            try testArgs(f64, -1e0, 1e0);
            try testArgs(f64, -1e0, 1e1);
            try testArgs(f64, -1e0, fmax(f64));
            try testArgs(f64, -1e0, inf(f64));
            try testArgs(f64, -1e0, nan(f64));

            try testArgs(f64, -1e-1, -nan(f64));
            try testArgs(f64, -1e-1, -inf(f64));
            try testArgs(f64, -1e-1, -fmax(f64));
            try testArgs(f64, -1e-1, -1e1);
            try testArgs(f64, -1e-1, -1e0);
            try testArgs(f64, -1e-1, -1e-1);
            try testArgs(f64, -1e-1, -fmin(f64));
            try testArgs(f64, -1e-1, -tmin(f64));
            try testArgs(f64, -1e-1, -0.0);
            try testArgs(f64, -1e-1, 0.0);
            try testArgs(f64, -1e-1, tmin(f64));
            try testArgs(f64, -1e-1, fmin(f64));
            try testArgs(f64, -1e-1, 1e-1);
            try testArgs(f64, -1e-1, 1e0);
            try testArgs(f64, -1e-1, 1e1);
            try testArgs(f64, -1e-1, fmax(f64));
            try testArgs(f64, -1e-1, inf(f64));
            try testArgs(f64, -1e-1, nan(f64));

            try testArgs(f64, -fmin(f64), -nan(f64));
            try testArgs(f64, -fmin(f64), -inf(f64));
            try testArgs(f64, -fmin(f64), -fmax(f64));
            try testArgs(f64, -fmin(f64), -1e1);
            try testArgs(f64, -fmin(f64), -1e0);
            try testArgs(f64, -fmin(f64), -1e-1);
            try testArgs(f64, -fmin(f64), -fmin(f64));
            try testArgs(f64, -fmin(f64), -tmin(f64));
            try testArgs(f64, -fmin(f64), -0.0);
            try testArgs(f64, -fmin(f64), 0.0);
            try testArgs(f64, -fmin(f64), tmin(f64));
            try testArgs(f64, -fmin(f64), fmin(f64));
            try testArgs(f64, -fmin(f64), 1e-1);
            try testArgs(f64, -fmin(f64), 1e0);
            try testArgs(f64, -fmin(f64), 1e1);
            try testArgs(f64, -fmin(f64), fmax(f64));
            try testArgs(f64, -fmin(f64), inf(f64));
            try testArgs(f64, -fmin(f64), nan(f64));

            try testArgs(f64, -tmin(f64), -nan(f64));
            try testArgs(f64, -tmin(f64), -inf(f64));
            try testArgs(f64, -tmin(f64), -fmax(f64));
            try testArgs(f64, -tmin(f64), -1e1);
            try testArgs(f64, -tmin(f64), -1e0);
            try testArgs(f64, -tmin(f64), -1e-1);
            try testArgs(f64, -tmin(f64), -fmin(f64));
            try testArgs(f64, -tmin(f64), -tmin(f64));
            try testArgs(f64, -tmin(f64), -0.0);
            try testArgs(f64, -tmin(f64), 0.0);
            try testArgs(f64, -tmin(f64), tmin(f64));
            try testArgs(f64, -tmin(f64), fmin(f64));
            try testArgs(f64, -tmin(f64), 1e-1);
            try testArgs(f64, -tmin(f64), 1e0);
            try testArgs(f64, -tmin(f64), 1e1);
            try testArgs(f64, -tmin(f64), fmax(f64));
            try testArgs(f64, -tmin(f64), inf(f64));
            try testArgs(f64, -tmin(f64), nan(f64));

            try testArgs(f64, -0.0, -nan(f64));
            try testArgs(f64, -0.0, -inf(f64));
            try testArgs(f64, -0.0, -fmax(f64));
            try testArgs(f64, -0.0, -1e1);
            try testArgs(f64, -0.0, -1e0);
            try testArgs(f64, -0.0, -1e-1);
            try testArgs(f64, -0.0, -fmin(f64));
            try testArgs(f64, -0.0, -tmin(f64));
            try testArgs(f64, -0.0, -0.0);
            try testArgs(f64, -0.0, 0.0);
            try testArgs(f64, -0.0, tmin(f64));
            try testArgs(f64, -0.0, fmin(f64));
            try testArgs(f64, -0.0, 1e-1);
            try testArgs(f64, -0.0, 1e0);
            try testArgs(f64, -0.0, 1e1);
            try testArgs(f64, -0.0, fmax(f64));
            try testArgs(f64, -0.0, inf(f64));
            try testArgs(f64, -0.0, nan(f64));

            try testArgs(f64, 0.0, -nan(f64));
            try testArgs(f64, 0.0, -inf(f64));
            try testArgs(f64, 0.0, -fmax(f64));
            try testArgs(f64, 0.0, -1e1);
            try testArgs(f64, 0.0, -1e0);
            try testArgs(f64, 0.0, -1e-1);
            try testArgs(f64, 0.0, -fmin(f64));
            try testArgs(f64, 0.0, -tmin(f64));
            try testArgs(f64, 0.0, -0.0);
            try testArgs(f64, 0.0, 0.0);
            try testArgs(f64, 0.0, tmin(f64));
            try testArgs(f64, 0.0, fmin(f64));
            try testArgs(f64, 0.0, 1e-1);
            try testArgs(f64, 0.0, 1e0);
            try testArgs(f64, 0.0, 1e1);
            try testArgs(f64, 0.0, fmax(f64));
            try testArgs(f64, 0.0, inf(f64));
            try testArgs(f64, 0.0, nan(f64));

            try testArgs(f64, tmin(f64), -nan(f64));
            try testArgs(f64, tmin(f64), -inf(f64));
            try testArgs(f64, tmin(f64), -fmax(f64));
            try testArgs(f64, tmin(f64), -1e1);
            try testArgs(f64, tmin(f64), -1e0);
            try testArgs(f64, tmin(f64), -1e-1);
            try testArgs(f64, tmin(f64), -fmin(f64));
            try testArgs(f64, tmin(f64), -tmin(f64));
            try testArgs(f64, tmin(f64), -0.0);
            try testArgs(f64, tmin(f64), 0.0);
            try testArgs(f64, tmin(f64), tmin(f64));
            try testArgs(f64, tmin(f64), fmin(f64));
            try testArgs(f64, tmin(f64), 1e-1);
            try testArgs(f64, tmin(f64), 1e0);
            try testArgs(f64, tmin(f64), 1e1);
            try testArgs(f64, tmin(f64), fmax(f64));
            try testArgs(f64, tmin(f64), inf(f64));
            try testArgs(f64, tmin(f64), nan(f64));

            try testArgs(f64, fmin(f64), -nan(f64));
            try testArgs(f64, fmin(f64), -inf(f64));
            try testArgs(f64, fmin(f64), -fmax(f64));
            try testArgs(f64, fmin(f64), -1e1);
            try testArgs(f64, fmin(f64), -1e0);
            try testArgs(f64, fmin(f64), -1e-1);
            try testArgs(f64, fmin(f64), -fmin(f64));
            try testArgs(f64, fmin(f64), -tmin(f64));
            try testArgs(f64, fmin(f64), -0.0);
            try testArgs(f64, fmin(f64), 0.0);
            try testArgs(f64, fmin(f64), tmin(f64));
            try testArgs(f64, fmin(f64), fmin(f64));
            try testArgs(f64, fmin(f64), 1e-1);
            try testArgs(f64, fmin(f64), 1e0);
            try testArgs(f64, fmin(f64), 1e1);
            try testArgs(f64, fmin(f64), fmax(f64));
            try testArgs(f64, fmin(f64), inf(f64));
            try testArgs(f64, fmin(f64), nan(f64));

            try testArgs(f64, 1e-1, -nan(f64));
            try testArgs(f64, 1e-1, -inf(f64));
            try testArgs(f64, 1e-1, -fmax(f64));
            try testArgs(f64, 1e-1, -1e1);
            try testArgs(f64, 1e-1, -1e0);
            try testArgs(f64, 1e-1, -1e-1);
            try testArgs(f64, 1e-1, -fmin(f64));
            try testArgs(f64, 1e-1, -tmin(f64));
            try testArgs(f64, 1e-1, -0.0);
            try testArgs(f64, 1e-1, 0.0);
            try testArgs(f64, 1e-1, tmin(f64));
            try testArgs(f64, 1e-1, fmin(f64));
            try testArgs(f64, 1e-1, 1e-1);
            try testArgs(f64, 1e-1, 1e0);
            try testArgs(f64, 1e-1, 1e1);
            try testArgs(f64, 1e-1, fmax(f64));
            try testArgs(f64, 1e-1, inf(f64));
            try testArgs(f64, 1e-1, nan(f64));

            try testArgs(f64, 1e0, -nan(f64));
            try testArgs(f64, 1e0, -inf(f64));
            try testArgs(f64, 1e0, -fmax(f64));
            try testArgs(f64, 1e0, -1e1);
            try testArgs(f64, 1e0, -1e0);
            try testArgs(f64, 1e0, -1e-1);
            try testArgs(f64, 1e0, -fmin(f64));
            try testArgs(f64, 1e0, -tmin(f64));
            try testArgs(f64, 1e0, -0.0);
            try testArgs(f64, 1e0, 0.0);
            try testArgs(f64, 1e0, tmin(f64));
            try testArgs(f64, 1e0, fmin(f64));
            try testArgs(f64, 1e0, 1e-1);
            try testArgs(f64, 1e0, 1e0);
            try testArgs(f64, 1e0, 1e1);
            try testArgs(f64, 1e0, fmax(f64));
            try testArgs(f64, 1e0, inf(f64));
            try testArgs(f64, 1e0, nan(f64));

            try testArgs(f64, 1e1, -nan(f64));
            try testArgs(f64, 1e1, -inf(f64));
            try testArgs(f64, 1e1, -fmax(f64));
            try testArgs(f64, 1e1, -1e1);
            try testArgs(f64, 1e1, -1e0);
            try testArgs(f64, 1e1, -1e-1);
            try testArgs(f64, 1e1, -fmin(f64));
            try testArgs(f64, 1e1, -tmin(f64));
            try testArgs(f64, 1e1, -0.0);
            try testArgs(f64, 1e1, 0.0);
            try testArgs(f64, 1e1, tmin(f64));
            try testArgs(f64, 1e1, fmin(f64));
            try testArgs(f64, 1e1, 1e-1);
            try testArgs(f64, 1e1, 1e0);
            try testArgs(f64, 1e1, 1e1);
            try testArgs(f64, 1e1, fmax(f64));
            try testArgs(f64, 1e1, inf(f64));
            try testArgs(f64, 1e1, nan(f64));

            try testArgs(f64, fmax(f64), -nan(f64));
            try testArgs(f64, fmax(f64), -inf(f64));
            try testArgs(f64, fmax(f64), -fmax(f64));
            try testArgs(f64, fmax(f64), -1e1);
            try testArgs(f64, fmax(f64), -1e0);
            try testArgs(f64, fmax(f64), -1e-1);
            try testArgs(f64, fmax(f64), -fmin(f64));
            try testArgs(f64, fmax(f64), -tmin(f64));
            try testArgs(f64, fmax(f64), -0.0);
            try testArgs(f64, fmax(f64), 0.0);
            try testArgs(f64, fmax(f64), tmin(f64));
            try testArgs(f64, fmax(f64), fmin(f64));
            try testArgs(f64, fmax(f64), 1e-1);
            try testArgs(f64, fmax(f64), 1e0);
            try testArgs(f64, fmax(f64), 1e1);
            try testArgs(f64, fmax(f64), fmax(f64));
            try testArgs(f64, fmax(f64), inf(f64));
            try testArgs(f64, fmax(f64), nan(f64));

            try testArgs(f64, inf(f64), -nan(f64));
            try testArgs(f64, inf(f64), -inf(f64));
            try testArgs(f64, inf(f64), -fmax(f64));
            try testArgs(f64, inf(f64), -1e1);
            try testArgs(f64, inf(f64), -1e0);
            try testArgs(f64, inf(f64), -1e-1);
            try testArgs(f64, inf(f64), -fmin(f64));
            try testArgs(f64, inf(f64), -tmin(f64));
            try testArgs(f64, inf(f64), -0.0);
            try testArgs(f64, inf(f64), 0.0);
            try testArgs(f64, inf(f64), tmin(f64));
            try testArgs(f64, inf(f64), fmin(f64));
            try testArgs(f64, inf(f64), 1e-1);
            try testArgs(f64, inf(f64), 1e0);
            try testArgs(f64, inf(f64), 1e1);
            try testArgs(f64, inf(f64), fmax(f64));
            try testArgs(f64, inf(f64), inf(f64));
            try testArgs(f64, inf(f64), nan(f64));

            try testArgs(f64, nan(f64), -nan(f64));
            try testArgs(f64, nan(f64), -inf(f64));
            try testArgs(f64, nan(f64), -fmax(f64));
            try testArgs(f64, nan(f64), -1e1);
            try testArgs(f64, nan(f64), -1e0);
            try testArgs(f64, nan(f64), -1e-1);
            try testArgs(f64, nan(f64), -fmin(f64));
            try testArgs(f64, nan(f64), -tmin(f64));
            try testArgs(f64, nan(f64), -0.0);
            try testArgs(f64, nan(f64), 0.0);
            try testArgs(f64, nan(f64), tmin(f64));
            try testArgs(f64, nan(f64), fmin(f64));
            try testArgs(f64, nan(f64), 1e-1);
            try testArgs(f64, nan(f64), 1e0);
            try testArgs(f64, nan(f64), 1e1);
            try testArgs(f64, nan(f64), fmax(f64));
            try testArgs(f64, nan(f64), inf(f64));
            try testArgs(f64, nan(f64), nan(f64));

            try testArgs(f80, -nan(f80), -nan(f80));
            try testArgs(f80, -nan(f80), -inf(f80));
            try testArgs(f80, -nan(f80), -fmax(f80));
            try testArgs(f80, -nan(f80), -1e1);
            try testArgs(f80, -nan(f80), -1e0);
            try testArgs(f80, -nan(f80), -1e-1);
            try testArgs(f80, -nan(f80), -fmin(f80));
            try testArgs(f80, -nan(f80), -tmin(f80));
            try testArgs(f80, -nan(f80), -0.0);
            try testArgs(f80, -nan(f80), 0.0);
            try testArgs(f80, -nan(f80), tmin(f80));
            try testArgs(f80, -nan(f80), fmin(f80));
            try testArgs(f80, -nan(f80), 1e-1);
            try testArgs(f80, -nan(f80), 1e0);
            try testArgs(f80, -nan(f80), 1e1);
            try testArgs(f80, -nan(f80), fmax(f80));
            try testArgs(f80, -nan(f80), inf(f80));
            try testArgs(f80, -nan(f80), nan(f80));

            try testArgs(f80, -inf(f80), -nan(f80));
            try testArgs(f80, -inf(f80), -inf(f80));
            try testArgs(f80, -inf(f80), -fmax(f80));
            try testArgs(f80, -inf(f80), -1e1);
            try testArgs(f80, -inf(f80), -1e0);
            try testArgs(f80, -inf(f80), -1e-1);
            try testArgs(f80, -inf(f80), -fmin(f80));
            try testArgs(f80, -inf(f80), -tmin(f80));
            try testArgs(f80, -inf(f80), -0.0);
            try testArgs(f80, -inf(f80), 0.0);
            try testArgs(f80, -inf(f80), tmin(f80));
            try testArgs(f80, -inf(f80), fmin(f80));
            try testArgs(f80, -inf(f80), 1e-1);
            try testArgs(f80, -inf(f80), 1e0);
            try testArgs(f80, -inf(f80), 1e1);
            try testArgs(f80, -inf(f80), fmax(f80));
            try testArgs(f80, -inf(f80), inf(f80));
            try testArgs(f80, -inf(f80), nan(f80));

            try testArgs(f80, -fmax(f80), -nan(f80));
            try testArgs(f80, -fmax(f80), -inf(f80));
            try testArgs(f80, -fmax(f80), -fmax(f80));
            try testArgs(f80, -fmax(f80), -1e1);
            try testArgs(f80, -fmax(f80), -1e0);
            try testArgs(f80, -fmax(f80), -1e-1);
            try testArgs(f80, -fmax(f80), -fmin(f80));
            try testArgs(f80, -fmax(f80), -tmin(f80));
            try testArgs(f80, -fmax(f80), -0.0);
            try testArgs(f80, -fmax(f80), 0.0);
            try testArgs(f80, -fmax(f80), tmin(f80));
            try testArgs(f80, -fmax(f80), fmin(f80));
            try testArgs(f80, -fmax(f80), 1e-1);
            try testArgs(f80, -fmax(f80), 1e0);
            try testArgs(f80, -fmax(f80), 1e1);
            try testArgs(f80, -fmax(f80), fmax(f80));
            try testArgs(f80, -fmax(f80), inf(f80));
            try testArgs(f80, -fmax(f80), nan(f80));

            try testArgs(f80, -1e1, -nan(f80));
            try testArgs(f80, -1e1, -inf(f80));
            try testArgs(f80, -1e1, -fmax(f80));
            try testArgs(f80, -1e1, -1e1);
            try testArgs(f80, -1e1, -1e0);
            try testArgs(f80, -1e1, -1e-1);
            try testArgs(f80, -1e1, -fmin(f80));
            try testArgs(f80, -1e1, -tmin(f80));
            try testArgs(f80, -1e1, -0.0);
            try testArgs(f80, -1e1, 0.0);
            try testArgs(f80, -1e1, tmin(f80));
            try testArgs(f80, -1e1, fmin(f80));
            try testArgs(f80, -1e1, 1e-1);
            try testArgs(f80, -1e1, 1e0);
            try testArgs(f80, -1e1, 1e1);
            try testArgs(f80, -1e1, fmax(f80));
            try testArgs(f80, -1e1, inf(f80));
            try testArgs(f80, -1e1, nan(f80));

            try testArgs(f80, -1e0, -nan(f80));
            try testArgs(f80, -1e0, -inf(f80));
            try testArgs(f80, -1e0, -fmax(f80));
            try testArgs(f80, -1e0, -1e1);
            try testArgs(f80, -1e0, -1e0);
            try testArgs(f80, -1e0, -1e-1);
            try testArgs(f80, -1e0, -fmin(f80));
            try testArgs(f80, -1e0, -tmin(f80));
            try testArgs(f80, -1e0, -0.0);
            try testArgs(f80, -1e0, 0.0);
            try testArgs(f80, -1e0, tmin(f80));
            try testArgs(f80, -1e0, fmin(f80));
            try testArgs(f80, -1e0, 1e-1);
            try testArgs(f80, -1e0, 1e0);
            try testArgs(f80, -1e0, 1e1);
            try testArgs(f80, -1e0, fmax(f80));
            try testArgs(f80, -1e0, inf(f80));
            try testArgs(f80, -1e0, nan(f80));

            try testArgs(f80, -1e-1, -nan(f80));
            try testArgs(f80, -1e-1, -inf(f80));
            try testArgs(f80, -1e-1, -fmax(f80));
            try testArgs(f80, -1e-1, -1e1);
            try testArgs(f80, -1e-1, -1e0);
            try testArgs(f80, -1e-1, -1e-1);
            try testArgs(f80, -1e-1, -fmin(f80));
            try testArgs(f80, -1e-1, -tmin(f80));
            try testArgs(f80, -1e-1, -0.0);
            try testArgs(f80, -1e-1, 0.0);
            try testArgs(f80, -1e-1, tmin(f80));
            try testArgs(f80, -1e-1, fmin(f80));
            try testArgs(f80, -1e-1, 1e-1);
            try testArgs(f80, -1e-1, 1e0);
            try testArgs(f80, -1e-1, 1e1);
            try testArgs(f80, -1e-1, fmax(f80));
            try testArgs(f80, -1e-1, inf(f80));
            try testArgs(f80, -1e-1, nan(f80));

            try testArgs(f80, -fmin(f80), -nan(f80));
            try testArgs(f80, -fmin(f80), -inf(f80));
            try testArgs(f80, -fmin(f80), -fmax(f80));
            try testArgs(f80, -fmin(f80), -1e1);
            try testArgs(f80, -fmin(f80), -1e0);
            try testArgs(f80, -fmin(f80), -1e-1);
            try testArgs(f80, -fmin(f80), -fmin(f80));
            try testArgs(f80, -fmin(f80), -tmin(f80));
            try testArgs(f80, -fmin(f80), -0.0);
            try testArgs(f80, -fmin(f80), 0.0);
            try testArgs(f80, -fmin(f80), tmin(f80));
            try testArgs(f80, -fmin(f80), fmin(f80));
            try testArgs(f80, -fmin(f80), 1e-1);
            try testArgs(f80, -fmin(f80), 1e0);
            try testArgs(f80, -fmin(f80), 1e1);
            try testArgs(f80, -fmin(f80), fmax(f80));
            try testArgs(f80, -fmin(f80), inf(f80));
            try testArgs(f80, -fmin(f80), nan(f80));

            try testArgs(f80, -tmin(f80), -nan(f80));
            try testArgs(f80, -tmin(f80), -inf(f80));
            try testArgs(f80, -tmin(f80), -fmax(f80));
            try testArgs(f80, -tmin(f80), -1e1);
            try testArgs(f80, -tmin(f80), -1e0);
            try testArgs(f80, -tmin(f80), -1e-1);
            try testArgs(f80, -tmin(f80), -fmin(f80));
            try testArgs(f80, -tmin(f80), -tmin(f80));
            try testArgs(f80, -tmin(f80), -0.0);
            try testArgs(f80, -tmin(f80), 0.0);
            try testArgs(f80, -tmin(f80), tmin(f80));
            try testArgs(f80, -tmin(f80), fmin(f80));
            try testArgs(f80, -tmin(f80), 1e-1);
            try testArgs(f80, -tmin(f80), 1e0);
            try testArgs(f80, -tmin(f80), 1e1);
            try testArgs(f80, -tmin(f80), fmax(f80));
            try testArgs(f80, -tmin(f80), inf(f80));
            try testArgs(f80, -tmin(f80), nan(f80));

            try testArgs(f80, -0.0, -nan(f80));
            try testArgs(f80, -0.0, -inf(f80));
            try testArgs(f80, -0.0, -fmax(f80));
            try testArgs(f80, -0.0, -1e1);
            try testArgs(f80, -0.0, -1e0);
            try testArgs(f80, -0.0, -1e-1);
            try testArgs(f80, -0.0, -fmin(f80));
            try testArgs(f80, -0.0, -tmin(f80));
            try testArgs(f80, -0.0, -0.0);
            try testArgs(f80, -0.0, 0.0);
            try testArgs(f80, -0.0, tmin(f80));
            try testArgs(f80, -0.0, fmin(f80));
            try testArgs(f80, -0.0, 1e-1);
            try testArgs(f80, -0.0, 1e0);
            try testArgs(f80, -0.0, 1e1);
            try testArgs(f80, -0.0, fmax(f80));
            try testArgs(f80, -0.0, inf(f80));
            try testArgs(f80, -0.0, nan(f80));

            try testArgs(f80, 0.0, -nan(f80));
            try testArgs(f80, 0.0, -inf(f80));
            try testArgs(f80, 0.0, -fmax(f80));
            try testArgs(f80, 0.0, -1e1);
            try testArgs(f80, 0.0, -1e0);
            try testArgs(f80, 0.0, -1e-1);
            try testArgs(f80, 0.0, -fmin(f80));
            try testArgs(f80, 0.0, -tmin(f80));
            try testArgs(f80, 0.0, -0.0);
            try testArgs(f80, 0.0, 0.0);
            try testArgs(f80, 0.0, tmin(f80));
            try testArgs(f80, 0.0, fmin(f80));
            try testArgs(f80, 0.0, 1e-1);
            try testArgs(f80, 0.0, 1e0);
            try testArgs(f80, 0.0, 1e1);
            try testArgs(f80, 0.0, fmax(f80));
            try testArgs(f80, 0.0, inf(f80));
            try testArgs(f80, 0.0, nan(f80));

            try testArgs(f80, tmin(f80), -nan(f80));
            try testArgs(f80, tmin(f80), -inf(f80));
            try testArgs(f80, tmin(f80), -fmax(f80));
            try testArgs(f80, tmin(f80), -1e1);
            try testArgs(f80, tmin(f80), -1e0);
            try testArgs(f80, tmin(f80), -1e-1);
            try testArgs(f80, tmin(f80), -fmin(f80));
            try testArgs(f80, tmin(f80), -tmin(f80));
            try testArgs(f80, tmin(f80), -0.0);
            try testArgs(f80, tmin(f80), 0.0);
            try testArgs(f80, tmin(f80), tmin(f80));
            try testArgs(f80, tmin(f80), fmin(f80));
            try testArgs(f80, tmin(f80), 1e-1);
            try testArgs(f80, tmin(f80), 1e0);
            try testArgs(f80, tmin(f80), 1e1);
            try testArgs(f80, tmin(f80), fmax(f80));
            try testArgs(f80, tmin(f80), inf(f80));
            try testArgs(f80, tmin(f80), nan(f80));

            try testArgs(f80, fmin(f80), -nan(f80));
            try testArgs(f80, fmin(f80), -inf(f80));
            try testArgs(f80, fmin(f80), -fmax(f80));
            try testArgs(f80, fmin(f80), -1e1);
            try testArgs(f80, fmin(f80), -1e0);
            try testArgs(f80, fmin(f80), -1e-1);
            try testArgs(f80, fmin(f80), -fmin(f80));
            try testArgs(f80, fmin(f80), -tmin(f80));
            try testArgs(f80, fmin(f80), -0.0);
            try testArgs(f80, fmin(f80), 0.0);
            try testArgs(f80, fmin(f80), tmin(f80));
            try testArgs(f80, fmin(f80), fmin(f80));
            try testArgs(f80, fmin(f80), 1e-1);
            try testArgs(f80, fmin(f80), 1e0);
            try testArgs(f80, fmin(f80), 1e1);
            try testArgs(f80, fmin(f80), fmax(f80));
            try testArgs(f80, fmin(f80), inf(f80));
            try testArgs(f80, fmin(f80), nan(f80));

            try testArgs(f80, 1e-1, -nan(f80));
            try testArgs(f80, 1e-1, -inf(f80));
            try testArgs(f80, 1e-1, -fmax(f80));
            try testArgs(f80, 1e-1, -1e1);
            try testArgs(f80, 1e-1, -1e0);
            try testArgs(f80, 1e-1, -1e-1);
            try testArgs(f80, 1e-1, -fmin(f80));
            try testArgs(f80, 1e-1, -tmin(f80));
            try testArgs(f80, 1e-1, -0.0);
            try testArgs(f80, 1e-1, 0.0);
            try testArgs(f80, 1e-1, tmin(f80));
            try testArgs(f80, 1e-1, fmin(f80));
            try testArgs(f80, 1e-1, 1e-1);
            try testArgs(f80, 1e-1, 1e0);
            try testArgs(f80, 1e-1, 1e1);
            try testArgs(f80, 1e-1, fmax(f80));
            try testArgs(f80, 1e-1, inf(f80));
            try testArgs(f80, 1e-1, nan(f80));

            try testArgs(f80, 1e0, -nan(f80));
            try testArgs(f80, 1e0, -inf(f80));
            try testArgs(f80, 1e0, -fmax(f80));
            try testArgs(f80, 1e0, -1e1);
            try testArgs(f80, 1e0, -1e0);
            try testArgs(f80, 1e0, -1e-1);
            try testArgs(f80, 1e0, -fmin(f80));
            try testArgs(f80, 1e0, -tmin(f80));
            try testArgs(f80, 1e0, -0.0);
            try testArgs(f80, 1e0, 0.0);
            try testArgs(f80, 1e0, tmin(f80));
            try testArgs(f80, 1e0, fmin(f80));
            try testArgs(f80, 1e0, 1e-1);
            try testArgs(f80, 1e0, 1e0);
            try testArgs(f80, 1e0, 1e1);
            try testArgs(f80, 1e0, fmax(f80));
            try testArgs(f80, 1e0, inf(f80));
            try testArgs(f80, 1e0, nan(f80));

            try testArgs(f80, 1e1, -nan(f80));
            try testArgs(f80, 1e1, -inf(f80));
            try testArgs(f80, 1e1, -fmax(f80));
            try testArgs(f80, 1e1, -1e1);
            try testArgs(f80, 1e1, -1e0);
            try testArgs(f80, 1e1, -1e-1);
            try testArgs(f80, 1e1, -fmin(f80));
            try testArgs(f80, 1e1, -tmin(f80));
            try testArgs(f80, 1e1, -0.0);
            try testArgs(f80, 1e1, 0.0);
            try testArgs(f80, 1e1, tmin(f80));
            try testArgs(f80, 1e1, fmin(f80));
            try testArgs(f80, 1e1, 1e-1);
            try testArgs(f80, 1e1, 1e0);
            try testArgs(f80, 1e1, 1e1);
            try testArgs(f80, 1e1, fmax(f80));
            try testArgs(f80, 1e1, inf(f80));
            try testArgs(f80, 1e1, nan(f80));

            try testArgs(f80, fmax(f80), -nan(f80));
            try testArgs(f80, fmax(f80), -inf(f80));
            try testArgs(f80, fmax(f80), -fmax(f80));
            try testArgs(f80, fmax(f80), -1e1);
            try testArgs(f80, fmax(f80), -1e0);
            try testArgs(f80, fmax(f80), -1e-1);
            try testArgs(f80, fmax(f80), -fmin(f80));
            try testArgs(f80, fmax(f80), -tmin(f80));
            try testArgs(f80, fmax(f80), -0.0);
            try testArgs(f80, fmax(f80), 0.0);
            try testArgs(f80, fmax(f80), tmin(f80));
            try testArgs(f80, fmax(f80), fmin(f80));
            try testArgs(f80, fmax(f80), 1e-1);
            try testArgs(f80, fmax(f80), 1e0);
            try testArgs(f80, fmax(f80), 1e1);
            try testArgs(f80, fmax(f80), fmax(f80));
            try testArgs(f80, fmax(f80), inf(f80));
            try testArgs(f80, fmax(f80), nan(f80));

            try testArgs(f80, inf(f80), -nan(f80));
            try testArgs(f80, inf(f80), -inf(f80));
            try testArgs(f80, inf(f80), -fmax(f80));
            try testArgs(f80, inf(f80), -1e1);
            try testArgs(f80, inf(f80), -1e0);
            try testArgs(f80, inf(f80), -1e-1);
            try testArgs(f80, inf(f80), -fmin(f80));
            try testArgs(f80, inf(f80), -tmin(f80));
            try testArgs(f80, inf(f80), -0.0);
            try testArgs(f80, inf(f80), 0.0);
            try testArgs(f80, inf(f80), tmin(f80));
            try testArgs(f80, inf(f80), fmin(f80));
            try testArgs(f80, inf(f80), 1e-1);
            try testArgs(f80, inf(f80), 1e0);
            try testArgs(f80, inf(f80), 1e1);
            try testArgs(f80, inf(f80), fmax(f80));
            try testArgs(f80, inf(f80), inf(f80));
            try testArgs(f80, inf(f80), nan(f80));

            try testArgs(f80, nan(f80), -nan(f80));
            try testArgs(f80, nan(f80), -inf(f80));
            try testArgs(f80, nan(f80), -fmax(f80));
            try testArgs(f80, nan(f80), -1e1);
            try testArgs(f80, nan(f80), -1e0);
            try testArgs(f80, nan(f80), -1e-1);
            try testArgs(f80, nan(f80), -fmin(f80));
            try testArgs(f80, nan(f80), -tmin(f80));
            try testArgs(f80, nan(f80), -0.0);
            try testArgs(f80, nan(f80), 0.0);
            try testArgs(f80, nan(f80), tmin(f80));
            try testArgs(f80, nan(f80), fmin(f80));
            try testArgs(f80, nan(f80), 1e-1);
            try testArgs(f80, nan(f80), 1e0);
            try testArgs(f80, nan(f80), 1e1);
            try testArgs(f80, nan(f80), fmax(f80));
            try testArgs(f80, nan(f80), inf(f80));
            try testArgs(f80, nan(f80), nan(f80));

            try testArgs(f128, -nan(f128), -nan(f128));
            try testArgs(f128, -nan(f128), -inf(f128));
            try testArgs(f128, -nan(f128), -fmax(f128));
            try testArgs(f128, -nan(f128), -1e1);
            try testArgs(f128, -nan(f128), -1e0);
            try testArgs(f128, -nan(f128), -1e-1);
            try testArgs(f128, -nan(f128), -fmin(f128));
            try testArgs(f128, -nan(f128), -tmin(f128));
            try testArgs(f128, -nan(f128), -0.0);
            try testArgs(f128, -nan(f128), 0.0);
            try testArgs(f128, -nan(f128), tmin(f128));
            try testArgs(f128, -nan(f128), fmin(f128));
            try testArgs(f128, -nan(f128), 1e-1);
            try testArgs(f128, -nan(f128), 1e0);
            try testArgs(f128, -nan(f128), 1e1);
            try testArgs(f128, -nan(f128), fmax(f128));
            try testArgs(f128, -nan(f128), inf(f128));
            try testArgs(f128, -nan(f128), nan(f128));

            try testArgs(f128, -inf(f128), -nan(f128));
            try testArgs(f128, -inf(f128), -inf(f128));
            try testArgs(f128, -inf(f128), -fmax(f128));
            try testArgs(f128, -inf(f128), -1e1);
            try testArgs(f128, -inf(f128), -1e0);
            try testArgs(f128, -inf(f128), -1e-1);
            try testArgs(f128, -inf(f128), -fmin(f128));
            try testArgs(f128, -inf(f128), -tmin(f128));
            try testArgs(f128, -inf(f128), -0.0);
            try testArgs(f128, -inf(f128), 0.0);
            try testArgs(f128, -inf(f128), tmin(f128));
            try testArgs(f128, -inf(f128), fmin(f128));
            try testArgs(f128, -inf(f128), 1e-1);
            try testArgs(f128, -inf(f128), 1e0);
            try testArgs(f128, -inf(f128), 1e1);
            try testArgs(f128, -inf(f128), fmax(f128));
            try testArgs(f128, -inf(f128), inf(f128));
            try testArgs(f128, -inf(f128), nan(f128));

            try testArgs(f128, -fmax(f128), -nan(f128));
            try testArgs(f128, -fmax(f128), -inf(f128));
            try testArgs(f128, -fmax(f128), -fmax(f128));
            try testArgs(f128, -fmax(f128), -1e1);
            try testArgs(f128, -fmax(f128), -1e0);
            try testArgs(f128, -fmax(f128), -1e-1);
            try testArgs(f128, -fmax(f128), -fmin(f128));
            try testArgs(f128, -fmax(f128), -tmin(f128));
            try testArgs(f128, -fmax(f128), -0.0);
            try testArgs(f128, -fmax(f128), 0.0);
            try testArgs(f128, -fmax(f128), tmin(f128));
            try testArgs(f128, -fmax(f128), fmin(f128));
            try testArgs(f128, -fmax(f128), 1e-1);
            try testArgs(f128, -fmax(f128), 1e0);
            try testArgs(f128, -fmax(f128), 1e1);
            try testArgs(f128, -fmax(f128), fmax(f128));
            try testArgs(f128, -fmax(f128), inf(f128));
            try testArgs(f128, -fmax(f128), nan(f128));

            try testArgs(f128, -1e1, -nan(f128));
            try testArgs(f128, -1e1, -inf(f128));
            try testArgs(f128, -1e1, -fmax(f128));
            try testArgs(f128, -1e1, -1e1);
            try testArgs(f128, -1e1, -1e0);
            try testArgs(f128, -1e1, -1e-1);
            try testArgs(f128, -1e1, -fmin(f128));
            try testArgs(f128, -1e1, -tmin(f128));
            try testArgs(f128, -1e1, -0.0);
            try testArgs(f128, -1e1, 0.0);
            try testArgs(f128, -1e1, tmin(f128));
            try testArgs(f128, -1e1, fmin(f128));
            try testArgs(f128, -1e1, 1e-1);
            try testArgs(f128, -1e1, 1e0);
            try testArgs(f128, -1e1, 1e1);
            try testArgs(f128, -1e1, fmax(f128));
            try testArgs(f128, -1e1, inf(f128));
            try testArgs(f128, -1e1, nan(f128));

            try testArgs(f128, -1e0, -nan(f128));
            try testArgs(f128, -1e0, -inf(f128));
            try testArgs(f128, -1e0, -fmax(f128));
            try testArgs(f128, -1e0, -1e1);
            try testArgs(f128, -1e0, -1e0);
            try testArgs(f128, -1e0, -1e-1);
            try testArgs(f128, -1e0, -fmin(f128));
            try testArgs(f128, -1e0, -tmin(f128));
            try testArgs(f128, -1e0, -0.0);
            try testArgs(f128, -1e0, 0.0);
            try testArgs(f128, -1e0, tmin(f128));
            try testArgs(f128, -1e0, fmin(f128));
            try testArgs(f128, -1e0, 1e-1);
            try testArgs(f128, -1e0, 1e0);
            try testArgs(f128, -1e0, 1e1);
            try testArgs(f128, -1e0, fmax(f128));
            try testArgs(f128, -1e0, inf(f128));
            try testArgs(f128, -1e0, nan(f128));

            try testArgs(f128, -1e-1, -nan(f128));
            try testArgs(f128, -1e-1, -inf(f128));
            try testArgs(f128, -1e-1, -fmax(f128));
            try testArgs(f128, -1e-1, -1e1);
            try testArgs(f128, -1e-1, -1e0);
            try testArgs(f128, -1e-1, -1e-1);
            try testArgs(f128, -1e-1, -fmin(f128));
            try testArgs(f128, -1e-1, -tmin(f128));
            try testArgs(f128, -1e-1, -0.0);
            try testArgs(f128, -1e-1, 0.0);
            try testArgs(f128, -1e-1, tmin(f128));
            try testArgs(f128, -1e-1, fmin(f128));
            try testArgs(f128, -1e-1, 1e-1);
            try testArgs(f128, -1e-1, 1e0);
            try testArgs(f128, -1e-1, 1e1);
            try testArgs(f128, -1e-1, fmax(f128));
            try testArgs(f128, -1e-1, inf(f128));
            try testArgs(f128, -1e-1, nan(f128));

            try testArgs(f128, -fmin(f128), -nan(f128));
            try testArgs(f128, -fmin(f128), -inf(f128));
            try testArgs(f128, -fmin(f128), -fmax(f128));
            try testArgs(f128, -fmin(f128), -1e1);
            try testArgs(f128, -fmin(f128), -1e0);
            try testArgs(f128, -fmin(f128), -1e-1);
            try testArgs(f128, -fmin(f128), -fmin(f128));
            try testArgs(f128, -fmin(f128), -tmin(f128));
            try testArgs(f128, -fmin(f128), -0.0);
            try testArgs(f128, -fmin(f128), 0.0);
            try testArgs(f128, -fmin(f128), tmin(f128));
            try testArgs(f128, -fmin(f128), fmin(f128));
            try testArgs(f128, -fmin(f128), 1e-1);
            try testArgs(f128, -fmin(f128), 1e0);
            try testArgs(f128, -fmin(f128), 1e1);
            try testArgs(f128, -fmin(f128), fmax(f128));
            try testArgs(f128, -fmin(f128), inf(f128));
            try testArgs(f128, -fmin(f128), nan(f128));

            try testArgs(f128, -tmin(f128), -nan(f128));
            try testArgs(f128, -tmin(f128), -inf(f128));
            try testArgs(f128, -tmin(f128), -fmax(f128));
            try testArgs(f128, -tmin(f128), -1e1);
            try testArgs(f128, -tmin(f128), -1e0);
            try testArgs(f128, -tmin(f128), -1e-1);
            try testArgs(f128, -tmin(f128), -fmin(f128));
            try testArgs(f128, -tmin(f128), -tmin(f128));
            try testArgs(f128, -tmin(f128), -0.0);
            try testArgs(f128, -tmin(f128), 0.0);
            try testArgs(f128, -tmin(f128), tmin(f128));
            try testArgs(f128, -tmin(f128), fmin(f128));
            try testArgs(f128, -tmin(f128), 1e-1);
            try testArgs(f128, -tmin(f128), 1e0);
            try testArgs(f128, -tmin(f128), 1e1);
            try testArgs(f128, -tmin(f128), fmax(f128));
            try testArgs(f128, -tmin(f128), inf(f128));
            try testArgs(f128, -tmin(f128), nan(f128));

            try testArgs(f128, -0.0, -nan(f128));
            try testArgs(f128, -0.0, -inf(f128));
            try testArgs(f128, -0.0, -fmax(f128));
            try testArgs(f128, -0.0, -1e1);
            try testArgs(f128, -0.0, -1e0);
            try testArgs(f128, -0.0, -1e-1);
            try testArgs(f128, -0.0, -fmin(f128));
            try testArgs(f128, -0.0, -tmin(f128));
            try testArgs(f128, -0.0, -0.0);
            try testArgs(f128, -0.0, 0.0);
            try testArgs(f128, -0.0, tmin(f128));
            try testArgs(f128, -0.0, fmin(f128));
            try testArgs(f128, -0.0, 1e-1);
            try testArgs(f128, -0.0, 1e0);
            try testArgs(f128, -0.0, 1e1);
            try testArgs(f128, -0.0, fmax(f128));
            try testArgs(f128, -0.0, inf(f128));
            try testArgs(f128, -0.0, nan(f128));

            try testArgs(f128, 0.0, -nan(f128));
            try testArgs(f128, 0.0, -inf(f128));
            try testArgs(f128, 0.0, -fmax(f128));
            try testArgs(f128, 0.0, -1e1);
            try testArgs(f128, 0.0, -1e0);
            try testArgs(f128, 0.0, -1e-1);
            try testArgs(f128, 0.0, -fmin(f128));
            try testArgs(f128, 0.0, -tmin(f128));
            try testArgs(f128, 0.0, -0.0);
            try testArgs(f128, 0.0, 0.0);
            try testArgs(f128, 0.0, tmin(f128));
            try testArgs(f128, 0.0, fmin(f128));
            try testArgs(f128, 0.0, 1e-1);
            try testArgs(f128, 0.0, 1e0);
            try testArgs(f128, 0.0, 1e1);
            try testArgs(f128, 0.0, fmax(f128));
            try testArgs(f128, 0.0, inf(f128));
            try testArgs(f128, 0.0, nan(f128));

            try testArgs(f128, tmin(f128), -nan(f128));
            try testArgs(f128, tmin(f128), -inf(f128));
            try testArgs(f128, tmin(f128), -fmax(f128));
            try testArgs(f128, tmin(f128), -1e1);
            try testArgs(f128, tmin(f128), -1e0);
            try testArgs(f128, tmin(f128), -1e-1);
            try testArgs(f128, tmin(f128), -fmin(f128));
            try testArgs(f128, tmin(f128), -tmin(f128));
            try testArgs(f128, tmin(f128), -0.0);
            try testArgs(f128, tmin(f128), 0.0);
            try testArgs(f128, tmin(f128), tmin(f128));
            try testArgs(f128, tmin(f128), fmin(f128));
            try testArgs(f128, tmin(f128), 1e-1);
            try testArgs(f128, tmin(f128), 1e0);
            try testArgs(f128, tmin(f128), 1e1);
            try testArgs(f128, tmin(f128), fmax(f128));
            try testArgs(f128, tmin(f128), inf(f128));
            try testArgs(f128, tmin(f128), nan(f128));

            try testArgs(f128, fmin(f128), -nan(f128));
            try testArgs(f128, fmin(f128), -inf(f128));
            try testArgs(f128, fmin(f128), -fmax(f128));
            try testArgs(f128, fmin(f128), -1e1);
            try testArgs(f128, fmin(f128), -1e0);
            try testArgs(f128, fmin(f128), -1e-1);
            try testArgs(f128, fmin(f128), -fmin(f128));
            try testArgs(f128, fmin(f128), -tmin(f128));
            try testArgs(f128, fmin(f128), -0.0);
            try testArgs(f128, fmin(f128), 0.0);
            try testArgs(f128, fmin(f128), tmin(f128));
            try testArgs(f128, fmin(f128), fmin(f128));
            try testArgs(f128, fmin(f128), 1e-1);
            try testArgs(f128, fmin(f128), 1e0);
            try testArgs(f128, fmin(f128), 1e1);
            try testArgs(f128, fmin(f128), fmax(f128));
            try testArgs(f128, fmin(f128), inf(f128));
            try testArgs(f128, fmin(f128), nan(f128));

            try testArgs(f128, 1e-1, -nan(f128));
            try testArgs(f128, 1e-1, -inf(f128));
            try testArgs(f128, 1e-1, -fmax(f128));
            try testArgs(f128, 1e-1, -1e1);
            try testArgs(f128, 1e-1, -1e0);
            try testArgs(f128, 1e-1, -1e-1);
            try testArgs(f128, 1e-1, -fmin(f128));
            try testArgs(f128, 1e-1, -tmin(f128));
            try testArgs(f128, 1e-1, -0.0);
            try testArgs(f128, 1e-1, 0.0);
            try testArgs(f128, 1e-1, tmin(f128));
            try testArgs(f128, 1e-1, fmin(f128));
            try testArgs(f128, 1e-1, 1e-1);
            try testArgs(f128, 1e-1, 1e0);
            try testArgs(f128, 1e-1, 1e1);
            try testArgs(f128, 1e-1, fmax(f128));
            try testArgs(f128, 1e-1, inf(f128));
            try testArgs(f128, 1e-1, nan(f128));

            try testArgs(f128, 1e0, -nan(f128));
            try testArgs(f128, 1e0, -inf(f128));
            try testArgs(f128, 1e0, -fmax(f128));
            try testArgs(f128, 1e0, -1e1);
            try testArgs(f128, 1e0, -1e0);
            try testArgs(f128, 1e0, -1e-1);
            try testArgs(f128, 1e0, -fmin(f128));
            try testArgs(f128, 1e0, -tmin(f128));
            try testArgs(f128, 1e0, -0.0);
            try testArgs(f128, 1e0, 0.0);
            try testArgs(f128, 1e0, tmin(f128));
            try testArgs(f128, 1e0, fmin(f128));
            try testArgs(f128, 1e0, 1e-1);
            try testArgs(f128, 1e0, 1e0);
            try testArgs(f128, 1e0, 1e1);
            try testArgs(f128, 1e0, fmax(f128));
            try testArgs(f128, 1e0, inf(f128));
            try testArgs(f128, 1e0, nan(f128));

            try testArgs(f128, 1e1, -nan(f128));
            try testArgs(f128, 1e1, -inf(f128));
            try testArgs(f128, 1e1, -fmax(f128));
            try testArgs(f128, 1e1, -1e1);
            try testArgs(f128, 1e1, -1e0);
            try testArgs(f128, 1e1, -1e-1);
            try testArgs(f128, 1e1, -fmin(f128));
            try testArgs(f128, 1e1, -tmin(f128));
            try testArgs(f128, 1e1, -0.0);
            try testArgs(f128, 1e1, 0.0);
            try testArgs(f128, 1e1, tmin(f128));
            try testArgs(f128, 1e1, fmin(f128));
            try testArgs(f128, 1e1, 1e-1);
            try testArgs(f128, 1e1, 1e0);
            try testArgs(f128, 1e1, 1e1);
            try testArgs(f128, 1e1, fmax(f128));
            try testArgs(f128, 1e1, inf(f128));
            try testArgs(f128, 1e1, nan(f128));

            try testArgs(f128, fmax(f128), -nan(f128));
            try testArgs(f128, fmax(f128), -inf(f128));
            try testArgs(f128, fmax(f128), -fmax(f128));
            try testArgs(f128, fmax(f128), -1e1);
            try testArgs(f128, fmax(f128), -1e0);
            try testArgs(f128, fmax(f128), -1e-1);
            try testArgs(f128, fmax(f128), -fmin(f128));
            try testArgs(f128, fmax(f128), -tmin(f128));
            try testArgs(f128, fmax(f128), -0.0);
            try testArgs(f128, fmax(f128), 0.0);
            try testArgs(f128, fmax(f128), tmin(f128));
            try testArgs(f128, fmax(f128), fmin(f128));
            try testArgs(f128, fmax(f128), 1e-1);
            try testArgs(f128, fmax(f128), 1e0);
            try testArgs(f128, fmax(f128), 1e1);
            try testArgs(f128, fmax(f128), fmax(f128));
            try testArgs(f128, fmax(f128), inf(f128));
            try testArgs(f128, fmax(f128), nan(f128));

            try testArgs(f128, inf(f128), -nan(f128));
            try testArgs(f128, inf(f128), -inf(f128));
            try testArgs(f128, inf(f128), -fmax(f128));
            try testArgs(f128, inf(f128), -1e1);
            try testArgs(f128, inf(f128), -1e0);
            try testArgs(f128, inf(f128), -1e-1);
            try testArgs(f128, inf(f128), -fmin(f128));
            try testArgs(f128, inf(f128), -tmin(f128));
            try testArgs(f128, inf(f128), -0.0);
            try testArgs(f128, inf(f128), 0.0);
            try testArgs(f128, inf(f128), tmin(f128));
            try testArgs(f128, inf(f128), fmin(f128));
            try testArgs(f128, inf(f128), 1e-1);
            try testArgs(f128, inf(f128), 1e0);
            try testArgs(f128, inf(f128), 1e1);
            try testArgs(f128, inf(f128), fmax(f128));
            try testArgs(f128, inf(f128), inf(f128));
            try testArgs(f128, inf(f128), nan(f128));

            try testArgs(f128, nan(f128), -nan(f128));
            try testArgs(f128, nan(f128), -inf(f128));
            try testArgs(f128, nan(f128), -fmax(f128));
            try testArgs(f128, nan(f128), -1e1);
            try testArgs(f128, nan(f128), -1e0);
            try testArgs(f128, nan(f128), -1e-1);
            try testArgs(f128, nan(f128), -fmin(f128));
            try testArgs(f128, nan(f128), -tmin(f128));
            try testArgs(f128, nan(f128), -0.0);
            try testArgs(f128, nan(f128), 0.0);
            try testArgs(f128, nan(f128), tmin(f128));
            try testArgs(f128, nan(f128), fmin(f128));
            try testArgs(f128, nan(f128), 1e-1);
            try testArgs(f128, nan(f128), 1e0);
            try testArgs(f128, nan(f128), 1e1);
            try testArgs(f128, nan(f128), fmax(f128));
            try testArgs(f128, nan(f128), inf(f128));
            try testArgs(f128, nan(f128), nan(f128));
        }
        fn testIntVectors() !void {
            try testArgs(@Vector(1, i1), .{
                0x0,
            }, .{
                -0x1,
            });
            try testArgs(@Vector(2, i1), .{
                0x0, 0x00,
            }, .{
                -0x1, -0x1,
            });
            try testArgs(@Vector(4, i1), .{
                0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1,
            });
            try testArgs(@Vector(8, i1), .{
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
            });
            try testArgs(@Vector(16, i1), .{
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
            });
            try testArgs(@Vector(32, i1), .{
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
            });
            try testArgs(@Vector(64, i1), .{
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
            });
            try testArgs(@Vector(128, i1), .{
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            }, .{
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
                -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, -0x1,
            });

            try testArgs(@Vector(1, u1), .{
                0x0,
            }, .{
                0x1,
            });
            try testArgs(@Vector(2, u1), .{
                0x0, 0x1,
            }, .{
                0x1, 0x1,
            });
            try testArgs(@Vector(4, u1), .{
                0x0, 0x0, 0x1, 0x0,
            }, .{
                0x1, 0x1, 0x1, 0x1,
            });
            try testArgs(@Vector(8, u1), .{
                0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1,
            }, .{
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
            });
            try testArgs(@Vector(16, u1), .{
                0x1, 0x0, 0x0, 0x1, 0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0, 0x1, 0x1, 0x1, 0x0, 0x1,
            }, .{
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
            });
            try testArgs(@Vector(32, u1), .{
                0x0, 0x1, 0x1, 0x1, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0,
                0x1, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0,
            }, .{
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
            });
            try testArgs(@Vector(64, u1), .{
                0x1, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0, 0x1, 0x1,
                0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x0, 0x0, 0x1, 0x1, 0x0, 0x1, 0x1, 0x1, 0x1, 0x0, 0x1, 0x1, 0x0, 0x0, 0x1,
                0x1, 0x0, 0x0, 0x1, 0x0, 0x0, 0x1, 0x0, 0x0, 0x1, 0x1, 0x0, 0x0, 0x1, 0x1, 0x0,
            }, .{
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
            });
            try testArgs(@Vector(128, u1), .{
                0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1,
                0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x1, 0x1, 0x1, 0x0, 0x0, 0x1,
                0x1, 0x1, 0x0, 0x1, 0x1, 0x0, 0x0, 0x1, 0x1, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x1, 0x1, 0x0, 0x1,
                0x1, 0x0, 0x1, 0x1, 0x0, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x1, 0x1,
                0x0, 0x1, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x1, 0x0, 0x1, 0x1,
                0x1, 0x0, 0x0, 0x1, 0x0, 0x1, 0x1, 0x1, 0x0, 0x0, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0,
                0x0, 0x0, 0x1, 0x1, 0x0, 0x1, 0x0, 0x0, 0x0, 0x1, 0x0, 0x1, 0x1, 0x1, 0x0, 0x1,
            }, .{
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
            });

            try testArgs(@Vector(1, i2), .{
                0x1,
            }, .{
                0x1,
            });
            try testArgs(@Vector(2, i2), .{
                0x0, -0x2,
            }, .{
                -0x2, -0x2,
            });
            try testArgs(@Vector(4, i2), .{
                -0x2, -0x1, 0x0, -0x2,
            }, .{
                -0x2, 0x1, -0x1, -0x2,
            });
            try testArgs(@Vector(8, i2), .{
                -0x1, 0x1, 0x1, -0x1, -0x2, -0x2, 0x0, -0x2,
            }, .{
                -0x1, -0x1, -0x2, -0x1, -0x2, 0x1, -0x1, 0x1,
            });
            try testArgs(@Vector(16, i2), .{
                0x0, -0x2, -0x1, -0x2, 0x1, 0x0, -0x1, 0x0, 0x1, -0x2, 0x1, -0x1, -0x2, -0x2, 0x1, 0x0,
            }, .{
                -0x2, -0x2, 0x1, -0x2, -0x1, -0x2, -0x1, -0x2, -0x2, -0x2, -0x1, -0x2, 0x1, -0x2, -0x2, -0x2,
            });
            try testArgs(@Vector(32, i2), .{
                -0x2, 0x1, -0x1, 0x1, 0x0, -0x2, 0x1, -0x2, -0x2, 0x0,  -0x1, 0x0,  -0x2, -0x2, 0x0, 0x1,
                -0x1, 0x1, -0x1, 0x1, 0x1, 0x1,  0x1, -0x2, -0x1, -0x1, 0x1,  -0x2, 0x0,  -0x1, 0x0, -0x2,
            }, .{
                0x1,  -0x1, 0x1, -0x1, 0x1,  0x1,  0x1,  -0x2, 0x1,  -0x2, -0x1, -0x2, 0x1,  0x1, 0x1,  -0x1,
                -0x2, 0x1,  0x1, -0x1, -0x2, -0x2, -0x1, -0x2, -0x1, -0x2, 0x1,  -0x2, -0x1, 0x1, -0x2, -0x2,
            });
            try testArgs(@Vector(64, i2), .{
                0x1,  -0x2, -0x1, 0x0,  0x1,  -0x2, -0x1, -0x2, -0x2, -0x1, -0x2, -0x1, 0x1, 0x1,  0x0,  0x1,
                -0x1, -0x1, -0x1, 0x1,  0x1,  -0x1, 0x0,  0x1,  -0x1, 0x0,  0x0,  0x1,  0x1, 0x0,  -0x2, -0x2,
                0x1,  0x0,  -0x2, -0x2, 0x1,  -0x2, -0x2, 0x1,  0x1,  -0x2, 0x1,  0x0,  0x0, -0x1, 0x0,  0x1,
                -0x2, 0x0,  0x0,  -0x1, -0x1, 0x1,  -0x2, 0x0,  -0x2, 0x0,  -0x2, 0x1,  0x0, -0x1, -0x1, 0x1,
            }, .{
                -0x2, -0x2, 0x1,  -0x1, -0x2, -0x2, -0x1, -0x2, 0x1,  0x1,  0x1,  -0x1, 0x1,  0x1,  0x1,  -0x1,
                -0x2, 0x1,  0x1,  -0x2, -0x2, 0x1,  0x1,  -0x1, -0x2, -0x2, 0x1,  -0x1, -0x2, 0x1,  -0x2, 0x1,
                0x1,  -0x2, -0x2, -0x2, -0x2, 0x1,  0x1,  0x1,  -0x2, 0x1,  -0x1, 0x1,  -0x1, 0x1,  0x1,  -0x1,
                -0x2, 0x1,  -0x1, 0x1,  -0x1, -0x1, 0x1,  0x1,  -0x2, 0x1,  0x1,  -0x2, -0x2, -0x1, -0x2, -0x2,
            });
            try testArgs(@Vector(128, i2), .{
                -0x1, -0x2, 0x0,  -0x2, -0x2, 0x1,  -0x1, 0x0,  -0x1, -0x2, 0x0,  -0x2, 0x0,  0x1,  0x0,  -0x1,
                0x0,  -0x2, 0x1,  0x0,  0x1,  0x0,  -0x2, 0x1,  0x1,  0x1,  -0x1, 0x1,  0x0,  -0x1, 0x1,  -0x1,
                0x1,  -0x2, 0x1,  -0x2, 0x1,  -0x2, 0x1,  -0x2, -0x2, -0x2, 0x0,  0x0,  0x1,  0x1,  -0x2, -0x1,
                0x1,  0x0,  0x0,  0x1,  -0x2, -0x1, 0x0,  -0x1, 0x1,  -0x2, 0x1,  0x0,  0x1,  0x0,  0x0,  -0x2,
                0x0,  0x0,  -0x1, 0x1,  -0x1, 0x0,  -0x1, -0x2, 0x1,  -0x2, -0x2, -0x1, -0x2, 0x0,  0x0,  0x0,
                -0x1, -0x1, -0x1, -0x1, -0x2, 0x0,  -0x1, 0x1,  0x0,  0x0,  -0x2, 0x0,  0x0,  0x0,  0x0,  0x1,
                0x1,  -0x2, 0x0,  0x0,  -0x1, -0x1, 0x1,  -0x1, -0x2, 0x0,  -0x1, -0x1, -0x2, -0x2, 0x0,  0x0,
                -0x1, 0x0,  0x1,  0x0,  -0x1, -0x2, 0x1,  -0x2, -0x1, -0x1, 0x0,  0x0,  -0x1, 0x0,  0x0,  0x1,
            }, .{
                -0x2, -0x2, 0x1,  0x1,  -0x2, -0x1, 0x1,  0x1,  0x1,  -0x2, -0x2, 0x1,  -0x2, -0x2, 0x1,  -0x1,
                -0x1, -0x2, 0x1,  -0x1, 0x1,  0x1,  0x1,  -0x1, -0x1, -0x1, -0x1, -0x1, -0x1, 0x1,  0x1,  -0x2,
                -0x1, -0x2, -0x2, -0x2, -0x2, -0x2, -0x1, -0x2, 0x1,  0x1,  -0x1, -0x1, -0x1, -0x1, 0x1,  -0x2,
                0x1,  -0x1, 0x1,  -0x1, 0x1,  0x1,  -0x1, -0x2, 0x1,  0x1,  -0x2, -0x2, -0x2, 0x1,  0x1,  -0x2,
                -0x1, 0x1,  -0x2, -0x1, -0x1, 0x1,  -0x2, -0x2, 0x1,  0x1,  -0x2, -0x1, -0x2, -0x2, -0x2, -0x2,
                0x1,  -0x1, 0x1,  -0x2, 0x1,  -0x1, -0x1, 0x1,  0x1,  -0x1, 0x1,  -0x1, -0x2, -0x2, -0x1, -0x2,
                -0x2, 0x1,  -0x2, -0x2, -0x1, -0x1, -0x1, -0x2, 0x1,  -0x2, 0x1,  -0x2, 0x1,  -0x2, -0x2, 0x1,
                0x1,  -0x1, 0x1,  0x1,  -0x1, -0x2, 0x1,  0x1,  -0x1, -0x2, -0x1, -0x1, 0x1,  -0x2, -0x2, -0x2,
            });

            try testArgs(@Vector(1, u2), .{
                0x2,
            }, .{
                0x2,
            });
            try testArgs(@Vector(2, u2), .{
                0x1, 0x0,
            }, .{
                0x2, 0x1,
            });
            try testArgs(@Vector(4, u2), .{
                0x3, 0x3, 0x0, 0x2,
            }, .{
                0x3, 0x1, 0x1, 0x3,
            });
            try testArgs(@Vector(8, u2), .{
                0x0, 0x3, 0x3, 0x2, 0x1, 0x2, 0x3, 0x1,
            }, .{
                0x1, 0x1, 0x3, 0x1, 0x2, 0x2, 0x2, 0x2,
            });
            try testArgs(@Vector(16, u2), .{
                0x1, 0x1, 0x0, 0x1, 0x0, 0x2, 0x2, 0x1, 0x2, 0x1, 0x3, 0x1, 0x1, 0x3, 0x3, 0x1,
            }, .{
                0x1, 0x2, 0x2, 0x2, 0x1, 0x2, 0x3, 0x1, 0x3, 0x3, 0x2, 0x2, 0x2, 0x1, 0x3, 0x1,
            });
            try testArgs(@Vector(32, u2), .{
                0x2, 0x2, 0x3, 0x1, 0x3, 0x2, 0x1, 0x3, 0x3, 0x0, 0x0, 0x3, 0x3, 0x1, 0x3, 0x0,
                0x1, 0x0, 0x2, 0x3, 0x2, 0x3, 0x2, 0x0, 0x1, 0x3, 0x1, 0x0, 0x2, 0x0, 0x3, 0x0,
            }, .{
                0x3, 0x2, 0x1, 0x1, 0x2, 0x3, 0x1, 0x3, 0x1, 0x1, 0x3, 0x1, 0x2, 0x3, 0x3, 0x2,
                0x2, 0x2, 0x1, 0x1, 0x1, 0x2, 0x1, 0x1, 0x2, 0x2, 0x2, 0x1, 0x3, 0x2, 0x3, 0x3,
            });
            try testArgs(@Vector(64, u2), .{
                0x1, 0x3, 0x2, 0x1, 0x1, 0x3, 0x1, 0x3, 0x2, 0x1, 0x3, 0x2, 0x2, 0x2, 0x3, 0x0,
                0x3, 0x1, 0x1, 0x0, 0x1, 0x0, 0x1, 0x1, 0x0, 0x0, 0x0, 0x1, 0x3, 0x3, 0x1, 0x3,
                0x1, 0x2, 0x3, 0x2, 0x3, 0x0, 0x1, 0x1, 0x2, 0x1, 0x0, 0x3, 0x2, 0x3, 0x3, 0x0,
                0x0, 0x0, 0x3, 0x1, 0x3, 0x0, 0x1, 0x0, 0x2, 0x0, 0x3, 0x0, 0x1, 0x0, 0x3, 0x3,
            }, .{
                0x1, 0x2, 0x2, 0x1, 0x2, 0x1, 0x2, 0x3, 0x3, 0x2, 0x1, 0x2, 0x3, 0x1, 0x2, 0x3,
                0x2, 0x2, 0x3, 0x1, 0x2, 0x2, 0x2, 0x1, 0x1, 0x2, 0x3, 0x3, 0x2, 0x3, 0x1, 0x1,
                0x3, 0x2, 0x1, 0x1, 0x3, 0x1, 0x1, 0x1, 0x2, 0x1, 0x3, 0x1, 0x1, 0x3, 0x2, 0x2,
                0x3, 0x2, 0x3, 0x3, 0x3, 0x1, 0x2, 0x1, 0x3, 0x1, 0x1, 0x2, 0x1, 0x3, 0x3, 0x1,
            });
            try testArgs(@Vector(128, u2), .{
                0x2, 0x0, 0x0, 0x1, 0x3, 0x0, 0x0, 0x3, 0x0, 0x1, 0x2, 0x0, 0x0, 0x2, 0x0, 0x1,
                0x3, 0x0, 0x0, 0x1, 0x3, 0x0, 0x3, 0x0, 0x1, 0x1, 0x2, 0x3, 0x0, 0x1, 0x2, 0x1,
                0x0, 0x0, 0x3, 0x3, 0x3, 0x2, 0x2, 0x1, 0x0, 0x3, 0x1, 0x1, 0x3, 0x3, 0x1, 0x0,
                0x1, 0x2, 0x2, 0x1, 0x0, 0x1, 0x2, 0x2, 0x2, 0x1, 0x2, 0x3, 0x2, 0x0, 0x0, 0x0,
                0x1, 0x3, 0x2, 0x3, 0x0, 0x0, 0x0, 0x3, 0x0, 0x0, 0x1, 0x0, 0x2, 0x1, 0x0, 0x3,
                0x2, 0x1, 0x3, 0x3, 0x1, 0x2, 0x1, 0x3, 0x3, 0x0, 0x1, 0x3, 0x2, 0x1, 0x0, 0x1,
                0x1, 0x0, 0x2, 0x0, 0x2, 0x2, 0x2, 0x1, 0x3, 0x2, 0x2, 0x3, 0x2, 0x0, 0x0, 0x1,
                0x1, 0x1, 0x1, 0x1, 0x0, 0x3, 0x1, 0x1, 0x2, 0x1, 0x0, 0x2, 0x3, 0x3, 0x1, 0x2,
            }, .{
                0x3, 0x2, 0x2, 0x1, 0x3, 0x3, 0x1, 0x3, 0x2, 0x3, 0x3, 0x1, 0x1, 0x1, 0x3, 0x1,
                0x2, 0x2, 0x1, 0x3, 0x1, 0x2, 0x3, 0x3, 0x3, 0x3, 0x1, 0x2, 0x3, 0x1, 0x3, 0x3,
                0x2, 0x1, 0x2, 0x3, 0x1, 0x2, 0x1, 0x2, 0x3, 0x3, 0x3, 0x1, 0x1, 0x2, 0x1, 0x3,
                0x1, 0x3, 0x1, 0x3, 0x2, 0x2, 0x2, 0x1, 0x3, 0x2, 0x2, 0x2, 0x2, 0x3, 0x1, 0x2,
                0x2, 0x2, 0x2, 0x3, 0x2, 0x2, 0x2, 0x2, 0x1, 0x2, 0x3, 0x3, 0x1, 0x3, 0x1, 0x2,
                0x1, 0x1, 0x3, 0x2, 0x2, 0x1, 0x3, 0x2, 0x3, 0x1, 0x2, 0x2, 0x2, 0x2, 0x1, 0x1,
                0x1, 0x3, 0x1, 0x3, 0x1, 0x3, 0x3, 0x3, 0x2, 0x3, 0x1, 0x1, 0x2, 0x2, 0x3, 0x1,
                0x2, 0x2, 0x3, 0x3, 0x1, 0x1, 0x1, 0x1, 0x2, 0x1, 0x3, 0x1, 0x3, 0x2, 0x3, 0x1,
            });

            try testArgs(@Vector(1, i3), .{
                -0x3,
            }, .{
                -0x1,
            });
            try testArgs(@Vector(2, i3), .{
                0x2, -0x3,
            }, .{
                0x1, 0x3,
            });
            try testArgs(@Vector(4, i3), .{
                0x1, -0x4, -0x2, -0x3,
            }, .{
                -0x2, -0x4, 0x2, 0x2,
            });
            try testArgs(@Vector(8, i3), .{
                0x0, 0x1, 0x3, 0x1, -0x3, 0x1, 0x3, 0x3,
            }, .{
                -0x3, 0x2, 0x1, 0x1, -0x4, -0x1, 0x3, -0x2,
            });
            try testArgs(@Vector(16, i3), .{
                -0x4, 0x3, -0x2, 0x0, -0x2, -0x1, 0x2, -0x4, 0x1, -0x3, 0x2, -0x2, 0x1, -0x2, 0x2, -0x4,
            }, .{
                0x2, -0x3, 0x3, 0x1, -0x4, 0x1, -0x1, 0x1, -0x1, -0x3, -0x4, 0x2, 0x3, 0x3, -0x1, -0x4,
            });
            try testArgs(@Vector(32, i3), .{
                0x1,  -0x3, -0x1, -0x3, -0x3, 0x2, 0x1, 0x0, 0x0, -0x1, 0x3,  -0x2, 0x3,  0x0, -0x3, 0x0,
                -0x4, -0x2, -0x1, -0x4, -0x4, 0x2, 0x2, 0x3, 0x1, 0x2,  -0x4, -0x4, -0x3, 0x1, -0x1, -0x2,
            }, .{
                -0x4, -0x2, 0x1, -0x1, 0x3,  0x1, 0x2,  -0x3, 0x2, -0x2, 0x1, -0x1, -0x2, -0x1, -0x1, -0x2,
                -0x2, -0x3, 0x3, -0x3, -0x4, 0x1, -0x3, 0x3,  0x1, -0x3, 0x3, 0x3,  -0x4, 0x3,  0x2,  -0x2,
            });
            try testArgs(@Vector(64, i3), .{
                0x1,  0x2,  0x1,  0x2,  -0x2, 0x2,  0x2,  -0x1, -0x4, 0x1,  0x3,  0x0,  -0x2, -0x2, 0x2,  -0x2,
                0x0,  -0x4, -0x3, -0x4, -0x1, -0x1, 0x2,  0x2,  -0x2, -0x1, -0x1, 0x3,  0x3,  -0x4, 0x2,  0x0,
                0x3,  0x2,  -0x4, -0x1, 0x1,  0x1,  0x3,  0x1,  0x2,  0x3,  -0x3, 0x1,  -0x4, -0x2, 0x1,  -0x3,
                -0x3, -0x1, 0x1,  -0x3, -0x1, 0x3,  -0x4, -0x4, 0x0,  0x0,  -0x4, -0x2, 0x3,  -0x1, -0x3, -0x3,
            }, .{
                0x3,  -0x2, 0x1,  -0x4, 0x1,  0x3,  -0x3, 0x1,  0x3,  0x1,  0x1,  -0x1, -0x2, 0x1,  -0x3, 0x1,
                -0x2, -0x2, 0x3,  -0x3, -0x1, -0x3, 0x1,  -0x1, -0x3, -0x3, 0x1,  -0x2, 0x1,  -0x2, 0x1,  0x2,
                0x3,  -0x4, -0x4, -0x1, 0x1,  0x3,  0x1,  0x1,  -0x4, 0x2,  -0x3, 0x3,  0x3,  -0x1, 0x1,  -0x1,
                -0x2, 0x2,  0x2,  -0x4, -0x4, 0x3,  -0x2, -0x4, -0x1, -0x2, -0x4, 0x1,  0x2,  0x1,  -0x1, -0x2,
            });
            try testArgs(@Vector(128, i3), .{
                -0x4, 0x1,  0x0,  -0x4, -0x4, 0x1,  -0x4, -0x2, 0x2,  0x2,  -0x3, 0x1,  0x2,  -0x2, 0x1,  0x1,
                0x3,  0x0,  0x3,  -0x4, -0x1, 0x3,  0x3,  -0x4, 0x0,  -0x3, 0x2,  -0x2, 0x0,  0x3,  0x1,  -0x2,
                -0x1, -0x1, 0x3,  -0x1, -0x2, 0x3,  0x3,  0x1,  -0x3, 0x1,  -0x1, -0x2, -0x4, 0x2,  -0x2, -0x1,
                0x1,  0x1,  0x1,  0x0,  -0x1, 0x2,  -0x1, 0x3,  0x2,  -0x1, -0x2, 0x3,  -0x2, 0x3,  0x3,  0x1,
                0x3,  -0x3, -0x4, -0x1, 0x2,  0x2,  -0x2, 0x3,  -0x4, -0x2, -0x1, 0x0,  0x1,  -0x1, 0x0,  0x0,
                -0x2, 0x3,  0x0,  -0x3, -0x4, 0x2,  -0x3, -0x2, -0x4, 0x0,  -0x3, -0x4, -0x4, -0x2, -0x1, -0x3,
                0x0,  -0x1, 0x0,  -0x1, 0x2,  -0x4, -0x3, 0x0,  -0x4, 0x0,  -0x2, 0x1,  -0x2, -0x4, -0x1, -0x1,
                -0x3, 0x3,  -0x1, -0x1, -0x2, 0x1,  0x3,  0x1,  -0x3, 0x1,  -0x4, -0x2, 0x0,  -0x1, -0x2, 0x2,
            }, .{
                -0x3, 0x2,  -0x3, 0x1,  -0x2, -0x1, -0x3, 0x1,  0x2,  0x2,  -0x2, 0x2,  0x2,  0x1,  0x3,  -0x1,
                -0x4, -0x3, 0x2,  -0x3, -0x2, 0x3,  -0x3, 0x2,  -0x1, -0x3, 0x1,  0x2,  -0x4, 0x2,  -0x2, -0x3,
                0x1,  -0x1, 0x2,  0x2,  -0x1, -0x3, -0x4, 0x2,  0x1,  -0x4, 0x1,  -0x4, 0x2,  -0x1, 0x2,  -0x2,
                0x2,  0x1,  -0x4, 0x3,  0x1,  -0x2, -0x3, -0x4, 0x3,  -0x1, 0x3,  -0x4, -0x2, 0x1,  -0x2, 0x3,
                0x1,  0x1,  0x2,  0x1,  -0x1, -0x2, 0x2,  -0x1, 0x1,  -0x1, -0x3, -0x1, 0x1,  -0x4, -0x1, -0x1,
                -0x3, -0x1, -0x4, 0x3,  0x1,  -0x1, -0x1, -0x1, 0x1,  -0x4, 0x1,  -0x2, -0x4, 0x2,  -0x4, -0x3,
                0x2,  -0x4, -0x1, 0x1,  0x3,  0x2,  -0x1, 0x3,  0x2,  0x2,  0x1,  -0x4, -0x3, 0x1,  -0x1, 0x1,
                -0x2, -0x4, 0x1,  0x3,  -0x1, 0x3,  0x1,  0x2,  -0x4, 0x2,  0x2,  -0x3, -0x3, -0x4, -0x2, 0x3,
            });

            try testArgs(@Vector(1, u3), .{
                0x5,
            }, .{
                0x2,
            });
            try testArgs(@Vector(2, u3), .{
                0x4, 0x5,
            }, .{
                0x2, 0x4,
            });
            try testArgs(@Vector(4, u3), .{
                0x7, 0x7, 0x2, 0x3,
            }, .{
                0x4, 0x5, 0x7, 0x1,
            });
            try testArgs(@Vector(8, u3), .{
                0x1, 0x5, 0x3, 0x7, 0x2, 0x5, 0x4, 0x7,
            }, .{
                0x5, 0x2, 0x3, 0x5, 0x5, 0x1, 0x3, 0x1,
            });
            try testArgs(@Vector(16, u3), .{
                0x6, 0x5, 0x7, 0x4, 0x7, 0x2, 0x2, 0x3, 0x7, 0x6, 0x6, 0x5, 0x6, 0x4, 0x7, 0x5,
            }, .{
                0x6, 0x3, 0x5, 0x7, 0x4, 0x4, 0x4, 0x4, 0x6, 0x5, 0x3, 0x7, 0x4, 0x3, 0x3, 0x2,
            });
            try testArgs(@Vector(32, u3), .{
                0x0, 0x6, 0x4, 0x3, 0x2, 0x4, 0x7, 0x5, 0x7, 0x5, 0x0, 0x6, 0x7, 0x2, 0x2, 0x2,
                0x6, 0x2, 0x6, 0x5, 0x2, 0x3, 0x1, 0x0, 0x7, 0x1, 0x7, 0x0, 0x3, 0x1, 0x6, 0x2,
            }, .{
                0x2, 0x5, 0x3, 0x2, 0x2, 0x2, 0x5, 0x4, 0x4, 0x1, 0x7, 0x2, 0x2, 0x2, 0x5, 0x1,
                0x2, 0x4, 0x3, 0x5, 0x5, 0x1, 0x5, 0x4, 0x7, 0x5, 0x4, 0x3, 0x1, 0x7, 0x5, 0x6,
            });
            try testArgs(@Vector(64, u3), .{
                0x2, 0x3, 0x1, 0x0, 0x5, 0x6, 0x1, 0x2, 0x2, 0x3, 0x1, 0x1, 0x5, 0x2, 0x2, 0x5,
                0x0, 0x0, 0x1, 0x1, 0x0, 0x6, 0x5, 0x2, 0x7, 0x3, 0x1, 0x1, 0x1, 0x0, 0x4, 0x7,
                0x2, 0x6, 0x4, 0x0, 0x1, 0x1, 0x6, 0x5, 0x2, 0x0, 0x3, 0x4, 0x1, 0x4, 0x5, 0x2,
                0x7, 0x4, 0x6, 0x6, 0x0, 0x2, 0x6, 0x2, 0x4, 0x6, 0x6, 0x5, 0x7, 0x0, 0x3, 0x6,
            }, .{
                0x7, 0x3, 0x3, 0x2, 0x6, 0x4, 0x3, 0x3, 0x7, 0x2, 0x3, 0x4, 0x7, 0x5, 0x2, 0x4,
                0x6, 0x3, 0x6, 0x1, 0x7, 0x4, 0x1, 0x6, 0x7, 0x3, 0x1, 0x3, 0x6, 0x6, 0x5, 0x5,
                0x2, 0x5, 0x7, 0x7, 0x4, 0x2, 0x2, 0x7, 0x4, 0x6, 0x6, 0x6, 0x4, 0x6, 0x2, 0x4,
                0x3, 0x2, 0x2, 0x1, 0x7, 0x7, 0x4, 0x4, 0x2, 0x4, 0x7, 0x6, 0x7, 0x2, 0x2, 0x3,
            });
            try testArgs(@Vector(128, u3), .{
                0x5, 0x2, 0x5, 0x4, 0x6, 0x0, 0x7, 0x2, 0x0, 0x6, 0x7, 0x4, 0x6, 0x4, 0x2, 0x6,
                0x7, 0x3, 0x5, 0x6, 0x4, 0x5, 0x3, 0x0, 0x1, 0x5, 0x2, 0x0, 0x7, 0x2, 0x7, 0x5,
                0x4, 0x6, 0x5, 0x4, 0x4, 0x3, 0x5, 0x7, 0x0, 0x2, 0x0, 0x6, 0x6, 0x1, 0x3, 0x3,
                0x3, 0x7, 0x3, 0x3, 0x1, 0x0, 0x5, 0x3, 0x0, 0x0, 0x5, 0x5, 0x2, 0x4, 0x7, 0x4,
                0x4, 0x1, 0x5, 0x0, 0x3, 0x2, 0x1, 0x3, 0x7, 0x3, 0x1, 0x4, 0x3, 0x1, 0x3, 0x2,
                0x5, 0x7, 0x7, 0x2, 0x3, 0x7, 0x1, 0x1, 0x0, 0x7, 0x2, 0x5, 0x7, 0x0, 0x1, 0x4,
                0x5, 0x6, 0x0, 0x1, 0x1, 0x4, 0x7, 0x5, 0x2, 0x3, 0x7, 0x7, 0x1, 0x3, 0x6, 0x4,
                0x6, 0x0, 0x1, 0x0, 0x3, 0x7, 0x5, 0x4, 0x7, 0x4, 0x6, 0x5, 0x6, 0x6, 0x7, 0x4,
            }, .{
                0x5, 0x7, 0x5, 0x1, 0x7, 0x1, 0x3, 0x5, 0x1, 0x4, 0x3, 0x2, 0x5, 0x5, 0x2, 0x1,
                0x4, 0x2, 0x2, 0x2, 0x5, 0x7, 0x1, 0x6, 0x2, 0x5, 0x2, 0x7, 0x2, 0x7, 0x4, 0x4,
                0x1, 0x5, 0x4, 0x3, 0x2, 0x1, 0x1, 0x6, 0x3, 0x4, 0x7, 0x2, 0x7, 0x4, 0x1, 0x4,
                0x3, 0x5, 0x3, 0x4, 0x6, 0x3, 0x7, 0x6, 0x6, 0x1, 0x7, 0x6, 0x3, 0x3, 0x5, 0x5,
                0x7, 0x1, 0x1, 0x3, 0x3, 0x3, 0x1, 0x1, 0x1, 0x2, 0x6, 0x5, 0x3, 0x7, 0x1, 0x1,
                0x5, 0x3, 0x1, 0x2, 0x7, 0x2, 0x5, 0x6, 0x4, 0x7, 0x3, 0x6, 0x5, 0x4, 0x3, 0x3,
                0x5, 0x3, 0x7, 0x2, 0x3, 0x3, 0x7, 0x3, 0x1, 0x5, 0x3, 0x4, 0x7, 0x7, 0x5, 0x7,
                0x1, 0x1, 0x2, 0x7, 0x2, 0x5, 0x1, 0x6, 0x4, 0x6, 0x1, 0x6, 0x5, 0x1, 0x2, 0x1,
            });

            try testArgs(@Vector(1, i4), .{
                0x2,
            }, .{
                0x1,
            });
            try testArgs(@Vector(2, i4), .{
                -0x2, 0x5,
            }, .{
                -0x1, 0x2,
            });
            try testArgs(@Vector(4, i4), .{
                -0x8, 0x5, 0x5, -0x2,
            }, .{
                -0x3, -0x7, -0x4, -0x5,
            });
            try testArgs(@Vector(8, i4), .{
                0x7, 0x3, 0x2, -0x1, -0x8, -0x2, 0x7, 0x1,
            }, .{
                -0x2, 0x4, -0x8, 0x7, 0x1, -0x5, 0x6, -0x7,
            });
            try testArgs(@Vector(16, i4), .{
                0x6, -0x3, 0x6, 0x6, -0x5, 0x6, 0x3, 0x7, -0x6, 0x7, -0x7, 0x6, -0x2, -0x2, -0x5, 0x0,
            }, .{
                0x2, -0x3, -0x4, -0x5, 0x3, 0x3, -0x5, 0x5, 0x4, -0x1, -0x6, 0x4, 0x7, -0x2, 0x3, 0x2,
            });
            try testArgs(@Vector(32, i4), .{
                -0x1, -0x4, 0x6,  0x6, 0x5,  0x3,  0x4, 0x0, 0x3, 0x7,  -0x6, 0x7, -0x2, -0x7, -0x4, 0x6,
                0x3,  -0x7, -0x5, 0x1, -0x7, -0x6, 0x1, 0x3, 0x7, -0x8, -0x5, 0x6, -0x5, 0x0,  0x0,  -0x8,
            }, .{
                -0x4, -0x4, -0x4, 0x4,  -0x5, 0x3, -0x1, 0x6,  0x1,  -0x3, -0x1, 0x6,  0x5,  -0x8, 0x1, -0x4,
                -0x1, -0x4, 0x1,  -0x3, 0x4,  0x6, -0x3, -0x8, -0x7, -0x4, 0x2,  -0x3, -0x1, -0x2, 0x6, -0x6,
            });
            try testArgs(@Vector(64, i4), .{
                0x0,  -0x3, -0x3, 0x5,  0x2,  -0x1, 0x4,  0x5,  0x6,  -0x2, 0x1,  0x5,  -0x3, -0x1, -0x2, -0x1,
                -0x8, 0x2,  -0x1, -0x2, 0x7,  -0x3, -0x2, -0x3, 0x1,  -0x5, 0x5,  0x2,  -0x1, -0x6, -0x2, -0x1,
                -0x2, -0x5, 0x0,  0x6,  0x3,  -0x4, -0x5, -0x5, -0x4, -0x7, -0x4, 0x1,  0x0,  -0x6, -0x7, -0x6,
                0x1,  -0x6, 0x4,  -0x4, -0x2, 0x6,  -0x7, 0x4,  0x4,  0x5,  0x3,  -0x6, -0x8, -0x5, 0x5,  -0x7,
            }, .{
                -0x1, -0x5, 0x5,  -0x2, 0x6,  -0x6, -0x4, -0x5, -0x4, 0x7,  -0x6, 0x7,  0x4,  -0x5, 0x5,  0x7,
                -0x6, 0x3,  -0x4, 0x2,  -0x8, 0x4,  -0x2, 0x5,  -0x5, -0x5, -0x8, 0x3,  -0x1, -0x4, -0x8, -0x2,
                -0x2, 0x5,  -0x7, -0x3, 0x2,  -0x5, -0x6, -0x7, -0x8, -0x2, 0x5,  -0x3, 0x2,  -0x1, -0x7, -0x4,
                -0x3, -0x3, 0x6,  -0x8, 0x3,  -0x4, 0x7,  0x3,  -0x2, 0x7,  -0x1, 0x1,  0x1,  0x6,  -0x2, -0x2,
            });
            try testArgs(@Vector(128, i4), .{
                -0x1, -0x3, -0x3, -0x4, 0x3, -0x4, 0x0,  -0x4, 0x7,  0x3,  0x5,  -0x4, -0x5, -0x4, -0x2, -0x7,
                0x2,  0x0,  -0x4, 0x7,  0x3, -0x5, 0x4,  0x5,  -0x2, -0x3, -0x4, 0x6,  -0x7, -0x1, 0x1,  -0x6,
                0x1,  0x5,  0x2,  0x5,  0x2, 0x2,  -0x4, -0x4, 0x5,  0x2,  -0x2, -0x8, -0x1, -0x2, 0x5,  0x3,
                0x0,  -0x5, 0x5,  0x7,  0x6, -0x3, -0x2, 0x0,  -0x7, -0x7, -0x4, 0x2,  -0x4, 0x7,  0x1,  -0x5,
                -0x4, -0x8, 0x2,  -0x7, 0x3, -0x4, 0x7,  0x6,  -0x7, -0x3, -0x7, 0x2,  0x4,  0x2,  -0x5, -0x6,
                0x3,  0x5,  0x1,  0x6,  0x5, 0x7,  0x7,  -0x4, -0x7, -0x1, 0x0,  -0x7, 0x6,  0x0,  0x6,  0x0,
                0x0,  -0x5, -0x1, -0x8, 0x7, -0x6, -0x5, -0x2, -0x4, 0x1,  0x1,  -0x8, 0x2,  0x6,  -0x1, -0x3,
                -0x6, 0x5,  -0x8, 0x3,  0x3, 0x1,  -0x1, -0x3, -0x3, -0x6, 0x7,  -0x6, -0x8, 0x1,  -0x7, -0x8,
            }, .{
                0x1,  0x3,  0x1,  0x3,  -0x6, 0x6,  0x2,  -0x3, 0x1,  -0x7, 0x7,  -0x3, -0x1, -0x1, 0x7,  0x2,
                -0x8, 0x2,  -0x3, -0x4, 0x4,  -0x4, 0x7,  0x6,  -0x5, -0x2, -0x1, 0x6,  -0x7, 0x4,  0x7,  -0x3,
                -0x5, -0x8, -0x5, -0x6, -0x6, 0x2,  0x1,  -0x8, 0x4,  0x3,  -0x5, 0x7,  -0x8, 0x3,  -0x1, 0x7,
                -0x3, 0x7,  -0x3, -0x2, -0x6, 0x4,  0x2,  -0x2, -0x2, -0x7, 0x5,  -0x1, -0x6, 0x7,  -0x5, 0x5,
                0x4,  0x5,  -0x8, -0x5, 0x6,  0x1,  -0x5, 0x7,  -0x6, -0x3, -0x4, 0x6,  -0x8, 0x7,  0x7,  -0x6,
                0x6,  -0x4, 0x2,  -0x8, -0x8, -0x4, -0x8, -0x3, 0x6,  0x5,  0x7,  -0x6, 0x1,  0x2,  -0x7, -0x3,
                -0x3, 0x1,  -0x3, 0x3,  -0x1, 0x3,  -0x7, -0x8, 0x1,  -0x3, -0x3, -0x3, -0x4, 0x5,  0x7,  -0x7,
                0x3,  0x2,  0x6,  -0x2, -0x4, -0x3, -0x1, 0x5,  -0x6, 0x2,  0x3,  -0x5, 0x5,  -0x3, -0x2, -0x8,
            });

            try testArgs(@Vector(1, u4), .{
                0x2,
            }, .{
                0xa,
            });
            try testArgs(@Vector(2, u4), .{
                0x0, 0xa,
            }, .{
                0xb, 0xa,
            });
            try testArgs(@Vector(4, u4), .{
                0xb, 0x7, 0x0, 0xd,
            }, .{
                0x4, 0x5, 0xf, 0x3,
            });
            try testArgs(@Vector(8, u4), .{
                0x9, 0xf, 0x0, 0x5, 0x4, 0x9, 0x3, 0x7,
            }, .{
                0xc, 0x6, 0x8, 0x8, 0x9, 0x8, 0x9, 0x2,
            });
            try testArgs(@Vector(16, u4), .{
                0x0, 0xb, 0xd, 0x2, 0x8, 0xa, 0x6, 0x7, 0xa, 0xf, 0xf, 0x4, 0x9, 0x9, 0x9, 0xf,
            }, .{
                0xd, 0x1, 0xf, 0x8, 0xb, 0xa, 0xe, 0x4, 0x5, 0x3, 0xd, 0x4, 0x1, 0xd, 0xd, 0xe,
            });
            try testArgs(@Vector(32, u4), .{
                0x3, 0xc, 0x5, 0x1, 0xa, 0x6, 0x7, 0xe, 0x5, 0x8, 0x5, 0x6, 0xe, 0x0, 0xe, 0x6,
                0x9, 0x5, 0x3, 0x6, 0xd, 0xe, 0x9, 0x4, 0xf, 0x1, 0x1, 0x5, 0x0, 0x2, 0xa, 0x0,
            }, .{
                0xd, 0x8, 0x7, 0xe, 0xa, 0x2, 0x5, 0x8, 0x5, 0x1, 0xa, 0x8, 0x1, 0x8, 0xb, 0x3,
                0xb, 0xe, 0x5, 0xf, 0xb, 0x8, 0xd, 0x7, 0x6, 0x4, 0x7, 0x5, 0x5, 0x7, 0xf, 0x6,
            });
            try testArgs(@Vector(64, u4), .{
                0x5, 0xd, 0x0, 0xd, 0x1, 0xb, 0xb, 0xe, 0xb, 0x7, 0xa, 0xc, 0xb, 0xe, 0x8, 0x9,
                0x1, 0xb, 0x9, 0x5, 0xa, 0x6, 0xc, 0x5, 0x1, 0xe, 0x5, 0xb, 0x2, 0x8, 0x1, 0x4,
                0x2, 0x6, 0x5, 0x1, 0x0, 0x5, 0xa, 0x5, 0xf, 0xf, 0x0, 0xb, 0x5, 0x4, 0xf, 0xb,
                0x6, 0x0, 0xb, 0x4, 0x7, 0x8, 0xd, 0xf, 0xc, 0xc, 0x1, 0xe, 0x0, 0xb, 0xa, 0xd,
            }, .{
                0xc, 0x5, 0xb, 0x3, 0x1, 0x5, 0xb, 0x1, 0x2, 0x1, 0x8, 0x4, 0xe, 0x1, 0xa, 0x7,
                0x2, 0x9, 0x4, 0xd, 0xa, 0x5, 0x4, 0xe, 0x1, 0x4, 0xb, 0x2, 0x9, 0x7, 0x4, 0x2,
                0x7, 0xd, 0x7, 0xb, 0xb, 0xf, 0xc, 0x5, 0xe, 0xf, 0x4, 0x8, 0x9, 0x5, 0x3, 0x6,
                0x8, 0x4, 0x2, 0x5, 0x8, 0x2, 0x3, 0x5, 0x4, 0xf, 0x5, 0x9, 0x4, 0x8, 0x9, 0x8,
            });
            try testArgs(@Vector(128, u4), .{
                0xe, 0x0, 0xa, 0xa, 0xf, 0x3, 0x3, 0x9, 0xe, 0x2, 0x7, 0x2, 0xf, 0x7, 0xf, 0x6,
                0xa, 0x8, 0x0, 0x5, 0x6, 0x4, 0xf, 0x6, 0x5, 0xd, 0x0, 0xc, 0x3, 0xe, 0x3, 0x3,
                0x5, 0x4, 0x8, 0x8, 0xb, 0x0, 0x7, 0x3, 0x8, 0xa, 0x8, 0x0, 0x8, 0x4, 0x7, 0x4,
                0x9, 0x6, 0xa, 0x2, 0xe, 0x2, 0x0, 0x1, 0xe, 0xf, 0x9, 0x0, 0x9, 0x4, 0xb, 0xa,
                0x1, 0x7, 0xf, 0xd, 0x6, 0x6, 0x2, 0x2, 0x1, 0xd, 0xe, 0x7, 0x5, 0xd, 0x9, 0x7,
                0xd, 0xc, 0xc, 0x0, 0xa, 0xc, 0x1, 0xa, 0x5, 0x3, 0xf, 0xc, 0xf, 0x7, 0x1, 0xc,
                0xa, 0x4, 0x3, 0xa, 0xc, 0x8, 0x2, 0xc, 0xf, 0x7, 0x3, 0x7, 0xf, 0x0, 0x0, 0x8,
                0x7, 0x3, 0x4, 0x9, 0xb, 0xc, 0x5, 0x0, 0x1, 0x2, 0xa, 0x7, 0x9, 0x1, 0x3, 0x1,
            }, .{
                0xb, 0x1, 0x9, 0x3, 0x4, 0xb, 0xb, 0x4, 0xb, 0x7, 0x2, 0x7, 0x4, 0x5, 0x1, 0x4,
                0x5, 0xa, 0xb, 0x4, 0x4, 0x2, 0xa, 0xb, 0xe, 0x4, 0x7, 0xb, 0xb, 0x4, 0x1, 0x6,
                0xd, 0x3, 0xc, 0x7, 0x8, 0x1, 0x7, 0x6, 0xf, 0x9, 0x8, 0x4, 0x5, 0x2, 0x6, 0xe,
                0xb, 0xd, 0x4, 0x6, 0x5, 0xb, 0x2, 0x8, 0x7, 0x2, 0xf, 0xe, 0x9, 0xe, 0xa, 0x5,
                0x6, 0xc, 0xb, 0x1, 0x8, 0xc, 0xd, 0x3, 0x1, 0x4, 0x4, 0xf, 0x4, 0x3, 0x5, 0x7,
                0xf, 0x3, 0x5, 0xf, 0xe, 0x2, 0xd, 0x7, 0x6, 0x2, 0x4, 0xd, 0xd, 0xa, 0x1, 0xa,
                0xb, 0xa, 0xa, 0x2, 0x4, 0x9, 0x8, 0xa, 0xe, 0xb, 0xf, 0xf, 0x6, 0x4, 0x9, 0x8,
                0x9, 0x6, 0x4, 0x5, 0xf, 0xe, 0x8, 0x5, 0x2, 0x5, 0xf, 0xb, 0xf, 0x4, 0x6, 0x4,
            });

            try testArgs(@Vector(1, i5), .{
                0x03,
            }, .{
                0x0a,
            });
            try testArgs(@Vector(2, i5), .{
                0x0c, -0x0e,
            }, .{
                -0x0f, -0x0e,
            });
            try testArgs(@Vector(4, i5), .{
                -0x0a, 0x06, -0x05, 0x09,
            }, .{
                -0x0f, 0x05, 0x05, 0x09,
            });
            try testArgs(@Vector(8, i5), .{
                -0x04, -0x04, 0x05, -0x05, 0x0f, -0x0e, 0x0f, -0x0e,
            }, .{
                -0x09, -0x0d, 0x02, 0x01, 0x08, -0x05, -0x09, -0x03,
            });
            try testArgs(@Vector(16, i5), .{
                -0x0e, -0x08, -0x10, -0x0b, -0x10, -0x09, -0x0f, -0x05, -0x10, 0x06, 0x0d, -0x04, 0x09, -0x0e, -0x10, -0x10,
            }, .{
                0x03, 0x0b, 0x0c, 0x06, -0x0d, 0x0e, -0x09, -0x04, 0x0a, -0x0e, -0x0d, 0x0f, -0x09, -0x0e, -0x0b, 0x03,
            });
            try testArgs(@Vector(32, i5), .{
                -0x08, -0x05, 0x09,  -0x08, 0x01, 0x0e, -0x0c, 0x0b, -0x0e, 0x0f,  -0x0b, 0x01, -0x03, 0x03, 0x08,  0x04,
                0x02,  0x0f,  -0x0b, -0x0b, 0x0d, 0x00, 0x09,  0x00, -0x06, -0x08, -0x01, 0x0b, 0x05,  0x03, -0x05, -0x07,
            }, .{
                -0x0c, 0x07,  0x0d,  -0x09, 0x0a,  0x06,  -0x0b, -0x07, -0x0a, 0x08,  0x07,  -0x0d, 0x08,  0x07,  0x09,  -0x07,
                0x0b,  -0x02, -0x02, -0x02, -0x06, -0x08, 0x0a,  -0x0a, 0x02,  -0x07, -0x0a, 0x0d,  -0x07, -0x05, -0x0e, 0x05,
            });
            try testArgs(@Vector(64, i5), .{
                0x04,  -0x0d, 0x0d,  -0x01, 0x07,  0x0c,  0x00, 0x01,  -0x07, 0x0a,  -0x01, -0x01, 0x08,  -0x0b, -0x03, -0x06,
                -0x03, -0x03, -0x0c, 0x0e,  -0x0c, -0x02, 0x07, -0x03, 0x0e,  -0x0a, -0x0e, -0x06, -0x08, 0x0a,  -0x0c, -0x0c,
                0x06,  -0x04, 0x04,  0x00,  0x05,  0x07,  0x04, 0x06,  -0x01, 0x0a,  0x07,  -0x08, 0x00,  0x0f,  0x0f,  0x0d,
                -0x07, 0x0f,  0x05,  -0x0b, -0x08, -0x0c, 0x0d, -0x05, -0x05, 0x0e,  0x02,  0x06,  0x0d,  0x06,  0x00,  0x0a,
            }, .{
                0x02,  -0x09, -0x01, -0x10, -0x0c, -0x0f, -0x10, -0x0d, 0x02,  0x0e, 0x07,  -0x01, -0x0a, -0x0b, 0x05,  -0x0e,
                -0x09, 0x03,  0x08,  -0x0d, 0x0d,  0x03,  -0x02, 0x0e,  0x0c,  0x03, 0x0b,  -0x0d, -0x04, -0x10, 0x0e,  0x0d,
                0x09,  -0x03, -0x0e, -0x03, -0x05, -0x0c, -0x07, 0x08,  -0x06, 0x08, -0x0e, 0x02,  -0x10, 0x01,  0x01,  -0x0a,
                0x01,  -0x09, 0x03,  -0x01, 0x05,  0x09,  0x06,  -0x03, -0x0a, 0x08, -0x0e, 0x0e,  0x07,  -0x05, -0x0c, -0x10,
            });
            try testArgs(@Vector(128, i5), .{
                0x01,  0x0b,  -0x01, -0x10, -0x05, 0x05,  -0x09, 0x0e,  -0x0e, 0x04,  0x0f,  -0x06, 0x0f,  0x04,  -0x02, 0x0a,
                -0x08, -0x06, 0x08,  -0x07, -0x08, 0x0e,  0x06,  0x0d,  -0x07, -0x04, 0x04,  -0x0b, 0x02,  -0x06, 0x07,  -0x10,
                0x0d,  0x09,  0x0b,  -0x04, 0x0e,  -0x06, -0x0a, 0x01,  0x06,  0x08,  0x01,  -0x0b, -0x09, -0x08, -0x0c, -0x0b,
                0x07,  0x06,  0x0d,  0x0c,  -0x0b, -0x03, -0x06, -0x0c, -0x0e, 0x05,  0x0b,  0x08,  -0x01, 0x00,  0x01,  0x0a,
                0x00,  0x0a,  0x06,  0x06,  -0x10, -0x05, -0x05, -0x0f, 0x02,  -0x06, -0x08, -0x08, 0x0f,  0x09,  -0x07, -0x05,
                0x07,  0x06,  0x03,  0x05,  0x02,  0x0f,  0x0d,  -0x0e, -0x03, -0x01, -0x06, -0x02, -0x01, -0x07, 0x09,  0x05,
                -0x07, -0x07, -0x08, 0x0c,  -0x0e, 0x09,  -0x0c, -0x0d, 0x07,  0x04,  0x07,  -0x03, 0x09,  0x0e,  0x04,  0x02,
                0x0f,  -0x02, -0x10, -0x03, -0x0d, -0x04, 0x0c,  -0x06, -0x01, -0x0e, -0x0e, -0x0a, 0x0d,  -0x0e, 0x04,  0x03,
            }, .{
                -0x08, -0x09, -0x04, 0x0f,  -0x0f, -0x08, -0x04, 0x0b,  0x09,  -0x0b, -0x02, 0x0f,  0x01,  -0x01, -0x0a, -0x0a,
                0x08,  0x09,  0x0d,  -0x06, 0x0f,  -0x02, 0x0c,  0x01,  0x0c,  0x02,  -0x04, 0x0b,  0x05,  0x02,  -0x08, -0x09,
                0x01,  0x0f,  -0x0b, 0x02,  -0x06, 0x08,  -0x0e, -0x02, -0x0b, -0x03, -0x01, 0x0c,  0x09,  -0x04, 0x08,  -0x0a,
                0x09,  -0x05, 0x08,  0x0e,  0x05,  0x03,  -0x0a, 0x0d,  -0x03, 0x06,  0x0f,  -0x09, 0x0a,  0x03,  0x02,  0x0c,
                0x08,  -0x0a, 0x06,  0x0e,  0x08,  0x02,  0x08,  -0x04, -0x0d, -0x02, -0x08, -0x0a, 0x0a,  0x0c,  -0x03, 0x04,
                0x0b,  -0x0c, -0x0e, 0x01,  0x07,  -0x01, 0x09,  0x0f,  -0x06, -0x05, -0x0e, -0x01, -0x04, 0x0a,  -0x0a, -0x0d,
                -0x10, -0x10, -0x03, -0x0f, -0x0c, -0x0a, -0x0b, -0x06, -0x04, -0x0f, -0x0b, -0x08, 0x0e,  0x04,  -0x01, -0x0b,
                -0x06, 0x0a,  0x0a,  -0x0c, -0x0c, 0x0b,  -0x02, 0x0c,  -0x04, -0x06, -0x0c, -0x09, -0x09, -0x0b, -0x0c, -0x0b,
            });

            try testArgs(@Vector(1, u5), .{
                0x0a,
            }, .{
                0x1c,
            });
            try testArgs(@Vector(2, u5), .{
                0x01, 0x07,
            }, .{
                0x03, 0x1d,
            });
            try testArgs(@Vector(4, u5), .{
                0x1c, 0x0d, 0x1f, 0x0a,
            }, .{
                0x14, 0x03, 0x07, 0x02,
            });
            try testArgs(@Vector(8, u5), .{
                0x00, 0x0c, 0x1f, 0x01, 0x12, 0x14, 0x12, 0x10,
            }, .{
                0x0c, 0x14, 0x05, 0x1a, 0x04, 0x17, 0x06, 0x1a,
            });
            try testArgs(@Vector(16, u5), .{
                0x1e, 0x17, 0x03, 0x16, 0x1f, 0x10, 0x00, 0x05, 0x19, 0x10, 0x18, 0x0d, 0x0f, 0x1b, 0x1e, 0x05,
            }, .{
                0x18, 0x13, 0x14, 0x12, 0x10, 0x11, 0x18, 0x0c, 0x03, 0x02, 0x11, 0x03, 0x17, 0x0c, 0x19, 0x05,
            });
            try testArgs(@Vector(32, u5), .{
                0x1a, 0x10, 0x16, 0x1f, 0x08, 0x07, 0x1a, 0x04, 0x05, 0x16, 0x07, 0x09, 0x09, 0x03, 0x0f, 0x00,
                0x03, 0x05, 0x1c, 0x00, 0x07, 0x16, 0x17, 0x1b, 0x0b, 0x01, 0x0e, 0x08, 0x15, 0x12, 0x04, 0x16,
            }, .{
                0x02, 0x14, 0x09, 0x17, 0x0c, 0x10, 0x1a, 0x1e, 0x14, 0x06, 0x03, 0x1b, 0x1d, 0x1f, 0x18, 0x0b,
                0x16, 0x1b, 0x11, 0x14, 0x0d, 0x18, 0x05, 0x18, 0x16, 0x1a, 0x14, 0x04, 0x14, 0x1a, 0x0c, 0x1e,
            });
            try testArgs(@Vector(64, u5), .{
                0x0c, 0x09, 0x0c, 0x05, 0x0e, 0x08, 0x0b, 0x07, 0x18, 0x05, 0x0a, 0x1e, 0x06, 0x14, 0x0d, 0x03,
                0x0c, 0x0d, 0x00, 0x10, 0x0f, 0x05, 0x12, 0x0e, 0x0c, 0x1c, 0x16, 0x11, 0x14, 0x0b, 0x16, 0x06,
                0x1e, 0x07, 0x00, 0x13, 0x09, 0x13, 0x1b, 0x03, 0x12, 0x1c, 0x0b, 0x04, 0x18, 0x0a, 0x18, 0x16,
                0x16, 0x0a, 0x11, 0x19, 0x00, 0x1d, 0x08, 0x06, 0x0a, 0x1e, 0x09, 0x1d, 0x18, 0x1e, 0x06, 0x1b,
            }, .{
                0x0d, 0x10, 0x05, 0x18, 0x10, 0x0a, 0x06, 0x03, 0x1c, 0x10, 0x1c, 0x1e, 0x19, 0x1c, 0x04, 0x03,
                0x0a, 0x1d, 0x1f, 0x10, 0x0e, 0x04, 0x0c, 0x18, 0x14, 0x05, 0x11, 0x19, 0x19, 0x14, 0x10, 0x06,
                0x0b, 0x16, 0x0f, 0x01, 0x12, 0x0c, 0x1b, 0x03, 0x19, 0x0d, 0x12, 0x15, 0x15, 0x11, 0x16, 0x1f,
                0x03, 0x11, 0x06, 0x11, 0x1d, 0x16, 0x0c, 0x17, 0x19, 0x1a, 0x06, 0x16, 0x13, 0x0a, 0x09, 0x1c,
            });
            try testArgs(@Vector(128, u5), .{
                0x09, 0x16, 0x11, 0x1e, 0x17, 0x13, 0x1d, 0x14, 0x07, 0x15, 0x1c, 0x0b, 0x08, 0x19, 0x01, 0x0b,
                0x1b, 0x19, 0x00, 0x0c, 0x0c, 0x0a, 0x10, 0x08, 0x1a, 0x1c, 0x03, 0x14, 0x1c, 0x0b, 0x18, 0x1f,
                0x0c, 0x10, 0x17, 0x16, 0x05, 0x16, 0x0e, 0x03, 0x02, 0x0b, 0x13, 0x0b, 0x0a, 0x09, 0x0f, 0x01,
                0x17, 0x0f, 0x1c, 0x13, 0x1d, 0x0b, 0x03, 0x0e, 0x01, 0x04, 0x1f, 0x18, 0x04, 0x07, 0x10, 0x05,
                0x18, 0x09, 0x08, 0x16, 0x1e, 0x0e, 0x0f, 0x0c, 0x11, 0x0b, 0x0c, 0x13, 0x0f, 0x13, 0x13, 0x1d,
                0x02, 0x01, 0x0f, 0x03, 0x17, 0x0f, 0x0f, 0x09, 0x0a, 0x1e, 0x1c, 0x0e, 0x0d, 0x17, 0x1e, 0x02,
                0x07, 0x05, 0x0f, 0x0b, 0x01, 0x1f, 0x13, 0x17, 0x1a, 0x01, 0x1d, 0x12, 0x07, 0x01, 0x11, 0x10,
                0x1a, 0x19, 0x02, 0x06, 0x1a, 0x1e, 0x13, 0x18, 0x11, 0x14, 0x19, 0x15, 0x1a, 0x1f, 0x01, 0x01,
            }, .{
                0x10, 0x04, 0x14, 0x13, 0x04, 0x0f, 0x1d, 0x17, 0x0a, 0x08, 0x17, 0x1a, 0x02, 0x0c, 0x0c, 0x12,
                0x07, 0x0d, 0x11, 0x1c, 0x01, 0x17, 0x13, 0x1b, 0x11, 0x1c, 0x02, 0x16, 0x10, 0x0c, 0x16, 0x07,
                0x02, 0x18, 0x03, 0x04, 0x1c, 0x1c, 0x18, 0x0c, 0x15, 0x14, 0x17, 0x1c, 0x1e, 0x0b, 0x1c, 0x1f,
                0x18, 0x13, 0x02, 0x06, 0x18, 0x03, 0x1e, 0x12, 0x0a, 0x03, 0x07, 0x11, 0x09, 0x1a, 0x1c, 0x07,
                0x10, 0x1b, 0x19, 0x0b, 0x1c, 0x10, 0x08, 0x05, 0x02, 0x09, 0x04, 0x02, 0x11, 0x05, 0x13, 0x1a,
                0x0b, 0x1b, 0x1e, 0x11, 0x1e, 0x0e, 0x05, 0x18, 0x08, 0x0c, 0x04, 0x04, 0x06, 0x15, 0x05, 0x04,
                0x14, 0x1f, 0x18, 0x0c, 0x04, 0x04, 0x03, 0x1c, 0x1e, 0x09, 0x1d, 0x08, 0x13, 0x16, 0x0d, 0x1c,
                0x15, 0x16, 0x04, 0x02, 0x0c, 0x04, 0x13, 0x1d, 0x1d, 0x07, 0x1a, 0x1c, 0x15, 0x15, 0x19, 0x09,
            });

            try testArgs(@Vector(1, i7), .{
                0x3b,
            }, .{
                0x0d,
            });
            try testArgs(@Vector(2, i7), .{
                -0x3e, -0x06,
            }, .{
                -0x37, -0x0f,
            });
            try testArgs(@Vector(4, i7), .{
                0x35, 0x29, -0x17, 0x39,
            }, .{
                -0x2c, -0x02, -0x29, -0x1a,
            });
            try testArgs(@Vector(8, i7), .{
                0x1d, 0x25, 0x03, 0x1c, -0x12, -0x09, 0x1d, 0x3c,
            }, .{
                0x34, 0x33, 0x3e, -0x21, 0x13, 0x2d, 0x1f, 0x05,
            });
            try testArgs(@Vector(16, i7), .{
                -0x12, 0x39, 0x11, 0x28, 0x29, -0x30, 0x08, -0x33, 0x2e, 0x03, 0x31, -0x2b, -0x1f, 0x37, 0x0f, -0x31,
            }, .{
                -0x0d, -0x1a, -0x22, -0x38, 0x30, 0x32, -0x38, -0x3b, -0x04, -0x2c, 0x27, -0x0d, -0x02, -0x2d, 0x18, 0x09,
            });
            try testArgs(@Vector(32, i7), .{
                0x04, 0x09,  0x1e, -0x1b, -0x33, 0x1f, -0x08, 0x2d, -0x30, -0x3c, 0x11,  -0x2a, 0x29,  -0x16, -0x3b, -0x1e,
                0x3a, -0x0d, 0x11, 0x16,  0x27,  0x0f, 0x2f,  0x14, 0x3b,  -0x2f, -0x3d, 0x1d,  -0x08, -0x2e, -0x2a, -0x33,
            }, .{
                -0x09, 0x3c,  0x15, -0x25, -0x03, 0x0a,  0x11, 0x03,  0x12,  -0x1d, -0x23, 0x29,  -0x30, -0x35, -0x0e, -0x15,
                -0x1c, -0x14, 0x07, 0x29,  -0x0d, -0x2e, 0x12, -0x3b, -0x0c, 0x22,  -0x15, -0x2d, 0x04,  0x19,  0x14,  -0x1d,
            });
            try testArgs(@Vector(64, i7), .{
                0x23,  0x09,  -0x13, 0x03, 0x19,  -0x35, -0x06, -0x3c, -0x31, 0x12,  0x09, 0x22,  -0x15, -0x1c, -0x25, -0x31,
                0x3a,  -0x31, 0x05,  0x0b, -0x14, 0x38,  0x39,  0x15,  0x15,  -0x11, 0x11, -0x21, 0x2f,  0x3d,  -0x2e, -0x33,
                -0x38, 0x1b,  0x14,  0x1d, 0x0d,  -0x16, 0x10,  -0x0a, 0x25,  0x0d,  0x1e, 0x1a,  -0x15, 0x21,  0x3e,  -0x0c,
                0x03,  0x3f,  0x1f,  0x17, 0x2c,  -0x0a, -0x2b, 0x1f,  0x32,  0x09,  0x0f, -0x15, 0x24,  -0x35, 0x27,  -0x13,
            }, .{
                -0x20, 0x25,  0x38,  -0x28, 0x06,  -0x2f, -0x0b, -0x2b, 0x21,  -0x23, -0x08, 0x06,  -0x2a, -0x26, 0x33,  -0x2f,
                0x06,  -0x1b, 0x3c,  -0x3d, 0x3e,  0x1f,  0x27,  0x28,  -0x05, -0x31, -0x29, -0x25, -0x13, -0x07, -0x3e, 0x3e,
                0x0e,  -0x2c, -0x0f, -0x3b, 0x1b,  0x17,  0x3f,  -0x3a, 0x21,  -0x16, 0x11,  -0x0a, 0x1b,  0x2a,  0x27,  0x3e,
                -0x09, -0x34, 0x20,  0x3e,  -0x29, -0x35, -0x0b, -0x20, -0x19, 0x21,  0x13,  0x22,  0x0c,  -0x1f, 0x38,  0x21,
            });
            try testArgs(@Vector(128, i7), .{
                -0x38, -0x10, 0x08,  -0x2b, 0x3e,  -0x19, 0x39,  -0x1f, -0x27, -0x10, -0x0c, 0x02,  0x07,  0x10, -0x1a, 0x0b,
                0x3c,  -0x2e, 0x1b,  -0x17, 0x3e,  -0x1b, -0x04, 0x35,  0x2d,  0x0d,  0x33,  0x0f,  0x18,  0x0b, 0x1a,  -0x09,
                0x25,  -0x0b, -0x21, 0x3a,  -0x28, 0x12,  0x16,  0x03,  -0x1f, 0x1d,  -0x1c, -0x1a, -0x38, 0x32, 0x3d,  -0x2a,
                -0x0b, -0x1b, -0x39, -0x0d, -0x20, -0x1e, -0x39, 0x02,  -0x13, -0x23, 0x2f,  0x0a,  -0x22, 0x15, 0x34,  -0x06,
                -0x2e, -0x3b, 0x26,  0x38,  0x33,  -0x29, -0x0c, 0x2e,  0x07,  -0x19, 0x3c,  -0x35, -0x33, 0x39, 0x3c,  0x37,
                -0x07, -0x13, 0x16,  0x05,  -0x27, 0x28,  -0x2b, -0x07, -0x25, -0x01, 0x1d,  -0x0a, -0x01, 0x1d, -0x2a, -0x30,
                0x31,  0x0a,  -0x24, 0x0c,  0x35,  -0x1c, -0x04, 0x21,  -0x35, 0x12,  0x19,  0x3d,  -0x0c, 0x20, 0x28,  -0x22,
                -0x3c, 0x09,  0x11,  -0x0c, -0x14, -0x39, 0x0f,  -0x40, -0x0a, 0x0f,  0x1b,  0x34,  -0x27, 0x35, 0x0e,  -0x3d,
            }, .{
                -0x1a, 0x06,  0x1f,  -0x24, -0x21, -0x3d, 0x1f,  -0x18, 0x2f,  -0x38, 0x2f,  -0x0f, 0x20,  0x2d,  0x31,  -0x09,
                -0x1d, 0x3a,  0x24,  -0x09, 0x0c,  -0x3b, -0x35, -0x2a, -0x08, -0x2d, 0x29,  0x23,  -0x37, -0x05, 0x27,  -0x12,
                0x23,  -0x14, 0x26,  0x36,  -0x33, -0x1d, -0x0f, 0x32,  0x2a,  -0x34, -0x31, 0x0a,  -0x33, -0x34, 0x30,  0x3d,
                -0x1a, 0x0f,  0x16,  0x07,  0x2d,  -0x2b, 0x2c,  -0x2d, 0x34,  -0x07, 0x32,  0x3a,  0x2e,  -0x1c, 0x2e,  0x0f,
                0x02,  0x33,  -0x1e, -0x05, -0x40, -0x0a, 0x3d,  -0x28, -0x21, -0x2b, -0x18, 0x02,  0x01,  -0x2c, -0x16, -0x3b,
                0x27,  0x23,  -0x19, 0x13,  -0x2c, 0x3c,  -0x1a, 0x0e,  -0x25, -0x19, 0x06,  0x1b,  -0x3f, 0x26,  0x30,  0x0d,
                -0x0e, -0x2f, -0x28, 0x3b,  -0x0e, 0x2d,  0x3d,  0x03,  0x0d,  -0x23, 0x02,  0x26,  0x0c,  0x31,  -0x10, -0x10,
                0x37,  -0x38, -0x0f, 0x20,  -0x17, 0x02,  0x3e,  -0x40, 0x37,  0x22,  0x06,  0x14,  -0x31, -0x1e, -0x36, -0x2c,
            });

            try testArgs(@Vector(1, u7), .{
                0x72,
            }, .{
                0x0c,
            });
            try testArgs(@Vector(2, u7), .{
                0x0c, 0x3a,
            }, .{
                0x72, 0x0b,
            });
            try testArgs(@Vector(4, u7), .{
                0x68, 0x2b, 0x52, 0x6e,
            }, .{
                0x74, 0x79, 0x10, 0x67,
            });
            try testArgs(@Vector(8, u7), .{
                0x68, 0x30, 0x65, 0x49, 0x3f, 0x3c, 0x05, 0x1b,
            }, .{
                0x3f, 0x0e, 0x04, 0x50, 0x20, 0x07, 0x07, 0x4c,
            });
            try testArgs(@Vector(16, u7), .{
                0x46, 0x73, 0x34, 0x68, 0x66, 0x0d, 0x69, 0x38, 0x7d, 0x40, 0x34, 0x22, 0x7b, 0x57, 0x76, 0x69,
            }, .{
                0x12, 0x45, 0x1b, 0x5d, 0x24, 0x36, 0x72, 0x70, 0x51, 0x1c, 0x23, 0x77, 0x7d, 0x7a, 0x20, 0x4b,
            });
            try testArgs(@Vector(32, u7), .{
                0x1e, 0x74, 0x19, 0x6c, 0x74, 0x05, 0x6f, 0x08, 0x54, 0x56, 0x25, 0x40, 0x07, 0x2d, 0x42, 0x73,
                0x5c, 0x1c, 0x60, 0x1e, 0x5a, 0x1d, 0x00, 0x33, 0x3b, 0x09, 0x28, 0x58, 0x66, 0x1d, 0x4e, 0x6b,
            }, .{
                0x22, 0x79, 0x72, 0x19, 0x19, 0x0b, 0x64, 0x6b, 0x15, 0x70, 0x10, 0x70, 0x73, 0x56, 0x48, 0x68,
                0x01, 0x16, 0x1b, 0x68, 0x67, 0x09, 0x37, 0x36, 0x29, 0x25, 0x01, 0x7c, 0x58, 0x37, 0x61, 0x1c,
            });
            try testArgs(@Vector(64, u7), .{
                0x79, 0x75, 0x24, 0x4a, 0x05, 0x1b, 0x28, 0x74, 0x43, 0x1c, 0x35, 0x06, 0x0d, 0x53, 0x07, 0x75,
                0x37, 0x3b, 0x6c, 0x50, 0x5d, 0x52, 0x3f, 0x76, 0x3e, 0x57, 0x1e, 0x12, 0x31, 0x7b, 0x62, 0x6e,
                0x30, 0x09, 0x1c, 0x0d, 0x3e, 0x52, 0x64, 0x6e, 0x23, 0x41, 0x2f, 0x4b, 0x69, 0x65, 0x67, 0x3f,
                0x56, 0x6d, 0x4d, 0x35, 0x54, 0x7c, 0x63, 0x5d, 0x24, 0x49, 0x0a, 0x71, 0x55, 0x48, 0x3e, 0x4b,
            }, .{
                0x6a, 0x1d, 0x23, 0x7d, 0x12, 0x29, 0x23, 0x0b, 0x53, 0x3d, 0x39, 0x4b, 0x45, 0x05, 0x1b, 0x4a,
                0x5c, 0x66, 0x38, 0x2d, 0x38, 0x70, 0x29, 0x5b, 0x32, 0x38, 0x39, 0x2e, 0x01, 0x3c, 0x15, 0x05,
                0x1f, 0x28, 0x3a, 0x0f, 0x0a, 0x09, 0x11, 0x5e, 0x0a, 0x7a, 0x3f, 0x7d, 0x2c, 0x34, 0x63, 0x34,
                0x1b, 0x61, 0x73, 0x63, 0x2c, 0x35, 0x25, 0x19, 0x09, 0x0c, 0x75, 0x5d, 0x01, 0x29, 0x3b, 0x0c,
            });
            try testArgs(@Vector(128, u7), .{
                0x5c, 0x65, 0x65, 0x34, 0x31, 0x03, 0x7a, 0x56, 0x16, 0x74, 0x5c, 0x7f, 0x2a, 0x46, 0x2a, 0x5f,
                0x62, 0x06, 0x51, 0x23, 0x58, 0x1f, 0x5a, 0x2d, 0x29, 0x21, 0x26, 0x5a, 0x5a, 0x13, 0x13, 0x46,
                0x26, 0x1c, 0x06, 0x2d, 0x08, 0x52, 0x5b, 0x6f, 0x2d, 0x4a, 0x00, 0x40, 0x68, 0x27, 0x00, 0x4a,
                0x3a, 0x22, 0x2d, 0x5b, 0x05, 0x26, 0x4e, 0x6f, 0x46, 0x4d, 0x14, 0x70, 0x51, 0x04, 0x66, 0x13,
                0x4c, 0x7c, 0x67, 0x23, 0x13, 0x55, 0x1b, 0x30, 0x7d, 0x04, 0x47, 0x78, 0x05, 0x09, 0x5a, 0x20,
                0x2e, 0x17, 0x11, 0x49, 0x6c, 0x5e, 0x34, 0x3e, 0x66, 0x60, 0x5d, 0x75, 0x48, 0x1d, 0x69, 0x67,
                0x40, 0x2d, 0x7b, 0x31, 0x13, 0x60, 0x19, 0x2f, 0x3e, 0x7d, 0x23, 0x6a, 0x0e, 0x16, 0x44, 0x34,
                0x5d, 0x5a, 0x2a, 0x0b, 0x64, 0x07, 0x22, 0x5b, 0x24, 0x22, 0x3b, 0x46, 0x23, 0x65, 0x5d, 0x34,
            }, .{
                0x4b, 0x36, 0x7a, 0x13, 0x5a, 0x4b, 0x69, 0x4b, 0x1d, 0x02, 0x1b, 0x3f, 0x61, 0x21, 0x45, 0x48,
                0x44, 0x61, 0x25, 0x42, 0x57, 0x7d, 0x7a, 0x45, 0x22, 0x2e, 0x44, 0x3f, 0x3a, 0x14, 0x07, 0x6e,
                0x68, 0x51, 0x03, 0x6b, 0x11, 0x32, 0x6d, 0x6f, 0x44, 0x5a, 0x61, 0x6d, 0x71, 0x66, 0x54, 0x14,
                0x5d, 0x56, 0x22, 0x5c, 0x3a, 0x72, 0x16, 0x39, 0x59, 0x3e, 0x27, 0x4d, 0x3d, 0x44, 0x72, 0x2c,
                0x71, 0x74, 0x3b, 0x6c, 0x70, 0x39, 0x0f, 0x5c, 0x71, 0x04, 0x67, 0x02, 0x2c, 0x18, 0x0f, 0x14,
                0x2d, 0x24, 0x51, 0x34, 0x6d, 0x0c, 0x19, 0x0f, 0x73, 0x79, 0x3d, 0x74, 0x20, 0x15, 0x22, 0x25,
                0x09, 0x14, 0x09, 0x71, 0x2d, 0x6f, 0x09, 0x2e, 0x27, 0x75, 0x57, 0x62, 0x4d, 0x07, 0x62, 0x01,
                0x41, 0x2d, 0x5d, 0x4c, 0x77, 0x10, 0x7f, 0x30, 0x0f, 0x50, 0x15, 0x39, 0x34, 0x7c, 0x33, 0x16,
            });

            try testArgs(@Vector(1, i8), .{
                -0x54,
            }, .{
                0x0f,
            });
            try testArgs(@Vector(2, i8), .{
                -0x4d, 0x55,
            }, .{
                0x7d, -0x5d,
            });
            try testArgs(@Vector(4, i8), .{
                0x73, 0x6f, 0x6e, -0x49,
            }, .{
                -0x66, 0x23, 0x21, -0x56,
            });
            try testArgs(@Vector(8, i8), .{
                0x44, -0x37, 0x33, -0x2b, -0x1f, 0x3e, 0x50, -0x4d,
            }, .{
                0x6a, 0x1a, -0x0e, 0x4c, -0x46, 0x03, -0x17, 0x3e,
            });
            try testArgs(@Vector(16, i8), .{
                -0x52, 0x1a, -0x4b, 0x4e, -0x75, 0x33, -0x43, 0x30, 0x71, -0x30, -0x73, -0x53, 0x64, 0x1f, -0x27, 0x36,
            }, .{
                0x65, 0x77, -0x62, 0x0f, 0x15, 0x52, 0x5c, 0x12, -0x10, 0x36, 0x6d, 0x42, -0x24, -0x79, -0x32, -0x75,
            });
            try testArgs(@Vector(32, i8), .{
                -0x12, -0x1e, 0x18, 0x6e, 0x31,  0x53,  -0x6a, -0x34, 0x13,  0x4d, 0x30, -0x7d, -0x31, 0x1e,  -0x24, 0x32,
                -0x1e, -0x01, 0x55, 0x33, -0x75, -0x44, -0x57, 0x2b,  -0x66, 0x19, 0x7f, -0x28, -0x3f, -0x7e, -0x5d, -0x06,
            }, .{
                0x05, -0x23, 0x43,  -0x54, -0x41, 0x7f,  -0x6a, -0x31, 0x04,  0x15,  -0x7a, -0x37, 0x6d, 0x16,  0x01,  0x4a,
                0x15, 0x55,  -0x4a, 0x16,  -0x73, -0x0c, 0x1c,  -0x26, -0x14, -0x01, 0x55,  0x7b,  0x16, -0x2e, -0x5f, -0x67,
            });
            try testArgs(@Vector(64, i8), .{
                -0x05, 0x76,  0x4e,  -0x5c, 0x7b,  -0x1a, -0x38, -0x2e, 0x3d,  0x36,  0x01,  0x30,  -0x02, -0x71, -0x24, 0x24,
                -0x2e, -0x6e, -0x60, 0x74,  -0x80, -0x1c, -0x34, -0x08, -0x33, 0x77,  0x1c,  -0x0f, 0x45,  -0x51, -0x1d, 0x35,
                -0x45, 0x44,  0x27,  -0x3c, 0x6b,  0x58,  -0x6a, -0x26, 0x06,  -0x30, -0x21, -0x0a, 0x60,  -0x11, -0x05, 0x75,
                0x38,  0x72,  -0x6d, -0x1f, -0x7f, 0x74,  -0x6b, -0x14, -0x80, 0x35,  -0x0f, -0x1e, 0x6a,  0x17,  -0x74, -0x6c,
            }, .{
                -0x5d, 0x2d,  0x55,  0x40,  -0x7c, 0x67,  0x61,  0x5f,  0x14,  0x5b, -0x0c, -0x4d, -0x5f, 0x25,  0x36,  0x3c,
                -0x75, -0x48, -0x2b, 0x76,  -0x57, -0x4a, 0x1d,  0x65,  -0x32, 0x18, -0x2a, -0x0a, -0x6e, -0x3c, -0x62, 0x4e,
                -0x24, -0x3c, 0x7d,  -0x79, -0x1a, -0x14, -0x03, -0x56, 0x7a,  0x5f, 0x64,  -0x68, 0x5f,  -0x10, -0x63, -0x07,
                0x79,  -0x44, 0x47,  0x7d,  0x6e,  0x77,  0x03,  -0x4e, 0x67,  0x38, 0x46,  -0x44, -0x41, 0x66,  -0x16, -0x0a,
            });
            try testArgs(@Vector(128, i8), .{
                0x30,  0x70,  -0x2a, -0x29, -0x35, -0x69, -0x18, 0x2b,  0x4a,  -0x17, -0x5f, -0x36, 0x34,  -0x26, 0x03,  -0x2d,
                -0x75, -0x27, -0x07, -0x49, -0x58, 0x00,  -0x45, 0x5d,  -0x11, -0x68, 0x34,  0x73,  -0x4d, 0x7f,  -0x25, -0x6a,
                0x46,  -0x1d, -0x68, 0x04,  0x64,  -0x0d, 0x30,  0x27,  -0x24, 0x67,  0x3c,  -0x7c, -0x2e, -0x24, 0x24,  0x3e,
                -0x2c, -0x05, 0x4e,  -0x17, 0x6d,  0x57,  0x76,  0x35,  -0x3d, 0x51,  0x71,  -0x4e, 0x50,  0x26,  0x4a,  -0x42,
                0x73,  -0x36, -0x5d, 0x2a,  0x55,  0x33,  -0x2b, -0x76, 0x08,  0x43,  0x77,  -0x73, -0x0a, 0x5c,  -0x03, -0x50,
                -0x0a, -0x1c, -0x20, 0x3c,  -0x7e, 0x60,  0x11,  -0x77, 0x25,  -0x71, 0x31,  0x2d,  -0x4b, -0x26, -0x2a, 0x7f,
                -0x1f, 0x23,  -0x34, -0x1f, 0x35,  0x0d,  0x3e,  0x76,  -0x08, 0x2c,  0x12,  0x3e,  -0x09, -0x3e, 0x4b,  -0x52,
                -0x1a, -0x44, -0x53, -0x41, -0x6d, -0x5e, -0x06, -0x04, 0x3f,  -0x2e, 0x01,  0x54,  0x19,  -0x5a, -0x62, -0x3a,
            }, .{
                0x42,  -0x11, -0x08, -0x64, -0x55, 0x31,  0x27,  -0x66, 0x38,  0x5a,  0x25,  -0x68, 0x0b,  -0x41, -0x0d, 0x60,
                -0x17, -0x6d, 0x62,  -0x65, -0x5e, -0x1c, -0x35, 0x28,  0x1c,  -0x74, -0x7f, -0x1c, 0x3a,  0x4e,  0x05,  -0x08,
                0x30,  -0x77, 0x03,  0x68,  -0x2c, 0x5c,  0x74,  0x6a,  -0x21, 0x0a,  0x36,  -0x55, 0x21,  0x29,  -0x05, 0x70,
                0x23,  0x3b,  0x0a,  0x7a,  0x19,  0x14,  0x65,  -0x1d, 0x2b,  0x65,  0x33,  0x2a,  0x52,  -0x63, 0x57,  0x10,
                -0x1b, 0x26,  -0x46, -0x7e, -0x25, 0x79,  -0x01, -0x0d, -0x49, -0x4d, 0x74,  0x03,  0x77,  0x16,  0x03,  -0x3d,
                0x1c,  0x25,  0x5a,  -0x2f, -0x16, -0x5f, -0x36, -0x55, -0x44, -0x0c, -0x0f, 0x7b,  -0x15, -0x1d, 0x32,  0x31,
                0x6e,  -0x44, -0x4a, -0x64, 0x67,  0x04,  0x47,  -0x02, 0x3c,  -0x0a, -0x79, 0x3d,  0x48,  0x5a,  0x61,  -0x2c,
                0x6d,  -0x68, -0x71, -0x6b, -0x11, 0x44,  -0x75, -0x55, -0x67, -0x52, 0x64,  -0x3d, -0x05, -0x76, -0x6d, -0x44,
            });

            try testArgs(@Vector(1, u8), .{
                0x1f,
            }, .{
                0x06,
            });
            try testArgs(@Vector(2, u8), .{
                0x80, 0x63,
            }, .{
                0xe4, 0x28,
            });
            try testArgs(@Vector(4, u8), .{
                0x83, 0x9e, 0x1e, 0xc1,
            }, .{
                0xf0, 0x5c, 0x46, 0x85,
            });
            try testArgs(@Vector(8, u8), .{
                0x1e, 0x4d, 0x9d, 0x2a, 0x4c, 0x74, 0x0a, 0x83,
            }, .{
                0x28, 0x60, 0xa9, 0xb5, 0xd9, 0xa6, 0xf1, 0xb6,
            });
            try testArgs(@Vector(16, u8), .{
                0xea, 0x80, 0xbb, 0xe8, 0x74, 0x81, 0xc8, 0x66, 0x7b, 0x41, 0x90, 0xcb, 0x30, 0x70, 0x4b, 0x0f,
            }, .{
                0x61, 0x26, 0xbe, 0x47, 0x02, 0x9c, 0x55, 0xa5, 0x59, 0xf0, 0xb2, 0x20, 0x30, 0xaf, 0x82, 0x3e,
            });
            try testArgs(@Vector(32, u8), .{
                0xa1, 0x88, 0xc4, 0xf4, 0x77, 0x0b, 0xf5, 0xbb, 0x09, 0x03, 0xbf, 0xf5, 0xcc, 0x7f, 0x6b, 0x2a,
                0x4c, 0x05, 0x37, 0xc9, 0x8a, 0xcb, 0x91, 0x23, 0x09, 0x5f, 0xb8, 0x99, 0x4a, 0x75, 0x26, 0xe4,
            }, .{
                0xff, 0x0f, 0x99, 0x49, 0xa6, 0x25, 0xa7, 0xd4, 0xc9, 0x2f, 0x97, 0x6a, 0x01, 0xd6, 0x6e, 0x41,
                0xa4, 0xb5, 0x3c, 0x03, 0xea, 0x82, 0x9c, 0x5f, 0xac, 0x07, 0x16, 0x15, 0x1c, 0x64, 0x25, 0x2f,
            });
            try testArgs(@Vector(64, u8), .{
                0xaa, 0x08, 0xeb, 0xb2, 0xd7, 0x89, 0x0f, 0x98, 0xda, 0x9f, 0xa6, 0x4e, 0x3c, 0xce, 0x1b, 0x1b,
                0x9e, 0x5f, 0x2b, 0xd6, 0x59, 0x26, 0x47, 0x05, 0x2a, 0xb7, 0xd1, 0x10, 0xde, 0xd9, 0x84, 0x00,
                0x07, 0xc0, 0xaa, 0x6e, 0xfa, 0x3b, 0x97, 0x85, 0xa8, 0x42, 0xd7, 0xa5, 0x90, 0xe6, 0x10, 0x1a,
                0x47, 0x84, 0xe1, 0x3e, 0xb0, 0x70, 0x26, 0x3f, 0xea, 0x24, 0xb8, 0x5f, 0xe3, 0xe3, 0x4c, 0xed,
            }, .{
                0x3b, 0xc5, 0xe0, 0x3d, 0x4f, 0x2e, 0x1d, 0xa9, 0xf7, 0x7b, 0xc7, 0xc1, 0x48, 0xc6, 0xe5, 0x9e,
                0x4d, 0xa8, 0x21, 0x37, 0xa1, 0x1a, 0x95, 0x69, 0x89, 0x2f, 0x15, 0x07, 0x3d, 0x7b, 0x69, 0x89,
                0xea, 0x87, 0xf0, 0x94, 0x67, 0xf2, 0x3d, 0x04, 0x96, 0x8a, 0xd6, 0x70, 0x7c, 0x16, 0xe7, 0x62,
                0xf0, 0x8d, 0x96, 0x65, 0xd1, 0x4a, 0x35, 0x3e, 0x7a, 0x67, 0xa6, 0x1f, 0x37, 0x66, 0xe3, 0x45,
            });
            try testArgs(@Vector(128, u8), .{
                0xa1, 0xd0, 0x7b, 0xf9, 0x7b, 0x77, 0x7b, 0x3d, 0x2d, 0x68, 0xc2, 0x7b, 0xb0, 0xb8, 0xd4, 0x7c,
                0x1a, 0x1f, 0xd2, 0x92, 0x3e, 0xcb, 0xc1, 0x6b, 0xb9, 0x4d, 0xf1, 0x67, 0x58, 0x8e, 0x77, 0xa6,
                0xb9, 0xdf, 0x10, 0x6f, 0xbe, 0xe3, 0x33, 0xb6, 0x93, 0x77, 0x80, 0xef, 0x09, 0x9d, 0x61, 0x40,
                0xa2, 0xf4, 0x52, 0x18, 0x9d, 0xe4, 0xb0, 0xaf, 0x0a, 0xa7, 0x0b, 0x09, 0x67, 0x38, 0x71, 0x04,
                0x72, 0xa1, 0xd2, 0xfd, 0xf8, 0xf0, 0xa7, 0x23, 0x24, 0x5b, 0x7d, 0xfb, 0x43, 0xba, 0x6c, 0xc4,
                0x83, 0x46, 0x0e, 0x4d, 0x6c, 0x92, 0xab, 0x4f, 0xd2, 0x70, 0x9d, 0xfe, 0xce, 0xf8, 0x05, 0x9f,
                0x98, 0x36, 0x9c, 0x90, 0x9a, 0xd0, 0xb5, 0x76, 0x16, 0xe8, 0x25, 0xc2, 0xbd, 0x91, 0xab, 0xf9,
                0x6f, 0x6c, 0xc5, 0x60, 0xe5, 0x30, 0xf2, 0xb7, 0x59, 0xc4, 0x9c, 0xdd, 0xdf, 0x04, 0x65, 0xd9,
            }, .{
                0xed, 0xe1, 0x8a, 0xf6, 0xf3, 0x8b, 0xfd, 0x1d, 0x3c, 0x87, 0xbf, 0xfe, 0x04, 0x52, 0x15, 0x82,
                0x0b, 0xb0, 0xcf, 0xcf, 0xf8, 0x03, 0x9c, 0xef, 0xc1, 0x76, 0x7e, 0xe3, 0xe9, 0xa8, 0x18, 0x90,
                0xd4, 0xc4, 0x91, 0x15, 0x68, 0x7f, 0x65, 0xd8, 0xe1, 0xb3, 0x23, 0xc2, 0x7d, 0x84, 0x3b, 0xaf,
                0x74, 0x69, 0x07, 0x2a, 0x1b, 0x5f, 0x0e, 0x44, 0x0d, 0x2b, 0x9c, 0x82, 0x41, 0xf9, 0x7f, 0xb5,
                0xc4, 0xd9, 0xcb, 0xd3, 0xc5, 0x31, 0x8b, 0x5f, 0xda, 0x09, 0x9b, 0x29, 0xa3, 0xb7, 0x13, 0x0d,
                0x55, 0x9b, 0x59, 0x33, 0x2a, 0x59, 0x3a, 0x44, 0x1f, 0xd3, 0x40, 0x4e, 0xde, 0x2c, 0xe4, 0x16,
                0xfd, 0xc3, 0x02, 0x74, 0xaa, 0x65, 0xfd, 0xc8, 0x2a, 0x8a, 0xdb, 0xae, 0x44, 0x28, 0x62, 0xa4,
                0x56, 0x4f, 0xf1, 0xaa, 0x0a, 0x0f, 0xdb, 0x1b, 0xc8, 0x45, 0x9b, 0x12, 0xb4, 0x1a, 0xe4, 0xa3,
            });

            try testArgs(@Vector(1, i9), .{
                0x002,
            }, .{
                0x0bd,
            });
            try testArgs(@Vector(2, i9), .{
                0x00c, 0x0b1,
            }, .{
                -0x00b, -0x009,
            });
            try testArgs(@Vector(4, i9), .{
                0x0b2, 0x02b, -0x09d, -0x03c,
            }, .{
                0x031, 0x078, 0x016, -0x08a,
            });
            try testArgs(@Vector(8, i9), .{
                0x066, -0x03b, 0x007, 0x054, 0x0a7, 0x0ee, 0x00f, -0x0f8,
            }, .{
                0x01e, 0x0af, 0x047, 0x0d8, 0x002, -0x030, -0x01d, 0x003,
            });
            try testArgs(@Vector(16, i9), .{
                0x0e7, -0x066, 0x079, -0x08d, -0x01a, -0x009, 0x0c8, 0x0c0, -0x070, 0x001, -0x00e, 0x014, -0x0f7, -0x07f, 0x0c8, -0x09a,
            }, .{
                0x0ea, -0x040, -0x045, -0x06d, 0x02c, -0x0b0, -0x0ba, -0x01a, 0x0af, 0x055, -0x015, -0x0fa, 0x0ca, 0x0f4, 0x007, -0x0a0,
            });
            try testArgs(@Vector(32, i9), .{
                -0x003, 0x01b,  0x0b6, -0x009, 0x090, 0x047,  -0x00b, -0x0f2, 0x0f6, -0x09d, 0x0bf,  0x06a, -0x0e0, 0x03f, 0x007,  0x0a1,
                0x009,  -0x0fb, 0x034, 0x0ba,  0x0cb, -0x0c9, -0x0ff, -0x0c1, 0x0d3, 0x029,  -0x076, 0x044, 0x0d4,  0x083, -0x002, 0x04e,
            }, .{
                -0x0cb, 0x0e3,  0x014, 0x02f,  -0x0da, -0x06a, 0x07f,  0x07d, -0x0ea, -0x014, 0x09a, 0x050, 0x017,  -0x00d, 0x041,  0x03e,
                -0x096, -0x008, 0x075, -0x0bc, 0x0f9,  -0x0fc, -0x0a7, 0x0ef, 0x0f9,  0x066,  0x02f, 0x0d3, -0x0f0, -0x04a, -0x100, -0x0c6,
            });
            try testArgs(@Vector(64, i9), .{
                -0x016, -0x0ae, 0x08b,  -0x0eb, -0x0b2, 0x02f,  0x039,  -0x0ba, -0x08d, -0x0a8, -0x0eb, -0x01a, 0x0eb,  0x0ca,  -0x049, 0x04e,
                -0x019, -0x0d9, -0x0bd, 0x0ae,  -0x07d, -0x092, -0x0fb, -0x06c, -0x0e6, 0x0d9,  0x02c,  0x0cc,  0x093,  -0x022, 0x07a,  -0x093,
                0x0e5,  -0x011, -0x003, 0x070,  -0x042, -0x0ad, 0x0be,  -0x038, -0x0bf, 0x098,  0x090,  -0x09e, -0x0a5, -0x0e1, -0x0e2, 0x039,
                -0x035, -0x0e5, -0x054, 0x04c,  0x04b,  -0x09f, 0x091,  -0x039, 0x09b,  -0x029, 0x014,  -0x0d3, 0x06b,  0x0ae,  0x091,  0x082,
            }, .{
                -0x0bb, -0x0ec, 0x0fa,  0x055,  0x06f,  0x011,  -0x09d, 0x083,  -0x066, 0x014, 0x007,  0x002,  -0x0ee, -0x0d9, 0x0c3,  -0x087,
                0x03c,  -0x065, -0x0cf, -0x075, -0x0c7, -0x0c1, 0x06b,  -0x0e3, -0x07a, 0x0b2, -0x0f8, -0x0fa, 0x001,  -0x0ba, 0x0c4,  0x0bb,
                0x032,  0x01e,  -0x074, -0x058, -0x040, 0x0aa,  0x077,  0x028,  -0x061, 0x076, -0x04e, 0x01a,  -0x05f, -0x073, 0x0ea,  0x06e,
                -0x069, -0x0a1, -0x041, 0x013,  -0x01c, -0x0f8, 0x053,  0x0f8,  -0x0c3, 0x058, -0x02d, 0x0f1,  -0x045, 0x04b,  -0x0b1, -0x0f3,
            });
            try testArgs(@Vector(128, i9), .{
                0x0d4,  0x036,  0x0bd,  -0x046, -0x0a7, 0x09e,  0x0dd,  0x043,  0x098,  -0x09a, -0x06f, 0x0bb,  -0x0b7, 0x021,  0x0a3,  0x0f0,
                0x069,  -0x08b, 0x0da,  0x016,  -0x049, 0x0d0,  0x07b,  0x004,  0x0ad,  -0x07c, -0x04e, -0x011, 0x01f,  -0x035, 0x028,  -0x0c9,
                -0x0eb, 0x077,  0x08b,  -0x009, 0x024,  -0x058, 0x04e,  -0x0c0, -0x01d, -0x0a7, 0x088,  0x01b,  -0x0f3, -0x0c5, -0x08e, 0x0dc,
                0x07d,  0x086,  -0x032, 0x0a9,  -0x00c, -0x06a, 0x06c,  0x032,  0x083,  0x0ec,  0x0ec,  -0x0a6, 0x029,  0x044,  -0x07f, 0x068,
                -0x038, 0x0f6,  0x0b5,  -0x00d, -0x051, -0x0c6, -0x0af, -0x0eb, -0x0b6, 0x03c,  -0x037, 0x0cc,  -0x033, 0x08a,  -0x0b4, -0x039,
                0x01e,  0x06c,  0x015,  -0x081, -0x029, 0x017,  -0x080, -0x01e, -0x081, 0x04f,  -0x071, -0x073, 0x0c3,  0x079,  0x0ad,  0x087,
                -0x072, 0x067,  -0x064, -0x0d4, 0x0b4,  0x003,  0x0b1,  0x0bb,  0x0cc,  -0x0e9, 0x0e7,  0x015,  0x07b,  0x0e4,  -0x0ee, -0x07f,
                -0x0bf, 0x0cd,  -0x056, 0x0ea,  0x0e5,  0x0fa,  0x0e1,  -0x087, 0x0fe,  0x017,  0x071,  -0x0d1, -0x053, -0x088, -0x0ef, 0x01b,
            }, .{
                0x0ea,  -0x018, 0x0ab,  0x039,  0x0ec,  0x0cc,  -0x033, -0x0e6, -0x037, -0x075, -0x055, -0x09a, 0x0bc,  0x099,  -0x03c, -0x0b4,
                -0x0fe, -0x0ce, 0x0d6,  -0x084, 0x08f,  0x04b,  0x0cc,  -0x023, 0x01e,  -0x09c, 0x058,  0x0f4,  -0x0a7, 0x085,  -0x049, -0x050,
                0x0f3,  -0x036, -0x0fe, 0x070,  -0x0a2, -0x081, -0x066, 0x057,  -0x017, -0x0c8, 0x070,  0x09b,  -0x0e4, -0x03b, -0x0d9, 0x081,
                0x041,  0x0ec,  -0x062, 0x0b9,  -0x0d2, -0x02a, 0x0ab,  0x072,  0x001,  -0x082, -0x0cd, 0x0c8,  0x017,  -0x09d, 0x094,  -0x027,
                0x09c,  0x024,  -0x0ec, 0x02f,  0x066,  -0x08e, 0x0ee,  0x099,  0x08e,  -0x0e5, -0x094, 0x0bb,  0x02f,  -0x0fe, -0x07e, -0x0ad,
                0x05c,  0x066,  0x07e,  -0x0a9, 0x0fe,  -0x0e3, -0x068, 0x058,  -0x007, 0x0d6,  -0x0e8, -0x0d6, 0x038,  0x0b8,  -0x0b2, 0x0c1,
                0x09a,  0x02f,  0x0d9,  0x07d,  0x0fc,  0x0f7,  -0x005, -0x01c, 0x0c2,  0x066,  0x064,  -0x096, -0x040, 0x065,  -0x00d, -0x063,
                0x031,  -0x088, 0x090,  -0x077, 0x0e2,  0x0a8,  -0x0e0, -0x077, 0x0eb,  0x0c3,  -0x0ad, 0x008,  0x04e,  -0x095, -0x041, -0x0a6,
            });

            try testArgs(@Vector(1, u9), .{
                0x09e,
            }, .{
                0x171,
            });
            try testArgs(@Vector(2, u9), .{
                0x0bf, 0x042,
            }, .{
                0x154, 0x14b,
            });
            try testArgs(@Vector(4, u9), .{
                0x0a5, 0x1ba, 0x1ef, 0x0b3,
            }, .{
                0x15d, 0x1d3, 0x00e, 0x13b,
            });
            try testArgs(@Vector(8, u9), .{
                0x068, 0x125, 0x1ac, 0x105, 0x0cb, 0x14b, 0x18b, 0x07f,
            }, .{
                0x04a, 0x011, 0x0ad, 0x1d7, 0x1b8, 0x083, 0x16d, 0x052,
            });
            try testArgs(@Vector(16, u9), .{
                0x00e, 0x0b4, 0x0d2, 0x149, 0x012, 0x17d, 0x13f, 0x1cb, 0x0f2, 0x145, 0x098, 0x005, 0x055, 0x141, 0x115, 0x01c,
            }, .{
                0x06c, 0x1da, 0x192, 0x0cf, 0x180, 0x0c2, 0x158, 0x0c6, 0x141, 0x105, 0x168, 0x165, 0x0aa, 0x0d5, 0x0a1, 0x03d,
            });
            try testArgs(@Vector(32, u9), .{
                0x1bd, 0x05b, 0x1e1, 0x03e, 0x18b, 0x1ad, 0x102, 0x1bc, 0x0cd, 0x09f, 0x028, 0x057, 0x0cd, 0x14f, 0x02b, 0x00f,
                0x140, 0x0b3, 0x155, 0x161, 0x1b6, 0x0ae, 0x13f, 0x1a7, 0x1b5, 0x0d4, 0x1f1, 0x1f5, 0x01c, 0x04b, 0x110, 0x0e2,
            }, .{
                0x027, 0x046, 0x00a, 0x035, 0x0ad, 0x10c, 0x010, 0x0ef, 0x096, 0x061, 0x016, 0x0cb, 0x17a, 0x0aa, 0x0d6, 0x1ad,
                0x108, 0x0e3, 0x078, 0x020, 0x145, 0x0fc, 0x109, 0x04e, 0x13b, 0x02b, 0x11c, 0x125, 0x0f0, 0x185, 0x06b, 0x0b2,
            });
            try testArgs(@Vector(64, u9), .{
                0x17b, 0x094, 0x1e8, 0x089, 0x0ec, 0x15d, 0x190, 0x0eb, 0x086, 0x091, 0x132, 0x074, 0x004, 0x142, 0x136, 0x066,
                0x0a1, 0x1dc, 0x1d2, 0x026, 0x11e, 0x1eb, 0x1d5, 0x055, 0x047, 0x116, 0x0b7, 0x14a, 0x1ea, 0x067, 0x1c1, 0x19e,
                0x13e, 0x11a, 0x16d, 0x0a6, 0x1b8, 0x0ef, 0x179, 0x076, 0x13e, 0x118, 0x0a3, 0x04e, 0x10a, 0x1bd, 0x186, 0x170,
                0x172, 0x14f, 0x15e, 0x0f2, 0x1bc, 0x016, 0x189, 0x199, 0x0ee, 0x1ac, 0x0d8, 0x094, 0x19f, 0x0c8, 0x0f2, 0x06a,
            }, .{
                0x096, 0x19f, 0x094, 0x03d, 0x060, 0x164, 0x171, 0x101, 0x1ab, 0x172, 0x14b, 0x177, 0x1d6, 0x10d, 0x193, 0x13e,
                0x1cf, 0x1be, 0x16a, 0x088, 0x0bb, 0x1bf, 0x052, 0x14c, 0x1fa, 0x060, 0x1c7, 0x073, 0x19d, 0x158, 0x1dc, 0x12d,
                0x1c1, 0x15c, 0x10e, 0x16e, 0x1d2, 0x155, 0x0d1, 0x0e1, 0x126, 0x0bd, 0x081, 0x17e, 0x1f9, 0x1aa, 0x1ad, 0x0fe,
                0x0f8, 0x158, 0x0ec, 0x00f, 0x033, 0x053, 0x033, 0x1e4, 0x05b, 0x072, 0x06b, 0x1a3, 0x157, 0x0ed, 0x1c8, 0x01b,
            });
            try testArgs(@Vector(128, u9), .{
                0x13e, 0x0ad, 0x121, 0x0b1, 0x186, 0x0af, 0x058, 0x1b6, 0x16c, 0x0b0, 0x1e4, 0x1a2, 0x1f7, 0x1e1, 0x12c, 0x098,
                0x0a5, 0x138, 0x1dd, 0x1d5, 0x0a0, 0x01e, 0x01e, 0x077, 0x0a9, 0x0f9, 0x12b, 0x153, 0x0bd, 0x0ac, 0x13e, 0x097,
                0x062, 0x064, 0x091, 0x100, 0x0be, 0x196, 0x096, 0x183, 0x18f, 0x006, 0x07f, 0x14c, 0x0ec, 0x028, 0x0cd, 0x09c,
                0x054, 0x0c7, 0x0cf, 0x019, 0x058, 0x0fa, 0x1ec, 0x1c4, 0x0d8, 0x0f7, 0x187, 0x1a5, 0x17f, 0x008, 0x087, 0x199,
                0x1cd, 0x094, 0x100, 0x011, 0x050, 0x09d, 0x05e, 0x1f8, 0x0a7, 0x0a7, 0x0f7, 0x06b, 0x05e, 0x14f, 0x03c, 0x08c,
                0x110, 0x16a, 0x08b, 0x1a3, 0x173, 0x1e0, 0x01a, 0x18a, 0x061, 0x0e8, 0x0d7, 0x0a6, 0x11b, 0x1fa, 0x004, 0x1fe,
                0x045, 0x117, 0x0ab, 0x11a, 0x079, 0x1f6, 0x1bb, 0x0b6, 0x04a, 0x01b, 0x0d5, 0x0a6, 0x15a, 0x088, 0x0fa, 0x180,
                0x0a4, 0x1fa, 0x17b, 0x117, 0x120, 0x110, 0x199, 0x109, 0x171, 0x1cb, 0x1cb, 0x0f3, 0x127, 0x1b2, 0x0e5, 0x152,
            }, .{
                0x137, 0x1c8, 0x1e2, 0x04a, 0x0f9, 0x0a7, 0x1d7, 0x1ba, 0x1a6, 0x035, 0x09b, 0x018, 0x1bd, 0x0fe, 0x08d, 0x029,
                0x0d8, 0x1cc, 0x06f, 0x174, 0x132, 0x02b, 0x188, 0x15f, 0x036, 0x15e, 0x0bc, 0x1bd, 0x1b2, 0x0f1, 0x193, 0x0b7,
                0x192, 0x03d, 0x0df, 0x1b7, 0x087, 0x14a, 0x137, 0x102, 0x117, 0x0de, 0x031, 0x03e, 0x1b0, 0x021, 0x0f4, 0x13e,
                0x148, 0x0a7, 0x19c, 0x11e, 0x0e6, 0x0f1, 0x043, 0x1b3, 0x0c6, 0x1b2, 0x162, 0x098, 0x1c1, 0x0e7, 0x142, 0x032,
                0x00d, 0x196, 0x124, 0x11e, 0x011, 0x19b, 0x023, 0x101, 0x0a1, 0x1ae, 0x03a, 0x0ec, 0x146, 0x020, 0x0c0, 0x0d7,
                0x135, 0x152, 0x0fe, 0x08b, 0x193, 0x147, 0x0bf, 0x1c3, 0x0a2, 0x0c2, 0x0f7, 0x1c5, 0x1fe, 0x0a2, 0x033, 0x1ec,
                0x043, 0x1a9, 0x1f5, 0x151, 0x04d, 0x176, 0x0df, 0x1f4, 0x09f, 0x054, 0x119, 0x0f8, 0x197, 0x0e9, 0x189, 0x196,
                0x083, 0x1bb, 0x19b, 0x1a9, 0x15b, 0x136, 0x192, 0x08f, 0x0ba, 0x166, 0x178, 0x0c2, 0x0d0, 0x1b7, 0x181, 0x1e2,
            });

            try testArgs(@Vector(1, i15), .{
                0x1309,
            }, .{
                0x1422,
            });
            try testArgs(@Vector(2, i15), .{
                0x32e8, 0x3d81,
            }, .{
                0x195c, 0x13e8,
            });
            try testArgs(@Vector(4, i15), .{
                -0x3485, 0x2320, -0x1725, 0x1e6e,
            }, .{
                0x2910, 0x3293, 0x3144, -0x3bbc,
            });
            try testArgs(@Vector(8, i15), .{
                0x1c0d, 0x2f06, -0x0e9e, 0x230a, 0x0a7b, 0x19ae, -0x19b6, -0x2ace,
            }, .{
                -0x34a3, -0x342a, -0x0aaf, 0x1ece, 0x12fc, 0x0562, 0x0d22, -0x310f,
            });
            try testArgs(@Vector(16, i15), .{
                -0x0abb, -0x1bbc, -0x3112, -0x23bf, -0x08b5, -0x1517, 0x1586, 0x06b2,
                0x25ec,  0x3cf1,  0x07ea,  0x3972,  0x09d8,  -0x18a6, 0x06dd, -0x1c34,
            }, .{
                -0x0ec7, 0x1144,  -0x1a94, 0x255f,  -0x1fbb, -0x1500, -0x0e4f, 0x0b67,
                0x1352,  -0x0d6b, 0x2f3e,  -0x086b, -0x19dc, -0x149b, -0x013e, 0x0ce6,
            });
            try testArgs(@Vector(32, i15), .{
                -0x330a, -0x0a40, -0x2533, -0x1e99, 0x1aa6, -0x2587, 0x2778,  0x394a,
                -0x0383, -0x2fb7, 0x04cf,  0x033a,  0x2bff, 0x3997,  -0x112c, 0x3a1a,
                0x1adf,  0x270b,  0x182e,  -0x23f6, 0x1a33, 0x2644,  -0x0b41, -0x1c48,
                0x1c2d,  -0x2a40, 0x007c,  0x1a62,  0x30d9, 0x0e4b,  0x32ee,  0x2b46,
            }, .{
                0x1af0,  0x286f,  -0x14fe, 0x2318,  0x002a,  -0x26b2, 0x350b,  0x0884,
                0x3011,  0x276a,  0x2b2a,  0x22d3,  -0x1ece, 0x0143,  0x2f5b,  -0x0fa2,
                0x2412,  -0x3d86, -0x3774, -0x09a5, 0x0fbf,  0x32f7,  -0x0a23, -0x3d5a,
                -0x1523, -0x27c5, 0x097f,  0x2923,  0x3060,  0x113e,  -0x0643, -0x1287,
            });
            try testArgs(@Vector(64, i15), .{
                0x0419,  0x1803,  -0x3897, 0x2b0c,  0x08a3,  -0x39d0, 0x174e,  -0x29c6,
                0x0152,  -0x1078, 0x1113,  0x23bf,  0x0990,  -0x2777, 0x2ba4,  -0x058b,
                -0x2d4a, -0x23ba, 0x3875,  -0x1720, -0x2625, -0x1c8f, 0x1f7c,  0x3f73,
                0x3780,  -0x3043, -0x0d8d, 0x2ced,  0x091a,  0x3481,  -0x1917, -0x352f,
                0x34c7,  0x322f,  -0x20ae, -0x0653, 0x1c82,  0x09a8,  -0x1a0b, -0x1dff,
                -0x24c2, -0x2592, -0x3ff7, 0x1515,  -0x3d32, 0x1e9e,  -0x334d, 0x352b,
                -0x2439, -0x3d0b, -0x2bcc, -0x2d29, 0x197c,  -0x2bad, -0x2682, 0x32cf,
                0x31e4,  -0x085c, -0x0c84, -0x2f11, 0x03ba,  -0x0111, -0x2634, 0x344f,
            }, .{
                0x011a,  0x186c,  -0x2d7e, 0x29b1,  0x2cfb,  -0x077b, 0x3e8c,  -0x3a62,
                0x3575,  0x35f0,  -0x2529, -0x3040, 0x398e,  -0x0c56, 0x2aa5,  0x0a72,
                -0x0c36, -0x2c53, 0x275b,  -0x1155, 0x1a9d,  -0x34af, -0x3d4f, 0x14a0,
                -0x0b88, 0x0b34,  0x2d60,  0x19ee,  -0x0ac4, -0x2f1b, -0x1e20, -0x2d8b,
                -0x23f4, 0x0472,  0x1977,  -0x33f2, -0x301d, -0x1931, -0x1abe, 0x307f,
                -0x2dcb, 0x2e99,  0x0dd1,  0x0377,  -0x3f91, -0x3719, 0x0248,  0x3c40,
                -0x08d4, -0x2f12, -0x12ee, 0x3bc0,  0x3c4a,  0x1ff3,  -0x1096, -0x37e0,
                -0x0879, -0x354f, -0x2277, 0x1ced,  0x0833,  -0x0f7e, 0x2070,  0x0d81,
            });

            try testArgs(@Vector(1, u15), .{
                0x18c0,
            }, .{
                0x0c85,
            });
            try testArgs(@Vector(2, u15), .{
                0x3697, 0x744b,
            }, .{
                0x60d5, 0x4172,
            });
            try testArgs(@Vector(4, u15), .{
                0x7c31, 0x62c3, 0x7fe9, 0x4a52,
            }, .{
                0x28bf, 0x58a9, 0x09d5, 0x111f,
            });
            try testArgs(@Vector(8, u15), .{
                0x3be1, 0x1928, 0x227e, 0x7ab4, 0x7e26, 0x4761, 0x586a, 0x4665,
            }, .{
                0x11b8, 0x4079, 0x39eb, 0x79d2, 0x7871, 0x5a40, 0x793c, 0x4a66,
            });
            try testArgs(@Vector(16, u15), .{
                0x30fe, 0x6781, 0x6db6, 0x16f7, 0x736f, 0x1dca, 0x122e, 0x4e43,
                0x41d8, 0x5b7a, 0x183b, 0x5036, 0x6a3a, 0x4301, 0x6c05, 0x5e7f,
            }, .{
                0x7dd5, 0x0897, 0x7f63, 0x0375, 0x5d05, 0x74c8, 0x0bc8, 0x6ac2,
                0x5063, 0x335a, 0x283c, 0x452d, 0x6274, 0x2531, 0x1f90, 0x05c3,
            });
            try testArgs(@Vector(32, u15), .{
                0x122d, 0x54a6, 0x7cf1, 0x5b48, 0x47e3, 0x6918, 0x0d81, 0x6074,
                0x06d3, 0x0951, 0x40d8, 0x52db, 0x6258, 0x13fa, 0x3fe0, 0x0cdc,
                0x6c69, 0x4fa8, 0x7bc7, 0x66e7, 0x1417, 0x368a, 0x46fc, 0x1850,
                0x2a1d, 0x2622, 0x3877, 0x524a, 0x64b0, 0x6391, 0x2f16, 0x5b7c,
            }, .{
                0x4c22, 0x7689, 0x57ba, 0x04b5, 0x2720, 0x081e, 0x25e4, 0x3f89,
                0x3065, 0x2d1e, 0x0386, 0x0f0c, 0x740a, 0x5fa5, 0x6b0a, 0x1fda,
                0x2b3c, 0x5e71, 0x77c5, 0x3e29, 0x6a2e, 0x147e, 0x79a1, 0x77f6,
                0x4bdd, 0x7fb1, 0x632c, 0x3898, 0x3dd3, 0x78b3, 0x75b9, 0x4960,
            });
            try testArgs(@Vector(64, u15), .{
                0x2bb1, 0x0225, 0x151a, 0x056c, 0x0655, 0x3f5b, 0x5fea, 0x000a,
                0x4f56, 0x7e08, 0x20b4, 0x4f64, 0x0da1, 0x74a0, 0x11b7, 0x38c7,
                0x7a25, 0x6608, 0x50a7, 0x79b8, 0x5444, 0x4cc4, 0x110d, 0x1cf0,
                0x5a2e, 0x4462, 0x03dc, 0x785a, 0x2d1c, 0x4592, 0x1855, 0x14c6,
                0x2c4d, 0x7ae3, 0x7b45, 0x6cb0, 0x197d, 0x6fcc, 0x269e, 0x6f98,
                0x7527, 0x7895, 0x0259, 0x2b3f, 0x181a, 0x5f50, 0x401d, 0x54d2,
                0x2acc, 0x0aa8, 0x6822, 0x5d64, 0x3459, 0x5823, 0x4e62, 0x395e,
                0x339f, 0x0b56, 0x25b8, 0x0c30, 0x5b3d, 0x7005, 0x0411, 0x074d,
            }, .{
                0x155c, 0x6c07, 0x5880, 0x1766, 0x661b, 0x5cfd, 0x1fb9, 0x67e1,
                0x617c, 0x2bb4, 0x251b, 0x7ace, 0x4940, 0x584b, 0x708c, 0x3849,
                0x0cdb, 0x3204, 0x4667, 0x7bee, 0x3279, 0x4c74, 0x7561, 0x2d6f,
                0x5676, 0x530e, 0x39a1, 0x7c05, 0x1b23, 0x7bd7, 0x25ce, 0x7e97,
                0x56c0, 0x0d59, 0x17f7, 0x6fed, 0x3b0e, 0x7470, 0x52a4, 0x5da3,
                0x17c8, 0x2a51, 0x031f, 0x5879, 0x22bb, 0x674e, 0x3a55, 0x13a2,
                0x1fef, 0x1cd8, 0x5067, 0x6602, 0x3d5b, 0x2f5e, 0x4b7f, 0x6cfc,
                0x197d, 0x5afc, 0x4254, 0x07de, 0x6b37, 0x07d5, 0x4435, 0x0b29,
            });

            try testArgs(@Vector(1, i16), .{
                -0x7b9c,
            }, .{
                0x600a,
            });
            try testArgs(@Vector(2, i16), .{
                0x43cc, -0x1421,
            }, .{
                -0x2b0e, 0x4d99,
            });
            try testArgs(@Vector(4, i16), .{
                0x558f, 0x6d92, 0x488f, 0x0a04,
            }, .{
                -0x01a9,
                0x2ee4,
                0x24a9,
                -0x5fee,
            });
            try testArgs(@Vector(8, i16), .{
                -0x7e5d, -0x02e4, -0x3a72, -0x2e30, 0x7c87, 0x3ea0, 0x4f02, 0x06e4,
            }, .{
                -0x417f, 0x5a13, -0x117b, 0x4c28, -0x3769, -0x56a8, 0x1656, -0x4431,
            });
            try testArgs(@Vector(16, i16), .{
                0x04be,  0x774a, 0x7395,  -0x6ca2, -0x21a0, 0x35be, 0x186c,  0x5991,
                -0x1a82, 0x4527, -0x2278, -0x3554, 0x42c1,  0x7f53, -0x670d, 0x1fad,
            }, .{
                0x7a7d,  0x47dd,  0x1975,  0x4028, 0x26ef,  -0x24f5, -0x77c9, -0x19a5,
                -0x4b04, -0x6939, -0x1b8d, 0x3718, -0x78e6, 0x0941,  -0x1208, -0x392d,
            });
            try testArgs(@Vector(32, i16), .{
                0x4cde,  0x3ab0,  0x354e,  0x0bc0,  -0x5333, 0x4857,  -0x7ccf, -0x69da,
                0x6ab8,  0x2bf3,  0x1c5a,  0x7b11,  -0x5653, 0x7bc5,  0x497e,  -0x0b55,
                0x7aa8,  -0x5a8c, -0x6d05, 0x6210,  0x1b64,  0x3f6f,  0x1a02,  0x65e4,
                -0x6795, 0x5867,  -0x6faf, -0x07cb, -0x762c, -0x7500, 0x1f1c,  -0x4348,
            }, .{
                0x72f6,  -0x5405, -0x3aac, 0x2857,  0x34cd,  -0x1dce, -0x56d8, 0x7150,
                -0x6549, 0x61bd,  -0x3a9f, -0x1e02, -0x5a5a, -0x7910, -0x166d, 0x7c8e,
                -0x5292, -0x6c6e, -0x37e3, 0x1514,  0x1787,  0x58cb,  -0x4d99, -0x6c15,
                0x592e,  -0x045f, 0x7682,  -0x1eef, 0x1fb2,  -0x7117, -0x2a17, -0x2d8e,
            });
            try testArgs(@Vector(64, i16), .{
                0x29c3,  -0x1b1f, -0x17ce, -0x50d0, -0x5de3, 0x5ffd,  0x184a,  -0x7769,
                0x445e,  0x0d8a,  0x7844,  -0x757d, 0x2b32,  0x5374,  -0x6ab2, -0x71c4,
                0x38f9,  0x347f,  0x2d4c,  0x69a4,  -0x2f92, -0x4479, 0x427b,  -0x0c5f,
                0x15ae,  0x2c86,  0x1864,  -0x0095, 0x6803,  -0x3484, 0x1001,  -0x0560,
                -0x0824, 0x7bf6,  0x7a3c,  -0x458a, -0x65cc, -0x54b1, -0x75c6, 0x782e,
                0x35a7,  -0x3188, -0x58ba, 0x40d0,  -0x4a9c, 0x6b79,  0x1ef5,  0x67a2,
                -0x3fb8, 0x1885,  -0x093d, -0x4802, 0x0379,  0x2f52,  0x7f1f,  0x256c,
                0x1052,  0x1b3b,  -0x6146, 0x7e0d,  0x79ca,  -0x79ee, 0x3d58,  0x7482,
            }, .{
                -0x0017, -0x3fdd, -0x6f93, 0x6178,  0x5c2b,  0x4eb3,  0x685b,  0x12c8,
                0x0290,  -0x34f4, -0x6572, 0x3ab6,  -0x3ed1, -0x5e5f, 0x3a90,  -0x4540,
                -0x2098, 0x6bde,  0x1246,  0x2212,  -0x4d6a, -0x2a5a, 0x5cc4,  -0x240f,
                0x51b2,  0x5ec0,  -0x5b5f, -0x1b6e, -0x57a5, -0x06bd, -0x5132, 0x7889,
                0x2817,  0x6ada,  -0x6b46, -0x6a37, -0x6475, -0x5ff4, 0x5a27,  0x1dfa,
                0x6bd6,  -0x49da, -0x09bf, -0x7c53, 0x2cd3,  -0x6be0, -0x2dca, 0x44bd,
                -0x1b95, 0x7680,  -0x5bb0, 0x7ad7,  -0x1988, 0x149f,  0x631e,  -0x1d2d,
                0x632b,  0x55c7,  -0x3433, 0x0dde,  -0x27a7, 0x560e,  -0x2063, 0x4570,
            });

            try testArgs(@Vector(1, u16), .{
                0x9d6f,
            }, .{
                0x44b1,
            });
            try testArgs(@Vector(2, u16), .{
                0xa0fa, 0xc365,
            }, .{
                0xe736, 0xc394,
            });
            try testArgs(@Vector(4, u16), .{
                0x9608, 0xa558, 0x161b, 0x206f,
            }, .{
                0x3088, 0xf25c, 0x7837, 0x9b3f,
            });
            try testArgs(@Vector(8, u16), .{
                0xcf61, 0xb121, 0x3cf1, 0x3e9f, 0x43a7, 0x8d69, 0x96f5, 0xc11e,
            }, .{
                0xee30, 0x82f0, 0x270b, 0x1498, 0x4c60, 0x6e72, 0x0b64, 0x02d4,
            });
            try testArgs(@Vector(16, u16), .{
                0x9191, 0xd23e, 0xf844, 0xd84a, 0xe907, 0xf1e8, 0x712d, 0x90af,
                0x6541, 0x3fa6, 0x92eb, 0xe35a, 0xc0c9, 0xcb47, 0xb790, 0x4453,
            }, .{
                0x21c3, 0x4039, 0x9b71, 0x60bd, 0xcd7f, 0x2ec8, 0x50ba, 0xe810,
                0xebd4, 0x06e5, 0xed18, 0x2f66, 0x7e31, 0xe282, 0xad63, 0xb25e,
            });
            try testArgs(@Vector(32, u16), .{
                0x6b6a, 0x30a9, 0xc267, 0x2231, 0xbf4c, 0x00bc, 0x9c2c, 0x2928,
                0xecad, 0x82df, 0xcfb0, 0xa4e5, 0x909b, 0x1b05, 0xaf40, 0x1fd9,
                0xcec6, 0xd8dc, 0xd4b5, 0x6d59, 0x8e3f, 0x4d8a, 0xb83a, 0x808e,
                0x47e2, 0x5782, 0x59bf, 0xcefc, 0x5179, 0x3f48, 0x93dc, 0x66d2,
            }, .{
                0x1be8, 0xe98c, 0xf9b3, 0xb008, 0x2f8d, 0xf087, 0xc9b9, 0x75aa,
                0xbd16, 0x9540, 0xc5bd, 0x2b2c, 0xd43f, 0x9394, 0x3e1d, 0xf695,
                0x167d, 0xff7a, 0xf09d, 0xdff8, 0xdfa2, 0xc779, 0x70b7, 0x01bd,
                0x46b3, 0x995a, 0xb7bc, 0xa79d, 0x5542, 0x961e, 0x37cd, 0x9c2a,
            });
            try testArgs(@Vector(64, u16), .{
                0x6b87, 0xfd84, 0x436b, 0xe345, 0xfb82, 0x81fc, 0x0992, 0x45f9,
                0x5527, 0x1f6d, 0xda46, 0x6a16, 0xf6e1, 0x8fb7, 0x3619, 0xdfe3,
                0x64ce, 0x8ac6, 0x3ae8, 0x30e3, 0xec3b, 0x4ba7, 0x02a4, 0xa694,
                0x8e68, 0x8f0c, 0x5e30, 0x0e55, 0x6538, 0x9852, 0xea35, 0x7be2,
                0xdabd, 0x57e6, 0x5b38, 0x0fb2, 0x2604, 0x85e7, 0x6595, 0x8de9,
                0x49b1, 0xe9a2, 0x3758, 0xa4d9, 0x505b, 0xc9d3, 0xddc5, 0x9a43,
                0xfd44, 0x50f5, 0x379e, 0x03b6, 0x6375, 0x692f, 0x5586, 0xc717,
                0x94dd, 0xee06, 0xb32d, 0x0bb9, 0x0e35, 0x5f8f, 0x0ba4, 0x19a8,
            }, .{
                0xbeeb, 0x3e54, 0x6486, 0x5167, 0xe432, 0x57cf, 0x9cac, 0x922e,
                0xd2f8, 0x5614, 0x2e7f, 0x19cf, 0x9a07, 0x0524, 0x168f, 0x4464,
                0x4def, 0x83ce, 0x97b4, 0xf269, 0xda5f, 0x28c1, 0x9cc3, 0xfa7c,
                0x25a0, 0x912d, 0x25b2, 0xd60d, 0xcd82, 0x0e03, 0x40cc, 0xc9dc,
                0x18eb, 0xc609, 0xb06d, 0x29e0, 0xf3c7, 0x997b, 0x8ca2, 0xa750,
                0xc9bc, 0x8f0e, 0x3916, 0xd905, 0x94f8, 0x397f, 0x98b5, 0xc61d,
                0x05db, 0x3e7a, 0xf750, 0xe8de, 0x3225, 0x81d9, 0x612e, 0x0a7e,
                0x2c02, 0xff5b, 0x19ca, 0xbbf5, 0x870e, 0xc9ca, 0x47bb, 0xcfcc,
            });

            try testArgs(@Vector(1, i17), .{
                0x0538f,
            }, .{
                0x01de0,
            });
            try testArgs(@Vector(2, i17), .{
                0x0cb5d, 0x00c0b,
            }, .{
                -0x0ef1d, -0x0797c,
            });
            try testArgs(@Vector(4, i17), .{
                -0x06cbb, 0x08fcd, 0x05d91, -0x05824,
            }, .{
                0x0714b, 0x09218, -0x0c0d8, 0x000dd,
            });
            try testArgs(@Vector(8, i17), .{
                0x0d8db, 0x0c58a, 0x09110, 0x0d637, -0x0a7e5, -0x00bc2, 0x08ffb, -0x0cf79,
            }, .{
                0x0a1ce, 0x0b491, 0x0aff1, -0x0b794, -0x085e7, 0x05c84, 0x040bc, 0x0f21f,
            });
            try testArgs(@Vector(16, i17), .{
                -0x0ccb0, -0x04d27, -0x0199e, -0x06dae, 0x0b1a1, 0x05324, -0x0edee, -0x0e52d,
                0x042d2,  0x06121,  0x0241f,  0x06833,  0x0a33b, 0x0f526, 0x0671a,  0x0c2a3,
            }, .{
                0x02be2, -0x08589, 0x0d95c,  -0x001cc, -0x03183, 0x08c1a,  -0x001db, 0x07604,
                0x08d92, 0x094ad,  -0x08aa5, -0x0b495, -0x0d6cd, -0x0dff1, -0x027f1, -0x0214e,
            });
            try testArgs(@Vector(32, i17), .{
                0x01222,  0x022bc,  0x042df,  0x02205,  -0x06de8, -0x0aaaf, 0x0fa4c,  -0x0c708,
                -0x06edd, -0x0acbe, 0x0b01f,  0x003f5,  -0x0b82a, 0x0a189,  -0x04f4b, 0x02122,
                -0x0debd, -0x0b05f, 0x091b6,  -0x074ff, 0x054e5,  -0x03355, 0x08ab0,  0x0c3c8,
                -0x0f488, -0x04304, -0x0168e, -0x0224a, -0x0cbaa, 0x0ac99,  -0x0f096, 0x0e064,
            }, .{
                0x0d1c0,  0x02f93,  0x0e28c,  0x0862d,  -0x09e1e, -0x02247, -0x01b56, 0x06633,
                0x0fdcc,  -0x0731f, 0x0e084,  0x0b865,  0x089ac,  -0x09e31, 0x0c730,  0x0af1d,
                0x0c9b2,  -0x0bbbd, -0x0f0a4, -0x0aba7, 0x0e593,  -0x02c83, -0x04e28, 0x0f375,
                -0x0e805, 0x0390f,  0x042a3,  -0x02aed, 0x03a5a,  0x070d3,  -0x0ed6a, 0x02b14,
            });
            try testArgs(@Vector(64, i17), .{
                0x0be66,  0x0e4fb,  -0x0b918, -0x029b8, 0x019e8,  0x00621,  0x0e380,  0x040f6,
                -0x0d095, 0x0b4d8,  -0x0a3ad, -0x0eaf2, 0x03bd3,  0x0635c,  0x02444,  -0x0830f,
                0x01239,  -0x037ed, -0x071d1, 0x057e7,  -0x02cdb, 0x0504c,  0x0612c,  -0x005bf,
                -0x04793, 0x03909,  0x0061c,  -0x06423, 0x040d6,  0x0bc6a,  -0x09204, 0x0e890,
                0x04b98,  0x00257,  0x0dc85,  -0x0af2b, -0x0a1e7, 0x04ff6,  0x0b680,  -0x07c61,
                -0x0eaff, -0x0da01, -0x04b21, -0x0088d, 0x068a8,  0x06b52,  -0x0d619, -0x09344,
                -0x09b96, 0x0b81e,  0x04df8,  -0x012f6, -0x0c3bd, 0x067cc,  -0x0fa47, -0x05e93,
                0x07d29,  0x00d87,  0x0de1f,  0x0d24f,  -0x0aede, -0x03414, -0x09a6c, 0x094dc,
            }, .{
                0x03d8e,  -0x0f297, -0x0d810, 0x05b8e,  -0x0630e, -0x0656f, 0x02f56,  0x0190b,
                0x0a1e6,  -0x0783a, -0x00bde, 0x01bb2,  -0x093a5, -0x02b3f, 0x0198c,  0x0cc55,
                0x04ec1,  -0x0ed31, -0x00a80, -0x0be6d, 0x0712b,  0x0451b,  0x067a4,  0x061cd,
                0x0e799,  -0x06c74, -0x09b05, 0x0dc73,  -0x0a87d, -0x0cf60, -0x00f07, 0x0b101,
                0x06d5b,  0x09d61,  -0x01092, 0x002ee,  0x0f192,  0x0024b,  0x04778,  0x06d05,
                -0x0e460, 0x08524,  -0x0ba27, -0x0611e, -0x0d944, -0x0a3de, -0x0c278, 0x015e5,
                0x071fe,  0x016d5,  -0x076e2, -0x035d8, 0x02763,  -0x0676f, -0x0a9aa, -0x0ab0b,
                0x012de,  -0x00d05, 0x0f528,  0x07837,  0x0fc4e,  -0x06304, 0x0616f,  -0x0b10d,
            });

            try testArgs(@Vector(1, u17), .{
                0x17ba6,
            }, .{
                0x1ac3a,
            });
            try testArgs(@Vector(2, u17), .{
                0x1d26d, 0x18548,
            }, .{
                0x0c0eb, 0x1bbc8,
            });
            try testArgs(@Vector(4, u17), .{
                0x1a01c, 0x12671, 0x175cc, 0x0ed36,
            }, .{
                0x141d6, 0x1b2bc, 0x1c2b9, 0x1eb18,
            });
            try testArgs(@Vector(8, u17), .{
                0x0cb1b, 0x0f5ce, 0x1eba1, 0x04fdc, 0x0510f, 0x02c4c, 0x09310, 0x132df,
            }, .{
                0x1b732, 0x0b446, 0x048a7, 0x04c58, 0x03a0b, 0x19346, 0x07688, 0x1d4d5,
            });
            try testArgs(@Vector(16, u17), .{
                0x1e6a3, 0x0eae5, 0x1065a, 0x18766, 0x1b70a, 0x1605b, 0x18256, 0x1e254,
                0x0d926, 0x0f023, 0x1d9de, 0x14549, 0x051dd, 0x1e89e, 0x0baba, 0x00f38,
            }, .{
                0x1e050, 0x0f727, 0x1dfef, 0x151a6, 0x05593, 0x04a79, 0x1c54c, 0x147b6,
                0x07173, 0x0480b, 0x094a6, 0x105ce, 0x0540c, 0x19d78, 0x15501, 0x1133a,
            });
            try testArgs(@Vector(32, u17), .{
                0x0d98a, 0x1c869, 0x12b2b, 0x1fc00, 0x00b1b, 0x1c7b9, 0x09dd0, 0x1b560,
                0x1f409, 0x18cdf, 0x04275, 0x07da6, 0x069e5, 0x12aa8, 0x0513a, 0x0dea5,
                0x00df4, 0x1f8da, 0x0df92, 0x07885, 0x1c4d7, 0x14e64, 0x09648, 0x040cb,
                0x04fc6, 0x122cb, 0x1022d, 0x1bbd5, 0x0fd59, 0x1978f, 0x17d5a, 0x06299,
            }, .{
                0x0086f, 0x023b6, 0x0d964, 0x0e90b, 0x1bd4b, 0x18f58, 0x09f26, 0x0a831,
                0x00c03, 0x03ad1, 0x01c05, 0x1aded, 0x1d300, 0x12529, 0x14124, 0x1e684,
                0x1b40d, 0x09328, 0x1a3b6, 0x1e492, 0x00f2a, 0x13b51, 0x1606e, 0x1d7f1,
                0x0a5e6, 0x04172, 0x1aaea, 0x1e96f, 0x1c3ae, 0x11494, 0x06aac, 0x01dee,
            });
            try testArgs(@Vector(64, u17), .{
                0x1b753, 0x10620, 0x0c1de, 0x1fa10, 0x118bf, 0x0a549, 0x06b32, 0x095dc,
                0x177a2, 0x0aee7, 0x0f2cf, 0x118e0, 0x0b694, 0x0f270, 0x00917, 0x0048c,
                0x1d903, 0x1de14, 0x10aa2, 0x06885, 0x1bba1, 0x0a5c5, 0x19373, 0x01355,
                0x153f9, 0x18b94, 0x0e8a3, 0x0cc07, 0x0a014, 0x0f9ed, 0x02d95, 0x18388,
                0x01de4, 0x0c8fa, 0x15858, 0x0ff57, 0x1fc97, 0x18d83, 0x11836, 0x0f136,
                0x0d4e3, 0x1742d, 0x09f22, 0x088cf, 0x134f8, 0x1b9a8, 0x11fd2, 0x18428,
                0x17411, 0x146e1, 0x0edea, 0x1d57d, 0x04059, 0x18b93, 0x10fc8, 0x01cd7,
                0x12d54, 0x0cb27, 0x04fc3, 0x0d479, 0x0202c, 0x0cfab, 0x11e82, 0x000e7,
            }, .{
                0x0122f, 0x06698, 0x0c704, 0x012de, 0x0e36c, 0x0d81b, 0x00d34, 0x10ad6,
                0x1f156, 0x00fca, 0x1f869, 0x1d14b, 0x13165, 0x1e11e, 0x1e60c, 0x00d18,
                0x164bf, 0x1881f, 0x18a59, 0x14f13, 0x04ef2, 0x0e2a7, 0x021b0, 0x15884,
                0x1ac75, 0x19969, 0x1353d, 0x073ec, 0x190ef, 0x1c777, 0x14b19, 0x12e43,
                0x1b93f, 0x06daf, 0x02a1f, 0x1a801, 0x0facc, 0x132db, 0x13fb2, 0x00791,
                0x11f11, 0x0ebc1, 0x0a376, 0x10e6d, 0x0321c, 0x154d7, 0x01180, 0x0cce1,
                0x1a449, 0x0383b, 0x0d5bb, 0x0e5dd, 0x07e94, 0x08f78, 0x1c681, 0x1a146,
                0x170db, 0x0da34, 0x1bd7f, 0x07a96, 0x0a017, 0x0b946, 0x0f98a, 0x0e9e5,
            });

            try testArgs(@Vector(1, i31), .{
                0x2b94a60e,
            }, .{
                0x20451023,
            });
            try testArgs(@Vector(2, i31), .{
                0x21d4d18c, -0x1f73454a,
            }, .{
                -0x18dcc667, -0x2e81b7f1,
            });
            try testArgs(@Vector(4, i31), .{
                -0x1d8f56b6, -0x2beae9b1, 0x3d488b10, -0x14ce8669,
            }, .{
                -0x03a922a5, -0x0ea0c434, -0x029db0c1, -0x3b8d64f3,
            });
            try testArgs(@Vector(8, i31), .{
                0x0ffaa22c,  0x15914f94,  -0x20cec195, -0x35e7b06a,
                -0x1d212622, -0x2bb576e4, -0x0dede257, 0x1cc1066e,
            }, .{
                -0x178ffdb4, -0x10934a93, 0x08c3b058,  -0x1579a89f,
                0x2340c302,  0x00280e85,  -0x38983c31, 0x0349891e,
            });
            try testArgs(@Vector(16, i31), .{
                -0x11bc6f72, 0x1ca1ca00,  0x0b49c711,  -0x07fd7d21,
                0x20ab59d2,  -0x07f45e94, -0x0d33151d, 0x065b8bff,
                0x2231354e,  0x21ff00a7,  -0x35061bb0, -0x1135899e,
                0x2ed1c690,  -0x1c1b598f, -0x19157726, -0x11c4d2c7,
            }, .{
                0x304dbbfb,  -0x3e59fd39, 0x1029151a,  -0x1e4d2063,
                -0x3e164c14, -0x35fb3d09, -0x22070b0d, 0x1b730749,
                0x380ae142,  0x357f1b30,  -0x17ccaa0d, -0x32cd12b4,
                0x305256f7,  -0x298ce473, 0x244faaf4,  0x23450241,
            });
            try testArgs(@Vector(32, i31), .{
                -0x2e3a0d66, -0x0df709be, 0x3bfd8b3f,  0x2a4f2d06,
                -0x2b7ea7af, -0x28016bef, -0x34a3b4f9, -0x2dfdded7,
                0x357e8c45,  0x0434b6b9,  0x28a3c5f9,  0x2d5b9944,
                0x316614a1,  0x0c12a228,  0x0422665d,  0x33c0dec9,
                0x0a7ede17,  -0x02e88ae9, -0x39e76560, 0x1e4b90af,
                0x0a1527bb,  0x3a9f0405,  0x163b6eae,  -0x3ff84429,
                0x1eb85fcc,  0x265f1f44,  0x2536ec34,  -0x30c952a2,
                -0x1f7864e5, 0x033737cd,  -0x20b5718a, -0x0aad3a2f,
            }, .{
                -0x2455af85, 0x210b1040,  0x39915c7d,  0x2d56c08e,
                0x1f318b8d,  -0x1e125926, -0x3faaabbb, -0x254d4da5,
                -0x1b2ded0f, -0x27fa4874, 0x02c0d73b,  0x123e9344,
                0x0351c023,  0x14cca255,  -0x2072b9d7, 0x1e624059,
                -0x07d014a1, 0x2eda3228,  -0x300ff9b4, 0x333f25ad,
                -0x3c653e21, 0x04b4a50e,  -0x20f17e80, 0x29063cd1,
                0x2d52f6ad,  -0x0b2cdb6b, -0x2e4c9778, 0x303ded7c,
                0x397162ee,  -0x2aa6708b, -0x0ef146b4, 0x04f36039,
            });

            try testArgs(@Vector(1, u31), .{
                0x3ed1fb2d,
            }, .{
                0x1b75c3fd,
            });
            try testArgs(@Vector(2, u31), .{
                0x38754d45, 0x04a454d9,
            }, .{
                0x7d06646d, 0x228e6c44,
            });
            try testArgs(@Vector(4, u31), .{
                0x725a3790, 0x43680c3d, 0x058a6acf, 0x76172c1c,
            }, .{
                0x77fa9932, 0x7354fc00, 0x1756db7a, 0x559bf7c1,
            });
            try testArgs(@Vector(8, u31), .{
                0x375a41f8, 0x761db971, 0x1c633348, 0x556c2682,
                0x2478e967, 0x4fc61f7d, 0x0b0c0fbc, 0x3989659e,
            }, .{
                0x2cd6c7c1, 0x518c1da4, 0x2a52dd59, 0x0a9165dd,
                0x5f2a31fd, 0x04dd2dba, 0x6eb0e7f6, 0x078c7a78,
            });
            try testArgs(@Vector(16, u31), .{
                0x4d4ae18f, 0x3f131977, 0x337240bd, 0x4461dafc,
                0x36bf5c5f, 0x527cca5e, 0x788a765b, 0x51da84b2,
                0x58afe262, 0x289694c8, 0x7f3dc333, 0x05f123e9,
                0x49182e11, 0x05ec0bb8, 0x0a760c6a, 0x4e74999f,
            }, .{
                0x107f6e90, 0x38d44d8e, 0x4b3adb3c, 0x7d6c21c0,
                0x3ec0863b, 0x72422c85, 0x45e72de4, 0x07fc07d3,
                0x7e30044d, 0x3ee5687d, 0x34037d8f, 0x1f3e1e71,
                0x77aec6b0, 0x02db5151, 0x697fe49b, 0x49f9ad57,
            });
            try testArgs(@Vector(32, u31), .{
                0x3b815f8c, 0x01c443d3, 0x22f036bf, 0x3d86e477,
                0x3f631301, 0x51df4ff2, 0x7edd9a1c, 0x1b8d97fc,
                0x7758837d, 0x23944d5a, 0x6b6fe951, 0x1cea3c27,
                0x27033a47, 0x00b7643b, 0x407e47c9, 0x6004a994,
                0x2efac78c, 0x22720791, 0x4308438b, 0x7776b2be,
                0x139db08a, 0x4d9068a5, 0x4e26c811, 0x5e05d0a0,
                0x0a651f83, 0x7f7a1fcc, 0x6b0f3eb0, 0x3467ea73,
                0x4827410b, 0x3e48eece, 0x73a3abf5, 0x212b7737,
            }, .{
                0x13031751, 0x08fb38ec, 0x4aff2c4e, 0x25046a42,
                0x0e9e35bf, 0x27349249, 0x54067ba1, 0x5a229b53,
                0x6e68895f, 0x74f3d476, 0x6584d407, 0x0ef73f77,
                0x2473e0ce, 0x3b936b7c, 0x2cf9dd51, 0x7100aa6b,
                0x6dca745e, 0x739f6346, 0x32407063, 0x40de144d,
                0x3dc73803, 0x3afedeab, 0x56cbbfe7, 0x4273c6db,
                0x7b2eeb85, 0x6bf11881, 0x4e8148c7, 0x7b8daec4,
                0x75c63050, 0x0001d08d, 0x7f14dd77, 0x13f23338,
            });

            try testArgs(@Vector(1, i32), .{
                0x7aef7b1e,
            }, .{
                0x60310858,
            });
            try testArgs(@Vector(2, i32), .{
                -0x21910ac9, 0x669f37ef,
            }, .{
                0x1a2a1681, 0x003b1fdf,
            });
            try testArgs(@Vector(4, i32), .{
                0x7906cf0d, 0x4818a45f, -0x0a2833b6, 0x51a018c9,
            }, .{
                -0x05a3e6a7, -0x47f4a500, 0x50d1141f, -0x264c85c2,
            });
            try testArgs(@Vector(8, i32), .{
                0x7566235a,  -0x7720144f, -0x7d4f5489, 0x3cd736c8,
                -0x77388801, 0x4e7f955a,  0x4cdf52bc,  0x50b0b53f,
            }, .{
                0x00ed6fc5, 0x37320361, 0x70c563c2,  -0x09acb495,
                0x0688e83f, 0x797295c4, -0x23bfbfdb, 0x38552096,
            });
            try testArgs(@Vector(16, i32), .{
                -0x0214589d, 0x74a7537f,  0x7a7dcb26, 0x3e2e4c44,
                -0x23bfc358, 0x60e8ef18,  0x5524a7bc, -0x3d88c153,
                -0x7dc8ff0f, 0x6e2698f6,  0x05641ab8, -0x45e9e405,
                -0x7c1a04d0, -0x4a8d1e91, 0x41d56723, 0x4ba924ab,
            }, .{
                -0x528dc756, -0x6bc217f4, 0x40789b06, 0x65f08d3a,
                -0x077140ea, -0x43bdaa79, 0x5d98f4e7, -0x2356a1ca,
                -0x36ef2b49, -0x7cd09b06, 0x71c8176e, 0x5b005860,
                0x6ce8cfab,  -0x49fd7609, 0x6cbb4e33, 0x6c7c121d,
            });
            try testArgs(@Vector(32, i32), .{
                0x7d22905d,  -0x354e4bbe, -0x68662618, -0x246e1858,
                -0x1c4285a9, -0x0338059c, -0x60f5bbf4, -0x04f06917,
                -0x55f837b6, -0x2fba5fe3, 0x092aabf4,  -0x5f533b31,
                0x6e81a558,  -0x7bcac358, 0x6c4d8d04,  0x3e2f9852,
                -0x78589b1a, -0x68a00fd4, -0x77d55e25, 0x7f79b51c,
                -0x66b88f45, 0x7f6dc8a5,  -0x27299a82, -0x426c8e1c,
                0x0c288f16,  0x158f8c3f,  0x26708be1,  -0x0b73626e,
                -0x32df1bee, 0x196330f4,  -0x68bb9529, -0x26376ab6,
            }, .{
                0x63bd0bd4,  0x4e507611,  -0x5e5222b8, -0x35d8e114,
                0x1feab77b,  -0x20de7dfd, -0x0ed0b09f, -0x7fc3d585,
                -0x2d3018e9, -0x261d431b, 0x54451864,  0x1415288f,
                -0x3ab89593, -0x7060e4c1, -0x54fcd501, -0x26324630,
                0x53fc8294,  0x2d4aceef,  -0x4ac8efd2, -0x2fec97b7,
                -0x4de3a2fc, 0x2269fe52,  -0x58c8b473, -0x21026285,
                -0x23438776, 0x3d5c8c41,  -0x1fc946b2, -0x161c7005,
                0x44913ff1,  -0x76e2bfaa, -0x54636350, -0x6ec53870,
            });

            try testArgs(@Vector(1, u32), .{
                0x1d0d9cc4,
            }, .{
                0xce2d0ab6,
            });
            try testArgs(@Vector(2, u32), .{
                0x5ab78c03, 0xd21bb513,
            }, .{
                0x8a6664eb, 0x79eac37d,
            });
            try testArgs(@Vector(4, u32), .{
                0x234d576e, 0x4151cc9c, 0x39f558e4, 0xba935a32,
            }, .{
                0x398f2a9d, 0x4540f093, 0x9225551c, 0x3bac865b,
            });
            try testArgs(@Vector(8, u32), .{
                0xb8336635, 0x2fc3182c, 0x27a00123, 0x71587fbe,
                0x9cbc65d2, 0x6f4bb0e6, 0x362594ce, 0x9971df38,
            }, .{
                0x5727e734, 0x972b0313, 0xff25f5dc, 0x924f8e55,
                0x04920a61, 0xa1c3b334, 0xf52df4b6, 0x5ef72ecc,
            });
            try testArgs(@Vector(16, u32), .{
                0xfb566f9e, 0x9ad4691a, 0x5b5f9ec0, 0x5a572d2a,
                0x8f2f226b, 0x2dfc7e33, 0x9fb07e32, 0x9d672a2e,
                0xbedc3cee, 0x6872428d, 0xbc73a9fd, 0xd4d5f055,
                0x69c1e9ee, 0x65038deb, 0x1449061a, 0x48412ec2,
            }, .{
                0x96cbe946, 0x3f24f60b, 0xaeacdc53, 0x7611a8b4,
                0x031a67a8, 0x52a26828, 0x75646f4b, 0xb75902c3,
                0x1f881f08, 0x834e02a4, 0x5e5b40eb, 0xc75c264d,
                0xa8251e09, 0x28e46bbd, 0x12cb1f31, 0x9a2af615,
            });
            try testArgs(@Vector(32, u32), .{
                0x131bbb7b, 0xa7311026, 0x9d5e59a0, 0x99b090d6,
                0xfe969e2e, 0x04547697, 0x357d3250, 0x43be6d7a,
                0x16ecf5c5, 0xf60febcc, 0x1d1e2602, 0x138a96d2,
                0x9117ba72, 0x9f185b32, 0xc10e23fd, 0x3e6b7fd8,
                0x4dc9be70, 0x2ee30047, 0xaffeab60, 0x7172d362,
                0x6154bfcf, 0x5388dc3e, 0xd6e5a76e, 0x8b782f2d,
                0xacbef4a2, 0x843aca71, 0x25d8ab5c, 0xe1a63a39,
                0xc26212e5, 0x0847b84b, 0xb53541e5, 0x0c8e44db,
            }, .{
                0x4ad92822, 0x715b623f, 0xa5bed8a7, 0x937447a9,
                0x7ecb38eb, 0x0a2f3dfc, 0x96f467a2, 0xec882793,
                0x41a8707f, 0xf7310656, 0x76217b80, 0x2058e5fc,
                0x26682154, 0x87313e31, 0x4bdc480a, 0x193572ff,
                0x60b03c75, 0x0fe45908, 0x56c73703, 0xdb86554c,
                0xdda2dd7d, 0x34371b27, 0xe4e6ad50, 0x422d1828,
                0x1de3801b, 0xdce268d3, 0x20af9ec8, 0x188a591f,
                0xf080e943, 0xc8718d14, 0x3f920382, 0x18d101b5,
            });

            try testArgs(@Vector(1, i33), .{
                0x0a9a3088e,
            }, .{
                0x06c76b26e,
            });
            try testArgs(@Vector(2, i33), .{
                0x0a9bd1d56, 0x05b0b9015,
            }, .{
                -0x05af6217c, 0x0227b5d3a,
            });
            try testArgs(@Vector(4, i33), .{
                -0x0405ee2ea, -0x0ff2c72eb, 0x0817f6727, 0x09093b663,
            }, .{
                -0x0ffdf18ee, 0x0956db821, -0x01ed194af, 0x059e085e9,
            });
            try testArgs(@Vector(8, i33), .{
                0x09d4fea1c,  0x0cd4254ba,  0x008d5f732,  0x0566c6f55,
                -0x01c2e54c3, -0x0469292fe, -0x00ba9ba6f, -0x076670146,
            }, .{
                0x02c01d901, 0x04407fcae,  -0x0e6a223a6, -0x0bd9499f8,
                0x0f9da76ed, -0x07483b289, -0x0bfc2d58e, -0x078b3055e,
            });
            try testArgs(@Vector(16, i33), .{
                -0x05a738cb0, -0x0be006f3e, 0x09271a365, 0x039d2f00d,
                -0x0d502b660, 0x0dd465278,  0x042a7e451, 0x03c1c3671,
                0x00eb6f4a9,  0x08982dbc4,  0x0421b8852, 0x015ee0e53,
                0x0e6924014,  0x0c6ddbc65,  0x00260ea59, 0x0d98aaedf,
            }, .{
                -0x0d285a53d, 0x0800f42de, -0x048e48809, -0x052d65f47,
                -0x0bda689e0, 0x0bc437a1b, -0x05cc595ba, 0x04b335861,
                -0x0f5ec6456, 0x0580ceda6, 0x06f0e76c9,  0x0b0064ff1,
                -0x0eae28371, 0x075c3c6b1, 0x07c8d26dd,  -0x06af4f476,
            });
            try testArgs(@Vector(32, i33), .{
                0x07b887609,  -0x004a23b00, 0x09b664a97,  -0x0d4932ed0,
                -0x01a63850e, -0x0a4298efc, -0x01e409b55, 0x01452fb7a,
                0x03d12175b,  -0x0463cd854, 0x0cf448f1d,  0x0d1d02e2e,
                -0x0da681c00, 0x0d1173267,  0x08faa4e2c,  0x0634c9df5,
                0x037e682e2,  0x0db055022,  -0x0641f3daa, 0x053852c9b,
                0x035822a2b,  -0x0b12bfe53, 0x084f704c9,  0x018cfacee,
                -0x07130725b, -0x0b301dece, 0x00e1765b3,  -0x0e0f0c97c,
                0x0ccd5e7fd,  -0x0ee60c481, -0x0c918345b, 0x04b2c6ec3,
            }, .{
                0x0df3d6e88,  0x00b4748ff,  -0x0d0381c05, -0x093d68cb5,
                -0x027834cc7, 0x05aa9ca20,  -0x04bc88f40, 0x080f0d937,
                0x06699a6b8,  -0x0fed64f1d, 0x0a79fe089,  -0x016a9c385,
                0x0186e6b5b,  -0x0a3c83fe6, 0x09a4f87ec,  0x011ce03bf,
                -0x0f742cb8c, 0x066be2e66,  -0x03b0beb52, 0x059bfda10,
                0x04bc221c0,  0x07d8b0344,  -0x0c6e34f34, -0x0de0338ce,
                -0x09571f80c, 0x0d36e8ea7,  -0x052c44147, 0x0072ce503,
                -0x0ef8dec64, 0x0b5956cb3,  -0x02b72b4b1, 0x0f2585167,
            });

            try testArgs(@Vector(1, u33), .{
                0x197ead992,
            }, .{
                0x0be595917,
            });
            try testArgs(@Vector(2, u33), .{
                0x1485499a5, 0x1e12b23e3,
            }, .{
                0x1431cd300, 0x0762a7b51,
            });
            try testArgs(@Vector(4, u33), .{
                0x00d6f907d, 0x19a2c1e5e, 0x18a597564, 0x0bea832ed,
            }, .{
                0x004f8c83b, 0x18fd5422c, 0x1b02cb79b, 0x092af8ba2,
            });
            try testArgs(@Vector(8, u33), .{
                0x100a8bdce, 0x182aa3624, 0x0a0523393, 0x0cc8b944f,
                0x0797fe181, 0x19c2ef2f6, 0x1b43977a0, 0x1513a878a,
            }, .{
                0x10da86327, 0x16e25c8c1, 0x036e09027, 0x1d85d870c,
                0x0ff720340, 0x07d3901ec, 0x03df35db0, 0x0b3e4a05e,
            });
            try testArgs(@Vector(16, u33), .{
                0x1c323b838, 0x03e15bdff, 0x0d11e109b, 0x152199f53,
                0x1f3fc1542, 0x0e7b471e0, 0x0d291cc97, 0x1f5576bf6,
                0x1c64d5f2e, 0x1468c9947, 0x18f1bb596, 0x0250829ac,
                0x08d1b66a0, 0x1102178a6, 0x03eaf21e6, 0x1d0012275,
            }, .{
                0x11bcb3f84, 0x13150388c, 0x0e41a521a, 0x1c6c23e22,
                0x130ac516c, 0x02d3a49c2, 0x1dd028aca, 0x1b83e56ef,
                0x161d93875, 0x0a0fcb218, 0x1d27943a8, 0x09c919906,
                0x182582997, 0x1c2acc0c7, 0x1cb8a9324, 0x0f456f948,
            });
            try testArgs(@Vector(32, u33), .{
                0x1819f161e, 0x11b0c6f8b, 0x10e54ef82, 0x0f56ffe99,
                0x1c128ddba, 0x0c70e8d84, 0x15e26011b, 0x1ed2f16e4,
                0x1c498769a, 0x1b3a95b06, 0x0580ebb27, 0x16ef0aa01,
                0x00a5a7986, 0x011a5fbf1, 0x092059f35, 0x065d9a218,
                0x18b3c3508, 0x1f8a52f0b, 0x12a0c771c, 0x15c566333,
                0x0882ec701, 0x0856047ee, 0x06974b33a, 0x049a97da9,
                0x103730040, 0x0fabaaafc, 0x08e6b9887, 0x12e97722d,
                0x00a2e302f, 0x144df5d90, 0x1dcc2f7d4, 0x1b6a6c079,
            }, .{
                0x13e4aa8fb, 0x1ff2fa13d, 0x0fd3d4549, 0x10837c43c,
                0x1db62d7c2, 0x0e92f9f8b, 0x10c7ee602, 0x0e010e5f6,
                0x1b216ca4f, 0x15808c554, 0x1ff8df1f7, 0x0c30cb60b,
                0x191d83ae9, 0x17dc4326a, 0x1ff1e287e, 0x12e08bb58,
                0x17787d83b, 0x074306807, 0x0ad4d40f7, 0x157b2e8a1,
                0x1830cc0d0, 0x18e688eec, 0x1f87405f3, 0x19443ff22,
                0x16ebfdd93, 0x07bb98b57, 0x01cd6f301, 0x08adbcc33,
                0x1ffbcb919, 0x007455180, 0x1edbabfcb, 0x0b5519b97,
            });

            try testArgs(@Vector(1, i63), .{
                -0x2d99033c3223ad4f,
            }, .{
                0x023c8c6807737a0e,
            });
            try testArgs(@Vector(2, i63), .{
                -0x08fe3255607ce099, -0x3bf678cfa16a59d2,
            }, .{
                -0x1b8733d130c49d54, 0x39deb4fe6c836b3f,
            });
            try testArgs(@Vector(4, i63), .{
                0x1e81cf3e0f9eae80, -0x0886f09bd1723b08,
                0x16e84b8d985e5b82, 0x0fa327538c09a281,
            }, .{
                -0x2594908bb49f963f, -0x29639632db767665,
                0x012d5330f966e1be,  -0x1143fddd48bf9752,
            });
            try testArgs(@Vector(8, i63), .{
                -0x08e352cf330c1852, -0x17bc1f760120ff85,
                -0x0f180e5c748c0e20, 0x07ee9290e2d53335,
                -0x33945ea070fbb445, 0x104802af8984525d,
                0x36d27ad0f35fcfd8,  0x292141a0133227a0,
            }, .{
                0x2adad30092da2886,  -0x1694bcdda9b82c45,
                0x1f5a019d638ba22c,  -0x2e7853134888b613,
                -0x2bb77a420f280a6d, -0x377771e94e493751,
                0x1dd5373311160f2f,  -0x02bb5248b7e0c55e,
            });
            try testArgs(@Vector(16, i63), .{
                0x2d930d47aa078416,  0x1edf9abe8d562bd5,
                0x3ef3a5266f822396,  -0x102f82f23c5608e1,
                -0x38755dccf6c87ae1, 0x09f11b107d033f85,
                0x079829e968213db8,  0x17248ef600ddb53d,
                0x19e16a7a4e6aa0cc,  0x11e21ddfb7b5b946,
                0x26ad3768e80b1258,  0x3672a14b31cb7f1a,
                0x3235b83f829966b4,  0x3b4009ac38f728b8,
                -0x205d4b6cd8a164ad, -0x2fc581f11fa0eb42,
            }, .{
                -0x1428b8c4947715ea, -0x0a5626024843736e,
                0x075a1a0d0d47f0af,  0x0ea460d282e8dcc0,
                -0x124b2a6e2957dc53, -0x0d2602075af449d5,
                -0x0db76b825400293c, -0x17c13cd693d2db13,
                0x0ad907bb94e64687,  -0x05fd33e10be897ad,
                -0x3210cf60aa544f0b, -0x10f80c3ee6d7c510,
                0x0106683b57f2cf9e,  0x353bea8a4c199155,
                0x3942af4e40b65cb0,  0x3da0254a739aa17a,
            });

            try testArgs(@Vector(1, u63), .{
                0x17beef25621255fb,
            }, .{
                0x79bc7e82d16c5e15,
            });
            try testArgs(@Vector(2, u63), .{
                0x58aeb180f136af8b, 0x0ed5f2cdb8ffe659,
            }, .{
                0x5df7aae04a4a1126, 0x53568966decbd14f,
            });
            try testArgs(@Vector(4, u63), .{
                0x3d50a0f4755d87e3, 0x722e93c0b1355665,
                0x3c8325a3e3640be1, 0x34eef2706884b9ab,
            }, .{
                0x2671797fd253520d, 0x22f81938e525536e,
                0x08ca256b0b348d57, 0x1cdbe1867f422280,
            });
            try testArgs(@Vector(8, u63), .{
                0x49ab492d75830041, 0x28f4065197f361cf,
                0x3fcebb5fe8968a08, 0x0ab4e3fd7b158803,
                0x7f517fcfc0451068, 0x05eaa5d2f93407b2,
                0x0fe06447fdbec4d6, 0x34862504232f73d8,
            }, .{
                0x64a1796fe76dcc4d, 0x159bd1a9228a8c41,
                0x093a4794b5759276, 0x40a740fa4d288585,
                0x5d2d1aede616f40e, 0x7e7af17ddce8e03e,
                0x7555fb4a1c18d5ff, 0x11b45e151e8724d0,
            });
            try testArgs(@Vector(16, u63), .{
                0x456de088589c1035, 0x23239ed26d0e198f,
                0x4f3c4ae380a12430, 0x1cb11ef73131a6f4,
                0x6e51a370969ec7ae, 0x38bed7b267bb163d,
                0x2fcfab012fb79669, 0x45e203406a43fe95,
                0x38468cff64a44f74, 0x3cc86f1d717e8c60,
                0x2ae5f2a7c73c6c2c, 0x0c8856138b43dff8,
                0x1a7493c9bb7b265c, 0x6e8536e5f32317d8,
                0x634701c32688fd34, 0x7a4e4a7f35ef9651,
            }, .{
                0x3da82f0beb7a091d, 0x040c9bbf428787fa,
                0x795418c55742e8d2, 0x700f9b62c01cdf30,
                0x78d567c18e7ce16d, 0x300da37dc14b6705,
                0x68bf0e06ec9054ca, 0x2e45a80bcd5dd30d,
                0x00e8c13b3acf4557, 0x19adb837145a0267,
                0x594889dd8e1ff4c2, 0x561da6bd7e2ba593,
                0x6a8ed2f67f586604, 0x2ce6d9d2663cb1fc,
                0x68ec40831cb6b863, 0x2862d922ed7a78eb,
            });

            try testArgs(@Vector(1, i64), .{
                0x4a31679b316d8b59,
            }, .{
                0x34a583368386afde,
            });
            try testArgs(@Vector(2, i64), .{
                0x3bae373f9cb990b3, -0x7e8c6c876e8fd34a,
            }, .{
                0x09dbef6f7cb9c726, 0x48dfeca879b0df51,
            });
            try testArgs(@Vector(4, i64), .{
                -0x2bd24dd5f5da94bf, -0x144113bae33082c2,
                0x51e8cb7027ba4b12,  -0x47b02168e2e22f13,
            }, .{
                0x769f113245641b91,  -0x414d0e24ea97bc53,
                -0x0d2a570e7ef9e923, -0x070513d46d3b5a4c,
            });
            try testArgs(@Vector(8, i64), .{
                0x10bb6779b6a55ca9,  0x5f6ffd567a187af4,
                -0x6ba191b1168486b4, -0x441b92ce455870a1,
                0x2b6fdefbec9386ad,  -0x6fdd3938d79217e4,
                0x6aa8fe1fb891501f,  0x20802f5bbdf6dc50,
            }, .{
                -0x7500319df437b479, 0x00ceb712d4fa62d4,
                0x67e715b9e99e660d,  -0x17ae00e1f0009ec2,
                -0x5b700b948503acdf, -0x3ff61fb5cce5a530,
                0x55a3efac2e3694a4,  0x7f951a8d842f1670,
            });
            try testArgs(@Vector(16, i64), .{
                0x37a205109a685810,  -0x50ff5d13134ccaa6,
                0x26813391c5505d5d,  -0x502cdc01603a2f21,
                -0x6b1b44b1c850c7ea, 0x1f6db974ace9dd70,
                -0x47d15da8b519e328, 0x3ac0763abbf79d8d,
                0x5f12e0dc1aed4a4f,  -0x46a973e16061e928,
                -0x3f59a3fa9699b4d5, -0x2f5012d390c78315,
                -0x40e510dea2c47e9c, 0x221c51defe0acc9a,
                -0x385fd6f1d390b84b, 0x35932fe2783fa6b9,
            }, .{
                0x0ba5202b71ad73dd,  0x65c8d2d5e2a14fe5,
                0x2e4d97cd66c41a3d,  0x14babbb47da51193,
                0x59d1d12b42ade3aa,  -0x3c3617e556dfa8fb,
                -0x5a36602ba43279c4, -0x61f1ddda13665d9f,
                -0x50cd6128589ddd04, 0x135ae0dcc85674ae,
                -0x25e80592affc038d, 0x07e184c44fbe9b12,
                -0x70ede1b90964bbaa, 0x3ec48b32e8efd98e,
                -0x5267d41d85a29f46, 0x53099805f9116b60,
            });

            try testArgs(@Vector(1, u64), .{
                0x333f593bf9d08546,
            }, .{
                0x6918bd767e730778,
            });
            try testArgs(@Vector(2, u64), .{
                0x4cd89a317b03d430, 0x28998f61842f63a9,
            }, .{
                0x6c34db64af0e217e, 0x57aa5d02cd45dceb,
            });
            try testArgs(@Vector(4, u64), .{
                0x946cf7e7484691c9, 0xf4fc5be2a762fcbf,
                0x71cc83bc25abaf14, 0xc69cef44c6f833a1,
            }, .{
                0x9f90cbd6c3ce1d4e, 0x182f65295dff4e84,
                0x4dfe62c59fed0040, 0x18402347c1db1999,
            });
            try testArgs(@Vector(8, u64), .{
                0x92c6281333943e2c, 0xa97750504668efb5,
                0x234be51057c0181f, 0xefbc1f407f3df4fb,
                0x8da6cc7c39cebb94, 0xb408f7e56feee497,
                0x2363f1f8821592ed, 0x01716e800c0619e1,
            }, .{
                0xa617426684147e7e, 0x7542da7ebe093a7b,
                0x3f21d99ac57606b7, 0x65cd36d697d22de4,
                0xed23d6bdf176c844, 0x2d4573f100ff7b58,
                0x4968f4d21b49f8ab, 0xf5d9a205d453e933,
            });
            try testArgs(@Vector(16, u64), .{
                0x2f61a4ee66177b4a, 0xf13b286b279f6a93,
                0x36b46beb63665318, 0x74294dbde0da98d2,
                0x3aa872ba60b936eb, 0xe8f698b36e62600b,
                0x9e8930c21a6a1a76, 0x876998b09b8eb03c,
                0xa0244771a2ec0adb, 0xb4c72bff3d3ac1a2,
                0xd70677210830eced, 0x6622abc1734dd72d,
                0x157e2bb0d57d6596, 0x2aac8192fb7ef973,
                0xc4a0ca92f34d7b13, 0x04300f8ad1845246,
            }, .{
                0xeaf71dcf0eb76f5d, 0x0e84b1b63dc97139,
                0x0f64cc38d23c94a1, 0x12775cf0816349b7,
                0xfdcf13387ba48d54, 0xf8d3c672cacd8779,
                0xe728c1f5eb56ab1e, 0x05931a34877f7a69,
                0x1861a763c8dafd1f, 0x4ac97573ecd5739f,
                0x3384414c9bf77b8c, 0x32c15bbd04a5ddc4,
                0xbfd88aee1d82ed32, 0x20e91c15b701059a,
                0xed533d18f8657f3f, 0x1ddd7cd7f6bab957,
            });

            try testArgs(@Vector(1, i65), .{
                0x0ca0853f57c0686c8,
            }, .{
                -0x05c79d7369ef879fd,
            });
            try testArgs(@Vector(2, i65), .{
                0x0c65f685f4839bc8d, -0x079057ad04859d897,
            }, .{
                -0x0dbb1951a67a71fc6, -0x0d4763ead1d5f66aa,
            });
            try testArgs(@Vector(4, i65), .{
                0x0d6a03163f101695e,  -0x0ebe991e54e61156d,
                -0x0715adf48176985dc, 0x01e57dbe6ea50b22f,
            }, .{
                -0x0b308d8311a45a38d, 0x07c292cc15044b1f5,
                0x0e69e3eae81046bc8,  0x053b75d6a544ca0db,
            });
            try testArgs(@Vector(8, i65), .{
                0x0066315a88896ba00,  0x026c8109f087eb4e3,
                -0x0b9928ad2e41d98ef, 0x0fc5ab9c89a8ee6ff,
                0x0dcdd248c4575dbb1,  -0x09db7d03c38a83255,
                -0x097bc9d5397c57594, 0x0e6af866eed43b462,
            }, .{
                -0x06ac0448a06876866, 0x0f89dbafcbbb065d7,
                -0x02b88b31ed9fc24dd, -0x005c56246687ed4f0,
                -0x085a4a7b09dcec260, -0x0068e92e14823a98a,
                -0x0ac4a04dd6de87eb9, 0x0716ed52ef9704b71,
            });
            try testArgs(@Vector(16, i65), .{
                -0x09fd6493584cf3a50, 0x0e6dc4b5655cb9d36,
                -0x03b55c156ac2bdcf1, 0x002cfefc233d5bcb8,
                0x0dbebb830228d2945,  -0x02133deab2ebd8699,
                -0x0ff9bc10c14c58c6c, -0x09170272ba214dabc,
                -0x06ed685bdc535a55e, 0x0c12e1ca45cf7be9a,
                -0x04e1094b79391df4a, 0x03b3fbc230416592d,
                0x08799db1379e6b1ba,  -0x0fa7c7aed60863358,
                -0x0c44dd44a770610bd, -0x0349cdc54719b2e37,
            }, .{
                0x03146cdf203a80cfd,  0x0e22a03fe80f3e2ed,
                0x07fa7a66dbe252222,  0x000a3bc923a32648a,
                -0x078bac9e36d66da71, -0x03055804cd3b73168,
                0x0d9280808858f006d,  -0x09415dfb2fd33fe5a,
                -0x01bb25a93961b763c, -0x0d7b9f64e9b0c5c82,
                -0x096d7b6ee9a0b1e11, -0x0358047a2c33fc157,
                0x0ac0128bbf7a5200e,  -0x009e0b2ab770e711b,
                0x05473b5629f372ee9,  -0x02eda67313ff7fa47,
            });

            try testArgs(@Vector(1, u65), .{
                0x1879059aca94dd383,
            }, .{
                0x0051da1f25078e919,
            });
            try testArgs(@Vector(2, u65), .{
                0x18f39bb41f03223f5, 0x16a59f6838a63e737,
            }, .{
                0x105aa15beae036a1a, 0x1b47ef7ef744b70fe,
            });
            try testArgs(@Vector(4, u65), .{
                0x18c685254b3c7170c, 0x0de8048a66902ebfd,
                0x02bc97f62163e7e31, 0x152b6eba67c1e76db,
            }, .{
                0x1f45ab5e13037f07b, 0x1a6ac8ec084a115ee,
                0x1db62793f956492ba, 0x0e4262599ec54c2a4,
            });
            try testArgs(@Vector(8, u65), .{
                0x07c1dbda5d0ddd69a, 0x18f5741ef462a799b,
                0x1fd2f93384860df65, 0x01827fcdb6c715d64,
                0x03869c173a922b018, 0x0addd48a4671a2f6b,
                0x1eee0f78995f9f118, 0x1e1d0d6b2396bcf38,
            }, .{
                0x159e9494fc84ed452, 0x0834f6aaa7666a22b,
                0x066765389e84150b4, 0x1e722ae23908c7e96,
                0x0d64ec725397e6ee0, 0x19f3a147a355baa22,
                0x02f1b100538b6dbc3, 0x175885a34aefca91b,
            });
            try testArgs(@Vector(16, u65), .{
                0x105647e12b2b76daa, 0x04dcca29537263f6a,
                0x16c112620be731a4e, 0x0d6c088da3c158fa0,
                0x02ff8ce4fc8331ec4, 0x127a7d10ab851980c,
                0x05703068045915d95, 0x07cc42e0bb216b310,
                0x08a15a16e4247ad98, 0x1c17b2292e34aa369,
                0x14c9808748fa615c3, 0x187449666c2f5375b,
                0x133fcb93a31d2f369, 0x047729af594c8c1c1,
                0x1ce798ff51a064ad2, 0x0800a3c18b944f0e4,
            }, .{
                0x0d65b8b643703ef96, 0x1c55c2e0816c5d056,
                0x0390a06d3ec60e632, 0x0d543d346db055847,
                0x017e27c7d663d7005, 0x112f7b98a78014ea3,
                0x030136142f19042d7, 0x059f9b6e576f79ef7,
                0x1dd78fb3577c5ed37, 0x1a4594314b3f1adde,
                0x1e26cd964c656292a, 0x0579c10261478da1d,
                0x0406f2849ab5ad15c, 0x024b15c729f2211b7,
                0x10f0505cc2f7f110c, 0x133cfa11f995e0afc,
            });

            try testArgs(@Vector(1, i127), .{
                0x226b8faf65414a9a0ffcd438c7fa9eea,
            }, .{
                0x2c582610b08531ca208fef1c2b839bdc,
            });
            try testArgs(@Vector(2, i127), .{
                0x35e8caffc9fc8e1b3b6d3667cb6a128c,
                -0x070d99d51807ae2314ea61e4f0166145,
            }, .{
                -0x3a59d011c2a385a6dcf00a40efd85b77,
                0x3b5f506c3fa0c8552fba624d1b5debec,
            });
            try testArgs(@Vector(4, i127), .{
                0x191594cc2356ffeac739f1841b06adcf,
                0x1f45176996076de7c3891f14f831e192,
                0x1c9047002e0a4f00656556fffeb50349,
                -0x38049f47bcc36ab26600bc475295389f,
            }, .{
                -0x2f8c1618324c60c40f65d216943d59d2,
                -0x21429f90bd9dff7b5d49c9d7f2655928,
                0x3baeef72d0d168fb50564c9f6eb5d778,
                0x3affe6f2eddfc6a69206c357633d0eeb,
            });
            try testArgs(@Vector(8, i127), .{
                -0x00c48629a415129f66e74a1a215d683a,
                0x3920a425cbec4c9af649a00d5747136a,
                0x11f53b9db15a12814c948c6a809b96f8,
                -0x1f7e272db97efc88762dedf54978e795,
                0x13e56ca8ed41f64d04ef01019703f402,
                0x294014109f4313454d9994f1003b4572,
                0x0f3d6fe7adde96149ffcc5c0808b708f,
                0x2d9bcd407da37ff3d43cc5f6b64fd385,
            }, .{
                0x3f95f21d3bc39fe8e3fcc184d150a984,
                0x2a8c36a5986d8c245bbdd302737b7e29,
                0x37c61446e10efe6a94f797da05a28fae,
                -0x096b2f4e16aef099d623066e941d13d1,
                0x3df11d4af3229ed59c52628cac02f506,
                0x326f78cbf454566daa3bc235a1fb3fb8,
                -0x2cf6b4872dffea018c77892e433b6784,
                0x345dfdd52635c224c70949913255ab68,
            });

            try testArgs(@Vector(1, u127), .{
                0x49a0cd1849f9adbed215770c6f97a584,
            }, .{
                0x5e10826a03aeb57d4a9a9ef2a8f02faa,
            });
            try testArgs(@Vector(2, u127), .{
                0x1c2544fbb76890de5c00f42c9a516846,
                0x324f292d72694d409152a311b5a0441c,
            }, .{
                0x01cc87106db8e357e85f875d46feac96,
                0x49e775cc0db88cf9725af13113d7d457,
            });
            try testArgs(@Vector(4, u127), .{
                0x3e82ddcd074646a0a489a4fd300c32c9,
                0x2a511ac041c17a68c5a71bc6d3cb3ba9,
                0x2dace4189083411634b753ae476579a8,
                0x4e1d5cb04d9681d806312d72d6dc5262,
            }, .{
                0x5f489e689ff15fcf38aad995b1796af2,
                0x49ee549bd8e20092c8ccebb992cde8b8,
                0x4e52d33281cba3fda6ae8d1f463c7a1f,
                0x0de0279b2dec3fffe44c1c7decc430f8,
            });
            try testArgs(@Vector(8, u127), .{
                0x636de193fbadb1984a0ed9969f88d38d,
                0x64426b7e468cb323b1d75656879fb9b2,
                0x48afb4cc5a11f2ca4b8609b057758312,
                0x176157ce93422bb4463d6f0dda275b94,
                0x746015d0e8cb5e36af43840a6df11aab,
                0x279b665776118bc2759134c19cbf1bb0,
                0x52cb4dc56d3935090fb7db710c8f9660,
                0x591884d8d8e2fe2f77b7f8508dddeaaa,
            }, .{
                0x42e00bc05d50ea63d546085642b8831b,
                0x4241ff07ce99ee055b48ed2939b8d6b7,
                0x45a5f53a5c5cb13f1a9e6621fec8cf4a,
                0x68d6938c1b348dc6cc98d4b6ab3a1c22,
                0x1f9448fc11e38500ec7ecf57a33a278b,
                0x7b331526d6fcfb958f3c88fc4656e123,
                0x4f1e8ddf41a7105cc1a1c815040a2693,
                0x31ac7bd68686d531d53ecca75e6d8b81,
            });

            try testArgs(@Vector(1, i128), .{
                -0x3bb56309fcad13fc1011dc671cf57bdc,
            }, .{
                -0x05338bb517db516ee08c45d1408e5836,
            });
            try testArgs(@Vector(2, i128), .{
                0x295f2901e3837e5592b9435f8c4df8a7,
                -0x1f246b0ff2d02a6bf30a63392fc63371,
            }, .{
                -0x31060c09e29b545670c4cbc721a4e26b,
                -0x631eb286321325d51c617aa798195392,
            });
            try testArgs(@Vector(4, i128), .{
                0x47110102c74f620f08e5b7c5dbe193c2,
                -0x61d12d2650413ad3ffeeeab3ba57e1f0,
                0x449781e64b29dc8a17a88f4b7a5b0717,
                0x0d2170e9238d12a585dc5377566e1938,
            }, .{
                0x0bf948e19bd01823dcb3887937d97079,
                -0x16f933ab12bfba3560d0d39ffe69b64a,
                0x3d0bfce3907a5cd157348f0329e2548e,
                -0x3c2d182e2e238a4bebd7defbd7f9699a,
            });
            try testArgs(@Vector(8, i128), .{
                -0x775678727c721662f02480619acbfc82,
                -0x6f504fcbff673cb91e4706af4373665f,
                -0x670f888d4186387c3106d125b856c294,
                0x0641e7efdfdd924d126b446d874154f8,
                0x57d7aef0f82d3351917f43c8f677392b,
                -0x4077e745dede8367d145c94f20ab8810,
                -0x0344a74fb60e1f1f72ba8ec288b05939,
                -0x0be3ce9be461aca1d25ad8e74dcc36e1,
            }, .{
                -0x4a873d91e5a2331def0d34c008d33d83,
                0x2744cecfd4c683bdd12f3cfc11d7f520,
                -0x0cb8e468fc1de93a7c5ad2a5a61e8f50,
                -0x1a3be9e58e918d6586cc4948a54515d3,
                -0x512ec6f88c3a34950a8aaee47130120b,
                -0x2e772e4a8812e553bcf9b2754a493709,
                0x0c7b137937dc25f9f9cbaf4d7a88ee6b,
                -0x2ecdd5eb81eb0e98ed8d0aa9516c1617,
            });

            try testArgs(@Vector(1, u128), .{
                0x5f11e16b0ca3392f907a857881455d2e,
            }, .{
                0xf9142d73b408fd6955922f9fc147f7d7,
            });
            try testArgs(@Vector(2, u128), .{
                0xee0fb41fabd805923fb21b5c658e3a87,
                0x2352e74aad6c58b3255ff0bba5aa6552,
            }, .{
                0x8d822f9fdd9cb9a5b43513b14419b224,
                0x1aef2a02704379e38ead4d53d69e4cc4,
            });
            try testArgs(@Vector(4, u128), .{
                0xc74437a4ea3bbbb193dbf0ea2f0c5281,
                0x039e4b1640868248780db1834a0027eb,
                0xb9e8bb34155b2b238da20331d08ff85b,
                0x863802d34a54c2e6aa71dd0f067c4904,
            }, .{
                0x7471bae24ff7b84ab107f86ba2b7d1e7,
                0x8f34c449d0576e682c20bda74aa6b6c9,
                0x1f34c3efa167b61c48c9d5ec01a1a93f,
                0x71c8318fcf3ddc7be058c73a52dce9e3,
            });
            try testArgs(@Vector(8, u128), .{
                0xbf2db71463037f55ee338431f902a906,
                0xb7ad317626655f38ab25ae30d8a1aa67,
                0x7d3c5a3ffaa607b5560d69ae3fcf7863,
                0x009a39a8badf8b628c686dc176aa1273,
                0x49dba3744c91304cc7bbbdab61b6c969,
                0x6ec664b624f7acf79ce69d80ed7bc85c,
                0xe02d7a303c0f00c39010f3b815547f1c,
                0xb13e1ee914616f58cffe6acd33d9b5c8,
            }, .{
                0x2f2d355a071942a7384f82ba72a945b8,
                0x61f151b3afec8cb7664f813cecf581d1,
                0x5bfbf5484f3a07f0eacc4739ff48af80,
                0x59c0abbf8d829cf525a87d5c9c41a38a,
                0xdad8b18eb680f0520ca49ebfb5842e22,
                0xa05adcaedd9057480b3ba0413d003cec,
                0x8b0b4a27fc94a0e90652d19bc755b63d,
                0xa858bce5ad0e48c13588a4e170e8667c,
            });

            try testArgs(@Vector(1, i129), .{
                -0x09c126c4e31389b174cb2b45e76c086dd,
            }, .{
                0x0d023f2566c56400f4b7edb9c4f364ecb,
            });
            try testArgs(@Vector(2, i129), .{
                -0x072be32e116741732f9422d9b20777db5,
                -0x010829386cc3d93283a83591bd994ca58,
            }, .{
                0x004671167d0681d46945832d16f70cfba,
                0x098550137341cbadfe8378987e3a83265,
            });
            try testArgs(@Vector(4, i129), .{
                0x04167620c7f5e094208fb204f06b9792c,
                0x07a6690c0b5f9de6c8955873f19b98f23,
                -0x06505997d01e5a971f820742210c7adc6,
                -0x07013921eab8d92559f17ad9e3712bc61,
            }, .{
                -0x0bdbf7ce4079fa628feb05f5814402e15,
                -0x0e6ee5464de547ce92ee5a6037f175e52,
                -0x009d079b88cdc765ab72758854b753d98,
                -0x085af31dd5243f61b46e6dc950728ff49,
            });
            try testArgs(@Vector(8, i129), .{
                0x0d85f471bdc56611e9187113f1489bd38,
                0x06e1e9cae044bb17b63c380fd6f2652b5,
                0x0921d649288a16481f2ec69747f443e5e,
                0x0e8db24d1aefd91cfab20bac61f560274,
                0x0187abef7578e5e02a396e4ebd5859c23,
                0x0d2dec5a6bd72afe18288ca428ec2b94d,
                0x0c52c111a077bffb1fa4483523cd044c3,
                -0x0b6a90c79d6230f271bf625c9a6c0dfc5,
            }, .{
                0x0d47c566bdedae2e9485f7aa381a98d30,
                -0x0e5d9573c01a9e56361b202c47f0e51f8,
                -0x0bdcafb1f08db4920121521b2d2679931,
                0x08de42eec43f2a5175f928f8a1812575d,
                0x0c3f57e712a7f8494e51b62d11573d9a0,
                -0x09287910d439c9bafd56bc8a6faf50cb3,
                0x07b494af9634c8f95bed2f50fcaf08dda,
                -0x0a150693d83af2e823dcc0765e4e331e2,
            });

            try testArgs(@Vector(1, u129), .{
                0x1e51bd13747df8fae52f0471e9f1ad3f2,
            }, .{
                0x00aba9f2c80c71b1ed07201486ea44d00,
            });
            try testArgs(@Vector(2, u129), .{
                0x0c7967a19d13d4bd3f6ebfa0f8fdeab92,
                0x01614ee2c32757cc92e2efd97e94321a7,
            }, .{
                0x175803a2c0bf888bd01e2a5bae28e4523,
                0x07d05a98ec8f4e7e72aac2712bc09a23a,
            });
            try testArgs(@Vector(4, u129), .{
                0x1b18b768c5852bb1f0a7b34ceaeac4a0c,
                0x038fc1f995d9378fcf1043598810d7a56,
                0x06eebd77f9920e79932decf0f29ef658d,
                0x1f31a766145022050d0b16a4f5d06f1e3,
            }, .{
                0x033b20a528a722b6704bf5c8aea497e68,
                0x0ea05276fb8de4e77e4a8d4ef55f64bba,
                0x1c632cf252683b00faae6dcb7d73d8b90,
                0x11a7e1e98bb34fc7f5ed36c327476b122,
            });
            try testArgs(@Vector(8, u129), .{
                0x1b85991584b26492938854a6f6953b766,
                0x119472b0f4b7199f1267639f601833e3d,
                0x130d19e6ccfebce09c61c8c8fb526fec0,
                0x1379f4fa9d25e18ef5138c193b7ec9ef3,
                0x15fc62d9e21c2c0c63f9cab5ab0a8cf36,
                0x123ceb2a65f200a0b3e559c801bdbfa58,
                0x0e740ae3c7ab0cd24c5ff94d9367e3ebb,
                0x008c7dd67796949390355d866e4f171ef,
            }, .{
                0x0ffdda009048cf61476610425d5e55560,
                0x061bcb9d024d015891b5666e7b317cc84,
                0x060c013386fb8c129a3bd65b7909f2bc5,
                0x01c8efdd7ea806b1dc984c6183da53d8f,
                0x02fae7cee43d7f97448e82b907335bd45,
                0x0365e7cadcbd0a64decc1377339967c53,
                0x1a52793ba8a9689e1d7f5036e8cb613e1,
                0x1257d7cdd8f04058d285a5bce173b5262,
            });

            try testArgs(@Vector(1, i191), .{
                -0x23ce1d6b12e301d243024c60aef14b6d068e1d4b1c4f442d,
            }, .{
                0x1a7b04f33aa590b99c1162bb32e7681ec267b7826e162512,
            });
            try testArgs(@Vector(2, i191), .{
                -0x25ed7b5b9a9cd517f7f1e2e796f8c5a28ae04af6c1e7bfb3,
                0x3f298efedf4269276db60344c2bed556ee25d24c5f887000,
            }, .{
                0x3c92b38c6c6eb449c25011a4248df259b8452293390d8ad7,
                -0x35743fe2fa86686c496ffd16f93f2fca1ed742b67b8722a7,
            });
            try testArgs(@Vector(4, i191), .{
                -0x1743b70ad78994b68b5f7ad6066447ce8aefaba4852af2c7,
                -0x10974462633ebb5631bf83d65ffde3239ff4029c9f62b7ef,
                0x1783dc9f0afa815051e6d338ef35da013e807da475815af5,
                0x3f32dd0689a9437b7acc4290920370205825a3f6a4453916,
            }, .{
                0x2ef1b4f92da40e0c33a1611f48f25d8f1c4208b5396e51dd,
                0x0d1e8846fd1a2055386c4d74aa55914ef085196399964a29,
                0x272c9065c4395186cf7c164fc5d43aeee7fdd08bfd98ad86,
                0x25438380cc92dba5c9f3d57ef311fad8e14e3a3c18910546,
            });
            try testArgs(@Vector(8, i191), .{
                -0x36d4fd6afdc4bae957b5caed3360891ac4c44383f77e0225,
                0x2bd89636510607345813f74ee303d3b22435b37a7d09c7ed,
                -0x3cc372c1659789b967ed7000bfae20f73829a093e9ac9232,
                -0x2e27691dc3d8ea12093136cf859ef8e0c686ae66e56e073d,
                -0x24150a1f8bb0097625000af9b186a8927f70993e76702c17,
                -0x3adebb65a71f180fbf21117bc38fa3aeddebe1e216ae5a70,
                -0x257688d6ef63e2046bb8bfa11ba84b665e4e12522d56d085,
                0x173a71a3792e72cbd31f2f10142cf568ff0987e8dfd4ed35,
            }, .{
                0x056e3bbfe91bd5adf441278fccaeabbe86cba8ae545dee95,
                -0x02705836e891812aba265ee3e12d17f6fcdbc69320e52ee9,
                -0x276a852ba9a4163fe636cf31007b5e3cb087bc44c0948a02,
                -0x14053135d82f772dd82e7a472315b6b9fa836a27bebcf980,
                -0x153f064d28f4fb27c827bb5fe2a44c95e3b54d21eba40a1c,
                -0x30ac5165fa3f132f294a5241d3201973a0671aa3b536e3ae,
                -0x2ce2be59f487892c58bf667a55724b117e3e8ba3b00c1c31,
                0x138bb8e5b837ffd06d296ea0af9f533ffe3a36073fafc2d3,
            });

            try testArgs(@Vector(1, u191), .{
                0x24f26e4c0b4b20639550564263b0be7083e112cdef6c2d83,
            }, .{
                0x020334928f4583d332043b7aef15e832047dfd01b2933038,
            });
            try testArgs(@Vector(2, u191), .{
                0x67074e5315030f5c1a4d035100736de691b5589f6d349162,
                0x0e655397f96e3fd66b317294a37975d36478242fd6392259,
            }, .{
                0x56bb6bd23999b9af6230833f3c661fd54fa2f012673f88bf,
                0x005c4fd0feb22f04ae76cd1479b6f0d6e62b76b249073cfd,
            });
            try testArgs(@Vector(4, u191), .{
                0x793af4124df65a0815c1f1603d309d0094e1ee29a571ec57,
                0x32163b39813a85f3c4ca626d14130258782eae8704f2ceb1,
                0x64a0ac41f560153b3d1f3193faa818db7be2c66f0dbc2457,
                0x195e210a66b88674fcb13b0bf26190442b71bd53b2df52fc,
            }, .{
                0x2668ee718a179e0fa57a1b72aa6a5dea00b60d8fe69a019c,
                0x447df595f31d0bac74b0dd7a379fbaecb92b2aba1b8615f7,
                0x0c794ae8369677209d714dd97092b5e4d0c6b9e794e6d9b9,
                0x2c7a81900b3eef44190b5d0264f9bf072588720247f69693,
            });
            try testArgs(@Vector(8, u191), .{
                0x1afd856825f4458371e2adcbdd7c1b1dbb935b8a6f4a6dca,
                0x738efc41846cf88223553ed8b4c1b45366088bece1fe8052,
                0x7841b17a1c38e4066376e5ae204959c02c524635740a9013,
                0x4ea41d7c910dca17242c74dfb1aedbaf05c9b93fee1e5b77,
                0x5c6ba91cfae1f4d49cb2b5cedfc090f0ffbde9afa6794788,
                0x4582bfd463bdf1f5ff4da91fc65bc2a38823f45c05bc485e,
                0x7cbac126c09224be8017d7d1c9a84014d2af0a3afb14a5b3,
                0x3068064c244d43736c5454d45b576f4c62324dd5aec39e8a,
            }, .{
                0x49907c71f5e8fb9626727be7a949ae8ee47bfc3658b09614,
                0x5a8f50d921fcdf9d0a20ff050ecbd2447cd3ab7ea3c4d9fc,
                0x11bfcb2033ef38914dd35cf384f22d5ece33c1685616ba90,
                0x1996b77370fef92a696ccd5e316eed50b2bc33ae10b245d7,
                0x1aeacf955748c195f4ead3b032cafce35db2cf253f4065c1,
                0x6661ba1be480a8ca7cb1ed35c01ec591c34ed15524412434,
                0x0d357b77a9e3b924156e18bcf41a83620246ad419a9ce9c2,
                0x467f70d48dfc54fa6cc3ba3f98e66cd1410283f1ec0ae934,
            });

            try testArgs(@Vector(1, i192), .{
                0x5348bc83a6f352c931d06b9817458273408470e8ce312bef,
            }, .{
                -0x1e9beca133a9c8cde4b5dae26e198968806ca966c6b8c07d,
            });
            try testArgs(@Vector(2, i192), .{
                0x468c1d585cd2e9549f9ead72889e80fedd3eb95a2ee8d869,
                -0x1c0276cb4b61b673492f493520098742edfa913d455c4f5b,
            }, .{
                0x4a503063a094c7e29c2ca37b6c686e16da8d921aa89c05be,
                0x4c2141b98f3736551e6e08f1d24eb864842753a8c7112ef2,
            });
            try testArgs(@Vector(4, i192), .{
                -0x62a9e282152d85abe46e802c276f18b0542871984cd7bacf,
                -0x3f01fc751a8bdef2e7a884d7984d6189b36c46048de3035f,
                0x2eb5379125d8169909e66f4b6bc903c5f6c92952872bf2fc,
                0x308053e7f5da3a2906cf5b48ab3752a5820cb90ab56d58ce,
            }, .{
                0x6bcb4f6375a8ee60b73240550c89edbe0976acd548588d06,
                0x1b63863c7a8871c34b2eed238ac4747508150578f60fd993,
                -0x2bc4a2065ebda452635e3c9cd420f9c01f869bf7abe75255,
                0x6093a6f058b4da28e5f64ebe7684a5d34e2ed48c98bef114,
            });
            try testArgs(@Vector(8, i192), .{
                -0x41d1d3675490a69b9455f1dd57f0c6a7c5e88e734adee8d9,
                0x03c5f5e58058b7a4a9038ac6717a1b70caf3851d017ed2e7,
                0x1829fef2dd242cca51c638d69b51e00a6e7847e79df6117c,
                -0x4622b84d4b52f94d9c933ef3ac435968b1c0b1b3ac1d07a3,
                -0x1bb5b63f2ad4dbc0c0090131116680074a83f51f79d1af32,
                -0x6b75cf9bc97f9b012305b718bbc0672f86543a245c363297,
                -0x43eb0ec7a8995f1340977273858be8f3d620b503a5931574,
                -0x1dcfa8f4475abd395fb4e8f696cb25625de768b2d5cb0464,
            }, .{
                -0x685420e7656ef93e813658d4eef9d44cb0acab0560894da6,
                -0x191a07e070edaa52554347726d2c0e1d701b52dd462b716a,
                -0x6a336f271fb3fa7cc33a441e6a0d9bba741d56bc5f83b113,
                -0x6313298dfc0492db682940661b6ae1a2f56159663f4ba525,
                0x35b1588853218d6e00c358bff9d9bf86e399a8b5e3db2b67,
                -0x6bb7cfcd5f78cc6437544a271922eba4fc64c25d4a8a0732,
                -0x1a40ab85aabcabc56a4e5523c38f5e184aa5c81d9cdc93f5,
                0x74438ae4acd2fa943409ad7b87feb48a467a845041aa8d21,
            });

            try testArgs(@Vector(1, u192), .{
                0x2058bb0137e3c0cf5c4afb9a17d6ca0646594ceadb5a041d,
            }, .{
                0xc1a1bff0426a68458ea170fba78d09a9fe172a5a3609e8eb,
            });
            try testArgs(@Vector(2, u192), .{
                0x693ffb174c224e1139c22e38405ad42e96d229c3fd7a8af2,
                0xce93932e25a8f26d8f3314dd0a56868ee899eeddb321da8d,
            }, .{
                0x69b7060f45d65d5d71ffd171aeebb3aaab8a3b313426f9b0,
                0xd2953b80f910619b3e0af7d65fe8f840b055f8690b3b7a5e,
            });
            try testArgs(@Vector(4, u192), .{
                0x4770c1f64c87afde65aec11764deed53f9a2d533875eb2be,
                0x40b75e355dc0b2962e5ce23a5b990642371d9f6a80b133bd,
                0x99c6d4c37fe86bd4d207fc56822f7ff6e8dfbda5f9d71256,
                0x43d7f6d2a18f88224c447e88848ae335cb58f3122d36de74,
            }, .{
                0xaa5d91b484e03b2dc31fc09b69192c265155f978e1ec2294,
                0xe474f9f62162317d3115396d50a33753b6b709cd3a06f5e5,
                0xeab9e1fc9c5da4e6e676ebf7cb0d871e9633d738928b8134,
                0xe493f9557f2e1eda644ee3a5055c912db265c302d588e2ec,
            });
            try testArgs(@Vector(8, u192), .{
                0x3a38fe23afa76c5ac5f8e0c0b27c70d0ca17c8e184033066,
                0x28104df9a858c83c6301788c0058fd6c58f7e62f0b735099,
                0x040f1bad46838cfd6bd5d269415512f7fd129b8322e944c4,
                0x5cc3d6202e8efb4d769535a20db0876c5142ce975cc175e3,
                0x24211e6d3db188ef22afa6ab4a382bfebb0520b76562bcf7,
                0x41c2ba9d1d085d99ffd58fd992c9508ed6cd975441710d0a,
                0x09e6ae22e1869faba24973fc0f686f4310b06c8da2b8b9cb,
                0x8ae0677c9dcdbe674d252a0c985a81bf9bf32001e2e8cc7e,
            }, .{
                0xe10819f5757f84ae79f934711e8cdcd6aac2848c9af0744d,
                0xf0264ebb8882377dff3f82dcdb9dadfa2350d058be09933e,
                0xa47708aedbc8100ef25a6de5eb01d7cd5f98074f69e1227b,
                0xd0145ba1e2d64d053034e2beed2f47179bbafb8b90b5e5f9,
                0xde348762a0ce1397ad611e84921a7f6f7e0683fd733b9a09,
                0x4de07b2982883977940773c44ea2a2e2cbf1e1db94fc832d,
                0x5af700739769e9ce05217e76638edf92a169bc4c3ee7542c,
                0xa58a80368b056aa1987f504ff1261cff3f5ffc4474ab48a1,
            });

            try testArgs(@Vector(1, i193), .{
                -0x0ccbf216d85fdae8d3a7ee2e7746bc6cc3aca87f3f8067f66,
            }, .{
                0x0906ac1fd6d47d6c762db9fcc02fa2987ee0c4d66312b79d5,
            });
            try testArgs(@Vector(2, i193), .{
                0x0f3a3fe06faf1140bbe4eb5e0d0268edb529918745ef3ec9f,
                -0x0609f53b7f095f629a4b358fb0b77332a89dc203ac0cf28b6,
            }, .{
                -0x0188251925a3542ea0d568901a19d67796b17339e9b73f88a,
                0x00f9037c3dab02483b14195ab2ef737090f187b90ebee13e9,
            });
            try testArgs(@Vector(4, i193), .{
                -0x072798ac04a8ca26a36f587412c9bad03e855fd2049ba72ac,
                -0x01a8dd5d7cc5ae4f3342ea2af61c4349bb777e9d14108eeda,
                0x0516fc9ec2e14cd7a5e27c0ea83826082c1097fe35f9f006a,
                -0x06bd00e1b3a8aff93618d16bcec743ad577e379a15eee0a72,
            }, .{
                0x0bdf3724329572c17cf6b82f7011daf08bf56bc28acfe650d,
                0x08049ade287c9661565a18c5bf57d487cdfb5c111033ba199,
                -0x0917208e354d2765f0944bc9f50836d4bfcdafabfe8e2442a,
                -0x0a354ea6608f71254d97e615dc45495e0bcccf05466a2db2f,
            });
            try testArgs(@Vector(8, i193), .{
                -0x027bd975ae44664a34f52fd844ada5c23e4b0fa5586a274ec,
                -0x077e3522a9cb0c6aa10beeb1430e0ac356a48e90f6466c233,
                -0x0d0d02b7ab7876460c3d4d3118bef476e2c5ddae50af453d5,
                -0x065c502be097b15379af566a20c4ee93893718330c9a258ce,
                0x08b5e11e5ff7422f25c99ab70c216eb77e35f269b5fb739a9,
                0x0d827f83698f1365a5140e1d38072571dac4169c2124ee1d6,
                0x062e1435b91faafeecadee5551c61dd01f0f132f56e849973,
                -0x0dbcd14bffb526c9f3286428e5eb273785128417f05336ce0,
            }, .{
                0x0a99c2d8d15184fcdaa5b68180f4e10b0c9fcde51d213c257,
                0x02065bf7e8d093371795f7f376e2fb3ac857a05a3e1f6befb,
                -0x060f3874a6f65b46738d0117db38b749aff45725000c06213,
                0x06019cbc9b1466b7669690ae9c6f095257d1c8874e5e27353,
                0x0bde8419e795cbad708c76ca90de50c00b585c44d78b2ad68,
                -0x02e271e95d11dbe0cb77c8b829c739bc00e6c9b2f7b532a29,
                0x0318a691ab34dabf1804facf1b773a9fb6f9e9fd9e63d985e,
                -0x04d151cd85a0bc49683bbdba28e2410292dc5648335819fae,
            });

            try testArgs(@Vector(1, u193), .{
                0x16d3f2329dafe80b17fdff6bfa688636ae9b5ba311b276f3a,
            }, .{
                0x15f95cc088cd4d4cabf9de25cad565d1880515c869da2866e,
            });
            try testArgs(@Vector(2, u193), .{
                0x1a40ffb1b6f0762c975581a45d9b6811b96eda8cdd6eb497c,
                0x1b010ecf0ba30ca695c39cce25d82142f4c67aa1f8ae39947,
            }, .{
                0x0851339a84dee70faac763dbd9cbf884c09f011f093846f20,
                0x16be7f51577c5cfcd423ecdac1bd0edd1fbce6755d7b20cac,
            });
            try testArgs(@Vector(4, u193), .{
                0x10e099200fef4497ed4be9e11269a254ee4f7fea53ae1e360,
                0x16cef44c285c1d6364cefe22db70934fba8d31dcbcefe2699,
                0x074c07744bd683a1a5ec77bcb1ac4cda8b840d5b6e5da9852,
                0x063c5565fbb29b63de719fb574657d50af454f33fb79f59fa,
            }, .{
                0x09cd6adfaaf1b9ed0fd6370049a2227088d9b834b74412a3c,
                0x0162bc69f5c0da662e3862ea235ea46819b737de31d258a45,
                0x111191f24663c0a425bd31ead4496b4693a089d6bd6082a11,
                0x127c9d184e79d0b80a87d9acd7fb79d93fd9b08ff480acef9,
            });
            try testArgs(@Vector(8, u193), .{
                0x171ea804993233dcf14ec91b9185a1520416bebdbb2f0f4b3,
                0x0f74e7e8f4b4759d22de5120dfb4db57205990a899ab3698b,
                0x094e8a7bf8cf2a802d3a79f77d3932e8a65d11378fb6f8ece,
                0x06d07aea60256fcb65c306b32ace35809b45baf5fca21efd1,
                0x17df00d2223a949f6119a3c8cf0cd87165ed48f93ad0eb921,
                0x173b7201aa391de8d236ff30ed8ae82b7be2ff5de51285361,
                0x02a95d9fae7d18739a93e174d9ea1b2f108bd2f5997dfa42f,
                0x0bffa67d4ac0f4bb56cd4fec9ea53d47896f05fd4efc0f6e0,
            }, .{
                0x08485a8df517ac7bf9d02ec8d0c34c246dad221f1ea51596b,
                0x0986d1fda1bca4b83da2cace25768e4d91d89028889443cfa,
                0x1faa463b7389740db0cf14b3274f1f955536c6a929c89df82,
                0x072b004463fc7c58f3ae51d7d5d44ca208205ad3396fa6c8b,
                0x1ee3603ef444b40e5ef74b6d79f3433648fdbfb918d50e4b7,
                0x1612fe2493d3e02b2fd38ef7664aa9fb079db6843bb201100,
                0x0d1a4e0c9596afd18e6f06c04ec3fb1bfb660133fc0c7f7aa,
                0x0de0220f630f0ac5a699cb36d7ced9da11b272dd2eb66e96e,
            });

            try testArgs(@Vector(1, i255), .{
                -0x228071e5036248a576fc6f30bda6553bc4f08505cd4fd272e681ddd1a551db11,
            }, .{
                -0x14c82347566b6d8eb19064009a7ef16e2d08cd6e40b4bf34f1e6723ad9b0d625,
            });
            try testArgs(@Vector(2, i255), .{
                -0x39313c0014d4850a7957418b2fdfc83a0c29c5f04d90ccd634d7b4e52ee6aef2,
                -0x096abeb3fdc6451052a96557657d917e9128765c256f83403f788992dd0cd486,
            }, .{
                0x2765779b4ffc6c405173fe64f621af1c7d63a91ab3fe5809d066fc428f630c47,
                0x206df1159f268d4fd99dc8d2228718189161d7095f0af64c7dee86a34a7b875f,
            });
            try testArgs(@Vector(4, i255), .{
                -0x2c31b98911222faeed03f6625c8a75e0ce5fa53be49e79a26695dde5610e28e4,
                0x38506947b5f5e5ed4cf3f0738140bb988af9e7cf514862861ec7259a8426b4c1,
                0x01ba20e69c07a1e8845b1cc837d8d588480a2a52b15f0a5532c763f91f3dad9a,
                0x1877f8233a0a96c33ea2aed47e3388f8961d4a81dd6c8c1a48c77aefe1b7ed6d,
            }, .{
                0x021a3c326f7841068338bbc9ee73fba9b36050156f2a6d3b44ecfdf2273496dd,
                0x0865f2eb5a35c85c480880b26a9a03f51e0f4cd9bbc2b8ab2755f2aadf1cf0e6,
                0x0d41a6c3956465b187286d95a42d42033f593be4bd681e757f1154a0735b894a,
                -0x0b87a6b415579cd9889321b01ad8d2b722dc6c932cf7aa97a0c8c807be5f6d68,
            });

            try testArgs(@Vector(1, u255), .{
                0x49ee4da820d884bb3693fb576d5b2f16c9f064ba1da5a81838911813a6445dc9,
            }, .{
                0x0afbdec22d512f0d88a95d179e6fc901c7f682be0746ce9acfca17b748543381,
            });
            try testArgs(@Vector(2, u255), .{
                0x293f83519c238a446748193388e0ab75567a03a458b4873f4c2b16b9250f15ff,
                0x1f0f33f7c2d6fc271ae497b6e3b7a7c6fdff096a321843aebd6d07d7f3050bef,
            }, .{
                0x788c4bf8d34d23eb8147a7f36ab2d09a96be0f4bcaa6be6816447e9e6e39d0f8,
                0x2fec35d0092202f654993429949fd5c121554c3cf6072239fcf35aa44d45dd1b,
            });
            try testArgs(@Vector(4, u255), .{
                0x5477956be73c0d9af22c5214b47a39761bf0e88c92dc08ad1955b12f60575982,
                0x4fd80abb62788804ff3edac72d91096e3747a8fe5a53e5f63b0cb4c1ec85a626,
                0x411f513c4e4dffd0a699f99b3d9aa50c315fccee34d183086b8209f42d965cd4,
                0x2561cd45d8e7fb3ddd810396823997354e7c2c4c5529d66b30f5a6ef095d92ce,
            }, .{
                0x4bb37f557ba14ab84ebc762ec943d39f5250ecb6005935f3269ba60d8df20d61,
                0x38358daa8c05bc317383942e3a9189d2f205ba705a76f9285acf9f223d954b36,
                0x3616b6288a23c31fb4412739d002df3d50b19d23995585a43dfcacc547f1eb49,
                0x00b4ecb3ddfce395458e448c299f74d8f5c37e36a14d9ba5b6bf8dd3917522d7,
            });

            try testArgs(@Vector(1, i256), .{
                0x1fe30aed39db1accf4d1b43845aec28c1094b500492555fdf59b4f2f85c6a1ce,
            }, .{
                0x6932f4faf261c45ecd701a4fe3015d4255e486b04c4ab448fe162980cead63fb,
            });
            try testArgs(@Vector(2, i256), .{
                -0x23daa9bab59dc1e685f4220c189930c3420a55784f0dec1028c2778d907ccfe2,
                0x521c992e4f46d61709d39e076ed94d5d884585f85ccbf71ca4d593da34f61bf5,
            }, .{
                0x2d880cb5aa793218a32411389db31e935932029645573a9625dd174099c9e5b2,
                0x2394a6cde7e8b2dc2995f07f22f815baa6c223d99c0b1ec4b2d8abd0094db853,
            });
            try testArgs(@Vector(4, i256), .{
                0x244e66ed932a4d970fd8735c10bfbd5f59bd4452c20fa0fcf873823b8c9e6321,
                -0x31577b747614b1ab83fd0178293cd80b3cb92e739459b2d038688a2471f6d659,
                -0x0dbdfc3d8bbd7cab6a33598cef29125aab7571fb0db9a528e42966963d6ce0e7,
                -0x72c58cce172d8a34019a44407a4baf1f8f8a4a611711bd5bb4daa2a2739dd67b,
            }, .{
                -0x2e88bc68893fc2d61af0e5ccb541f31fa6169504e8cfcbeab0b74a03b9e86c33,
                -0x7eba0783f3382b59a17ffbea57ba1dd8fa30e2d4f7eba7ed68d336d3c37b4561,
                -0x66d1463efd38e9e994e126d09b5c65c8efc932ffea9ec6cdf6042561ba05f801,
                0x2024bbacefbabbfd5b32a09be631451764a1f889a77918f9094382dc6d02aef2,
            });

            try testArgs(@Vector(1, u256), .{
                0x28df37e1f57a56133ba3f5b5b2164ce24eb6c29a8973a597fd91fbee8ab4bafb,
            }, .{
                0x63f725028cab082b5b1e6cb474428c8c3655cf438f3bb05c7a87f8270198f357,
            });
            try testArgs(@Vector(2, u256), .{
                0xcc79740b85597ef411e6d7e92049dfaa2328781ea4911540a3dcb512b71c7f3c,
                0x51ae46d2f93cbecff1578481f6ddc633dacee94ecaf81597c752c5c5db0ae766,
            }, .{
                0x257f0107305cb71cef582a9a58612a019f335e390d7998f51f5898f245874a6e,
                0x0a95a17323a4d16a715720f122b752785e9877e3dd3d3f9b72cdac3d1139a81f,
            });
            try testArgs(@Vector(4, u256), .{
                0x19667a6e269342cba437a8904c7ba42a762358d32723723ae2637b01124e63c5,
                0x14f7d3599a7edc7bcc46874f68d4291793e6ef72bd1f3763bc5e923f54f2f781,
                0x1c939de0ae980b80de773a04088ba45813441336cdfdc281ee356c98d71f653b,
                0x39f5d755965382fe13d1b1d6690b8e3827f153f8166768c4ad8a28a963b781f2,
            }, .{
                0xbe03de37cdcb8126083b4e86cd8a9803121d31b186fd5ce555ad77ce624dd6c7,
                0xa0c0730f0d7f141cc959849d09730b049f00693361539f1bc4758270554a60c1,
                0x2664bdba8de4eaa36ecee72f6bfec5b4daa6b4e00272d8116f2cc532c29490cc,
                0xe47a122bd45d5e7d69722d864a6b795ddee965a0993094f8791dd309d692de8b,
            });

            try testArgs(@Vector(1, i257), .{
                -0x037f102b7ce87d2f4c704b7dd9c77c79d5ef99cbaa890cdf5be7f1c991b377f12,
            }, .{
                0x0e6613140253b86eb76f9cf0da699c734f1073559d4d59b876727531aa1566a3a,
            });
            try testArgs(@Vector(2, i257), .{
                -0x0516f834d832f5b33a8b766b5830ae9b6ed2a8be3347d7cce6a0d536c0ccdcda3,
                -0x04148b4556c411a3db079163f1aba615971677b03abf31a34abe73cf054957e01,
            }, .{
                0x01de4743d129cde4400547974ca9e9cfe234fe8fa67ec3c00f70b52f16a683ac9,
                -0x010dfb09c7a42112f07962065751b8bcabe282143d79aaad484080f2c15ac41a1,
            });
            try testArgs(@Vector(4, i257), .{
                -0x097f0ce2c2a4de17cd779503e3e86de1fa9153ca69674546367166703b79658aa,
                0x0d6414d92755101344039202da1d6ea15e7054817dbcf4f30c16f85eaf48f3a85,
                0x01e73273f475e7fb3111f8a4212eba3f736c536006f1f1a0fa0656fd3fc34fc66,
                -0x0277808e445419c1f814213ef86dec08f7a0192ac985dd22043a8161e0f291c42,
            }, .{
                0x0a3a6678ee5f9458ea259d8434c1604cbfab67b294525a7b2e6ee5dee752db0d8,
                0x009f39291d0f97269ce694958d6252a666b928737e645865e38fc70995307290a,
                -0x0beed4ee766fb1a04a66a0cbad3da0f471b5c0e32c252279b23feddad2877d35c,
                -0x02ad0e2fa1940ad0d2ba67f8f27b486ec781bf5da1f580a9bba0ba8bb0d11aff5,
            });

            try testArgs(@Vector(1, u257), .{
                0x1bb62cd7dbcbbbf2e708871d12f647840997f16f6d322eae96393b3b46ad0ae11,
            }, .{
                0x1d4361c83425068c40a7a142019b4004a496cf16649773aa04431225b189fbd68,
            });
            try testArgs(@Vector(2, u257), .{
                0x08459d63d1124e6bf747a2dba45df79ba9813451189f4e9bd8fcae37d92646ef9,
                0x1336f89e29d7da4d741e10a8a8016e007ad3f475c7b302a03271f0edcb2dbaa98,
            }, .{
                0x0fd91b46af0a41227ae191250a1d49b7e44e4435f371eac7e8355b8f3ccff1ccb,
                0x03914f3814478e96cf3efb4169aa36747aa4bc33daa56ca41134dd71a3af85de6,
            });
            try testArgs(@Vector(4, u257), .{
                0x0aa2d811711d70ec5dd639ecb979dda726c157bdc18dc34447c3026fac49d3909,
                0x00652c96fa6a34772a424e4b9c7c3613558c79f4144349e0d700c15ff9ec2f974,
                0x11b10abfe69b4f75c11e0a0ee128526ec9f3fb7b32502d1005984b0c0652ff7c4,
                0x053ea83a9caded41dd751a742b49b062fe1fd62af3d3025486bc1af7921225ab0,
            }, .{
                0x018c2110a0432d0acd462886f559f826bdfb05e91e61e2928a3a43b98d1e6bfab,
                0x1b212dde794f97203018963e51b025b21a5dd47f04a007fee80aaaadb87e30140,
                0x1394a84c2431e46862d33dbf0dd0cf23f7ff7f85c0107c04cdeca1c168df5c556,
                0x060c9e2ba327cde7650bbe329345b4184223d77adda253c5f425531676e863c8b,
            });

            try testArgs(@Vector(1, i511), .{
                0x25c69b25440d3059c5c38ba2771252430152afcbcb988d8c5de0832f49f1d8649a17a4e0dd508d8cd7349adc4ba228902099092726af175a8f04f29a19ded5ed,
            }, .{
                0x0c28729ed05abb52e888bb7fefe58f783ed5c7ef3c8a4cdd7349fe47edca26db746de0308e642b64b659a52e17405dac9932ec43499e6f17b6cbebcab597e577,
            });
            try testArgs(@Vector(2, i511), .{
                0x2b6235f2d231f63ebc67ac71893fa5ad6f2125b6d50a5f9eedaf8bb4de3e116939ab5b2c0e9b7cbc0a2308c3a5dd4a99049f4538cffd4155b24721e3c77bc268,
                0x10cac70f8d1dbb88f1dfd913823e8fa53ad58f54929222c1c7bedb591dd3c90ecc5c1239fccc80515b5bbf4c4d47669f267b3880dd8f465f6c7e9fc6e63faac4,
            }, .{
                -0x3dc3af786e95767befb16c51f5602029a5fdbc76dafafeab2c409168332f8c5c038a0e7f3d0021acaf6eb6f6ff9a232a9dd19e5b33c7c4158f8f1798150448f1,
                -0x0eeaa2dc65820153224f26847a99a3626d6ee9991ecba613e721bbd169e69371dd5bcadc8983ae9b82d77376b0e8179997e400fce64c74c9efd2b4a5f174b854,
            });

            try testArgs(@Vector(1, u511), .{
                0x207381c6b742f50bf76d0d220943d9354d96f4cf27e979bac6c8f47d70d64d44153dd6c2ed62cc7b5a4fce98600382fbece15ee4e4b3d1c0d4277a553ac01c10,
            }, .{
                0x35ad1698d693b3b7618d1243163f1ce2beb5f6c3c7b6e33a24ce9639e5a3a30f78350f4c3c818512377bf89851388e1d444a50b20a10a2ce66c60d0af1bebc84,
            });
            try testArgs(@Vector(2, u511), .{
                0x039131b98944347f35fe54337902bba6b975a1b6bd9e36a20e236f3149b53156b5bfa0b468a56dfb1c09684a8f24b5d548c6e216c20dde01813c044cf031a3eb,
                0x43ac7c9afa88f5169405ff4963557bb7e78ed15eda5bfa91335f7d9117ee13d969d6cdd2f0910f8865cb57687fd2e0f4e6cb188bb34759609724a7ce128c0db1,
            }, .{
                0x43dc8c03e26c12e96d69076a68afd3e0515ffd67fd2b2aeb8457c92e7e2ec6c503a362866ddd99d4a4f21e7bece901e3df76a9496e978d11f4c4cc50d1e52601,
                0x4f97c33b53b3c4b5a59c257b575149524e7e4ec4fcfe1574a9a3111b066959d39affe87e6e99656a80d64ae95d60ef4f90c2544559d22abbf26d6ab34e5b3074,
            });

            try testArgs(@Vector(1, i512), .{
                -0x439ba81b44584e0c4d7abc80d18ab9d679a4e921884e877b28d04eb15b2d3e7be8d670b0aba2c4cc25c12655e1899ab514d0a6e50a221bcf076d506e6411d5c2,
            }, .{
                0x18b1d3be5a03310d82859a4ab72f056a33d1a4b554522bcc062fb33eda3b8111045ee79e045dd1a665d250b897f6f2e12003a03313c2547698f8c1eab452eae1,
            });
            try testArgs(@Vector(2, i512), .{
                0x28e2ab84d87d5fb12be65d8650de67b992dd162fe563ca74b62f51f2f32e1084e03e32c8370930816445ac5052b4d345059c8ace582e3ef44377b160e265ec9b,
                -0x3a96548c707219326c42063997e71bc7a17b3067d402063843f84c86e747b71e09338079c28943d20601c0cde018bad57f5615fc89784bcb6232e45c54dff1db,
            }, .{
                0x64beecc90609b7156653b75a861e174c58fb42d5c7bf8d793efbb1cbe785c6b8cd52ce5f9aa859f174123c387820d40a2f93122b81396d739eb85c3ea33fcd37,
                -0x3632e347bc6d794940424ca0945dafa04328a924ec6b0ccdedcda6d296e09aa2dd5dca83b934cac752993238aa4fe826be8d62991c9347bae6f01bc0b1b4223d,
            });

            try testArgs(@Vector(1, u512), .{
                0x651058c1d89a8f34cfc5e66b6d25294eecfcc4a7e1e4a356eb51ee7d7b2db25378e4afee51b7d18d16e520772a60c50a02d7966f40ced1870b32c658e5821397,
            }, .{
                0xd726e265ec80cb99510ba4f480ca64e959de5c528a7f54c386ecad22eeeefa845f0fd44b1bd64258a5f868197ee2d8fed59df9c9f0b72e74051a7ff20230880e,
            });
            try testArgs(@Vector(2, u512), .{
                0x22c8183c95cca8b09fdf541e431b73e9e4a1a5a00dff12381937fab52681d09d38ea25727d7025a2be08942cfa01535759e1644792e347c7901ec94b343c6337,
                0x292fdf644e75927e1aea9465ae2f60fb27550cd095f1afdea2cf7855286d26fbeed1c0b9c0474b73cb6b75621f7eadaa2f94ec358179ce2aaa0766df20da1ef3,
            }, .{
                0xe1cd8c0ca244c6626d4415e10b4ac43fa69e454c529c24fec4b13e6b945684d4ea833709c16c636ca78cffa5c5bf0fe945cd714a9ad695184a6bdad31dec9e31,
                0x8fa3d86099e9e2789d72f8e792290356d659ab20ac0414ff94745984c6ae7d986082197bb849889f912e896670aa2c1a11bd7e66e3f650710b0f0a18a1533f90,
            });

            try testArgs(@Vector(1, i513), .{
                0x0dd56664962c44dbd9941a8e45102e1e050ef164752b954c4029ce6a28752c97b76ce3b0ae50dd09076fc16c89c628bf82ea7d3250101c3ee1316e8c51a746a4b,
            }, .{
                -0x0c4f50a700f8d91c3944c66e6932ea9cf0433a309dd41fd8ec1ab6e7c7f031de17c7fa7bde7a162fd653c1911aeddd176271f5bd76cca68eeab79ffde88835808,
            });
            try testArgs(@Vector(2, i513), .{
                0x0099b42682a76cfc1d6a0b680cd44c907387e78ca92d4c30c555dd6b05f136ad7e136f892641f1b256ef2aa10b1497d1e5a25c9e29260bd861b4fdc1ccc821a4c,
                -0x03aafdfa35c0b27515ee422ee71afcb157c6b578a77b514a6134e759bd80100f41344d6016a4dc252034667cb7a9b5165c058c5af0a632ed4b9a49d345b54d711,
            }, .{
                -0x07c699f50cc1592587bae58fa52742130df1dcd12da8ab1a15d48cbb3c8adeccacd16da37b91ba8a4ffe02669a089e3a1aadf325f161b99a010e76275a11f8dd0,
                0x0cec94f5064e3d4736016908cee5bd5469c2c60ed22c560a68b5bbc3a912b984195d7a2aa499db9b67779eadf0158ac9e9c166d58d42720834c5cde96d9a22c33,
            });

            try testArgs(@Vector(1, u513), .{
                0x167f9eb1095f756f462ceb2a48b7a5230a92f9ca6c572f394d741475cfa791e9666852b7696944f624f938f9474fe64e2189c1a584bdadc70d0f6db5c94355c78,
            }, .{
                0x06566ddffb298aee609074e06fbd881774623431f401410416645844a6c95f65cb08e1765f9c80bdf8f6d0d4c8ec9113d96b6e94cf97909d7da8c6165773162d8,
            });
            try testArgs(@Vector(2, u513), .{
                0x0e58f2fad85c025548e8c011faf78307d5237f25c41a319b0ea826704fba3db56f5e1074e6c76c8ecb83004058ff7dc5157d397d93d6725ac604efe0a48e27b8e,
                0x1635d3b34a3186f0e3c8d6ecdea25c84be4ef1f1bbc503dba90e9a260ffd8ec781b857c28e30fcc108ea93c3afa6acb91de3ad3fdb8e68cacdf412bcd31121c5e,
            }, .{
                0x043c3969668c05c0bec64d7be9741790a17588b8fd35ab88b8708c32658acc6e92dfc1691ee41da1278f7abbfc3f92aea885cabc17c556688f0971ca40b2acdef,
                0x198d4fc313ec8bafc85712c426223460c465a976aade6ca2b21ccb216257519675dda21f0707134920d23479c983e0d8fc75bb5e113f19fa3b4f63a69329cf723,
            });

            try testArgs(@Vector(1, i1023), .{
                -0x18ad357e523014b4b2b02d7802e8d6687e0b37e0e20bc992d9a1d3498cdccc3683c62628505026725ccab8e2d7da378de5e3dd539f168530e83b8add890851977a58c640102ebeb7d15f56b024a54636008af9232f73ac4a83f9e502ed1f6cf0647e4d6c2cc6c6e8fc4a49abcb2e34fa927cc114692905d73ffed1aed664eab4,
            }, .{
                0x29757ede90f3fd7a77d970667941eee2f7f7df5dc1100562c8e3bd45dcf1cbbbffface90f0b4f2aef49642e1cdeaa19045cc6dcf9f81750bee8e9d84d951da233d16878ae1473d42146660bc454a78a4bc22ebf2916b7f535c4b88302ea0108b458bd38660e95b0ae703d268cff78b39be828918cf6bd9ad16a90d407d3ee5b1,
            });

            try testArgs(@Vector(1, u1023), .{
                0x7e22aa4f394329943e1f265df8327c44032b28baea5ce81dfdf9781ed2c9ad337964b57c1ad4cb03cb920035c85e8c6e475ad33742874226beeba62e3e130ff6fbd21e902e49f7f95c7c3b1c6d7ce34a1ed85ba8028b41d19ab9547e05da56e6c8fba7c9c4f949412808ac3fb8709e490a859bebe22a77e704c04ea44a4579a0,
            }, .{
                0x4d2ec73e1a38a7373514259ed749a9895a5c45e53498ad3e75690116ec167321c0bcaa4fe86301b486eba831e7c15c3872676afe677d01ad5d088b51d64248d1bce2e191dcb87d6c9f9b944554b5c5a74bb64c7eea50a0badc2f292251b640c97d5b8e9010eb2f034d77b3a7f14aafb76c104b196a4b76073503acb085055209,
            });

            try testArgs(@Vector(1, i1024), .{
                -0x4fe568569c0531c9bfbbda1516e93a6c61a3d035c98e13fdc85225165a3bea84d5dc6b610ced008f9321453af42ea50bbf6881d40d2759b73b9b6186c0d6d243f367e292cbbf6b5c5c30d7f4e8de19701c7b0fc9e67cdf31228daa1675a4887f6c4f1588b48855d6f4730a21f27dec8a756c568727709b65cd531020d53ff394,
            }, .{
                -0x7cab2a053dfbf944cd342460350c989fd1b4469a6c7b54ddcacd54e605d29c03651b5c463495610d82269c9ac5b51bfd07816a0f7b1ab50cb598989ed64607b3faff79a190702eb285b0fedc050ec1a71537abc47ec590eb671d4f76b19567049ba4789d1a4348385607a0320fbff9b78260536a9b6030bddb0b09da689d1687,
            });

            try testArgs(@Vector(1, u1024), .{
                0x0ca1a0dfaf8bb1da714b457d23c71aef948e66c7cd45c0aa941498a796fb18502ec32f34e885d0a107d44ae81595f8b52c2f0fb38e584b7139903a0e8a823ae20d01ca0662722dd474e7efc40f32d74cc065d97d8a09d0447f1ab6107fa0a57f3f8c866ae872506627ce82f18add79cee8dc69837f4ead3ca770c4d622d7e544,
            }, .{
                0xf1e3bbe031d59351770a7a501b6e969b2c00d144f17648db3f944b69dfeb7be72e5ff933a061eba4eaa422f8ca09e5a97d0b0dd740fd4076eba8c72d7a278523f399202dc2d043c4e0eb58a2bcd4066e2146e321810b1ee4d3afdddb4f026bcc7905ce17e033a7727b4e08f33b53c63d8c9f763fc6c31d0523eb38c30d5e40bc,
            });

            try testArgs(@Vector(1, i1025), .{
                -0x0aac7daecbe81ad0f5b3582238ce842a9e57f580af344429c55785eb8ce32d28658417792d10e5263c6c7d0ab7d8ab6198d78bd024ce9c23de9470b20aa6eaf9dd301034cfee6b22025be5df4e91708d7cc9e980959a449b0cb893355392d1c94c4a4ed67d91108df655383f5f8fcde66f22dbd6453d838c1d160fb80ee07ab18,
            }, .{
                -0x0be0a1d4693d8969af6e26aa98ddb82f44124aa292fb336dd90cb5f28d708a33ef2d055db58e32578c5c20bb436a613b8ca214914db5066d458599600ced96129f4894b80293a3975e2bf7fd1a1f396d128ef89fd0609d2e518534e66c5e46c90b0a73e4a807c8a6decba204ac6e11859a492df1c81beec8b04961afa8544e081,
            });

            try testArgs(@Vector(1, u1025), .{
                0x129e165d8601a1ef41658e3ab9a7d0993124c46a37a672395a1314d5f8984de3c73e4569f1bd91f28aa8bf3e940d2121ef8bb557023abd80deb6761a7b0e2597763e5b895a52fc32308cc39b34a31f17fd8fe04bd1817e5b4a1046bbc1ee2bd360274e667be4392874a7dd8de7c8c054e3e6919302cb2ad46743798591ad0accb,
            }, .{
                0x07ff746b3d7ed091996cb20d21d6e85397c7daa127063a9f30cdb91483b145f2af3aa0bcf58188bc171e97a7b07800ee007af0305fb40e086ed2289dc7c303961d325bb799920a47de27bb16f6a868d80e93769982d81aa56cc3d1dbc87f1138179f0af4f6def885ade090d2725a044b500ef56fe39794906d45330fab9a4f81f,
            });
        }
        fn testFloatVectors() !void {
            @setEvalBranchQuota(21_700);

            try testArgs(@Vector(1, f16), .{
                -tmin(f16),
            }, .{
                fmax(f16),
            });
            try testArgs(@Vector(2, f16), .{
                1e-1, 1e0,
            }, .{
                -nan(f16), -fmin(f16),
            });
            try testArgs(@Vector(4, f16), .{
                1e-1, -fmax(f16), 0.0, 1e-1,
            }, .{
                -fmin(f16), -1e1, 1e0, -tmin(f16),
            });
            try testArgs(@Vector(8, f16), .{
                -fmax(f16), -fmin(f16), -nan(f16), -0.0, tmin(f16), -0.0, 0.0, 1e-1,
            }, .{
                -1e0, tmin(f16), nan(f16), nan(f16), -fmax(f16), -1e1, -nan(f16), 1e1,
            });
            try testArgs(@Vector(16, f16), .{
                1e-1, fmax(f16), -1e1, fmax(f16), -1e1, 1e-1, -tmin(f16), -inf(f16), -tmin(f16), -1e0, -fmin(f16), tmin(f16), 1e1, -fmax(f16), 0.0, -fmin(f16),
            }, .{
                inf(f16), -1e1, -fmax(f16), fmax(f16), -tmin(f16), 0.0, -1e0, -1e0, 1e-1, -nan(f16), -tmin(f16), 1e0, 1e-1, fmax(f16), -0.0, inf(f16),
            });
            try testArgs(@Vector(32, f16), .{
                -inf(f16), tmin(f16), fmin(f16), -nan(f16),  nan(f16),  1e-1,     0.0,        1e1,  -tmin(f16), inf(f16), 1e0,       -1e1, fmin(f16),  -0.0, 1e0,      -fmax(f16),
                1e1,       -0.0,      -1e1,      -tmin(f16), fmax(f16), nan(f16), -fmin(f16), -1e0, 0.0,        -1e1,     -nan(f16), 1e0,  -tmin(f16), -0.0, nan(f16), 1e1,
            }, .{
                0.0,      1e1,  -nan(f16), -0.0, tmin(f16),  fmax(f16), nan(f16),  tmin(f16), -1e1,       1e-1,      1e1, fmin(f16), -fmax(f16), inf(f16),   inf(f16),   -tmin(f16),
                inf(f16), -0.0, 1e-1,      0.0,  -fmin(f16), -0.0,      -nan(f16), -inf(f16), -fmin(f16), fmax(f16), 1e0, fmin(f16), -0.0,       -tmin(f16), -fmax(f16), -1e1,
            });
            try testArgs(@Vector(64, f16), .{
                -nan(f16), fmin(f16),  -inf(f16),  inf(f16),  -tmin(f16), inf(f16),   1e-1,      -1e0,      -inf(f16), nan(f16),  -fmin(f16), 1e-1,     -tmin(f16), -fmax(f16), -1e1,     inf(f16),
                0.0,       -fmin(f16), -fmax(f16), 1e1,       -fmax(f16), fmax(f16),  1e1,       fmin(f16), -inf(f16), -nan(f16), -tmin(f16), nan(f16), -0.0,       0.0,        1e-1,     -fmin(f16),
                0.0,       nan(f16),   inf(f16),   fmax(f16), nan(f16),   tmin(f16),  1e0,       tmin(f16), fmin(f16), -1e1,      0.0,        1e-1,     inf(f16),   -1e1,       inf(f16), 1e0,
                1e-1,      -inf(f16),  1e1,        -0.0,      -1e0,       -tmin(f16), -nan(f16), 1e-1,      1e-1,      -nan(f16), -0.0,       -1e1,     -0.0,       -nan(f16),  1e-1,     fmin(f16),
            }, .{
                1e1,        0.0,       fmax(f16), -inf(f16),  -fmax(f16), -fmax(f16), tmin(f16), -1e0,       -tmin(f16), -1e1, nan(f16), -nan(f16), tmin(f16),  -fmin(f16), nan(f16), -1e1,
                1e1,        fmax(f16), 1e-1,      0.0,        1e-1,       -fmax(f16), -0.0,      -fmin(f16), inf(f16),   -1e0, inf(f16), fmin(f16), -inf(f16),  -tmin(f16), 1e1,      1e1,
                1e-1,       1e-1,      1e-1,      1e1,        -fmin(f16), inf(f16),   1e-1,      fmax(f16),  inf(f16),   -0.0, -1e1,     tmin(f16), -fmin(f16), 0.0,        1e1,      0.0,
                -tmin(f16), -inf(f16), 1e0,       -fmax(f16), inf(f16),   1e1,        fmax(f16), -1e0,       0.0,        1e-1, -1e0,     -inf(f16), 1e-1,       0.0,        -1e1,     fmax(f16),
            });
            try testArgs(@Vector(128, f16), .{
                -fmin(f16), 1e0,        0.0,       1e-1,      nan(f16),   1e-1,       1e-1,      -inf(f16),  -tmin(f16), 1e0,        -fmin(f16), -fmax(f16), -1e0,      -fmin(f16), 1e1,        -nan(f16),
                inf(f16),   -inf(f16),  tmin(f16), -1e1,      -1e0,       -0.0,       -0.0,      1e0,        nan(f16),   -1e1,       fmin(f16),  -tmin(f16), tmin(f16), 1e-1,       -fmax(f16), fmax(f16),
                tmin(f16),  -fmin(f16), nan(f16),  1e1,       1e0,        -fmin(f16), 1e-1,      1e1,        fmax(f16),  fmax(f16),  fmax(f16),  -1e0,       -nan(f16), 1e1,        tmin(f16),  -nan(f16),
                -nan(f16),  -inf(f16),  -0.0,      -inf(f16), nan(f16),   -1e0,       1e-1,      -fmax(f16), -1e1,       nan(f16),   1e0,        -1e1,       tmin(f16), 1e0,        1e-1,       1e0,
                1e1,        1e-1,       tmin(f16), nan(f16),  -inf(f16),  -1e0,       -1e0,      -fmax(f16), -inf(f16),  1e-1,       1e-1,       -0.0,       1e1,       fmin(f16),  -1e0,       inf(f16),
                1e-1,       -1e1,       inf(f16),  -0.0,      1e-1,       0.0,        inf(f16),  1e0,        tmin(f16),  -tmin(f16), 1e-1,       inf(f16),   tmin(f16), -inf(f16),  1e1,        1e0,
                -inf(f16),  1e-1,       1e0,       fmax(f16), -fmin(f16), nan(f16),   -nan(f16), fmin(f16),  -1e0,       -fmax(f16), inf(f16),   -fmax(f16), 0.0,       -1e1,       fmin(f16),  -fmax(f16),
                -0.0,       -1e0,       1e-1,      1e1,       inf(f16),   fmax(f16),  inf(f16),  1e1,        fmax(f16),  -0.0,       -tmin(f16), fmin(f16),  inf(f16),  nan(f16),   -fmin(f16), -1e0,
            }, .{
                -fmax(f16), fmax(f16),  inf(f16),  1e0,        nan(f16),  1e-1,      -fmax(f16), 1e1,        -fmin(f16), 1e-1,       fmin(f16),  -0.0,      1e-1,       -0.0,      -nan(f16),  -nan(f16),
                inf(f16),   1e0,        -1e0,      1e-1,       1e-1,      1e-1,      0.0,        -tmin(f16), -1e0,       -1e1,       -tmin(f16), 1e0,       -1e1,       fmin(f16), -fmax(f16), -nan(f16),
                -tmin(f16), -inf(f16),  inf(f16),  -fmin(f16), -nan(f16), 0.0,       -inf(f16),  -fmax(f16), 1e-1,       -inf(f16),  tmin(f16),  nan(f16),  tmin(f16),  fmin(f16), -0.0,       1e-1,
                fmin(f16),  fmin(f16),  1e0,       tmin(f16),  0.0,       1e1,       1e-1,       inf(f16),   1e1,        -tmin(f16), tmin(f16),  -1e0,      -fmin(f16), 1e0,       nan(f16),   -fmax(f16),
                nan(f16),   -fmin(f16), 1e-1,      1e1,        -1e1,      1e0,       -0.0,       tmin(f16),  nan(f16),   inf(f16),   -fmax(f16), tmin(f16), -tmin(f16), 1e1,       fmin(f16),  -tmin(f16),
                -0.0,       1e0,        tmin(f16), fmax(f16),  1e0,       -inf(f16), -nan(f16),  -0.0,       1e-1,       -inf(f16),  1e-1,       fmax(f16), -inf(f16),  -nan(f16), -1e0,       -inf(f16),
                1e-1,       fmin(f16),  -1e1,      -tmin(f16), 1e0,       -nan(f16), -fmax(f16), -1e1,       -tmin(f16), 1e1,        nan(f16),   fmin(f16), fmax(f16),  tmin(f16), -inf(f16),  1e0,
                -fmin(f16), tmin(f16),  -1e0,      1e-1,       0.0,       nan(f16),  1e0,        fmax(f16),  -1e0,       1e1,        nan(f16),   1e0,       fmin(f16),  1e0,       -1e1,       -1e1,
            });
            try testArgs(@Vector(69, f16), .{
                -nan(f16), -1e0,      -fmin(f16), fmin(f16), inf(f16),  1e-1,      0.0,       fmax(f16),  tmin(f16), 1e-1,      0.0,        -tmin(f16), 0.0,        0.0,        1e0,        -inf(f16),
                tmin(f16), -inf(f16), -tmin(f16), fmin(f16), -inf(f16), -nan(f16), tmin(f16), -tmin(f16), 1e-1,      -1e0,      -tmin(f16), fmax(f16),  nan(f16),   -fmin(f16), fmin(f16),  1e1,
                fmin(f16), -1e1,      0.0,        fmin(f16), fmax(f16), -nan(f16), fmax(f16), -fmax(f16), nan(f16),  -nan(f16), fmin(f16),  -1e1,       -fmin(f16), fmin(f16),  -fmin(f16), -nan(f16),
                0.0,       -1e0,      fmax(f16),  1e-1,      inf(f16),  1e0,       -1e0,      -0.0,       1e1,       1e-1,      -fmax(f16), tmin(f16),  -inf(f16),  tmin(f16),  -fmax(f16), 1e-1,
                -1e1,      -0.0,      -fmax(f16), nan(f16),  fmax(f16),
            }, .{
                inf(f16),   -fmin(f16), 1e-1,      1e-1,      -0.0,       fmax(f16),  1e-1,      -0.0,      0.0,       -0.0,       0.0,       -tmin(f16), tmin(f16), -1e0,     nan(f16),   -fmin(f16),
                fmin(f16),  1e-1,       1e-1,      nan(f16),  -fmax(f16), -inf(f16),  -nan(f16), -nan(f16), 1e-1,      -fmax(f16), fmin(f16), 1e-1,       1e-1,      1e-1,     -0.0,       1e1,
                tmin(f16),  -nan(f16),  fmin(f16), -1e0,      1e0,        -tmin(f16), 0.0,       nan(f16),  fmax(f16), -1e1,       fmin(f16), -fmin(f16), -1e0,      1e-1,     -fmin(f16), -fmin(f16),
                -fmax(f16), 0.0,        fmin(f16), -1e1,      -1e0,       -1e0,       fmax(f16), -nan(f16), -inf(f16), -inf(f16),  0.0,       tmin(f16),  -0.0,      nan(f16), -inf(f16),  nan(f16),
                inf(f16),   fmin(f16),  -nan(f16), -inf(f16), inf(f16),
            });

            try testArgs(@Vector(1, f32), .{
                fmin(f32),
            }, .{
                -tmin(f32),
            });
            try testArgs(@Vector(2, f32), .{
                nan(f32), -1e1,
            }, .{
                -tmin(f32), fmin(f32),
            });
            try testArgs(@Vector(4, f32), .{
                fmax(f32), -fmax(f32), -1e1, 0.0,
            }, .{
                inf(f32), inf(f32), -1e1, inf(f32),
            });
            try testArgs(@Vector(8, f32), .{
                -1e1, fmax(f32), inf(f32), -0.0, -tmin(f32), -tmin(f32), 1e1, 1e-1,
            }, .{
                1e1, -1e0, -1e0, inf(f32), 1e0, -tmin(f32), nan(f32), 1e1,
            });
            try testArgs(@Vector(16, f32), .{
                1e-1, 1e-1, -nan(f32), -1e1, -nan(f32), 0.0, fmin(f32), fmin(f32), -1e1, 1e0, -fmax(f32), -0.0, inf(f32), -0.0, fmax(f32), -fmin(f32),
            }, .{
                nan(f32), 0.0, tmin(f32), -1e0, -1e1, -tmin(f32), fmin(f32), -fmax(f32), 1e-1, 1e-1, -inf(f32), tmin(f32), -0.0, 1e1, -0.0, -inf(f32),
            });
            try testArgs(@Vector(32, f32), .{
                1e-1,       tmin(f32), -1e0,       1e0,       tmin(f32), -1e1,      fmax(f32), 0.0,       tmin(f32),  1e-1,      -1e0,     fmax(f32),  -nan(f32), -0.0,      fmin(f32), 0.0,
                -fmax(f32), fmax(f32), -fmin(f32), -inf(f32), tmin(f32), -nan(f32), -1e0,      tmin(f32), -fmin(f32), -inf(f32), nan(f32), -tmin(f32), inf(f32),  -inf(f32), -nan(f32), 1e-1,
            }, .{
                -fmin(f32), -1e0,      fmax(f32), inf(f32),   -fmin(f32), fmax(f32),  0.0,       -1e1, 0.0,  1e-1,      fmin(f32), -inf(f32),  1e0, -nan(f32), -nan(f32),
                -inf(f32),  -0.0,      nan(f32),  -fmax(f32), 1e1,        -tmin(f32), fmax(f32), -1e1, 1e-1, tmin(f32), 1e-1,      -fmax(f32), 0.0, 1e-1,      -nan(f32),
                -fmin(f32), fmax(f32),
            });
            try testArgs(@Vector(64, f32), .{
                fmin(f32),  0.0,  -inf(f32), 1e-1,      -1e1,      -fmin(f32), 1e1,        nan(f32),  1e-1,       1e0,       -1e0,      1e1,        1e1,       1e-1,       -fmax(f32), -1e0,
                -fmin(f32), 1e-1, -inf(f32), -inf(f32), 1e-1,      1e-1,       0.0,        -1e0,      nan(f32),   -0.0,      -0.0,      -fmin(f32), -inf(f32), inf(f32),   tmin(f32),  -nan(f32),
                1e-1,       0.0,  1e0,       tmin(f32), 1e1,       fmin(f32),  -fmin(f32), fmax(f32), nan(f32),   1e0,       -nan(f32), -nan(f32),  1e0,       nan(f32),   1e0,        fmax(f32),
                -0.0,       0.0,  inf(f32),  nan(f32),  tmin(f32), 0.0,        fmin(f32),  -0.0,      -fmin(f32), tmin(f32), -1e0,      -1e1,       1e-1,      -tmin(f32), -inf(f32),  -1e0,
            }, .{
                nan(f32),   -nan(f32),  -tmin(f32), inf(f32),   -inf(f32), 1e-1,      1e-1,       1e-1,       -1e0,       -inf(f32),  -0.0,     fmax(f32), tmin(f32), -nan(f32),  -fmax(f32), -1e0,
                -fmin(f32), -0.0,       fmax(f32),  -fmax(f32), 1e0,       -0.0,      0.0,        1e1,        -1e0,       -fmin(f32), 0.0,      fmax(f32), 1e-1,      1e0,        1e1,        1e-1,
                1e-1,       fmin(f32),  -nan(f32),  -inf(f32),  -0.0,      -inf(f32), 1e-1,       -fmax(f32), -1e1,       -1e1,       nan(f32), 1e1,       -1e0,      -fmin(f32), 1e1,        fmin(f32),
                1e0,        -fmax(f32), nan(f32),   inf(f32),   fmax(f32), fmax(f32), -fmin(f32), -inf(f32),  -tmin(f32), -nan(f32),  nan(f32), nan(f32),  1e-1,      1e-1,       -1e0,       inf(f32),
            });
            try testArgs(@Vector(128, f32), .{
                -1e1,       -nan(f32),  inf(f32),   inf(f32),  -tmin(f32), -0.0,       0.0,        1e-1,       -0.0,       fmin(f32),  nan(f32),   -1e0,       nan(f32),   -fmax(f32), nan(f32),   0.0,
                1e0,        -tmin(f32), 0.0,        -nan(f32), 1e-1,       1e-1,       -1e0,       1e1,        -fmax(f32), -fmin(f32), 1e-1,       nan(f32),   1e-1,       -fmax(f32), -tmin(f32), -inf(f32),
                inf(f32),   tmin(f32),  -tmin(f32), nan(f32),  -inf(f32),  -1e1,       1e0,        -nan(f32),  1e-1,       nan(f32),   -1e0,       tmin(f32),  -fmin(f32), -0.0,       -0.0,       1e0,
                fmin(f32),  -fmin(f32), 1e-1,       1e-1,      1e-1,       -1e1,       -1e1,       -tmin(f32), 1e0,        -0.0,       1e1,        -fmax(f32), 1e1,        -fmax(f32), inf(f32),   -1e0,
                -fmax(f32), fmin(f32),  fmin(f32),  fmin(f32), -1e0,       -nan(f32),  fmax(f32),  -nan(f32),  1e-1,       -1e0,       -fmax(f32), -tmin(f32), -0.0,       fmax(f32),  -1e1,       inf(f32),
                1e1,        -inf(f32),  1e-1,       fmin(f32), nan(f32),   -fmax(f32), -tmin(f32), inf(f32),   tmin(f32),  -fmin(f32), fmax(f32),  1e0,        fmin(f32),  -0.0,       1e-1,       fmin(f32),
                1e-1,       inf(f32),   -1e1,       inf(f32),  1e1,        tmin(f32),  0.0,        1e0,        inf(f32),   -1e1,       -fmin(f32), tmin(f32),  1e0,        1e-1,       1e-1,       -fmin(f32),
                1e1,        1e-1,       fmax(f32),  fmin(f32), 1e0,        -1e1,       -inf(f32),  -1e1,       0.0,        -fmax(f32), -inf(f32),  -1e0,       fmax(f32),  -tmin(f32), inf(f32),   nan(f32),
            }, .{
                -tmin(f32), -fmax(f32), -fmax(f32), 1e1,        inf(f32),  1e-1,     1e0,        fmin(f32),  1e-1,       1e1,        fmin(f32),  -fmax(f32), 1e0,        fmax(f32),  1e-1,       -fmin(f32),
                0.0,        -0.0,       -0.0,       -1e0,       -nan(f32), nan(f32), -tmin(f32), 1e1,        -tmin(f32), -1e1,       inf(f32),   0.0,        tmin(f32),  0.0,        -fmax(f32), inf(f32),
                fmin(f32),  1e-1,       -1e1,       tmin(f32),  tmin(f32), 1e-1,     fmin(f32),  -tmin(f32), fmin(f32),  nan(f32),   1e-1,       -fmax(f32), -1e0,       -0.0,       fmin(f32),  -0.0,
                -1e0,       -0.0,       -inf(f32),  fmax(f32),  -1e1,      1e0,      inf(f32),   -1e0,       -tmin(f32), -tmin(f32), 1e-1,       -1e1,       -fmin(f32), 1e1,        -1e1,       -inf(f32),
                -1e0,       inf(f32),   1e-1,       1e0,        -nan(f32), 1e-1,     -1e1,       -nan(f32),  -tmin(f32), 0.0,        fmin(f32),  -nan(f32),  fmax(f32),  -tmin(f32), 0.0,        0.0,
                -fmax(f32), -inf(f32),  -1e0,       -0.0,       1e1,       nan(f32), 1e-1,       tmin(f32),  -1e1,       1e1,        tmin(f32),  -fmax(f32), 1e-1,       -1e1,       -tmin(f32), fmax(f32),
                -fmax(f32), 1e-1,       -nan(f32),  -fmin(f32), inf(f32),  inf(f32), tmin(f32),  tmin(f32),  -tmin(f32), tmin(f32),  0.0,        -0.0,       1e0,        1e1,        -1e1,       inf(f32),
                0.0,        -fmin(f32), fmax(f32),  -1e1,       fmax(f32), -0.0,     0.0,        -fmin(f32), 1e1,        -fmin(f32), -fmin(f32), -fmin(f32), 1e1,        fmin(f32),  -inf(f32),  fmax(f32),
            });
            try testArgs(@Vector(69, f32), .{
                nan(f32),   1e-1,      -tmin(f32), fmax(f32),  nan(f32),  -fmax(f32), 1e-1,       fmax(f32), 1e1,        inf(f32), -fmin(f32), -fmax(f32), inf(f32),   -nan(f32),  1e-1,       1e0,
                fmax(f32),  1e-1,      1e1,        0.0,        -1e1,      fmax(f32),  1e1,        0.0,       1e0,        1e1,      -fmax(f32), 0.0,        -tmin(f32), -fmin(f32), 1e-1,       1e0,
                fmin(f32),  tmin(f32), -fmin(f32), -tmin(f32), tmin(f32), -inf(f32),  -fmax(f32), -0.0,      -1e0,       -0.0,     -fmax(f32), fmax(f32),  fmin(f32),  -0.0,       0.0,        -inf(f32),
                -tmin(f32), inf(f32),  -nan(f32),  tmin(f32),  -1e0,      -tmin(f32), 1e1,        -inf(f32), -fmin(f32), 1e-1,     -inf(f32),  -1e0,       nan(f32),   -inf(f32),  -tmin(f32), 1e1,
                1e1,        -nan(f32), -nan(f32),  tmin(f32),  -nan(f32),
            }, .{
                -nan(f32), 1e0,       fmax(f32), 1e-1,       -0.0,       1e0,       -inf(f32), -fmin(f32), -nan(f32), inf(f32),   1e0,       -nan(f32), -nan(f32), -inf(f32), tmin(f32), -fmin(f32),
                -nan(f32), 1e-1,      fmin(f32), -1e0,       -fmax(f32), 1e-1,      -1e0,      1e-1,       1e-1,      -tmin(f32), 1e-1,      1e-1,      1e1,       fmin(f32), 0.0,       nan(f32),
                tmin(f32), 1e0,       nan(f32),  -fmin(f32), tmin(f32),  nan(f32),  1e-1,      nan(f32),   1e0,       -fmax(f32), tmin(f32), 1e0,       0.0,       -1e0,      nan(f32),  fmin(f32),
                -inf(f32), fmax(f32), -0.0,      nan(f32),   tmin(f32),  tmin(f32), -inf(f32), -1e1,       -nan(f32), -fmax(f32), -0.0,      1e-1,      -inf(f32), 1e0,       nan(f32),  1e0,
                -1e1,      fmin(f32), inf(f32),  fmin(f32),  0.0,
            });

            try testArgs(@Vector(1, f64), .{
                -0.0,
            }, .{
                1e0,
            });
            try testArgs(@Vector(2, f64), .{
                -1e0, 0.0,
            }, .{
                -inf(f64), -fmax(f64),
            });
            try testArgs(@Vector(4, f64), .{
                -inf(f64), inf(f64), 1e1, 0.0,
            }, .{
                -tmin(f64), 1e0, nan(f64), 0.0,
            });
            try testArgs(@Vector(8, f64), .{
                1e-1, -tmin(f64), -fmax(f64), 1e0, inf(f64), -1e1, -tmin(f64), -1e1,
            }, .{
                tmin(f64), fmin(f64), 1e-1, 1e1, -0.0, -0.0, fmax(f64), -1e0,
            });
            try testArgs(@Vector(16, f64), .{
                1e-1, -nan(f64), 1e0, tmin(f64), fmax(f64), -fmax(f64), -tmin(f64), -0.0, -fmin(f64), -1e0, -fmax(f64), -nan(f64), -fmax(f64), nan(f64), -0.0, 1e-1,
            }, .{
                -1e0, -tmin(f64), -fmin(f64), 1e-1, 1e-1, -0.0, -nan(f64), -inf(f64), -inf(f64), -0.0, nan(f64), tmin(f64), 1e0, 1e-1, tmin(f64), fmin(f64),
            });
            try testArgs(@Vector(32, f64), .{
                -fmax(f64), fmin(f64), 1e-1, 1e-1,      0.0,       1e0,  -0.0, -tmin(f64), tmin(f64), inf(f64),  -tmin(f64), -tmin(f64), -tmin(f64), -fmax(f64), fmin(f64), 1e0,
                -fmin(f64), -nan(f64), 1e0,  -inf(f64), -nan(f64), -1e0, 0.0,  0.0,        nan(f64),  -nan(f64), -fmin(f64), fmin(f64),  1e-1,       nan(f64),   tmin(f64), -fmax(f64),
            }, .{
                -tmin(f64), -fmax(f64), -inf(f64),  -nan(f64), fmin(f64), -inf(f64), 1e-1,     -fmax(f64), -inf(f64), fmin(f64), inf(f64), -1e0, -tmin(f64), inf(f64), 1e-1, nan(f64),
                fmin(f64),  1e1,        -tmin(f64), -nan(f64), -inf(f64), 1e0,       nan(f64), -fmin(f64), -1e0,      nan(f64),  -1e0,     0.0,  1e0,        nan(f64), -1e0, -fmin(f64),
            });
            try testArgs(@Vector(64, f64), .{
                -1e1,      fmax(f64),  -nan(f64),  tmin(f64),  1e-1,      -1e0,       1e0,      -0.0,      -fmin(f64), 1e-1,      -fmin(f64), -0.0,      -0.0,      tmin(f64), -1e1,      1e-1,
                -1e1,      -fmax(f64), -1e1,       -fmin(f64), 0.0,       -1e1,       nan(f64), 1e0,       inf(f64),   inf(f64),  -inf(f64),  tmin(f64), tmin(f64), 1e-1,      -0.0,      1e-1,
                -0.0,      1e-1,       -1e1,       1e1,        fmax(f64), -fmin(f64), 1e0,      fmax(f64), 1e0,        -1e1,      fmin(f64),  fmax(f64), -1e0,      -0.0,      -0.0,      fmax(f64),
                -inf(f64), -inf(f64),  -tmin(f64), -fmax(f64), -nan(f64), tmin(f64),  -1e0,     0.0,       -inf(f64),  fmax(f64), nan(f64),   -inf(f64), fmin(f64), -nan(f64), -nan(f64), -1e1,
            }, .{
                nan(f64),  -1e0, 0.0,       -1e1,       -fmax(f64), -fmin(f64), -nan(f64),  -tmin(f64), 1e-1,       -1e0,      -nan(f64),  -fmax(f64), 0.0,       0.0,      1e1,       inf(f64),
                fmin(f64), 0.0,  -1e1,      1e0,        -tmin(f64), -inf(f64),  -fmax(f64), 0.0,        -fmin(f64), -1e0,      -fmin(f64), tmin(f64),  1e0,       -1e1,     fmin(f64), 1e-1,
                inf(f64),  -0.0, tmin(f64), -fmax(f64), -tmin(f64), -fmax(f64), fmin(f64),  -fmax(f64), 1e-1,       1e0,       1e0,        0.0,        fmin(f64), nan(f64), -1e1,      tmin(f64),
                inf(f64),  1e-1, 1e0,       -nan(f64),  1e0,        -fmin(f64), fmax(f64),  inf(f64),   fmin(f64),  -inf(f64), -0.0,       0.0,        -1e0,      -0.0,     1e-1,      1e-1,
            });
            try testArgs(@Vector(128, f64), .{
                nan(f64),   -fmin(f64), fmax(f64),  fmin(f64), -1e1,       nan(f64),  tmin(f64), fmax(f64),  inf(f64),   -nan(f64),  tmin(f64),  -nan(f64), -0.0,       fmin(f64),  fmax(f64),
                -inf(f64),  inf(f64),   -1e0,       0.0,       1e-1,       fmin(f64), 0.0,       1e-1,       -1e0,       -inf(f64),  1e-1,       fmax(f64), fmin(f64),  fmax(f64),  -fmax(f64),
                fmin(f64),  inf(f64),   -fmin(f64), -1e1,      -0.0,       1e-1,      nan(f64),  -fmax(f64), -fmax(f64), -1e0,       1e1,        1e1,       -1e0,       -inf(f64),  inf(f64),
                -fmin(f64), 1e0,        -inf(f64),  -1e1,      1e-1,       1e0,       1e1,       1e1,        tmin(f64),  nan(f64),   inf(f64),   0.0,       -1e0,       -1e1,       1e0,
                -tmin(f64), -fmax(f64), -nan(f64),  1e1,       1e-1,       tmin(f64), 0.0,       1e1,        1e-1,       -tmin(f64), -tmin(f64), 1e0,       -fmax(f64), nan(f64),   -fmin(f64),
                nan(f64),   1e1,        -1e0,       -0.0,      -tmin(f64), nan(f64),  1e1,       1e1,        -inf(f64),  1e-1,       -nan(f64),  -1e1,      -tmin(f64), -fmax(f64), -fmax(f64),
                inf(f64),   -inf(f64),  tmin(f64),  1e0,       -inf(f64),  -1e1,      inf(f64),  1e-1,       -nan(f64),  -inf(f64),  fmax(f64),  1e-1,      -inf(f64),  1e-1,       1e0,
                1e-1,       1e-1,       1e-1,       inf(f64),  -inf(f64),  1e0,       1e1,       1e1,        nan(f64),   1e1,        -tmin(f64), 1e0,       -fmin(f64), -1e0,       -fmax(f64),
                -fmin(f64), -fmin(f64), -1e0,       inf(f64),  nan(f64),   tmin(f64), 1e-1,      -1e0,
            }, .{
                0.0,       0.0,        inf(f64),  -0.0,       1e-1,       -nan(f64),  1e1,        -nan(f64), tmin(f64),  -1e1,       -0.0,      inf(f64),   -fmin(f64), 1e-1,       fmax(f64),
                nan(f64),  -tmin(f64), tmin(f64), 1e0,        1e-1,       -1e1,       -nan(f64),  1e0,       inf(f64),   -1e1,       fmin(f64), 1e-1,       1e1,        -1e1,       1e1,
                -nan(f64), -nan(f64),  1e-1,      0.0,        1e1,        -fmax(f64), -tmin(f64), tmin(f64), -1e0,       -tmin(f64), -1e1,      1e-1,       -fmax(f64), 1e1,        nan(f64),
                fmax(f64), -1e0,       -1e0,      -tmin(f64), fmax(f64),  -1e1,       1e-1,       1e0,       fmin(f64),  inf(f64),   1e-1,      tmin(f64),  1e-1,       -fmax(f64), fmax(f64),
                -1e1,      -fmax(f64), fmax(f64), tmin(f64),  -fmin(f64), inf(f64),   1e-1,       -0.0,      fmax(f64),  tmin(f64),  1e-1,      1e0,        -inf(f64),  1e0,        1e1,
                1e-1,      0.0,        -1e1,      -nan(f64),  1e1,        -fmin(f64), -tmin(f64), 1e1,       1e0,        -tmin(f64), -1e0,      -fmin(f64), -0.0,       -1e1,       1e-1,
                inf(f64),  -fmax(f64), 1e-1,      tmin(f64),  -0.0,       fmax(f64),  0.0,        -nan(f64), -fmin(f64), fmax(f64),  -0.0,      nan(f64),   -inf(f64),  tmin(f64),  1e-1,
                inf(f64),  0.0,        1e1,       -fmax(f64), tmin(f64),  -0.0,       fmin(f64),  -nan(f64), -1e1,       -inf(f64),  nan(f64),  inf(f64),   -0.0,       1e1,        fmax(f64),
                tmin(f64), -1e1,       -nan(f64), 1e1,        -inf(f64),  -fmax(f64), -inf(f64),  -1e0,
            });
            try testArgs(@Vector(69, f64), .{
                inf(f64),   -0.0,      -fmax(f64), fmax(f64),  fmax(f64), 0.0,      fmin(f64), -nan(f64), 1e-1,      1e-1,      1e-1,       -fmin(f64), inf(f64),   1e-1,      fmax(f64),  nan(f64),
                tmin(f64),  -1e1,      1e1,        -tmin(f64), -0.0,      nan(f64), -1e1,      fmin(f64), 0.0,       -0.0,      1e-1,       inf(f64),   -tmin(f64), -nan(f64), inf(f64),   -nan(f64),
                -inf(f64),  fmax(f64), 1e-1,       -fmin(f64), 1e-1,      -1e0,     fmin(f64), fmin(f64), fmin(f64), 1e1,       -fmin(f64), nan(f64),   0.0,        0.0,       1e1,        nan(f64),
                -tmin(f64), tmin(f64), tmin(f64),  fmin(f64),  -0.0,      -1e0,     1e-1,      1e0,       fmax(f64), tmin(f64), fmin(f64),  0.0,        -fmin(f64), fmin(f64), -tmin(f64), 0.0,
                -nan(f64),  1e1,       -1e0,       1e-1,       0.0,
            }, .{
                -1e1,       -0.0,       fmin(f64), -fmin(f64), nan(f64),  1e1,      -tmin(f64), -fmax(f64), 1e1,       1e-1,     -fmin(f64), inf(f64),  -inf(f64),  -tmin(f64), 1e0,        tmin(f64),
                -tmin(f64), -nan(f64),  fmax(f64), 0.0,        -1e0,      1e1,      inf(f64),   fmin(f64),  fmax(f64), 1e-1,     1e-1,       fmax(f64), -inf(f64),  1e-1,       1e-1,       fmin(f64),
                1e-1,       fmin(f64),  -1e1,      nan(f64),   0.0,       0.0,      fmax(f64),  -inf(f64),  tmin(f64), inf(f64), -tmin(f64), fmax(f64), -inf(f64),  -1e1,       -1e0,       fmin(f64),
                1e-1,       -nan(f64),  fmax(f64), -fmin(f64), fmax(f64), nan(f64), -0.0,       -fmax(f64), 1e1,       nan(f64), inf(f64),   -1e0,      -fmin(f64), nan(f64),   -fmin(f64), -0.0,
                -nan(f64),  -fmin(f64), 1e-1,      nan(f64),   1e-1,
            });

            try testArgs(@Vector(1, f80), .{
                -nan(f80),
            }, .{
                -1e0,
            });
            try testArgs(@Vector(2, f80), .{
                -fmax(f80), -inf(f80),
            }, .{
                1e-1, 1e1,
            });
            try testArgs(@Vector(4, f80), .{
                -0.0, -inf(f80), 1e-1, 1e1,
            }, .{
                -1e0, 0.0, 1e-1, -1e1,
            });
            try testArgs(@Vector(8, f80), .{
                1e0, -0.0, -inf(f80), 1e-1, -inf(f80), fmin(f80), 0.0, 1e1,
            }, .{
                -0.0, -fmin(f80), fmin(f80), -nan(f80), nan(f80), inf(f80), fmin(f80), 1e1,
            });
            try testArgs(@Vector(16, f80), .{
                1e1, inf(f80), -fmin(f80), 1e-1, -tmin(f80), -0.0, -inf(f80), -1e0, -fmax(f80), -nan(f80), -tmin(f80), 1e1, 1e1, -inf(f80), -fmax(f80), fmax(f80),
            }, .{
                -inf(f80), nan(f80), -fmax(f80), fmin(f80), 1e0, 1e-1, -inf(f80), nan(f80), 1e-1, nan(f80), -inf(f80), nan(f80), tmin(f80), 1e-1, -tmin(f80), -1e1,
            });
            try testArgs(@Vector(32, f80), .{
                inf(f80),  -0.0, 1e-1,     -0.0, 1e-1,     -fmin(f80), -0.0,       fmax(f80), nan(f80),  -tmin(f80), nan(f80), -1e1,       0.0,       1e0,        1e1, -fmin(f80),
                fmin(f80), 1e-1, inf(f80), -0.0, nan(f80), tmin(f80),  -tmin(f80), fmin(f80), tmin(f80), -0.0,       nan(f80), -fmax(f80), tmin(f80), -fmin(f80), 1e0, tmin(f80),
            }, .{
                0.0,  -1e1,     fmax(f80), -inf(f80),  1e-1,      -inf(f80), inf(f80),   1e1,  -1e0, -1e1,      -fmin(f80), 0.0,  inf(f80),   1e0,        -nan(f80), 0.0,
                1e-1, nan(f80), 1e0,       -fmax(f80), fmin(f80), -inf(f80), -fmax(f80), 1e-1, -1e1, tmin(f80), fmax(f80),  -0.0, -fmin(f80), -fmin(f80), fmin(f80), -tmin(f80),
            });
            try testArgs(@Vector(64, f80), .{
                -fmax(f80), 1e-1,      -1e0,       1e0,        inf(f80),   1e-1,      -1e1,      1e-1,      fmin(f80), -fmin(f80), -1e1,      -fmax(f80), 0.0,        -1e1,      -1e0,       -nan(f80),
                0.0,        1e-1,      -1e0,       -tmin(f80), 1e0,        tmin(f80), fmax(f80), 0.0,       -1e1,      -tmin(f80), fmax(f80), -0.0,       1e-1,       -inf(f80), -fmax(f80), -1e0,
                -nan(f80),  tmin(f80), -tmin(f80), -0.0,       -0.0,       -1e0,      -0.0,      fmax(f80), inf(f80),  -nan(f80),  1e-1,      -inf(f80),  -tmin(f80), nan(f80),  1e-1,       1e1,
                nan(f80),   -inf(f80), 1e-1,       tmin(f80),  -fmin(f80), 1e1,       -1e1,      tmin(f80), fmin(f80), nan(f80),   1e-1,      -nan(f80),  tmin(f80),  nan(f80),  fmax(f80),  -fmax(f80),
            }, .{
                -nan(f80), -fmax(f80), tmin(f80), -inf(f80),  -tmin(f80), fmin(f80), -nan(f80), -fmin(f80), fmax(f80), inf(f80), -0.0,      -1e0, 1e-1,       -fmax(f80), 1e0,       -inf(f80),
                0.0,       -nan(f80),  -1e1,      -1e0,       -nan(f80),  inf(f80),  1e0,       -nan(f80),  1e1,       inf(f80), tmin(f80), 1e-1, tmin(f80),  -tmin(f80), -inf(f80), -fmin(f80),
                fmax(f80), fmax(f80),  1e-1,      -tmin(f80), -nan(f80),  -1e0,      fmin(f80), -nan(f80),  -nan(f80), inf(f80), -1e0,      1e-1, -fmin(f80), -tmin(f80), 0.0,       -0.0,
                1e-1,      -fmin(f80), -inf(f80), -1e0,       -tmin(f80), 1e0,       -inf(f80), -0.0,       0.0,       1e0,      tmin(f80), 0.0,  1e-1,       -nan(f80),  fmax(f80), 1e0,
            });
            try testArgs(@Vector(128, f80), .{
                1e-1,      -0.0,       1e-1,       0.0,        fmin(f80),  -1e0,      1e0,       -inf(f80),  fmax(f80),  -fmin(f80), nan(f80),   1e1,        1e-1,       1e-1,       -fmin(f80), -inf(f80),
                -1e0,      -inf(f80),  1e0,        -fmin(f80), inf(f80),   -nan(f80), 1e1,       inf(f80),   tmin(f80),  nan(f80),   -1e1,       inf(f80),   1e1,        inf(f80),   -1e1,       0.0,
                -1e1,      fmin(f80),  -tmin(f80), 1e0,        -fmax(f80), nan(f80),  0.0,       fmax(f80),  1e-1,       -1e0,       -fmin(f80), inf(f80),   -tmin(f80), nan(f80),   -tmin(f80), 1e1,
                -1e1,      -tmin(f80), -1e0,       -tmin(f80), -fmax(f80), 1e1,       -1e0,      -inf(f80),  -nan(f80),  0.0,        1e0,        fmax(f80),  -tmin(f80), -fmin(f80), fmin(f80),  fmin(f80),
                -1e1,      -fmax(f80), -tmin(f80), inf(f80),   1e0,        0.0,       tmin(f80), -nan(f80),  -fmin(f80), 1e-1,       -nan(f80),  0.0,        1e-1,       -1e1,       -0.0,       -nan(f80),
                1e0,       1e1,        -1e1,       fmin(f80),  -nan(f80),  fmax(f80), -0.0,      1e0,        inf(f80),   1e0,        -fmin(f80), -fmin(f80), 0.0,        1e-1,       inf(f80),   1e1,
                tmin(f80), -1e0,       fmax(f80),  -0.0,       fmax(f80),  fmax(f80), 1e-1,      -fmin(f80), -1e1,       1e0,        -fmin(f80), -fmax(f80), fmin(f80),  -fmax(f80), -0.0,       -1e0,
                -nan(f80), -inf(f80),  nan(f80),   -fmax(f80), inf(f80),   -inf(f80), -nan(f80), fmin(f80),  nan(f80),   -1e0,       tmin(f80),  tmin(f80),  1e-1,       1e1,        -tmin(f80), -nan(f80),
            }, .{
                -1e0,       -0.0,      0.0,        fmax(f80),  -1e0,       -0.0,       1e-1,       tmin(f80),  -inf(f80),  1e1,        -0.0,       1e-1,      -tmin(f80), -fmax(f80), tmin(f80), inf(f80),
                1e-1,       1e0,       tmin(f80),  nan(f80),   -fmax(f80), 1e1,        fmin(f80),  -1e0,       -fmax(f80), nan(f80),   -fmin(f80), 1e1,       -1e0,       tmin(f80),  inf(f80),  -0.0,
                tmin(f80),  1e0,       0.0,        -fmin(f80), 0.0,        1e1,        -fmax(f80), -0.0,       -inf(f80),  fmin(f80),  -0.0,       -0.0,      -0.0,       -fmax(f80), 1e-1,      fmax(f80),
                -tmin(f80), tmin(f80), -fmax(f80), 1e1,        -fmax(f80), 1e-1,       fmax(f80),  -1e1,       1e-1,       1e0,        -1e0,       -1e0,      nan(f80),   -nan(f80),  1e1,       -nan(f80),
                nan(f80),   -1e1,      -tmin(f80), fmin(f80),  -tmin(f80), -fmin(f80), tmin(f80),  -0.0,       1e-1,       fmax(f80),  tmin(f80),  tmin(f80), nan(f80),   1e-1,       1e1,       1e-1,
                inf(f80),   inf(f80),  1e0,        -inf(f80),  -fmax(f80), 0.0,        1e0,        -fmax(f80), fmax(f80),  nan(f80),   fmin(f80),  1e-1,      -1e0,       1e0,        1e-1,      -tmin(f80),
                1e1,        1e-1,      -fmax(f80), 0.0,        nan(f80),   -tmin(f80), 1e-1,       fmax(f80),  fmax(f80),  1e-1,       -1e0,       inf(f80),  nan(f80),   1e1,        fmax(f80), -nan(f80),
                -1e1,       -1e0,      tmin(f80),  fmin(f80),  inf(f80),   fmax(f80),  -fmin(f80), fmin(f80),  -inf(f80),  -tmin(f80), 1e0,        nan(f80),  -fmin(f80), -fmin(f80), fmax(f80), 1e0,
            });
            try testArgs(@Vector(69, f80), .{
                -1e1,       tmin(f80), 1e-1,       -nan(f80), -inf(f80), -nan(f80), fmin(f80), -0.0,       1e1,  fmax(f80), -fmin(f80), 1e-1,       -nan(f80),  inf(f80), 1e0,       -1e0,
                inf(f80),   fmin(f80), -fmax(f80), 1e-1,      nan(f80),  0.0,       0.0,       nan(f80),   -1e1, fmax(f80), fmin(f80),  -fmax(f80), 1e0,        1e-1,     0.0,       -fmin(f80),
                -tmin(f80), 0.0,       -1e1,       fmin(f80), 1e0,       1e1,       1e-1,      nan(f80),   -1e1, fmax(f80), 1e-1,       fmin(f80),  -inf(f80),  0.0,      tmin(f80), inf(f80),
                fmax(f80),  1e0,       1e-1,       nan(f80),  inf(f80),  tmin(f80), tmin(f80), -fmax(f80), 0.0,  fmin(f80), -inf(f80),  1e-1,       -tmin(f80), 1e-1,     -1e0,      1e-1,
                -fmax(f80), -1e0,      1e-1,       -1e0,      fmax(f80),
            }, .{
                -1e0,      fmin(f80),  inf(f80),   -nan(f80), -0.0,       fmin(f80),  -0.0, nan(f80),  -fmax(f80), 1e-1,       1e0,        -1e1,       -tmin(f80), -fmin(f80), 1e1,       inf(f80),
                -1e1,      -tmin(f80), -fmin(f80), 1e1,       0.0,        -tmin(f80), 1e1,  -1e1,      1e-1,       1e-1,       tmin(f80),  fmax(f80),  0.0,        1e-1,       1e-1,      -1e1,
                fmin(f80), nan(f80),   -1e1,       -1e1,      -1e1,       0.0,        -0.0, 1e-1,      fmin(f80),  fmin(f80),  -0.0,       -fmin(f80), -nan(f80),  -inf(f80),  0.0,       -inf(f80),
                inf(f80),  fmax(f80),  -tmin(f80), inf(f80),  1e-1,       -nan(f80),  1e-1, tmin(f80), -1e1,       -fmax(f80), -fmax(f80), inf(f80),   -nan(f80),  1e0,        -inf(f80), 1e1,
                nan(f80),  1e1,        -1e1,       0.0,       -fmin(f80),
            });

            try testArgs(@Vector(1, f128), .{
                -nan(f128),
            }, .{
                -0.0,
            });
            try testArgs(@Vector(2, f128), .{
                0.0, -inf(f128),
            }, .{
                1e-1, -fmin(f128),
            });
            try testArgs(@Vector(4, f128), .{
                1e-1, fmax(f128), 1e1, -fmax(f128),
            }, .{
                -tmin(f128), fmax(f128), -0.0, -0.0,
            });
            try testArgs(@Vector(8, f128), .{
                1e1, -fmin(f128), 0.0, -inf(f128), 1e1, -0.0, -1e0, -fmin(f128),
            }, .{
                fmin(f128), tmin(f128), -1e0, -1e1, 0.0, -tmin(f128), 0.0, 1e-1,
            });
            try testArgs(@Vector(16, f128), .{
                -fmin(f128), -1e1, -fmin(f128), 1e-1, -1e1, 1e0, -fmax(f128), tmin(f128), -nan(f128), -tmin(f128), 1e1, -inf(f128), -1e0, tmin(f128), -0.0, nan(f128),
            }, .{
                -fmax(f128), fmin(f128), inf(f128), tmin(f128), -1e1, 1e1, fmax(f128), 1e0, -inf(f128), -inf(f128), -fmax(f128), -nan(f128), 1e0, -inf(f128), tmin(f128), tmin(f128),
            });
            try testArgs(@Vector(32, f128), .{
                -0.0,       -1e0, 1e0,        -fmax(f128), -fmax(f128), 1e-1,        -fmin(f128), -fmin(f128), -1e0,       -tmin(f128), -0.0,       -fmax(f128), tmin(f128), inf(f128), 0.0,  fmax(f128),
                -nan(f128), -0.0, -inf(f128), -1e0,        1e-1,        -fmin(f128), tmin(f128),  -1e1,        fmax(f128), -nan(f128),  -nan(f128), -fmax(f128), 1e-1,       inf(f128), -0.0, tmin(f128),
            }, .{
                -1e0,       -1e1,       -fmin(f128), -fmin(f128), inf(f128),  tmin(f128), nan(f128), 0.0,        -fmin(f128), 1e-1, -nan(f128), 1e-1, -0.0, tmin(f128), 1e0,         0.0,
                fmin(f128), fmax(f128), -fmax(f128), -tmin(f128), fmin(f128), -0.0,       -1e0,      -nan(f128), -inf(f128),  1e0,  nan(f128),  1e0,  1e-1, -0.0,       -fmax(f128), -1e1,
            });
            try testArgs(@Vector(64, f128), .{
                -1e0,       -0.0,       nan(f128),   1e-1,        -1e1,        0.0,         1e0,         1e0,       -inf(f128), fmin(f128),  fmax(f128), nan(f128),  -nan(f128), inf(f128),   -0.0,
                1e-1,       -inf(f128), -fmax(f128), 1e1,         -tmin(f128), -tmin(f128), -fmax(f128), 1e0,       1e-1,       1e-1,        nan(f128),  1e1,        1e0,        -tmin(f128), 1e1,
                -nan(f128), fmax(f128), fmax(f128),  0.0,         fmax(f128),  inf(f128),   1e0,         -0.0,      1e-1,       -tmin(f128), fmin(f128), fmax(f128), tmin(f128), inf(f128),   -1e1,
                -1e0,       -1e0,       -1e0,        -inf(f128),  1e1,         -tmin(f128), nan(f128),   nan(f128), 1e-1,       fmin(f128),  1e-1,       tmin(f128), -1e1,       1e-1,        1e1,
                fmax(f128), fmax(f128), 1e-1,        -fmax(f128),
            }, .{
                -0.0,      1e-1,       -0.0,      -fmin(f128), 1e1,  0.0,        1e0,         -inf(f128), tmin(f128),  -1e0,      fmin(f128),  -nan(f128), -1e1,       1e-1,       -1e1,       1e-1,
                1e-1,      tmin(f128), nan(f128), -1e0,        0.0,  -1e1,       -1e1,        fmax(f128), -fmax(f128), inf(f128), -nan(f128),  1e-1,       -nan(f128), 1e0,        fmax(f128), inf(f128),
                nan(f128), fmin(f128), 1e1,       inf(f128),   0.0,  -inf(f128), 1e-1,        1e-1,       1e-1,        -1e0,      1e-1,        -1e1,       inf(f128),  -nan(f128), 1e-1,       inf(f128),
                inf(f128), inf(f128),  -1e1,      -tmin(f128), 1e-1, -inf(f128), -fmin(f128), 1e0,        -tmin(f128), 1e0,       -tmin(f128), -inf(f128), -0.0,       -nan(f128), -1e0,       -fmax(f128),
            });
            try testArgs(@Vector(128, f128), .{
                -inf(f128),  tmin(f128),  -fmax(f128), 1e0,         fmin(f128),  -fmax(f128), -1e0,        1e-1,        -fmax(f128), -fmin(f128), -1e1,        nan(f128),   1e-1,       nan(f128),
                inf(f128),   -1e0,        tmin(f128),  -inf(f128),  0.0,         fmax(f128),  tmin(f128),  -fmin(f128), fmin(f128),  -1e1,        -fmin(f128), -1e1,        1e0,        -nan(f128),
                -inf(f128),  fmin(f128),  inf(f128),   -tmin(f128), 1e-1,        0.0,         1e1,         1e0,         -tmin(f128), -tmin(f128), tmin(f128),  1e0,         fmin(f128), 1e-1,
                1e-1,        1e-1,        fmax(f128),  1e-1,        inf(f128),   0.0,         fmin(f128),  -fmin(f128), 1e1,         1e1,         -1e1,        tmin(f128),  inf(f128),  inf(f128),
                -fmin(f128), 0.0,         1e-1,        -nan(f128),  1e-1,        -inf(f128),  -nan(f128),  -1e0,        fmin(f128),  -0.0,        1e1,         -tmin(f128), 1e1,        1e0,
                1e-1,        -0.0,        -tmin(f128), 1e-1,        -1e0,        -tmin(f128), -fmin(f128), tmin(f128),  1e-1,        -tmin(f128), -nan(f128),  -1e1,        -inf(f128), 0.0,
                1e-1,        0.0,         -fmin(f128), 0.0,         1e1,         1e1,         tmin(f128),  inf(f128),   -nan(f128),  -inf(f128),  -1e0,        -fmin(f128), -1e1,       -fmin(f128),
                -inf(f128),  -fmax(f128), tmin(f128),  tmin(f128),  -fmin(f128), 1e-1,        fmin(f128),  fmin(f128),  -fmin(f128), nan(f128),   -1e0,        -0.0,        -0.0,       1e-1,
                fmax(f128),  0.0,         -fmax(f128), nan(f128),   nan(f128),   nan(f128),   nan(f128),   -nan(f128),  fmin(f128),  -inf(f128),  inf(f128),   -fmax(f128), -1e1,       fmin(f128),
                1e-1,        fmax(f128),
            }, .{
                0.0,         1e1,         1e-1,        inf(f128),   -0.0,        -1e0,        nan(f128),  -1e1,        -inf(f128),  1e-1,        -tmin(f128), 1e0,         inf(f128),   1e-1,        -1e0,
                1e1,         0.0,         1e0,         nan(f128),   tmin(f128),  fmax(f128),  1e1,        1e-1,        1e-1,        -fmin(f128), -inf(f128),  -nan(f128),  -fmin(f128), -0.0,        -inf(f128),
                -nan(f128),  fmax(f128),  -fmin(f128), -tmin(f128), -fmin(f128), -fmax(f128), nan(f128),  fmin(f128),  -fmax(f128), fmax(f128),  1e0,         1e1,         -fmax(f128), nan(f128),   -fmax(f128),
                -inf(f128),  nan(f128),   -nan(f128),  tmin(f128),  -1e0,        1e-1,        1e-1,       -1e0,        -nan(f128),  fmax(f128),  1e1,         -inf(f128),  1e1,         -0.0,        -1e0,
                -0.0,        -tmin(f128), 1e1,         -1e0,        -fmax(f128), fmin(f128),  fmax(f128), tmin(f128),  1e1,         fmin(f128),  -nan(f128),  1e0,         -tmin(f128), -1e0,        fmax(f128),
                1e0,         -tmin(f128), 1e-1,        -nan(f128),  inf(f128),   1e-1,        1e-1,       fmax(f128),  -fmin(f128), fmin(f128),  -0.0,        fmax(f128),  -fmax(f128), -tmin(f128), tmin(f128),
                nan(f128),   1e-1,        tmin(f128),  -1e0,        fmin(f128),  -nan(f128),  fmax(f128), 1e0,         nan(f128),   -nan(f128),  inf(f128),   -fmin(f128), fmin(f128),  1e-1,        1e1,
                -tmin(f128), -1e1,        0.0,         1e-1,        -fmin(f128), -0.0,        0.0,        -1e1,        fmax(f128),  nan(f128),   nan(f128),   -fmin(f128), -fmax(f128), 1e1,         0.0,
                fmin(f128),  1e1,         -tmin(f128), -tmin(f128), 0.0,         -1e1,        1e0,        -fmin(f128),
            });
            try testArgs(@Vector(69, f128), .{
                -1e0,       nan(f128),  1e-1,       1e-1,       1e-1,       -1e0, -1e1,       inf(f128), -0.0,       inf(f128),  tmin(f128),  0.0,         -fmax(f128), -tmin(f128), -1e1,        -fmax(f128),
                -0.0,       0.0,        nan(f128),  inf(f128),  1e0,        -1e0, 1e-1,       -0.0,      1e0,        fmax(f128), -fmax(f128), 0.0,         inf(f128),   -inf(f128),  -tmin(f128), -inf(f128),
                1e1,        fmin(f128), 1e1,        -1e1,       1e-1,       1e0,  -0.0,       nan(f128), tmin(f128), inf(f128),  inf(f128),   -nan(f128),  -nan(f128),  1e0,         -tmin(f128), 0.0,
                fmin(f128), fmax(f128), fmin(f128), -1e1,       nan(f128),  0.0,  -nan(f128), -0.0,      -nan(f128), 1e-1,       -1e1,        -tmin(f128), fmax(f128),  1e0,         fmin(f128),  fmax(f128),
                nan(f128),  -inf(f128), 1e0,        fmin(f128), -nan(f128),
            }, .{
                -inf(f128), fmax(f128), 0.0,        nan(f128),   -1e1,        tmin(f128),  nan(f128),  1e0,       1e1,         -fmin(f128), fmin(f128),  tmin(f128),  0.0,         -fmin(f128), -0.0,        fmin(f128),
                inf(f128),  inf(f128),  fmin(f128), fmin(f128),  -tmin(f128), -fmax(f128), 1e1,        nan(f128), -0.0,        1e0,         1e1,         -1e1,        -inf(f128),  fmin(f128),  -fmax(f128), 1e-1,
                -1e0,       -nan(f128), -1e1,       tmin(f128),  inf(f128),   nan(f128),   0.0,        -1e1,      tmin(f128),  0.0,         -fmax(f128), -tmin(f128), 1e-1,        1e-1,        1e1,         1e-1,
                fmax(f128), 1e-1,       0.0,        -fmin(f128), -inf(f128),  -inf(f128),  -nan(f128), 1e-1,      -fmax(f128), fmax(f128),  -fmax(f128), -0.0,        -tmin(f128), -1e0,        nan(f128),   1e-1,
                -1e0,       -inf(f128), tmin(f128), inf(f128),   inf(f128),
            });
        }
    };
}

inline fn addUnsafe(comptime Type: type, lhs: Type, rhs: Type) AddOneBit(Type) {
    @setRuntimeSafety(false);
    return @as(AddOneBit(Type), lhs) + rhs;
}
test addUnsafe {
    const test_add_unsafe = binary(addUnsafe, .{});
    try test_add_unsafe.testInts();
    try test_add_unsafe.testIntVectors();
    try test_add_unsafe.testFloats();
    try test_add_unsafe.testFloatVectors();
}

inline fn addSafe(comptime Type: type, lhs: Type, rhs: Type) AddOneBit(Type) {
    @setRuntimeSafety(true);
    return @as(AddOneBit(Type), lhs) + rhs;
}
test addSafe {
    const test_add_safe = binary(addSafe, .{});
    try test_add_safe.testInts();
    try test_add_safe.testFloats();
    try test_add_safe.testFloatVectors();
}

inline fn addWrap(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs +% rhs;
}
test addWrap {
    const test_add_wrap = binary(addWrap, .{});
    try test_add_wrap.testInts();
    try test_add_wrap.testIntVectors();
}

inline fn addSat(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs +| rhs;
}
test addSat {
    const test_add_sat = binary(addSat, .{});
    try test_add_sat.testInts();
    try test_add_sat.testIntVectors();
}

inline fn subUnsafe(comptime Type: type, lhs: Type, rhs: Type) AddOneBit(Type) {
    @setRuntimeSafety(false);
    return switch (@typeInfo(Scalar(Type))) {
        else => @compileError(@typeName(Type)),
        .int => |int| switch (int.signedness) {
            .signed => @as(AddOneBit(Type), lhs) - rhs,
            .unsigned => @as(AddOneBit(Type), @max(lhs, rhs)) - @min(lhs, rhs),
        },
        .float => lhs - rhs,
    };
}
test subUnsafe {
    const test_sub_unsafe = binary(subUnsafe, .{});
    try test_sub_unsafe.testInts();
    try test_sub_unsafe.testIntVectors();
    try test_sub_unsafe.testFloats();
    try test_sub_unsafe.testFloatVectors();
}

inline fn subSafe(comptime Type: type, lhs: Type, rhs: Type) AddOneBit(Type) {
    @setRuntimeSafety(true);
    return switch (@typeInfo(Scalar(Type))) {
        else => @compileError(@typeName(Type)),
        .int => |int| switch (int.signedness) {
            .signed => @as(AddOneBit(Type), lhs) - rhs,
            .unsigned => @as(AddOneBit(Type), @max(lhs, rhs)) - @min(lhs, rhs),
        },
        .float => lhs - rhs,
    };
}
test subSafe {
    const test_sub_safe = binary(subSafe, .{});
    try test_sub_safe.testInts();
    try test_sub_safe.testFloats();
    try test_sub_safe.testFloatVectors();
}

inline fn subWrap(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs -% rhs;
}
test subWrap {
    const test_sub_wrap = binary(subWrap, .{});
    try test_sub_wrap.testInts();
    try test_sub_wrap.testIntVectors();
}

inline fn subSat(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs -| rhs;
}
test subSat {
    const test_sub_sat = binary(subSat, .{});
    try test_sub_sat.testInts();
    try test_sub_sat.testIntVectors();
}

inline fn mulUnsafe(comptime Type: type, lhs: Type, rhs: Type) DoubleBits(Type) {
    @setRuntimeSafety(false);
    return @as(DoubleBits(Type), lhs) * rhs;
}
test mulUnsafe {
    const test_mul_unsafe = binary(mulUnsafe, .{});
    try test_mul_unsafe.testInts();
    try test_mul_unsafe.testIntVectors();
}

inline fn mulSafe(comptime Type: type, lhs: Type, rhs: Type) DoubleBits(Type) {
    @setRuntimeSafety(true);
    return @as(DoubleBits(Type), lhs) * rhs;
}
test mulSafe {
    const test_mul_safe = binary(mulSafe, .{});
    try test_mul_safe.testInts();
}

inline fn mulWrap(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs *% rhs;
}
test mulWrap {
    const test_mul_wrap = binary(mulWrap, .{});
    try test_mul_wrap.testInts();
    try test_mul_wrap.testIntVectors();
}

inline fn mulSat(comptime Type: type, lhs: Type, rhs: Type) Type {
    return lhs *| rhs;
}
test mulSat {
    const test_mul_sat = binary(mulSat, .{});
    try test_mul_sat.testInts();
    try test_mul_sat.testIntVectors();
}

inline fn multiply(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs * rhs) {
    return lhs * rhs;
}
test multiply {
    const test_multiply = binary(multiply, .{});
    try test_multiply.testFloats();
    try test_multiply.testFloatVectors();
}

inline fn divide(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs / rhs) {
    return lhs / rhs;
}
test divide {
    const test_divide = binary(divide, .{ .compare = .approx });
    try test_divide.testFloats();
    try test_divide.testFloatVectors();
}

inline fn divTrunc(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@divTrunc(lhs, rhs)) {
    return @divTrunc(lhs, rhs);
}
test divTrunc {
    const test_div_trunc = binary(divTrunc, .{ .compare = .approx_int });
    try test_div_trunc.testInts();
    try test_div_trunc.testIntVectors();
    try test_div_trunc.testFloats();
    try test_div_trunc.testFloatVectors();
}

inline fn divFloor(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@divFloor(lhs, rhs)) {
    return @divFloor(lhs, rhs);
}
test divFloor {
    const test_div_floor = binary(divFloor, .{ .compare = .approx_int });
    try test_div_floor.testFloats();
    try test_div_floor.testFloatVectors();
}

inline fn rem(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@rem(lhs, rhs)) {
    return @rem(lhs, rhs);
}
test rem {
    const test_rem = binary(rem, .{});
    try test_rem.testInts();
    try test_rem.testIntVectors();
    try test_rem.testFloats();
    try test_rem.testFloatVectors();
}

inline fn mod(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@mod(lhs, rhs)) {
    // workaround llvm backend bugs
    if (@inComptime()) {
        const scalarMod = struct {
            fn scalarMod(scalar_lhs: Scalar(Type), scalar_rhs: Scalar(Type)) Scalar(Type) {
                const scalar_rem = @rem(scalar_lhs, scalar_rhs);
                return if (scalar_rem == 0 or sign(scalar_rem) == sign(scalar_rhs)) scalar_rem else scalar_rem + scalar_rhs;
            }
        }.scalarMod;
        switch (@typeInfo(Type)) {
            else => return scalarMod(lhs, rhs),
            .vector => |info| {
                var res: Type = undefined;
                inline for (0..info.len) |i| res[i] = scalarMod(lhs[i], rhs[i]);
                return res;
            },
        }
    }
    return @mod(lhs, rhs);
}
test mod {
    const test_mod = binary(mod, .{});
    try test_mod.testFloats();
    try test_mod.testFloatVectors();
}

inline fn max(comptime Type: type, lhs: Type, rhs: Type) Type {
    return @max(lhs, rhs);
}
test max {
    const test_max = binary(max, .{});
    try test_max.testInts();
    try test_max.testIntVectors();
    try test_max.testFloats();
    try test_max.testFloatVectors();
}

inline fn min(comptime Type: type, lhs: Type, rhs: Type) Type {
    return @min(lhs, rhs);
}
test min {
    const test_min = binary(min, .{});
    try test_min.testInts();
    try test_min.testIntVectors();
    try test_min.testFloats();
    try test_min.testFloatVectors();
}

inline fn addWithOverflow(comptime Type: type, lhs: Type, rhs: Type) struct { Type, u1 } {
    return @addWithOverflow(lhs, rhs);
}
test addWithOverflow {
    const test_add_with_overflow = binary(addWithOverflow, .{});
    try test_add_with_overflow.testInts();
}

inline fn subWithOverflow(comptime Type: type, lhs: Type, rhs: Type) struct { Type, u1 } {
    return @subWithOverflow(lhs, rhs);
}
test subWithOverflow {
    const test_sub_with_overflow = binary(subWithOverflow, .{});
    try test_sub_with_overflow.testInts();
}

inline fn mulWithOverflow(comptime Type: type, lhs: Type, rhs: Type) struct { Type, u1 } {
    return @mulWithOverflow(lhs, rhs);
}
test mulWithOverflow {
    const test_mul_with_overflow = binary(mulWithOverflow, .{});
    try test_mul_with_overflow.testInts();
}

inline fn shlWithOverflow(comptime Type: type, lhs: Type, rhs: Type) struct { Type, u1 } {
    const bit_cast_rhs: AsSignedness(Type, .unsigned) = @bitCast(rhs);
    const truncate_rhs: Log2Int(Type) = @truncate(bit_cast_rhs);
    return @shlWithOverflow(lhs, if (comptime cast(Log2Int(Scalar(Type)), @bitSizeOf(Scalar(Type)))) |bits| truncate_rhs % splat(Log2Int(Type), bits) else truncate_rhs);
}
test shlWithOverflow {
    const test_shl_with_overflow = binary(shlWithOverflow, .{});
    try test_shl_with_overflow.testInts();
}

inline fn equal(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs == rhs) {
    return lhs == rhs;
}
test equal {
    const test_equal = binary(equal, .{});
    try test_equal.testInts();
    try test_equal.testIntVectors();
    try test_equal.testFloats();
    try test_equal.testFloatVectors();
}

inline fn notEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs != rhs) {
    return lhs != rhs;
}
test notEqual {
    const test_not_equal = binary(notEqual, .{});
    try test_not_equal.testInts();
    try test_not_equal.testIntVectors();
    try test_not_equal.testFloats();
    try test_not_equal.testFloatVectors();
}

inline fn lessThan(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs < rhs) {
    return lhs < rhs;
}
test lessThan {
    const test_less_than = binary(lessThan, .{});
    try test_less_than.testInts();
    try test_less_than.testIntVectors();
    try test_less_than.testFloats();
    try test_less_than.testFloatVectors();
}

inline fn lessThanOrEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs <= rhs) {
    return lhs <= rhs;
}
test lessThanOrEqual {
    const test_less_than_or_equal = binary(lessThanOrEqual, .{});
    try test_less_than_or_equal.testInts();
    try test_less_than_or_equal.testIntVectors();
    try test_less_than_or_equal.testFloats();
    try test_less_than_or_equal.testFloatVectors();
}

inline fn greaterThan(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs > rhs) {
    return lhs > rhs;
}
test greaterThan {
    const test_greater_than = binary(greaterThan, .{});
    try test_greater_than.testInts();
    try test_greater_than.testIntVectors();
    try test_greater_than.testFloats();
    try test_greater_than.testFloatVectors();
}

inline fn greaterThanOrEqual(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs >= rhs) {
    return lhs >= rhs;
}
test greaterThanOrEqual {
    const test_greater_than_or_equal = binary(greaterThanOrEqual, .{});
    try test_greater_than_or_equal.testInts();
    try test_greater_than_or_equal.testIntVectors();
    try test_greater_than_or_equal.testFloats();
    try test_greater_than_or_equal.testFloatVectors();
}

inline fn bitAnd(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs & rhs) {
    return lhs & rhs;
}
test bitAnd {
    const test_bit_and = binary(bitAnd, .{});
    try test_bit_and.testInts();
    try test_bit_and.testIntVectors();
}

inline fn bitOr(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs | rhs) {
    return lhs | rhs;
}
test bitOr {
    const test_bit_or = binary(bitOr, .{});
    try test_bit_or.testInts();
    try test_bit_or.testIntVectors();
}

inline fn shr(comptime Type: type, lhs: Type, rhs: Type) Type {
    const bit_cast_rhs: AsSignedness(Type, .unsigned) = @bitCast(rhs);
    const truncate_rhs: Log2Int(Type) = @truncate(bit_cast_rhs);
    return lhs >> if (comptime cast(Log2Int(Scalar(Type)), @bitSizeOf(Scalar(Type)))) |bits| truncate_rhs % splat(Log2Int(Type), bits) else truncate_rhs;
}
test shr {
    const test_shr = binary(shr, .{});
    try test_shr.testInts();
    try test_shr.testIntVectors();
}

inline fn shrExact(comptime Type: type, lhs: Type, rhs: Type) Type {
    const bit_cast_rhs: AsSignedness(Type, .unsigned) = @bitCast(rhs);
    const truncate_rhs: Log2Int(Type) = @truncate(bit_cast_rhs);
    const final_rhs = if (comptime cast(Log2Int(Scalar(Type)), @bitSizeOf(Scalar(Type)))) |bits| truncate_rhs % splat(Log2Int(Type), bits) else truncate_rhs;
    return @shrExact(lhs >> final_rhs << final_rhs, final_rhs);
}
test shrExact {
    const test_shr_exact = binary(shrExact, .{});
    try test_shr_exact.testInts();
    try test_shr_exact.testIntVectors();
}

inline fn shl(comptime Type: type, lhs: Type, rhs: Type) Type {
    const bit_cast_rhs: AsSignedness(Type, .unsigned) = @bitCast(rhs);
    const truncate_rhs: Log2Int(Type) = @truncate(bit_cast_rhs);
    return lhs << if (comptime cast(Log2Int(Scalar(Type)), @bitSizeOf(Scalar(Type)))) |bits| truncate_rhs % splat(Log2Int(Type), bits) else truncate_rhs;
}
test shl {
    const test_shl = binary(shl, .{});
    try test_shl.testInts();
    try test_shl.testIntVectors();
}

inline fn shlExactUnsafe(comptime Type: type, lhs: Type, rhs: Type) Type {
    @setRuntimeSafety(false);
    const bit_cast_rhs: AsSignedness(Type, .unsigned) = @bitCast(rhs);
    const truncate_rhs: Log2Int(Type) = @truncate(bit_cast_rhs);
    const final_rhs = if (comptime cast(Log2Int(Scalar(Type)), @bitSizeOf(Scalar(Type)))) |bits| truncate_rhs % splat(Log2Int(Type), bits) else truncate_rhs;
    return @shlExact(lhs << final_rhs >> final_rhs, final_rhs);
}
test shlExactUnsafe {
    const test_shl_exact_unsafe = binary(shlExactUnsafe, .{});
    try test_shl_exact_unsafe.testInts();
    try test_shl_exact_unsafe.testIntVectors();
}

inline fn shlSat(comptime Type: type, lhs: Type, rhs: Type) Type {
    // workaround https://github.com/ziglang/zig/issues/23034
    if (@inComptime()) {
        // workaround https://github.com/ziglang/zig/issues/23139
        return lhs <<| @min(@abs(rhs), splat(ChangeScalar(Type, u64), imax(u64)));
    }
    // workaround https://github.com/ziglang/zig/issues/23033
    @setRuntimeSafety(false);
    return lhs <<| @abs(rhs);
}
test shlSat {
    const test_shl_sat = binary(shlSat, .{});
    try test_shl_sat.testInts();
    try test_shl_sat.testIntVectors();
}

inline fn bitXor(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(lhs ^ rhs) {
    return lhs ^ rhs;
}
test bitXor {
    const test_bit_xor = binary(bitXor, .{});
    try test_bit_xor.testInts();
    try test_bit_xor.testIntVectors();
}

inline fn optionalsEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    if (@inComptime()) return lhs == rhs; // workaround https://github.com/ziglang/zig/issues/22636
    return @as(?Type, lhs) == rhs;
}
test optionalsEqual {
    const test_optionals_equal = binary(optionalsEqual, .{});
    try test_optionals_equal.testInts();
    try test_optionals_equal.testFloats();
}

inline fn optionalsNotEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    if (@inComptime()) return lhs != rhs; // workaround https://github.com/ziglang/zig/issues/22636
    return lhs != @as(?Type, rhs);
}
test optionalsNotEqual {
    const test_optionals_not_equal = binary(optionalsNotEqual, .{});
    try test_optionals_not_equal.testInts();
    try test_optionals_not_equal.testFloats();
}

inline fn reduceAndEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.And, lhs == rhs);
}
test reduceAndEqual {
    const test_reduce_and_equal = binary(reduceAndEqual, .{});
    try test_reduce_and_equal.testIntVectors();
    try test_reduce_and_equal.testFloatVectors();
}

inline fn reduceAndNotEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.And, lhs != rhs);
}
test reduceAndNotEqual {
    const test_reduce_and_not_equal = binary(reduceAndNotEqual, .{});
    try test_reduce_and_not_equal.testIntVectors();
    try test_reduce_and_not_equal.testFloatVectors();
}

inline fn reduceOrEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.Or, lhs == rhs);
}
test reduceOrEqual {
    const test_reduce_or_equal = binary(reduceOrEqual, .{});
    try test_reduce_or_equal.testIntVectors();
    try test_reduce_or_equal.testFloatVectors();
}

inline fn reduceOrNotEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.Or, lhs != rhs);
}
test reduceOrNotEqual {
    const test_reduce_or_not_equal = binary(reduceOrNotEqual, .{});
    try test_reduce_or_not_equal.testIntVectors();
    try test_reduce_or_not_equal.testFloatVectors();
}

inline fn reduceXorEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.Xor, lhs == rhs);
}
test reduceXorEqual {
    const test_reduce_xor_equal = binary(reduceXorEqual, .{});
    try test_reduce_xor_equal.testIntVectors();
    try test_reduce_xor_equal.testFloatVectors();
}

inline fn reduceXorNotEqual(comptime Type: type, lhs: Type, rhs: Type) bool {
    return @reduce(.Xor, lhs != rhs);
}
test reduceXorNotEqual {
    const test_reduce_xor_not_equal = binary(reduceXorNotEqual, .{});
    try test_reduce_xor_not_equal.testIntVectors();
    try test_reduce_xor_not_equal.testFloatVectors();
}

inline fn mulAdd(comptime Type: type, lhs: Type, rhs: Type) @TypeOf(@mulAdd(Type, lhs, rhs, rhs)) {
    return @mulAdd(Type, lhs, rhs, rhs);
}
test mulAdd {
    const test_mul_add = binary(mulAdd, .{ .compare = .approx });
    try test_mul_add.testFloats();
    try test_mul_add.testFloatVectors();
}
