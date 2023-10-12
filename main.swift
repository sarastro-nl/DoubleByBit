import Foundation

struct DoubleByBit: Equatable {
    static let zero = DoubleByBit(e: 0, m: 0)
    static let one = DoubleByBit(e: 1023, m: 0)
    static let two = DoubleByBit(e: 1024, m: 0)

    var bytes: UInt64 = 0

    init(_ d: Double) { bytes = d.bitPattern }
    init(_ s: String) { bytes = s.convertToUInt64() }

    private init(e: UInt64, m: UInt64, n: Bool = false) { bytes = e << 52 | m | (n ? 1 << 63 : 0) }
    
    var exponent: UInt64 { bytes >> 52 & (1 << 11 - 1) }
    var mantisse: UInt64 { bytes & (1 << 52 - 1) }
    var isNegative: Bool { bytes & 1 << 63 > 0 }
    
    var doubleValue: Double { Double(bitPattern: bytes) }
    
    var bitPatternString: String {
        var s = ""
        for i in (0...63).reversed() {
            s += ( bytes & 1 << i > 0 ) ? "1" : "0"
            if i % 8 == 0 { s += " " }
        }
        return s
    }

    static prefix func - (operand: DoubleByBit) -> DoubleByBit {
        if operand == .zero { return operand }
        var operand = operand
        operand.bytes ^= 1 << 63
        return operand
    }
    
    static func < (lhs: DoubleByBit, rhs: DoubleByBit) -> Bool {
        if lhs.isNegative && !rhs.isNegative { return true }
        if !lhs.isNegative && rhs.isNegative { return false }
        if lhs.isNegative { return -lhs > -rhs }
        if lhs.exponent < rhs.exponent { return true }
        if lhs.exponent > rhs.exponent { return false }
        return lhs.mantisse < rhs.mantisse
    }

    static func > (lhs: DoubleByBit, rhs: DoubleByBit) -> Bool {
        if lhs == rhs { return false }
        return !(lhs < rhs)
    }

    static func + (lhs: DoubleByBit, rhs: DoubleByBit) -> DoubleByBit {
        if lhs == .zero { return rhs }
        if rhs == .zero { return lhs }
        if lhs == -rhs { return .zero }
        if abs(lhs) < abs(rhs) { return rhs + lhs }
        if lhs.exponent - rhs.exponent > 52 { return lhs }
        if lhs.isNegative { return -(-lhs + -rhs) }
        let lmantisse = 1 << 52 + lhs.mantisse
        let rmantisse = (1 << 52 + rhs.mantisse) >> (lhs.exponent - rhs.exponent)
        var exponent = lhs.exponent
        var mantisse = rhs.isNegative ? lmantisse - rmantisse : lmantisse + rmantisse
        if mantisse & 1 << 53 > 0 {
            exponent += 1
            mantisse >>= 1
        }
        while mantisse & 1 << 52 == 0 {
            exponent -= 1
            mantisse <<= 1
        }
        mantisse -= 1 << 52
        return DoubleByBit(e: exponent, m: mantisse)
    }

    static func - (lhs: DoubleByBit, rhs: DoubleByBit) -> DoubleByBit { lhs + -rhs }

    static func * (lhs: DoubleByBit, rhs: DoubleByBit) -> DoubleByBit {
        if lhs == .zero || rhs == .zero { return .zero }
        if lhs == .one { return rhs }
        if rhs == .one { return lhs }
        var r1: UInt64 = 0, r2: UInt64 = 0
        var l1: UInt64 = 0, l2: UInt64 = 1 << 52 + lhs.mantisse
        let rmantisse = 1 << 52 + rhs.mantisse
        for i in (0...52) {
            if rmantisse & 1 << i > 0 {
                r1 += l1
                let r = r2.addingReportingOverflow(l2)
                if r.overflow { r1 += 1 }
                r2 = r.partialValue
            }
            l1 <<= 1
            if l2 & 1 << 63 > 0 { l1 += 1 }
            l2 <<= 1
        }
        var exponent = lhs.exponent + rhs.exponent - 1023
        var mantisse = r1 << 12 + r2 >> 52
        if mantisse & 1 << 53 > 0 {
            exponent += 1
            mantisse >>= 1
        }
        mantisse -= 1 << 52
        return DoubleByBit(e: exponent, m: mantisse, n: lhs.isNegative != rhs.isNegative)
    }
    
