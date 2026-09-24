#if !os(watchOS)
import Foundation
import Security

/// Where the Gemini key lives, and whether anybody asked for it to be used.
///
/// ## Why the key is not in the App Group
///
/// Everything else this app keeps goes in `SenkuStorage.shared`, because it
/// is food logs and the widgets need to read them. A credential is a different
/// kind of thing: `UserDefaults` is a plist in the container, readable by
/// anything that can reach the container and trivially recovered from an
/// unencrypted backup. The Keychain is the one place on the phone built to hold
/// a secret, so that is where this goes, even though it means two stores for
/// one feature.
enum GeminiAccount {
    private static let service = "pk.Senku.gemini"
    private static let account = "api-key"
    private static let enabledKey = "senku.gemini.enabled"

    // MARK: - The key

    /// The stored key, or nil.
    static var key: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let key = String(data: data, encoding: .utf8),
            !key.isEmpty
        else { return nil }
        return key
    }

    /// Stores a key, replacing any already there. An empty string clears it,
    /// because that is what an emptied text field means.
    @discardableResult
    static func save(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clear() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(trimmed.utf8),
            // Without this the key is readable while the phone is locked, and
            // syncs into backups. It is needed only when somebody is looking at
            // the screen, so it can have the strictest class that still works.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }

        var insert = query
        insert.merge(attributes) { current, _ in current }
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func clear() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - The switch

    /// Whether readings should go to Gemini.
    ///
    /// Separate from whether a key exists, so that turning it off leaves the
    /// key where it is — somebody switching back on should not have to go and
    /// find it again.
    static var isEnabled: Bool {
        get { SenkuStorage.shared.bool(forKey: enabledKey) }
        set { SenkuStorage.shared.set(newValue, forKey: enabledKey) }
    }

    /// The only question the reading path asks: send this photograph away, or
    /// not. Both halves have to be true.
    static var isActive: Bool { isEnabled && key != nil }
}
#endif
