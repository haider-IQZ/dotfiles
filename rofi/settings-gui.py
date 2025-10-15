#!/usr/bin/env python3
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf
import subprocess
import os
import glob
import re
import shutil
import json
import shutil


class SettingsMenu(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self, title="Settings")
        self.set_border_width(0)
        self.set_default_size(900, 700)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_decorated(False)  # Remove default titlebar

        # Preferences
        self.prefs_path = os.path.expanduser("~/.config/rofi/settings-gui.json")
        self.prefs = self.load_prefs()
        
        # Load wallpaper directory from prefs or use default
        self.wallpaper_dir = self.prefs.get("wallpaper_dir", os.path.expanduser("~/Pictures/Wallpapers"))

        # External command availability
        self.has_feh = shutil.which("feh") is not None
        self.has_nitrogen = shutil.which("nitrogen") is not None
        self.has_notify = shutil.which("notify-send") is not None
        self.has_pactl = shutil.which("pactl") is not None
        self.has_xrandr = shutil.which("xrandr") is not None
        self.has_bluetoothctl = shutil.which("bluetoothctl") is not None
        self.has_nmcli = shutil.which("nmcli") is not None
        self.has_resolvectl = shutil.which("resolvectl") is not None
        self.has_iperf3 = shutil.which("iperf3") is not None

        # Set dark theme
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-application-prefer-dark-theme", True)

        # Apply custom CSS for macOS-style with gruvbox colors
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            window {
                background: linear-gradient(135deg, #1d2021 0%, #282828 100%);
                border-radius: 16px;
            }

            .title-label {
                color: #ebdbb2;
                font-size: 28px;
                font-weight: 600;
                padding: 20px;
            }

            .settings-button {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                color: #ebdbb2;
                border: none;
                border-radius: 16px;
                padding: 24px;
                margin: 8px;
                font-size: 15px;
                font-weight: 500;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
                transition: all 200ms cubic-bezier(0.4, 0.0, 0.2, 1);
            }

            .settings-button:hover {
                background: linear-gradient(135deg, #504945 0%, #3c3836 100%);
                box-shadow: 0 8px 24px rgba(254, 128, 25, 0.3);
            }

            .settings-button:active {
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
            }

            .settings-button label {
                color: #ebdbb2;
            }

            .icon-box {
                background: linear-gradient(135deg, #fe8019 0%, #d65d0e 100%);
                border-radius: 12px;
                padding: 12px;
                margin-right: 16px;
                min-width: 48px;
                min-height: 48px;
            }

            .icon-label {
                font-size: 24px;
            }

            .button-text {
                font-size: 15px;
                font-weight: 500;
            }

            .shortcut-card {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border-radius: 12px;
                padding: 16px;
                margin: 4px;
                border-left: 4px solid #fe8019;
            }

            .shortcut-name {
                color: #ebdbb2;
                font-size: 14px;
                font-weight: 600;
            }

            .shortcut-desc {
                color: #a89984;
                font-size: 12px;
            }



            .settings-card {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border: 2px solid #504945;
                border-radius: 20px;
                padding: 25px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            }

            .settings-card:hover {
                background: linear-gradient(135deg, #504945 0%, #3c3836 100%);
                border-color: #fe8019;
                box-shadow: 0 8px 20px rgba(254, 128, 25, 0.4);
                margin-top: -2px;
            }

            .card-icon {
                font-size: 48px;
            }

            .card-text {
                color: #ebdbb2;
                font-size: 16px;
                font-weight: 600;
            }

            .welcome-card {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border-radius: 20px;
                padding: 30px;
                margin-bottom: 10px;
                box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
            }

            .welcome-title {
                color: #ebdbb2;
            }

            .welcome-subtitle {
                color: #928374;
            }

            .back-button {
                background: #3c3836;
                color: #ebdbb2;
                border: none;
                border-radius: 12px;
                padding: 12px 20px;
                font-size: 14px;
                font-weight: 500;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
            }

            .back-button:hover {
                background: #504945;
                box-shadow: 0 4px 12px rgba(254, 128, 25, 0.2);
            }

            flowboxchild {
                padding: 0;
                margin: 0;
                border: none;
                outline: none;
            }

            .wallpaper-card {
                background: transparent;
                border: none;
                padding: 0;
                margin: 0;
                outline: none;
                box-shadow: none;
            }

            .wallpaper-card * {
                padding: 0;
                margin: 0;
                border: none;
            }

            .wallpaper-card image {
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
            }

            .wallpaper-card:hover image {
                box-shadow: 0 8px 24px rgba(254, 128, 25, 0.5);
            }

            button.wallpaper-card {
                padding: 0;
                border: 0;
                outline: 0;
                min-width: 0;
                min-height: 0;
            }

            .wallpaper-card fixed {
                padding: 0;
                margin: 0;
                border: none;
            }

            .volume-card {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border-radius: 16px;
                padding: 30px;
                margin: 10px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            }

            .volume-label {
                color: #8ec07c;
                font-size: 18px;
                font-weight: 600;
            }

            .volume-value {
                color: #fe8019;
                font-size: 48px;
                font-weight: 700;
            }

            .mute-button {
                background: linear-gradient(135deg, #fb4934 0%, #cc241d 100%);
                color: #ebdbb2;
                border: none;
                border-radius: 16px;
                padding: 16px 32px;
                font-size: 16px;
                font-weight: 600;
                box-shadow: 0 4px 12px rgba(251, 73, 52, 0.3);
            }

            .mute-button:hover {
                background: linear-gradient(135deg, #fb5934 0%, #fb4934 100%);
                box-shadow: 0 6px 16px rgba(251, 73, 52, 0.5);
            }

            .unmute-button {
                background: linear-gradient(135deg, #b8bb26 0%, #98971a 100%);
                color: #282828;
                border: none;
                border-radius: 16px;
                padding: 16px 32px;
                font-size: 16px;
                font-weight: 600;
                box-shadow: 0 4px 12px rgba(184, 187, 38, 0.3);
            }

            .unmute-button:hover {
                background: linear-gradient(135deg, #d3d220 0%, #b8bb26 100%);
                box-shadow: 0 6px 16px rgba(184, 187, 38, 0.5);
            }

            .device-label {
                color: #fe8019;
                font-size: 15px;
                font-weight: 600;
                margin-bottom: 8px;
            }

            .system-label {
                background: linear-gradient(135deg, #83a598 0%, #458588 100%);
                color: #282828;
                border-radius: 12px;
                padding: 8px 16px;
                font-size: 12px;
                font-weight: 600;
            }

            combobox button {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                color: #ebdbb2;
                border: 2px solid #504945;
                border-radius: 12px;
                padding: 14px;
                font-size: 14px;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
            }

            combobox button:hover {
                background: linear-gradient(135deg, #504945 0%, #3c3836 100%);
                border-color: #fe8019;
                box-shadow: 0 4px 12px rgba(254, 128, 25, 0.3);
            }

            combobox window {
                background: transparent;
                border: none;
                margin: 0;
            }

            combobox menu {
                background: #282828;
                border: 2px solid #fe8019;
                border-radius: 12px;
                padding: 6px;
                margin: 0;
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
            }

            combobox cellview {
                margin: 0;
                padding: 0;
            }

            combobox menuitem {
                background: #3c3836;
                color: #ebdbb2;
                border-radius: 8px;
                padding: 12px 16px;
                margin: 3px;
                font-size: 14px;
            }

            combobox menuitem:first-child {
                margin-top: 0;
            }

            combobox menuitem:last-child {
                margin-bottom: 0;
            }

            combobox menuitem:hover {
                background: linear-gradient(135deg, #fe8019 0%, #d65d0e 100%);
                color: #282828;
                box-shadow: 0 2px 8px rgba(254, 128, 25, 0.4);
            }

            combobox menuitem:selected {
                background: linear-gradient(135deg, #b8bb26 0%, #98971a 100%);
                color: #282828;
                font-weight: 600;
            }

            scale {
                min-height: 80px;
            }

            scale trough {
                background: linear-gradient(90deg, #3c3836 0%, #32302f 100%);
                border-radius: 30px;
                min-height: 16px;
                box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.3);
            }

            scale highlight {
                background: linear-gradient(90deg, #8ec07c 0%, #b8bb26 50%, #fabd2f 100%);
                border-radius: 30px;
                box-shadow: 0 2px 8px rgba(184, 187, 38, 0.4);
            }

            scale slider {
                background: linear-gradient(135deg, #ebdbb2 0%, #d5c4a1 100%);
                border: 3px solid #fe8019;
                border-radius: 50%;
                min-width: 32px;
                min-height: 32px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
            }

            scale slider:hover {
                background: linear-gradient(135deg, #fbf1c7 0%, #ebdbb2 100%);
                border-color: #fabd2f;
                box-shadow: 0 6px 16px rgba(254, 128, 25, 0.5);
                min-width: 36px;
                min-height: 36px;
            }

            scale marks {
                color: #928374;
            }

            scrollbar {
                opacity: 0;
            }

            .monitor-preview {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border-radius: 20px;
                padding: 40px;
                margin: 10px;
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
            }

            .current-display-label {
                color: #fabd2f;
                font-size: 18px;
                font-weight: 600;
            }

            .apply-button {
                background: linear-gradient(135deg, #b8bb26 0%, #98971a 100%);
                color: #282828;
                border: none;
                border-radius: 16px;
                padding: 18px;
                font-size: 16px;
                font-weight: 600;
                box-shadow: 0 4px 12px rgba(184, 187, 38, 0.3);
            }

            .apply-button:hover {
                background: linear-gradient(135deg, #d3d220 0%, #b8bb26 100%);
                box-shadow: 0 6px 16px rgba(184, 187, 38, 0.5);
            }

            .display-hero {
                background: linear-gradient(135deg, #1d2021 0%, #282828 100%);
                border: 2px solid #3c3836;
                border-radius: 24px;
                padding: 40px;
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(235, 219, 178, 0.1);
            }

            .monitor-icon {
                text-shadow: 0 0 30px rgba(250, 189, 47, 0.6);
            }

            .display-resolution {
                color: #fabd2f;
                text-shadow: 0 2px 8px rgba(250, 189, 47, 0.4);
            }

            .refresh-badge-text {
                color: #b8bb26;
                text-shadow: 0 2px 8px rgba(184, 187, 38, 0.6);
            }

            .control-panel {
                padding: 10px;
            }

            .control-card {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                border: 2px solid #504945;
                border-radius: 18px;
                padding: 25px;
                box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
            }

            .control-card:hover {
                border-color: #665c54;
                box-shadow: 0 6px 20px rgba(0, 0, 0, 0.5);
            }

            .futuristic-apply-button {
                background: linear-gradient(135deg, #b8bb26 0%, #98971a 100%);
                color: #1d2021;
                border: none;
                border-radius: 50px;
                padding: 20px 50px;
                font-size: 16px;
                font-weight: 700;
                box-shadow: 0 8px 24px rgba(184, 187, 38, 0.4);
                text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
            }

            .futuristic-apply-button:hover {
                background: linear-gradient(135deg, #d3d220 0%, #b8bb26 100%);
                box-shadow: 0 12px 32px rgba(184, 187, 38, 0.6);
            }

            .futuristic-apply-button:active {
                box-shadow: 0 4px 16px rgba(184, 187, 38, 0.4);
            }

            .status-label {
                color: #928374;
            }

            .speed-progress {
                min-height: 30px;
                border-radius: 15px;
            }

            .speed-progress trough {
                background: linear-gradient(90deg, #3c3836 0%, #32302f 100%);
                border-radius: 15px;
                min-height: 30px;
                box-shadow: inset 0 2px 6px rgba(0, 0, 0, 0.4);
            }

            .speed-progress progress {
                background: linear-gradient(90deg, #b8bb26 0%, #8ec07c 100%);
                border-radius: 15px;
                box-shadow: 0 2px 8px rgba(184, 187, 38, 0.5);
            }

            .option-button {
                background: linear-gradient(135deg, #3c3836 0%, #32302f 100%);
                color: #ebdbb2;
                border: 2px solid #504945;
                border-radius: 12px;
                padding: 14px 20px;
                font-size: 15px;
                font-weight: 500;
                box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
            }

            .option-button:hover {
                background: linear-gradient(135deg, #504945 0%, #3c3836 100%);
                border-color: #665c54;
                box-shadow: 0 4px 10px rgba(0, 0, 0, 0.4);
            }

            .option-button-active {
                background: linear-gradient(135deg, #b8bb26 0%, #98971a 100%);
                color: #1d2021;
                border-color: #b8bb26;
                font-weight: 700;
                box-shadow: 0 4px 12px rgba(184, 187, 38, 0.5);
            }

            .option-button-active:hover {
                background: linear-gradient(135deg, #d3d220 0%, #b8bb26 100%);
                box-shadow: 0 6px 16px rgba(184, 187, 38, 0.6);
            }

            .titlebar {
                background: #1d2021;
                padding: 12px 20px;
                border-radius: 16px 16px 0 0;
            }

            .window-button {
                background: #fb4934;
                border: none;
                border-radius: 7px;
                padding: 0;
                margin: 0;
            }

            .window-button.minimize {
                background: #fabd2f;
            }

            .window-button.maximize {
                background: #b8bb26;
            }

            .window-button:hover {
                opacity: 0.8;
            }

            .window-title {
                color: #ebdbb2;
                font-size: 14px;
                font-weight: 600;
            }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # Main container
        main_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_container)

        # Custom titlebar with macOS-style buttons
        titlebar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        titlebar.get_style_context().add_class("titlebar")

        # Left side container (buttons + back button below)
        left_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        # Window control buttons (macOS style: red, yellow, green)
        controls_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        # Create simple colored circles using Labels
        close_box = Gtk.EventBox()
        close_label = Gtk.Label(label="●")
        close_label.set_markup('<span foreground="#fb4934" size="14000">●</span>')
        close_box.add(close_label)
        close_box.connect("button-press-event", lambda w, e: self.destroy())
        controls_box.pack_start(close_box, False, False, 0)

        minimize_box = Gtk.EventBox()
        minimize_label = Gtk.Label(label="●")
        minimize_label.set_markup('<span foreground="#fabd2f" size="14000">●</span>')
        minimize_box.add(minimize_label)
        minimize_box.connect("button-press-event", lambda w, e: self.iconify())
        controls_box.pack_start(minimize_box, False, False, 0)

        maximize_box = Gtk.EventBox()
        maximize_label = Gtk.Label(label="●")
        maximize_label.set_markup('<span foreground="#b8bb26" size="14000">●</span>')
        maximize_box.add(maximize_label)
        maximize_box.connect("button-press-event", lambda w, e: self.toggle_maximize(w))
        controls_box.pack_start(maximize_box, False, False, 0)

        left_container.pack_start(controls_box, False, False, 0)

        # Back button (green arrow, hidden by default)
        self.back_button_box = Gtk.EventBox()
        back_label = Gtk.Label()
        back_label.set_markup(
            '<span foreground="#b8bb26" size="16000" weight="bold"></span>'
        )
        self.back_button_box.add(back_label)
        self.back_button_box.connect("button-press-event", lambda w, e: self.go_back())
        self.back_button_box.set_visible(False)  # Hidden by default
        left_container.pack_start(self.back_button_box, False, False, 0)

        titlebar.pack_start(left_container, False, False, 0)

        # Window title (absolutely centered)
        title_label = Gtk.Label(label="Settings")
        title_label.get_style_context().add_class("window-title")
        title_label.set_halign(Gtk.Align.CENTER)
        titlebar.pack_start(title_label, True, True, 0)

        # Right side container for folder button (same width as left for balance)
        self.right_container = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=8
        )
        self.right_container.set_size_request(70, 1)  # Same as left side

        # Folder button (for wallpaper page)
        self.folder_button_box = Gtk.EventBox()
        folder_label = Gtk.Label()
        folder_label.set_markup(
            '<span foreground="#fe8019" size="16000" weight="bold"></span>'
        )
        self.folder_button_box.add(folder_label)
        self.folder_button_box.connect(
            "button-press-event", lambda w, e: self.choose_wallpaper_directory(None)
        )
        self.folder_button_box.set_visible(False)  # Hidden by default
        self.right_container.pack_end(self.folder_button_box, False, False, 0)

        titlebar.pack_start(self.right_container, False, False, 0)

        # Make titlebar draggable
        titlebar.connect("button-press-event", self.on_titlebar_clicked)

        main_container.pack_start(titlebar, False, False, 0)

        # Stack for different pages with smooth animations
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(250)  # Faster, smoother
        self.stack.set_interpolate_size(True)  # Smooth size transitions
        main_container.pack_start(self.stack, True, True, 0)

        # Create main menu page
        self.create_main_menu()

        # Create wallpaper picker page (lazy-load content on open)
        self.create_wallpaper_picker()

        # Create audio settings page
        self.create_audio_settings()

        # Create display settings page
        self.create_display_settings()

        # Show main menu by default
        self.stack.set_visible_child_name("main")

        # Ensure back button and folder button are hidden on startup
        self.back_button_box.set_visible(False)
        self.folder_button_box.set_visible(False)

    def create_main_menu(self):
        """Create the main settings menu"""
        # Scrolled window for main menu
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        main_box.set_margin_top(40)
        main_box.set_margin_bottom(30)
        main_box.set_margin_start(40)
        main_box.set_margin_end(40)

        # Grid for buttons (2 columns)
        grid = Gtk.Grid()
        grid.set_row_spacing(16)
        grid.set_column_spacing(16)
        grid.set_column_homogeneous(True)
        main_box.pack_start(grid, True, True, 0)

        # Settings buttons with icons and colors
        buttons = [
            ("\uf03e", "Wallpaper", "#b8bb26", self.open_wallpaper),
            ("\uf028", "Audio", "#8ec07c", self.open_audio),
            ("\uf108", "Display", "#83a598", self.open_display),
            ("\uf0e7", "Power", "#fb4934", self.open_power),
        ]

        row = 0
        col = 0
        for icon, label, color, callback in buttons:
            btn = self.create_card_button(icon, label, color)
            btn.connect("clicked", callback)
            grid.attach(btn, col, row, 1, 1)

            col += 1
            if col > 1:  # 2 columns
                col = 0
                row += 1

        # Add main_box to scrolled window
        scrolled.add(main_box)

        # Add scrolled window to stack
        self.stack.add_named(scrolled, "main")

        # Fade in animation
        self.set_opacity(0)
        GLib.timeout_add(10, self.fade_in)

        # Force hide back button and folder button after window is realized
        self.connect(
            "realize",
            lambda w: (
                self.back_button_box.set_visible(False),
                self.folder_button_box.set_visible(False),
            ),
        )

    def create_wallpaper_picker(self):
        """Create the wallpaper picker page"""
        wallpaper_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        wallpaper_box.set_margin_top(20)
        wallpaper_box.set_margin_bottom(20)
        wallpaper_box.set_margin_start(30)
        wallpaper_box.set_margin_end(30)

        # Header with title
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="600">Choose Wallpaper</span>')
        title.get_style_context().add_class("title-label")
        title.set_halign(Gtk.Align.START)
        header.pack_start(title, False, False, 0)

        wallpaper_box.pack_start(header, False, False, 10)

        # Scrolled window for wallpapers
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        # FlowBox - simple and works
        self.wallpaper_flow = Gtk.FlowBox()
        self.wallpaper_flow.set_valign(Gtk.Align.START)
        self.wallpaper_flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.wallpaper_flow.set_row_spacing(0)
        self.wallpaper_flow.set_column_spacing(0)

        # Controls on header: refresh button
        refresh_btn = Gtk.Button(label="↻ Refresh")
        refresh_btn.get_style_context().add_class("apply-button")
        refresh_btn.connect("clicked", lambda w: self.reload_wallpapers())
        header.pack_end(refresh_btn, False, False, 0)

        scrolled.add(self.wallpaper_flow)
        wallpaper_box.pack_start(scrolled, True, True, 0)

        # Add to stack
        self.stack.add_named(wallpaper_box, "wallpapers")

    def load_wallpapers(self):
        """Load wallpapers from directory"""
        if not os.path.exists(self.wallpaper_dir):
            os.makedirs(self.wallpaper_dir)
            return

        patterns = ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        wallpapers = []
        for pattern in patterns:
            wallpapers.extend(glob.glob(os.path.join(self.wallpaper_dir, pattern)))

        for wallpaper_path in sorted(wallpapers):
            card = self.create_wallpaper_card(wallpaper_path)
            self.wallpaper_flow.add(card)

    def reload_wallpapers(self):
        """Clear and reload wallpaper thumbnails"""
        for child in self.wallpaper_flow.get_children():
            self.wallpaper_flow.remove(child)
        self.load_wallpapers()
        self.wallpaper_flow.show_all()

    def create_wallpaper_card(self, wallpaper_path):
        """Create a card for each wallpaper - uniform size, maintain aspect ratio"""
        card = Gtk.Button()
        card.get_style_context().add_class("wallpaper-card")
        card.connect("clicked", lambda w: self.set_wallpaper(wallpaper_path))
        card.set_relief(Gtk.ReliefStyle.NONE)

        # Load and scale image - maintain aspect ratio, crop to fit
        try:
            # Load original
            original_pixbuf = GdkPixbuf.Pixbuf.new_from_file(wallpaper_path)

            # Target size
            target_width = 280
            target_height = 157  # 16:9 aspect ratio

            # Calculate scaling to cover the target area
            orig_width = original_pixbuf.get_width()
            orig_height = original_pixbuf.get_height()

            scale_w = target_width / orig_width
            scale_h = target_height / orig_height
            scale = max(scale_w, scale_h)  # Scale to cover

            # Scale the image
            scaled_width = int(orig_width * scale)
            scaled_height = int(orig_height * scale)
            scaled_pixbuf = original_pixbuf.scale_simple(
                scaled_width, scaled_height, GdkPixbuf.InterpType.BILINEAR
            )

            # Crop to center
            offset_x = (scaled_width - target_width) // 2
            offset_y = (scaled_height - target_height) // 2

            cropped_pixbuf = GdkPixbuf.Pixbuf.new(
                GdkPixbuf.Colorspace.RGB,
                scaled_pixbuf.get_has_alpha(),
                8,
                target_width,
                target_height,
            )

            scaled_pixbuf.copy_area(
                offset_x, offset_y, target_width, target_height, cropped_pixbuf, 0, 0
            )

            # Create image and force EXACT size
            image = Gtk.Image.new_from_pixbuf(cropped_pixbuf)
            image.set_size_request(target_width, target_height)

            # Wrap in box to force exact dimensions
            box = Gtk.Box()
            box.set_size_request(target_width, target_height)
            box.pack_start(image, False, False, 0)
            card.add(box)

            # Force card size too
            card.set_size_request(target_width, target_height)
        except Exception as e:
            print(f"Error loading {wallpaper_path}: {e}")
            label = Gtk.Label(label="Error")
            card.add(label)

        return card

    def set_wallpaper(self, wallpaper_path):
        """Set the selected wallpaper"""
        try:
            ran_any = False
            if self.has_feh:
                subprocess.run(["feh", "--bg-fill", wallpaper_path], check=True)
                ran_any = True
            if self.has_nitrogen:
                subprocess.run(
                    ["nitrogen", "--set-zoom-fill", wallpaper_path, "--save"],
                    check=True,
                )
                ran_any = True
            if ran_any:
                if self.has_notify:
                    subprocess.run(
                        [
                            "notify-send",
                            "Wallpaper Changed!",
                            os.path.basename(wallpaper_path),
                        ]
                    )
            else:
                if self.has_notify:
                    subprocess.run(
                        [
                            "notify-send",
                            "Error",
                            "Install feh or nitrogen to set wallpapers",
                        ]
                    )
        except Exception as e:
            if self.has_notify:
                subprocess.run(
                    ["notify-send", "Error", f"Failed to set wallpaper: {str(e)}"]
                )

    def choose_wallpaper_directory(self, widget):
        """Open directory chooser dialog"""
        dialog = Gtk.FileChooserDialog(
            title="Choose Wallpaper Folder",
            parent=self,
            action=Gtk.FileChooserAction.SELECT_FOLDER,
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL,
            Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN,
            Gtk.ResponseType.OK,
        )

        # Set current directory
        dialog.set_current_folder(self.wallpaper_dir)

        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            new_dir = dialog.get_filename()
            self.wallpaper_dir = new_dir
            
            # Save to preferences
            self.prefs["wallpaper_dir"] = new_dir
            self.save_prefs()

            # Clear and reload wallpapers
            for child in self.wallpaper_flow.get_children():
                self.wallpaper_flow.remove(child)

            self.load_wallpapers()
            self.wallpaper_flow.show_all()

            # Show notification
            if self.has_notify:
                subprocess.run(
                    [
                        "notify-send",
                        "Folder Changed",
                        f"Now showing wallpapers from:\n{new_dir}",
                    ]
                )

        dialog.destroy()

    def fade_in(self):
        opacity = self.get_opacity()
        if opacity < 1.0:
            self.set_opacity(opacity + 0.05)
            return True
        return False

    def toggle_maximize(self, widget):
        """Toggle window maximize state"""
        if self.is_maximized():
            self.unmaximize()
        else:
            self.maximize()

    def on_titlebar_clicked(self, widget, event):
        """Make window draggable by titlebar"""
        if event.button == 1:  # Left click
            self.begin_move_drag(
                event.button, int(event.x_root), int(event.y_root), event.time
            )

    def draw_circle(self, widget, cr, color):
        """Draw a perfect circle for window buttons"""
        import cairo

        # Clear background
        cr.set_operator(cairo.OPERATOR_CLEAR)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        # Parse hex color
        r = int(color[1:3], 16) / 255.0
        g = int(color[3:5], 16) / 255.0
        b = int(color[5:7], 16) / 255.0

        # Draw circle
        cr.arc(6, 6, 5.5, 0, 2 * 3.14159)  # x, y, radius, start_angle, end_angle
        cr.set_source_rgb(r, g, b)
        cr.fill()

        return True

    def create_card_button(self, icon, text, color):
        """Create a modern card-style button with custom color"""
        btn = Gtk.Button()
        btn.get_style_context().add_class("settings-card")
        btn.set_size_request(220, 140)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        vbox.set_halign(Gtk.Align.CENTER)
        vbox.set_valign(Gtk.Align.CENTER)

        # Icon with colored background circle
        icon_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        icon_box.set_halign(Gtk.Align.CENTER)

        icon_label = Gtk.Label()
        icon_label.set_markup(f'<span size="35000" foreground="#fe8019">{icon}</span>')
        icon_label.get_style_context().add_class("card-icon")
        icon_box.pack_start(icon_label, False, False, 0)

        vbox.pack_start(icon_box, False, False, 0)

        # Text label
        text_label = Gtk.Label(label=text)
        text_label.get_style_context().add_class("card-text")
        vbox.pack_start(text_label, False, False, 0)

        btn.add(vbox)
        return btn

    def open_wallpaper(self, widget):
        self.stack.set_visible_child_name("wallpapers")
        self.back_button_box.set_visible(True)  # Show back button
        self.folder_button_box.set_visible(True)  # Show folder button
        # Lazy-load wallpapers when opening page
        if (
            hasattr(self, "wallpaper_flow")
            and len(self.wallpaper_flow.get_children()) == 0
        ):
            self.load_wallpapers()
            self.wallpaper_flow.show_all()

    def go_back(self):
        """Go back to main menu"""
        self.stack.set_visible_child_name("main")
        self.back_button_box.set_visible(False)  # Hide back button
        self.folder_button_box.set_visible(False)  # Hide folder button

    def open_audio(self, widget):
        # Navigate to audio page
        self.stack.set_visible_child_name("audio")
        self.back_button_box.set_visible(True)

    def create_audio_settings(self):
        """Create integrated audio settings page"""
        audio_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        audio_box.set_margin_top(20)
        audio_box.set_margin_bottom(20)
        audio_box.set_margin_start(40)
        audio_box.set_margin_end(40)

        # Title
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="600" foreground="#fe8019"></span> <span size="x-large" weight="600">Audio Settings</span>')
        title.get_style_context().add_class("title-label")
        title.set_halign(Gtk.Align.START)
        audio_box.pack_start(title, False, False, 0)

        # Audio system badge
        audio_system = self.detect_audio_system() if self.has_pactl else "Unavailable"
        system_label = Gtk.Label(label=f"Using: {audio_system}")
        system_label.get_style_context().add_class("system-label")
        audio_box.pack_start(system_label, False, False, 0)

        # Output device selection
        output_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        output_card.get_style_context().add_class("volume-card")

        output_label = Gtk.Label(label="Output Device")
        output_label.get_style_context().add_class("device-label")
        output_label.set_halign(Gtk.Align.START)
        output_card.pack_start(output_label, False, False, 0)

        self.output_combo = Gtk.ComboBoxText()
        self.output_combo.set_wrap_width(1)  # Force single column
        if self.has_pactl:
            self.load_output_devices()
            self.output_combo.connect("changed", self.on_output_changed)
        else:
            self.output_combo.set_sensitive(False)
        output_card.pack_start(self.output_combo, False, False, 0)

        audio_box.pack_start(output_card, False, False, 0)

        # Input device selection
        input_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        input_card.get_style_context().add_class("volume-card")

        input_label = Gtk.Label(label="Input Device")
        input_label.get_style_context().add_class("device-label")
        input_label.set_halign(Gtk.Align.START)
        input_card.pack_start(input_label, False, False, 0)

        self.input_combo = Gtk.ComboBoxText()
        self.input_combo.set_wrap_width(1)  # Force single column
        if self.has_pactl:
            self.load_input_devices()
            self.input_combo.connect("changed", self.on_input_changed)
        else:
            self.input_combo.set_sensitive(False)
        input_card.pack_start(self.input_combo, False, False, 0)

        audio_box.pack_start(input_card, False, False, 0)

        # Volume card
        volume_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        volume_card.get_style_context().add_class("volume-card")

        # Volume label and value
        label_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        vol_label = Gtk.Label(label="Volume")
        vol_label.get_style_context().add_class("volume-label")
        label_box.pack_start(vol_label, False, False, 0)

        self.volume_value_label = Gtk.Label(label="50%")
        self.volume_value_label.get_style_context().add_class("volume-value")
        label_box.pack_end(self.volume_value_label, False, False, 0)

        volume_card.pack_start(label_box, False, False, 0)

        # Volume slider (0-150%)
        self.volume_scale = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0, 150, 1
        )
        self.volume_scale.set_draw_value(False)
        self.volume_scale.connect("value-changed", self.on_volume_changed)
        self.volume_scale.add_mark(100, Gtk.PositionType.BOTTOM, "100%")
        if not self.has_pactl:
            self.volume_scale.set_sensitive(False)
        volume_card.pack_start(self.volume_scale, False, False, 0)

        # Mute button
        self.mute_button = Gtk.Button(label="🔇 Mute")
        self.mute_button.get_style_context().add_class("mute-button")
        self.mute_button.connect("clicked", self.toggle_mute)
        if not self.has_pactl:
            self.mute_button.set_sensitive(False)
        volume_card.pack_start(self.mute_button, False, False, 10)

        audio_box.pack_start(volume_card, False, False, 0)

        # Refresh controls
        refresh_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        refresh_btn = Gtk.Button(label="↻ Refresh Devices")
        refresh_btn.get_style_context().add_class("apply-button")
        refresh_btn.connect("clicked", lambda w: self.refresh_audio_devices())
        refresh_row.pack_start(refresh_btn, False, False, 0)
        audio_box.pack_start(refresh_row, False, False, 0)

        # Load current volume
        if self.has_pactl:
            self.load_current_volume()
            # Update volume periodically
            GLib.timeout_add(1000, self.update_volume)

        # Add to stack
        self.stack.add_named(audio_box, "audio")

    def load_current_volume(self):
        """Load current volume from pactl"""
        try:
            output = subprocess.check_output(
                ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]
            ).decode()
            match = re.search(r"(\d+)%", output)
            if match:
                volume = int(match.group(1))
                self.volume_scale.set_value(volume)
                self.volume_value_label.set_text(f"{volume}%")

            # Check mute status
            mute_output = subprocess.check_output(
                ["pactl", "get-sink-mute", "@DEFAULT_SINK@"]
            ).decode()
            if "yes" in mute_output:
                self.mute_button.set_label("🔊 Unmute")
                self.mute_button.get_style_context().remove_class("mute-button")
                self.mute_button.get_style_context().add_class("unmute-button")
            else:
                self.mute_button.set_label("🔇 Mute")
                self.mute_button.get_style_context().remove_class("unmute-button")
                self.mute_button.get_style_context().add_class("mute-button")
        except Exception as e:
            print(f"Error loading volume: {e}")

    def update_volume(self):
        """Update volume display periodically"""
        try:
            output = subprocess.check_output(
                ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]
            ).decode()
            match = re.search(r"(\d+)%", output)
            if match:
                volume = int(match.group(1))
                # Avoid fighting the slider while user is adjusting
                if (
                    not hasattr(self, "pending_volume_timeout")
                    or self.pending_volume_timeout is None
                ):
                    if abs(self.volume_scale.get_value() - volume) > 2:
                        self.volume_scale.set_value(volume)
                        self.volume_value_label.set_text(f"{volume}%")
        except:
            pass
        return True

    def on_volume_changed(self, scale):
        """Handle volume slider change"""
        if not self.has_pactl:
            return
        volume = int(scale.get_value())
        self.volume_value_label.set_text(f"{volume}%")
        # Debounce applying volume to avoid spamming pactl
        if (
            hasattr(self, "pending_volume_timeout")
            and self.pending_volume_timeout is not None
        ):
            GLib.source_remove(self.pending_volume_timeout)
            self.pending_volume_timeout = None

        def apply_volume():
            try:
                subprocess.run(
                    ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{volume}%"],
                    check=True,
                )
            except Exception as e:
                print(f"Error setting volume: {e}")
            self.pending_volume_timeout = None
            return False

        self.pending_volume_timeout = GLib.timeout_add(150, apply_volume)

    def toggle_mute(self, widget):
        """Toggle mute/unmute"""
        try:
            subprocess.run(
                ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"], check=True
            )
            GLib.timeout_add(100, self.load_current_volume)
        except Exception as e:
            print(f"Error toggling mute: {e}")

    def detect_audio_system(self):
        """Detect if using PipeWire or PulseAudio"""
        try:
            output = subprocess.check_output(["pactl", "info"]).decode()
            if "PipeWire" in output:
                return "PipeWire"
            else:
                return "PulseAudio"
        except:
            return "Unknown"

    def load_output_devices(self):
        """Load available output devices"""
        try:
            full_output = subprocess.check_output(["pactl", "list", "sinks"]).decode()
            self.output_devices = []

            current_name = None
            current_desc = None

            for line in full_output.split("\n"):
                if line.startswith("Sink #"):
                    if current_name and current_desc:
                        self.output_devices.append(
                            {"name": current_name, "desc": current_desc}
                        )
                        self.output_combo.append_text(current_desc)
                    current_name = None
                    current_desc = None
                elif "Name:" in line and current_name is None:
                    current_name = line.split("Name:")[1].strip()
                elif "Description:" in line and current_desc is None:
                    current_desc = line.split("Description:")[1].strip()

            if current_name and current_desc:
                self.output_devices.append({"name": current_name, "desc": current_desc})
                self.output_combo.append_text(current_desc)

            try:
                default_output = (
                    subprocess.check_output(["pactl", "get-default-sink"])
                    .decode()
                    .strip()
                )
                for i, device in enumerate(self.output_devices):
                    if device["name"] == default_output:
                        self.output_combo.set_active(i)
                        break
            except:
                if self.output_devices:
                    self.output_combo.set_active(0)
        except Exception as e:
            print(f"Error loading output devices: {e}")

    def load_input_devices(self):
        """Load available input devices"""
        try:
            full_output = subprocess.check_output(["pactl", "list", "sources"]).decode()
            self.input_devices = []

            current_name = None
            current_desc = None

            for line in full_output.split("\n"):
                if line.startswith("Source #"):
                    if current_name and current_desc and ".monitor" not in current_name:
                        self.input_devices.append(
                            {"name": current_name, "desc": current_desc}
                        )
                        self.input_combo.append_text(current_desc)
                    current_name = None
                    current_desc = None
                elif "Name:" in line and current_name is None:
                    current_name = line.split("Name:")[1].strip()
                elif "Description:" in line and current_desc is None:
                    current_desc = line.split("Description:")[1].strip()

            if current_name and current_desc and ".monitor" not in current_name:
                self.input_devices.append({"name": current_name, "desc": current_desc})
                self.input_combo.append_text(current_desc)

            try:
                default_input = (
                    subprocess.check_output(["pactl", "get-default-source"])
                    .decode()
                    .strip()
                )
                for i, device in enumerate(self.input_devices):
                    if device["name"] == default_input:
                        self.input_combo.set_active(i)
                        break
            except:
                if self.input_devices:
                    self.input_combo.set_active(0)
        except Exception as e:
            print(f"Error loading input devices: {e}")

    def on_output_changed(self, combo):
        """Handle output device change"""
        idx = combo.get_active()
        if idx >= 0 and idx < len(self.output_devices):
            device = self.output_devices[idx]
            try:
                subprocess.run(
                    ["pactl", "set-default-sink", device["name"]], check=True
                )
                subprocess.run(["notify-send", "Output Changed", device["desc"]])
            except Exception as e:
                print(f"Error changing output: {e}")

    def on_input_changed(self, combo):
        """Handle input device change"""
        idx = combo.get_active()
        if idx >= 0 and idx < len(self.input_devices):
            device = self.input_devices[idx]
            try:
                subprocess.run(
                    ["pactl", "set-default-source", device["name"]], check=True
                )
                subprocess.run(["notify-send", "Input Changed", device["desc"]])
            except Exception as e:
                print(f"Error changing input: {e}")

    def refresh_audio_devices(self):
        """Refresh audio device lists"""
        if self.has_pactl:
            # Clear current devices
            self.output_combo.remove_all()
            self.input_combo.remove_all()

            # Reload devices
            self.load_output_devices()
            self.load_input_devices()

            # Show notification
            if self.has_notify:
                subprocess.run(
                    ["notify-send", "Audio Devices", "Device list refreshed"]
                )

    def open_display(self, widget):
        # Navigate to display page
        self.stack.set_visible_child_name("display")
        self.back_button_box.set_visible(True)
        # Load display info when opened
        if self.has_xrandr:
            self.load_display_info()
        else:
            self.display_info_label.set_markup(
                '<span color="#fb4934">xrandr not found. Install xorg-xrandr.</span>'
            )

    def create_display_settings(self):
        """Create FUTURISTIC display settings page"""
        # Scrolled window for display settings
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        display_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        display_box.set_margin_top(30)
        display_box.set_margin_bottom(30)
        display_box.set_margin_start(50)
        display_box.set_margin_end(50)

        # HERO SECTION - Current Display Info
        hero_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        hero_card.get_style_context().add_class("display-hero")

        # Current resolution - BIG and BOLD
        self.current_display_label = Gtk.Label()
        self.current_display_label.set_markup(
            '<span size="50000" weight="700" foreground="#fabd2f">1920x1080</span>'
        )
        self.current_display_label.get_style_context().add_class("display-resolution")
        self.current_display_label.set_halign(Gtk.Align.CENTER)
        hero_card.pack_start(self.current_display_label, False, False, 20)

        # Refresh rate - bright and visible
        self.refresh_rate_badge = Gtk.Label()
        self.refresh_rate_badge.set_markup(
            '<span size="x-large" weight="700" foreground="#b8bb26">60 Hz</span>'
        )
        self.refresh_rate_badge.get_style_context().add_class("refresh-badge-text")
        self.refresh_rate_badge.set_halign(Gtk.Align.CENTER)
        hero_card.pack_start(self.refresh_rate_badge, False, False, 0)

        display_box.pack_start(hero_card, False, False, 0)

        # CONTROL PANEL - Grid layout for modern look
        control_panel = Gtk.Grid()
        control_panel.set_row_spacing(20)
        control_panel.set_column_spacing(20)
        control_panel.set_halign(Gtk.Align.CENTER)
        control_panel.get_style_context().add_class("control-panel")

        # Display selector card
        display_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        display_card.get_style_context().add_class("control-card")

        display_header = Gtk.Label()
        display_header.set_markup(
            '<span weight="600" size="large" foreground="#83a598">🖥 Display</span>'
        )
        display_header.set_halign(Gtk.Align.START)
        display_card.pack_start(display_header, False, False, 0)

        self.display_combo = Gtk.ComboBoxText()
        display_card.pack_start(self.display_combo, False, False, 0)

        control_panel.attach(display_card, 0, 0, 2, 1)

        # Resolution selector card
        res_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        res_card.get_style_context().add_class("control-card")

        res_header = Gtk.Label()
        res_header.set_markup(
            '<span weight="600" size="large" foreground="#b8bb26">📐 Resolution</span>'
        )
        res_header.set_halign(Gtk.Align.START)
        res_card.pack_start(res_header, False, False, 0)

        # Scrolled window for resolution buttons
        res_scroll = Gtk.ScrolledWindow()
        res_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        res_scroll.set_size_request(-1, 200)

        self.resolution_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        res_scroll.add(self.resolution_box)
        res_card.pack_start(res_scroll, True, True, 0)

        control_panel.attach(res_card, 0, 1, 1, 1)

        # Refresh rate selector card
        rate_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        rate_card.get_style_context().add_class("control-card")

        rate_header = Gtk.Label()
        rate_header.set_markup(
            '<span weight="600" size="large" foreground="#fe8019">⚡ Refresh Rate</span>'
        )
        rate_header.set_halign(Gtk.Align.START)
        rate_card.pack_start(rate_header, False, False, 0)

        # Scrolled window for refresh rate buttons
        rate_scroll = Gtk.ScrolledWindow()
        rate_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        rate_scroll.set_size_request(-1, 200)

        self.rate_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        rate_scroll.add(self.rate_box)
        rate_card.pack_start(rate_scroll, True, True, 0)

        control_panel.attach(rate_card, 1, 1, 1, 1)

        display_box.pack_start(control_panel, False, False, 0)

        # APPLY BUTTON - Futuristic style
        apply_btn = Gtk.Button()
        apply_btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        apply_btn_box.set_halign(Gtk.Align.CENTER)

        apply_icon = Gtk.Label()
        apply_icon.set_markup('<span size="large">✓</span>')
        apply_btn_box.pack_start(apply_icon, False, False, 0)

        apply_text = Gtk.Label()
        apply_text.set_markup('<span size="large" weight="600">APPLY CHANGES</span>')
        apply_btn_box.pack_start(apply_text, False, False, 0)

        apply_btn.add(apply_btn_box)
        apply_btn.get_style_context().add_class("futuristic-apply-button")
        apply_btn.connect("clicked", self.apply_display_settings)
        display_box.pack_start(apply_btn, False, False, 0)

        # Status label
        self.display_info_label = Gtk.Label()
        self.display_info_label.set_markup(
            '<span size="small" alpha="70%">Configure your display settings</span>'
        )
        self.display_info_label.get_style_context().add_class("status-label")
        display_box.pack_start(self.display_info_label, False, False, 0)

        # Action row with refresh
        action_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        refresh_btn = Gtk.Button(label="↻ Refresh Displays")
        refresh_btn.get_style_context().add_class("apply-button")
        refresh_btn.connect(
            "clicked",
            lambda w: self.load_display_info()
            if self.has_xrandr
            else self.display_info_label.set_markup(
                '<span color="#fb4934">xrandr not found. Install xorg-xrandr.</span>'
            ),
        )
        action_row.pack_start(refresh_btn, False, False, 0)
        display_box.pack_start(action_row, False, False, 0)

        # Add display_box to scrolled window
        scrolled.add(display_box)

        # Add scrolled window to stack
        self.stack.add_named(scrolled, "display")

    def load_display_info(self):
        """Load display information using xrandr"""
        try:
            output = subprocess.check_output(["xrandr", "--query"]).decode()
            self.displays = []
            current_display = None

            for line in output.split("\n"):
                if " connected" in line:
                    parts = line.split()
                    display_name = parts[0]

                    current_res = None
                    current_rate = None
                    for part in parts:
                        if "x" in part and "+" in part:
                            current_res = part.split("+")[0]

                    current_display = {
                        "name": display_name,
                        "modes": [],
                        "current_res": current_res,
                        "current_rate": None,
                    }
                    self.displays.append(current_display)
                elif current_display and line.strip() and line[0] == " ":
                    parts = line.strip().split()
                    if parts and "x" in parts[0]:
                        resolution = parts[0]
                        rates = []
                        for part in parts[1:]:
                            if re.match(r"^\d+\.\d+[\*\+]*$", part):
                                is_current = "*" in part
                                rate_clean = part.replace("*", "").replace("+", "")
                                rates.append(rate_clean)

                                if is_current:
                                    if resolution == current_display["current_res"]:
                                        current_display["current_rate"] = rate_clean
                                    elif current_display["current_res"] is None:
                                        current_display["current_res"] = resolution
                                        current_display["current_rate"] = rate_clean

                        if rates:
                            current_display["modes"].append(
                                {"resolution": resolution, "rates": rates}
                            )

            # Populate display combo
            self.display_combo.remove_all()
            for display in self.displays:
                self.display_combo.append_text(display["name"])
            if self.displays:
                self.display_combo.set_active(0)
                self.display_combo.connect(
                    "changed", self.on_display_changed_integrated
                )
                self.on_display_changed_integrated(self.display_combo)

        except Exception as e:
            print(f"Error loading displays: {e}")

    def on_display_changed_integrated(self, combo):
        """Handle display change"""
        display_idx = combo.get_active()
        if display_idx < 0 or display_idx >= len(self.displays):
            return

        display = self.displays[display_idx]
        self.current_modes = display["modes"]

        # Clear resolution buttons
        for child in self.resolution_box.get_children():
            self.resolution_box.remove(child)

        # Add resolution buttons
        for i, mode in enumerate(display["modes"]):
            btn = Gtk.Button(label=mode["resolution"])
            btn.get_style_context().add_class("option-button")
            if mode["resolution"] == display["current_res"]:
                btn.get_style_context().add_class("option-button-active")
                self.selected_resolution_idx = i
            btn.connect(
                "clicked", lambda w, idx=i: self.on_resolution_button_clicked(idx)
            )
            self.resolution_box.pack_start(btn, False, False, 0)

        self.resolution_box.show_all()

        if display["modes"] and hasattr(self, "selected_resolution_idx"):
            self.on_resolution_button_clicked(self.selected_resolution_idx)

        # Update current display label
        if display["current_res"] and display["current_rate"]:
            self.current_display_label.set_markup(
                f'<span size="50000" weight="700" foreground="#fabd2f">{display["current_res"]}</span>'
            )
            self.refresh_rate_badge.set_markup(
                f'<span size="x-large" weight="700" foreground="#b8bb26">{display["current_rate"]} Hz</span>'
            )

    def on_resolution_button_clicked(self, res_idx):
        """Handle resolution button click"""
        if res_idx < 0 or res_idx >= len(self.current_modes):
            return

        # Update button styles
        for child in self.resolution_box.get_children():
            child.get_style_context().remove_class("option-button-active")

        buttons = self.resolution_box.get_children()
        if res_idx < len(buttons):
            buttons[res_idx].get_style_context().add_class("option-button-active")

        self.selected_resolution_idx = res_idx
        mode = self.current_modes[res_idx]
        display_idx = self.display_combo.get_active()
        display = self.displays[display_idx]

        # Clear rate buttons
        for child in self.rate_box.get_children():
            self.rate_box.remove(child)

        # Add rate buttons
        for i, rate in enumerate(mode["rates"]):
            btn = Gtk.Button(label=f"{rate} Hz")
            btn.get_style_context().add_class("option-button")
            if (
                rate == display["current_rate"]
                and mode["resolution"] == display["current_res"]
            ):
                btn.get_style_context().add_class("option-button-active")
                self.selected_rate_idx = i
            btn.connect("clicked", lambda w, idx=i: self.on_rate_button_clicked(idx))
            self.rate_box.pack_start(btn, False, False, 0)

        self.rate_box.show_all()

    def on_rate_button_clicked(self, rate_idx):
        """Handle refresh rate button click"""
        # Update button styles
        for child in self.rate_box.get_children():
            child.get_style_context().remove_class("option-button-active")

        buttons = self.rate_box.get_children()
        if rate_idx < len(buttons):
            buttons[rate_idx].get_style_context().add_class("option-button-active")

        self.selected_rate_idx = rate_idx

    def apply_display_settings(self, widget):
        """Apply display settings"""
        display_idx = self.display_combo.get_active()

        if not hasattr(self, "selected_resolution_idx") or not hasattr(
            self, "selected_rate_idx"
        ):
            self.display_info_label.set_markup(
                '<span color="#fb4934">Please select resolution and refresh rate!</span>'
            )
            return

        if display_idx < 0:
            self.display_info_label.set_markup(
                '<span color="#fb4934">Please select a display!</span>'
            )
            return

        display = self.displays[display_idx]
        resolution = self.current_modes[self.selected_resolution_idx]["resolution"]
        rate = self.current_modes[self.selected_resolution_idx]["rates"][
            self.selected_rate_idx
        ]

        try:
            cmd = [
                "xrandr",
                "--output",
                display["name"],
                "--mode",
                resolution,
                "--rate",
                rate,
            ]
            subprocess.run(cmd, check=True)
            self.display_info_label.set_markup(
                f'<span color="#b8bb26" weight="600">✓ Applied successfully!</span>'
            )

            # Update current display label
            self.current_display_label.set_markup(
                f'<span size="50000" weight="700" foreground="#fabd2f">{resolution}</span>'
            )
            self.refresh_rate_badge.set_markup(
                f'<span size="x-large" weight="700" foreground="#b8bb26">{rate} Hz</span>'
            )

            # Reload to update current settings
            GLib.timeout_add(500, self.load_display_info)
        except Exception as e:
            self.display_info_label.set_markup(
                f'<span color="#fb4934">Error: {str(e)}</span>'
            )

    def open_bluetooth(self, widget):
        # Navigate to bluetooth page
        self.stack.set_visible_child_name("bluetooth")
        self.back_button_box.set_visible(True)
        # Scan for devices when opened
        self.scan_bluetooth_devices()

    def create_bluetooth_settings(self):
        """Create integrated bluetooth settings page"""
        bluetooth_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        bluetooth_box.set_margin_top(30)
        bluetooth_box.set_margin_bottom(30)
        bluetooth_box.set_margin_start(40)
        bluetooth_box.set_margin_end(40)

        # Title
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="600">📶 Bluetooth</span>')
        title.get_style_context().add_class("title-label")
        title.set_halign(Gtk.Align.START)
        bluetooth_box.pack_start(title, False, False, 0)

        # Bluetooth toggle and status
        status_card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        status_card.get_style_context().add_class("volume-card")

        status_label = Gtk.Label()
        status_label.set_markup('<span size="large" weight="600">Bluetooth</span>')
        status_card.pack_start(status_label, False, False, 0)

        self.bt_toggle = Gtk.Switch()
        self.bt_toggle.set_active(True)
        self.bt_toggle.connect("notify::active", self.on_bluetooth_toggle)
        status_card.pack_end(self.bt_toggle, False, False, 0)

        bluetooth_box.pack_start(status_card, False, False, 0)

        # Scan button
        scan_btn = Gtk.Button(label="🔍 Scan for Devices")
        scan_btn.get_style_context().add_class("futuristic-apply-button")
        scan_btn.connect("clicked", lambda w: self.scan_bluetooth_devices())
        bluetooth_box.pack_start(scan_btn, False, False, 0)

        # Devices list
        devices_label = Gtk.Label()
        devices_label.set_markup(
            '<span size="large" weight="600">Available Devices</span>'
        )
        devices_label.set_halign(Gtk.Align.START)
        bluetooth_box.pack_start(devices_label, False, False, 0)

        # Scrolled window for devices
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(-1, 300)

        self.bt_devices_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        scrolled.add(self.bt_devices_box)
        bluetooth_box.pack_start(scrolled, True, True, 0)

        # Status label
        self.bt_status_label = Gtk.Label()
        self.bt_status_label.set_markup('<span color="#8ec07c">Ready to scan</span>')
        bluetooth_box.pack_start(self.bt_status_label, False, False, 0)

        # Add to stack
        self.stack.add_named(bluetooth_box, "bluetooth")

    def on_bluetooth_toggle(self, switch, gparam):
        """Toggle bluetooth on/off"""
        if switch.get_active():
            self.bt_status_label.set_markup(
                '<span color="#b8bb26">Bluetooth enabled</span>'
            )
            try:
                subprocess.run(["bluetoothctl", "power", "on"], check=True)
            except:
                pass
        else:
            self.bt_status_label.set_markup(
                '<span color="#fb4934">Bluetooth disabled</span>'
            )
            try:
                subprocess.run(["bluetoothctl", "power", "off"], check=True)
            except:
                pass

    def scan_bluetooth_devices(self):
        """Scan for bluetooth devices"""
        self.bt_status_label.set_markup('<span color="#fabd2f">Scanning...</span>')

        # Clear current devices
        for child in self.bt_devices_box.get_children():
            self.bt_devices_box.remove(child)

        try:
            # Start scan
            subprocess.run(["bluetoothctl", "scan", "on"], timeout=1)
        except:
            pass

        # Wait a bit then get devices
        GLib.timeout_add(3000, self.load_bluetooth_devices)

    def load_bluetooth_devices(self):
        """Load discovered bluetooth devices"""
        try:
            output = subprocess.check_output(["bluetoothctl", "devices"]).decode()

            devices_found = False
            for line in output.strip().split("\n"):
                if line.startswith("Device"):
                    devices_found = True
                    parts = line.split(" ", 2)
                    if len(parts) >= 3:
                        mac = parts[1]
                        name = parts[2]

                        device_card = self.create_bt_device_card(mac, name)
                        self.bt_devices_box.pack_start(device_card, False, False, 0)

            self.bt_devices_box.show_all()

            if devices_found:
                self.bt_status_label.set_markup(
                    '<span color="#b8bb26">Scan complete</span>'
                )
            else:
                self.bt_status_label.set_markup(
                    '<span color="#928374">No devices found</span>'
                )
        except Exception as e:
            self.bt_status_label.set_markup(
                f'<span color="#fb4934">Error: {str(e)}</span>'
            )

        return False

    def create_bt_device_card(self, mac, name):
        """Create a card for each bluetooth device"""
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        card.get_style_context().add_class("control-card")

        # Device info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)

        name_label = Gtk.Label()
        name_label.set_markup(f'<span weight="600">{name}</span>')
        name_label.set_halign(Gtk.Align.START)
        info_box.pack_start(name_label, False, False, 0)

        mac_label = Gtk.Label(label=mac)
        mac_label.set_halign(Gtk.Align.START)
        mac_label.get_style_context().add_class("status-label")
        info_box.pack_start(mac_label, False, False, 0)

        card.pack_start(info_box, True, True, 0)

        # Connect button
        connect_btn = Gtk.Button(label="Connect")
        connect_btn.get_style_context().add_class("apply-button")
        connect_btn.connect("clicked", lambda w: self.connect_bt_device(mac, name))
        card.pack_end(connect_btn, False, False, 0)

        return card

    def connect_bt_device(self, mac, name):
        """Connect to a bluetooth device"""
        self.bt_status_label.set_markup(
            f'<span color="#fabd2f">Connecting to {name}...</span>'
        )

        try:
            # Pair and connect
            subprocess.run(["bluetoothctl", "pair", mac], timeout=10)
            subprocess.run(["bluetoothctl", "connect", mac], timeout=10, check=True)
            self.bt_status_label.set_markup(
                f'<span color="#b8bb26">✓ Connected to {name}</span>'
            )
            subprocess.run(["notify-send", "Bluetooth", f"Connected to {name}"])
        except Exception as e:
            self.bt_status_label.set_markup(
                f'<span color="#fb4934">Failed to connect</span>'
            )
            subprocess.run(
                ["notify-send", "Bluetooth Error", f"Could not connect to {name}"]
            )

    def open_network(self, widget):
        # Navigate to network page
        self.stack.set_visible_child_name("network")
        self.back_button_box.set_visible(True)
        # Load network info when opened
        self.load_network_info()

    def create_network_settings(self):
        """Create integrated network settings page"""
        # Scrolled window for network page
        scrolled_main = Gtk.ScrolledWindow()
        scrolled_main.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS)
        scrolled_main.set_hexpand(True)
        scrolled_main.set_vexpand(True)

        network_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        network_box.set_margin_top(30)
        network_box.set_margin_bottom(80)
        network_box.set_margin_start(40)
        network_box.set_margin_end(40)

        # Title
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="600" foreground="#fe8019"></span> <span size="x-large" weight="600">Network</span>')
        title.get_style_context().add_class("title-label")
        title.set_halign(Gtk.Align.START)
        network_box.pack_start(title, False, False, 0)

        # Connection status hero card
        status_hero = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        status_hero.get_style_context().add_class("display-hero")

        # Connection icon
        self.net_icon = Gtk.Label()
        self.net_icon.set_markup('<span size="50000" foreground="#fe8019"></span>')
        self.net_icon.set_halign(Gtk.Align.CENTER)
        status_hero.pack_start(self.net_icon, False, False, 10)

        # Connection status
        self.net_status_label = Gtk.Label()
        self.net_status_label.set_markup(
            '<span size="xx-large" weight="700" foreground="#b8bb26">Connected</span>'
        )
        self.net_status_label.set_halign(Gtk.Align.CENTER)
        status_hero.pack_start(self.net_status_label, False, False, 0)

        # IP address
        self.net_ip_label = Gtk.Label()
        self.net_ip_label.set_markup(
            '<span size="large" foreground="#83a598">192.168.1.100</span>'
        )
        self.net_ip_label.set_halign(Gtk.Align.CENTER)
        status_hero.pack_start(self.net_ip_label, False, False, 0)

        network_box.pack_start(status_hero, False, False, 0)

        # Network interfaces
        interfaces_label = Gtk.Label()
        interfaces_label.set_markup(
            '<span size="large" weight="600">Network Interfaces</span>'
        )
        interfaces_label.set_halign(Gtk.Align.START)
        network_box.pack_start(interfaces_label, False, False, 0)

        # Scrolled window for interfaces
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(-1, 250)
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(False)

        self.net_interfaces_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=12
        )
        scrolled.add(self.net_interfaces_box)
        network_box.pack_start(scrolled, True, True, 0)

        # Action buttons (keep only Show/Hide IPs here)
        actions_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        actions_box.set_halign(Gtk.Align.CENTER)
        actions_box.set_margin_top(10)
        actions_box.set_margin_bottom(10)

        # Show/Hide IP toggle
        self.show_ip_btn = Gtk.Button(label="👁 Show IPs")
        self.show_ip_btn.get_style_context().add_class("apply-button")
        self.show_ip_btn.connect("clicked", self.toggle_ip_visibility)
        self.show_ips = False
        actions_box.pack_start(self.show_ip_btn, True, True, 0)

        network_box.pack_start(actions_box, False, False, 0)

        # Bottom spacer to ensure last elements are reachable when scrolling
        spacer = Gtk.Box()
        spacer.set_size_request(-1, 60)
        network_box.pack_start(spacer, False, False, 0)

        # Add network_box to scrolled window (let GTK add a viewport automatically)
        scrolled_main.add(network_box)

        # Add to stack
        self.stack.add_named(scrolled_main, "network")

    def load_prefs(self):
        try:
            if os.path.exists(self.prefs_path):
                with open(self.prefs_path, "r") as f:
                    return json.load(f)
        except Exception:
            pass
        return {}

    def save_prefs(self):
        try:
            os.makedirs(os.path.dirname(self.prefs_path), exist_ok=True)
            with open(self.prefs_path, "w") as f:
                json.dump(self.prefs, f)
        except Exception:
            pass

    def get_dns_servers_from_selection(self):
        label = self.dns_combo.get_active_text() or ""
        if "Cloudflare" in label:
            return ["1.1.1.1", "1.0.0.1"]
        if "Google" in label:
            return ["8.8.8.8", "8.8.4.4"]
        if "OpenDNS" in label:
            return ["208.67.222.222", "208.67.220.220"]
        if "Quad9" in label:
            return ["9.9.9.9", "149.112.112.112"]
        if "AdGuard" in label:
            return ["94.140.14.14", "94.140.15.15"]
        return []

    def apply_selected_dns(self, widget):
        servers = self.get_dns_servers_from_selection()
        if not servers:
            self.bt_status_label.set_markup(
                '<span color="#fb4934">No DNS selected</span>'
            )
            return
        try:
            if self.has_nmcli:
                self.apply_dns_via_nmcli(servers)
            elif self.has_resolvectl:
                self.apply_dns_via_resolvectl(servers)
            else:
                self.net_status_label.set_markup(
                    '<span color="#fb4934">Install nmcli (NetworkManager) or resolvectl (systemd-resolved)</span>'
                )
                return
            self.net_status_label.set_markup(
                '<span color="#b8bb26">✓ DNS applied</span>'
            )
            # Persist selection
            self.prefs["dns_preset"] = self.dns_combo.get_active_text()
            self.prefs["dns_custom"] = self.custom_dns_entry.get_text()
            self.save_prefs()
        except Exception as e:
            self.net_status_label.set_markup(
                f'<span color="#fb4934">DNS error: {str(e)}</span>'
            )

    def reset_dns_to_auto(self, widget):
        try:
            if self.has_nmcli:
                # For all active IPv4 connections: set dns auto
                active = (
                    subprocess.check_output(
                        [
                            "nmcli",
                            "-t",
                            "-f",
                            "NAME,TYPE,DEVICE",
                            "con",
                            "show",
                            "--active",
                        ]
                    )
                    .decode()
                    .strip()
                    .split("\n")
                )
                for line in active:
                    if not line:
                        continue
                    name, ctype, dev = (line.split(":") + ["", "", ""])[:3]
                    if ctype in ("wifi", "ethernet"):
                        subprocess.run(
                            ["nmcli", "con", "mod", name, "ipv4.ignore-auto-dns", "no"],
                            check=True,
                        )
                        subprocess.run(
                            ["nmcli", "con", "mod", name, "ipv4.dns", '""'], check=True
                        )
                        subprocess.run(["nmcli", "con", "up", name], check=True)
                self.net_status_label.set_markup(
                    '<span color="#b8bb26">✓ DNS reset to automatic</span>'
                )
            elif self.has_resolvectl:
                # Clear per-link DNS by setting empty list on all up links
                links = subprocess.check_output(["resolvectl", "status"]).decode()
                for line in links.split("\n"):
                    if line.strip().startswith("Link") and "(" in line:
                        # Example: Link 2 (wlo1)
                        iface = line.split("(")[-1].split(")")[0]
                        subprocess.run(["resolvectl", "dns", iface], check=False)
                self.net_status_label.set_markup(
                    '<span color="#b8bb26">✓ DNS reset requested</span>'
                )
            else:
                self.net_status_label.set_markup(
                    '<span color="#fb4934">No supported DNS tool found</span>'
                )
        except Exception as e:
            self.net_status_label.set_markup(
                f'<span color="#fb4934">DNS reset error: {str(e)}</span>'
            )

    def apply_dns_via_nmcli(self, servers):
        # Apply to all active IPv4 network connections (wifi/ethernet)
        active = (
            subprocess.check_output(
                ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "con", "show", "--active"]
            )
            .decode()
            .strip()
            .split("\n")
        )
        for line in active:
            if not line:
                continue
            name, ctype, dev = (line.split(":") + ["", "", ""])[:3]
            if ctype in ("wifi", "ethernet"):
                # IPv4
                subprocess.run(
                    ["nmcli", "con", "mod", name, "ipv4.ignore-auto-dns", "yes"],
                    check=True,
                )
                subprocess.run(
                    ["nmcli", "con", "mod", name, "ipv4.dns", ",".join(servers)],
                    check=True,
                )
                # IPv6: apply where valid (IPv6 servers will be included if specified)
                subprocess.run(
                    ["nmcli", "con", "mod", name, "ipv6.ignore-auto-dns", "yes"],
                    check=True,
                )
                subprocess.run(
                    ["nmcli", "con", "mod", name, "ipv6.dns", ",".join(servers)],
                    check=False,
                )
                subprocess.run(["nmcli", "con", "up", name], check=True)

    def apply_dns_via_resolvectl(self, servers):
        # Apply DNS to the default route interface(s)
        routes = (
            subprocess.check_output(["ip", "route", "show", "default"])
            .decode()
            .strip()
            .split("\n")
        )
        ifaces = []
        for r in routes:
            parts = r.split()
            if "dev" in parts:
                idx = parts.index("dev")
                if idx + 1 < len(parts):
                    ifaces.append(parts[idx + 1])
        if not ifaces:
            raise Exception("No default interface found")
        for iface in set(ifaces):
            subprocess.run(["resolvectl", "dns", iface] + servers, check=True)
            # Also disable fallback/auto for clarity (where applicable)
            subprocess.run(
                ["resolvectl", "dnssec", iface, "allow-downgrade"], check=False
            )

    def apply_custom_dns(self, widget):
        text = (self.custom_dns_entry.get_text() or "").strip()
        if not text:
            self.net_status_label.set_markup(
                '<span color="#fb4934">Enter DNS servers first</span>'
            )
            return
        # Parse comma/space separated IPv4/IPv6 addresses
        parts = [p.strip() for p in re.split(r"[ ,]+", text) if p.strip()]
        if not parts:
            self.net_status_label.set_markup(
                '<span color="#fb4934">Invalid DNS format</span>'
            )
            return
        try:
            if self.has_nmcli:
                self.apply_dns_via_nmcli(parts)
            elif self.has_resolvectl:
                self.apply_dns_via_resolvectl(parts)
            else:
                self.net_status_label.set_markup(
                    '<span color="#fb4934">Install nmcli or resolvectl</span>'
                )
                return
            self.net_status_label.set_markup(
                '<span color="#b8bb26">✓ Custom DNS applied</span>'
            )
            self.prefs["dns_preset"] = self.dns_combo.get_active_text()
            self.prefs["dns_custom"] = text
            self.save_prefs()
        except Exception as e:
            self.net_status_label.set_markup(
                f'<span color="#fb4934">DNS error: {str(e)}</span>'
            )

    def load_network_info(self):
        """Load network information"""
        # Clear current interfaces
        for child in self.net_interfaces_box.get_children():
            self.net_interfaces_box.remove(child)

        try:
            # Get network interfaces
            output = subprocess.check_output(["ip", "addr", "show"]).decode()

            current_interface = None
            interface_data = {}

            for line in output.split("\n"):
                # New interface
                if line and line[0].isdigit():
                    if current_interface and interface_data:
                        card = self.create_network_interface_card(
                            current_interface, interface_data
                        )
                        self.net_interfaces_box.pack_start(card, False, False, 0)

                    parts = line.split(": ")
                    if len(parts) >= 2:
                        current_interface = parts[1].split("@")[0]
                        interface_data = {
                            "status": "UP" if "UP" in line else "DOWN",
                            "ips": [],
                        }

                # IP address
                elif "inet " in line and current_interface:
                    ip = line.strip().split()[1].split("/")[0]
                    interface_data["ips"].append(ip)

                    # Update hero card with first active connection
                    if interface_data["status"] == "UP" and ip:
                        self.net_status_label.set_markup(
                            '<span size="xx-large" weight="700" foreground="#b8bb26">Connected</span>'
                        )
                        if self.show_ips:
                            self.net_ip_label.set_markup(
                                f'<span size="large" foreground="#83a598">{ip}</span>'
                            )
                        else:
                            self.net_ip_label.set_markup(
                                '<span size="large" foreground="#928374">IP Hidden</span>'
                            )

            # Add last interface
            if current_interface and interface_data:
                card = self.create_network_interface_card(
                    current_interface, interface_data
                )
                self.net_interfaces_box.pack_start(card, False, False, 0)

            self.net_interfaces_box.show_all()

        except Exception as e:
            self.net_status_label.set_markup(
                f'<span color="#fb4934">Error loading network info</span>'
            )

    def create_network_interface_card(self, name, data):
        """Create a card for each network interface"""
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.get_style_context().add_class("control-card")

        # Header with name and status
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)

        # Interface icon and name
        icon = (
            "🔌"
            if "eth" in name or "enp" in name
            else "📡"
            if "wlan" in name or "wlp" in name
            else "🔗"
        )
        name_label = Gtk.Label()
        name_label.set_markup(f'<span size="large" weight="600">{icon} {name}</span>')
        name_label.set_halign(Gtk.Align.START)
        header.pack_start(name_label, False, False, 0)

        # Status badge
        status_color = "#b8bb26" if data["status"] == "UP" else "#928374"
        status_label = Gtk.Label()
        status_label.set_markup(
            f'<span foreground="{status_color}" weight="600">{data["status"]}</span>'
        )
        header.pack_end(status_label, False, False, 0)

        card.pack_start(header, False, False, 0)

        # IP addresses - always create but hide if needed
        if data["ips"]:
            for ip in data["ips"]:
                ip_label = Gtk.Label(label=f"IP: {ip}")
                ip_label.set_halign(Gtk.Align.START)
                ip_label.get_style_context().add_class("status-label")
                ip_label.get_style_context().add_class("ip-address")  # Mark as IP
                if not self.show_ips:
                    ip_label.set_no_show_all(True)
                    ip_label.hide()
                card.pack_start(ip_label, False, False, 0)
        else:
            no_ip = Gtk.Label(label="No IP assigned")
            no_ip.set_halign(Gtk.Align.START)
            no_ip.get_style_context().add_class("status-label")
            no_ip.get_style_context().add_class("ip-address")
            if not self.show_ips:
                no_ip.set_no_show_all(True)
                no_ip.hide()
            card.pack_start(no_ip, False, False, 0)

        return card

    def toggle_ip_visibility(self, widget):
        """Toggle IP address visibility - instant, no rebuild"""
        self.show_ips = not self.show_ips

        if self.show_ips:
            self.show_ip_btn.set_label("🙈 Hide IPs")
        else:
            self.show_ip_btn.set_label("👁 Show IPs")

        # Just show/hide IP labels - NO rebuilding!
        for card in self.net_interfaces_box.get_children():
            for child in card.get_children():
                if hasattr(child, "get_style_context"):
                    if "ip-address" in child.get_style_context().list_classes():
                        if self.show_ips:
                            child.show()
                        else:
                            child.hide()

        # Update hero card IP
        try:
            output = subprocess.check_output(["ip", "addr", "show"]).decode()
            for line in output.split("\n"):
                if "inet " in line and "scope global" in line:
                    ip = line.strip().split()[1].split("/")[0]
                    if self.show_ips:
                        self.net_ip_label.set_markup(
                            f'<span size="large" foreground="#83a598">{ip}</span>'
                        )
                    else:
                        self.net_ip_label.set_markup(
                            '<span size="large" foreground="#928374">IP Hidden</span>'
                        )
                    break
        except:
            pass

    def run_speed_test(self, widget):
        """Run internet speed test with animations"""
        print("Speed test button clicked!")

        # Make card visible with fade-in
        self.speed_test_card.show_all()
        print("Speed test card shown")

        # Reset progress bars
        self.download_progress.set_fraction(0)
        self.upload_progress.set_fraction(0)
        self.download_speed_label.set_markup(
            '<span size="x-large" weight="700">0.0 Mbps</span>'
        )
        self.upload_speed_label.set_markup(
            '<span size="x-large" weight="700">0.0 Mbps</span>'
        )
        self.ping_label.set_markup(
            '<span size="large" foreground="#83a598">📡 Ping: -- ms</span>'
        )
        self.speed_test_status.set_markup(
            '<span size="large" weight="600" foreground="#fabd2f">⏳ Testing your connection...</span>'
        )

        # Start animation BEFORE thread
        self.testing = True
        self.progress_value = 0.0

        def animate_progress():
            if hasattr(self, "testing") and self.testing:
                # Slowly fill up to 85% while testing - slower and smoother
                self.progress_value = min(0.85, self.progress_value + 0.005)
                self.download_progress.set_fraction(self.progress_value)
                self.upload_progress.set_fraction(self.progress_value)
                return True
            return False

        # Start animation timer - slower for smoother feel
        GLib.timeout_add(100, animate_progress)

        # Run in background
        def test_speed():
            print("Test speed thread started!")

            try:
                print("Checking for speedtest command...")
                # Check if speedtest-cli is installed
                speedtest_cmd = None
                result = subprocess.run(["which", "speedtest-cli"], capture_output=True)
                if result.returncode == 0:
                    speedtest_cmd = "speedtest-cli"
                else:
                    # Try official speedtest
                    result = subprocess.run(["which", "speedtest"], capture_output=True)
                    if result.returncode == 0:
                        speedtest_cmd = "speedtest"

                # If user selected iperf3 and available, use it instead of Ookla tools
                selected_backend = (
                    self.speed_backend_combo.get_active_text()
                    if hasattr(self, "speed_backend_combo")
                    else "Ookla"
                )
                if self.has_iperf3 and selected_backend == "iperf3":
                    GLib.idle_add(
                        lambda: self.speed_test_status.set_markup(
                            '<span size="large" weight="600" foreground="#83a598">Using iperf3 backend</span>'
                        )
                    )
                    self.run_iperf3_test_realtime()
                    return

                if not speedtest_cmd:
                    print("No speedtest command found!")
                    self.testing = False

                    def show_error():
                        self.speed_test_status.set_markup(
                            '<span color="#fb4934" size="large" weight="600">❌ No speedtest tool found!</span>'
                        )
                        self.download_speed_label.set_markup(
                            '<span size="small">Install with:\npip install speedtest-cli</span>'
                        )
                        self.upload_speed_label.set_markup(
                            '<span size="small">or:\nsudo pacman -S speedtest-cli</span>'
                        )
                        self.ping_label.set_markup(
                            '<span size="small">Then try again!</span>'
                        )

                    GLib.idle_add(show_error)
                    return

                print(f"Using speedtest command: {speedtest_cmd}")

                # Run speed test with real-time output
                print(f"Running: {speedtest_cmd}")

                if speedtest_cmd == "speedtest-cli":
                    # Use Popen to get real-time output
                    process = subprocess.Popen(
                        [speedtest_cmd, "--simple"],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True,
                    )

                    output_lines = []
                    for line in process.stdout:
                        line = line.strip()
                        print(f"Real-time: {line}")
                        output_lines.append(line)

                        # Update UI as we get data
                        if "Ping:" in line:
                            ping_str = line.split(":")[1].strip()
                            GLib.idle_add(
                                lambda p=ping_str: self.ping_label.set_markup(
                                    f'<span size="large" foreground="#83a598" weight="600">📡 Ping: {p}</span>'
                                )
                            )
                            GLib.idle_add(
                                lambda: self.speed_test_status.set_markup(
                                    '<span size="large" weight="600" foreground="#83a598">📡 Testing download...</span>'
                                )
                            )
                        elif "Download:" in line:
                            download_str = line.split(":")[1].strip()
                            GLib.idle_add(
                                lambda: self.speed_test_status.set_markup(
                                    '<span size="large" weight="600" foreground="#b8bb26">⬇️ Testing upload...</span>'
                                )
                            )
                        elif "Upload:" in line:
                            upload_str = line.split(":")[1].strip()

                    process.wait()
                    output = "\n".join(output_lines)
                else:
                    # Official speedtest with JSONL to stream real-time metrics
                    process = subprocess.Popen(
                        [
                            speedtest_cmd,
                            "--accept-license",
                            "--accept-gdpr",
                            "--format=jsonl",
                        ],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        universal_newlines=True,
                    )
                    output_lines = []
                    for line in process.stdout:
                        line = line.strip()
                        if not line:
                            continue
                        output_lines.append(line)
                        try:
                            evt = json.loads(line)
                        except Exception:
                            continue
                        evt_type = evt.get("type") or evt.get("Type")
                        # Ping updates
                        if evt_type and "ping" in evt_type.lower():
                            ping_val = (
                                evt.get("latency")
                                or evt.get("Ping")
                                or evt.get("jitter")
                            )
                            if ping_val is not None:
                                GLib.idle_add(
                                    lambda p=ping_val: self.ping_label.set_markup(
                                        f'<span size="large" foreground="#83a598" weight="600">📡 Ping: {p:.1f} ms</span>'
                                    )
                                )
                                GLib.idle_add(
                                    lambda: self.speed_test_status.set_markup(
                                        '<span size="large" weight="600" foreground="#83a598">📡 Testing download...</span>'
                                    )
                                )
                        # Download updates
                        if evt_type and "download" in evt_type.lower():
                            bps = evt.get("bps") or evt.get("download", {}).get(
                                "bandwidth"
                            )
                            if bps is not None:
                                mbps = float(bps) / 1_000_000.0
                                GLib.idle_add(
                                    lambda v=mbps: self.download_speed_label.set_markup(
                                        f'<span size="x-large" weight="700" foreground="#b8bb26">{v:.1f} Mbps</span>'
                                    )
                                )
                                # Progress fraction heuristic (cap at 200 Mbps scale)
                                frac = max(0.0, min(1.0, mbps / 200.0))
                                GLib.idle_add(
                                    lambda f=frac: self.download_progress.set_fraction(
                                        f
                                    )
                                )
                                GLib.idle_add(
                                    lambda: self.speed_test_status.set_markup(
                                        '<span size="large" weight="600" foreground="#b8bb26">⬇️ Testing download...</span>'
                                    )
                                )
                        # Upload updates
                        if evt_type and "upload" in evt_type.lower():
                            bps = evt.get("bps") or evt.get("upload", {}).get(
                                "bandwidth"
                            )
                            if bps is not None:
                                mbps = float(bps) / 1_000_000.0
                                GLib.idle_add(
                                    lambda v=mbps: self.upload_speed_label.set_markup(
                                        f'<span size="x-large" weight="700" foreground="#fe8019">{v:.1f} Mbps</span>'
                                    )
                                )
                                frac = max(0.0, min(1.0, mbps / 200.0))
                                GLib.idle_add(
                                    lambda f=frac: self.upload_progress.set_fraction(f)
                                )
                                GLib.idle_add(
                                    lambda: self.speed_test_status.set_markup(
                                        '<span size="large" weight="600" foreground="#fe8019">⬆️ Testing upload...</span>'
                                    )
                                )
                    process.wait()
                    output = "\n".join(output_lines)

                print(f"Speed test complete!")

                # Parse results
                lines = output.strip().split("\n")
                download_val = upload_val = ping_val = 0
                download_str = upload_str = ping_str = "N/A"

                for line in lines:
                    if "Download:" in line:
                        download_str = line.split(":")[1].strip()
                        try:
                            download_val = float(download_str.split()[0])
                        except:
                            pass
                    elif "Upload:" in line:
                        upload_str = line.split(":")[1].strip()
                        try:
                            upload_val = float(upload_str.split()[0])
                        except:
                            pass
                    elif "Ping:" in line:
                        ping_str = line.split(":")[1].strip()
                        try:
                            ping_val = float(ping_str.split()[0])
                        except:
                            pass

                self.testing = False
                print(
                    f"Parsed: Download={download_val}, Upload={upload_val}, Ping={ping_str}"
                )
                print("Updating UI with results...")

                # Update all results at once
                def show_results():
                    print("show_results called!")
                    self.download_progress.set_fraction(1.0)
                    self.download_speed_label.set_markup(
                        f'<span size="x-large" weight="700" foreground="#b8bb26">{download_val:.1f} Mbps</span>'
                    )
                    self.upload_progress.set_fraction(1.0)
                    self.upload_speed_label.set_markup(
                        f'<span size="x-large" weight="700" foreground="#fe8019">{upload_val:.1f} Mbps</span>'
                    )
                    self.ping_label.set_markup(
                        f'<span size="large" foreground="#83a598" weight="600">📡 Ping: {ping_str}</span>'
                    )
                    self.speed_test_status.set_markup(
                        '<span size="large" weight="600" foreground="#b8bb26">✓ Test Complete!</span>'
                    )
                    self.speed_test_start_btn.set_sensitive(True)
                    self.speed_test_cancel_btn.set_sensitive(False)
                    print("UI updated!")

                GLib.idle_add(show_results)
                print("Results queued for UI update")

                # Notification
                subprocess.run(
                    [
                        "notify-send",
                        "Speed Test Complete",
                        f"Download: {download_str}\nUpload: {upload_str}\nPing: {ping_str}",
                    ]
                )

            except subprocess.TimeoutExpired:
                self.testing = False
                GLib.idle_add(
                    lambda: self.speed_test_status.set_markup(
                        '<span color="#fb4934">Speed test timed out</span>'
                    )
                )
            except Exception as e:
                self.testing = False
                GLib.idle_add(
                    lambda: self.speed_test_status.set_markup(
                        f'<span color="#fb4934">Error: {str(e)}</span>'
                    )
                )

        # Run in thread to not block UI
        import threading

        self._speedtest_thread_stop = False
        thread = threading.Thread(target=test_speed)
        thread.daemon = True
        thread.start()
        self.speed_test_start_btn.set_sensitive(False)
        self.speed_test_cancel_btn.set_sensitive(True)

    def cancel_speed_test(self, widget):
        # Best-effort cancel: mark testing false and update UI
        self.testing = False
        self.speed_test_status.set_markup('<span color="#fb4934">Cancelled</span>')
        self.speed_test_start_btn.set_sensitive(True)
        self.speed_test_cancel_btn.set_sensitive(False)

    def run_iperf3_test_realtime(self):
        """Run iperf3 download (reverse) then upload, updating UI in real-time."""
        server = "iperf3.iperf.fr"
        try:
            # DOWNLOAD (server->client) with -R
            self.speed_test_status.set_markup(
                '<span size="large" weight="600" foreground="#b8bb26">⬇️ Testing download...</span>'
            )
            proc_down = subprocess.Popen(
                ["iperf3", "-c", server, "-R", "-i", "1", "-t", "10"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
            )
            for line in proc_down.stdout:
                line = line.strip()
                if "sec" in line and "Mbits/sec" in line:
                    # Parse interval line
                    try:
                        mbps = float(line.split()[-2])
                        frac = max(0.0, min(1.0, mbps / 200.0))
                        GLib.idle_add(
                            lambda v=mbps: self.download_speed_label.set_markup(
                                f'<span size="x-large" weight="700" foreground="#b8bb26">{v:.1f} Mbps</span>'
                            )
                        )
                        GLib.idle_add(
                            lambda f=frac: self.download_progress.set_fraction(f)
                        )
                    except Exception:
                        pass
            proc_down.wait()

            # UPLOAD (client->server)
            self.speed_test_status.set_markup(
                '<span size="large" weight="600" foreground="#fe8019">⬆️ Testing upload...</span>'
            )
            proc_up = subprocess.Popen(
                ["iperf3", "-c", server, "-i", "1", "-t", "10"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
            )
            for line in proc_up.stdout:
                line = line.strip()
                if "sec" in line and "Mbits/sec" in line:
                    try:
                        mbps = float(line.split()[-2])
                        frac = max(0.0, min(1.0, mbps / 200.0))
                        GLib.idle_add(
                            lambda v=mbps: self.upload_speed_label.set_markup(
                                f'<span size="x-large" weight="700" foreground="#fe8019">{v:.1f} Mbps</span>'
                            )
                        )
                        GLib.idle_add(
                            lambda f=frac: self.upload_progress.set_fraction(f)
                        )
                    except Exception:
                        pass
            proc_up.wait()

            self.speed_test_status.set_markup(
                '<span size="large" weight="600" foreground="#b8bb26">✓ Test Complete!</span>'
            )
            self.speed_test_start_btn.set_sensitive(True)
            self.speed_test_cancel_btn.set_sensitive(False)
        except Exception as e:
            self.speed_test_status.set_markup(
                f'<span color="#fb4934">iperf3 error: {str(e)}</span>'
            )
            self.speed_test_start_btn.set_sensitive(True)
            self.speed_test_cancel_btn.set_sensitive(False)
        print("Thread started!")

    def open_shortcuts(self, widget):
        # Navigate to shortcuts page
        self.stack.set_visible_child_name("shortcuts")
        self.back_button_box.set_visible(True)

    def open_files(self, widget):
        subprocess.Popen(["thunar"], env={**os.environ, "GTK_THEME": "Adwaita:dark"})
        self.destroy()

    def open_power(self, widget):
        # Create power menu dialog
        dialog = Gtk.Dialog(title="Power Menu", parent=self, flags=0)
        dialog.set_default_size(300, 200)
        dialog.add_button("Shutdown", 1)
        dialog.add_button("Reboot", 2)
        dialog.add_button("Logout", 3)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)

        label = Gtk.Label(label="Select power option:")
        box = dialog.get_content_area()
        box.add(label)
        dialog.show_all()

        response = dialog.run()
        if response == 1:
            subprocess.run(["systemctl", "poweroff"])
        elif response == 2:
            subprocess.run(["systemctl", "reboot"])
        elif response == 3:
            subprocess.run(["bspc", "quit"])

        dialog.destroy()
        self.destroy()

    def create_shortcuts_settings(self):
        """Create keyboard shortcuts management page"""
        # Main scrolled window for entire page
        scrolled_main = Gtk.ScrolledWindow()
        scrolled_main.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        shortcuts_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        shortcuts_box.set_margin_top(20)
        shortcuts_box.set_margin_bottom(20)
        shortcuts_box.set_margin_start(40)
        shortcuts_box.set_margin_end(40)

        # Title
        title = Gtk.Label()
        title.set_markup(
            '<span size="x-large" weight="600">⌨️ Keyboard Shortcuts</span>'
        )
        title.get_style_context().add_class("title-label")
        title.set_halign(Gtk.Align.START)
        shortcuts_box.pack_start(title, False, False, 0)

        # Description
        desc = Gtk.Label(label="Manage your system keyboard shortcuts")
        desc.get_style_context().add_class("system-label")
        shortcuts_box.pack_start(desc, False, False, 0)

        # Shortcuts grid
        grid = Gtk.Grid()
        grid.set_row_spacing(12)
        grid.set_column_spacing(20)
        grid.set_column_homogeneous(True)

        # Common shortcuts
        # Store shortcuts in instance variable so we can add to it
        self.shortcuts_list = [
            ("Launch Terminal", "Super + q", "Open terminal"),
            ("Launch Rofi", "Super + d", "Application launcher"),
            ("Close Window", "Super + c", "Close focused window"),
            ("Open Browser", "Super + x", "Open web browser"),
            ("Move to Workspace", "Super + 1-9", "Move window to workspace"),
            ("Screenshot", "Print", "Take screenshot"),
        ]

        self.shortcuts_grid = grid

        row = 0
        for name, shortcut, description in self.shortcuts_list:
            # Shortcut card
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            card.get_style_context().add_class("shortcut-card")
            card.set_margin_top(8)
            card.set_margin_bottom(8)

            # Shortcut name
            name_label = Gtk.Label(label=name)
            name_label.get_style_context().add_class("shortcut-name")
            name_label.set_halign(Gtk.Align.START)
            name_label.set_xalign(0)
            card.pack_start(name_label, False, False, 0)

            # Shortcut key
            shortcut_label = Gtk.Label()
            shortcut_label.set_markup(
                f'<span size="large" weight="bold" foreground="#fe8019">{shortcut}</span>'
            )
            shortcut_label.set_halign(Gtk.Align.START)
            shortcut_label.set_xalign(0)
            card.pack_start(shortcut_label, False, False, 0)

            # Description
            desc_label = Gtk.Label(label=description)
            desc_label.get_style_context().add_class("shortcut-desc")
            desc_label.set_halign(Gtk.Align.START)
            desc_label.set_xalign(0)
            card.pack_start(desc_label, False, False, 0)

            # Add to grid (2 columns)
            col = row % 2
            grid_row = row // 2
            grid.attach(card, col, grid_row, 1, 1)
            row += 1

        shortcuts_box.pack_start(grid, True, True, 0)

        # Add separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator.set_margin_top(30)
        separator.set_margin_bottom(30)
        shortcuts_box.pack_start(separator, False, False, 0)

        # Add custom shortcut section - DEAD SIMPLE
        custom_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        custom_box.get_style_context().add_class("control-card")
        custom_box.set_margin_top(20)
        custom_box.set_margin_bottom(40)

        custom_title = Gtk.Label()
        custom_title.set_markup(
            '<span size="x-large" weight="600" foreground="#fe8019">➕ Quick Shortcut Creator</span>'
        )
        custom_title.set_halign(Gtk.Align.CENTER)
        custom_box.pack_start(custom_title, False, False, 0)

        # Simple form - no dialog needed!
        form_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        form_box.set_margin_start(20)
        form_box.set_margin_end(20)

        # What does it do?
        name_label = Gtk.Label(label="What does this shortcut do?")
        name_label.set_halign(Gtk.Align.START)
        name_label.get_style_context().add_class("device-label")
        form_box.pack_start(name_label, False, False, 0)

        self.shortcut_name_entry = Gtk.Entry()
        self.shortcut_name_entry.set_placeholder_text("e.g., Open Music Player")
        form_box.pack_start(self.shortcut_name_entry, False, False, 0)

        # What command?
        cmd_label = Gtk.Label(label="What command should it run?")
        cmd_label.set_halign(Gtk.Align.START)
        cmd_label.get_style_context().add_class("device-label")
        form_box.pack_start(cmd_label, False, False, 0)

        self.shortcut_command_entry = Gtk.Entry()
        self.shortcut_command_entry.set_placeholder_text("e.g., spotify")
        form_box.pack_start(self.shortcut_command_entry, False, False, 0)

        # What key? - Interactive key detection
        key_label = Gtk.Label(label="Press the key combination:")
        key_label.set_halign(Gtk.Align.START)
        key_label.get_style_context().add_class("device-label")
        form_box.pack_start(key_label, False, False, 0)

        # Key detection button
        self.key_detect_btn = Gtk.Button(label="🎯 Click here then press keys...")
        self.key_detect_btn.get_style_context().add_class("option-button")
        self.key_detect_btn.connect("clicked", self.start_key_detection)
        form_box.pack_start(self.key_detect_btn, False, False, 0)

        # Display detected keys
        self.detected_keys_label = Gtk.Label(label="No keys detected yet")
        self.detected_keys_label.get_style_context().add_class("status-label")
        form_box.pack_start(self.detected_keys_label, False, False, 0)

        # Create button
        create_btn = Gtk.Button(label="🚀 Create Shortcut")
        create_btn.get_style_context().add_class("futuristic-apply-button")
        create_btn.set_size_request(200, 50)
        create_btn.connect("clicked", self.create_shortcut_now)
        form_box.pack_start(create_btn, False, False, 20)

        custom_box.pack_start(form_box, False, False, 0)

        shortcuts_box.pack_start(custom_box, False, False, 20)

        # Add shortcuts_box to scrolled window
        scrolled_main.add(shortcuts_box)

        # Add to stack
        self.stack.add_named(scrolled_main, "shortcuts")

    def create_shortcut_now(self, widget):
        """Create shortcut immediately - no dialog needed!"""
        name = self.shortcut_name_entry.get_text().strip()
        command = self.shortcut_command_entry.get_text().strip()
        key = self.detected_keys  # Use the detected keys

        if not name:
            if self.has_notify:
                subprocess.run(
                    ["notify-send", "Oops!", "Tell me what the shortcut does!"]
                )
            return

        if not command:
            if self.has_notify:
                subprocess.run(["notify-send", "Oops!", "What command should it run?"])
            return

        if not key:
            if self.has_notify:
                subprocess.run(["notify-send", "Oops!", "What key combination?"])
            return

        # Create the shortcut
        success = self.add_custom_shortcut(name, command, key)

        if success:
            # Add to displayed shortcuts
            self.shortcuts_list.append((name, key, f"Runs: {command}"))
            self.refresh_shortcuts_display()

            # Show success
            if self.has_notify:
                subprocess.run(
                    [
                        "notify-send",
                        "✅ Done!",
                        f"Shortcut '{name}' created!\nPress {key} to run: {command}",
                    ]
                )

            # Clear the form for next shortcut
            self.shortcut_name_entry.set_text("")
            self.shortcut_command_entry.set_text("")
            self.detected_keys = ""
            self.detected_keys_label.set_text("No keys detected yet")
            self.key_detect_btn.set_label("🎯 Click here then press keys...")
        else:
            if self.has_notify:
                subprocess.run(["notify-send", "❌ Error", "Failed to create shortcut"])

    def start_key_detection(self, widget):
        """Start listening for key presses"""
        self.key_detect_btn.set_label("🎯 Listening... Press keys now!")
        self.detected_keys = ""
        self.detected_keys_label.set_text("Press Super, Ctrl, Alt, Shift + any key...")

        # Connect key press event
        self.connect("key-press-event", self.on_key_press_detection)

    def on_key_press_detection(self, widget, event):
        """Handle key presses for shortcut detection"""
        keyval = event.keyval
        keyname = Gdk.keyval_name(keyval)
        state = event.state

        modifiers = []
        if state & Gdk.ModifierType.CONTROL_MASK:
            modifiers.append("Ctrl")
        if state & Gdk.ModifierType.SUPER_MASK:
            modifiers.append("Super")
        if state & Gdk.ModifierType.SHIFT_MASK:
            modifiers.append("Shift")
        if state & Gdk.ModifierType.MOD1_MASK:  # Alt
            modifiers.append("Alt")

        # Ignore modifier-only presses
        if keyname and keyname not in [
            "Control_L",
            "Control_R",
            "Super_L",
            "Super_R",
            "Shift_L",
            "Shift_R",
            "Alt_L",
            "Alt_R",
        ]:
            if modifiers:
                key_combination = " + ".join(modifiers) + " + " + keyname
            else:
                key_combination = keyname

            self.detected_keys = key_combination
            self.detected_keys_label.set_text(f"✅ Detected: {key_combination}")
            self.key_detect_btn.set_label("🎯 Click to detect different keys")

            # Disconnect the event handler
            self.disconnect_by_func(self.on_key_press_detection)

        return True

    def refresh_shortcuts_display(self):
        """Refresh the shortcuts grid with updated list"""
        # Clear current shortcuts
        for child in self.shortcuts_grid.get_children():
            self.shortcuts_grid.remove(child)

        # Re-add all shortcuts
        row = 0
        for name, shortcut, description in self.shortcuts_list:
            # Shortcut card
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            card.get_style_context().add_class("shortcut-card")
            card.set_margin_top(8)
            card.set_margin_bottom(8)

            # Shortcut name
            name_label = Gtk.Label(label=name)
            name_label.get_style_context().add_class("shortcut-name")
            name_label.set_halign(Gtk.Align.START)
            name_label.set_xalign(0)
            card.pack_start(name_label, False, False, 0)

            # Shortcut key
            shortcut_label = Gtk.Label()
            shortcut_label.set_markup(
                f'<span size="large" weight="bold" foreground="#fe8019">{shortcut}</span>'
            )
            shortcut_label.set_halign(Gtk.Align.START)
            shortcut_label.set_xalign(0)
            card.pack_start(shortcut_label, False, False, 0)

            # Description
            desc_label = Gtk.Label(label=description)
            desc_label.get_style_context().add_class("shortcut-desc")
            desc_label.set_halign(Gtk.Align.START)
            desc_label.set_xalign(0)
            card.pack_start(desc_label, False, False, 0)

            # Add to grid (2 columns)
            col = row % 2
            grid_row = row // 2
            self.shortcuts_grid.attach(card, col, grid_row, 1, 1)
            row += 1

        self.shortcuts_grid.show_all()

    def add_custom_shortcut(self, name, command, key):
        """Add custom shortcut to sxhkd config for bspwm"""
        try:
            # Parse the key combination for sxhkd format
            sxhkd_key = self.parse_key_for_sxhkd(key)

            # Get sxhkd config path
            sxhkd_config = os.path.expanduser("~/.config/sxhkd/sxhkdrc")

            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(sxhkd_config), exist_ok=True)

            # Read existing config
            existing_config = ""
            if os.path.exists(sxhkd_config):
                with open(sxhkd_config, "r") as f:
                    existing_config = f.read()

            # Add new shortcut
            new_shortcut = f"\n# {name}\n{sxhkd_key}\n\t{command}\n"

            # Write back to file
            with open(sxhkd_config, "a") as f:
                f.write(new_shortcut)

            # Reload sxhkd
            subprocess.run(["pkill", "-USR1", "-x", "sxhkd"])

            print(f"✅ Added to sxhkd: {name} -> {command} with key {sxhkd_key}")
            return True

        except Exception as e:
            print(f"❌ Error adding shortcut: {e}")
            return False

    def parse_key_for_sxhkd(self, key):
        """Convert human-readable key to sxhkd format"""
        # Replace common patterns
        sxhkd_key = key.replace("Super", "super")
        sxhkd_key = sxhkd_key.replace("Ctrl", "ctrl")
        sxhkd_key = sxhkd_key.replace("Shift", "shift")
        sxhkd_key = sxhkd_key.replace("Alt", "alt")
        sxhkd_key = sxhkd_key.replace(" + ", "+")

        # Handle special cases
        if sxhkd_key == "Print":
            sxhkd_key = "Print"

        return sxhkd_key


win = SettingsMenu()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
