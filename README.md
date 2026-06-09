# Atrium Feasibility

이 저장소는 좌심방 해부학 특징 추출과 RRI 기반 품질 인식 모니터링 제어기를 검토하기 위한 MATLAB/Simulink 타당성 패키지입니다. 원자료와 자동 생성 프로젝트 파일은 제외하고, 재현 확인에 필요한 코드, 핵심 그림, CSV 산출물을 정리했습니다.

## 프로젝트 구성

- `code/phase1_anatomy`: AtriaSeg 기반 좌심방 부피와 바운딩 박스 특징 추출 코드입니다.
- `code/phase2_signal_control_mvp`: 합성 RRI 시나리오, 신호 품질 지표, 품질 가중 관찰자, 적응형 알림 제어기, Simulink 테스트벤치입니다.
- `code/phase3_mspc_baseline`: Phase 2 특징을 이용한 MSPC 기준 모델과 위험 프록시 비교 코드입니다.
- `figures/`: 파이프라인, 관찰자 궤적, 알림 정책, MSPC 비교 그림입니다.
- `outputs/`: 주요 CSV 결과와 테스트 요약입니다.

## 실행 방법

MATLAB 현재 폴더를 `code`로 맞춘 뒤 실행합니다.

```matlab
run('phase2_signal_control_mvp/scripts/run_phase2_demo.m')
run('phase2_signal_control_mvp/scripts/run_patient_level_monitoring_demo.m')
run('phase2_signal_control_mvp/tests/run_all_phase2_tests.m')

run('phase3_mspc_baseline/scripts/run_phase3_mspc_demo.m')
run('phase3_mspc_baseline/tests/run_all_phase3_tests.m')
```

Phase 1 원자료는 포함하지 않았습니다. Phase 1을 다시 실행하려면 `code/config/paths_local_template.m`을 `code/config/paths_local.m`으로 복사한 뒤 로컬 AtriaSeg 데이터 경로를 설정해야 합니다.

## 범위

이 패키지는 공학적 타당성 확인용입니다. 임상 진단, 재발 예측, 치료 효과 판정을 주장하지 않습니다.
