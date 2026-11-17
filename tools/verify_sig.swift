// Checks a Sparkle EdDSA signature against a file using only the public key
// (no Keychain access). Exit 0 = valid, 1 = invalid.
// usage: swift tools/verify_sig.swift <public-key-base64> <signature-base64> <file>
import CryptoKit
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: verify_sig.swift <public-key> <signature> <file>\n".data(using: .utf8)!)
    exit(2)
}
guard let keyData = Data(base64Encoded: args[1]), keyData.count == 32,
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
    print("bad public key"); exit(1)
}
guard let sig = Data(base64Encoded: args[2]), sig.count == 64 else {
    print("bad signature: not 64 bytes of base64"); exit(1)
}
guard let file = FileManager.default.contents(atPath: args[3]) else {
    print("can't read \(args[3])"); exit(1)
}
if key.isValidSignature(sig, for: file) {
    print("valid"); exit(0)
} else {
    print("INVALID"); exit(1)
}
