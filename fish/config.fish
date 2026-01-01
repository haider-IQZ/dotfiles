source /usr/share/cachyos-fish-config/cachyos-config.fish

# add local bin to path
fish_add_path /home/soka/.local/bin
alias hc="nvim .config/hypr/hyprland.conf"
# FZF to NVIM binding
function fzf_nvim
    set -l file (fzf --preview 'bat --color=always --line-range :500 {}')
    if test -n "$file"
        nvim "$file"
    end
    commandline -f repaint
end

bind \ct fzf_nvim

# overwrite greeting
function fish_greeting
    cachy-fetch
end
