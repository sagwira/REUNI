//
//  CachedImageLoader.swift
//  REUNI
//
//  Custom image loader with persistent caching and retry logic
//

import SwiftUI
import Combine

// MARK: - Image Cache Manager
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits
        cache.countLimit = 200  // Maximum 200 images
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
    }

    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Image Loader
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasFailed = false  // Track complete failure

    private let url: URL
    private var cancellable: AnyCancellable?
    private var retryCount = 0
    private let maxRetries = 2  // Reduced from 3 for faster failure
    private var timeoutTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
    }

    func load() {
        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            self.isLoading = false
            self.hasFailed = false
            return
        }

        // Already loading or loaded or failed
        guard image == nil && !isLoading && !hasFailed else { return }

        isLoading = true
        error = nil

        // Set a timeout to prevent indefinite loading
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15 seconds total timeout
            if self.isLoading && self.image == nil {
                print("⏱️ Image load timeout: \(self.url.lastPathComponent)")
                self.isLoading = false
                self.hasFailed = true
                self.cancellable?.cancel()
            }
        }

        // Create request with proper headers
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10  // Reduced to 10 seconds per attempt

        cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map { UIImage(data: $0.data) }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false

                    switch completion {
                    case .finished:
                        self.timeoutTask?.cancel()
                        break
                    case .failure(let error):
                        self.error = error
                        print("⚠️ Image load failed: \(self.url.lastPathComponent) - \(error.localizedDescription)")

                        // Retry logic
                        if self.retryCount < self.maxRetries {
                            self.retryCount += 1
                            print("🔄 Retrying image load (\(self.retryCount)/\(self.maxRetries))...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.load()
                            }
                        } else {
                            // Max retries reached - mark as failed
                            print("❌ Image load failed after \(self.maxRetries) retries: \(self.url.lastPathComponent)")
                            self.hasFailed = true
                            self.timeoutTask?.cancel()
                        }
                    }
                },
                receiveValue: { [weak self] image in
                    guard let self = self, let image = image else {
                        // Image data was corrupted or invalid
                        self?.hasFailed = true
                        self?.isLoading = false
                        self?.timeoutTask?.cancel()
                        return
                    }

                    // Cache the image
                    ImageCache.shared.set(image, forKey: self.url.absoluteString)
                    self.image = image
                    self.retryCount = 0  // Reset retry count on success
                    self.hasFailed = false
                    self.timeoutTask?.cancel()
                    print("✅ Image loaded and cached: \(self.url.lastPathComponent)")
                }
            )
    }

    func cancel() {
        cancellable?.cancel()
        timeoutTask?.cancel()
    }

    nonisolated deinit {
        cancellable?.cancel()
    }
}

// MARK: - Cached Async Image View
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader: ImageLoader

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder

        // Initialize loader
        if let url = url {
            _loader = StateObject(wrappedValue: ImageLoader(url: url))
        } else {
            _loader = StateObject(wrappedValue: ImageLoader(url: URL(string: "about:blank")!))
        }
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else if loader.hasFailed {
                // When image fails - show nothing (clean look)
                EmptyView()
            } else {
                placeholder()
            }
        }
        .onAppear {
            if url != nil {
                loader.load()
            }
        }
    }
}

// MARK: - Convenience Initializer
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
