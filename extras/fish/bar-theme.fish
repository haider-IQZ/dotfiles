# Terminal colors from the bar's wallpaper accent. Source this from config.fish (after your own
# colors): it loads $XDG_STATE_HOME/bar/theme/fish.fish, which sets the accent parts of fish's
# syntax colors, STARSHIP_CONFIG, FZF_DEFAULT_OPTS_FILE, EZA_COLORS and the fetch mug's shades,
# and recolors the terminal it runs in. The bar sets the universal variable bar_theme whenever
# the accent changes, so every open shell reloads it.

set -g __bar_theme_dir (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo ~/.local/state)/bar/theme
function __bar_theme_load
    test -f $__bar_theme_dir/fish.fish; and source $__bar_theme_dir/fish.fish
end
function __bar_theme_changed --on-variable bar_theme
    __bar_theme_load
end
__bar_theme_load
