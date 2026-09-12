#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <optional>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

namespace {
constexpr UINT WM_APP_TRAY = WM_APP + 101;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "luxwap/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto& method = call.method_name();
        HWND handle = GetHandle();

        if (method == "cleanProxy") {
          CleanSystemProxy();
          result->Success();
          return;
        }

        if (method == "killCore") {
          KillCoreProcesses();
          result->Success();
          return;
        }

        if (method == "setTunNodeRoute") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("nodeIp"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<std::string>(&it->second)) {
                Win32Window::SetTunNodeRoute(*val);
              }
            }
          }
          result->Success();
          return;
        }

        if (method == "cleanTunNodeRoute") {
          Win32Window::CleanTunNodeRoute();
          result->Success();
          return;
        }

        if (method == "setCloseToTray") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("enabled"));
            if (it != args->end()) {
              if (const auto* val = std::get_if<bool>(&it->second)) {
                SetCloseToTray(*val);
              }
            }
          }
          result->Success();
          return;
        }

        if (method == "show") {
          if (handle) {
            ShowWindow(handle, SW_SHOW);
            SetForegroundWindow(handle);
          }
          result->Success();
          return;
        }

        if (method == "hide") {
          if (handle) {
            ShowWindow(handle, SW_HIDE);
          }
          result->Success();
          return;
        }

        if (method != "setSize" && method != "setWindowSize") {
          result->NotImplemented();
          return;
        }

        double width = 0;
        double height = 0;
        bool center = false;
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args) {
          auto read_number = [args](const char* key) -> double {
            auto it = args->find(flutter::EncodableValue(key));
            if (it == args->end()) {
              return 0;
            }
            if (const auto* value = std::get_if<int>(&it->second)) {
              return static_cast<double>(*value);
            }
            if (const auto* value = std::get_if<long long>(&it->second)) {
              return static_cast<double>(*value);
            }
            if (const auto* value = std::get_if<double>(&it->second)) {
              return *value;
            }
            return 0;
          };
          width = read_number("width");
          height = read_number("height");
          auto center_it = args->find(flutter::EncodableValue("center"));
          if (center_it != args->end()) {
            if (const auto* value = std::get_if<bool>(&center_it->second)) {
              center = *value;
            }
          }
        }

        if (!handle || width <= 0 || height <= 0) {
          result->Error("invalid-argument", "Invalid window size.");
          return;
        }

        // DPI Scaling calculation
        HMONITOR monitor = MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST);
        UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
        double scale_factor = (dpi > 0) ? (dpi / 96.0) : 1.0;

        int client_w = static_cast<int>(width * scale_factor);
        int client_h = static_cast<int>(height * scale_factor);

        DWORD style = static_cast<DWORD>(GetWindowLong(handle, GWL_STYLE));
        DWORD ex_style =
            static_cast<DWORD>(GetWindowLong(handle, GWL_EXSTYLE));
        RECT rect = {0, 0, client_w, client_h};
        AdjustWindowRectEx(&rect, style, FALSE, ex_style);
        int outer_w = rect.right - rect.left;
        int outer_h = rect.bottom - rect.top;

        int x = 0;
        int y = 0;
        UINT flags = SWP_NOZORDER | SWP_NOACTIVATE;
        if (center) {
          MONITORINFO monitor_info;
          monitor_info.cbSize = sizeof(MONITORINFO);
          GetMonitorInfo(monitor, &monitor_info);
          const RECT work_area = monitor_info.rcWork;
          x = work_area.left +
              ((work_area.right - work_area.left) - outer_w) / 2;
          y = work_area.top +
              ((work_area.bottom - work_area.top) - outer_h) / 2;
        } else {
          RECT cur_rect;
          GetWindowRect(handle, &cur_rect);
          x = cur_rect.left;
          y = cur_rect.top;
        }

        SetWindowPos(handle, nullptr, x, y, outer_w, outer_h, flags);
        result->Success();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  InitTray();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTray();
  CleanSystemProxy();
  CleanTunNodeRoute();
  KillCoreProcesses();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::InitTray() {
  if (tray_initialized_) return;
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  tray_data_.cbSize = sizeof(NOTIFYICONDATAW);
  tray_data_.hWnd = hwnd;
  tray_data_.uID = 1001;
  tray_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  tray_data_.uCallbackMessage = WM_APP_TRAY;
  tray_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray_data_.szTip, L"Luxwap");
  Shell_NotifyIconW(NIM_ADD, &tray_data_);
  tray_initialized_ = true;
}

void FlutterWindow::RemoveTray() {
  if (tray_initialized_) {
    Shell_NotifyIconW(NIM_DELETE, &tray_data_);
    tray_initialized_ = false;
  }
}

void FlutterWindow::HandleTrayMenu(HWND hwnd) {
  HMENU hMenu = CreatePopupMenu();
  AppendMenuW(hMenu, MF_STRING, 1, L"主界面");
  AppendMenuW(hMenu, MF_STRING, 2, L"线路选择");
  AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(hMenu, MF_STRING, 3, L"切换代理状态");

  HMENU hSub = CreatePopupMenu();
  AppendMenuW(hSub, MF_STRING | (GetCloseToTray() ? MF_CHECKED : MF_UNCHECKED),
              41, L"最小化到托盘");
  AppendMenuW(hSub, MF_STRING | (!GetCloseToTray() ? MF_CHECKED : MF_UNCHECKED),
              42, L"直接关闭");
  AppendMenuW(hMenu, MF_POPUP, (UINT_PTR)hSub, L"关闭按钮选项");

  AppendMenuW(hMenu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(hMenu, MF_STRING, 5, L"退出");

  POINT pt;
  GetCursorPos(&pt);
  SetForegroundWindow(hwnd);
  int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY, pt.x, pt.y, 0,
                           hwnd, nullptr);
  DestroyMenu(hMenu);

  if (cmd == 1) {
    ShowWindow(hwnd, SW_SHOW);
    SetForegroundWindow(hwnd);
    if (window_channel_) {
      window_channel_->InvokeMethod("onTrayAction",
                                    std::make_unique<flutter::EncodableValue>("showMain"));
    }
  } else if (cmd == 2) {
    ShowWindow(hwnd, SW_SHOW);
    SetForegroundWindow(hwnd);
    if (window_channel_) {
      window_channel_->InvokeMethod("onTrayAction",
                                    std::make_unique<flutter::EncodableValue>("showLines"));
    }
  } else if (cmd == 3) {
    if (window_channel_) {
      window_channel_->InvokeMethod("onTrayAction",
                                    std::make_unique<flutter::EncodableValue>("toggleProxy"));
    }
  } else if (cmd == 41) {
    SetCloseToTray(true);
    if (window_channel_) {
      window_channel_->InvokeMethod(
          "onTrayAction", std::make_unique<flutter::EncodableValue>("closeToTray_true"));
    }
  } else if (cmd == 42) {
    SetCloseToTray(false);
    if (window_channel_) {
      window_channel_->InvokeMethod(
          "onTrayAction", std::make_unique<flutter::EncodableValue>("closeToTray_false"));
    }
  } else if (cmd == 5) {
    CleanSystemProxy();
    CleanTunNodeRoute();
    KillCoreProcesses();
    RemoveTray();
    DestroyWindow(hwnd);
    PostQuitMessage(0);
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_APP_TRAY) {
    if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
      ShowWindow(hwnd, SW_SHOW);
      SetForegroundWindow(hwnd);
      return 0;
    }
    if (lparam == WM_RBUTTONUP) {
      HandleTrayMenu(hwnd);
      return 0;
    }
  }

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

