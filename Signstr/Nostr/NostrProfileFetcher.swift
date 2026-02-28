// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  NostrProfileFetcher.swift
//  Signstr — Fetches kind 0 profile metadata for identities from Nostr relays.

import Foundation
import SwiftUI
import UIKit

// MARK: - Profile fetcher

/// Fetches kind 0 (profile metadata) events from Nostr relays for each identity.
/// Extracts `picture` and `name`/`display_name` fields and updates IdentityManager.
/// Fetches at most once per app launch per identity.
@MainActor
final class NostrProfileFetcher {

    static let shared = NostrProfileFetcher()

    /// Pubkey hexes that have already been fetched this launch.
    private var fetchedPubkeys: Set<String> = []

    private let fallbackRelay = "wss://relay.damus.io"

    private init() {}

    /// Fetches profiles for all identities that haven't been fetched this launch.
    func fetchAllProfiles() {
        let im = IdentityManager.shared
        for identity in im.identities where !fetchedPubkeys.contains(identity.pubkeyHex) {
            fetchProfile(for: identity)
        }
    }

    /// Fetches the profile for a single identity.
    func fetchProfile(for identity: NostrIdentity) {
        guard !fetchedPubkeys.contains(identity.pubkeyHex) else { return }
        fetchedPubkeys.insert(identity.pubkeyHex)

        let pubkeyHex = identity.pubkeyHex
        let identityId = identity.id

        // Pick relay: first connected relay for this identity, or fallback
        let relayURL = pickRelay(for: identity)
        print("[ProfileFetcher] Fetching kind 0 for \(pubkeyHex.prefix(8))... from \(relayURL)")

        Task.detached { [fallbackRelay] in
            do {
                let profile = try await Self.fetchKind0(pubkeyHex: pubkeyHex, relayURL: relayURL)
                await MainActor.run {
                    IdentityManager.shared.updateProfileMetadata(
                        id: identityId,
                        pictureURL: profile.picture,
                        profileName: profile.displayName ?? profile.name
                    )
                }
            } catch {
                // If the primary relay failed and it wasn't already the fallback, try fallback
                if relayURL != fallbackRelay {
                    print("[ProfileFetcher] Primary relay failed (\(error)), trying fallback...")
                    do {
                        let profile = try await Self.fetchKind0(pubkeyHex: pubkeyHex, relayURL: fallbackRelay)
                        await MainActor.run {
                            IdentityManager.shared.updateProfileMetadata(
                                id: identityId,
                                pictureURL: profile.picture,
                                profileName: profile.displayName ?? profile.name
                            )
                        }
                    } catch {
                        print("[ProfileFetcher] Fallback also failed for \(pubkeyHex.prefix(8))...: \(error)")
                    }
                } else {
                    print("[ProfileFetcher] Failed to fetch profile for \(pubkeyHex.prefix(8))...: \(error)")
                }
            }
        }
    }

    private func pickRelay(for identity: NostrIdentity) -> String {
        // Check if there's a connected relay for this identity via saved connections
        let connections = NIP46ConnectionStore.loadAll(forIdentity: identity.id)
        if let firstRelay = connections.first?.relayURLs.first {
            return firstRelay
        }
        return fallbackRelay
    }

    // MARK: - WebSocket kind 0 fetch

    /// Opens a temporary WebSocket, sends REQ for kind 0, waits for the event, then closes.
    private static func fetchKind0(pubkeyHex: String, relayURL: String) async throws -> NostrProfile {
        guard let url = URL(string: relayURL) else {
            throw ProfileFetchError.invalidURL
        }

        let ws = URLSession.shared.webSocketTask(with: url)
        ws.resume()

        defer { ws.cancel(with: .normalClosure, reason: nil) }

        // Send REQ
        let subId = "profile-\(pubkeyHex.prefix(8))"
        let req = "[\"REQ\",\"\(subId)\",{\"kinds\":[0],\"authors\":[\"\(pubkeyHex)\"],\"limit\":1}]"
        try await ws.send(.string(req))

        // Wait for EVENT or EOSE (timeout after 10 seconds)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await ws.receive()
            } catch {
                throw ProfileFetchError.connectionFailed(error)
            }

