import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = FlowViewController()
        window.makeKeyAndVisible(); self.window = window
        return true
    }
}

extension UIColor {
    static let flowBlue = UIColor(red: 0.24, green: 0.48, blue: 0.70, alpha: 1)
    static let flowBackground = UIColor(red: 0.91, green: 0.96, blue: 0.99, alpha: 1)
}

func fittedRect(_ size: CGSize, in bounds: CGRect) -> CGRect {
    guard size.width > 0, size.height > 0 else { return bounds }
    let scale = min(bounds.width / size.width, bounds.height / size.height)
    let result = CGSize(width: size.width * scale, height: size.height * scale)
    return CGRect(x: bounds.midX - result.width / 2, y: bounds.midY - result.height / 2, width: result.width, height: result.height)
}
