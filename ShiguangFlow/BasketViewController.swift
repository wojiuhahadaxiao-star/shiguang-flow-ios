import UIKit

final class BasketViewController: UITableViewController {
    private let store: PhotoStore
    private var ids: [String]
    private var deleting = false
    private var preview: PhotoViewer?
    var onRestore: ((String) -> Void)?
    var onRestoreAll: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?
    init(store: PhotoStore, ids: [String]) { self.store = store; self.ids = ids; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); tableView.backgroundColor = .flowBackground; tableView.rowHeight = 86
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "返回", style: .plain, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "删除…", style: .plain, target: self, action: #selector(deleteTapped))
        navigationController?.navigationBar.tintColor = .flowBlue
        reload(ids: ids)
    }
    func reload(ids: [String]) {
        self.ids = ids; title = "待删除 · \(ids.count) 张"; tableView.reloadData()
        navigationItem.rightBarButtonItem?.isEnabled = !ids.isEmpty && !deleting
    }
    func setDeleting(_ value: Bool) {
        deleting = value; tableView.isUserInteractionEnabled = !value
        navigationItem.leftBarButtonItem?.isEnabled = !value; navigationItem.rightBarButtonItem?.isEnabled = !value && !ids.isEmpty
        title = value ? "正在提交系统删除…" : "待删除 · \(ids.count) 张"
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : ids.count }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "点击照片查看大图；向左滑动单行可撤回。上滑标记还没有删除系统相册中的照片。" : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = ids.isEmpty ? "暂无待删除照片" : "全部撤回"
            cell.textLabel?.textColor = .flowBlue; return cell
        }
        let id = ids[indexPath.row], asset = store.assets[id]
        cell.textLabel?.text = asset?.creationDate.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "日期未知"
        cell.detailTextLabel?.text = "点击回看 · 左滑撤回"
        cell.imageView?.image = UIImage(systemName: "photo"); cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.tintColor = .flowBlue
        store.image(for: id, pixels: CGSize(width: 150, height: 150)) { [weak cell] image, _, _ in
            guard let image else { return }; cell?.imageView?.image = image; cell?.setNeedsLayout()
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, !deleting else { return nil }
        let action = UIContextualAction(style: .normal, title: "撤回") { [weak self] _, _, done in
            guard let self else { done(false); return }; let id = self.ids[indexPath.row]
            self.onRestore?(id); self.ids.remove(at: indexPath.row); self.reload(ids: self.ids); done(true)
        }
        action.backgroundColor = .flowBlue; return UISwipeActionsConfiguration(actions: [action])
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true); guard !deleting else { return }
        if indexPath.section == 0 { onRestoreAll?(); reload(ids: []); return }
        let id = ids[indexPath.row]; guard let asset = store.assets[id], let container = navigationController?.view else { return }
        let viewer = PhotoViewer(frame: container.bounds, image: tableView.cellForRow(at: indexPath)?.imageView?.image, pixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight))
        preview = viewer; container.addSubview(viewer); viewer.layoutIfNeeded(); viewer.load(id: id, store: store)
        viewer.onClose = { [weak self, weak viewer] _, _ in viewer?.removeFromSuperview(); self?.preview = nil }
    }
    @objc private func deleteTapped() { if !deleting { onDelete?() } }
    @objc private func close() { let callback = onDismiss; dismiss(animated: true) { callback?() } }
}
