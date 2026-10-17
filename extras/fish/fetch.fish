# fetch: a coffee mug shaded in the wallpaper's accent, and a few facts about the system.
# Runs when a terminal opens (home.nix); type `fetch` to see it again. (Replaces nitch.)

function fetch
    # the mug: lit from the left, dense letters where it's bright (made by a small script)
    set -l mug \
        '       ddddhhhhhyyyy' \
        '  mm..................:ss' \
        'hN....................:::o=' \
        'hhmmm.................sss==' \
        'hhddmmmNNNdhhhhhyyso//+====so=' \
        'hhddmmmNNNmmddhhyyso//+====/syo=' \
        'hhddmmmNNNmmddhhyyso//+====  +ss=' \
        'hhddmmmNNNmmddhhyyso//+====   +so' \
        'hhddmmmNNNmmddhhyyso//+====   =so' \
        'hhddmmmNNNmmddhhyyso//+====   /s/' \
        'hhddmmmNNNmmddhhyyso//+==== =oso' \
        'hhddmmmNNNmmddhhyyso//+====sys+' \
        'hhddmmmNNNmmddhhyyso//+====+' \
        'hhddmmmNNNmmddhhyyso//+====' \
        ' ssyyhhhhhhyyyssoo//+==---' \
        '  syyhhhhhhyyyssoo//+==--'

    # three shades of the accent (lit, base, shadow), written by the bar with the wallpaper's
    # colors (bar/theme/fish.fish); mint if the bar hasn't run yet
    set -l shade $bar_accent_shades
    test (count $shade) -eq 3; or set shade 6ee3c6 3dd2b0 1f7a66
    set -l lit (set_color $shade[1])
    set -l base (set_color $shade[2])
    set -l shadow (set_color $shade[3])
    set -l dim (set_color 6b7a75)
    set -l fg (set_color e6e1d8)
    set -l off (set_color normal)

    # pad first (so the info column lines up), then color by letter density
    set -l art (string pad -r -w 34 -- $mug \
        | string replace -ra '([MNmdh]+)' "$lit\$1" \
        | string replace -ra '([yso/]+)' "$base\$1" \
        | string replace -ra '([-+=:.]+)' "$shadow\$1")

    # ---- the facts ----
    set -l os (string match -rg '^PRETTY_NAME="?([^"]*)' < /etc/os-release)
    set -l secs (string split -f1 . < /proc/uptime)
    set -l days (math -s0 "$secs / 86400")
    set -l up (math -s0 "$secs % 86400 / 3600")h" "(math -s0 "$secs % 3600 / 60")m
    test $days -gt 0; and set up {$days}d" $up"
    set -l total (string match -rg '^MemTotal:\s+(\d+)' < /proc/meminfo)
    set -l avail (string match -rg '^MemAvailable:\s+(\d+)' < /proc/meminfo)
    set -l mem (math -s1 "($total - $avail) / 1048576")" / "(math -s1 "$total / 1048576")" GiB"
    # packages in the running system: counting takes ~0.1 s, so it's cached until the next rebuild
    set -l gen (path resolve /run/current-system)
    set -l cache (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo ~/.cache)/fetch-pkgs
    set -l pkgs
    if test -f $cache
        set -l saved (cat $cache)
        test "$saved[1]" = "$gen"; and set pkgs $saved[2]
    end
    if test -z "$pkgs"
        set pkgs (nix-store -qR $gen 2>/dev/null | count)
        printf '%s\n%s\n' $gen $pkgs > $cache
    end

    set -l who "$USER@$hostname"
    set -l info \
        "$lit$USER$dim@$lit$hostname$off" \
        "$shadow"(string repeat -n (string length -- $who) ─)"$off" \
        "$base"os"$off       $fg$os$off" \
        "$base"kernel"$off   $fg"(uname -r)"$off" \
        "$base"uptime"$off   $fg$up$off" \
        "$base"shell"$off    $fg""fish $version""$off" \
        "$base"wm"$off       $fg$XDG_CURRENT_DESKTOP$off" \
        "$base"pkgs"$off     $fg$pkgs$off" \
        "$base"memory"$off   $fg$mem$off" \
        "" \
        (for c in red yellow green cyan blue magenta white; printf '%s● ' (set_color $c); end)"$lit●$off"

    # info beside the mug, starting a few rows down so it sits in the middle of the cup
    set -l first 4
    echo
    for i in (seq (count $art))
        set -l j (math $i - $first + 1)
        if test $j -ge 1 -a $j -le (count $info)
            printf '  %s%s    %s\n' $art[$i] $off $info[$j]
        else
            printf '  %s%s\n' $art[$i] $off
        end
    end
end
