import Foundation

struct DMXValue{

    static let zero = DMXValue(withAbsoluteValue: 0)

    let absoluteValue: UInt8

    init(withAbsoluteValue value: UInt8){
        self.absoluteValue = value
    }

    var percent: Decimal{
        return Decimal(self.absoluteValue) / 255 * 100
    }
}
