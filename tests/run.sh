#!/bin/sh
# The script's herdr-free parts: URL extraction and $BROWSER dispatch. SH picks the shell under test.
# shellcheck disable=SC2016 # literal $, ` and quotes are the test data
set -u
cd "$(dirname "$0")/.." || exit
fails=0

check() {
	if [ "$2" = "$3" ]; then
		echo "ok   $1"
	else
		printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"
		fails=$((fails + 1))
	fi
}

extract() { printf '%b' "$1" | ${SH:-sh} fzf-open extract | paste -sd ' ' -; }
browse() { FZF_OPEN_URL=$1 BROWSER=$2 ${SH:-sh} fzf-open browser </dev/null 2>&1; }

check "trailing prose punctuation is dropped" \
	"https://a/b https://a/c https://a/d" \
	"$(extract 'https://a/d…\n(https://a/c),\nhttps://a/b.')"
check "balanced parens are kept" \
	"https://en.wikipedia.org/wiki/Foo_(bar)" \
	"$(extract 'https://en.wikipedia.org/wiki/Foo_(bar)).')"
check "markdown, json, quotes and brackets end a url" \
	"https://e/f https://a/b https://x.io/a https://example.com/docs" \
	"$(extract 'see [docs](https://example.com/docs) and {"url":"https://x.io/a","n":1} <https://a/b> `https://e/f`|x')"
check "scheme wins over www and local dev inside it" \
	"http://localhost:3000/api https://www.example.com/x" \
	"$(extract 'https://www.example.com/x and http://localhost:3000/api')"
check "dev servers and ipv4 are normalised" \
	"http://10.0.0.5:8080/api http://[::1]:4000 http://localhost:8080/health http://localhost:5173" \
	"$(extract 'listening on localhost:5173\n0.0.0.0:8080/health\n[::1]:4000 ok\napi at 10.0.0.5:8080/api.')"
check "bare hosts, versions and invalid ipv4 are not urls" \
	"" \
	"$(extract 'localhost is fine; server 192.168.1.1 up; tool v1.2.3.4; 256.1.1.1:80')"
check "www and git ssh" \
	"https://gitlab.com/x/y https://github.com/a/b https://www.example.com/path" \
	"$(extract 'visit www.example.com/path, clone git@github.com:a/b.git or ssh://git@gitlab.com/x/y.git')"
check "newest first, deduped, ansi stripped" \
	"https://a/1 https://a/2" \
	"$(extract 'https://a/1\n\033[32mhttps://a/2\033[0m\nhttps://a/1\n')"

check "browser alternatives fall through and %s is replaced" \
	"got https://a" \
	"$(browse https://a 'nope-x:echo got %s')"
check "browser is split like a shell" \
	"/mnt/c/Program Files/b.exe --c=W a b https://a" \
	"$(browse https://a 'echo /mnt/c/Program\ Files/b.exe --c=W "a b"')"
check "the url is never evaluated" \
	'https://a/?q=$(id)&x=`id`;id' \
	"$(browse 'https://a/?q=$(id)&x=`id`;id' echo)"
check "unset BROWSER is reported" \
	"fzf-open: BROWSER is not set" \
	"$(browse https://a '')"

# The picker against a fake herdr (one URL on screen, records `plugin pane open`) and a fake fzf
# (records its args, answers with $FAKE_KEY and the first URL; in the target list it picks the line for
# $FAKE_TARGET, or cancels like esc when there is none).
FAKE=$(mktemp -d)
trap 'rm -rf "$FAKE"' EXIT
cat >"$FAKE/herdr" <<'EOF'
#!/bin/sh
case "$1 $2" in
"pane get") echo '{"result":{"pane":{"scroll":{"offset_from_bottom":0,"viewport_rows":5}}}}' ;;
"pane read") echo 'see https://a/1' ;;
"plugin config-dir") echo "$FAKE/config" ;;
"plugin pane") printf '%s\n' "$@" >"$FAKE/herdr-args" ;;
esac
EOF
cat >"$FAKE/fzf" <<'EOF'
#!/bin/sh
case "$*" in
*--prompt=open\ with*) grep "^$FAKE_TARGET	" || exit 130 ;;
*)
	printf '%s\n' "$@" >"$FAKE/fzf-args"
	printf '%s\n' "$FAKE_KEY" "$(head -n 1)"
	;;
esac
EOF
chmod +x "$FAKE/herdr" "$FAKE/fzf"
mkdir "$FAKE/config"
export FAKE HERDR_BIN_PATH="$FAKE/herdr" FZF_OPEN_SOURCE_PANE=w1:p1

# Picks with key $1, targets file $2 (none when empty), $BROWSER $3 and, for ctrl-x, the listed
# target $4; prints the BROWSER handed to the split, or the error.
pick_with() {
	rm -f "$FAKE/herdr-args" "$FAKE/config/targets"
	[ -z "$2" ] || printf '%s\n' "$2" >"$FAKE/config/targets"
	err=$(FAKE_KEY=$1 BROWSER=$3 FAKE_TARGET=${4:-} PATH="$FAKE:$PATH" HERDR_PLUGIN_CONFIG_DIR="$FAKE/config" \
		${SH:-sh} fzf-open picker </dev/null 2>&1)
	if [ -f "$FAKE/herdr-args" ]; then sed -n 's/^BROWSER=//p' "$FAKE/herdr-args"; else echo "$err"; fi
}
header() { sed -n 's/^--header=//p' "$FAKE/fzf-args"; }

TARGETS='# keys are fzf key names
enter   wslview

ctrl-o  w3m -o x=1
ctrl-t  /mnt/c/Program\ Files/Brave/brave.exe --x'

check "without targets, enter opens \$BROWSER" "xdg-open" "$(pick_with '' '' xdg-open)"
check "a target's key opens that target" "w3m -o x=1" "$(pick_with ctrl-o "$TARGETS" xdg-open)"
check "enter opens the enter target over \$BROWSER" "wslview" "$(pick_with '' "$TARGETS" xdg-open)"
check "without an enter target, enter falls back to \$BROWSER" "xdg-open" \
	"$(pick_with '' 'ctrl-o w3m' xdg-open)"
check "the header names each target by its program" \
	"enter: wslview | ctrl-o: w3m | ctrl-t: brave.exe | ctrl-x: choose | ctrl-y: copy | esc: cancel" \
	"$(pick_with '' "$TARGETS" xdg-open >/dev/null; header)"
check "ctrl-x opens the target chosen from the list" "w3m -o x=1" \
	"$(pick_with ctrl-x "$TARGETS" xdg-open ctrl-o)"
check "cancelling the target list opens nothing" "" "$(pick_with ctrl-x "$TARGETS" xdg-open none)"
check "no target at all is reported" \
	"fzf-open: no browser: set BROWSER or add targets to $FAKE/config/targets" \
	"$(pick_with '' '' '')"
check "open uses the enter target, finding the config dir via herdr" "wslview" "$(
	rm -f "$FAKE/herdr-args"
	printf '%s\n' "$TARGETS" >"$FAKE/config/targets"
	BROWSER=xdg-open ${SH:-sh} fzf-open open https://a
	sed -n 's/^BROWSER=//p' "$FAKE/herdr-args"
)"

[ "$fails" -eq 0 ] || {
	echo "$fails failed"
	exit 1
}
