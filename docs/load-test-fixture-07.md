# Shell Startup

Startup files are split by shell and by login/interactive status.

## Order

1. `/etc/profile`
2. `~/.zprofile`
3. `~/.zshrc` (interactive only)
4. `~/.zlogin`

`~/.zshenv` runs for every shell, including non-interactive ones, so it must
stay cheap. It currently sources a 400-line completion file, which adds roughly
120 ms to every script invocation.

## PATH

PATH is assembled once in `~/.zprofile` and guarded by a marker check so it is
not duplicated on nested shells. The guard compares the whole PATH string, so
any modification by a tool invalidates the guard and PATH is prepended twice.

## Interactive-only work

Prompt setup, aliases, and completion live in `~/.zshrc`. Anything that must be
available to scripts belongs in `~/.zprofile` instead.

## Known issue

The duplicate-PATH guard fails when a tool appends to PATH before `~/.zprofile`
runs. Observed with the version manager, which appends its bin directory.
