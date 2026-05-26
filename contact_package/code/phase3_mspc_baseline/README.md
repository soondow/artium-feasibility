# Phase 3 MSPC Baseline 안내

Phase 3는 Phase 2 wearable RRI monitoring-policy testbench에 MSPC 기반 anomaly-observation baseline을 추가합니다. Normal, high-quality HRV window로 PCA/MSPC normal-operating-condition model을 학습하고, T2 및 Q residual statistic으로 모든 Phase 2 window를 score합니다.

## 목적

MSPC score는 final decision policy가 아니라 observation candidate입니다. Process-monitoring anomaly score를 transparent hand-crafted irregularity proxy와 비교하기 위해 사용합니다:

- Case A: observer input = `risk_proxy`
- Case B: observer input = `mspc_risk`
- Case C: observer input = `max(risk_proxy, mspc_risk)`

Signal quality와 coverage는 controller-stage confidence variable로 유지됩니다. MSPC가 높더라도 signal quality가 낮으면 Phase 2 safety gate가 direct alert를 억제하고 해당 case를 `request_more_data` 또는 `request_confirmation`으로 routing합니다.

## MSPC 정규화

현재 MSPC-to-risk mapping은 feasibility test용 bounded heuristic normalization입니다:

```text
risk = 0.12 + 0.58 * (1 - exp(-0.75 * mspcScore))
```

이 mapping은 최적화된 것이 아니며, high-risk level에 도달하기 전에 saturate될 수 있습니다. Calibration은 next step으로 남깁니다.

## 해석

MSPC는 process-monitoring anomaly-observation baseline으로 포함했습니다. 아직 improved controller input으로 calibrate된 것은 아닙니다.

MSPC score는 아직 superior controller input으로 calibrate되지 않았습니다. Near-threshold-noise scenario에서는 MSPC 또는 hybrid observation이 false direct-alert episode를 증가시킬 수 있습니다. 따라서 Phase 3는 baseline comparison 및 calibration target으로 해석해야 합니다.

현재 near-threshold result:

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

이 결과는 MSPC-to-risk mapping이 controller input으로 사용되기 전에 calibration이 필요함을 보여줍니다.

## 실행

```matlab
cd('C:\path\to\contact_package\code')
run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
```

## 산출물

- `outputs/mspc_scores.csv`
- `outputs/mspc_window_score_comparison.csv`
- `outputs/mspc_event_metrics.csv`
- `outputs/phase3_test_results.csv`
- `figures/figure_06_mspc_score_trajectory.png`
- `figures/figure_07_risk_proxy_vs_mspc.png`

`outputs/mspc_window_score_comparison.csv`는 hand-crafted risk proxy, MSPC risk observation, hybrid observation의 window-level comparison입니다. `outputs/mspc_event_metrics.csv`는 `risk_source`, direct-alert episode, request/confirmation episode, total action episode, non-risk safety-action episode, risk-episode detection count, `policy_transition_count`, `action_switch_count`, `direct_alert_switch_count`를 보고합니다. Episode/day metric은 실제 `start_sec`/`stop_sec` duration을 사용하며, `day0_6`은 plotting axis로만 사용합니다.

## 테스트

```matlab
cd('C:\path\to\contact_package\code')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

Test는 normal MSPC score가 낮게 유지되는지, high-risk synthetic segment에서 MSPC observation이 증가하는지, near-threshold limitation이 warning으로 드러나는지, duration calculation이 실제 window time을 사용하는지 확인합니다.

## 향후 Calibration

- MSPC-to-risk normalization을 조정합니다.
- Quality-aware MSPC score damping을 적용합니다.
- Normal window만 사용해 Q/T2 limit을 tune합니다.
- Q-only, T2-only, max(Q,T2), weighted combination을 비교합니다.
- Near-threshold false direct-alert sensitivity를 평가합니다.
