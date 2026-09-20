import UIKit

final class CoverFlowLayout: UICollectionViewLayout {
    var cardSize = CGSize(width: 300, height: 390)
    var pitch: CGFloat { cardSize.width * 0.60 }
    private var count: Int { collectionView?.numberOfItems(inSection: 0) ?? 0 }
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        cardSize = CGSize(width: min(collectionView.bounds.width * 0.76, 440), height: collectionView.bounds.height * 0.86)
    }
    override var collectionViewContentSize: CGSize {
        CGSize(width: (collectionView?.bounds.width ?? 0) + CGFloat(max(0, count - 1)) * pitch, height: collectionView?.bounds.height ?? 0)
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { true }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard count > 0, let collectionView else { return [] }
        let center = collectionView.contentOffset.x / max(1, pitch)
        let low = max(0, Int(floor(center)) - 4), high = min(count - 1, Int(ceil(center)) + 4)
        guard low <= high else { return [] }
        return (low...high).compactMap { layoutAttributesForItem(at: IndexPath(item: $0, section: 0)) }
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView else { return nil }
        let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attr.size = cardSize
        attr.center = CGPoint(x: collectionView.bounds.width / 2 + CGFloat(indexPath.item) * pitch, y: collectionView.bounds.height / 2)
        let delta = (attr.center.x - collectionView.contentOffset.x - collectionView.bounds.width / 2) / max(1, pitch)
        let amount = min(abs(delta), 1)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 950
        if !UIAccessibility.isReduceMotionEnabled {
            transform = CATransform3DRotate(transform, -max(-1, min(delta, 1)) * .pi * 0.29, 0, 1, 0)
        }
        let scale = 1 - amount * 0.20
        transform = CATransform3DScale(transform, scale, scale, 1)
        attr.transform3D = transform
        attr.alpha = 1 - min(abs(delta), 3) * 0.16
        attr.zIndex = 1000 - Int(abs(delta) * 100)
        return attr
    }
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView, count > 0 else { return .zero }
        let current = collectionView.contentOffset.x / max(1, pitch)
        var index = (proposedContentOffset.x / max(1, pitch)).rounded()
        if abs(velocity.x) > 0.25, abs(index - current) < 0.5 { index = velocity.x > 0 ? floor(current) + 1 : ceil(current) - 1 }
        // Bound a flick to three photos; UIKit handles deceleration continuously.
        index = max(current.rounded() - 3, min(current.rounded() + 3, index))
        index = max(0, min(CGFloat(count - 1), index))
        return CGPoint(x: index * pitch, y: 0)
    }
}

final class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()
    private let liveOverlay = LivePhotoOverlay()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let message = UILabel()
    private var request: Int32?
    private weak var store: PhotoStore?
    private(set) var representedID: String?
    private var ratio: CGFloat = 1
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.addSubview(liveOverlay)
        contentView.addSubview(imageView); contentView.addSubview(spinner); contentView.addSubview(message)
        imageView.contentMode = .scaleAspectFit; imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14; imageView.backgroundColor = .white.withAlphaComponent(0.35)
        message.textAlignment = .center; message.font = .systemFont(ofSize: 13); message.textColor = .secondaryLabel
        message.numberOfLines = 3
        isAccessibilityElement = true
        accessibilityHint = "左右滑动浏览，上滑标记删除，双击查看大图"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        // Equal target area, bounded to card; unusually wide panoramas remain uncropped.
        let area = bounds.width * bounds.height * 0.66
        let desired = CGSize(width: sqrt(area * ratio), height: sqrt(area / ratio))
        let factor = min(1, bounds.width / max(1, desired.width), bounds.height / max(1, desired.height))
        let size = CGSize(width: desired.width * factor, height: desired.height * factor)
        imageView.frame = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
        liveOverlay.frame = imageView.bounds
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
        message.frame = bounds.insetBy(dx: 18, dy: 40)
    }
    func setLiveActive(_ active: Bool) {
        if active, let id = representedID, let store { liveOverlay.play(id: id, store: store) }
        else { liveOverlay.stop() }
    }
    func configure(id: String, store: PhotoStore, pixels: CGSize) {
        liveOverlay.stop()
        if let request { self.store?.manager.cancelImageRequest(request) }
        self.store = store; representedID = id
        imageView.image = store.cachedPreview(for: id, pixels: pixels)
        imageView.isHidden = false; contentView.transform = .identity; contentView.alpha = 1
        if imageView.image == nil { spinner.startAnimating() } else { spinner.stopAnimating() }
        message.text = nil
        if let asset = store.assets[id] { ratio = CGFloat(asset.pixelWidth) / CGFloat(max(1, asset.pixelHeight)) }
        setNeedsLayout()
        request = store.image(for: id, pixels: pixels) { [weak self] image, final, error in
            guard let self, self.representedID == id else { return }
            if let image, final || self.imageView.image == nil { self.imageView.image = image; self.spinner.stopAnimating() }
            if final {
                self.spinner.stopAnimating()
                if self.imageView.image == nil { self.message.text = error == nil ? "照片暂不可用\n请检查 iCloud 网络" : "照片加载失败\n请稍后重试" }
            }
        }
    }
    override func prepareForReuse() {
        super.prepareForReuse(); liveOverlay.stop()
        if let request { store?.manager.cancelImageRequest(request) }
        request = nil; representedID = nil; imageView.image = nil
        contentView.transform = .identity; contentView.alpha = 1
    }
}

/// Outline-only trash can: the count replaces the three interior strokes.
final class TrashCountView: UIView {
    var count = 0 { didSet { if oldValue != count { setNeedsDisplay() } } }
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; backgroundColor = .clear; isAccessibilityElement = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ rect: CGRect) {
        UIColor.flowBlue.setStroke()
        let outline = UIBezierPath(); outline.lineWidth = 2.2
        outline.lineCapStyle = .round; outline.lineJoinStyle = .round
        outline.move(to: CGPoint(x: 8, y: 14)); outline.addLine(to: CGPoint(x: 40, y: 14))
        outline.move(to: CGPoint(x: 18, y: 13)); outline.addLine(to: CGPoint(x: 19, y: 7))
        outline.addLine(to: CGPoint(x: 29, y: 7)); outline.addLine(to: CGPoint(x: 30, y: 13))
        outline.move(to: CGPoint(x: 11, y: 18)); outline.addLine(to: CGPoint(x: 13, y: 43))
        outline.addQuadCurve(to: CGPoint(x: 17, y: 47), controlPoint: CGPoint(x: 13, y: 47))
        outline.addLine(to: CGPoint(x: 31, y: 47))
        outline.addQuadCurve(to: CGPoint(x: 35, y: 43), controlPoint: CGPoint(x: 35, y: 47))
        outline.addLine(to: CGPoint(x: 37, y: 18)); outline.stroke()
        let text = String(count) as NSString
        var fontSize: CGFloat = 17
        var font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        while text.size(withAttributes: [.font: font]).width > 24 && fontSize > 5 {
            fontSize -= 0.5; font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        }
        let size = text.size(withAttributes: [.font: font])
        text.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: 32 - size.height / 2), withAttributes: [.font: font, .foregroundColor: UIColor.flowBlue])
    }
}
