import sys
import time
import ctypes
from ctypes import wintypes
from PyQt5.QtCore import QUrl, Qt, QTimer
from PyQt5.QtWidgets import QApplication, QMainWindow, QInputDialog, QMessageBox, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton
from PyQt5.QtGui import QFont, QCursor
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEngineProfile

# ------------------------------------------------------------------------
# NATIVE WINDOWS SECURITY HOOKS & UTILITIES (Zero External Dependencies)
# ------------------------------------------------------------------------

# Native Windows Battery Status Struct
class SYSTEM_POWER_STATUS(ctypes.Structure):
    _fields_ = [
        ('ACLineStatus', wintypes.BYTE),
        ('BatteryFlag', wintypes.BYTE),
        ('BatteryLifePercent', wintypes.BYTE),
        ('Reserved1', wintypes.BYTE),
        ('BatteryLifeTime', wintypes.DWORD),
        ('BatteryFullLifeTime', wintypes.DWORD),
    ]

def get_battery_info():
    status = SYSTEM_POWER_STATUS()
    if ctypes.windll.kernel32.GetSystemPowerStatus(ctypes.byref(status)):
        percent = status.BatteryLifePercent
        is_charging = status.ACLineStatus == 1
        # Treat 255 as unknown / desktop PC
        if percent == 255:
            return 100, False
        return percent, is_charging
    return 100, False

# Keyboard Hook References to prevent Garbage Collection
hHook = None
hook_proc = None

def install_keyboard_hook():
    """
    Memasang low-level keyboard hook untuk menangkap dan memblokir shortcut
    keamanan Windows seperti Windows Key, Alt+Tab, Alt+Esc, dan Ctrl+Esc.
    """
    global hHook, hook_proc
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    
    WH_KEYBOARD_LL = 13
    HC_ACTION = 0
    
    VK_TAB = 0x09
    VK_ESCAPE = 0x1B
    VK_LWIN = 0x5B
    VK_RWIN = 0x5C
    LLKHF_ALTDOWN = 0x20
    
    class KBDLLHOOKSTRUCT(ctypes.Structure):
        _fields_ = [
            ("vkCode", wintypes.DWORD),
            ("scanCode", wintypes.DWORD),
            ("flags", wintypes.DWORD),
            ("time", wintypes.DWORD),
            ("dwExtraInfo", ctypes.c_ulonglong)
        ]
        
    HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_int, ctypes.c_int, wintypes.WPARAM, ctypes.POINTER(KBDLLHOOKSTRUCT))
    
    def keyboard_hook_callback(nCode, wParam, lParam):
        if nCode == HC_ACTION:
            vkCode = lParam.contents.vkCode
            flags = lParam.contents.flags
            is_alt = (flags & LLKHF_ALTDOWN) != 0
            
            # 1. Blokir Tombol Windows Kiri / Kanan (Mencegah buka Start Menu / Taskbar)
            if vkCode in (VK_LWIN, VK_RWIN):
                return 1
                
            # 2. Blokir Alt + Tab (Mencegah ganti jendela/aplikasi)
            if vkCode == VK_TAB and is_alt:
                return 1
                
            # 3. Blokir Alt + Escape (Mencegah ganti fokus jendela langsung)
            if vkCode == VK_ESCAPE and is_alt:
                return 1
                
            # 4. Blokir Ctrl + Escape (Mencegah pemicuan Start Menu)
            # VK_CONTROL = 0x11
            if vkCode == VK_ESCAPE and (user32.GetKeyState(0x11) & 0x8000):
                return 1
                
        return user32.CallNextHookEx(None, nCode, wParam, lParam)
        
    hook_proc = HOOKPROC(keyboard_hook_callback)
    hHook = user32.SetWindowsHookExW(
        WH_KEYBOARD_LL, 
        hook_proc, 
        kernel32.GetModuleHandleW(None), 
        0
    )

def uninstall_keyboard_hook():
    """
    Melepas keyboard hook secara bersih saat aplikasi ditutup resmi oleh proktor.
    """
    global hHook
    if hHook:
        ctypes.windll.user32.UnhookWindowsHookEx(hHook)
        hHook = None


