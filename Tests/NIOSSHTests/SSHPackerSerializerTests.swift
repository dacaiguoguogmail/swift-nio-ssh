//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2019 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@testable import NIOSSH
import XCTest

final class SSHPacketSerializerTests: XCTestCase {

    func testVersion() throws {
        let message = SSHMessage.version("SSH-2.0-SwiftSSH_1.0")
        let serializer = SSHPacketSerializer()
        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 22)
        serializer.serialize(message: message, to: &buffer)

        XCTAssertEqual("SSH-2.0-SwiftSSH_1.0\r\n", buffer.readString(length: buffer.readableBytes))
    }

    func testDisconnectMessage() throws {
        let message = SSHMessage.disconnect(.init(reason: 42, description: ByteBuffer.of(string: "description"), tag: ByteBuffer.of(string: "tag")))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)
        parser.append(bytes: &buffer)

        switch try parser.nextPacket() {
        case .disconnect(let message):
            XCTAssertEqual(42, message.reason)
            XCTAssertEqual(ByteBuffer.of(string: "description"), message.description)
            XCTAssertEqual(ByteBuffer.of(string: "tag"), message.tag)
        default:
            XCTFail("Expecting .disconnect")
        }
    }

    func testServiceRequest() throws {
        let message = SSHMessage.serviceRequest(.init(service: ByteBuffer.of(string: "ssh-userauth")))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)

        XCTAssertEqual([0, 0, 0, 24,  6, 5, 0, 0, 0, 12, 115, 115, 104, 45, 117, 115, 101, 114, 97, 117, 116, 104], buffer.getBytes(at: 0, length: 22))

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .serviceRequest(let message):
            XCTAssertEqual(ByteBuffer.of(string: "ssh-userauth"), message.service)
        default:
            XCTFail("Expecting .serviceRequest")
        }
    }

    func testServiceAccept() throws {
        let message = SSHMessage.serviceAccept(.init(service: ByteBuffer.of(string: "ssh-userauth")))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)

        XCTAssertEqual([0, 0, 0, 24,  6, 6, 0, 0, 0, 12, 115, 115, 104, 45, 117, 115, 101, 114, 97, 117, 116, 104], buffer.getBytes(at: 0, length: 22))

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .serviceAccept(let message):
            XCTAssertEqual(ByteBuffer.of(string: "ssh-userauth"), message.service)
        default:
            XCTFail("Expecting .serviceAccept")
        }
    }

    func testKeyExchange() throws {
        let message = SSHMessage.keyExchange(.init(
            cookie: ByteBuffer.of(bytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
            keyExchangeAlgorithms: ["curve25519-sha256"],
            serverHostKeyAlgorithms: ["ssh-rsa", "ssh-dss", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521"],
            encryptionAlgorithmsClientToServer: ["aes256-ctr"],
            encryptionAlgorithmsServerToClient: ["aes256-ctr"],
            macAlgorithmsClientToServer: ["hmac-sha2-256"],
            macAlgorithmsServerToClient: ["hmac-sha2-256"],
            compressionAlgorithmsClientToServer: ["none"],
            compressionAlgorithmsServerToClient: ["none"],
            languagesClientToServer: [],
            languagesServerToClient: []
        ))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .keyExchange(let message):
            XCTAssertEqual(ByteBuffer.of(bytes: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), message.cookie)
            XCTAssertEqual(["curve25519-sha256"], message.keyExchangeAlgorithms)
            XCTAssertEqual(["ssh-rsa", "ssh-dss", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521"], message.serverHostKeyAlgorithms)
            XCTAssertEqual(["aes256-ctr"], message.encryptionAlgorithmsClientToServer)
            XCTAssertEqual(["aes256-ctr"], message.encryptionAlgorithmsServerToClient)
            XCTAssertEqual(["hmac-sha2-256"], message.macAlgorithmsClientToServer)
            XCTAssertEqual(["hmac-sha2-256"], message.macAlgorithmsServerToClient)
            XCTAssertEqual(["none"], message.compressionAlgorithmsClientToServer)
            XCTAssertEqual(["none"], message.compressionAlgorithmsServerToClient)
            XCTAssertEqual([], message.languagesClientToServer)
            XCTAssertEqual([], message.languagesServerToClient)
        default:
            XCTFail("Expecting .keyExchange")
        }
    }

    func testKeyExchangeInit() throws {
        let message = SSHMessage.keyExchangeInit(.init(publicKey: ByteBuffer.of(bytes: [42])))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .keyExchangeInit(let message):
            XCTAssertEqual(ByteBuffer.of(bytes: [42]), message.publicKey)

        default:
            XCTFail("Expecting .keyExchangeInit")
        }
    }

    func testKeyExchangeReply() throws {
        let message = SSHMessage.keyExchangeReply(.init(
            hostKey: ByteBuffer.of(bytes: [11, 101]),
            publicKey: ByteBuffer.of(bytes: [42, 42]),
            signature: ByteBuffer.of(bytes: [100, 101, 102])
        ))
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 20)
        serializer.serialize(message: message, to: &buffer)

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .keyExchangeReply(let message):
            XCTAssertEqual(ByteBuffer.of(bytes: [11, 101]), message.hostKey)
            XCTAssertEqual(ByteBuffer.of(bytes: [42, 42]), message.publicKey)
            XCTAssertEqual(ByteBuffer.of(bytes: [100, 101, 102]), message.signature)
        default:
            XCTFail("Expecting .keyExchangeReply")
        }
    }

    func testNewKey() throws {
        let message = SSHMessage.newKeys
        let allocator = ByteBufferAllocator()
        var serializer = SSHPacketSerializer()
        var parser = SSHPacketParser(allocator: allocator)

        do {
            var buffer = allocator.buffer(capacity: 22)
            serializer.serialize(message: .version("SSH-2.0-SwiftSSH_1.0"), to: &buffer)
            parser.append(bytes: &buffer)
            _ = try parser.nextPacket()
            serializer.state = .cleartext
        }

        var buffer = allocator.buffer(capacity: 5)
        serializer.serialize(message: message, to: &buffer)

        parser.append(bytes: &buffer)
        switch try parser.nextPacket() {
        case .newKeys:
            break
        default:
            XCTFail("Expecting .newKeys")
        }
    }
}
