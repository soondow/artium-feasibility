# Phase 1 Anatomy

좌심방 MRI 라벨에서 기본 해부학 특징을 추출하는 코드입니다.

## 하는 일

- `laendo.nrrd` 라벨을 읽어 좌심방 부피를 계산합니다.
- 라벨의 3차원 바운딩 박스 크기를 계산합니다.
- 일부 케이스의 MRI/라벨 오버레이 이미지를 저장합니다.

## 실행

원자료는 패키지에 포함하지 않았습니다. 다시 실행하려면 `config/paths_local_template.m`을 `config/paths_local.m`으로 복사한 뒤 로컬 데이터 경로를 설정합니다.

```matlab
run('phase1_anatomy/scripts/run_phase1_batch_basic_features.m')
```

## 주요 산출물

- `outputs/tables/x_anat_basic.csv`
- `outputs/preview_png/Case_001_overlay_mid.png`

## 범위

이 단계는 라벨 기반 특징 추출만 다룹니다. 영상 분할 모델이나 임상 해석은 포함하지 않습니다.
