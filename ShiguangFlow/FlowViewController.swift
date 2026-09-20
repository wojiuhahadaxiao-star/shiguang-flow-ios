import UIKit
import Photos
import PhotosUI

final class FlowViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
    private let store = PhotoStore()
    private let session = FlowSession(pending: UserDefaults.standard.stringArray(forKey: "flow.pending.v1") ?? [])
    private let flow = CoverFlowLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
    private let dateButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let trashButton = UIButton(type: .system)
    private let trashGraphic = TrashCountView()
    private var edgeReady = false
    private let countLabel = UILabel()
    private let hintLabel = UILabel()
    private let edgeLabel = UILabel()
    private let emptyLabel = UILabel()
    private let permissionButton = UIButton(type: .system)
    private let activity = UIActivityIndicatorView(style: .large)
    private var ids: [String] = []
    private var index = 0
    private var currentID: String? { ids.indices.contains(index) ? ids[index] : nil }
    private var isBusy = false
    private var deferredRefresh = false
    private var loading = false
    private var viewer: PhotoViewer?
    private var deletePan: UIPanGestureRecognizer!
    private var pagingDirection = 0
    private var panID: String?
    private var thumbnailSize: CGSize { CGSize(width: 1100, height: 1100) }
    private var lastBounds: CGSize = .zero
    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日"; return f
    }()
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .flowBackground
        collection.backgroundColor = .clear
        collection.dataSource = self; collection.delegate = self
        collection.register(PhotoCell.self, forCellWithReuseIdentifier: "photo")
        collection.decelerationRate = .fast; collection.alwaysBounceHorizontal = true
        collection.showsHorizontalScrollIndicator = false; collection.clipsToBounds = false
        collection.contentInsetAdjustmentBehavior = .never
        collection.isPrefetchingEnabled = true
        [collection, dateButton, settingsButton, undoButton, trashButton, countLabel, hintLabel, edgeLabel, emptyLabel, permissionButton, activity].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0)
        }
        configureButton(settingsButton, symbol: "gearshape", title: "设置", action: #selector(settings))
        configureButton(undoButton, symbol: "arrow.uturn.backward", title: "撤回", action: #selector(undo))
        trashButton.addTarget(self, action: #selector(basket), for: .touchUpInside)
        trashGraphic.isUserInteractionEnabled = false
        trashGraphic.translatesAutoresizingMaskIntoConstraints = false
        trashButton.addSubview(trashGraphic)
        NSLayoutConstraint.activate([
            trashGraphic.centerXAnchor.constraint(equalTo: trashButton.centerXAnchor),
            trashGraphic.centerYAnchor.constraint(equalTo: trashButton.centerYAnchor),
            trashGraphic.widthAnchor.constraint(equalToConstant: 48),
            trashGraphic.heightAnchor.constraint(equalToConstant: 52)
        ])
        dateButton.contentHorizontalAlignment = .leading; dateButton.tintColor = .flowBlue
        dateButton.addTarget(self, action: #selector(toggleDate), for: .touchUpInside)
        permissionButton.setTitle("允许访问照片", for: .normal); permissionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        permissionButton.addTarget(self, action: #selector(permissionTapped), for: .touchUpInside)
        emptyLabel.numberOfLines = 0; emptyLabel.textAlignment = .center; emptyLabel.textColor = .secondaryLabel
        countLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium); countLabel.textColor = .flowBlue; countLabel.textAlignment = .center
        hintLabel.font = .systemFont(ofSize: 13); hintLabel.textColor = .secondaryLabel; hintLabel.textAlignment = .center
        edgeLabel.font = .systemFont(ofSize: 13, weight: .medium); edgeLabel.textColor = .flowBlue; edgeLabel.textAlignment = .center; edgeLabel.alpha = 0
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            dateButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24), dateButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            dateButton.heightAnchor.constraint(equalToConstant: 60), dateButton.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -8),
            settingsButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20), settingsButton.centerYAnchor.constraint(equalTo: dateButton.centerYAnchor), settingsButton.widthAnchor.constraint(equalToConstant: 48), settingsButton.heightAnchor.constraint(equalToConstant: 48),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor), collection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collection.topAnchor.constraint(equalTo: dateButton.bottomAnchor, constant: 30), collection.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -22),
            countLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor), countLabel.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -12),
            hintLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor), hintLabel.bottomAnchor.constraint(equalTo: undoButton.topAnchor, constant: -20),
            undoButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24), undoButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16), undoButton.widthAnchor.constraint(equalToConstant: 60), undoButton.heightAnchor.constraint(equalToConstant: 56),
            trashButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24), trashButton.bottomAnchor.constraint(equalTo: undoButton.bottomAnchor), trashButton.widthAnchor.constraint(equalToConstant: 60), trashButton.heightAnchor.constraint(equalToConstant: 56),
            edgeLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor), edgeLabel.topAnchor.constraint(equalTo: dateButton.bottomAnchor, constant: 8),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor), emptyLabel.centerYAnchor.constraint(equalTo: collection.centerYAnchor, constant: -30), emptyLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 28), emptyLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -28),
            permissionButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor), permissionButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 16), permissionButton.heightAnchor.constraint(equalToConstant: 48),
            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor), activity.centerYAnchor.constraint(equalTo: collection.centerYAnchor)
        ])
        deletePan = UIPanGestureRecognizer(target: self, action: #selector(deleteDragged(_:)))
        deletePan.maximumNumberOfTouches = 1; deletePan.delegate = self; collection.addGestureRecognizer(deletePan)
        collection.panGestureRecognizer.require(toFail: deletePan)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(openPhoto)); doubleTap.numberOfTapsRequired = 2; collection.addGestureRecognizer(doubleTap)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:))); pinch.delegate = self; collection.addGestureRecognizer(pinch)
        store.onChange = { [weak self] in self?.refresh() }
        NotificationCenter.default.addObserver(self, selector: #selector(active), name: UIApplication.didBecomeActiveNotification, object: nil)
        updateChrome(); refresh()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if collection.bounds.size != lastBounds {
            lastBounds = collection.bounds.size; flow.invalidateLayout(); collection.layoutIfNeeded(); focus(index, animated: false)
        }
    }
    private func configureButton(_ button: UIButton, symbol: String, title: String, action: Selector) {
        var config = UIButton.Configuration.plain(); config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .regular)); config.baseForegroundColor = .flowBlue
        button.configuration = config; button.accessibilityLabel = title; button.addTarget(self, action: action, for: .touchUpInside)
    }
    private func haptic() { if UserDefaults.standard.object(forKey: "flow.haptics") as? Bool != false { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    private var motionDuration: TimeInterval { UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.38 }
    @objc private func active() { refresh() }
    private func refresh() {
        guard isViewLoaded else { return }
        guard !isBusy, viewer == nil, panID == nil, presentedViewController == nil, !collection.isDragging, !collection.isDecelerating else { deferredRefresh = true; return }
        loading = true
        if ids.isEmpty { activity.startAnimating() }; updateChrome()
        let anchor = currentID
        store.load { [weak self] records in
            guard let self else { return }
            self.loading = false; self.activity.stopAnimating()
            guard !self.isBusy, self.viewer == nil, self.panID == nil, self.presentedViewController == nil, !self.collection.isDragging, !self.collection.isDecelerating else { self.deferredRefresh = true; return }
            self.session.update(records); self.persist(); self.render(focus: anchor)
        }
    }
    private func finishInteraction() {
        isBusy = false; collection.isScrollEnabled = true; updateChrome()
        if deferredRefresh { deferredRefresh = false; refresh() }
    }
    private func persist() { UserDefaults.standard.set(session.pending, forKey: "flow.pending.v1") }
    private func render(focus id: String? = nil, fallback: Int = 0) {
        ids = session.visibleIDs; index = id.flatMap { ids.firstIndex(of: $0) } ?? min(fallback, max(0, ids.count - 1))
        collection.reloadData(); collection.layoutIfNeeded(); focus(index, animated: false); updateChrome(); preheat()
    }
    private func focus(_ value: Int, animated: Bool) {
        guard !ids.isEmpty else { collection.contentOffset = .zero; return }
        index = max(0, min(ids.count - 1, value)); collection.setContentOffset(CGPoint(x: CGFloat(index) * flow.pitch, y: 0), animated: animated)
    }
    private func preheat() {
        let start = max(0, index - 3), end = min(ids.count, index + 4)
        if start < end { store.preheat(Array(ids[start..<end]), size: thumbnailSize) }
    }
    private func updateChrome() {
        let photoDate = currentID.flatMap { store.assets[$0]?.creationDate }
        let date: Date? = { if case .day(let day) = session.mode { return photoDate ?? day }; return photoDate }()
        var config = UIButton.Configuration.plain()
        config.title = date.map { formatter.string(from: $0) } ?? "拾光 Flow"
        if case .random = session.mode { config.subtitle = "随机 · 点击日期查看当天" } else { config.subtitle = "当日 · 点击日期回到随机" }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in var out = input; out.font = .systemFont(ofSize: 21, weight: .semibold); return out }
        config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in var out = input; out.font = .systemFont(ofSize: 12); return out }
        config.titleAlignment = .leading; config.contentInsets = .zero; config.baseForegroundColor = .flowBlue; config.titlePadding = 5
        dateButton.configuration = config
        let inDay: Bool = { if case .day = session.mode { return true }; return false }()
        dateButton.isEnabled = !isBusy && (date != nil || inDay)
        countLabel.text = ids.isEmpty ? "0 / 0" : "\(index + 1) / \(ids.count)" + "  ·  第 \(session.groupNumber) 组"
        hintLabel.text = "上滑待删除 · 双击放大 · 拉过边界换组"
        undoButton.isEnabled = session.canUndo && !isBusy
        trashButton.isEnabled = !session.pending.isEmpty && !isBusy
        trashGraphic.count = session.pending.count
        trashButton.accessibilityLabel = "待删除 \(session.pending.count) 张"
        settingsButton.isEnabled = !isBusy
        emptyLabel.isHidden = !ids.isEmpty || loading
        permissionButton.isHidden = !ids.isEmpty || loading
        if !store.isAuthorized {
            emptyLabel.text = "允许访问照片后\n开始浏览你的回忆"
            permissionButton.setTitle(store.authorization == .notDetermined ? "允许访问照片" : "前往设置开启照片权限", for: .normal)
            if store.authorization == .restricted { emptyLabel.text = "照片访问受到系统限制\n请检查屏幕使用时间或设备管理设置" }
        } else {
            emptyLabel.text = inDay ? "当天可浏览的照片已全部标记\n点击日期回到随机，或撤回" : "这一组没有可浏览照片\n可换一组、撤回或检查照片权限"
            permissionButton.setTitle(store.authorization == .limited ? "选择更多照片" : "随机换一组", for: .normal)
        }
    }
    @objc private func permissionTapped() {
        switch store.authorization {
        case .notDetermined: store.authorize { [weak self] in self?.refresh() }
        case .limited: PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
        case .authorized: session.newRandomBatch(); render()
        default: openSettings()
        }
    }
    private func openSettings() { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
    @objc private func toggleDate() {
        guard !isBusy, viewer == nil else { return }
        isBusy = true; collection.isScrollEnabled = false
        collection.setContentOffset(CGPoint(x: CGFloat(index) * flow.pitch, y: 0), animated: false)
        let anchor = session.toggleMode(focused: currentID); haptic()
        UIView.transition(with: collection, duration: motionDuration, options: .transitionCrossDissolve, animations: { self.render(focus: anchor) }) { _ in self.finishInteraction() }
    }
    @objc private func undo() {
        guard !isBusy, let id = session.undo() else { return }
        isBusy = true; collection.isScrollEnabled = false; persist(); haptic(); render(focus: id)
        if let cell = focusedCell() {
            cell.contentView.transform = CGAffineTransform(translationX: 0, y: -90); cell.contentView.alpha = 0
            UIView.animate(withDuration: motionDuration, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0, animations: { cell.contentView.transform = .identity; cell.contentView.alpha = 1 }) { _ in self.finishInteraction() }
        } else { finishInteraction() }
    }
    private func focusedCell() -> PhotoCell? { collection.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoCell }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { ids.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoCell
        let id = ids[indexPath.item]; cell.configure(id: id, store: store, pixels: thumbnailSize)
        cell.accessibilityLabel = "照片 \(indexPath.item + 1)，" + (store.assets[id]?.creationDate.map { formatter.string(from: $0) } ?? "日期未知")
        cell.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "标记删除") { [weak self] _ in
            guard let self, !self.isBusy, let position = self.ids.firstIndex(of: id) else { return false }
            self.focus(position, animated: false); self.collection.layoutIfNeeded(); self.stageFocused(); return true
        }]
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isBusy, viewer == nil else { return }; focus(indexPath.item, animated: true)
    }
    @objc private func accessibilityDelete() -> Bool { stageFocused(); return true }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !ids.isEmpty, !isBusy else { return }
        let next = max(0, min(ids.count - 1, Int((scrollView.contentOffset.x / max(1, flow.pitch)).rounded())))
        if next != index { index = next; updateChrome() }
        let maxX = CGFloat(max(0, ids.count - 1)) * flow.pitch
        let overscroll = scrollView.contentOffset.x < 0 ? -scrollView.contentOffset.x : scrollView.contentOffset.x - maxX
        if overscroll > 12 {
            let canPage = scrollView.contentOffset.x < 0 ? session.hasPrevious : session.hasNext
            let directionName = scrollView.contentOffset.x < 0 ? "上一组" : "下一组"
            let ready = canPage && overscroll >= 64
            if ready && !edgeReady { haptic() }
            edgeReady = ready
            edgeLabel.text = canPage ? (ready ? "松手，切换\(directionName)" : "继续拉出\(directionName)") : "已到边界"
            edgeLabel.transform = CGAffineTransform(scaleX: ready ? 1.06 : 1, y: ready ? 1.06 : 1)
            edgeLabel.alpha = min(1, overscroll / 64)
        } else { edgeLabel.alpha = 0; edgeReady = false; edgeLabel.transform = .identity }
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { pagingDirection = 0; edgeReady = false }
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let maxX = CGFloat(max(0, ids.count - 1)) * flow.pitch
        if scrollView.contentOffset.x < -64 && session.hasPrevious { pagingDirection = -1 }
        else if scrollView.contentOffset.x > maxX + 64 && session.hasNext { pagingDirection = 1 }
        if pagingDirection != 0 { targetContentOffset.pointee.x = max(0, min(maxX, scrollView.contentOffset.x)) }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if pagingDirection != 0 { let direction = pagingDirection; pagingDirection = 0; changePage(direction) }
        else if !decelerate { settled() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { settled() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { settled() }
    private func settled() { preheat(); if deferredRefresh && !isBusy { deferredRefresh = false; refresh() } }
    private func changePage(_ direction: Int) {
        guard !isBusy, session.movePage(direction) else { return }
        isBusy = true; collection.isScrollEnabled = false; haptic(); edgeLabel.alpha = 0; edgeReady = false; updateChrome()
        UIView.animate(withDuration: 0.13, animations: {
            self.collection.transform = CGAffineTransform(translationX: CGFloat(-direction) * 44, y: 0); self.collection.alpha = 0
        }) { _ in
            self.render(fallback: direction > 0 ? 0 : self.session.visibleIDs.count - 1)
            self.collection.transform = CGAffineTransform(translationX: CGFloat(direction) * 100, y: 0)
            UIView.animate(withDuration: self.motionDuration + 0.1, delay: 0, usingSpringWithDamping: 0.69, initialSpringVelocity: 0.6, animations: {
                self.collection.transform = .identity; self.collection.alpha = 1
            }) { _ in self.finishInteraction() }
        }
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isBusy, viewer == nil, currentID != nil, !collection.isDecelerating else { return false }
        if gestureRecognizer === deletePan {
            let velocity = deletePan.velocity(in: collection)
            guard let cell = focusedCell(), cell.frame.contains(deletePan.location(in: collection)) else { return false }
            return velocity.y < 0 && abs(velocity.y) > abs(velocity.x) * 1.2
        }
        return true
    }
    @objc private func deleteDragged(_ gesture: UIPanGestureRecognizer) {
        guard let cell = focusedCell() else { return }
        let distance = max(0, -gesture.translation(in: collection).y)
        switch gesture.state {
        case .began: panID = currentID
        case .changed:
            let scale = max(0.78, 1 - distance / 1200)
            cell.contentView.transform = CGAffineTransform(translationX: 0, y: -distance).scaledBy(x: scale, y: scale)
            cell.contentView.alpha = max(0.1, 1 - distance / 400)
        case .ended:
            if panID == currentID && (distance > 95 || gesture.velocity(in: collection).y < -850) { stageFocused() } else { resetCell(cell) }
            panID = nil; settled()
        case .cancelled, .failed: resetCell(cell); panID = nil; settled()
        default: break
        }
    }
    private func resetCell(_ cell: PhotoCell) {
        UIView.animate(withDuration: motionDuration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) { cell.contentView.transform = .identity; cell.contentView.alpha = 1 }
    }
    private func stageFocused() {
        guard !isBusy, let id = currentID, let cell = focusedCell() else { return }
        isBusy = true; collection.isScrollEnabled = false; updateChrome(); haptic()
        let oldIndex = index
        let oldPage = session.page
        let hasRightNeighbor = ids.indices.contains(index + 1)
        let nextID = ids.indices.contains(index + 1) ? ids[index + 1] : (index > 0 ? ids[index - 1] : nil)
        UIView.animate(withDuration: 0.25, animations: {
            cell.contentView.transform = CGAffineTransform(translationX: 0, y: -self.collection.bounds.height).scaledBy(x: 0.75, y: 0.75)
            cell.contentView.alpha = 0
        }) { _ in
            self.session.stage(id); self.persist()
            let movedToPreviousPage = self.session.page < oldPage
            self.render(focus: nextID, fallback: movedToPreviousPage ? max(0, self.session.visibleIDs.count - 1) : oldIndex)
            guard let incoming = self.focusedCell() else { self.finishInteraction(); return }
            incoming.contentView.transform = CGAffineTransform(translationX: hasRightNeighbor && !movedToPreviousPage ? self.flow.pitch * 0.65 : -self.flow.pitch * 0.65, y: 0).scaledBy(x: 0.86, y: 0.86)
            incoming.contentView.alpha = 0.65
            UIView.animate(withDuration: self.motionDuration, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.3, animations: {
                incoming.contentView.transform = .identity; incoming.contentView.alpha = 1
            }) { _ in self.finishInteraction() }
        }
    }
    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began && gesture.scale >= 1 { openPhoto() }
    }
    @objc private func openPhoto() {
        guard !isBusy, viewer == nil, let id = currentID, let cell = focusedCell(), let image = cell.imageView.image, let asset = store.assets[id] else { return }
        focus(index, animated: false); collection.layoutIfNeeded(); isBusy = true; haptic()
        let origin = cell.imageView.convert(cell.imageView.bounds, to: view)
        let overlay = PhotoViewer(frame: view.bounds, image: image, pixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight))
        viewer = overlay; overlay.imageView.isHidden = true; overlay.alpha = 0; overlay.isUserInteractionEnabled = false; view.addSubview(overlay); overlay.layoutIfNeeded()
        let flying = UIImageView(image: image); flying.contentMode = .scaleAspectFit; flying.frame = origin; flying.clipsToBounds = true; flying.layer.cornerRadius = 14
        view.addSubview(flying); cell.imageView.isHidden = true
        let target = fittedRect(image.size, in: view.bounds)
        UIView.animate(withDuration: motionDuration, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0, animations: {
            flying.frame = target; flying.layer.cornerRadius = 0; overlay.alpha = 1
        }) { _ in
            flying.removeFromSuperview(); overlay.imageView.isHidden = false; overlay.isUserInteractionEnabled = true; overlay.load(id: id, store: self.store)
        }
        overlay.onClose = { [weak self, weak overlay] photo, from in
            guard let self, let overlay else { return }
            overlay.isUserInteractionEnabled = false
            let flying = UIImageView(image: photo); flying.contentMode = .scaleAspectFit; flying.clipsToBounds = true; flying.frame = from; self.view.addSubview(flying)
            overlay.imageView.isHidden = true
            var destination = origin
            if let destinationCell = self.focusedCell() { destination = destinationCell.imageView.convert(destinationCell.imageView.bounds, to: self.view) }
            UIView.animate(withDuration: self.motionDuration, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0, animations: {
                flying.frame = destination; flying.layer.cornerRadius = 14; overlay.alpha = 0
            }) { _ in
                flying.removeFromSuperview(); overlay.removeFromSuperview(); self.focusedCell()?.imageView.isHidden = false
                self.viewer = nil; self.haptic(); self.finishInteraction()
            }
        }
    }
    @objc private func settings() {
        guard !isBusy else { return }
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
        let sheet = UIAlertController(title: "拾光 Flow", message: "独立新版 · v1.1.0 (\(buildNumber))", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "随机换一组", style: .default) { _ in self.session.newRandomBatch(); self.render() })
        if store.authorization == .notDetermined { sheet.addAction(UIAlertAction(title: "允许访问照片", style: .default) { _ in self.store.authorize { self.refresh() } }) }
        if store.authorization == .limited { sheet.addAction(UIAlertAction(title: "管理可访问的照片", style: .default) { _ in PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) }) }
        sheet.addAction(UIAlertAction(title: "系统照片权限设置", style: .default) { _ in self.openSettings() })
        let enabled = UserDefaults.standard.object(forKey: "flow.haptics") as? Bool != false
        sheet.addAction(UIAlertAction(title: enabled ? "关闭触感反馈" : "开启触感反馈", style: .default) { _ in UserDefaults.standard.set(!enabled, forKey: "flow.haptics") })
        sheet.addAction(UIAlertAction(title: "操作说明", style: .default) { _ in
            self.message("操作说明", "左右滑动浏览；上滑放入待删除；双击或双指展开进入大图。\n\n大图支持双指缩放，捏回适屏后下滑返回。\n\n点击日期切换随机 / 当日。两种模式都可在最右端继续左拉换下一组，在最左端继续右拉回上一组，每组最多 25 张。\n\n左下角撤回，右下角回看待删。实删需两次确认及系统授权。Live Photo 当前显示静态照片。")
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in self.settled() })
        sheet.popoverPresentationController?.sourceView = settingsButton; sheet.popoverPresentationController?.sourceRect = settingsButton.bounds
        present(sheet, animated: true)
    }
    @objc private func basket() {
        guard !isBusy, !session.pending.isEmpty else { return }
        let basket = BasketViewController(store: store, ids: session.pending)
        basket.onRestore = { [weak self] id in guard let self else { return }; self.session.restore(id); self.persist(); self.render(focus: self.currentID) }
        basket.onRestoreAll = { [weak self] in guard let self else { return }; self.session.restoreAll(); self.persist(); self.render(focus: self.currentID) }
        basket.onDelete = { [weak self, weak basket] in
            guard let self, let basket else { return }
            self.confirmDelete(from: basket)
        }
        basket.onDismiss = { [weak self] in self?.refresh() }
        let nav = UINavigationController(rootViewController: basket); nav.modalPresentationStyle = .fullScreen; present(nav, animated: true)
    }
    private func confirmDelete(from basket: BasketViewController) {
        let ids = session.pending; guard !ids.isEmpty else { return }
        let first = UIAlertController(title: "确认删除 \(ids.count) 张照片？", message: "现在仍可取消，回看或撤回这些照片。", preferredStyle: .alert)
        first.addAction(UIAlertAction(title: "再检查一下", style: .cancel))
        first.addAction(UIAlertAction(title: "继续", style: .destructive) { _ in
            let second = UIAlertController(title: "再次确认删除", message: "即将从系统相册删除这 \(ids.count) 张照片。提交成功后，App 内的撤回不再适用；可到系统相册“最近删除”中恢复。", preferredStyle: .alert)
            second.addAction(UIAlertAction(title: "取消，保留照片", style: .cancel))
            second.addAction(UIAlertAction(title: "确认从相册删除", style: .destructive) { _ in
                basket.setDeleting(true); self.isBusy = true
                self.store.delete(ids) { success, error in
                    basket.setDeleting(false); self.isBusy = false
                    if success {
                        self.session.committed(ids); self.persist(); basket.reload(ids: self.session.pending); self.render()
                        self.deferredRefresh = true
                    } else {
                        let alert = UIAlertController(title: "未删除照片", message: error ?? "系统取消了删除，待删除列表已保留。", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "知道了", style: .default)); basket.present(alert, animated: true)
                    }
                }
            })
            basket.present(second, animated: true)
        })
        basket.present(first, animated: true)
    }
    private func message(_ title: String, _ body: String) {
        let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default) { _ in self.settled() }); present(alert, animated: true)
    }
}
