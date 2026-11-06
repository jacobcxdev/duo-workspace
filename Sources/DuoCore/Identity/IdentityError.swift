import Foundation

public enum IdentityError: LocalizedError {
    case randomGeneration(Int32), keychain(Int32), invalidIdentity, invalidCertificate, invalidInvitation, expiredInvitation, missingIdentity, invalidRevocationRecord, accessStoreInUse

    public var errorDescription: String? {
        switch self {
        case .randomGeneration: "Couldn’t create pairing data. Try again."
        case .keychain: "Keychain access failed. Unlock this device and allow access if asked."
        case .invalidIdentity: "Couldn’t verify the pairing data. Access is blocked."
        case .invalidCertificate: "Couldn’t verify the other device."
        case .invalidInvitation: "Paste the full pairing invitation from your Mac."
        case .expiredInvitation: "This invitation expired. Create a new one on your Mac."
        case .missingIdentity: "The Mac’s identity is missing. Restore its Keychain record before sharing."
        case .invalidRevocationRecord: "The revocation record is missing or invalid. Restore it before sharing."
        case .accessStoreInUse: "Duo Workspace Host is already running. Quit the other copy first."
        }
    }
}
