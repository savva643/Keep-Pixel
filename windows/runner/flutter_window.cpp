#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  overlay_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "keep_pixel/game_overlay",
      &flutter::StandardMethodCodec::GetInstance());
  overlay_ = std::make_unique<GameOverlay>(GetHandle(),
      [this](bool visible, int64_t game) {
        overlay_channel_->InvokeMethod("changed", std::make_unique<flutter::EncodableValue>(
            flutter::EncodableMap{{flutter::EncodableValue("visible"), flutter::EncodableValue(visible)},
                                  {flutter::EncodableValue("game_id"), flutter::EncodableValue(game)}}));
      }, [this]() { overlay_channel_->InvokeMethod("hotkeyError", nullptr); });
  overlay_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("invalid_arguments", "SDK arguments required"); return; }
    auto integer = [args](const char* key) -> int64_t {
      const auto it = args->find(flutter::EncodableValue(key));
      if (it == args->end()) return 0;
      if (const auto* n = std::get_if<int32_t>(&it->second)) return *n;
      if (const auto* n = std::get_if<int64_t>(&it->second)) return *n;
      return 0;
    };
    const auto game = integer("game_id");
    if (game <= 0) { result->Error("invalid_game", "Game ID required"); return; }
    if (call.method_name() == "register") {
      const auto pid = integer("pid");
      if (pid <= 0 || pid > MAXDWORD) { result->Error("invalid_pid", "PID required"); return; }
      overlay_->Register(game, static_cast<DWORD>(pid));
    } else if (call.method_name() == "unregister") {
      overlay_->Unregister(game);
    } else if (call.method_name() == "setVisible") {
      const auto it = args->find(flutter::EncodableValue("visible"));
      const bool* visible = it == args->end() ? nullptr : std::get_if<bool>(&it->second);
      if (!visible || !overlay_->SetVisible(game, *visible)) {
        result->Error("game_not_foreground", "Focus the running game before opening the panel"); return;
      }
    } else { result->NotImplemented(); return; }
    result->Success();
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  overlay_.reset();
  overlay_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (overlay_ && message == WM_TIMER && wparam == GameOverlay::kTimer) {
    overlay_->Tick(); return 0;
  }
  if (overlay_ && message == WM_HOTKEY && wparam == GameOverlay::kHotkey) {
    overlay_->Hotkey(); return 0;
  }
  if (overlay_ && message == WM_CLOSE && overlay_->visible()) {
    overlay_->Close(); return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