    static func / (lhs: DoubleByBit, rhs: DoubleByBit) -> DoubleByBit {
        if rhs == .zero { fatalError() }
        if lhs == .zero { return .zero }
        if rhs == .one { return lhs }
        if lhs == rhs { return .one }
        var numerator = DoubleByBit(e: 1022, m: lhs.mantisse)
        let denominator = DoubleByBit(e: 1022, m: rhs.mantisse)
        var error = .one - denominator
        while .one + error > .one {
            numerator = numerator * (.one + error)
            error = error * error
        }
        return DoubleByBit(e: numerator.exponent + lhs.exponent - rhs.exponent, m: numerator.mantisse, n: lhs.isNegative != rhs.isNegative)
    }
    
    static func abs(_ operand: DoubleByBit) -> DoubleByBit {
        if operand.isNegative { return -operand }
        return operand
    }
    
    static func sqrt(_ operand: DoubleByBit) -> DoubleByBit {
        if operand.isNegative { fatalError() }
        if operand == .zero { return .zero }
        if operand == .one { return .one }
        let o: DoubleByBit
        var x: DoubleByBit
        if operand.exponent & 1 == 0 {
            o = DoubleByBit(e: 1024, m: operand.mantisse)
            x = DoubleByBit(e: 1023, m: (1 << 52 + o.mantisse) >> 1)
        } else {
            o = DoubleByBit(e: 1023, m: operand.mantisse)
            x = DoubleByBit(e: 1023, m: o.mantisse >> 1)
        }
        let threshold = DoubleByBit(e: 1023 - 48, m: 0)
        while abs(o - (x * x)) > threshold {
            x = x + o / x
            x = DoubleByBit(e: x.exponent - 1, m: x.mantisse)
        }
        return DoubleByBit(e: (operand.exponent + 1) >> 1 + 1023 - 512, m: x.mantisse)
    }
    
    static func cos(_ operand: DoubleByBit) -> DoubleByBit {
        if operand == .zero { return .one }
        return _sin(DoubleByBit(e: 1021, m: 0) - normalize(abs(operand)))
    }
    
    static func sin(_ operand: DoubleByBit) -> DoubleByBit {
        if operand == .zero { return .zero }
        return _sin(normalize(operand))
    }
    
    static func tan(_ operand: DoubleByBit) -> DoubleByBit { sin(operand) / cos(operand) }
    
    static private func normalize(_ operand: DoubleByBit) -> DoubleByBit {
        let operand = operand * DoubleByBit(e: 1020, m: 1230561511852163) // 1/(2*pi)
        if operand.exponent < 1023 { return operand }
        var exponent = operand.exponent
        var mantisse = operand.mantisse & (1 << (52 - (operand.exponent - 1023)) - 1)
        while mantisse & 1 << 52 == 0 {
            exponent -= 1
            mantisse <<= 1
        }
        mantisse -= 1 << 52
        return DoubleByBit(e: exponent, m: mantisse, n: operand.isNegative)
    }
    
    static private func _sin(_ operand: DoubleByBit) -> DoubleByBit {
        if operand.isNegative { return -_sin(-operand) }
        if operand > DoubleByBit(e: 1022, m: 0) { return -_sin(DoubleByBit(e: 1023, m: 0) - operand) }
        if operand > DoubleByBit(e: 1021, m: 0) { return  _sin(DoubleByBit(e: 1022, m: 0) - operand) }
        var operand = operand * DoubleByBit(e: 1025, m: 2570638124657944) // 2*pi
        let square = -operand * operand
        var r = DoubleByBit.zero
        var fac = DoubleByBit.two
        while r + operand != r {
            r = r + operand
            operand = operand * square / (fac * (fac + .one))
            fac = fac + .two
        }
        return r
    }
    
