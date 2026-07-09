#include "flutter_window.h"

#include <imm.h>

#include <optional>

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  RegisterImeChannel();

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
  SetImeEnabled(true);
  ime_channel_ = nullptr;
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

void FlutterWindow::RegisterImeChannel() {
  ime_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "unreal_blueprint_bridge/ime",
      &flutter::StandardMethodCodec::GetInstance());
  ime_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "setEnabled") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("bad-arguments", "setEnabled expects a bool.");
            return;
          }
          SetImeEnabled(*enabled);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::SetImeEnabled(bool enabled) {
  if (!flutter_controller_ || !flutter_controller_->view()) {
    ime_enabled_ = enabled;
    return;
  }
  if (ime_enabled_ == enabled) {
    return;
  }

  const HWND flutter_view_window =
      flutter_controller_->view()->GetNativeWindow();
  const HWND host_window = GetHandle();
  if (enabled) {
    ImmAssociateContext(flutter_view_window, original_ime_context_);
    if (host_window != nullptr) {
      ImmAssociateContext(host_window, original_ime_context_);
    }
  } else {
    if (original_ime_context_ == nullptr) {
      original_ime_context_ = ImmAssociateContext(flutter_view_window, nullptr);
    } else {
      ImmAssociateContext(flutter_view_window, nullptr);
    }
    if (host_window != nullptr) {
      ImmAssociateContext(host_window, nullptr);
    }
  }
  ime_enabled_ = enabled;
}
