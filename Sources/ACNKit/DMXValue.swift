import Foundation

public struct DMXValue: Equatable {

    public static let zero = DMXValue(withAbsoluteValue: 0)

    public let absoluteValue: UInt8

    public init(withAbsoluteValue value: UInt8){
        self.absoluteValue = value
    }

    public var percent: Decimal{
        return Decimal(self.absoluteValue) / 255 * 100
    }

    public static func == (lhs: DMXValue, rhs: DMXValue) -> Bool {
        return lhs.absoluteValue == rhs.absoluteValue
    }
}
