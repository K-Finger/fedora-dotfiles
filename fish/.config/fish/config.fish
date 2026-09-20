if status is-interactive
    # Commands to run in interactive sessions can go here
end
starship init fish | source
if status is-interactive; and command -q fastfetch
    fastfetch
end
