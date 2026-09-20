import UIKit
import Photos

/// Full-screen child uses UIScrollView for Photos-like pinch, pan and elastic limits.
final class PhotoViewer: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let scroll = UIScrollView()
    let imageView = UIImageView()
    private let backdrop = UIView()
    private let closeButton = UIButton(type: .system)
    private let status = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var request: PHImageRequestID?
    private weak var store: PhotoStore?
    private var dismissPan: UIPanGestureRecognizer!
    private var fittedSize: CGSize = .zero
    private var isDismissing = false
    var onClose: ((UIImage?, CGRect) -> Void)?
    var onClosed: (() -> Void)?
    private var photoSize: CGSize
    init(frame: CGRect, image: UIImage?, pixelSize: CGSize) {
        photoSize = pixelSize
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
        backdrop.backgroundColor = .black; addSubview(backdrop)
        addSubview(scroll); scroll.addSubview(imageView)
        scroll.delegate = self; scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 6
        scroll.bouncesZoom = true; scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        imageView.image = image; imageView.contentMode = .scaleAspectFit
        closeButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        closeButton.tintColor = .white; closeButton.accessibilityLabel = "返回浏览"
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside); addSubview(closeButton)
        status.font = .systemFont(ofSize: 13); status.textColor = .white; status.textAlignment = .center; status.numberOfLines = 2
        addSubview(status); spinner.color = .white; addSubview(spinner)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:))); doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        dismissPan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        dismissPan.delegate = self; dismissPan.maximumNumberOfTouches = 1; addGestureRecognizer(dismissPan)
        scroll.panGestureRecognizer.require(toFail: dismissPan)
        accessibilityViewIsModal = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { if let request { store?.manager.cancelImageRequest(request) } }
    override func layoutSubviews() {
        super.layoutSubviews(); backdrop.frame = bounds; scroll.frame = bounds
        closeButton.frame = CGRect(x: 18, y: safeAreaInsets.top + 8, width: 48, height: 48)
        status.frame = CGRect(x: 24, y: bounds.height - safeAreaInsets.bottom - 65, width: bounds.width - 48, height: 45)
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let newSize = fittedRect(photoSize, in: bounds).size
        if newSize != fittedSize {
            scroll.setZoomScale(1, animated: false); fittedSize = newSize
            imageView.frame = CGRect(origin: .zero, size: newSize); scroll.contentSize = newSize
        }
        centerImage()
    }
    func load(id: String, store: PhotoStore) {
        self.store = store; spinner.startAnimating(); status.text = "正在加载清晰照片…"
        // Original aspect ratio at full screen, with up to 6K detail for zoom.
        let factor = min(1, 6000 / max(1, max(photoSize.width, photoSize.height)))
        let pixels = CGSize(width: photoSize.width * factor, height: photoSize.height * factor)
        request = store.image(for: id, pixels: pixels, highQuality: true) { [weak self] image, final, error in
            guard let self, !self.isDismissing else { return }
            if let image { self.imageView.image = image }
            if final {
                self.spinner.stopAnimating()
                self.status.text = image == nil ? "高清照片加载失败，可返回重试" : nil
            }
        }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }
    private func centerImage() {
        scroll.contentInset = UIEdgeInsets(top: max(0, (scroll.bounds.height - scroll.contentSize.height) / 2), left: max(0, (scroll.bounds.width - scroll.contentSize.width) / 2), bottom: 0, right: 0)
    }
    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: true); return }
        let point = gesture.location(in: imageView), scale: CGFloat = 2.5
        let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
        scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan else { return true }
        let velocity = dismissPan.velocity(in: self)
        return scroll.zoomScale <= 1.01 && velocity.y > 0 && abs(velocity.y) > abs(velocity.x) * 1.2 && !isDismissing
    }
    @objc private func dragged(_ gesture: UIPanGestureRecognizer) {
        let y = max(0, gesture.translation(in: self).y)
        switch gesture.state {
        case .changed:
            scroll.transform = CGAffineTransform(translationX: gesture.translation(in: self).x * 0.3, y: y)
            backdrop.alpha = max(0.25, 1 - y / 500); closeButton.alpha = backdrop.alpha
        case .ended:
            if y > 110 || gesture.velocity(in: self).y > 800 { close() } else { restore() }
        case .cancelled, .failed: restore()
        default: break
        }
    }
    private func restore() {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.84, initialSpringVelocity: 0) {
            self.scroll.transform = .identity; self.backdrop.alpha = 1; self.closeButton.alpha = 1
        }
    }
    @objc private func close() {
        guard !isDismissing else { return }; isDismissing = true
        if let request { store?.manager.cancelImageRequest(request) }
        onClose?(imageView.image, imageView.convert(imageView.bounds, to: superview))
    }
    override func accessibilityPerformEscape() -> Bool { close(); return true }
}
