#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║               PIPEX TESTER v3.0 — 42 School                                ║
# ║          Output · Exit Codes · Leaks · Timing · Edge Cases                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ── CONFIG ──────────────────────────────────────────────────────────────────────
PIPEX_PATH="./pipex"
TEST_DIR="/tmp/pipex_test_$$"
VALGRIND_LOG="$TEST_DIR/valgrind.log"
TIMEOUT_SEC=10
SHOW_DIFF=1
CHECK_LEAKS=1
CHECK_BONUS=0

# ── COLORS ──────────────────────────────────────────────────────────────────────
RED='\033[1;31m'    GREEN='\033[1;32m'   YELLOW='\033[1;33m'
BLUE='\033[1;34m'   MAGENTA='\033[1;35m' CYAN='\033[1;36m'
WHITE='\033[1;37m'  GRAY='\033[0;90m'    BOLD='\033[1m'
DIM='\033[2m'       RESET='\033[0m'
CHECK="${GREEN}✓${RESET}"  CROSS="${RED}✗${RESET}"  WARN="${YELLOW}⚠${RESET}"
LEAK="${MAGENTA}💧${RESET}"

# ── COUNTERS ────────────────────────────────────────────────────────────────────
TOTAL=0; PASSED=0; FAILED=0; LEAKED=0; WARNINGS=0; TOTAL_TIME=0
_ST=0; _SP=0   # section total / section passed

# ── HELPERS ─────────────────────────────────────────────────────────────────────
get_time_ms() {
    [[ "$OSTYPE" == "linux-gnu"* ]] && { date +%s%N | cut -b1-13; return; }
    python3 -c "import time;print(int(time.time()*1000))" 2>/dev/null || date +%s000
}

fmt_time() {
    local ms=$1
    [ "$ms" -lt 1000 ] && echo "${ms}ms" || echo "$((ms/1000)).$(printf '%03d' $((ms%1000)))s"
}

time_color() {
    local ms=$1
    [ $ms -lt 100 ] && echo -e "${GREEN}$(fmt_time $ms)${RESET}" && return
    [ $ms -lt 500 ] && echo -e "${YELLOW}$(fmt_time $ms)${RESET}" && return
    echo -e "${RED}$(fmt_time $ms)${RESET}"
}

# ── SECTION TRACKING ────────────────────────────────────────────────────────────
flush_section() {
    [ $_ST -eq 0 ] && return
    local c=$GREEN
    [ $_SP -lt $_ST ] && c=$YELLOW
    [ $_SP -eq 0 ]    && c=$RED
    echo -e "  ${GRAY}└── Result: ${c}${_SP}/${_ST} passed${RESET}"
    _ST=0; _SP=0
}

print_section() {
    flush_section
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    printf "${BLUE}║${RESET}  %b  ${BOLD}${WHITE}%-61s${RESET}${BLUE}║${RESET}\n" "$2" "$1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${RESET}"
}

# ── DIFF DISPLAY ────────────────────────────────────────────────────────────────
show_diff() {
    local exp="$1" got="$2"
    echo -e "     ${GRAY}┌─ Expected (shell):${RESET}"
    if [ -f "$exp" ] && [ -s "$exp" ]; then
        head -5 "$exp" | while IFS= read -r l; do
            echo -e "     ${GRAY}│${RESET}  ${GREEN}$l${RESET}"
        done
        local n; n=$(wc -l < "$exp")
        [ "$n" -gt 5 ] && echo -e "     ${GRAY}│  ${DIM}... (+$((n-5)) lines)${RESET}"
    else
        echo -e "     ${GRAY}│  ${DIM}(empty or no file created)${RESET}"
    fi
    echo -e "     ${GRAY}├─ Got (pipex):${RESET}"
    if [ -f "$got" ] && [ -s "$got" ]; then
        head -5 "$got" | while IFS= read -r l; do
            echo -e "     ${GRAY}│${RESET}  ${RED}$l${RESET}"
        done
        local n; n=$(wc -l < "$got")
        [ "$n" -gt 5 ] && echo -e "     ${GRAY}│  ${DIM}... (+$((n-5)) lines)${RESET}"
    else
        echo -e "     ${GRAY}│  ${DIM}(empty or no file created)${RESET}"
    fi
    if [ -f "$exp" ] && [ -f "$got" ]; then
        local nd; nd=$(diff "$exp" "$got" 2>/dev/null | grep -c '^[<>]')
        [ "${nd:-0}" -gt 0 ] && echo -e "     ${GRAY}├─ ${RED}${nd} line(s) differ${RESET}"
    fi
    echo -e "     ${GRAY}└────────────────────────────────────────${RESET}"
}

