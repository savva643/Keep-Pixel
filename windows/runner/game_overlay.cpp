#include "game_overlay.h"
#include <algorithm>
#include <utility>

GameOverlay::GameOverlay(HWND host, std::function<void(bool, int64_t)> changed,
                         std::function<void()> hotkey_error)
    : host_(host), changed_(std::move(changed)), hotkey_error_(std::move(hotkey_error)) { saved_.length = sizeof(WINDOWPLACEMENT); }
GameOverlay::~GameOverlay() {
  Hide(false);
  KillTimer(host_, kTimer);
  if (hotkey_) UnregisterHotKey(host_, kHotkey);
}
void GameOverlay::Register(int64_t game, DWORD pid) {
  games_[game] = pid;
  SetTimer(host_, kTimer, 100, nullptr);
  Tick();
}
void GameOverlay::Unregister(int64_t game) {
  if (visible_ && game_ == game) Hide(false);
  games_.erase(game);
  if (games_.empty()) KillTimer(host_, kTimer);
  Tick();
}
bool GameOverlay::OwnsForeground() const {
  return GetAncestor(GetForegroundWindow(), GA_ROOT) == host_;
}
int64_t GameOverlay::ForegroundGame() const {
  DWORD pid = 0;
  GetWindowThreadProcessId(GetForegroundWindow(), &pid);
  for (const auto& entry : games_) if (entry.second == pid) return entry.first;
  return 0;
}
void GameOverlay::Tick() {
  if (visible_ && !OwnsForeground()) Hide(false);
  const bool needed = (visible_ && OwnsForeground()) || ForegroundGame() != 0;
  if (needed && !hotkey_) {
    hotkey_ = RegisterHotKey(host_, kHotkey, MOD_SHIFT | MOD_NOREPEAT, VK_TAB) != FALSE;
    if (!hotkey_ && !hotkey_warned_) { hotkey_warned_ = true; hotkey_error_(); }
  } else if (!needed && hotkey_) {
    UnregisterHotKey(host_, kHotkey);
    hotkey_ = false;
  }
  if (!needed) hotkey_warned_ = false;
}
void GameOverlay::Hotkey() {
  if (visible_ && OwnsForeground()) { Hide(true); return; }
  const auto game = ForegroundGame();
  if (game != 0) SetVisible(game, true);
}
bool GameOverlay::SetVisible(int64_t game, bool visible) {
  if (!visible) {
    if (visible_ && game_ == game) Hide(OwnsForeground());
    return true;
  }
  if (visible_) return game_ == game;
  if (games_.find(game) == games_.end() || ForegroundGame() != game) return false;
  previous_game_ = GetForegroundWindow();
  GetWindowPlacement(host_, &saved_);
  style_ = GetWindowLongPtr(host_, GWL_STYLE);
  ex_style_ = GetWindowLongPtr(host_, GWL_EXSTYLE);
  was_visible_ = IsWindowVisible(host_) != FALSE;
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(MonitorFromWindow(previous_game_, MONITOR_DEFAULTTONEAREST), &monitor);
  const int width = std::min(1120L, monitor.rcWork.right - monitor.rcWork.left);
  const int height = std::min(780L, monitor.rcWork.bottom - monitor.rcWork.top);
  SetWindowLongPtr(host_, GWL_STYLE, (style_ & ~(WS_CAPTION | WS_THICKFRAME)) | WS_POPUP);
  SetWindowLongPtr(host_, GWL_EXSTYLE, (ex_style_ & ~WS_EX_APPWINDOW) | WS_EX_TOOLWINDOW);
  visible_ = true;
  game_ = game;
  changed_(true, game);
  ShowWindow(host_, SW_RESTORE);
  SetWindowPos(host_, HWND_TOPMOST,
      monitor.rcWork.left + (monitor.rcWork.right - monitor.rcWork.left - width) / 2,
      monitor.rcWork.top + (monitor.rcWork.bottom - monitor.rcWork.top - height) / 2,
      width, height, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  if (!SetForegroundWindow(host_) && !OwnsForeground()) { Hide(false); return false; }
  return true;
}
void GameOverlay::Hide(bool return_focus) {
  if (!visible_) return;
  visible_ = false;
  SetWindowLongPtr(host_, GWL_STYLE, style_);
  SetWindowLongPtr(host_, GWL_EXSTYLE, ex_style_);
  SetWindowPos(host_, (ex_style_ & WS_EX_TOPMOST) ? HWND_TOPMOST : HWND_NOTOPMOST,
               0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  SetWindowPlacement(host_, &saved_);
  if (!was_visible_) ShowWindow(host_, SW_HIDE);
  changed_(false, game_);
  game_ = 0;
  if (return_focus && IsWindow(previous_game_)) SetForegroundWindow(previous_game_);
  previous_game_ = nullptr;
}
