# Phase 2 Signal-Control MVP

RRI 신호 품질을 고려해 알림, 추가 데이터 요청, 확인 요청을 분기하는 MATLAB/Simulink 타당성 테스트벤치입니다.

## 하는 일

- 합성 RRI 시나리오를 생성합니다.
- 신호 품질, 커버리지, HRV 특징을 계산합니다.
- 품질 가중 관찰자로 위험 상태와 불확실성을 추정합니다.
- 적응형 임계값 제어기로 `direct_alert`, `request_more_data`, `request_confirmation`을 결정합니다.
- Phase 2 검증 테스트와 Simulink step 테스트벤치를 제공합니다.

## 실행

```matlab
run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
run('phase2_signal_control_mvp/scripts/run_patient_level_monitoring_demo.m')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')
```

공개 RRI CSV를 점검하려면 환경 변수에 파일 경로를 넣고 실행합니다.

```matlab
setenv('PUBLIC_RRI_CSV', 'C:\path\to\rri.csv')
run('phase2_signal_control_mvp/scripts/run_public_rri_sanity_template.m')
```

## 주요 산출물

- `outputs/tables/window_metrics.csv`
- `outputs/tables/baseline_vs_proposed.csv`
- `outputs/tables/alert_log.csv`
- `outputs/tables/patient_level_monitoring_summary.csv`
- `outputs/tables/phase2_test_results.csv`
- `outputs/simulink/phase2_signal_control_testbench.slx`
- `figures/figure_01_pipeline.png`
- `figures/figure_02_quality_observer_trajectory.png`
- `figures/figure_03_fixed_vs_adaptive_threshold.png`
- `figures/figure_04_alert_log_day0_6.png`
- `figures/figure_05_simulink_step_testbench.png`

## 범위

현재 단계는 합성 신호 기반 공학 검증입니다. 진단, 재발 예측, 치료 효과 판정은 주장하지 않습니다.
