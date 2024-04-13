set -o vi

bind 'set show-mode-in-prompt on'
bind 'set vi-ins-mode-string \1\e[4 q\2'
bind 'set vi-cmd-mode-string \1\e[6 q\2'

bind -m vi-command 'Control-l: clear-screen'
bind -m vi-insert 'Control-l: clear-screen'

alias l="lsd -l"