# ── VALGRIND HELPER ─────────────────────────────────────────────────────────────
check_leaks() {
    local infile="$1" cmd1="$2" cmd2="$3"
    valgrind --leak-check=full --show-leak-kinds=all --track-fds=yes \
        --log-file="$VALGRIND_LOG" --error-exitcode=42 \
        "$PIPEX_PATH" "$infile" "$cmd1" "$cmd2" "$TEST_DIR/out_vg" 2>/dev/null
    local def; def=$(grep "definitely lost:" "$VALGRIND_LOG" 2>/dev/null | awk '{print $4}' | tr -d ',')
    local ind; ind=$(grep "indirectly lost:" "$VALGRIND_LOG" 2>/dev/null | awk '{print $4}' | tr -d ',')
    local fds; fds=$(grep "Open file descriptor" "$VALGRIND_LOG" 2>/dev/null | wc -l)
    fds=$((fds > 3 ? fds - 3 : 0))
    def=${def:-0}; ind=${ind:-0}
    local info="" ok=1
    if [ "$def" != "0" ] || [ "$ind" != "0" ]; then
        ok=0; info="${RED}DEF:${def}B IND:${ind}B${RESET}"; LEAKED=$((LEAKED+1))
    fi
    [ $fds -gt 0 ] && info="${info:+$info }${MAGENTA}FD:+${fds}${RESET}" && WARNINGS=$((WARNINGS+1))
    echo "${ok}|${info}"
}

# ════════════════════════════════ TEST FUNCTIONS ═════════════════════════════════

# run_test NAME INFILE CMD1 CMD2
# Compares pipex output with the equivalent shell pipeline
run_test() {
    local name="$1" infile="$2" cmd1="$3" cmd2="$4"
    local out_p="$TEST_DIR/out_pipex" out_s="$TEST_DIR/out_shell"
    TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
    rm -f "$out_p" "$out_s" "$VALGRIND_LOG"

    # Shell reference — eval preserves quoted args (e.g. "tr ' ' '\n'")
    eval "< \"$infile\" $cmd1 2>/dev/null | $cmd2 > \"$out_s\" 2>/dev/null"

    # Run pipex with timing
    local t0; t0=$(get_time_ms)
    timeout $TIMEOUT_SEC "$PIPEX_PATH" "$infile" "$cmd1" "$cmd2" "$out_p" 2>/dev/null
    local ec=$?; local el=$(( $(get_time_ms) - t0 ))
    TOTAL_TIME=$((TOTAL_TIME+el))
    local td; td=$(time_color $el)

    if [ $ec -eq 124 ]; then
        FAILED=$((FAILED+1))
        echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${RED}TIMEOUT (>${TIMEOUT_SEC}s)${RESET}"
        return
    fi

    # Compare outputs
    local ok=0
    diff -q "$out_p" "$out_s" >/dev/null 2>&1 && ok=1
    { [ ! -f "$out_p" ] && [ ! -f "$out_s" ]; } && ok=1

    # Leak check
    local lok=1 linfo=""
    if [ $CHECK_LEAKS -eq 1 ] && command -v valgrind &>/dev/null; then
        local lr; lr=$(check_leaks "$infile" "$cmd1" "$cmd2")
        lok=${lr%%|*}; linfo=${lr#*|}
    fi

    local extra="${linfo:+  ${GRAY}│${RESET} ${linfo}}"
    if [ $ok -eq 1 ] && [ $lok -eq 1 ]; then
        PASSED=$((PASSED+1)); _SP=$((_SP+1))
        echo -e "  ${CHECK}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}${extra}"
    elif [ $ok -eq 1 ]; then
        PASSED=$((PASSED+1)); _SP=$((_SP+1))
        echo -e "  ${WARN}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│${RESET} ${LEAK} ${linfo}"
    else
        FAILED=$((FAILED+1))
        echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}${extra}"
        [ $SHOW_DIFF -eq 1 ] && show_diff "$out_s" "$out_p"
    fi
}

# run_no_crash NAME [PIPEX_ARGS...]
# Checks pipex doesn't segfault/abort — any other exit code is OK
run_no_crash() {
    local name="$1"; shift
    TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
    local t0; t0=$(get_time_ms)
    timeout $TIMEOUT_SEC "$PIPEX_PATH" "$@" 2>/dev/null
    local ec=$?; local el=$(( $(get_time_ms) - t0 ))
    TOTAL_TIME=$((TOTAL_TIME+el))
    local td; td=$(time_color $el)

    case $ec in
        124) FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${RED}TIMEOUT${RESET}" ;;
        139) FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│${RESET} ${RED}SEGFAULT${RESET}" ;;
        138) FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│${RESET} ${RED}BUS ERROR${RESET}" ;;
        134) FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│${RESET} ${RED}ABORT${RESET}" ;;
        *)   PASSED=$((PASSED+1)); _SP=$((_SP+1))
             echo -e "  ${CHECK}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│ exit: ${ec}${RESET}" ;;
    esac
}

