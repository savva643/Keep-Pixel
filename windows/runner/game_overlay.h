#ifndef RUNNER_GAME_OVERLAY_H_
#define RUNNER_GAME_OVERLAY_H_
#include <windows.h>
#include <cstdint>
#include <functional>
#include <map>

// A cooperative launcher window above a borderless/windowed game; no injection.
class GameOverlay {
 public:
  static constexpr UINT_PTR kTimer = 0x4B50;
  static constexpr int kHotkey = 0x4B51;
  GameOverlay(HWND host, std::function<void(bool, int64_t)> changed,
              std::function<void()> hotkey_error);
  ~GameOverlay();
  void Register(int64_t game, DWORD pid);
  void Unregister(int64_t game);
  bool SetVisible(int64_t game, bool visible);
  void Tick();
  void Hotkey();
  void Close() { Hide(OwnsForeground()); }
  bool visible() const { return visible_; }
 private:
  int64_t ForegroundGame() const;
  bool OwnsForeground() const;
  void Hide(bool return_focus);
  HWND host_, previous_game_ = nullptr;
  WINDOWPLACEMENT saved_{};
  LONG_PTR style_ = 0, ex_style_ = 0;
  bool visible_ = false, hotkey_ = false, was_visible_ = true, hotkey_warned_ = false;
  int64_t game_ = 0;
  std::map<int64_t, DWORD> games_;
  std::function<void(bool, int64_t)> changed_;
  std::function<void()> hotkey_error_;
};
#endif
