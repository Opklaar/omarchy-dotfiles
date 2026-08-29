# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Drop aliases for AI agents that were removed
unalias cx cy 2>/dev/null

# Drop aliases for removed apps (rails, herdr, tmux)
unalias r h t ic ix icx 2>/dev/null

# Drop herdr/tmux layout functions
unset -f hdl hds hdlm hsl _herdr_ratio _herdr_split 2>/dev/null
unset -f tdl tds tdlm tsl 2>/dev/null
