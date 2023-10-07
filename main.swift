import Foundation

struct Double: Equatable {
    static let zero = Double(0)
    static let one = Double(1)

    var bytes: UInt = 0

    init(_ d: Swift.Double) {
        guard d != 0 else { return }
        var d = d
        if d < 0 {
            bytes |= 1 << 63
            d = -d
        }
        let e = Int(floor(log2(d)))
        guard e > -1023, e < 1025 else { fatalError() }
        bytes |= UInt(e + 1023) << 52
        bytes |= UInt(pow(2, 52) * (d / pow(2, floor(log2(d))) - 1))
    }
    
    init(e: UInt, m: UInt) {
        guard e > 0, e < 2048, m < 1 << 52 else { fatalError("out of bounds") }
        bytes = e << 52
        bytes |= m
    }
    
    var exponent: UInt {
        var r = bytes >> 52
        r &= 1 << 11 - 1
        return r
    }
    
    var mantisse: UInt {
        return bytes & (1 << 52 - 1)
    }
    
    var isNegative: Bool {
        return bytes & 1 << 63 > 0
    }
    
    var doubleValue: Swift.Double {
        if self == .zero { return 0 }
        let r = pow(2, Swift.Double(exponent - 1023)) * (Swift.Double(mantisse) / pow(2, 52) + 1)
        return isNegative ? -r : r
    }

    static prefix func - (operand: Double) -> Double {
        if operand == .zero { return operand }
        var operand = operand
        operand.bytes ^= 1 << 63
        return operand
    }
    
    static func < (lhs: Double, rhs: Double) -> Bool {
        if lhs.isNegative && !rhs.isNegative { return true }
        if !lhs.isNegative && rhs.isNegative { return false }
        if lhs.isNegative { return -lhs > -rhs }
        if lhs.exponent < rhs.exponent { return true }
        if lhs.exponent > rhs.exponent { return false }
        if lhs.mantisse < rhs.mantisse { return true }
        if lhs.mantisse > rhs.mantisse { return false }
        return false
    }

    static func > (lhs: Double, rhs: Double) -> Bool {
        if lhs.isNegative && !rhs.isNegative { return false }
        if !lhs.isNegative && rhs.isNegative { return true }
        if lhs.isNegative { return -lhs < -rhs }
        if lhs.exponent < rhs.exponent { return false }
        if lhs.exponent > rhs.exponent { return true }
        if lhs.mantisse < rhs.mantisse { return false }
        if lhs.mantisse > rhs.mantisse { return true }
        return false
    }

    static func + (lhs: Double, rhs: Double) -> Double {
        if lhs == .zero { return rhs }
        if rhs == .zero { return lhs }
        if lhs.isNegative && rhs.isNegative { return -(-lhs + -rhs) }
        if lhs.isNegative { return rhs - -lhs }
        if rhs.isNegative { return lhs - -rhs }
        if lhs < rhs { return rhs + lhs }
        var exponent = lhs.exponent
        var mantisse = lhs.mantisse + (1 << 52 + rhs.mantisse) >> (lhs.exponent - rhs.exponent)
        if mantisse >= 1 << 52 {
            exponent += 1
            mantisse -= 1 << 52
            mantisse >>= 1
        }
        return Double(e: exponent, m: mantisse)
    }

    static func - (lhs: Double, rhs: Double) -> Double {
        if lhs == .zero { return -rhs }
        if rhs == .zero { return lhs }
        if lhs == rhs { return .zero }
        if lhs.isNegative && rhs.isNegative { return -rhs - -lhs }
        if lhs.isNegative { return -(-lhs + rhs) }
        if rhs.isNegative { return lhs + -rhs }
        if lhs < rhs { return -(rhs - lhs) }
        var exponent = lhs.exponent
        var mantisse = 1 << 52 + lhs.mantisse - (1 << 52 + rhs.mantisse) >> (lhs.exponent - rhs.exponent)
        while mantisse & 1 << 52 == 0 {
            exponent -= 1
            mantisse <<= 1
        }
        mantisse -= 1 << 52
        return Double(e: exponent, m: mantisse)
    }

    static func * (lhs: Double, rhs: Double) -> Double {
        if lhs == .zero || rhs == .zero { return .zero }
        if lhs == .one { return rhs }
        if rhs == .one { return lhs }
        if lhs.isNegative && rhs.isNegative { return -lhs * -rhs }
        if lhs.isNegative { return -(-lhs * rhs) }
        if rhs.isNegative { return -(lhs * -rhs) }
        var exponent = lhs.exponent + rhs.exponent - 1023
        let m = (1 << 52 + lhs.mantisse).multipliedFullWidth(by: 1 << 52 + rhs.mantisse)
        var mantisse = m.high << 12 + m.low >> 52
        if mantisse & 1 << 53 > 0 {
            exponent += 1
            mantisse >>= 1
        }
        mantisse -= 1 << 52
        return Double(e: exponent, m: mantisse)
    }
    
    static func / (lhs: Double, rhs: Double) -> Double {
        if rhs == .zero { fatalError() }
        if lhs == .zero { return .zero }
        if rhs == .one { return lhs }
        if lhs == rhs { return .one }
        if lhs.isNegative && rhs.isNegative { return -lhs / -rhs }
        if lhs.isNegative { return -(-lhs / rhs) }
        if rhs.isNegative { return -(lhs / -rhs) }
        var numerator = Double(e: 1022, m: lhs.mantisse)
        let denominator = Double(e: 1022, m: rhs.mantisse)
        var error = .one - denominator
        while .one + error > .one {
            numerator = numerator * (.one + error)
            error = error * error
        }
        return Double(e: numerator.exponent + lhs.exponent - rhs.exponent, m: numerator.mantisse)
    }
    
    func myprint() {
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
        print()
    }
}

let ff = -40.0
let gg = -3.0
let ss = ff / gg

let f = Double(ff)
let g = Double(gg)
let h = Double(ss)
let s = f / g
print(ff)
print(gg)
print(ss)
f.myprint()
g.myprint()
h.myprint()
s.myprint()
