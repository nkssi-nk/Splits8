import Foundation

// MARK: - 실제 대회 중간값 (2025/26 시즌 · 완주 시간대별)

/// HYROX 전 세계 기록(2025/26 시즌)의 시간대별 중간값.
/// band = 완주 시간(분), run = 1km 러닝(초),
/// st = 스테이션 8개(초, 대회 순서: 스키 · 푸시 · 풀 · BBJ · 로잉 · 파머스 · 런지 · 월볼),
/// rox = Roxzone 8개 합(초)
enum HyroxBench {
    static let openMen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 60, run: 226, st: [246, 135, 194, 190, 254, 93, 193, 242], rox: 245),  // n=1164
        (band: 65, run: 241, st: [252, 146, 214, 218, 262, 99, 221, 279], rox: 281),  // n=3741
        (band: 70, run: 259, st: [257, 154, 233, 244, 269, 106, 244, 310], rox: 311),  // n=7211
        (band: 75, run: 276, st: [262, 164, 251, 271, 276, 113, 267, 343], rox: 345),  // n=10108
        (band: 80, run: 294, st: [267, 172, 271, 297, 283, 121, 288, 375], rox: 374),  // n=11613
        (band: 85, run: 311, st: [272, 181, 290, 323, 289, 127, 310, 412], rox: 408),  // n=11590
        (band: 90, run: 328, st: [276, 191, 309, 351, 295, 134, 332, 443], rox: 445),  // n=10259
        (band: 95, run: 344, st: [281, 199, 327, 375, 303, 141, 353, 486], rox: 483),  // n=8353
        (band: 100, run: 361, st: [285, 210, 346, 399, 309, 147, 372, 519], rox: 525),  // n=6720
        (band: 105, run: 378, st: [289, 221, 364, 426, 315, 154, 393, 557], rox: 557),  // n=5304
        (band: 110, run: 395, st: [292, 230, 381, 449, 321, 160, 413, 593], rox: 601),  // n=3891
        (band: 115, run: 414, st: [296, 238, 396, 472, 327, 166, 435, 625], rox: 633),  // n=3150
        (band: 120, run: 429, st: [300, 249, 415, 502, 331, 172, 460, 670], rox: 669),  // n=2145
        (band: 125, run: 450, st: [304, 260, 431, 519, 337, 175, 480, 704], rox: 690),  // n=1645
        (band: 130, run: 471, st: [307, 266, 446, 542, 342, 184, 490, 724], rox: 731),  // n=1313
        (band: 135, run: 488, st: [310, 272, 461, 567, 348, 185, 517, 768], rox: 768),  // n=996
        (band: 140, run: 509, st: [312, 294, 477, 582, 350, 190, 541, 805], rox: 777),  // n=709
        (band: 145, run: 527, st: [318, 295, 491, 601, 355, 193, 560, 844], rox: 827),  // n=534
        (band: 150, run: 548, st: [319, 303, 504, 618, 361, 207, 570, 879], rox: 855),  // n=445
    ]

    static let openWomen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 65, run: 244, st: [280, 124, 226, 234, 284, 101, 193, 236], rox: 270),  // n=266
        (band: 70, run: 264, st: [285, 132, 245, 255, 293, 106, 211, 259], rox: 302),  // n=1159
        (band: 75, run: 282, st: [292, 142, 266, 283, 301, 114, 230, 286], rox: 330),  // n=2720
        (band: 80, run: 300, st: [299, 149, 284, 310, 308, 120, 249, 313], rox: 368),  // n=4620
        (band: 85, run: 319, st: [304, 157, 304, 339, 315, 126, 270, 342], rox: 391),  // n=5974
        (band: 90, run: 337, st: [311, 165, 324, 369, 322, 131, 289, 366], rox: 427),  // n=6350
        (band: 95, run: 354, st: [316, 173, 344, 397, 329, 137, 308, 401], rox: 463),  // n=6122
        (band: 100, run: 372, st: [322, 181, 362, 429, 336, 143, 330, 432], rox: 489),  // n=5163
        (band: 105, run: 388, st: [328, 190, 383, 460, 342, 148, 348, 471], rox: 526),  // n=4312
        (band: 110, run: 406, st: [332, 197, 402, 491, 348, 155, 372, 502], rox: 553),  // n=3557
        (band: 115, run: 423, st: [337, 206, 420, 526, 354, 159, 394, 533], rox: 587),  // n=2689
        (band: 120, run: 440, st: [341, 214, 444, 554, 361, 166, 416, 567], rox: 617),  // n=2029
        (band: 125, run: 460, st: [347, 218, 456, 582, 367, 171, 431, 607], rox: 641),  // n=1597
        (band: 130, run: 478, st: [350, 222, 472, 618, 370, 177, 456, 640], rox: 671),  // n=1200
        (band: 135, run: 495, st: [354, 229, 484, 654, 377, 180, 482, 685], rox: 695),  // n=946
        (band: 140, run: 516, st: [359, 234, 508, 674, 382, 186, 499, 710], rox: 720),  // n=737
        (band: 145, run: 532, st: [363, 245, 518, 711, 387, 197, 525, 750], rox: 748),  // n=567
        (band: 150, run: 556, st: [368, 242, 548, 729, 394, 198, 547, 782], rox: 744),  // n=394
    ]

    static let proMen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 55, run: 205, st: [229, 146, 194, 153, 235, 84, 169, 226], rox: 224),  // n=126
        (band: 60, run: 220, st: [236, 167, 223, 171, 246, 93, 195, 260], rox: 249),  // n=764
        (band: 65, run: 234, st: [244, 186, 253, 193, 255, 101, 225, 298], rox: 273),  // n=1621
        (band: 70, run: 250, st: [249, 202, 280, 216, 262, 109, 250, 336], rox: 296),  // n=2244
        (band: 75, run: 265, st: [253, 217, 311, 239, 267, 118, 276, 373], rox: 326),  // n=2523
        (band: 80, run: 280, st: [257, 233, 343, 263, 274, 129, 302, 406], rox: 353),  // n=2387
        (band: 85, run: 295, st: [261, 246, 371, 285, 279, 139, 323, 441], rox: 395),  // n=2072
        (band: 90, run: 311, st: [264, 261, 403, 305, 285, 150, 343, 475], rox: 426),  // n=1617
        (band: 95, run: 324, st: [269, 276, 433, 326, 291, 163, 364, 520], rox: 466),  // n=1269
        (band: 100, run: 340, st: [271, 292, 458, 346, 296, 171, 391, 561], rox: 494),  // n=892
        (band: 105, run: 356, st: [273, 313, 493, 359, 301, 179, 409, 597], rox: 528),  // n=597
        (band: 110, run: 373, st: [279, 318, 512, 378, 308, 185, 432, 638], rox: 566),  // n=472
        (band: 115, run: 388, st: [283, 339, 538, 402, 311, 192, 452, 679], rox: 600),  // n=334
        (band: 120, run: 407, st: [284, 374, 580, 423, 318, 203, 459, 686], rox: 617),  // n=219
        (band: 125, run: 420, st: [287, 371, 577, 453, 322, 212, 484, 762], rox: 672),  // n=183
        (band: 130, run: 443, st: [292, 388, 606, 443, 326, 213, 495, 781], rox: 712),  // n=119
    ]

    static let proWomen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 65, run: 238, st: [267, 173, 238, 212, 275, 108, 208, 248], rox: 267),  // n=354
        (band: 70, run: 254, st: [275, 191, 266, 231, 284, 118, 231, 277], rox: 295),  // n=779
        (band: 75, run: 271, st: [282, 207, 291, 254, 292, 129, 255, 308], rox: 314),  // n=1077
        (band: 80, run: 287, st: [287, 224, 317, 279, 299, 141, 279, 338], rox: 340),  // n=1123
        (band: 85, run: 303, st: [291, 238, 341, 304, 304, 151, 304, 368], rox: 375),  // n=1114
        (band: 90, run: 319, st: [297, 249, 364, 331, 311, 164, 325, 398], rox: 409),  // n=973
        (band: 95, run: 336, st: [302, 266, 388, 348, 317, 173, 344, 435], rox: 439),  // n=763
        (band: 100, run: 351, st: [308, 284, 414, 376, 322, 189, 371, 462], rox: 466),  // n=624
        (band: 105, run: 367, st: [310, 294, 447, 392, 329, 198, 388, 505], rox: 501),  // n=427
        (band: 110, run: 386, st: [313, 312, 460, 426, 335, 209, 405, 537], rox: 515),  // n=356
        (band: 115, run: 399, st: [318, 319, 473, 451, 342, 213, 438, 582], rox: 572),  // n=251
        (band: 120, run: 416, st: [322, 341, 508, 447, 345, 222, 448, 624], rox: 615),  // n=176
        (band: 125, run: 428, st: [330, 368, 534, 489, 354, 227, 481, 658], rox: 635),  // n=134
        (band: 130, run: 453, st: [328, 378, 529, 514, 359, 246, 504, 651], rox: 667),  // n=102
    ]

    static let doublesMen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 55, run: 224, st: [219, 92, 149, 132, 238, 81, 150, 215], rox: 232),  // n=743
        (band: 60, run: 245, st: [227, 99, 164, 148, 248, 86, 168, 227], rox: 273),  // n=3580
        (band: 65, run: 269, st: [233, 103, 177, 162, 256, 90, 185, 239], rox: 303),  // n=6898
        (band: 70, run: 293, st: [239, 107, 188, 175, 262, 94, 199, 251], rox: 341),  // n=9587
        (band: 75, run: 317, st: [244, 110, 199, 190, 269, 99, 213, 263], rox: 377),  // n=9515
        (band: 80, run: 339, st: [249, 115, 211, 204, 277, 103, 228, 276], rox: 425),  // n=7960
        (band: 85, run: 362, st: [253, 120, 223, 219, 284, 108, 243, 291], rox: 463),  // n=5804
        (band: 90, run: 385, st: [257, 126, 235, 231, 290, 112, 255, 305], rox: 509),  // n=3981
        (band: 95, run: 407, st: [263, 132, 246, 244, 297, 116, 269, 320], rox: 557),  // n=2603
        (band: 100, run: 431, st: [266, 137, 257, 258, 303, 119, 281, 339], rox: 592),  // n=1696
        (band: 105, run: 456, st: [269, 142, 259, 264, 309, 121, 293, 351], rox: 644),  // n=1083
        (band: 110, run: 480, st: [274, 148, 275, 277, 313, 122, 305, 366], rox: 680),  // n=732
        (band: 115, run: 505, st: [277, 152, 282, 287, 317, 125, 318, 391], rox: 711),  // n=491
        (band: 120, run: 539, st: [277, 154, 278, 281, 321, 128, 325, 381], rox: 743),  // n=267
        (band: 125, run: 559, st: [287, 158, 293, 302, 329, 131, 342, 409], rox: 777),  // n=191
        (band: 130, run: 580, st: [290, 167, 306, 316, 335, 134, 351, 450], rox: 811),  // n=137
    ]

    static let doublesWomen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 65, run: 266, st: [259, 94, 195, 175, 279, 90, 165, 217], rox: 298),  // n=806
        (band: 70, run: 292, st: [267, 97, 206, 193, 286, 95, 177, 224], rox: 319),  // n=2976
        (band: 75, run: 315, st: [274, 101, 219, 210, 294, 100, 191, 234], rox: 357),  // n=6059
        (band: 80, run: 339, st: [280, 104, 232, 227, 301, 104, 205, 245], rox: 390),  // n=8892
        (band: 85, run: 362, st: [286, 109, 244, 246, 307, 110, 219, 256], rox: 427),  // n=9739
        (band: 90, run: 383, st: [292, 114, 259, 265, 316, 114, 233, 270], rox: 473),  // n=8841
        (band: 95, run: 407, st: [297, 119, 273, 283, 321, 118, 247, 283], rox: 503),  // n=6723
        (band: 100, run: 428, st: [302, 123, 284, 306, 328, 122, 261, 299], rox: 551),  // n=4998
        (band: 105, run: 452, st: [307, 128, 296, 324, 335, 125, 275, 314], rox: 580),  // n=3457
        (band: 110, run: 476, st: [311, 132, 307, 344, 341, 128, 287, 331], rox: 611),  // n=2434
        (band: 115, run: 500, st: [316, 134, 320, 364, 347, 130, 302, 345], rox: 642),  // n=1589
        (band: 120, run: 522, st: [322, 138, 332, 394, 353, 133, 316, 366], rox: 670),  // n=1062
        (band: 125, run: 548, st: [326, 141, 341, 410, 358, 134, 328, 385], rox: 693),  // n=717
        (band: 130, run: 573, st: [330, 145, 346, 424, 363, 138, 339, 406], rox: 725),  // n=452
        (band: 135, run: 597, st: [330, 147, 363, 448, 366, 140, 359, 428], rox: 743),  // n=316
        (band: 140, run: 623, st: [331, 144, 361, 489, 368, 141, 371, 440], rox: 771),  // n=203
        (band: 145, run: 648, st: [339, 150, 374, 486, 371, 145, 386, 466], rox: 799),  // n=132
    ]

    static let doublesMixed: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 55, run: 223, st: [225, 95, 154, 133, 242, 82, 147, 207], rox: 231),  // n=266
        (band: 60, run: 244, st: [234, 107, 174, 147, 253, 89, 165, 216], rox: 263),  // n=1600
        (band: 65, run: 267, st: [240, 112, 190, 162, 261, 94, 185, 227], rox: 293),  // n=3541
        (band: 70, run: 290, st: [247, 118, 205, 176, 269, 98, 201, 239], rox: 327),  // n=6650
        (band: 75, run: 313, st: [253, 124, 219, 192, 276, 103, 218, 252], rox: 359),  // n=9143
        (band: 80, run: 335, st: [258, 130, 233, 207, 283, 107, 235, 267], rox: 400),  // n=10134
        (band: 85, run: 357, st: [264, 136, 248, 222, 290, 112, 251, 285], rox: 436),  // n=9243
        (band: 90, run: 379, st: [269, 142, 261, 238, 297, 116, 267, 303], rox: 475),  // n=7353
        (band: 95, run: 400, st: [273, 149, 275, 254, 304, 120, 283, 326], rox: 516),  // n=5109
        (band: 100, run: 422, st: [278, 155, 286, 272, 311, 123, 300, 345], rox: 554),  // n=3612
        (band: 105, run: 444, st: [282, 162, 300, 286, 317, 127, 317, 363], rox: 594),  // n=2456
        (band: 110, run: 467, st: [286, 169, 310, 302, 324, 130, 328, 387], rox: 628),  // n=1740
        (band: 115, run: 492, st: [290, 175, 319, 316, 327, 133, 342, 414], rox: 648),  // n=1195
        (band: 120, run: 516, st: [296, 180, 330, 327, 333, 136, 356, 430], rox: 684),  // n=760
        (band: 125, run: 536, st: [299, 189, 343, 339, 339, 137, 376, 464], rox: 726),  // n=498
        (band: 130, run: 562, st: [303, 198, 354, 345, 341, 142, 395, 469], rox: 757),  // n=363
        (band: 135, run: 576, st: [305, 203, 370, 382, 349, 141, 421, 561], rox: 760),  // n=213
        (band: 140, run: 608, st: [307, 203, 376, 373, 349, 146, 419, 571], rox: 792),  // n=155
        (band: 145, run: 631, st: [315, 197, 386, 399, 356, 147, 437, 585], rox: 830),  // n=121
    ]

    static let proDoublesMen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 50, run: 199, st: [203, 98, 157, 110, 217, 77, 138, 206], rox: 202),  // n=104
        (band: 55, run: 218, st: [213, 110, 185, 123, 232, 85, 156, 216], rox: 236),  // n=787
        (band: 60, run: 239, st: [221, 120, 209, 138, 242, 91, 179, 228], rox: 260),  // n=2027
        (band: 65, run: 260, st: [227, 130, 230, 152, 249, 96, 201, 241], rox: 294),  // n=2499
        (band: 70, run: 283, st: [232, 137, 250, 165, 256, 100, 217, 254], rox: 325),  // n=2535
        (band: 75, run: 305, st: [237, 143, 270, 177, 262, 104, 235, 268], rox: 364),  // n=1936
        (band: 80, run: 327, st: [242, 152, 292, 189, 270, 108, 250, 288], rox: 393),  // n=1342
        (band: 85, run: 345, st: [246, 162, 307, 203, 277, 113, 270, 317], rox: 445),  // n=808
        (band: 90, run: 368, st: [250, 173, 330, 212, 282, 116, 281, 334], rox: 478),  // n=508
        (band: 95, run: 388, st: [250, 177, 341, 224, 289, 120, 300, 367], rox: 528),  // n=311
        (band: 100, run: 417, st: [255, 180, 367, 227, 292, 122, 311, 366], rox: 544),  // n=163
        (band: 105, run: 435, st: [264, 193, 370, 237, 301, 127, 334, 418], rox: 576),  // n=127
    ]

    static let proDoublesWomen: [(band: Int, run: Int, st: [Int], rox: Int)] = [
        (band: 60, run: 236, st: [244, 121, 198, 158, 263, 94, 171, 208], rox: 255),  // n=204
        (band: 65, run: 259, st: [251, 129, 217, 170, 272, 100, 189, 217], rox: 283),  // n=660
        (band: 70, run: 283, st: [259, 137, 235, 181, 280, 106, 205, 227], rox: 306),  // n=1074
        (band: 75, run: 305, st: [265, 143, 251, 197, 285, 111, 223, 239], rox: 346),  // n=1308
        (band: 80, run: 328, st: [270, 151, 269, 211, 293, 115, 240, 252], rox: 375),  // n=1242
        (band: 85, run: 349, st: [275, 158, 285, 227, 299, 120, 260, 268], rox: 416),  // n=982
        (band: 90, run: 369, st: [281, 164, 300, 246, 307, 124, 277, 284], rox: 465),  // n=708
        (band: 95, run: 390, st: [287, 175, 316, 260, 313, 129, 291, 304], rox: 505),  // n=535
        (band: 100, run: 411, st: [290, 181, 335, 282, 318, 134, 314, 333], rox: 525),  // n=327
        (band: 105, run: 432, st: [298, 185, 352, 300, 327, 137, 332, 357], rox: 556),  // n=201
        (band: 110, run: 451, st: [301, 197, 364, 316, 332, 139, 344, 382], rox: 617),  // n=157
        (band: 115, run: 470, st: [305, 193, 393, 323, 338, 143, 357, 412], rox: 676),  // n=109
    ]

    // max scale adj 4.21 %
    // non-monotonic [('openWomen', 150, 1, 245, 242), ('proMen', 125, 1, 374, 371), ('proMen', 125, 2, 580, 577), ('proMen', 130, 3, 453, 443), ('proWomen', 120, 3, 451, 447), ('proWomen', 130, 0, 330, 328), ('proWomen', 130, 2, 534, 529), ('proWomen', 130, 7, 658, 651), ('doublesMen', 120, 2, 282, 278), ('doublesMen', 120, 3, 287, 281), ('doublesMen', 120, 7, 391, 381), ('doublesWomen', 140, 1, 147, 144), ('doublesWomen', 140, 2, 363, 361), ('doublesWomen', 145, 3, 489, 486), ('doublesMixed', 135, 5, 142, 141), ('doublesMixed', 140, 3, 382, 373), ('doublesMixed', 140, 6, 421, 419), ('doublesMixed', 145, 1, 203, 197), ('proDoublesMen', 100, 7, 367, 366), ('proDoublesWomen', 115, 1, 197, 193)]

    /// 디비전 키("openM") 또는 이름("Open Men") → 표. 모르는 값은 Open Men
    static func table(for divisionKey: String) -> [(band: Int, run: Int, st: [Int], rox: Int)] {
        switch Division.of(divisionKey).key {
        case "openW": return openWomen
        case "proM": return proMen
        case "proW": return proWomen
        case "dblM": return doublesMen
        case "dblW": return doublesWomen
        case "dblX": return doublesMixed
        case "dblMP": return proDoublesMen
        case "dblWP": return proDoublesWomen
        default: return openMen
        }
    }

    /// 완주 시간(초)에 맞는 줄: 두 시간대 사이는 비례로 섞고, 범위 밖이면 끝 줄을 시간 비율로 늘리거나 줄임
    private static func row(for divisionKey: String, finish totalSec: Int) -> (run: Double, st: [Double], rox: Double) {
        let t = table(for: divisionKey)
        guard let first = t.first, let last = t.last else {
            return (270, Defaults.stationGoals.map(Double.init), Double(8 * Defaults.roxTarget))
        }
        let m: Double = Double(totalSec) / 60
        func scaled(_ r: (band: Int, run: Int, st: [Int], rox: Int), by f: Double) -> (run: Double, st: [Double], rox: Double) {
            (Double(r.run) * f, r.st.map { Double($0) * f }, Double(r.rox) * f)
        }
        if m <= Double(first.band) { return scaled(first, by: m / Double(first.band)) }
        if m >= Double(last.band) { return scaled(last, by: m / Double(last.band)) }
        for i in 0..<(t.count - 1) {
            let a = t[i], b = t[i + 1]
            guard m >= Double(a.band), m <= Double(b.band) else { continue }
            let f: Double = (m - Double(a.band)) / Double(max(1, b.band - a.band))
            let run: Double = Double(a.run) + (Double(b.run) - Double(a.run)) * f
            let st: [Double] = (0..<8).map { Double(a.st[$0]) + (Double(b.st[$0]) - Double(a.st[$0])) * f }
            let rox: Double = Double(a.rox) + (Double(b.rox) - Double(a.rox)) * f
            return (run, st, rox)
        }
        return scaled(last, by: 1)
    }

    /// 같은 완주 시간대 중간값 그대로 (비교용): run = 1km 러닝(초), st = 스테이션 8개(초)
    static func bench(for divisionKey: String, finish totalSec: Int) -> (run: Int, st: [Int]) {
        let r = row(for: divisionKey, finish: totalSec)
        return (Int(r.run.rounded()), r.st.map { Int($0.rounded()) })
    }

    /// 같은 완주 시간대 Roxzone 8개 합(초) 중간값
    static func roxTotal(for divisionKey: String, finish totalSec: Int) -> Int {
        Int(row(for: divisionKey, finish: totalSec).rox.rounded())
    }

    /// 같은 완주 시간대 Roxzone 1번 목표(초): 실제 중간값 ÷ 8, 5초 단위, 20초~2분 사이
    static func roxEach(goal totalSec: Int, division: String) -> Int {
        let each: Double = row(for: division, finish: totalSec).rox / 8
        return min(120, max(20, Int((each / 5).rounded()) * 5))
    }

    /// 목표 시간(Roxzone 포함)을 16칸 [Run1, St1, Run2, St2, …] 로 나눔.
    /// 중간값의 비율은 그대로 두고, 16칸 합이 (목표 − 8 × 이동 목표) 가 되게 전체를 한 번만 늘리거나 줄임
    static func splits16(goal totalSec: Int, division: String, rox: Int = Defaults.roxTarget) -> [Int] {
        let r = row(for: division, finish: totalSec)
        var raw: [Double] = []
        for i in 0..<8 {
            raw.append(r.run)
            raw.append(r.st[i])
        }
        let want: Double = Double(max(16 * 30, totalSec - 8 * rox))
        let sum: Double = max(1, raw.reduce(0, +))
        return raw.map { Int(($0 * want / sum).rounded()) }
    }
}
