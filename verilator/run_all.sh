#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
#
# Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

# Build and run every sim/**/*_tb.sv with Verilator 5.
# Run from anywhere; the script cds to the colibri_sv root.
# Exit 0 only when every test exits 0.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

JOBS="${JOBS:-4}"
pass=0
fail=0
declare -a failed_names=()

if ! command -v verilator >/dev/null 2>&1; then
  echo "verilator is not on PATH" >&2
  exit 1
fi

mapfile -t tests < <(find sim -type f -name '*_tb.sv' | sort)
if (( ${#tests[@]} == 0 )); then
  echo "no testbenches found under sim/" >&2
  exit 1
fi

# File lists that the per-directory runs used, selected by testbench path.
lists_for() {
  local tb="$1"
  case "$tb" in
    sim/common/*)
      echo verilator/files/common.f
      ;;
    sim/memory/*|sim/comms/*)
      echo verilator/files/common.f verilator/files/memory.f verilator/files/comms.f
      ;;
    sim/endec/*)
      echo verilator/files/common.f verilator/files/endec.f
      ;;
    sim/io/*)
      echo verilator/files/common.f verilator/files/io.f
      ;;
    sim/interfaces/*)
      echo verilator/files/common.f verilator/files/memory.f verilator/files/interfaces.f
      ;;
    sim/packet/*|sim/pipes/*)
      echo verilator/files/common.f verilator/files/memory.f verilator/files/interfaces.f verilator/files/misc.f verilator/files/packet_pipes.f
      ;;
    sim/misc/*)
      echo verilator/files/common.f verilator/files/memory.f verilator/files/interfaces.f verilator/files/misc.f
      ;;
    sim/proto/*)
      echo verilator/files/common.f verilator/files/memory.f verilator/files/comms.f verilator/files/endec.f verilator/files/aurora.f
      ;;
    sim/fileio/*)
      echo verilator/files/fileio.f
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

# Bound checkers that belong with this testbench. Name match, plus the
# extra binds the directory runs already used (second interleaver checker,
# deinterleaver on the loopback, both RAM checkers, both gearbox checkers).
svas_for() {
  local tb="$1"
  local top stem
  top="$(basename "$tb" .sv)"
  stem="${top%_tb}"
  local -a out=()
  local f g

  case "$top" in
    interleaver_tb)
      out+=(fv/packet/interleaver_sva.sv fv/packet/interleaver_bd_sva.sv)
      ;;
    interleaver_loopback_tb)
      out+=(
        fv/packet/interleaver_sva.sv
        fv/packet/interleaver_bd_sva.sv
        fv/packet/deinterleaver_sva.sv
      )
      ;;
    avst_ram_tb)
      out+=(
        fv/interfaces/stream/avst_ram_write_sva.sv
        fv/interfaces/stream/avst_ram_read_sva.sv
      )
      ;;
    avst_ram_be_tb)
      out+=(fv/interfaces/stream/avst_ram_write_unaligned_sva.sv)
      ;;
    *)
      while IFS= read -r f; do
        [[ -n "$f" ]] && out+=("$f")
      done < <(find fv -type f -name "${stem}_sva.sv" | sort)
      ;;
  esac

  if [[ "$tb" == sim/comms/* ]]; then
    for g in fv/comms/gearbox_up_sva.sv fv/comms/gearbox_down_sva.sv; do
      local seen=0
      for f in "${out[@]+"${out[@]}"}"; do
        if [[ "$f" == "$g" ]]; then
          seen=1
          break
        fi
      done
      if (( seen == 0 )); then
        out+=("$g")
      fi
    done
  fi

  if (( ${#out[@]} > 0 )); then
    printf '%s\n' "${out[@]}"
  fi
}

run_one() {
  local tb="$1"
  local top log
  local -a lists=() svas=() cmd=()
  top="$(basename "$tb" .sv)"
  log="obj_dir/${top}/run.log"
  mkdir -p "obj_dir/${top}"

  read -r -a lists <<< "$(lists_for "$tb")"
  if [[ "${lists[0]}" == "UNKNOWN" ]]; then
    echo "no file list for ${tb}" >"$log"
    echo FAIL >"obj_dir/${top}/result"
    return 1
  fi

  mapfile -t svas < <(svas_for "$tb")

  cmd=(
    verilator --timing --binary --assert
    -Wno-DECLFILENAME -Wno-MULTITOP
    -j 1
    --Mdir "obj_dir/${top}"
    --top "$top"
    -f verilator/colibri.f
  )
  local list
  for list in "${lists[@]}"; do
    cmd+=(-f "$list")
  done
  if [[ "$tb" == sim/packet/* ]]; then
    cmd+=(sim/packet/packet_tb_pkg.sv)
  fi
  cmd+=("$tb")
  if (( ${#svas[@]} > 0 )); then
    cmd+=("${svas[@]}")
  fi

  {
    printf 'CMD'
    printf ' %q' "${cmd[@]}"
    printf '\n'
    "${cmd[@]}"
  } >"$log" 2>&1 || {
    echo FAIL >"obj_dir/${top}/result"
    return 1
  }

  if [[ ! -x "obj_dir/${top}/V${top}" ]]; then
    echo "missing binary obj_dir/${top}/V${top}" >>"$log"
    echo FAIL >"obj_dir/${top}/result"
    return 1
  fi

  if "./obj_dir/${top}/V${top}" >>"$log" 2>&1; then
    echo PASS >"obj_dir/${top}/result"
    return 0
  fi
  echo FAIL >"obj_dir/${top}/result"
  return 1
}

mkdir -p obj_dir
echo "Running ${#tests[@]} testbenches with ${JOBS} jobs"

declare -a pids=()
declare -a names=()

# Reap whichever job finished so a slow compile does not hold the other slots.
reap_one() {
  local pid="" i="" name=""
  wait -n || true
  for i in "${!pids[@]}"; do
    pid="${pids[i]}"
    if ! kill -0 "$pid" 2>/dev/null; then
      name="${names[i]}"
      unset 'pids[i]'
      unset 'names[i]'
      if (( ${#pids[@]} > 0 )); then
        pids=("${pids[@]}")
        names=("${names[@]}")
      else
        pids=()
        names=()
      fi
      if [[ -f "obj_dir/${name}/result" ]] && [[ "$(cat "obj_dir/${name}/result")" == PASS ]]; then
        echo "PASS ${name}"
        pass=$((pass + 1))
      else
        echo "FAIL ${name}"
        fail=$((fail + 1))
        failed_names+=("$name")
        if [[ -f "obj_dir/${name}/run.log" ]]; then
          echo "----- ${name} (last 40 lines) -----"
          tail -n 40 "obj_dir/${name}/run.log"
          echo "----- end ${name} -----"
        fi
      fi
      return 0
    fi
  done
  echo "reap_one: wait returned but every job is still alive" >&2
  return 0
}

for tb in "${tests[@]}"; do
  run_one "$tb" &
  pids+=("$!")
  names+=("$(basename "$tb" .sv)")
  if (( ${#pids[@]} >= JOBS )); then
    reap_one
  fi
done

while (( ${#pids[@]} > 0 )); do
  reap_one
done

echo
echo "Summary: ${pass} passed, ${fail} failed, $((pass + fail)) total"
if (( fail > 0 )); then
  echo "Failed:"
  printf '  %s\n' "${failed_names[@]}"
  exit 1
fi
exit 0
