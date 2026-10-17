#!/usr/bin/env bash
# Shown in Konsole by tools/screenshot.sh: prompt, ls colours and the
# 16-colour palette.
cd "$HOME" || exit 1
PS1='\[\e[32m\]d3mon\[\e[0m\]@\[\e[34m\]kde\[\e[0m\] \w \$ '
printf '%s ls --color\n' "$(printf '\e[32md3mon\e[0m@\e[34mkde\e[0m ~ $')"
ls --color=always
echo
for row in 0 8; do
	for i in $(seq "$row" $((row + 7))); do printf '\e[48;5;%dm   \e[0m ' "$i"; done
	echo
done
echo
printf '\e[31mred\e[0m \e[32mgreen\e[0m \e[33myellow\e[0m \e[34mblue\e[0m '
printf '\e[35mmagenta\e[0m \e[36mcyan\e[0m \e[1mbold\e[0m\n\n'
exec bash --norc -i