# run_exit_test NAME INFILE CMD1 CMD2
# Checks pipex returns the same exit code as the shell's last pipe command
run_exit_test() {
    local name="$1" infile="$2" cmd1="$3" cmd2="$4"
    local shell_exit t0 td el pipex_exit
    TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
    # Run in a subshell so PIPESTATUS is captured cleanly, independent of function scope
    shell_exit=$(bash -c "< \"$infile\" $cmd1 2>/dev/null | $cmd2 >/dev/null 2>/dev/null; echo \${PIPESTATUS[1]}" 2>/dev/null)
    t0=$(get_time_ms)
    timeout $TIMEOUT_SEC "$PIPEX_PATH" "$infile" "$cmd1" "$cmd2" "$TEST_DIR/out_exit" 2>/dev/null
    pipex_exit=$?; el=$(( $(get_time_ms) - t0 ))
    TOTAL_TIME=$((TOTAL_TIME+el))
    td=$(time_color $el)

    if [ $pipex_exit -eq $shell_exit ]; then
        PASSED=$((PASSED+1)); _SP=$((_SP+1))
        echo -e "  ${CHECK}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│ exit: ${GREEN}${pipex_exit}${RESET} ${GRAY}(expected: ${shell_exit})${RESET}"
    else
        FAILED=$((FAILED+1))
        echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${td}  ${GRAY}│ exit: ${RED}${pipex_exit}${RESET} ${GRAY}(expected: ${GREEN}${shell_exit}${RESET}${GRAY})${RESET}"
    fi
}

# run_outfile_test NAME — manual test for outfile behavior
run_outfile_test() {
    local name="$1" result="$2"   # result: 0=pass, 1=fail
    TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
    if [ "$result" -eq 0 ]; then
        PASSED=$((PASSED+1)); _SP=$((_SP+1))
        echo -e "  ${CHECK}  ${WHITE}${name}${RESET}"
    else
        FAILED=$((FAILED+1))
        echo -e "  ${CROSS}  ${WHITE}${name}${RESET}"
    fi
}

# ══════════════════════════════════ HEADER ════════════════════════════════════════
clear
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}██████╗ ██╗██████╗ ███████╗██╗  ██╗${RESET}                                  ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}██╔══██╗██║██╔══██╗██╔════╝╚██╗██╔╝${RESET}   ${CYAN}TESTER v3.0${RESET} — 42 School   ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}██████╔╝██║██████╔╝█████╗   ╚███╔╝ ${RESET}                                  ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}██╔═══╝ ██║██╔═══╝ ██╔══╝   ██╔██╗ ${RESET}   Output · Exit Codes            ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}██║     ██║██║     ███████╗██╔╝ ██╗${RESET}    Leaks · Timing · Edge Cases   ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}${WHITE}╚═╝     ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝${RESET}                                  ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── PARSE ARGS ───────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
        --no-leaks) CHECK_LEAKS=0 ;;
        --no-diff)  SHOW_DIFF=0 ;;
        --bonus)    CHECK_BONUS=1 ;;
        --path=*)   PIPEX_PATH="${arg#*=}" ;;
        --help|-h)
            echo -e "  ${BOLD}Usage:${RESET} $0 [options]"
            echo -e "  ${CYAN}--path=PATH${RESET}   Path to pipex binary (default: ./pipex)"
            echo -e "  ${CYAN}--bonus${RESET}       Enable bonus tests (here_doc + multi-pipe)"
            echo -e "  ${CYAN}--no-leaks${RESET}    Skip valgrind leak checks"
            echo -e "  ${CYAN}--no-diff${RESET}     Don't show diff details on failure"
            echo ""; exit 0 ;;
    esac
done

# ── CHECKS ───────────────────────────────────────────────────────────────────────
if [ ! -f "$PIPEX_PATH" ]; then
    echo -e "  ${CROSS} ${RED}Binary not found:${RESET} ${WHITE}$PIPEX_PATH${RESET}"
    echo -e "  ${GRAY}Compile first (make) or use --path=<path>${RESET}"; exit 1
fi
[ ! -x "$PIPEX_PATH" ] && chmod +x "$PIPEX_PATH"

if [ $CHECK_LEAKS -eq 1 ] && ! command -v valgrind &>/dev/null; then
    echo -e "  ${WARN} ${YELLOW}valgrind not found — leak checks disabled${RESET}"
    CHECK_LEAKS=0
elif [ $CHECK_LEAKS -eq 1 ]; then
    echo -e "  ${CHECK} ${GREEN}valgrind found — leak checks enabled${RESET}"
fi

# ── SETUP TEST FILES ─────────────────────────────────────────────────────────────
mkdir -p "$TEST_DIR"

printf "Hello World\nThis is a test file\nWith multiple lines\nFor the pipex tester\nLine five\nLine six\nLine seven\n" \
    > "$TEST_DIR/infile"
