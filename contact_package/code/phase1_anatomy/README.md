# Phase 1 Optional Anatomy Module 안내

이 module은 optional anatomy-covariate feasibility module입니다. MATLAB으로 3D left atrial MRI label을 처리하고, LA volume 및 bounding-box feature 같은 간단한 anatomical covariate를 추출할 수 있음을 보여줍니다. 이 project의 main novelty는 아닙니다. 중심 연구 방향은 Phase 2의 quality-aware wearable RRI monitoring-policy control입니다.

## 목적

Phase 1은 MATLAB이 3D atrial MRI/label data를 불러오고, 기본 left atrial volume과 bounding-box feature를 계산하며, 정리된 summary table과 preview overlay를 export할 수 있음을 보여줍니다.

## Contact Package 산출물

빠른 검토용:

- `contact_package/outputs/x_anat_basic.csv`
- `contact_package/figures/Case_001_overlay_mid.png`

code-local reference용:

- `contact_package/code/phase1_anatomy/outputs/tables/x_anat_basic.csv`
- `contact_package/code/phase1_anatomy/outputs/preview_png/Case_001_overlay_mid.png`

대용량 raw MRI data, workspace `.mat` file, autosave `.asv` file, 중복 local project folder는 contact package에서 제외했습니다.

Phase 1 script는 contact package에 reference용으로만 포함했습니다. 패키지를 작게 유지하기 위해 raw MRI/label file은 제외했습니다. Phase 1을 다시 실행하려면 `config/paths_local_template.m`에서 `config/paths_local.m`을 만들고 local raw-data path를 설정해야 합니다.

## 해석

Phase 1은 optional anatomical covariate extraction module로 설명해야 합니다. 현재 중심 방향은 Phase 2/3입니다. 즉, MATLAB/Simulink 기반 quality-aware wearable RRI monitoring policy와 MSPC baseline입니다.

## 현재 한계

이 module은 제공된 segmentation label을 사용하며, segmentation 자체나 clinical interpretation을 수행하지 않습니다. 추출 feature는 left atrial volume과 bounding-box dimension 같은 간단한 geometric covariate로 제한됩니다.
