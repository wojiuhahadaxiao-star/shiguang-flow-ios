import UIKit
import Photos

final class PhotoStore: NSObject, PHPhotoLibraryChangeObserver {
    let manager = PHCachingImageManager()
    private(set) var assets: [String: PHAsset] = [:]
    var onChange: (() -> Void)?
    private let queue = DispatchQueue(label: "com.yang.shiguangflow.photos", qos: .userInitiated)
    private var generation = 0
    private let previews: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    private func previewKey(_ id: String, _ pixels: CGSize) -> NSString {
        return "\(id)|\(Int(pixels.width))x\(Int(pixels.height))" as NSString
    }
    func cachedPreview(for id: String, pixels: CGSize) -> UIImage? {
        previews.object(forKey: previewKey(id, pixels))
    }
    override init() { super.init(); PHPhotoLibrary.shared().register(self) }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    var authorization: PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    func authorize(completion: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in DispatchQueue.main.async(execute: completion) }
    }
    func load(completion: @escaping ([PhotoRecord]) -> Void) {
        generation += 1; let ticket = generation
        guard isAuthorized else { assets = [:]; completion([]); return }
        queue.async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var records: [PhotoRecord] = []; var assets: [String: PHAsset] = [:]
            result.enumerateObjects { asset, _, _ in
                assets[asset.localIdentifier] = asset
                records.append(PhotoRecord(id: asset.localIdentifier, date: asset.creationDate))
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == ticket else { return }
                self.assets = assets; completion(records)
            }
        }
    }
    @discardableResult func image(for id: String, pixels: CGSize, highQuality: Bool = false, completion: @escaping (UIImage?, Bool, String?) -> Void) -> PHImageRequestID? {
        guard let asset = assets[id] else { completion(nil, true, "照片已不可用"); return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        options.deliveryMode = highQuality ? .highQualityFormat : .opportunistic
        options.version = .current
        return manager.requestImage(for: asset, targetSize: pixels, contentMode: .aspectFit, options: options) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let error = info?[PHImageErrorKey] as? Error
            DispatchQueue.main.async {
                guard !cancelled else { return }
                if !highQuality, let image {
                    let key = self.previewKey(id, pixels)
                    // A low-resolution callback must not replace an existing clear preview.
                    if !degraded || self.previews.object(forKey: key) == nil {
                        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                        self.previews.setObject(image, forKey: key, cost: cost)
                    }
                }
                completion(image, !degraded, error?.localizedDescription)
            }
        }
    }
    func preheat(_ ids: [String], size: CGSize) {
        manager.stopCachingImagesForAllAssets()
        let options = PHImageRequestOptions(); options.deliveryMode = .opportunistic; options.resizeMode = .fast
        manager.startCachingImages(for: ids.compactMap { assets[$0] }, targetSize: size, contentMode: .aspectFit, options: options)
    }
    func delete(_ ids: [String], completion: @escaping (Bool, String?) -> Void) {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.deleteAssets(result) }) { success, error in
            DispatchQueue.main.async { completion(success, error?.localizedDescription) }
        }
    }
    func photoLibraryDidChange(_ changeInstance: PHChange) { DispatchQueue.main.async { [weak self] in self?.previews.removeAllObjects(); self?.onChange?() } }
}
