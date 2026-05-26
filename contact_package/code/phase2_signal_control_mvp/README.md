# Phase 2 Signal-Control MVP

## Purpose

This module is a compact MATLAB/Simulink feasibility package for quality-aware wearable RRI monitoring policy. It does not make diagnosis, recurrence-prediction, or anatomy-segmentation claims.

The prototype demonstrates a MATLAB/Simulink-based quality-aware monitoring-policy loop that estimates a latent risk-state from wearable RRI observations and controls direct alert, `request_more_data`, or `request_confirmation` according to signal quality, coverage, and uncertainty.

Phase 1 anatomy remains an optional feasibility baseline. Phase 2 is the main signal/control loop.

## What It Builds

- Synthetic RRI streams for normal baseline, low-quality artifact, high-risk irregular, missing burst, and near-threshold noise scenarios.
- Signal quality index `q_k` and coverage `c_k`.
- HRV and irregularity features: meanNN, SDNN, RMSSD, pNN50, CV_RRI, SD1, SD2.
- Quality-weighted risk-state observer: `x_hat_k`, observer gain `K_k`, and uncertainty `U_k`.
- Adaptive threshold controller and safety gate.
- Episode-level direct-alert, request, confirmation, and total-action burden metrics so overlapping windows do not inflate event counts.
- Numeric Simulink step-function testbench.
- Safety/pass-fail tests.

The Simulink model is a numeric step-function illustration of the policy concept. It is not claimed to be a one-to-one implementation of every branch and parameter in `adaptive_threshold_controller.m`; the executable MATLAB scripts remain the reference implementation for metric generation.

Shared observer/controller constants are centralized in `config/phase_control_params.m` and reused by Phase 2 and Phase 3 where applicable.

## Run

From MATLAB:

```matlab
cd('C:\atrium-feasibility')
run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
```

Full Phase 2 verification:

```matlab
cd('C:\atrium-feasibility')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')
```

Numeric Simulink testbench only:

```matlab
cd('C:\atrium-feasibility')
run('phase2_signal_control_mvp/scripts/build_simulink_testbench.m')
```

## Outputs

- `outputs/tables/window_metrics.csv`
- `outputs/tables/baseline_vs_proposed.csv`
- `outputs/tables/alert_log.csv`
- `outputs/tables/phase2_pass_fail_summary.csv`
- `outputs/tables/phase2_test_results.csv`
- `outputs/simulink/phase2_signal_control_testbench.slx`
- `outputs/simulink/simulink_step_testbench_log.csv`
- `figures/figure_01_pipeline.png`
- `figures/figure_02_quality_observer_trajectory.png`
- `figures/figure_03_fixed_vs_adaptive_threshold.png`
- `figures/figure_04_alert_log_day0_6.png`
- `figures/figure_05_simulink_step_testbench.png`

## Engineering Formulation

| Variable | Meaning |
|---|---|
| `r_k` | raw HRV irregularity observation at window `k` |
| `q_k` | signal quality index |
| `c_k` | valid coverage |
| `x_hat_k` | estimated latent risk-state |
| `U_k` | uncertainty |
| `K_k` | observer gain |
| `tau_k` | adaptive threshold |
| `a_k` | direct alert decision |
| `m_k` | request_more_data decision |
| `h_k` | request_confirmation decision |

Observer gain:

```text
K_k = K_0 * q_k * c_k
```

Risk-state observer:

```text
x_hat_k = x_hat_{k-1} + K_k * (r_k - x_hat_{k-1})
```

Uncertainty update:

```text
U_k = clip(U_0 + beta * (1 - q_k) + gamma * (1 - c_k) + residual terms, 0, 1)
```

Direct alert condition:

```text
direct_alert_k = 1 only if
x_hat_k > tau_k
and q_k >= q_min
and U_k <= U_max
and c_k >= c_min
```

Low-quality routing rule:

```text
if q_k < q_min and the observation is suspicious:
    direct_alert_k = 0
    request_more_data_k = 1 or request_confirmation_k = 1
```

## Safety Invariants

