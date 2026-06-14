#include "flutter_window.h"

#include <flutter/encodable_value.h>
#include <optional>
#include <flutter/method_channel.h>
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

  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "luxwap/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "setSize") {
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

        HWND handle = GetHandle();
        if (!handle || width <= 0 || height <= 0) {
          result->Error("invalid-argument", "Invalid window size.");
          return;
        }

        int x = 0;
        int y = 0;
        UINT flags = SWP_NOZORDER | SWP_NOACTIVATE;
        if (center) {
          MONITORINFO monitor_info;
          monitor_info.cbSize = sizeof(MONITORINFO);
          HMONITOR monitor = MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST);
          GetMonitorInfo(monitor, &monitor_info);
          const RECT work_area = monitor_info.rcWork;
          x = work_area.left +
              ((work_area.right - work_area.left) - static_cast<int>(width)) / 2;
          y = work_area.top +
              ((work_area.bottom - work_area.top) - static_cast<int>(height)) / 2;
        } else {
          RECT rect;
          GetWindowRect(handle, &rect);
          x = rect.left;
          y = rect.top;
        }

        SetWindowPos(handle, nullptr, x, y, static_cast<int>(width),
                     static_cast<int>(height), flags);
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
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
