import Foundation

enum HostFormError: LocalizedError {
    case name, address, pairingMissing

    var errorDescription: String? {
        switch self {
        case .name: "Enter a Mac name of up to 80 characters."
        case .address: "Enter a hostname or IP address and a port from 1 to 65535."
        case .pairingMissing: "Get a new invitation on your Mac. Then choose Edit Mac to pair again."
        }
    }
}
