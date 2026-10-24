# ~/.gitconfig — rendered from home/gitconfig.tpl by install-chroot.sh, which
# substitutes @GIT_NAME@ and @GIT_EMAIL@.
#
# The settings below are the ones from your existing config, with two changes:
#   - the GitHub credential helper is called as `gh auth git-credential` rather
#     than by an absolute path into a mise install, so it survives gh upgrades
#   - a `user` section is templated, so it is set at install time

[user]
	name = @GIT_NAME@
	email = @GIT_EMAIL@

[init]
	# Kept as master, matching your existing configuration.
	defaultBranch = master

[alias]
	co = checkout
	br = branch
	ci = commit
	st = status
	lg = log --oneline --graph --decorate -20
	last = log -1 HEAD --stat
	unstage = restore --staged

[pull]
	# Rebase instead of merge on pull.
	rebase = true

[push]
	# Automatically set the upstream branch on the first push.
	autoSetupRemote = true

[diff]
	# Clearer diffs on moved or edited lines.
	algorithm = histogram
	colorMoved = plain
	mnemonicPrefix = true

[commit]
	# Include the diff as a comment in the commit message template.
	verbose = true

[column]
	ui = auto

[branch]
	sort = -committerdate

[tag]
	sort = -version:refname

[rerere]
	# Record conflict resolutions and reapply them automatically.
	enabled = true
	autoupdate = true

[core]
	editor = nano
	pager = less -R

[help]
	autocorrect = 10

# Use the GitHub CLI as the credential helper for github.com and gist.github.com.
# `helper =` with an empty value first clears any inherited helper, which is the
# documented way to replace rather than add.
[credential "https://github.com"]
	helper =
	helper = !gh auth git-credential

[credential "https://gist.github.com"]
	helper =
	helper = !gh auth git-credential
