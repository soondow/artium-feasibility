# Phase 2 Signal-Control MVP 안내

## 목적

이 module은 quality-aware wearable RRI monitoring policy를 위한 compact MATLAB/Simulink feasibility package입니다. 진단, recurrence-prediction, anatomy-segmentation claim을 하지 않습니다.

이 prototype은 wearable RRI observation에서 latent risk-state를 추정하고, signal quality, coverage, uncertainty에 따라 direct alert, `request_more_data`, `request_confirmation`을 제어하는 MATLAB/Simulink 기반 quality-aware monitoring-policy loop를 보여줍니다.

Phase 1 anatomy는 optional feasibility baseline이고, Phase 2가 main signal/control loop입니다.

## 구현 내용

- normal baseline, low-quality artifact, high-risk irregular, missing burst, near-threshold noise scenario용 synthetic RRI stream.
- Signal quality index `q_k`와 coverage `c_k`.
- HRV 및 irregularity feature: meanNN, SDNN, RMSSD, pNN50, CV_RRI, SD1, SD2.
- Quality-weighted risk-state observer: `x_hat_k`, observer gain `K_k`, uncertainty `U_k`를 계산합니다.
- Adaptive threshold controller와 safety gate.
- overlapping window가 event count를 부풀리지 않도록 episode-level direct-alert, request, confirmation, total-action burden metric.
- Numeric Simulink step-function testbench를 포함합니다.
- Safety/pass-fail test를 포함합니다.

Simulink model은 policy concept를 보여주는 numeric step-function illustration입니다. `adaptive_threshold_controller.m`의 모든 branch와 parameter를 one-to-one으로 구현했다고 주장하지 않습니다. Metric generation의 reference implementation은 executable MATLAB script입니다.

공통 observer/controller constant는 `config/phase_control_params.m`에 모아 두었고, 가능한 경우 Phase 2와 Phase 3에서 재사용합니다.

## 실행

MATLAB에서 실행:

```matlab
cd('C:\path\to\contact_package\code')
run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
```

Phase 2 전체 검증:

```matlab
cd('C:\path\to\contact_package\code')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')
```

Numeric Simulink testbench만 실행:

```matlab
cd('C:\path\to\contact_package\code')
run('phase2_signal_control_mvp/scripts/build_simulink_testbench.m')
```

## 산출물

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

## 공학적 정식화

| Variable | 의미 |
|---|---|
| `r_k` | window `k`의 raw HRV irregularity observation |
| `q_k` | signal quality index |
| `c_k` | valid coverage |
| `x_hat_k` | estimated latent risk-state |
| `U_k` | uncertainty |
| `K_k` | observer gain |
| `tau_k` | adaptive threshold |
| `a_k` | direct alert decision |
| `m_k` | request_more_data decision |
| `h_k` | request_confirmation decision |

Observer gain 계산:

```text
K_k = K_0 * q_k * c_k
```

Risk-state observer update:

```text
x_hat_k = x_hat_{k-1} + K_k * (r_k - x_hat_{k-1})
```

Uncertainty update:

```text
U_k = clip(U_0 + beta * (1 - q_k) + gamma * (1 - c_k) + residual terms, 0, 1)
```

Direct alert 조건:

```text
direct_alert_k = 1이 되려면
x_hat_k > tau_k
그리고 q_k >= q_min
그리고 U_k <= U_max
그리고 c_k >= c_min
```

Low-quality routing rule:

```text
q_k < q_min 이고 observation이 suspicious이면:
    direct_alert_k = 0
    request_more_data_k = 1 또는 request_confirmation_k = 1
```

## Safety Invariant 검증

| Safety invariant | 의미 | Pass condition |
|---|---|---|
| `0 <= q_k <= 1` | signal quality bound | all windows |
| `0 <= c_k <= 1` | coverage bound | all windows |
| `0 <= x_hat_k <= 1` | risk-state bound | all windows |
| `0 <= U_k <= 1` | uncertainty bound | all windows |
| `q_k < q_min => direct_alert_k = 0` | low-quality direct alert prohibition | all proposed windows |
| `true_low_quality & ~true_risk => direct_alert_k = 0` | injected low-quality non-risk false direct alert prohibition | all proposed windows |
| low `q_k` + suspicious risk는 confirmation/more data로 routing | uncertainty handling | low-quality artifact scenario |
| overlapping alert는 하나의 episode로 mapping | alert-burden accounting | episode metrics |
| `tau_min <= tau_k <= tau_max` | threshold bound | all windows |
| high-risk policy switching은 bounded 상태 유지 | controller chattering control | `policy_transition_count <= 30` |

