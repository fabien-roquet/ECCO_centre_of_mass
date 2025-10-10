#!/usr/bin/env bash
set -euo pipefail

# ====== CONFIG ======
CONDA_ENV="ecco"                     # conda env to use
NOTEBOOKS=(                          # absolute or relative paths
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/01.Global_Trends_N2_and_CoM.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/01b.Trends_Visualisation.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/02.Compute_Local_Trends.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/02b.Plot_Local_Mean.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/02c.Plot_Local_Trends.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/03.N2_and_CoM_Depths.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/03b.Depths_Visualisation.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/04.N2_and_CoM_Partial_Means.ipynb"
  "/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/04b.Plot_Partial_mean_Profiles.ipynb"
)
LOG_DIR="/media/disk3/share_disk3/ECCO_products/compute_centre_of_mass/Roquet_et_al_2026/nb_logs"            # where logs will be written
INPLACE=true                         # true -> overwrite; false -> write *_executed.ipynb
TIMEOUT="-1"                         # -1 disables timeouts
KERNEL_NAME=""                       # e.g., "ecco" to force a specific kernel; empty to auto
STOP_ON_ERROR=true                   # true: stop if a notebook fails; false: continue
# =====================

mkdir -p "$LOG_DIR"

run_nb() {
  local nb="$1"
  local base out_arg
  base="$(basename "$nb" .ipynb)"
  if [[ "$INPLACE" == "true" ]]; then
    out_arg="--inplace"
  else
    out_arg="--output ${base}_executed.ipynb"
  fi

  local kernel_arg=()
  if [[ -n "$KERNEL_NAME" ]]; then
    kernel_arg=(--ExecutePreprocessor.kernel_name="$KERNEL_NAME")
  fi

  echo "[$(date '+%F %T')] Starting: $nb"
  conda run -n "$CONDA_ENV" python -m jupyter nbconvert \
    --to notebook --execute $out_arg \
    --ExecutePreprocessor.timeout="$TIMEOUT" \
    "${kernel_arg[@]}" \
    "$nb"
  echo "[$(date '+%F %T')] Finished: $nb"
}

overall_log="${LOG_DIR}/batch_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$overall_log") 2>&1

echo "===== Notebook batch start $(date '+%F %T') ====="
echo "Environment: $CONDA_ENV"
echo "Logs: $overall_log"
echo "----------------------------------------------"

for nb in "${NOTEBOOKS[@]}"; do
  if [[ ! -f "$nb" ]]; then
    echo "[ERROR] Not found: $nb"
    if [[ "$STOP_ON_ERROR" == "true" ]]; then exit 1; else continue; fi
  fi

  # per-notebook log (captures nbconvert stdout/stderr)
  nb_log="${LOG_DIR}/$(basename "$nb" .ipynb).log"
  {
    echo "----- $(date '+%F %T') Executing $nb -----"
    if run_nb "$nb"; then
      echo "----- $(date '+%F %T') SUCCESS $nb -----"
    else
      rc=$?
      echo "----- $(date '+%F %T') FAILED $nb (rc=$rc) -----"
      if [[ "$STOP_ON_ERROR" == "true" ]]; then exit "$rc"; fi
    fi
  } | tee -a "$nb_log"
done

echo "----------------------------------------------"
echo "===== Notebook batch end $(date '+%F %T') ====="
