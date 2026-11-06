import Foundation
import Network
import Security

/// TLS 1.3 with client certificates. Device approval is checked after the handshake.
public enum SecureParameters {
    public static func server(identity: LocalIdentity, loopbackOnly: Bool = false) -> NWParameters {
        let options = tls(identity: identity)
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, completion in
            completion(validate(trust: sec_trust_copy_ref(trust).takeRetainedValue(), pin: nil, server: false))
        }, DispatchQueue(label: "DuoWorkspace.ClientIdentity"))
        return parameters(options, loopbackOnly: loopbackOnly)
    }

    public static func client(identity: LocalIdentity, hostPin: Data) throws -> NWParameters {
        guard hostPin.count == 32 else { throw IdentityError.invalidIdentity }
        let options = tls(identity: identity)
        sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, "duoworkspace.local")
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, completion in
            completion(validate(trust: sec_trust_copy_ref(trust).takeRetainedValue(), pin: hostPin, server: true))
        }, DispatchQueue(label: "DuoWorkspace.HostIdentity"))
        return parameters(options, loopbackOnly: false)
    }

    static func validate(trust: SecTrust, pin: Data?, server: Bool) -> Bool {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], chain.count == 1,
              let certificate = chain.first,
              let actualPin = LocalIdentity.pin(certificate: SecCertificateCopyData(certificate) as Data) else { return false }
        if let pin, !LocalIdentity.matches(pin, actualPin) { return false }
        let policy = SecPolicyCreateSSL(server, server ? "duoworkspace.local" as CFString : nil)
        guard SecTrustSetPolicies(trust, policy) == errSecSuccess,
              SecTrustSetAnchorCertificates(trust, [certificate] as CFArray) == errSecSuccess,
              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
              SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess else { return false }
        return SecTrustEvaluateWithError(trust, nil)
    }

    private static func tls(identity: LocalIdentity) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_local_identity(options.securityProtocolOptions, sec_identity_create(identity.securityIdentity)!)
        // Require a fresh handshake so resumed sessions cannot bypass revocation.
        sec_protocol_options_set_tls_resumption_enabled(options.securityProtocolOptions, false)
        sec_protocol_options_set_tls_tickets_enabled(options.securityProtocolOptions, false)
        return options
    }

    private static func parameters(_ tls: NWProtocolTLS.Options, loopbackOnly: Bool) -> NWParameters {
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.allowLocalEndpointReuse = true
        if loopbackOnly { parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any) }
        return parameters
    }
}
