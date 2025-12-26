# Enable colors and change prompt:
autoload -U colors && colors
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

# History in cache directory:
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.cache/zsh/history

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

# Starship
eval "$(starship init zsh)"

# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Cursor Style
# Block for normal, beam for insert
echo -ne '\e[5 q'

# Bind Tab to accept autosuggestion
bindkey '^I' autosuggest-accept

# Start nitch fetch
nitch
export QT_STYLE_OVERRIDE=kvantum
export QT_QPA_PLATFORMTHEME=qt5ct
alias dots="cd ~/dotfiles && git add -A && git commit -m \"sync\" && git push"