            guard case .string(let text) = message,
                  let data = text.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let msgType = array.first as? String else {
                continue
            }

            if msgType == "EVENT", array.count >= 3,
               let eventDict = array[2] as? [String: Any],
               let content = eventDict["content"] as? String {
                // Parse the profile JSON from the event content
                if let profileData = content.data(using: .utf8),
                   let profileDict = try? JSONSerialization.jsonObject(with: profileData) as? [String: Any] {
                    let profile = NostrProfile(
                        name: profileDict["name"] as? String,
                        displayName: profileDict["display_name"] as? String,
                        picture: profileDict["picture"] as? String
                    )
                    print("[ProfileFetcher] Got profile from \(relayURL): name=\(profile.name ?? "nil") picture=\(profile.picture?.prefix(40) ?? "nil")")
                    // Send CLOSE
                    try? await ws.send(.string("[\"CLOSE\",\"\(subId)\"]"))
                    return profile
                }
            }

            if msgType == "EOSE" {
                // End of stored events — no kind 0 found
                try? await ws.send(.string("[\"CLOSE\",\"\(subId)\"]"))
                throw ProfileFetchError.noProfileFound
            }
        }

        throw ProfileFetchError.timeout
    }

    enum ProfileFetchError: Error {
        case invalidURL
        case connectionFailed(Error)
        case noProfileFound
        case timeout
    }
}

/// Parsed fields from a kind 0 Nostr profile event.
struct NostrProfile {
    let name: String?
    let displayName: String?
    let picture: String?
}

// MARK: - Profile image cache and loader

/// In-memory image cache for profile pictures. Keyed by URL string.
final class ProfileImageCache {
    static let shared = ProfileImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50
    }

    func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func setImage(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}

/// Observable image loader for a single profile picture URL.
/// Used by SwiftUI views to asynchronously load and display profile images.
@MainActor
final class ProfileImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private var loadedURL: String?

    func load(from urlString: String?) {
        guard let urlString, !urlString.isEmpty else {
            image = nil
            return
        }

        // Already loaded this URL
        if loadedURL == urlString, image != nil { return }

        // Check cache
        if let cached = ProfileImageCache.shared.image(for: urlString) {
            image = cached
            loadedURL = urlString
            return
        }

        guard let url = URL(string: urlString) else { return }

        isLoading = true
        loadedURL = urlString
        let capturedURL = urlString

        Task.detached {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let uiImage = UIImage(data: data) else {
                    await MainActor.run { self.isLoading = false }
                    return
                }
                ProfileImageCache.shared.setImage(uiImage, for: capturedURL)
                await MainActor.run {
                    // Only update if we haven't been asked to load a different URL since
                    if self.loadedURL == capturedURL {
                        self.image = uiImage
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// MARK: - Reusable avatar view

/// Displays a profile picture in a circle, falling back to initials if no picture is available.
struct ProfileAvatarView: View {
    let pictureURL: String?
    let initials: String
    var size: CGFloat = 48
    var fontSize: CGFloat? = nil
    var isSelected: Bool = false

    @StateObject private var loader = ProfileImageLoader()

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.sgBorderHover : Color.sgBgSurface)
                .frame(width: size, height: size)

            if isSelected {
                Circle()
                    .stroke(Color.sgTextBright, lineWidth: 2)
                    .frame(width: size + 4, height: size + 4)
            }

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.outfit(.medium, size: fontSize ?? (size * 0.33)))
                    .foregroundColor(isSelected ? .sgTextWhite : .sgTextMuted)
            }
        }
        .onAppear { loader.load(from: pictureURL) }
        .onChange(of: pictureURL) { newURL in loader.load(from: newURL) }
    }
}
