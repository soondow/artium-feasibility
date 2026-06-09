# Phase 3 MSPC Baseline

Phase 2에서 만든 RRI 윈도우 특징에 MSPC 이상 점수를 적용해 기존 위험 프록시와 비교하는 기준 모델입니다.

## 하는 일

- 정상 고품질 윈도우로 MSPC 모델을 학습합니다.
- 전체 윈도우에 MSPC 점수를 계산합니다.
- `risk_proxy`, `mspc_risk`, `hybrid_risk`를 비교합니다.
- 같은 Phase 2 제어기에 넣어 알림과 요청 지표를 비교합니다.

## 실행

```matlab
run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

## 주요 산출물

- `outputs/mspc_scores.csv`
- `outputs/mspc_window_score_comparison.csv`
- `outputs/mspc_event_metrics.csv`
- `outputs/phase3_test_results.csv`
- `figures/figure_06_mspc_score_trajectory.png`
- `figures/figure_07_risk_proxy_vs_mspc.png`

## 범위

MSPC는 현재 비교용 이상 점수입니다. 최종 의사결정 모델이 아니며, 실제 적용 전에는 점수 정규화와 임계값 보정이 필요합니다.
