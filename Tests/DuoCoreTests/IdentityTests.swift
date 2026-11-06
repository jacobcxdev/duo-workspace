import Foundation
import CryptoKit
import Security
import Testing
@testable import DuoCore

struct IdentityTests {
    @Test func graphemeCountCannotBypassNameByteLimit() throws {
        let oversized = "a" + String(repeating: "\u{301}", count: 2000)
        #expect(oversized.count == 1)
        #expect(!DeviceDisplayName.isValid(oversized))
        #expect(!AuthorizationRequest(deviceName: oversized).isValid)
        var registry = DeviceRegistry(hostPin: Data(repeating: 1, count: 32))
        #expect(throws: IdentityError.self) { try registry.approve(pin: Data(repeating: 2, count: 32), name: oversized) }
        #expect(DeviceDisplayName.isValid("iPhone · café 日本語"))
    }
    @Test func invitationRejectsAmbiguousURLAuthorityAndFragment() throws {
        let invitation = try PairingInvitation(name: "Mac", address: "mac.local", hostPin: LocalIdentity().publicKeyPin)
        let valid = try invitation.link()
        for invalid in [valid.replacingOccurrences(of: "//pair?", with: "//user@pair?"),
                        valid.replacingOccurrences(of: "//pair?", with: "//pair:443?"), valid + "#fragment",
                        valid + "&invite=duplicate"] {
            #expect(throws: IdentityError.self) { try PairingInvitation.parse(invalid) }
        }
        #expect(throws: IdentityError.self) { try PairingInvitation(name: "\n", address: "mac.local", hostPin: Data(repeating: 0, count: 32)) }
    }
    @Test func packetWorkBudgetCannotBuildAnUnboundedCallbackQueue() {
        var budget = TrafficBudget(capacity: 3, perSecond: 2)
        for _ in 0..<3 { let accepted = budget.consume(now: 0); #expect(accepted) }
        let overloaded = budget.consume(now: 0)
        let recovered = budget.consume(now: 0.5)
        #expect(!overloaded)
        #expect(recovered)
    }
    @Test func renewedCertificateKeepsPublicKeyIdentity() throws {
        let key = P256.Signing.PrivateKey()
        let first = try LocalIdentity(privateKey: key)
        let renewed = try LocalIdentity(privateKey: key, now: Date().addingTimeInterval(60))
        #expect(first.certificate != renewed.certificate)
        #expect(first.publicKeyPin == renewed.publicKeyPin)
        #expect(LocalIdentity.pin(certificate: first.certificate) == first.publicKeyPin)
    }

    @Test func expiryAndWrongPinsFailTrustEvaluation() throws {
        let current = try LocalIdentity()
        let expired = try LocalIdentity(now: Date().addingTimeInterval(-400 * 86400))
        func trust(_ identity: LocalIdentity) throws -> SecTrust {
            let certificate = try #require(SecCertificateCreateWithData(nil, identity.certificate as CFData))
            var result: SecTrust?
            #expect(SecTrustCreateWithCertificates(certificate, SecPolicyCreateSSL(true, "duoworkspace.local" as CFString), &result) == errSecSuccess)
            return try #require(result)
        }
        #expect(try SecureParameters.validate(trust: trust(current), pin: current.publicKeyPin, server: true))
        #expect(try !SecureParameters.validate(trust: trust(current), pin: expired.publicKeyPin, server: true))
        #expect(try !SecureParameters.validate(trust: trust(expired), pin: expired.publicKeyPin, server: true))
    }

    @Test func invitationRoundTripAndExpiryAreBounded() throws {
        let now = Date()
        let identity = try LocalIdentity()
        let invitation = try PairingInvitation(name: "Office Mac", address: "mac.local", hostPin: identity.publicKeyPin, now: now)
        let parsed = try PairingInvitation.parse(invitation.link(), now: now)
        #expect(parsed == invitation)
        #expect(throws: IdentityError.self) { try PairingInvitation.parse(invitation.link(), now: now.addingTimeInterval(301)) }
        #expect(throws: IdentityError.self) { try PairingInvitation.parse("https://example.com", now: now) }
    }

    @Test func revokingOneDeviceDoesNotRevokeAnother() throws {
        let server = try LocalIdentity(), first = try LocalIdentity(), second = try LocalIdentity()
        var registry = DeviceRegistry(hostPin: server.publicKeyPin)
        try registry.approve(pin: first.publicKeyPin, name: "First")
        try registry.approve(pin: second.publicKeyPin, name: "Second")
        registry.revoke(id: first.id)
        let restored = try JSONDecoder().decode(DeviceRegistry.self, from: JSONEncoder().encode(registry))
        #expect(restored.isValid)
        #expect(restored.device(pin: first.publicKeyPin)?.isApproved == false)
        #expect(restored.device(pin: second.publicKeyPin)?.isApproved == true)
    }

    @Test func admissionIsRateLimitedPerAddress() {
        var limiter = AdmissionLimiter()
        for _ in 0..<12 { let allowed = limiter.allow("peer", now: 0); #expect(allowed) }
        let rejected = limiter.allow("peer", now: 0)
        let otherAllowed = limiter.allow("other", now: 0)
        let refilled = limiter.allow("peer", now: 5)
        #expect(!rejected)
        #expect(otherAllowed)
        #expect(refilled)
    }
}
