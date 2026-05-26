# Contact Package

This package contains a compact MATLAB/Simulink feasibility prototype for quality-aware wearable RRI monitoring policy. It is a compact contact package, not a full development repository.

## Main Message

I implemented a MATLAB/Simulink feasibility testbench for quality-aware wearable RRI monitoring policy. The system does not directly alert on noisy high-risk observations; instead, it estimates risk-state under signal-quality uncertainty and controls whether to observe, request more data, request confirmation, or issue a direct alert.

## Contents

- `professor_summary_1page.md`: concise research direction summary.
- `phase2_engineering_report.md`: engineering formulation, safety invariants, and demonstration results.
- `figures/`: key figures for the contact discussion.
- `outputs/`: core CSV outputs and pass/fail summaries.
- `code/`: clean MATLAB source folders for Phase 1, Phase 2, Phase 3, and shared config.

Large raw datasets, MATLAB project resources, workspace files, and external-RRI scaffold files are intentionally excluded.

## What This Is Not

- Not a diagnosis tool.
- Not a recurrence-prediction tool.
- Not an anatomy segmentation project.
- Not a treatment-efficacy claim.

## How To Reproduce

All reproducibility commands in this contact package assume that MATLAB's current directory is `contact_package/code`.

```matlab
cd('C:\path\to\contact_package\code')

run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')

run('phase2_signal_control_mvp/scripts/build_simulink_testbench.m')

run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

Phase 1 is included as reference code and cleaned output. Raw MRI/label files are not included; to rerun Phase 1, copy `config/paths_local_template.m` to `config/paths_local.m` and set the local raw-data path.

Public ECG-derived RRI sanity checking is intentionally deferred and is not included as a result claim in this package.