| Safety invariant | Meaning | Pass condition |
|---|---|---|
| `0 <= q_k <= 1` | signal quality bound | all windows |
| `0 <= c_k <= 1` | coverage bound | all windows |
| `0 <= x_hat_k <= 1` | risk-state bound | all windows |
| `0 <= U_k <= 1` | uncertainty bound | all windows |
| `q_k < q_min => direct_alert_k = 0` | low-quality direct alert prohibition | all proposed windows |
| `true_low_quality & ~true_risk => direct_alert_k = 0` | injected low-quality non-risk false direct alert prohibition | all proposed windows |
| low `q_k` + suspicious risk routes to confirmation/more data | uncertainty handling | low-quality artifact scenario |
| overlapping alerts map to one episode | alert-burden accounting | episode metrics |
| `tau_min <= tau_k <= tau_max` | threshold bound | all windows |
| high-risk policy switching remains bounded | controller chattering control | `policy_transition_count <= 30` |

## Demonstration Results

The main result table is `outputs/tables/baseline_vs_proposed.csv`. Alert burden rates use actual synthetic signal duration from `start_sec`/`stop_sec`; `day0_6` is used only as a plotting axis.

Direct-alert burden and total monitoring-action burden are reported separately:

- `direct_alert_episode_count`
- `false_direct_alert_episode_count`
- `request_episode_count`
- `confirmation_episode_count`
- `action_episode_count`
- `false_action_episode_count`
- `nonrisk_request_episode_count`
- `nonrisk_confirmation_episode_count`
- `nonrisk_action_episode_count`
- `request_windows_per_day`
- `confirmation_windows_per_day`
- `policy_transition_count`
- `action_switch_count`
- `direct_alert_switch_count`

Policy chattering is evaluated using `policy_transition_count`, which directly counts changes in the final policy label. The earlier episode-style `controller_switch_count_deprecated` metric is retained only for backward comparison.

A non-risk action is not necessarily a controller failure. In low-quality artifact scenarios, `request_more_data` or `request_confirmation` is intended safety-routing behavior. Direct false alerts and non-risk safety requests are therefore reported separately.

Primary burden metrics are episode-level action counts, not window-level request counts. `request_windows_per_day` and `confirmation_windows_per_day` are diagnostic metrics for controller state density and should not be interpreted as user-facing notification rates.

| Scenario | Fixed baseline | Proposed controller | Intended behavior |
|---|---:|---:|---|
| normal baseline | no false alert episode | no false alert episode | suppress normal alerts |
| low-quality artifact | direct false alert episode occurs | direct alert = 0, confirmation/request > 0 | prohibit low-quality direct alerts |
| high-risk irregular | detects irregular episode | detects irregular episode with quality-aware routing | detect high-risk segment |
| missing burst | direct false alert can occur | uncertainty rises and direct alert is suppressed | coverage-aware control |
| near-threshold noise | fixed threshold chatters | proposed controller suppresses direct alerts | reduce alert burden |

`outputs/tables/phase2_pass_fail_summary.csv` records the executable pass/fail checks for these claims. `outputs/tables/phase2_test_results.csv` is generated by the test runner.

The synthetic artifact severity is intentionally configured as a stress-test condition so that injected low-quality windows are unambiguous under the SQI definition. This is not a physiological claim.

## Engineering Interpretation

This MVP is a control-oriented monitoring feasibility testbench. The main objective is to demonstrate how wearable RRI observations can be processed under signal-quality uncertainty and how direct alerts can be separated from request/confirmation routing.

The core design principle is low-quality direct-alert prohibition. When raw irregularity appears high but signal quality or coverage is insufficient, the system suppresses direct alerts and routes the case to `request_more_data` or `request_confirmation`. Therefore, signal quality is not treated as a preprocessing filter only; it directly modulates observer gain, uncertainty, and controller action.

Current direct alerts are window-policy outputs after refractory control. For user-facing notification design, these should be latched or merged into one notification per risk episode.

## Current Limitation

- The current Phase 2 scenarios are synthetic stress-test scenarios.
- No diagnosis, recurrence-prediction, or treatment-outcome claim is made.
- MSPC in Phase 3 is a baseline anomaly observation, not the final decision policy.

## Next Extension

- Compare hand-crafted HRV risk, MSPC anomaly score, and hybrid observer inputs under the same safety gate.
- Calibrate `q_min`, `U_max`, threshold bounds, and MSPC-to-risk mapping.
- Share core step functions between MATLAB scripts and future Simulink blocks.
