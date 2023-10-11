import Foundation

struct DoubleByBit: Equatable {
    static let zero = DoubleByBit(0)
    static let one = DoubleByBit(e: 1023, m: 0)
    static let two = DoubleByBit(e: 1024, m: 0)

    var bytes: UInt64 = 0

    init(_ d: Double) { bytes = d.bitPattern }
    
    private init(e: UInt64, m: UInt64, n: Bool = false) {
        guard e > 0, e < 2048, m < 1 << 52 else { fatalError("out of bounds") }
        bytes = e << 52
        bytes += m
        if n { bytes |= 1 << 63}
    }
    
    var exponent: UInt64 { bytes >> 52 & (1 << 11 - 1) }
    var mantisse: UInt64 { bytes & (1 << 52 - 1) }
    var isNegative: Bool { bytes & 1 << 63 > 0 }
    
    var doubleValue: Double {
        if self == .zero { return 0 }
        let r = Darwin.pow(2, Double(Int(exponent) - 1023)) * (Double(mantisse) * Darwin.pow(2, -52) + 1)
        return isNegative ? -r : r
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
    
    func bitPattern() {
        for i in (0...63).reversed() {
            if bytes & 1 << i > 0 {
                print("1", terminator: "")
            } else {
                print("0", terminator: "")
            }
            if i % 8 == 0 {
                print(" ", terminator: "")
            }
        }
        print("")
    }
}

let ff = 1.234
let gg = -1.99
let ss = pow(ff, gg)

let f = DoubleByBit(ff)
let g = DoubleByBit(gg)
let h = DoubleByBit(ss)
let s = DoubleByBit.pow(f, g)
print(ff)
print(gg)
print(ss)
print(s.doubleValue)
f.bitPattern()
g.bitPattern()
h.bitPattern()
s.bitPattern()
