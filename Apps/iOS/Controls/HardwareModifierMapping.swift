import UIKit
import DuoCore

enum HardwareModifierMapping {
    static let bindings: [(flag: UIKeyModifierFlags, modifier: RemoteModifier)] = [
        (.control, .control), (.alternate, .option), (.shift, .shift), (.command, .command)
    ]

    static let combinations: [UIKeyModifierFlags] = bindings.reduce([[]]) { combinations, binding in
        combinations + combinations.map { $0.union(binding.flag) }
    }
}