## Demonstration Result 요약

Main result table은 `outputs/tables/baseline_vs_proposed.csv`입니다. Alert burden rate는 `start_sec`/`stop_sec`에서 계산한 실제 synthetic signal duration을 사용합니다. `day0_6`은 plotting axis로만 사용합니다.

Direct-alert burden과 total monitoring-action burden은 분리해서 보고합니다:

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

Policy chattering은 final policy label의 변화를 직접 세는 `policy_transition_count`로 평가합니다. 이전 episode-style `controller_switch_count_deprecated` metric은 backward comparison용으로만 남겨 두었습니다.

Non-risk action이 항상 controller failure를 의미하지는 않습니다. Low-quality artifact scenario에서 `request_more_data` 또는 `request_confirmation`은 의도된 safety-routing behavior입니다. 따라서 direct false alert와 non-risk safety request를 분리해서 보고합니다.

Primary burden metric은 window-level request count가 아니라 episode-level action count입니다. `request_windows_per_day`와 `confirmation_windows_per_day`는 controller state density를 보기 위한 diagnostic metric이며, user-facing notification rate로 해석하면 안 됩니다.

| Scenario | Fixed baseline | Proposed controller | 의도한 동작 |
|---|---:|---:|---|
| normal baseline | no false alert episode | no false alert episode | normal alert 억제 |
| low-quality artifact | direct false alert episode 발생 | direct alert = 0, confirmation/request > 0 | low-quality direct alert 금지 |
| high-risk irregular | irregular episode 감지 | quality-aware routing과 함께 irregular episode 감지 | high-risk segment 감지 |
| missing burst | direct false alert 가능 | uncertainty가 상승하고 direct alert 억제 | coverage-aware control |
| near-threshold noise | fixed threshold chattering | proposed controller가 direct alert 억제 | alert burden 감소 |

`outputs/tables/phase2_pass_fail_summary.csv`는 위 claim에 대한 executable pass/fail check를 기록합니다. `outputs/tables/phase2_test_results.csv`는 test runner가 생성합니다.

Synthetic artifact severity는 SQI 정의 아래에서 injected low-quality window가 명확해지도록 stress-test condition으로 의도적으로 설정했습니다. 이는 physiological claim이 아닙니다.

## Engineering Interpretation 해석

이 MVP는 control-oriented monitoring feasibility testbench입니다. 주요 목적은 wearable RRI observation을 signal-quality uncertainty 아래에서 어떻게 처리할 수 있는지, 그리고 direct alert를 request/confirmation routing과 어떻게 분리할 수 있는지 보여주는 것입니다.

핵심 design principle은 low-quality direct-alert prohibition입니다. Raw irregularity가 높게 보이더라도 signal quality 또는 coverage가 충분하지 않으면, system은 direct alert를 억제하고 해당 case를 `request_more_data` 또는 `request_confirmation`으로 routing합니다. 따라서 signal quality는 단순 preprocessing filter가 아니라 observer gain, uncertainty, controller action을 직접 조절하는 변수입니다.

현재 direct alert는 refractory control 이후의 window-policy output입니다. User-facing notification design에서는 이를 risk episode당 하나의 notification으로 latch 또는 merge해야 합니다.

## 현재 한계

- 현재 Phase 2 scenario는 synthetic stress-test scenario입니다.
- Diagnosis, recurrence-prediction, treatment-outcome claim을 하지 않습니다.
- Phase 3의 MSPC는 baseline anomaly observation이며 final decision policy가 아닙니다.

## 다음 확장

- 동일한 safety gate 아래에서 hand-crafted HRV risk, MSPC anomaly score, hybrid observer input을 비교합니다.
- `q_min`, `U_max`, threshold bound, MSPC-to-risk mapping을 calibrate합니다.
- MATLAB script와 future Simulink block 사이에서 core step function을 공유하도록 정리합니다.