printf "" > "$TEST_DIR/empty"
printf "just one line\n" > "$TEST_DIR/oneline"
printf "apple\nbanana\napple\ncherry\napple\nbanana\ndate\ncherry\napple\n" > "$TEST_DIR/fruits"
printf "42\n1\n100\n7\n42\n99\n3\n42\n" > "$TEST_DIR/numbers"
printf "Hello WORLD\nhello world\nHELLO\nworld hello\nHeLLo WoRlD\n" > "$TEST_DIR/mixed_case"
printf "field1:field2:field3\ndata1:data2:data3\nval1:val2:val3\n" > "$TEST_DIR/colon_sep"
printf "   spaces   before\n\ttabs\there\t\nmixed \t whitespace\n" > "$TEST_DIR/whitespace"
printf "Line with 'quotes'\nLine with \"double\"\nLine with special: %s\n" '$var' > "$TEST_DIR/special"
echo "restricted content" > "$TEST_DIR/no_read" && chmod 000 "$TEST_DIR/no_read"

echo -e "  ${CHECK} ${GREEN}Test environment ready${RESET}"
echo -e "  ${GRAY}Binary: $(realpath "$PIPEX_PATH" 2>/dev/null || echo "$PIPEX_PATH")${RESET}"

# ═══════════════════════════════════════════════════════════════════════════════════
#                                    TESTS
# ═══════════════════════════════════════════════════════════════════════════════════

# ── 1. BASIC FUNCTIONALITY ───────────────────────────────────────────────────────
print_section "BASIC FUNCTIONALITY" "🔧"

run_test "cat | cat"          "$TEST_DIR/infile"  "cat"       "cat"
run_test "cat | wc -l"        "$TEST_DIR/infile"  "cat"       "wc -l"
run_test "cat | wc -w"        "$TEST_DIR/infile"  "cat"       "wc -w"
run_test "cat | wc -c"        "$TEST_DIR/infile"  "cat"       "wc -c"
run_test "cat | head -3"      "$TEST_DIR/infile"  "cat"       "head -3"
run_test "cat | tail -2"      "$TEST_DIR/infile"  "cat"       "tail -2"
run_test "echo hi | cat"      "$TEST_DIR/infile"  "echo hi"   "cat"
run_test "cat | rev"          "$TEST_DIR/infile"  "cat"       "rev"
run_test "grep test | wc -l"  "$TEST_DIR/infile"  "grep test" "wc -l"

# ── 2. UNIX PIPELINE CLASSICS ────────────────────────────────────────────────────
print_section "UNIX PIPELINE CLASSICS" "🐧"

run_test "sort | uniq"                   "$TEST_DIR/fruits"      "sort"                 "uniq"
run_test "sort | uniq -c"                "$TEST_DIR/fruits"      "sort"                 "uniq -c"
run_test "sort -n | tail -1"             "$TEST_DIR/numbers"     "sort -n"              "tail -1"
run_test "sort -n | head -1"             "$TEST_DIR/numbers"     "sort -n"              "head -1"
run_test "sort -rn | head -3"            "$TEST_DIR/numbers"     "sort -rn"             "head -3"
run_test "grep apple | wc -l"            "$TEST_DIR/fruits"      "grep apple"           "wc -l"
run_test "grep -i hello | wc -l"         "$TEST_DIR/mixed_case"  "grep -i hello"        "wc -l"
run_test "grep -v apple | sort"          "$TEST_DIR/fruits"      "grep -v apple"        "sort"
run_test "tr a-z A-Z | sort"             "$TEST_DIR/fruits"      "tr a-z A-Z"           "sort"
run_test "tr A-Z a-z | sort"             "$TEST_DIR/infile"      "tr A-Z a-z"           "sort"
run_test "tr ' ' '\n' | sort"            "$TEST_DIR/oneline"     "tr ' ' '\n'"          "sort"
run_test "cut -d: -f2 | sort"            "$TEST_DIR/colon_sep"   "cut -d: -f2"          "sort"
run_test "cat -n | tail -3"              "$TEST_DIR/infile"      "cat -n"               "tail -3"
run_test "rev | rev"                     "$TEST_DIR/infile"      "rev"                  "rev"
run_test "sed 's/apple/APPLE/g' | sort"  "$TEST_DIR/fruits"      "sed 's/apple/APPLE/g'" "sort"
run_test "awk '{print NR, \$0}' | head"  "$TEST_DIR/infile"      "awk '{print NR, \$0}'" "head -3"

# ── 3. PATH RESOLUTION ───────────────────────────────────────────────────────────
print_section "PATH RESOLUTION" "🔍"

run_test "/bin/cat | /usr/bin/wc -l"    "$TEST_DIR/infile"  "/bin/cat"      "/usr/bin/wc -l"
run_test "/usr/bin/sort | uniq"         "$TEST_DIR/fruits"  "/usr/bin/sort" "uniq"
run_test "relative cmd (PATH lookup)"   "$TEST_DIR/infile"  "cat"           "wc"
[ -f "/bin/grep" ] && \
run_test "/bin/grep | wc -l"            "$TEST_DIR/infile"  "/bin/grep Hello" "/usr/bin/wc -l"

# ── 4. ERROR HANDLING ────────────────────────────────────────────────────────────
print_section "ERROR HANDLING" "⚠️"
echo -e "  ${DIM}${GRAY}Must not crash (segfault/abort = fail) — any other exit is OK${RESET}"
echo ""

