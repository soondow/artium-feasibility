# Phase 1 Optional Anatomy Module

This module is an optional anatomy-covariate feasibility module. It demonstrates MATLAB-based processing of 3D left atrial MRI labels and extraction of simple anatomical covariates such as LA volume and bounding-box features. It is not the main novelty of this project. The main research direction is Phase 2: quality-aware wearable RRI monitoring-policy control.

## Purpose

Phase 1 demonstrates that MATLAB can load 3D atrial MRI/label data, compute basic left atrial volume and bounding-box features, and export clean summary tables and preview overlays.

## Outputs For Contact Package

For quick review:

- `contact_package/outputs/x_anat_basic.csv`
- `contact_package/figures/Case_001_overlay_mid.png`

For code-local reference:

- `contact_package/code/phase1_anatomy/outputs/tables/x_anat_basic.csv`
- `contact_package/code/phase1_anatomy/outputs/preview_png/Case_001_overlay_mid.png`

The large raw MRI data, workspace `.mat` files, autosave `.asv` files, and duplicate local project folders are excluded from the contact package.

Phase 1 scripts are included for reference only in the contact package. Raw MRI/label files are excluded to keep the package small. To rerun Phase 1, create `config/paths_local.m` from `config/paths_local_template.m` and set the local raw-data path.

## Interpretation

Phase 1 should be described as an optional anatomical covariate extraction module. The main ongoing direction is Phase 2/3: quality-aware wearable RRI monitoring policy with MATLAB/Simulink and an MSPC baseline.

## Current Limitation

This module uses provided segmentation labels and does not perform segmentation or clinical interpretation. The extracted features are limited to simple geometric covariates such as left atrial volume and bounding-box dimensions.
