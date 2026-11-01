#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// كل نسخ التطبيق تستخدم نفس اسم النافذة، وهذا ما يجعل اكتشاف
// "التطبيق يعمل بالفعل" ممكنًا دون أي مكوّن إضافي.
constexpr const wchar_t kSingleInstanceWindowClass[] =
    L"Convert92727282929SingleInstance";
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Local\\Convert92727282929.SingleInstance";

// يُنشئ نافذة مخفية تحمل رسالة مخصّصة "أظهر النافذة الأولى".
void SendShowRequest(HWND target) {
  if (target == nullptr) return;
  if (::IsIconic(target)) {
    ::ShowWindow(target, SW_RESTORE);
  }
  ::SetForegroundWindow(target);
  ::FlashWindow(target, TRUE);
}

HWND FindPrimaryWindow() {
  return ::FindWindowW(kSingleInstanceWindowClass, nullptr);
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
  // إن كان هناك نسخة تعمل، لا نفتح نافذة ثانية: نُظهر النافذة القائمة ونخرج.
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = FindPrimaryWindow();
    if (existing == nullptr) {
      ::Sleep(400);
      existing = FindPrimaryWindow();
    }
    SendShowRequest(existing);
    ::CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // سجل بديل للنسخة الأولى: نافذة مخفية بنفس اسم الصنف الذي يبحث عنه
  // أي تشغيل لاحق. وجودها يعني "التطبيق شغال".
  WNDCLASSW marker_class{};
  marker_class.lpfnWndProc = ::DefWindowProcW;
  marker_class.hInstance = instance;
  marker_class.lpszClassName = kSingleInstanceWindowClass;
  ::RegisterClassW(&marker_class);
  HWND marker = ::CreateWindowExW(0, kSingleInstanceWindowClass, L"convert",
                                  WS_OVERLAPPED, 0, 0, 0, 0, nullptr, nullptr,
                                  instance, nullptr);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(48, 48);
  Win32Window::Size size(1240, 800);
  if (!window.Create(L"تحويل — Convert", origin, size)) {
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
