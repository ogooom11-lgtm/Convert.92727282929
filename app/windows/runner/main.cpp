#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// اسم النافذة الوسيطة: وجودها يعني "التطبيق شغال".
constexpr const wchar_t kMarkerWindowClass[] =
    L"Convert92727282929SingleInstance";
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Local\\Convert92727282929.SingleInstance";

constexpr const wchar_t kAppTitle[] = L"تحويل — Convert";

/// يُظهر النافذة الأولى (ويُعيدها من التصغير) ويضعها في المقدمة.
void BringToFront(HWND target) {
  if (target == nullptr) return;
  if (::IsIconic(target)) {
    ::ShowWindow(target, SW_RESTORE);
  }
  ::SetForegroundWindow(target);
  ::FlashWindow(target, TRUE);
}

HWND FindPrimaryWindow() {
  return ::FindWindowW(kMarkerWindowClass, nullptr);
}

/// حجم أولي يتكيّف مع الشاشة: لا نافذة أكبر من مساحة العمل، ولا نافذة
/// تبدأ خارج الشاشة على الشاشات الصغيرة (1366×768 مثلًا).
void ComputeInitialBounds(Win32Window::Point* origin, Win32Window::Size* size) {
  RECT work_area{};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, NULL);

  const double available_width =
      static_cast<double>(work_area.right - work_area.left);
  const double available_height =
      static_cast<double>(work_area.bottom - work_area.top);

  UINT dpi = ::GetDpiForSystem();
  const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
  const double logical_width = available_width / scale;
  const double logical_height = available_height / scale;

  const double width = logical_width * 0.9 < 1240 ? logical_width * 0.9 : 1240;
  const double height =
      logical_height * 0.88 < 800 ? logical_height * 0.88 : 800;

  const double x = (logical_width - width) / 2;
  const double y = (logical_height - height) / 2;

  *origin = Win32Window::Point(
      static_cast<unsigned int>(x < 0 ? 0 : x),
      static_cast<unsigned int>(y < 0 ? 0 : y));
  *size = Win32Window::Size(
      static_cast<unsigned int>(width < 640 ? 640 : width),
      static_cast<unsigned int>(height < 480 ? 480 : height));
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // ── قفل النسخة الواحدة ──────────────────────────────────────────────
  // إن كانت هناك نسخة تعمل: لا نافذة ثانية. نُظهر النافذة القائمة ونخرج.
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = FindPrimaryWindow();
    if (existing == nullptr) {
      ::Sleep(400);
      existing = FindPrimaryWindow();
    }
    BringToFront(existing);
    ::CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // نافذة مخفية بنفس اسم الصنف الذي يبحث عنه أي تشغيل لاحق.
  WNDCLASSW marker_class{};
  marker_class.lpfnWndProc = ::DefWindowProcW;
  marker_class.hInstance = instance;
  marker_class.lpszClassName = kMarkerWindowClass;
  ::RegisterClassW(&marker_class);
  HWND marker = ::CreateWindowExW(0, kMarkerWindowClass, L"convert", WS_OVERLAPPED,
                                  0, 0, 0, 0, nullptr, nullptr, instance,
                                  nullptr);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  Win32Window::Point origin(48, 48);
  Win32Window::Size size(1240, 800);
  ComputeInitialBounds(&origin, &size);

  FlutterWindow window(project);
  if (!window.Create(kAppTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (marker != nullptr) {
    ::DestroyWindow(marker);
  }
  ::CoUninitialize();
  if (mutex != nullptr) {
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
  }
  return EXIT_SUCCESS;
}
