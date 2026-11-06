import XCTest
import Network
import Security
@testable import DuoCore

final class SecureChannelTests:XCTestCase {
    func testClientWithoutIdentityCannotSendApplicationData() throws {
        try rejectedConnection(tls12: false, presentIdentity: false)
    }

    func testTLS12CannotDowngradeTheListener() throws {
        try rejectedConnection(tls12: true, presentIdentity: true)
    }

    private func rejectedConnection(tls12: Bool, presentIdentity: Bool) throws {
        let rejected = expectation(description: "Handshake rejected")
        rejected.assertForOverFulfill = false
        let leaked = expectation(description: "No rejected application data")
        leaked.isInverted = true
        let host = try LocalIdentity(), device = try LocalIdentity()
        let listener = try NWListener(using: SecureParameters.server(identity: host, loopbackOnly: true), on: .any)
        var server: SecureChannel?, client: SecureChannel?
        listener.newConnectionHandler = { connection in
            let channel = SecureChannel(connection); server = channel
            channel.onPacket = { _ in leaked.fulfill() }
            channel.onFailure = { _ in rejected.fulfill() }
            channel.start()
        }
        listener.stateUpdateHandler = { state in
            guard case .ready = state, let port = listener.port else { return }
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, tls12 ? .TLSv12 : .TLSv13)
            sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, tls12 ? .TLSv12 : .TLSv13)
            if presentIdentity { sec_protocol_options_set_local_identity(tls.securityProtocolOptions, sec_identity_create(device.securityIdentity)!) }
            sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
                complete(SecureParameters.validate(trust: sec_trust_copy_ref(trust).takeRetainedValue(), pin: host.publicKeyPin, server: true))
            }, DispatchQueue(label: "DuoTest.RejectedTrust"))
            let channel = SecureChannel(NWConnection(host: "127.0.0.1", port: port, using: NWParameters(tls: tls)))
            client = channel
            channel.onFailure = { _ in rejected.fulfill() }
            channel.onReady = { channel.send(.ping, payload: Data([1])) }
            channel.start()
        }
        listener.start(queue: DispatchQueue(label: "DuoTest.RejectedConnection"))
        wait(for: [rejected, leaked], timeout: 3)
        client?.onFailure = nil; server?.onFailure = nil
        client?.cancel(); server?.cancel(); listener.cancel()
    }
    func testAuthenticatedTLSRoundTrip() throws {
        let done=expectation(description:"Authenticated packet round trip")
        let serverIdentity = try LocalIdentity(), clientIdentity = try LocalIdentity()
        let listener=try NWListener(using:SecureParameters.server(identity: serverIdentity, loopbackOnly: true),on:.any)
        var server:SecureChannel?,client:SecureChannel?
        listener.newConnectionHandler={connection in
            let channel=SecureChannel(connection);server=channel
            channel.onFailure={XCTFail("Server: \($0)")}
            channel.onPacket={p in if p.kind == .ping {channel.send(.pong,payload:p.payload)}}
            channel.start()
        }
        listener.stateUpdateHandler={state in
            guard case .ready=state,let port=listener.port else{return}
            let connection=NWConnection(host:"127.0.0.1",port:port,using:try! SecureParameters.client(identity: clientIdentity, hostPin: serverIdentity.publicKeyPin))
            let channel=SecureChannel(connection);client=channel
            channel.onFailure={XCTFail("Client: \($0)")}
            channel.onReady={XCTAssertTrue(channel.isTLS13); XCTAssertEqual(channel.peerPublicKeyPin, serverIdentity.publicKeyPin); channel.send(.ping,payload:Data("authenticated".utf8))}
            channel.onPacket={p in if p.kind == .pong {XCTAssertEqual(p.payload,Data("authenticated".utf8));done.fulfill()}}
            channel.start()
        }
        listener.start(queue:DispatchQueue(label:"DuoTest.Listener"))
        wait(for:[done],timeout:10)
        client?.onFailure=nil;server?.onFailure=nil;client?.cancel();server?.cancel();listener.cancel()
    }
    func testWrongHostPinCannotSendApplicationData() throws {
        let rejected=expectation(description:"TLS rejects wrong key")
        rejected.assertForOverFulfill=false
        let leaked=expectation(description:"No unauthenticated packet")
        leaked.isInverted=true
        let serverIdentity = try LocalIdentity(), clientIdentity = try LocalIdentity(),wrong=try LocalIdentity()
        let listener=try NWListener(using:SecureParameters.server(identity: serverIdentity, loopbackOnly: true),on:.any)
        var server:SecureChannel?,client:SecureChannel?
        listener.newConnectionHandler={connection in
            let channel=SecureChannel(connection);server=channel
            channel.onPacket={_ in leaked.fulfill()};channel.start()
        }
        listener.stateUpdateHandler={state in
            guard case .ready=state,let port=listener.port else{return}
            let channel=SecureChannel(NWConnection(host:"127.0.0.1",port:port,using:try! SecureParameters.client(identity: clientIdentity, hostPin: wrong.publicKeyPin)))
            client=channel;channel.onReady={channel.send(.ping,payload:Data([1]))}
            channel.onFailure={_ in rejected.fulfill()};channel.start()
        }
        listener.start(queue:DispatchQueue(label:"DuoTest.BadKey"))
        wait(for:[rejected,leaked],timeout:3)
        client?.onFailure=nil;server?.onFailure=nil;client?.cancel();server?.cancel();listener.cancel()
    }
}
