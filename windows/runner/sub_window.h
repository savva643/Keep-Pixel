#ifndef RUNNER_SUB_WINDOW_H_
#define RUNNER_SUB_WINDOW_H_

#include <windows.h>

// Secondary windows (settings) get the app's own frame instead of the system one.
void ConfigureSubWindows(HWND main_window);

#endif  // RUNNER_SUB_WINDOW_H_
