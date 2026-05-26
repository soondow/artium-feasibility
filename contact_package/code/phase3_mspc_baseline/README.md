# Phase 3 MSPC Baseline

Phase 3 adds an MSPC-based anomaly-observation baseline to the Phase 2 wearable RRI monitoring-policy testbench. It trains a PCA/MSPC normal-operating-condition model on normal, high-quality HRV windows and scores all Phase 2 windows using T2 and Q residual statistics.

## Purpose

The MSPC score is an observation candidate, not a final decision policy. It is used to compare a process-monitoring anomaly score with the transparent hand-crafted irregularity proxy:

- Case A: observer input = `risk_proxy`
- Case B: observer input = `mspc_risk`
- Case C: observer input = `max(risk_proxy, mspc_risk)`

Signal quality and coverage remain controller-stage confidence variables. If MSPC is high but signal quality is low, the Phase 2 safety gate suppresses direct alerts and routes the case to `request_more_data` or `request_confirmation`.

## MSPC Normalization

The current MSPC-to-risk mapping is a bounded heuristic normalization for feasibility testing:

```text
risk = 0.12 + 0.58 * (1 - exp(-0.75 * mspcScore))
```

This mapping is not optimized and may saturate before reaching high-risk levels. Calibration is left as a next step.

## Interpretation

MSPC is included as a process-monitoring anomaly-observation baseline. It is not yet calibrated as an improved controller input.

The MSPC score is not yet calibrated as a superior controller input. In the near-threshold-noise scenario, MSPC or hybrid observations can increase false direct-alert episodes. Therefore, Phase 3 is interpreted as a baseline comparison and calibration target.

Current near-threshold result:

```text
near_threshold_noise / risk_proxy:
direct_alert_episode_count = 0

near_threshold_noise / mspc:
direct_alert_episode_count = 7
false_direct_alert_episode_count = 7

near_threshold_noise / hybrid:
direct_alert_episode_count = 7
false_direct_alert_episode_count = 7
```

This result shows why the MSPC-to-risk mapping needs calibration before being used as a controller input.

## Run

```matlab
cd('C:\atrium-feasibility')
run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
```

## Outputs

- `outputs/mspc_scores.csv`
- `outputs/mspc_window_score_comparison.csv`
- `outputs/mspc_event_metrics.csv`
- `outputs/phase3_test_results.csv`
- `figures/figure_06_mspc_score_trajectory.png`
- `figures/figure_07_risk_proxy_vs_mspc.png`

`outputs/mspc_window_score_comparison.csv` is the window-level comparison of the hand-crafted risk proxy, MSPC risk observation, and hybrid observation. `outputs/mspc_event_metrics.csv` reports `risk_source`, direct-alert episodes, request/confirmation episodes, total action episodes, non-risk safety-action episodes, risk-episode detection counts, `policy_transition_count`, `action_switch_count`, and `direct_alert_switch_count`. Episode/day metrics use actual `start_sec`/`stop_sec` duration; `day0_6` is only a plotting axis.

## Tests

```matlab
cd('C:\atrium-feasibility')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

The tests check that normal MSPC scores remain low, high-risk synthetic segments increase the MSPC observation, near-threshold limitations are surfaced as warnings, and duration calculations use real window time.

## Future Calibration

- Adjust MSPC-to-risk normalization.
- Apply quality-aware MSPC score damping.
- Tune Q/T2 limits using only normal windows.
- Compare Q-only, T2-only, max(Q,T2), and weighted combinations.
- Evaluate near-threshold false direct-alert sensitivity.
