#include "sub_window.h"

#include <algorithm>

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <dwmapi.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <url_launcher_windows/url_launcher_windows.h>

#pragma comment(lib, "dwmapi.lib")

namespace {

HWND g_main_window = nullptr;

using Channel = flutter::MethodChannel<flutter::EncodableValue>;

int Argument(const flutter::EncodableValue* args, const char* key, int fallback) {
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (!map) return fallback;
  const auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) return fallback;
  const auto* value = std::get_if<int32_t>(&it->second);
  return value ? *value : fallback;
}

// Replaces the system frame with the app's own, keeping Windows 11 rounded
// corners and the shadow, and places the window over the main one.
void MakeFrameless(HWND window, int width, int height) {
  const LONG_PTR visible = GetWindowLongPtr(window, GWL_STYLE) & WS_VISIBLE;
  SetWindowLongPtr(window, GWL_STYLE,
                   WS_POPUP | WS_MINIMIZEBOX | WS_SYSMENU | visible);
  SetWindowTextW(window, L"\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438 Keep Pixel");
  if (g_main_window) {
    SetWindowLongPtr(window, GWLP_HWNDPARENT,
                     reinterpret_cast<LONG_PTR>(g_main_window));
  }
  const int corner = 2;  // DWMWCP_ROUND
  DwmSetWindowAttribute(window, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */, &corner,
                        sizeof(corner));
  const MARGINS shadow{1, 1, 1, 1};
  DwmExtendFrameIntoClientArea(window, &shadow);
  const UINT dpi = GetDpiForWindow(window);
  RECT screen{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &screen, 0);
  const int w = std::min<int>(MulDiv(width, dpi, 96), screen.right - screen.left);
  const int h = std::min<int>(MulDiv(height, dpi, 96), screen.bottom - screen.top);
  RECT area{};
  if (!g_main_window || !GetWindowRect(g_main_window, &area)) {
    area = screen;
  }
  SetWindowPos(window, nullptr, area.left + (area.right - area.left - w) / 2,
               area.top + (area.bottom - area.top - h) / 2, w, h,
               SWP_NOZORDER | SWP_FRAMECHANGED);
}

void OnSubWindowCreated(void* controller_pointer) {
  auto* controller =
      static_cast<flutter::FlutterViewController*>(controller_pointer);
  const HWND view = controller->view()->GetNativeWindow();
  // A new engine has no plugins of its own; links open through this one.
  UrlLauncherWindowsRegisterWithRegistrar(
      controller->engine()->GetRegistrarForPlugin("UrlLauncherWindows"));
  // Lives as long as the process; a closed window simply never calls it again.
  auto* channel = new Channel(controller->engine()->messenger(),
                              "keep_pixel/sub_window",
                              &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([view](const auto& call, auto result) {
    const HWND window = GetAncestor(view, GA_ROOT);
    const auto& method = call.method_name();
    if (method == "frameless") {
      MakeFrameless(window, Argument(call.arguments(), "width", 720),
                    Argument(call.arguments(), "height", 680));
    } else if (method == "drag") {
      ReleaseCapture();
      PostMessage(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
    } else if (method == "minimize") {
      ShowWindow(window, SW_MINIMIZE);
    } else if (method == "focus") {
      if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
      SetForegroundWindow(window);
    } else if (method == "close") {
      PostMessage(window, WM_CLOSE, 0, 0);
    } else {
      result->NotImplemented();
      return;
    }
    result->Success();
  });
}

}  // namespace

void ConfigureSubWindows(HWND main_window) {
  g_main_window = main_window;
  DesktopMultiWindowSetWindowCreatedCallback(OnSubWindowCreated);
}