run_no_crash "Invalid infile"           "/no/such/file_42"      "cat"         "wc -l"   "$TEST_DIR/out_e1"
run_no_crash "Invalid cmd1"             "$TEST_DIR/infile"      "fakecmd_42"  "wc -l"   "$TEST_DIR/out_e2"
run_no_crash "Invalid cmd2"             "$TEST_DIR/infile"      "cat"         "fakecmd_42" "$TEST_DIR/out_e3"
run_no_crash "Both cmds invalid"        "$TEST_DIR/infile"      "fake1_42"    "fake2_42" "$TEST_DIR/out_e4"
run_no_crash "Invalid infile + bad cmds" "/no/such/file_42"     "fake1_42"    "fake2_42" "$TEST_DIR/out_e5"
run_no_crash "No read permission"       "$TEST_DIR/no_read"     "cat"         "wc -l"   "$TEST_DIR/out_e6"
run_no_crash "Empty cmd1"               "$TEST_DIR/infile"      ""            "wc -l"   "$TEST_DIR/out_e7"
run_no_crash "Empty cmd2"               "$TEST_DIR/infile"      "cat"         ""        "$TEST_DIR/out_e8"
run_no_crash "Both cmds empty"          "$TEST_DIR/infile"      ""            ""        "$TEST_DIR/out_e9"
run_no_crash "Space-only cmd1"          "$TEST_DIR/infile"      "   "         "wc -l"   "$TEST_DIR/out_e10"

# ── 5. OUTFILE BEHAVIOR ──────────────────────────────────────────────────────────
print_section "OUTFILE BEHAVIOR" "📄"
echo -e "  ${DIM}${GRAY}Outfile must be created/truncated — even when infile is missing${RESET}"
echo ""

# Test 1: outfile must be truncated (not appended)
echo "OLD CONTENT THAT SHOULD BE GONE" > "$TEST_DIR/trunc_test"
timeout $TIMEOUT_SEC "$PIPEX_PATH" "$TEST_DIR/infile" "cat" "wc -l" "$TEST_DIR/trunc_test" 2>/dev/null
if [ -f "$TEST_DIR/trunc_test" ] && ! grep -q "OLD CONTENT" "$TEST_DIR/trunc_test" 2>/dev/null; then
    run_outfile_test "Outfile is truncated (O_TRUNC, not O_APPEND)" 0
else
    run_outfile_test "Outfile is truncated (O_TRUNC, not O_APPEND)" 1
fi

# Test 2: outfile must be created even if infile doesn't exist
rm -f "$TEST_DIR/out_no_infile"
timeout $TIMEOUT_SEC "$PIPEX_PATH" "/no/such/file_42" "cat" "wc -l" "$TEST_DIR/out_no_infile" 2>/dev/null
if [ -f "$TEST_DIR/out_no_infile" ]; then
    run_outfile_test "Outfile created even when infile is missing" 0
else
    run_outfile_test "Outfile created even when infile is missing" 1
fi

# Test 3: outfile content matches shell when cmd2 writes nothing (cmd1 fails)
# (just checks no crash and file is created)
rm -f "$TEST_DIR/out_cmd1fail"
timeout $TIMEOUT_SEC "$PIPEX_PATH" "/no/such/file_42" "cat" "cat" "$TEST_DIR/out_cmd1fail" 2>/dev/null
if [ -f "$TEST_DIR/out_cmd1fail" ]; then
    run_outfile_test "Outfile created when cmd1 fails" 0
else
    run_outfile_test "Outfile created when cmd1 fails" 1
fi

# ── 6. EXIT CODES ────────────────────────────────────────────────────────────────
print_section "EXIT CODES" "🔢"
echo -e "  ${DIM}${GRAY}pipex must return the exit code of the last command (cmd2)${RESET}"
echo ""

run_exit_test "cat | cat → 0"               "$TEST_DIR/infile"  "cat"         "cat"
run_exit_test "cat | grep Hello → 0"        "$TEST_DIR/infile"  "cat"         "grep Hello"
run_exit_test "cat | grep NOTFOUND → 1"     "$TEST_DIR/infile"  "cat"         "grep NOTFOUND"
run_exit_test "cat | true → 0"              "$TEST_DIR/infile"  "cat"         "true"
run_exit_test "cat | false → 1"             "$TEST_DIR/infile"  "cat"         "false"
run_exit_test "fakecmd | cat → 0"           "$TEST_DIR/infile"  "fakecmd_42"  "cat"
run_exit_test "cat | fakecmd → 127"         "$TEST_DIR/infile"  "cat"         "fakecmd_42"
run_exit_test "fakecmd | fakecmd → 127"     "$TEST_DIR/infile"  "fakecmd_42"  "fakecmd_42"

# ── 7. EDGE CASES ────────────────────────────────────────────────────────────────
print_section "EDGE CASES" "🧪"