    static func log(_ operand: DoubleByBit) -> DoubleByBit {
        if operand.isNegative { fatalError() }
        if operand == .zero { fatalError() }
        if operand == .one { return .zero }
        var operand = operand
        var m: UInt64 = 1
        while operand < DoubleByBit(e: 1022, m: 0) || operand > .two {
            operand = sqrt(operand)
            m += 1
        }
        operand = (operand - .one) / (operand + .one)
        let square = operand * operand
        var r = DoubleByBit.zero
        var e = operand
        var n = DoubleByBit.one
        while r + e != r {
            r = r + e
            operand = operand * square
            n = n + .two
            e = operand / n
        }
        return DoubleByBit(e: r.exponent + m, m: r.mantisse, n: r.isNegative)
    }
    
    static func exp(_ operand: DoubleByBit) -> DoubleByBit {
        if operand == .zero { return .one }
        let o: DoubleByBit
        if operand.exponent > 1022 {
            o = DoubleByBit(e: 1022, m: operand.mantisse)
        } else {
            o = DoubleByBit(e: operand.exponent, m: operand.mantisse)
        }
        var r = DoubleByBit.one
        var e = o
        var fac = DoubleByBit.two
        while r + e != r {
            r = r + e
            e = e * o / fac
            fac = fac + .one
        }
        var exponent = operand.exponent
        while exponent > 1022 {
            r = r * r
            exponent -= 1
        }
        if operand.isNegative {
            r = .one / r
        }
        return r
    }
    
    static func pow(_ lhs: DoubleByBit, _ rhs: DoubleByBit) -> DoubleByBit { exp(log(lhs) * rhs) }
    
    static func atan(_ operand: DoubleByBit) -> DoubleByBit {
        if operand == .zero { return .zero }
        if operand.isNegative { return -atan(-operand) }
        let quarter = DoubleByBit(e: 1021, m: 0)   // .0.25
        var m = DoubleByBit.zero
        var operand = operand
        while operand > quarter {
            operand = (operand - quarter) / (.one + (operand * quarter))
            m = m + .one
        }
        let square = -operand * operand
        var r = DoubleByBit.zero
        var e = operand
        var n = DoubleByBit.one
        while r + e != r {
            r = r + e
            operand = operand * square
            n = n + .two
            e = operand / n
        }
        return r + m * DoubleByBit(e: 1020, m: 4322686900404445) // atan(0.25)
    }
}

private extension String {
    struct Data {
        var dp: Int
        var nrDigits: Int
        var digits: [UInt8]
        let isNegative: Bool
    }

    func convertToUInt64() -> UInt64 {
        let powers: [UInt64] = [
            0,  3,  6,  9,  13, 16, 19, 23, 26, 29,
            33, 36, 39, 43, 46, 49, 53, 56, 59,
        ]
        var data = parse()
        guard data.nrDigits > 0 else { return 0 }
        var shift: UInt64 = 0
        var exp: UInt64 = 1023
        while data.dp > 1 {
            shift = data.dp < 19 ? powers[data.dp] : 60
            rightShift(data: &data, shift: shift)
            exp += shift
        }
        while data.dp < 0 {
            shift = -data.dp < 19 ? powers[-data.dp] + 1 : 60
            leftShift(data: &data, shift: shift)
            exp -= shift
        }
        shift = 52
        let n = data.digits[..<3].reduce(0, { ($0 * 10) + UInt($1) })
        var m: Int64
        if data.dp == 0 {  // between 0.1 and 1.0
            switch n {
                case 100..<125: m = -4
                case 125..<250: m = -3
                case 250..<500: m = -2
                default: m = -1
            }
        } else {           // between 1.0 and 10.0
            switch n {
                case 100..<200: m = 0
                case 200..<400: m = 1
                case 400..<800: m = 2
                default: m = 3
            }
        }
        exp = m < 0 ? exp - UInt64(-m) : exp + UInt64(m)
        shift = m < 0 ? shift + UInt64(-m) : shift - UInt64(m)
        leftShift(data: &data, shift: shift)
        let mantisse = data.digits[..<16].reduce(0, { ($0 * 10) + UInt64($1) }) - 1 << 52
        return (data.isNegative ? 1 << 63 : 0) | exp << 52 | mantisse
    }
    
