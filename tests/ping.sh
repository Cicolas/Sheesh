#!/bin/bash
# Run with: bash tests/ping.sh
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/bin" "$WORK/empty-bin"
export HOME="$WORK/home" NC_LOG="$WORK/nc.log" NC_STATUS=0
cat > "$WORK/bin/nc" <<'NC'
#!/bin/bash
printf '%s\n' "$@" > "$NC_LOG"
printf 'netcat stdout noise\n'
printf 'netcat stderr noise\n' >&2
exit "$NC_STATUS"
NC
chmod +x "$WORK/bin/nc"
cat > "$HOME/.sheesh" <<'CONFIG'
# ignored:example.com

prod:admin@example.com
custom:developer@192.168.1.100 -p 2222 -i ~/.ssh/dev_key
reordered:host -i key -p 00022
ipv6:user@2001:db8::1 -p 2200
bracketed:user@[::1]
loopback:::1
first:one.example
first:two.example
literal.*:literal.example
literalZZ:wrong.example
slash\name:slash.example
empty:
full:ssh user@example.com
jump:host -J jump
proxy:host -o ProxyCommand=proxy
optionhost:-example.com
baduser:user@@host
badbracket:[::1
quoted:host -i "a key"
escaped:host -i a\ key
substitution:$(touch /should-never-exist)
backtick:`hostname`
zero:host -p 0
large:host -p 65536
huge:host -p 99999999999999999999
nonnumeric:host -p abc
negative:host -p -1
missingport:host -p
missingkey:host -i
duplicateport:host -p 22 -p 23
duplicatekey:host -i key -i other
flags:host -A -v -N -L 8080:localhost:80 -o StrictHostKeyChecking=no -p 2223
before:ssh -v -i "a key" -J jump.example -o 'ProxyCommand=nc proxy 22' -p 2224 user@target.example
attached:ssh -vvAp2225 user@attached.example
ignoredport:host -o 'ProxyCommand=nc -p 9999 proxy 22' -p 2226
onlyflags:ssh -v -i key
unclosed:host -i "key
CONFIG
cp "$HOME/.sheesh" "$WORK/original"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run_ping() {
    : > "$NC_LOG"
    status=0
    PATH="$WORK/bin" /bin/bash "$ROOT/sheesh.sh" ping "$@" > "$WORK/out" 2> "$WORK/err" || status=$?
    out=$(<"$WORK/out")
    err=$(<"$WORK/err")
}
assert_probe() {
    local host="$1" port="$2"
    local -a actual=()
    mapfile -t actual < "$NC_LOG"
    [[ ${#actual[@]} == 5 && "${actual[0]}" == -z && "${actual[1]}" == -w &&
       "${actual[2]}" == 5 && "${actual[3]}" == "$host" && "${actual[4]}" == "$port" ]] || fail 'netcat arguments'
}
assert_invalid() {
    run_ping "$@"
    [[ "$status" == 1 && -z "$out" && -n "$err" && ! -s "$NC_LOG" ]] || fail "invalid input: $*"
}

run_ping prod
[[ "$status" == 0 && -z "$out" && -z "$err" ]] || fail 'silent success'
assert_probe example.com 22
run_ping custom
assert_probe 192.168.1.100 2222
run_ping reordered
assert_probe host 22
run_ping ipv6 --verbose
assert_probe 2001:db8::1 2200
[[ "$out" == 'ipv6 ([2001:db8::1]:2200) is reachable' ]] || fail 'IPv6 verbose output'
run_ping --verbose bracketed
assert_probe ::1 22
[[ "$out" == 'bracketed ([::1]:22) is reachable' ]] || fail 'bracketed IPv6 output'
run_ping loopback
assert_probe ::1 22
run_ping first
assert_probe one.example 22
run_ping 'literal.*'
assert_probe literal.example 22
run_ping 'slash\name'
assert_probe slash.example 22

for NC_STATUS in 0 1 7 127; do
    export NC_STATUS
    expected=1
    result=unreachable
    if [[ "$NC_STATUS" == 0 ]]; then expected=0; result=reachable; fi
    run_ping prod
    [[ "$status" == "$expected" && -z "$out" && -z "$err" ]] || fail "silent status $NC_STATUS"
    for order in before after; do
        if [[ "$order" == before ]]; then run_ping --verbose prod; else run_ping prod --verbose; fi
        [[ "$status" == "$expected" && "$out" == "prod (example.com:22) is $result" && -z "$err" ]] || fail "verbose status $NC_STATUS ($order)"
    done
done
export NC_STATUS=0
assert_invalid
assert_invalid --verbose
assert_invalid prod other
assert_invalid prod --unknown
assert_invalid prod --verbose --verbose
assert_invalid ''
assert_invalid unknown
assert_invalid 'literal.'
assert_invalid ignored
for alias in empty optionhost baduser badbracket substitution backtick zero large huge nonnumeric negative missingport duplicateport onlyflags unclosed; do
    assert_invalid "$alias"
done

for alias in full jump proxy quoted escaped missingkey duplicatekey; do
    run_ping "$alias"
    [[ "$status" == 0 && -z "$out" && -z "$err" ]] || fail "ignored SSH flags: $alias"
    if [[ "$alias" == full ]]; then assert_probe example.com 22; else assert_probe host 22; fi
done
run_ping flags
assert_probe host 2223
run_ping before
assert_probe target.example 2224
run_ping attached
assert_probe attached.example 2225
run_ping ignoredport
assert_probe host 2226

# A shell substitution in a stored identity operand must never execute.
printf 'malicious:host -i $(touch %s)\n' "$WORK/executed" >> "$HOME/.sheesh"
run_ping malicious
[[ "$status" == 0 ]] || fail "ignored identity operand"
assert_probe host 22
[[ ! -e "$WORK/executed" ]] || fail 'saved text executed'
cp "$WORK/original" "$HOME/.sheesh"
# Last entry without a newline is still readable.
printf '\nlast:final.example' >> "$HOME/.sheesh"
run_ping last
assert_probe final.example 22
cp "$WORK/original" "$HOME/.sheesh"
run_ping prod
cmp -s "$WORK/original" "$HOME/.sheesh" || fail 'configuration modified'

# A PATH without nc must still produce a controlled error.
status=0
PATH="$WORK/empty-bin" /bin/bash "$ROOT/sheesh.sh" ping prod > "$WORK/out" 2> "$WORK/err" || status=$?
[[ "$status" == 1 && ! -s "$WORK/out" && $(<"$WORK/err") == *'nc is required'* ]] || fail 'missing nc'
mv "$HOME/.sheesh" "$WORK/config"
assert_invalid prod
[[ ! -e "$HOME/.sheesh" ]] || fail 'missing configuration created'
mkdir "$HOME/.sheesh"
assert_invalid prod
rmdir "$HOME/.sheesh"
mv "$WORK/config" "$HOME/.sheesh"

/bin/bash "$ROOT/sheesh.sh" help > "$WORK/help"
[[ $(<"$WORK/help") == *ping* && $(<"$WORK/help") == *--verbose* ]] || fail 'help'
source "$ROOT/sheesh-completion.sh"
assert_completion() {
    local expected="$1" candidate
    shift
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _sheesh_completions
    for candidate in "${COMPREPLY[@]}"; do
        [[ "$candidate" != "$expected" ]] || return 0
    done
    fail "missing completion: $expected ($*)"
}
assert_completion ping sheesh p
assert_completion prod sheesh ping pr
assert_completion --verbose sheesh ping --v
assert_completion prod sheesh ping --verbose pr
assert_completion --verbose sheesh ping prod --v
COMP_WORDS=(sheesh ping --verbose prod '')
COMP_CWORD=4
_sheesh_completions
[[ ${#COMPREPLY[@]} == 0 ]] || fail 'completion after all arguments'
printf 'All ping checks passed.\n'