run_test "Empty input file"          "$TEST_DIR/empty"      "cat"       "wc -l"
run_test "Empty file | cat"          "$TEST_DIR/empty"      "cat"       "cat"
run_test "Single line | wc -w"       "$TEST_DIR/oneline"    "cat"       "wc -w"
run_test "Whitespace file | wc -l"   "$TEST_DIR/whitespace" "cat"       "wc -l"
run_test "Special chars | wc -l"     "$TEST_DIR/special"    "cat"       "wc -l"
run_test "cmd with multiple flags"   "$TEST_DIR/fruits"     "sort -r"   "uniq -c"
run_test "grep -c flag | cat"        "$TEST_DIR/fruits"     "grep -c apple" "cat"
run_test "tr range | sort"           "$TEST_DIR/infile"     "tr A-Z a-z" "sort"
run_test "head -0 (empty output)"    "$TEST_DIR/infile"     "cat"       "head -0"
run_test "tail -1 (last line)"       "$TEST_DIR/infile"     "cat"       "tail -1"
run_test "sort | tail -1 (max num)"  "$TEST_DIR/numbers"    "sort -n"   "tail -1"
run_test "uniq -d (only dupes)"      "$TEST_DIR/fruits"     "sort"      "uniq -d"

# ── 8. ARGUMENT VALIDATION ───────────────────────────────────────────────────────
print_section "ARGUMENT VALIDATION" "📋"
echo -e "  ${DIM}${GRAY}Wrong number of arguments must not crash${RESET}"
echo ""

run_no_crash "0 arguments"
run_no_crash "1 argument"    "one"
run_no_crash "2 arguments"   "one" "two"
run_no_crash "3 arguments"   "one" "two" "three"

# ── 9. STRESS TESTS ──────────────────────────────────────────────────────────────
print_section "STRESS TESTS" "💪"
echo -e "  ${GRAY}Generating large test files...${RESET}"

seq 1 10000  > "$TEST_DIR/large_10k"
seq 1 100000 > "$TEST_DIR/large_100k"
python3 -c "
for i in range(1000):
    print('A' * 200 + ' line_' + str(i))
" > "$TEST_DIR/long_lines" 2>/dev/null || \
    seq 1 1000 | awk '{printf "%200s line_%s\n", "A", $1}' > "$TEST_DIR/long_lines"
dd if=/dev/urandom bs=1024 count=10 2>/dev/null | base64 > "$TEST_DIR/binary_b64"
echo ""

run_test "10K lines: sort -n | tail -5"   "$TEST_DIR/large_10k"  "sort -n"  "tail -5"
run_test "100K lines: wc -l | cat"        "$TEST_DIR/large_100k" "wc -l"    "cat"
run_test "100K: sort -n | tail -1"        "$TEST_DIR/large_100k" "sort -n"  "tail -1"
run_test "Long lines: cat | wc -l"        "$TEST_DIR/long_lines" "cat"      "wc -l"
run_test "Base64: cat | wc -c"            "$TEST_DIR/binary_b64" "cat"      "wc -c"

# ── 10. MEMORY LEAK DEEP SCAN ────────────────────────────────────────────────────
if [ $CHECK_LEAKS -eq 1 ]; then
    print_section "MEMORY LEAK DEEP SCAN" "💧"
    echo -e "  ${GRAY}Detailed valgrind analysis on key scenarios...${RESET}"
    echo ""

    do_leak() {
        local name="$1"; shift
        TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
        valgrind --leak-check=full --show-leak-kinds=all --track-fds=yes \
            --track-origins=yes --log-file="$VALGRIND_LOG" \
            "$PIPEX_PATH" "$@" 2>/dev/null
        local def; def=$(grep "definitely lost:" "$VALGRIND_LOG" 2>/dev/null | awk '{print $4}' | tr -d ',')
        local ind; ind=$(grep "indirectly lost:" "$VALGRIND_LOG" 2>/dev/null | awk '{print $4}' | tr -d ',')
        local fds; fds=$(grep "Open file descriptor" "$VALGRIND_LOG" 2>/dev/null | wc -l)
        fds=$((fds > 3 ? fds - 3 : 0))
        def=${def:-0}; ind=${ind:-0}
        if [ "$def" != "0" ] || [ "$ind" != "0" ]; then
            FAILED=$((FAILED+1)); LEAKED=$((LEAKED+1))
            echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${RED}DEF:${def}B IND:${ind}B${RESET}${fds:+  ${MAGENTA}FD:+${fds}${RESET}}"
        else
            PASSED=$((PASSED+1)); _SP=$((_SP+1))
            local reach; reach=$(grep "still reachable:" "$VALGRIND_LOG" 2>/dev/null | awk '{print $4}' | tr -d ',')
            reach=${reach:-0}
            local info="${GREEN}CLEAN${RESET}"
            [ "$reach" != "0" ] && info="${YELLOW}REACH:${reach}B${RESET}"
            [ $fds -gt 0 ]      && info="$info ${MAGENTA}FD:+${fds}${RESET}" && WARNINGS=$((WARNINGS+1))
            echo -e "  ${CHECK}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} $info"
        fi
    }

    do_leak "Normal: cat | wc -l"      "$TEST_DIR/infile"    "cat"      "wc -l"    "$TEST_DIR/out_vg1"
    do_leak "Invalid infile"           "/tmp/nope_42_xxx"    "cat"      "wc -l"    "$TEST_DIR/out_vg2"
    do_leak "Invalid cmd1"             "$TEST_DIR/infile"    "fake_42"  "wc -l"    "$TEST_DIR/out_vg3"
    do_leak "Invalid cmd2"             "$TEST_DIR/infile"    "cat"      "fake_42"  "$TEST_DIR/out_vg4"
    do_leak "Both cmds invalid"        "$TEST_DIR/infile"    "fake1_42" "fake2_42" "$TEST_DIR/out_vg5"
    do_leak "No read permission"       "$TEST_DIR/no_read"   "cat"      "wc -l"    "$TEST_DIR/out_vg6"
    do_leak "Empty file: cat | cat"    "$TEST_DIR/empty"     "cat"      "cat"      "$TEST_DIR/out_vg7"
    do_leak "Large file: sort | tail"  "$TEST_DIR/large_10k" "sort"     "tail -1"  "$TEST_DIR/out_vg8"
