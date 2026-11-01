#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <windows.h>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char kChannelName[] = "convert/desktop";

// لون شريط العنوان (ويندوز 11). نُعرّفه يدويًا كي يُبنى المشروع أيضًا
// على إصدارات Windows SDK الأقدم.
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

// يحوّل مسار نظام ويندوز (UTF-16) إلى UTF-8 كي يصل سليمًا إلى Dart،
// فلا تُفسد أسماء الملفات العربية ولا المسافات.
std::string Utf16ToUtf8(const std::wstring& text) {
  if (text.empty()) return std::string();
  int size = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                                   static_cast<int>(text.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string out(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                        static_cast<int>(text.size()), out.data(), size,
                        nullptr, nullptr);
  return out;
}

std::wstring Utf8ToUtf16(const std::string& text) {
  if (text.empty()) return std::wstring();
  int size = ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(),
                                   static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                        out.data(), size);
  return out;
}

// نافذة اختيار مجلد أصلية بواجهة ويندوز الحديثة.
std::optional<std::wstring> PickFolder(const std::wstring& title) {
  IFileOpenDialog* dialog = nullptr;
  HRESULT hr = ::CoCreateInstance(
      CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
      __uuidof(IFileOpenDialog), reinterpret_cast<void**>(&dialog));
  if (FAILED(hr) || dialog == nullptr) return std::nullopt;

  DWORD options = 0;
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM |
                     FOS_PATHMUSTEXIST);
  dialog->SetTitle(title.c_str());

  std::optional<std::wstring> result;
  hr = dialog->Show(nullptr);
  if (SUCCEEDED(hr)) {
    IShellItem* item = nullptr;
    if (SUCCEEDED(dialog->GetResult(&item)) && item != nullptr) {
      PWSTR path = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) &&
          path != nullptr) {
        result = std::wstring(path);
        ::CoTaskMemFree(path);
      }
      item->Release();
    }
  }
  dialog->Release();
  return result;
}

}  // namespace

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

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

        auto read_string = [&args](const char* key) -> std::string {
          if (args == nullptr) return std::string();
          auto it = args->find(flutter::EncodableValue(key));
          if (it == args->end()) return std::string();
          if (const auto* v = std::get_if<std::string>(&it->second)) {
            return *v;
          }
          return std::string();
        };

        if (method == "setCaptionColor") {
          int r = 0, g = 0, b = 0;
          auto read_int = [&args](const char* key, int& target) {
            if (args == nullptr) return;
            auto it = args->find(flutter::EncodableValue(key));
            if (it == args->end()) return;
            if (const auto* v = std::get_if<int32_t>(&it->second)) {
              target = *v;
            }
          };
          read_int("r", r);
          read_int("g", g);
          read_int("b", b);
          COLORREF color = RGB(r, g, b);
          ::DwmSetWindowAttribute(GetHandle(),
                                  static_cast<DWORD>(DWMWA_CAPTION_COLOR),
                                  &color, sizeof(color));
          BOOL dark = r + g + b < 384;
          ::DwmSetWindowAttribute(GetHandle(),
                                  static_cast<DWORD>(DWMWA_USE_IMMERSIVE_DARK_MODE),
                                  &dark, sizeof(dark));
          result->Success();
          return;
        }

        if (method == "openPath" || method == "revealPath") {
          std::wstring path = Utf8ToUtf16(read_string("path"));
          if (path.empty()) {
            result->Error("bad_args", "path is required");
            return;
          }
          HINSTANCE outcome;
          if (method == "openPath") {
            outcome = ::ShellExecuteW(nullptr, L"open", path.c_str(), nullptr,
                                      nullptr, SW_SHOWNORMAL);
          } else {
            std::wstring args = L"/select,\"" + path + L"\"";
            outcome = ::ShellExecuteW(nullptr, L"open", L"explorer.exe",
                                      args.c_str(), nullptr, SW_SHOWNORMAL);
          }
          result->Success(flutter::EncodableValue(
              static_cast<int64_t>(reinterpret_cast<intptr_t>(outcome))));
          return;
        }

        if (method == "pickFolder") {
          std::wstring title = Utf8ToUtf16(read_string("title"));
          if (title.empty()) title = L"اختر مجلد النتائج";
          auto picked = PickFolder(title);
          if (!picked.has_value()) {
            result->Success(flutter::EncodableValue());
          } else {
            result->Success(flutter::EncodableValue(Utf16ToUtf8(*picked)));
          }
          return;
        }

        result->NotImplemented();
      });

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
  channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::NotifyDroppedFiles(HDROP drop) {
  if (channel_ == nullptr || drop == nullptr) return;
  UINT count = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  std::vector<flutter::EncodableValue> paths;
  paths.reserve(count);
  for (UINT i = 0; i < count; ++i) {
    UINT length = ::DragQueryFileW(drop, i, nullptr, 0);
    if (length == 0) continue;
    std::wstring buffer(length + 1, L'\0');
    ::DragQueryFileW(drop, i, buffer.data(), length + 1);
    buffer.resize(length);
    paths.emplace_back(Utf16ToUtf8(buffer));
  }
  channel_->InvokeMethod(
      "droppedFiles",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(paths)));
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
    case WM_DROPFILES:
      NotifyDroppedFiles(reinterpret_cast<HDROP>(wparam));
      ::DragFinish(reinterpret_cast<HDROP>(wparam));
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