class ExamBrowserWindows(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("XAMBRO Windows")
        
        # 1. Kunci Layar Penuh (Frameless) & Selalu di Paling Atas (Stays on Top)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.CustomizeWindowHint)
        self.showFullScreen()
        
        # 2. Main Widget & Layout
        main_widget = QWidget()
        main_layout = QVBoxLayout(main_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # 3. Create Top Bar
        top_bar = QWidget()
        top_bar.setFixedHeight(45)
        top_bar.setStyleSheet("""
            QWidget {
                background-color: #1E1B4B;
                border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            }
            QLabel {
                color: #FFFFFF;
                border: none;
            }
        """)
        
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(15, 0, 15, 0)
        
        # Left: Branding Title
        self.title_label = QLabel("XAMBRO")
        self.title_font = QFont("Inter", 12, QFont.Black)
        self.title_font.setLetterSpacing(QFont.AbsoluteSpacing, 2)
        self.title_label.setFont(self.title_font)
        top_layout.addWidget(self.title_label)
        
        top_layout.addStretch()
        
        # Right: Info & Actions
        info_layout = QHBoxLayout()
        info_layout.setSpacing(15)
        
        # Clock Widget
        self.clock_label = QLabel()
        self.clock_font = QFont("monospace", 10, QFont.Bold)
        self.clock_label.setFont(self.clock_font)
        self.clock_label.setStyleSheet("color: rgba(255, 255, 255, 0.85);")
        info_layout.addWidget(self.clock_label)
        
        # Separator
        self.sep_label = QLabel("|")
        self.sep_label.setStyleSheet("color: rgba(255, 255, 255, 0.2);")
        info_layout.addWidget(self.sep_label)
        
        # Battery Widget
        self.battery_label = QLabel()
        self.battery_font = QFont("monospace", 10, QFont.Bold)
        self.battery_label.setFont(self.battery_font)
        self.battery_label.setStyleSheet("color: rgba(255, 255, 255, 0.85);")
        info_layout.addWidget(self.battery_label)
        
        # Separator 2
        self.sep_label2 = QLabel("|")
        self.sep_label2.setStyleSheet("color: rgba(255, 255, 255, 0.2);")
        info_layout.addWidget(self.sep_label2)
        
        # Refresh Button
        self.refresh_btn = QPushButton("↺ Refresh")
        self.refresh_btn.setCursor(QCursor(Qt.PointingHandCursor))
        self.refresh_btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                color: rgba(255, 255, 255, 0.85);
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 4px;
                padding: 4px 10px;
                font-family: 'Inter';
                font-weight: bold;
                font-size: 11px;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.1);
                color: #FFFFFF;
                border: 1px solid rgba(255, 255, 255, 0.4);
            }
        """)
        self.refresh_btn.clicked.connect(self.reload_page)
        info_layout.addWidget(self.refresh_btn)
        
        # Exit Button
        self.exit_btn = QPushButton("✕ Keluar")
        self.exit_btn.setCursor(QCursor(Qt.PointingHandCursor))
        self.exit_btn.setStyleSheet("""
            QPushButton {
                background-color: #EF4444;
                color: #FFFFFF;
                border: none;
                border-radius: 4px;
                padding: 4px 10px;
                font-family: 'Inter';
                font-weight: bold;
                font-size: 11px;
            }
            QPushButton:hover {
                background-color: #DC2626;
            }
        """)
        self.exit_btn.clicked.connect(self.close)
        info_layout.addWidget(self.exit_btn)
        
        top_layout.addLayout(info_layout)
        
        main_layout.addWidget(top_bar)
        
        # 4. Setup WebView
        self.webview = QWebEngineView()
        
        # 5. Tanam User Agent khusus agar dikenali sebagai aplikasi resmi
        profile = QWebEngineProfile.defaultProfile()
        profile.setHttpUserAgent("ExamBrowser-Xcoding")
        
        # 6. Tanam Link Ujian Anda
        self.webview.setUrl(QUrl("https://x.madafa.sch.id/?examkey=asas"))
        main_layout.addWidget(self.webview)
        
        self.setCentralWidget(main_widget)
        
        # 7. Setup Timer for Clock & Battery Updates
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_info)
        self.timer.start(1000) # Update every second
        self.update_info() # Initial update

    def reload_page(self):
        self.webview.reload()

    def update_info(self):
        # Update Clock
        self.clock_label.setText(time.strftime("%H:%M:%S"))
        
        # Update Battery
        percent, is_charging = get_battery_info()
        charging_icon = "⚡" if is_charging else "🔋"
        self.battery_label.setText(f"{charging_icon} {percent}%")

    def closeEvent(self, event):
        # 8. Kunci tombol keluar (Alt+F4 dll) dengan PIN Proktor
        pin, ok = QInputDialog.getText(
            self, 
            "Otoritas Proktor", 
            "Masukkan PIN Keamanan untuk Keluar dari Ujian:", 
            QInputDialog.TextInput, 
            ""
        )
        if ok and pin == "7777":
            event.accept()  # Izinkan keluar jika PIN benar
        else:
            QMessageBox.warning(self, "Akses Ditolak", "PIN Keamanan Salah!")
            event.ignore()  # Tolak keluar jika PIN salah / dibatalkan

    def keyPressEvent(self, event):
        # 9. Nonaktifkan tombol navigasi keyboard bawaan (Escape, F11, dll)
        if event.key() in [Qt.Key_Escape, Qt.Key_F11, Qt.Key_F5]:
            event.ignore()
        else:
            super().keyPressEvent(event)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    # Nonaktifkan klik kanan agar siswa tidak bisa inspect element
    app.setStartDragTime(0)
    
    # Pasang Keyboard Hook Keamanan Tingkat Tinggi (Blokir Alt+Tab, Win Key, Ctrl+Esc, dll)
    install_keyboard_hook()
    
    window = ExamBrowserWindows()
    
    # Blokir menu klik kanan di webview
    window.webview.setContextMenuPolicy(Qt.NoContextMenu)
    
    # Jalankan Aplikasi Qt
    exit_code = app.exec_()
    
    # Lepas Keyboard Hook saat aplikasi ditutup secara resmi oleh proktor
    uninstall_keyboard_hook()
    
    sys.exit(exit_code)
