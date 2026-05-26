# Quality-Aware Wearable RRI Monitoring-Policy Testbench

## Research Direction

This is a MATLAB/Simulink feasibility package for quality-aware wearable RRI monitoring-policy control. It is not a diagnosis or recurrence-prediction tool.

## Motivation

Wearable RRI observations can be noisy, incomplete, or affected by motion and poor coverage. A direct alert from unreliable observations can increase unnecessary monitoring burden. The project therefore treats signal quality and coverage as control inputs for monitoring policy, not only as preprocessing filters.

## Current Implementation

## Phase 1: Optional Anatomy Module

Phase 1 is retained only as an optional anatomy-covariate feasibility module. It demonstrates MATLAB-based handling of 3D left atrial MRI labels, but it is not the main novelty.

## Phase 2: Quality-Aware Monitoring-Policy MVP

Phase 2 is the main signal/control loop: synthetic RRI stress-test generation, SQI and coverage estimation, HRV feature extraction, a quality-weighted risk-state observer, uncertainty estimation, adaptive threshold control, safety gating, episode-level burden metrics, and a numeric Simulink concept testbench.

## Phase 3: MSPC Anomaly-Observation Baseline

Phase 3 adds an MSPC anomaly-observation baseline. It compares `risk_proxy`, `mspc_risk`, and a hybrid observation under the same Phase 2 safety gate.

## Key Demonstration

The main behavior demonstrated in Phase 2 is low-quality direct-alert prohibition. Suspicious but unreliable RRI observations are routed to `request_more_data` or `request_confirmation` instead of direct alerts.

## Safety-Oriented Design

The package checks bounded SQI, bounded coverage, bounded observer state, bounded uncertainty, low-quality direct-alert prohibition, injected low-quality non-risk false direct-alert prohibition, request/action burden, and high-risk policy switching.

## Current Limitations

1. Current Phase 2 results are based on synthetic stress-test scenarios.
2. The prototype does not make diagnosis, recurrence-prediction, or treatment-outcome claims.
3. The Simulink testbench is a numeric step-function concept illustration, not a full one-to-one implementation of the MATLAB controller.
4. MSPC is currently an anomaly-observation baseline and can increase false direct alerts in near-threshold noise.
5. Phase 1 anatomy extraction is optional and does not represent the main novelty.

## Next Steps

Calibrate `q_min`, `U_max`, threshold bounds, and MSPC-to-risk mapping; then separately run a public ECG-derived RRI sanity check as a later task.
