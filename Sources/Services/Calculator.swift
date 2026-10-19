import Foundation

/// Evaluates simple arithmetic lines ("12 * (3 + 4) =") safely.
/// Input is whitelisted and grammar-checked before it ever reaches NSExpression,
/// because malformed NSExpression formats raise Objective-C exceptions Swift cannot catch.
enum Calculator {
    private enum Token { case number(String), op(Character), open, close }

    private static let allowed = Set("0123456789.+-*/()xX×÷ ")

    /// Returns the formatted result for a line ending in "=", or nil if it isn't valid math.
    static func result(for line: String) -> String? {
        var body = line.trimmingCharacters(in: .whitespaces)
        guard body.hasSuffix("="), body.count > 1, body.count < 500 else { return nil }
        body.removeLast()
        guard body.allSatisfy({ allowed.contains($0) }),
              let formatString = normalizedFormat(body) else { return nil }
        let expression = NSExpression(format: formatString)
        guard let value = (expression.expressionValue(with: nil, context: nil) as? NSNumber)?.doubleValue,
              value.isFinite else { return nil }
        return display(value)
    }

    /// Tokenises, validates operator/operand order and parenthesis balance, and
    /// rewrites every number as a Double literal so division isn't integer division.
    private static func normalizedFormat(_ text: String) -> String? {
        var tokens: [Token] = []
        var number = ""
        func flush() -> Bool {
            guard !number.isEmpty else { return true }
            guard number.filter({ $0 == "." }).count <= 1, number != "." else { return false }
            tokens.append(.number(number)); number = ""; return true
        }
        for ch in text {
            switch ch {
            case "0"..."9", ".": number.append(ch)
            case " ": guard flush() else { return nil }
            case "(": guard flush() else { return nil }; tokens.append(.open)
            case ")": guard flush() else { return nil }; tokens.append(.close)
            case "x", "X", "×": guard flush() else { return nil }; tokens.append(.op("*"))
            case "÷": guard flush() else { return nil }; tokens.append(.op("/"))
            default: guard flush() else { return nil }; tokens.append(.op(ch))
            }
        }
        guard flush(), !tokens.isEmpty else { return nil }

        var out = ""
        var depth = 0
        var expectOperand = true
        var pendingSign = false
        var hasOperator = false
        for token in tokens {
            switch token {
            case .number(let n):
                guard expectOperand else { return nil }
                let literal = n.hasPrefix(".") ? "0" + n : n
                out += literal.contains(".") ? (literal.hasSuffix(".") ? literal + "0" : literal) : literal + ".0"
                expectOperand = false; pendingSign = false
            case .open:
                guard expectOperand else { return nil }
                out += "("; depth += 1; pendingSign = false
            case .close:
                guard !expectOperand, depth > 0 else { return nil }
                out += ")"; depth -= 1
            case .op(let o):
                if expectOperand {
                    // A single unary sign is allowed directly before an operand.
                    guard o == "-" || o == "+", !pendingSign else { return nil }
                    if o == "-" { out += "-" }
                    pendingSign = true
                } else {
                    out += String(o); expectOperand = true; hasOperator = true
                }
            }
        }
        guard !expectOperand, depth == 0, hasOperator else { return nil }
        return out
    }

    private static func display(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(format: "%.10g", value)
    }
}
