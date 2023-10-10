import Foundation

struct Double: Equatable {
    static let zero = Double(0)
    static let one = Double(e: 1023, m: 0)
    static let two = Double(e: 1024, m: 0)

    var bytes: UInt = 0

    init(_ d: Swift.Double) {
        guard d != 0 else { return }
        var d = d
        if d < 0 {
            bytes |= 1 << 63
            d = -d
        }
        let e = floor(log2(d))
        bytes |= UInt(e + 1023) << 52
        bytes |= UInt(pow(2, 52) * (d * pow(2, -e) - 1))
    }
    
    init(e: UInt, m: UInt, n: Bool = false) {
        guard e > 0, e < 2048, m < 1 << 52 else { fatalError("out of bounds") }
        bytes = e << 52
        bytes |= m
        if n { bytes |= 1 << 63}
    }
    
    var exponent: UInt { bytes >> 52 & (1 << 11 - 1) }
    var mantisse: UInt { bytes & (1 << 52 - 1) }
    var isNegative: Bool { bytes & 1 << 63 > 0 }
    
    var doubleValue: Swift.Double {
        if self == .zero { return 0 }
        let r = pow(2, Swift.Double(Int(exponent) - 1023)) * (Swift.Double(mantisse) * pow(2, -52) + 1)
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
        return lhs.mantisse < rhs.mantisse
    }

    static func > (lhs: Double, rhs: Double) -> Bool {
        if lhs == rhs { return false }
        return !(lhs < rhs)
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
    
    static func abs(_ operand: Double) -> Double {
        if operand.isNegative { return -operand }
        return operand
    }
    
    static func sqrt(_ operand: Double) -> Double {
        if operand.isNegative { fatalError() }
        if operand == .zero { return .zero }
        if operand == .one { return .one }
        let o: Double
        var x: Double
        if operand.exponent & 1 == 0 {
            o = Double(e: 1024, m: operand.mantisse)
            x = Double(e: 1023, m: (1 << 52 + o.mantisse) >> 1)
        } else {
            o = Double(e: 1023, m: operand.mantisse)
            x = Double(e: 1023, m: o.mantisse >> 1)
        }
        let threshold = Double(e: 1023 - 48, m: 0)
        while abs(o - (x * x)) > threshold {
            x = x + o / x
            x = Double(e: x.exponent - 1, m: x.mantisse)
        }
        return Double(e: (operand.exponent + 1) >> 1 + 1023 - 512, m: x.mantisse)
    }
    
    static func cos(_ operand: Double) -> Double {
        if operand == .zero { return .one }
        return _sin(Double(e: 1021, m: 0) - normalize(abs(operand)))
    }
    
    static func sin(_ operand: Double) -> Double {
        if operand == .zero { return .zero }
        return _sin(normalize(operand))
    }
    
    static func tan(_ operand: Double) -> Double { sin(operand) / cos(operand) }
    
    static private func normalize(_ operand: Double) -> Double {
        let operand = operand * Double(e: 1020, m: 1230561511852163) // 1/(2*pi)
        if operand.exponent < 1023 { return operand }
        var exponent = operand.exponent
        var mantisse = operand.mantisse & (1 << (52 - (operand.exponent - 1023)) - 1)
        while mantisse & 1 << 52 == 0 {
            exponent -= 1
            mantisse <<= 1
        }
        mantisse -= 1 << 52
        return Double(e: exponent, m: mantisse, n: operand.isNegative)
    }
    
    static private func _sin(_ operand: Double) -> Double {
        if operand.isNegative { return -_sin(-operand) }
        if operand > Double(e: 1022, m: 0) { return -_sin(Double(e: 1023, m: 0) - operand) }
        if operand > Double(e: 1021, m: 0) { return  _sin(Double(e: 1022, m: 0) - operand) }
        var operand = operand * Double(e: 1025, m: 2570638124657944) // 2*pi
        let square = -operand * operand
        var r = Double.zero
        var fac = Double.two
        while r + operand != r {
            r = r + operand
            operand = operand * square / (fac * (fac + .one))
            fac = fac + .two
        }
        return r
    }
    
    static func log(_ operand: Double) -> Double {
        if operand.isNegative { fatalError() }
        if operand == .zero { fatalError() }
        if operand == .one { return .zero }
        var operand = operand
        var m: UInt = 1
        while operand < Double(e: 1022, m: 0) || operand > .two {
            operand = sqrt(operand)
            m += 1
        }
        operand = (operand - .one) / (operand + .one)
        let square = operand * operand
        var r = Double.zero
        var e = operand
        var n = Double.one
        while r + e != r {
            r = r + e
            operand = operand * square
            n = n + .two
            e = operand / n
        }
        return Double(e: r.exponent + m, m: r.mantisse, n: r.isNegative)
    }
    
    static func exp(_ operand: Double) -> Double {
        if operand == .zero { return .one }
        let o: Double
        if operand.exponent > 1022 {
            o = Double(e: 1022, m: operand.mantisse)
        } else {
            o = Double(e: operand.exponent, m: operand.mantisse)
        }
        var r = Double.one
        var e = o
        var fac = Double.two
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
    
    static func ^ (lhs: Double, rhs: Double) -> Double { exp(log(lhs) * rhs) }
    
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
        print("")
    }
}

let ff = 1.1296
let gg = -3.0
let ss = pow(ff, gg)

let f = Double(ff)
let g = Double(gg)
let h = Double(ss)
let s = f ^ g
print(ff)
print(gg)
print(ss)
print(s.doubleValue)
f.myprint()
g.myprint()
h.myprint()
s.myprint()
