import OpenBurnBarCore
import Foundation

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

func intValue(_ value: BurnBarJSONValue?) -> Int {
    switch value {
    case .number(let number):
        return Int(number)
    case .string(let string):
        return Int(string) ?? 0
    default:
        return 0
    }
}
