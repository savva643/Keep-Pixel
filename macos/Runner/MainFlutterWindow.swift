import Cocoa
import FlutterMacOS
import bitsdojo_window_macos  // ✅ Добавляем поддержку bitsdojo_window

class MainFlutterWindow: BitsdojoWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // ✅ Настройки окна (можно изменить)
    self.title = "Keep Pixel"  // Название окна
    self.styleMask.insert(.titled)  // Разрешить заголовок
    self.styleMask.insert(.fullSizeContentView)  // Убрать стандартные кнопки macOS
    self.titleVisibility = .hidden  // Скрыть заголовок
    self.titlebarAppearsTransparent = true  // Сделать заголовок прозрачным

    // ✅ Делаем окно перетаскиваемым
    let dragArea = NSView(frame: NSMakeRect(0, self.frame.height - 40, self.frame.width, 40))
    dragArea.wantsLayer = true
    dragArea.layer?.backgroundColor = NSColor.clear.cgColor
    self.contentView?.addSubview(dragArea)
    self.isMovableByWindowBackground = true
  }
}
