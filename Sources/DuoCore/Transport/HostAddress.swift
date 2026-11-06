import Foundation

public enum HostAddress {
    public static func normalized(_ input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("["), value.hasSuffix("]") {
            value.removeFirst()
            value.removeLast()
        }
        guard !value.isEmpty, value.utf8.count <= 253,
              !value.contains(where: { $0.isWhitespace }),
              !value.contains("/"), !value.contains("@"),
              !value.contains("?"), !value.contains("#"),
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || ".-:%".unicodeScalars.contains($0) })
        else { return nil }
        // A single colon is normally an accidentally pasted host:port. Ports
        // have their own field; IPv6 addresses contain at least two colons.
        guard value.filter({ $0 == ":" }).count != 1 else { return nil }
        return value.lowercased()
    }
}