    func leftShift(data: inout Data, shift: UInt64) {
        let extraDigitsTable = [
            0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4,
            4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 7, 8, 8,
            8, 9, 9, 9, 10, 10, 10, 10, 11, 11, 11,
            12, 12, 12, 13, 13, 13, 13, 14, 14, 14,
            15, 15, 15, 16, 16, 16, 16, 17, 17, 17,
            18, 18, 18, 19]
        var extraDigits = extraDigitsTable[Int(shift)]
        var n: UInt64 = 0
        var ir = data.nrDigits - 1
        var iw = data.nrDigits - 1 + extraDigits
        repeat {
            n += UInt64(data.digits[ir]) << shift; ir -= 1
            data.digits[iw] = UInt8(n % 10); iw -= 1
            n /= 10
        } while ir >= 0
        while n > 0 {
            data.digits[iw] = UInt8(n % 10); iw -= 1
            n /= 10
        }
        if iw == 0 {
            data.digits.removeFirst()
            data.digits.append(0)
            extraDigits -= 1
        }
        data.nrDigits += extraDigits
        data.dp += extraDigits
        while data.digits[data.nrDigits - 1] == 0 {
            data.nrDigits -= 1
        }
    }
    
    func rightShift(data: inout Data, shift: UInt64) {
        var n: UInt64 = 0
        var ir = 0
        var iw = 0
        repeat {
            n = (n * 10) + (ir < data.nrDigits ? UInt64(data.digits[ir]) : 0); ir += 1
        } while n >> shift == 0
        data.dp -= ir - 1
        repeat {
            data.digits[iw] = UInt8(n >> shift); iw += 1
            n = (n & (1 << shift - 1)) * 10 + (ir < data.nrDigits ? UInt64(data.digits[ir]) : 0); ir += 1
        } while n > 0
        data.nrDigits = iw
    }
    
    func parse() -> Data {
        let pattern = #"^(?<sign>-|\+)?0*(?<integer>\d*)(\.(?<fraction>\d+?))?0*(e(?<exponent>(-|\+)?\d+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { fatalError("Parse error: \(self)") }
        guard let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) else { fatalError("Parse error: \(self)") }
        var dp = 0
        var iw = 0
        var digits: [UInt8] = Array(repeating: 0, count: 1000)
        var isNegative = false
        let string = self as NSString
        let signRange = match.range(withName: "sign")
        if signRange.length > 0, string.substring(with: signRange) == "-" {
            isNegative = true
        }
        let integerRange = match.range(withName: "integer")
        if integerRange.length > 0 {
            let s = string.substring(with: integerRange)
            dp = integerRange.length
            for c in s {
                if let ui = UInt8(String(c)) {
                    digits[iw] = ui; iw += 1
                }
            }
        }
        let fractionRange = match.range(withName: "fraction")
        if fractionRange.length > 0 {
            var s = string.substring(with: fractionRange)
            var index = 0
            if iw == 0 {
                for c in s {
                    if c == "0" {
                        index += 1
                    } else {
                        break
                    }
                }
                if fractionRange.length > index {
                    dp -= index
                }
            }
            let newRange = NSRange(location: fractionRange.location + index, length: fractionRange.length - index)
            s = string.substring(with: newRange)
            for c in s {
                if let ui = UInt8(String(c)) {
                    digits[iw] = ui; iw += 1
                }
            }
        }
        while iw > 0 && digits[iw - 1] == 0 {
            iw -= 1
        }
        let exponentRange = match.range(withName: "exponent")
        if exponentRange.length > 0 {
            let s = string.substring(with: exponentRange)
            if let i = Int(s) {
                dp += i
            }
        }
        return Data(dp: dp, nrDigits: iw, digits: digits, isNegative: isNegative)
    }
}

let ff = 1.234
let gg = -1.99
let ss = atan(ff)

let f = DoubleByBit(String(ff))
let g = DoubleByBit(gg)
let h = DoubleByBit(ss)
let s = DoubleByBit.atan(f)
print(ff)
print(gg)
print(ss)
print(s.doubleValue)
print(f.bitPatternString)
print(g.bitPatternString)
print(h.bitPatternString)
print(s.bitPatternString)
