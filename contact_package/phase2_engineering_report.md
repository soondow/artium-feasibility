# Phase 2 Engineering Report

## Engineering Formulation

The Phase 2 MVP uses the following window-level variables:

Shared constants such as `q_min`, `c_min`, `U_max`, threshold bounds, refractory windows, and merge-gap windows are centralized in `config/phase_control_params.m`.

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

| Safety invariant | Pass condition |
|---|---|
| `0 <= q_k <= 1` | all windows |
| `0 <= c_k <= 1` | all windows |
| `0 <= x_hat_k <= 1` | all windows |
| `0 <= U_k <= 1` | all windows |
| `q_k < q_min => direct_alert_k = 0` | all proposed controller windows |
| `true_low_quality & ~true_risk => direct_alert_k = 0` | injected low-quality non-risk windows |
| suspicious low-quality observation routes to confirmation/more data | low-quality artifact scenario |
| overlapping alerts are counted as one episode | episode-level metrics |
| `tau_min <= tau_k <= tau_max` | all windows |
| high-risk policy switching remains bounded | `policy_transition_count <= 30` |

## Demonstration Results

The key CSV files are:

- `outputs/baseline_vs_proposed.csv`
- `outputs/phase2_pass_fail_summary.csv`
- `outputs/phase2_test_results.csv`
- `outputs/mspc_event_metrics.csv`

Public ECG-derived RRI sanity-check outputs are intentionally omitted from this package.

The current Phase 2 pass/fail summary reports all checks passing. In the low-quality artifact scenario, the proposed controller has `direct_alert_episode_count = 0` and routes suspicious low-quality windows to `request_more_data` or `request_confirmation`.

Alert burden rates are computed from actual synthetic signal duration using `start_sec` and `stop_sec`. The normalized `day0_6` axis is used only for plotting.

The result table separates direct alerts from monitoring actions:

- `false_direct_alert_episode_count`
- `request_episode_count`
- `false_request_episode_count`
- `confirmation_episode_count`
- `false_confirmation_episode_count`
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

The synthetic artifact severity is intentionally configured as a stress-test condition so that injected low-quality windows are unambiguous under the SQI definition. This is not a physiological claim.

Policy chattering is evaluated using `policy_transition_count`, which directly counts changes in the final policy label. The earlier `controller_switch_count_deprecated` metric is retained only for backward comparison because it did not necessarily represent string-level policy transitions.

A non-risk action is not necessarily a controller failure. In low-quality artifact scenarios, `request_more_data` or `request_confirmation` is intended safety-routing behavior. Direct false alerts and non-risk safety requests are therefore reported separately.

Primary burden metrics are episode-level action counts, not window-level request counts. `request_windows_per_day` and `confirmation_windows_per_day` are diagnostic metrics for controller state density and should not be interpreted as user-facing notification rates.

## Engineering Interpretation

This MVP is a control-oriented monitoring feasibility testbench. The main objective is to demonstrate how wearable RRI observations can be processed under signal-quality uncertainty and how direct alerts can be separated from request/confirmation routing.

The core design principle is low-quality direct-alert prohibition. When raw irregularity appears high but signal quality or coverage is insufficient, the system suppresses direct alerts and routes the case to `request_more_data` or `request_confirmation`. Therefore, signal quality is not treated as a preprocessing filter only; it directly modulates observer gain, uncertainty, and controller action.

Current direct alerts are window-policy outputs after refractory control. For user-facing notification design, these should be latched or merged into one notification per risk episode.

## Current Limitation

The current implementation uses synthetic RRI stress-test scenarios. Public ECG/RRI data should be added later as a separate sanity check. No diagnosis or recurrence-prediction claim is made.

The Simulink model is a numeric step-function illustration of the policy concept, not a one-to-one implementation of every branch and parameter in the MATLAB controller.

The Phase 3 MSPC baseline is included as an anomaly-observation baseline. It should not be described as improving false alarm performance without additional calibration.

## Next Extension

Phase 3 adds an MSPC anomaly baseline trained on normal high-quality HRV windows. Public ECG-derived RRI testing is deferred until suitable input data is inserted.
