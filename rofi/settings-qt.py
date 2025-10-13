#!/usr/bin/env python3
"""
Apple-inspired Settings App - Qt/QML Version
Smooth, beautiful, and fast like macOS
"""

import sys
import os
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

class AnimatedCard(QWidget):
    """Card widget with iOS-style press animation"""
    
    def __init__(self):
        super().__init__()
        self.scale_effect = QGraphicsOpacityEffect()
        self.setGraphicsEffect(self.scale_effect)
        self.scale_effect.setOpacity(1.0)
    
    def mousePressEvent(self, event):
        """Scale down on press"""
        if event.button() == Qt.LeftButton:
            # Scale down animation
            self.press_anim = QPropertyAnimation(self, b"geometry")
            self.press_anim.setDuration(100)
            
            current = self.geometry()
            # Scale to 97% from center
            new_width = int(current.width() * 0.97)
            new_height = int(current.height() * 0.97)
            offset_x = (current.width() - new_width) // 2
            offset_y = (current.height() - new_height) // 2
            
            self.press_anim.setStartValue(current)
            self.press_anim.setEndValue(QRect(
                current.x() + offset_x,
                current.y() + offset_y,
                new_width,
                new_height
            ))
            self.press_anim.setEasingCurve(QEasingCurve.OutCubic)
            self.press_anim.start()
            
            # Opacity animation
            self.opacity_anim = QPropertyAnimation(self.scale_effect, b"opacity")
            self.opacity_anim.setDuration(100)
            self.opacity_anim.setStartValue(1.0)
            self.opacity_anim.setEndValue(0.8)
            self.opacity_anim.start()
        
        super().mousePressEvent(event)
    
    def mouseReleaseEvent(self, event):
        """Scale back up on release"""
        if event.button() == Qt.LeftButton:
            # Scale back up animation
            self.release_anim = QPropertyAnimation(self, b"geometry")
            self.release_anim.setDuration(150)
            
            current = self.geometry()
            # Scale back to 100%
            original_width = int(current.width() / 0.97)
            original_height = int(current.height() / 0.97)
            offset_x = (current.width() - original_width) // 2
            offset_y = (current.height() - original_height) // 2
            
            self.release_anim.setStartValue(current)
            self.release_anim.setEndValue(QRect(
                current.x() + offset_x,
                current.y() + offset_y,
                original_width,
                original_height
            ))
            self.release_anim.setEasingCurve(QEasingCurve.OutBack)  # Bounce effect!
            self.release_anim.start()
            
            # Opacity back
            self.opacity_back = QPropertyAnimation(self.scale_effect, b"opacity")
            self.opacity_back.setDuration(150)
            self.opacity_back.setStartValue(0.8)
            self.opacity_back.setEndValue(1.0)
            self.opacity_back.start()
            
            # Navigate to page (only wallpaper for now)
            if hasattr(self, 'page_index') and hasattr(self, 'parent_window'):
                if self.page_index == 0:  # Wallpaper
                    QTimer.singleShot(150, lambda: self.parent_window.slide_to_page(1))
        
        super().mouseReleaseEvent(event)