fi

# ── 11. BONUS ────────────────────────────────────────────────────────────────────
if [ $CHECK_BONUS -eq 1 ]; then
    print_section "BONUS: HERE_DOC" "📜"

    run_heredoc() {
        local name="$1" lim="$2" cmd1="$3" cmd2="$4" input="$5"
        local out_p="$TEST_DIR/out_hd_p" out_s="$TEST_DIR/out_hd_s"
        TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
        rm -f "$out_p" "$out_s"
        printf "%s\n" "$input" | eval "$cmd1 2>/dev/null" | eval "$cmd2 >> \"$out_s\" 2>/dev/null"
        printf "%s\n%s\n" "$input" "$lim" | \
            timeout $TIMEOUT_SEC "./pipex_bonus" "here_doc" "$lim" "$cmd1" "$cmd2" "$out_p" 2>/dev/null
        local ec=$?
        [ $ec -eq 124 ] && { FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${RED}TIMEOUT${RESET}"; return; }
        if diff -q "$out_p" "$out_s" >/dev/null 2>&1; then
            PASSED=$((PASSED+1)); _SP=$((_SP+1)); echo -e "  ${CHECK}  ${WHITE}${name}${RESET}"
        else
            FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│ output differs${RESET}"
            [ $SHOW_DIFF -eq 1 ] && show_diff "$out_s" "$out_p"
        fi
    }

    run_heredoc "here_doc cat | wc -l"    "EOF"  "cat"        "wc -l"  "Hello World"$'\n'"Second line"$'\n'"Third"
    run_heredoc "here_doc grep | wc -l"   "STOP" "grep hello" "wc -l"  "hello world"$'\n'"goodbye"$'\n'"hello again"
    run_heredoc "here_doc sort | uniq"    "END"  "sort"       "uniq"   "banana"$'\n'"apple"$'\n'"banana"$'\n'"cherry"

    print_section "BONUS: MULTI-PIPE" "🔗"

    run_multipipe() {
        local name="$1" infile="$2"; shift 2
        local cmds=("$@")
        local last=$(( ${#cmds[@]} - 1 ))
        local outfile="${cmds[$last]}"; unset 'cmds[$last]'
        local out_s="$TEST_DIR/out_mp_s"
        TOTAL=$((TOTAL+1)); _ST=$((_ST+1))
        rm -f "$outfile" "$out_s"
        local shell_cmd="< \"$infile\""
        for cmd in "${cmds[@]}"; do shell_cmd="$shell_cmd $cmd |"; done
        eval "${shell_cmd%|} > \"$out_s\" 2>/dev/null"
        local t0; t0=$(get_time_ms)
        timeout $TIMEOUT_SEC "./pipex_bonus" "$infile" "${cmds[@]}" "$outfile" 2>/dev/null
        local ec=$?; local el=$(( $(get_time_ms) - t0 ))
        TOTAL_TIME=$((TOTAL_TIME+el))
        [ $ec -eq 124 ] && { FAILED=$((FAILED+1)); echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} ${RED}TIMEOUT${RESET}"; rm -f "$outfile"; return; }
        if diff -q "$outfile" "$out_s" >/dev/null 2>&1; then
            PASSED=$((PASSED+1)); _SP=$((_SP+1))
            echo -e "  ${CHECK}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} $(time_color $el)"
        else
            FAILED=$((FAILED+1))
            echo -e "  ${CROSS}  ${WHITE}${name}${RESET}  ${GRAY}│${RESET} $(time_color $el)  ${GRAY}│ output differs${RESET}"
            [ $SHOW_DIFF -eq 1 ] && show_diff "$out_s" "$outfile"
        fi
        rm -f "$outfile"
    }

    run_multipipe "3 cmds: cat | sort | uniq"            "$TEST_DIR/fruits" "cat" "sort" "uniq" "$TEST_DIR/out_mp1"
    run_multipipe "4 cmds: cat | grep a | sort | wc -l"  "$TEST_DIR/fruits" "cat" "grep a" "sort" "wc -l" "$TEST_DIR/out_mp2"
    run_multipipe "5 cmds: cat|tr|sort|uniq|wc -l"       "$TEST_DIR/fruits" "cat" "tr a-z A-Z" "sort" "uniq" "wc -l" "$TEST_DIR/out_mp3"
fi

# Flush last section
flush_section

# ═══════════════════════════════════════════════════════════════════════════════════
#                                  FINAL REPORT
# ═══════════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}                         ${BOLD}${WHITE}FINAL REPORT${RESET}                                ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════╣${RESET}"

PERCENT=0; [ $TOTAL -gt 0 ] && PERCENT=$((PASSED*100/TOTAL))

if   [ $PERCENT -eq 100 ]; then SC=$GREEN;  VD="${GREEN}${BOLD}PERFECT!${RESET} 🚀"
elif [ $PERCENT -ge 90  ]; then SC=$GREEN;  VD="${GREEN}${BOLD}EXCELLENT${RESET} 🌟"
elif [ $PERCENT -ge 75  ]; then SC=$YELLOW; VD="${YELLOW}${BOLD}GOOD — minor issues${RESET}"
elif [ $PERCENT -ge 50  ]; then SC=$YELLOW; VD="${YELLOW}${BOLD}NEEDS WORK${RESET}"
else                             SC=$RED;    VD="${RED}${BOLD}FAILING${RESET} 😬"
fi

W=40; F=0; [ $TOTAL -gt 0 ] && F=$((PASSED*W/TOTAL)); E=$((W-F))
BAR=""; for ((i=0;i<F;i++)); do BAR+="█"; done; for ((i=0;i<E;i++)); do BAR+="░"; done

echo -e "${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}Score:${RESET}   ${SC}${BAR} ${PASSED}/${TOTAL} (${PERCENT}%)${RESET}"
echo -e "${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${CHECK}  ${GREEN}Passed:${RESET}    ${BOLD}${PASSED}${RESET}"
echo -e "${CYAN}║${RESET}  ${CROSS}  ${RED}Failed:${RESET}    ${BOLD}${FAILED}${RESET}"
[ $CHECK_LEAKS -eq 1 ] && echo -e "${CYAN}║${RESET}  ${LEAK}  ${MAGENTA}Leaks:${RESET}     ${BOLD}${LEAKED}${RESET}"
[ $WARNINGS   -gt 0  ] && echo -e "${CYAN}║${RESET}  ${WARN}  ${YELLOW}Warnings:${RESET}  ${BOLD}${WARNINGS}${RESET}"
TDISP="$(fmt_time $TOTAL_TIME)"
echo -e "${CYAN}║${RESET}  ⏱   ${CYAN}Total time:${RESET} ${BOLD}${TDISP}${RESET}"
echo -e "${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}  ${BOLD}Verdict:${RESET} ${VD}"
echo -e "${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}┌──────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${RED}│${RESET}  ${BOLD}Debug tips:${RESET}                                                      ${RED}│${RESET}"
    echo -e "${RED}│${RESET}  ${GRAY}• Output differs? →  < infile cmd1 | cmd2 > outfile${RESET}             ${RED}│${RESET}"
    echo -e "${RED}│${RESET}  ${GRAY}• Segfault?       →  check NULL, malloc return, fd values${RESET}       ${RED}│${RESET}"
    echo -e "${RED}│${RESET}  ${GRAY}• Wrong exit?     →  return WEXITSTATUS of last child${RESET}           ${RED}│${RESET}"
    echo -e "${RED}│${RESET}  ${GRAY}• Timeout?        →  make sure all pipe FDs are closed${RESET}          ${RED}│${RESET}"
    echo -e "${RED}│${RESET}  ${GRAY}• Outfile issue?  →  open with O_TRUNC before forking${RESET}           ${RED}│${RESET}"
    echo -e "${RED}└──────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
fi
if [ $LEAKED -gt 0 ]; then
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${MAGENTA}│${RESET}  ${BOLD}Leak tips:${RESET}                                                        ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  ${GRAY}• Free ft_split / PATH results after use${RESET}                       ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  ${GRAY}• Free path string if execve fails${RESET}                             ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}│${RESET}  ${GRAY}• In child: free before exit() or execve()${RESET}                     ${MAGENTA}│${RESET}"
    echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
fi

# Cleanup
chmod 644 "$TEST_DIR/no_read" 2>/dev/null
rm -rf "$TEST_DIR"
[ $FAILED -eq 0 ] && exit 0 || exit 1
