# Contact Package 안내

이 패키지는 quality-aware wearable RRI monitoring policy를 위한 간결한 MATLAB/Simulink feasibility prototype입니다. 전체 개발 repo가 아니라 교수님께 공유하기 위한 compact contact package입니다.

## 핵심 메시지

MATLAB/Simulink 기반 quality-aware wearable RRI monitoring policy feasibility testbench를 구현했습니다. 이 시스템은 noisy high-risk observation에서 곧바로 direct alert를 내지 않습니다. 대신 signal-quality uncertainty 아래에서 risk-state를 추정하고, observe, `request_more_data`, `request_confirmation`, `direct_alert` 중 어떤 policy action을 낼지 제어합니다.

## 구성

- `professor_summary_1page.md`: 연구 방향 요약.
- `phase2_engineering_report.md`: engineering formulation, safety invariant, demonstration result.
- `figures/`: contact discussion용 핵심 figure.
- `outputs/`: 핵심 CSV output 및 pass/fail summary.
- `code/`: Phase 1, Phase 2, Phase 3, shared config의 정리된 MATLAB source folder.

대용량 raw dataset, MATLAB project resource, workspace file, external-RRI scaffold file은 의도적으로 제외했습니다.

## 이 패키지가 주장하지 않는 것

- 진단 도구가 아닙니다.
- recurrence-prediction 도구가 아닙니다.
- anatomy segmentation project가 아닙니다.
- treatment-efficacy claim이 아닙니다.

## 재현 방법

이 contact package의 모든 재현 명령은 MATLAB current directory가 `contact_package/code`라고 가정합니다.

```matlab
cd('C:\path\to\contact_package\code')

run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')

run('phase2_signal_control_mvp/scripts/build_simulink_testbench.m')

run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

Phase 1은 reference code와 정리된 output만 포함합니다. Raw MRI/label file은 포함하지 않았습니다. Phase 1을 다시 실행하려면 `config/paths_local_template.m`을 `config/paths_local.m`으로 복사한 뒤 local raw-data path를 설정해야 합니다.

Public ECG-derived RRI sanity check는 의도적으로 후속 작업으로 미뤘으며, 이 패키지의 result claim에 포함하지 않았습니다.