class AppleSettings(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Settings")
        self.setGeometry(100, 100, 900, 700)
        
        # Apple-style window flags
        self.setWindowFlags(Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)
        
        # Main widget
        main_widget = QWidget()
        main_widget.setObjectName("mainWidget")
        self.setCentralWidget(main_widget)
        
        # Main layout
        layout = QVBoxLayout(main_widget)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Custom titlebar
        self.create_titlebar(layout)
        
        # Content area
        self.create_content(layout)
        
        # Apply Apple-inspired stylesheet
        self.apply_apple_style()
        
        # Fade in animation
        self.fade_in()
    
    def create_titlebar(self, layout):
        """Create macOS-style titlebar"""
        titlebar = QWidget()
        titlebar.setObjectName("titlebar")
        titlebar.setFixedHeight(50)
        
        titlebar_layout = QHBoxLayout(titlebar)
        titlebar_layout.setContentsMargins(15, 0, 15, 0)
        
        # macOS traffic lights
        traffic_lights = QWidget()
        traffic_layout = QHBoxLayout(traffic_lights)
        traffic_layout.setSpacing(8)
        traffic_layout.setContentsMargins(0, 0, 0, 0)
        
        # Close button
        close_btn = QPushButton()
        close_btn.setObjectName("closeBtn")
        close_btn.setFixedSize(12, 12)
        close_btn.clicked.connect(self.close)
        traffic_layout.addWidget(close_btn)
        
        # Minimize button
        min_btn = QPushButton()
        min_btn.setObjectName("minBtn")
        min_btn.setFixedSize(12, 12)
        min_btn.clicked.connect(self.showMinimized)
        traffic_layout.addWidget(min_btn)
        
        # Maximize button
        max_btn = QPushButton()
        max_btn.setObjectName("maxBtn")
        max_btn.setFixedSize(12, 12)
        traffic_layout.addWidget(max_btn)
        
        titlebar_layout.addWidget(traffic_lights)
        
        # Title
        title = QLabel("Settings")
        title.setObjectName("titleLabel")
        titlebar_layout.addStretch()
        titlebar_layout.addWidget(title)
        titlebar_layout.addStretch()
        
        # Empty space for symmetry
        titlebar_layout.addWidget(QWidget(), 1)
        
        layout.addWidget(titlebar)
    
    def create_content(self, layout):
        """Create main content area with page stack"""
        # Stack widget for pages
        self.stack = QStackedWidget()
        self.stack.setObjectName("stackWidget")
        
        # Main menu page
        main_page = self.create_main_page()
        self.stack.addWidget(main_page)
        
        # Wallpaper page
        wallpaper_page = self.create_wallpaper_page()
        self.stack.addWidget(wallpaper_page)
        
        layout.addWidget(self.stack)
    
    def create_main_page(self):
        """Create the main menu page"""
        # Scroll area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setObjectName("scrollArea")
        
        # Content widget
        content = QWidget()
        content.setObjectName("contentWidget")
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(40, 30, 40, 30)
        content_layout.setSpacing(20)
        
        # Settings cards
        self.create_settings_cards(content_layout)
        
        scroll.setWidget(content)
        return scroll
    
    def create_wallpaper_page(self):
        """Create wallpaper picker page"""
        page = QWidget()
        page.setObjectName("contentWidget")
        page_layout = QVBoxLayout(page)
        page_layout.setContentsMargins(40, 20, 40, 30)
        page_layout.setSpacing(20)
        
        # Back button
        back_btn = QPushButton("‹ Settings")
        back_btn.setObjectName("backButton")
        back_btn.setCursor(Qt.PointingHandCursor)
        back_btn.clicked.connect(lambda: self.slide_to_page(0))
        page_layout.addWidget(back_btn)
        
        # Title
        title = QLabel("Wallpaper")
        title.setObjectName("pageTitle")
        page_layout.addWidget(title)
        
        # Wallpaper grid (placeholder for now)
        grid_label = QLabel("🖼️ Wallpaper grid coming soon...")
        grid_label.setObjectName("cardSubtitle")
        grid_label.setAlignment(Qt.AlignCenter)
        page_layout.addWidget(grid_label, 1)
        
        return page
    
    def create_settings_cards(self, layout):
        """Create Apple-style settings cards"""
        cards = [
            ("🖼️", "Wallpaper", "Choose your desktop background"),
            ("🔊", "Sound", "Volume and audio devices"),
            ("🖥️", "Display", "Resolution and refresh rate"),
            ("📶", "Bluetooth", "Connect devices"),
            ("🌐", "Network", "Wi-Fi and Ethernet"),
        ]
        
        for i, (icon, title, subtitle) in enumerate(cards):
            card = self.create_card(icon, title, subtitle, i)
            layout.addWidget(card)
        
        layout.addStretch()
    
    def create_card(self, icon, title, subtitle, page_index):
        """Create a single settings card with animations"""
        card = AnimatedCard()
        card.setObjectName("settingsCard")
        card.setCursor(Qt.PointingHandCursor)
        card.page_index = page_index
        
        # Store reference to parent for navigation
        card.parent_window = self
        
        card_layout = QHBoxLayout(card)
        card_layout.setContentsMargins(20, 15, 20, 15)
        
        # Icon
        icon_label = QLabel(icon)
        icon_label.setObjectName("cardIcon")
        card_layout.addWidget(icon_label)
        
        # Text container
        text_container = QVBoxLayout()
        text_container.setSpacing(2)
        
        title_label = QLabel(title)
        title_label.setObjectName("cardTitle")
        text_container.addWidget(title_label)
        
        subtitle_label = QLabel(subtitle)
        subtitle_label.setObjectName("cardSubtitle")
        text_container.addWidget(subtitle_label)
        
        card_layout.addLayout(text_container)
        card_layout.addStretch()
        
        # Chevron
        chevron = QLabel("›")
        chevron.setObjectName("chevron")
        card_layout.addWidget(chevron)
        
        return card
    
    def slide_to_page(self, index):
        """Slide to a page with animation"""
        current_index = self.stack.currentIndex()
        
        if current_index == index:
            return
        
        # Determine slide direction
        if index > current_index:
            # Slide left (going forward)
            offset = self.stack.width()
        else:
            # Slide right (going back)
            offset = -self.stack.width()
        
        # Get current and next widgets
        current_widget = self.stack.currentWidget()
        next_widget = self.stack.widget(index)
        
        # Position next widget off-screen
        next_widget.setGeometry(offset, 0, self.stack.width(), self.stack.height())
        next_widget.show()
        next_widget.raise_()
        
        # Animate current widget out
        current_anim = QPropertyAnimation(current_widget, b"pos")
        current_anim.setDuration(300)
        current_anim.setStartValue(QPoint(0, 0))
        current_anim.setEndValue(QPoint(-offset, 0))
        current_anim.setEasingCurve(QEasingCurve.OutCubic)
        
        # Animate next widget in
        next_anim = QPropertyAnimation(next_widget, b"pos")
        next_anim.setDuration(300)
        next_anim.setStartValue(QPoint(offset, 0))
        next_anim.setEndValue(QPoint(0, 0))
        next_anim.setEasingCurve(QEasingCurve.OutCubic)
        
        # Change page when animation completes
        next_anim.finished.connect(lambda: self.stack.setCurrentIndex(index))
        
        # Start animations
        current_anim.start()
        next_anim.start()
        
        # Store animations to prevent garbage collection
        self.current_anim = current_anim
        self.next_anim = next_anim
    
    def apply_apple_style(self):
        """Apply Apple-inspired stylesheet - GLASSY FROSTED"""
        self.setStyleSheet("""
            #mainWidget {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(15, 15, 20, 0.85), stop:1 rgba(25, 25, 35, 0.85));
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.1);
            }
            
            #titlebar {
                background: rgba(20, 20, 25, 0.7);
                border-top-left-radius: 20px;
                border-top-right-radius: 20px;
                border-bottom: 1px solid rgba(255, 255, 255, 0.08);
                backdrop-filter: blur(20px);
            }
            
            #closeBtn {
                background: #ff5f57;
                border: none;
                border-radius: 6px;
            }
            
            #closeBtn:hover {
                background: #ff4136;
            }
            
            #minBtn {
                background: #ffbd2e;
                border: none;
                border-radius: 6px;
            }
            
            #minBtn:hover {
                background: #ffaa00;
            }
            
            #maxBtn {
                background: #28ca42;
                border: none;
                border-radius: 6px;
            }
            
            #maxBtn:hover {
                background: #1fb834;
            }
            
            #titleLabel {
                font-size: 15px;
                font-weight: 600;
                color: #f5f5f7;
                letter-spacing: 0.5px;
            }
            
            #scrollArea {
                background: transparent;
                border: none;
            }
            
            #contentWidget {
                background: transparent;
            }
            
            QScrollBar:vertical {
                background: transparent;
                width: 6px;
                margin: 0;
            }
            
            QScrollBar::handle:vertical {
                background: rgba(255, 255, 255, 0.2);
                border-radius: 3px;
                min-height: 20px;
            }
            
            QScrollBar::handle:vertical:hover {
                background: rgba(255, 255, 255, 0.3);
            }
            
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
            
            #settingsCard {
                background: rgba(255, 255, 255, 0.05);
                border-radius: 20px;
                border: 1px solid rgba(255, 255, 255, 0.12);
                backdrop-filter: blur(40px);
            }
            
            #settingsCard:hover {
                background: rgba(255, 255, 255, 0.08);
                border: 1px solid rgba(255, 255, 255, 0.18);
            }
            
            #cardIcon {
                font-size: 36px;
                margin-right: 15px;
            }
            
            #cardTitle {
                font-size: 18px;
                font-weight: 600;
                color: #ffffff;
                letter-spacing: 0.2px;
            }
            
            #cardSubtitle {
                font-size: 13px;
                color: #a0a0a5;
            }
            
            #chevron {
                font-size: 30px;
                color: #505055;
                font-weight: 200;
            }
            
            #backButton {
                background: transparent;
                border: none;
                color: #007aff;
                font-size: 16px;
                font-weight: 500;
                text-align: left;
                padding: 5px 0px;
            }
            
            #backButton:hover {
                color: #0051d5;
            }
            
            #pageTitle {
                font-size: 28px;
                font-weight: 700;
                color: #f5f5f7;
                letter-spacing: 0.5px;
            }
        """)
    
    def fade_in(self):
        """Smooth fade-in animation"""
        self.setWindowOpacity(0)
        self.show()
        
        self.fade_animation = QPropertyAnimation(self, b"windowOpacity")
        self.fade_animation.setDuration(300)
        self.fade_animation.setStartValue(0)
        self.fade_animation.setEndValue(1)
        self.fade_animation.setEasingCurve(QEasingCurve.OutCubic)
        self.fade_animation.start()
    
    def mousePressEvent(self, event):
        """Enable window dragging"""
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPos() - self.frameGeometry().topLeft()
            event.accept()
    
    def mouseMoveEvent(self, event):
        """Handle window dragging"""
        if event.buttons() == Qt.LeftButton:
            self.move(event.globalPos() - self.drag_position)
            event.accept()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    # Set app-wide font (closest to San Francisco)
    app.setFont(QFont("SF Pro Display", 13))
    
    window = AppleSettings()
    window.show()
    
    sys.exit(app.exec_())
