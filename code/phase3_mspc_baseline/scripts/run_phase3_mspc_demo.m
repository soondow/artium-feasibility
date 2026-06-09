% 스크립트 설명:
%   Phase 2 윈도우 특징을 사용해 Phase 3 MSPC 기준 모델을 학습, 점수화, 비교합니다.
%
% 입력:
%   Phase 2 window_metrics.csv를 사용하며, 없으면 Phase 2 데모를 실행해 산출물을 생성합니다.
%
% 출력:
%   MSPC 점수 CSV, 위험 프록시 비교 CSV, 이벤트 지표 CSV, MSPC 관련 그림을 생성합니다.
%
% 예외:
%   Phase 2 산출물 생성, 테이블 읽기, MSPC 학습/점수화, 그림 저장 중 발생한 MATLAB 예외가 전파될 수 있습니다.
%
% 처리 절차:
%   1. 정상·고품질 윈도우로 MSPC 정상운전조건 모델을 학습합니다.
%   2. 전체 윈도우에 MSPC 점수를 계산하고 0~1 위험 프록시로 정규화합니다.
%   3. 수작업 위험 프록시, MSPC 위험, 하이브리드 위험을 비교합니다.
%   4. 각 위험 관측값을 동일한 제어기에 넣어 이벤트 지표를 산출합니다.
%   5. 점수 궤적과 프록시 비교 그림을 저장합니다.


clear; clc; close all;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
phase3Root = fileparts(scriptDir);
repoRoot = fileparts(phase3Root);
phase2Root = fullfile(repoRoot, 'phase2_signal_control_mvp');

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(phase3Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));

outDir = fullfile(phase3Root, 'outputs');
figDir = fullfile(phase3Root, 'figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

phase2Csv = fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv');
ensurePhase2Outputs(phase2Root);

W = readtable(phase2Csv);
W.scenario = string(W.scenario);
featureNames = {'meanNN_ms', 'SDNN_ms', 'RMSSD_ms', 'pNN50', 'CV_RRI', 'SD1_ms', 'SD2_ms'};
X = W{:, featureNames};

trainMask = W.scenario == "normal" & W.q >= 0.90 & W.coverage >= 0.95 & ~W.true_risk;
model = train_mspc_model(X(trainMask, :), 0.90);
S = score_mspc_model(X, model);
mspcRisk = normalize_mspc_score(S.mspc_score);

mspcScores = [W(:, {'scenario', 'window_id', 'start_sec', 'stop_sec', 'day0_6', ...
    'q', 'coverage', 'true_risk', 'true_low_quality'}) S];
mspcScores.mspc_risk = mspcRisk;
writetable(mspcScores, fullfile(outDir, 'mspc_scores.csv'));

comparison = compare_risk_proxy_vs_mspc(W, mspcRisk);
writetable(comparison, fullfile(outDir, 'mspc_window_score_comparison.csv'));

eventMetrics = buildMspcEventMetrics(W, mspcRisk);
writetable(eventMetrics, fullfile(outDir, 'mspc_event_metrics.csv'));

plotMspcTrajectory(W, mspcScores, figDir);
plotRiskVsMspc(comparison, figDir);

fprintf('Phase 3 MSPC baseline complete.\n');
fprintf('Outputs: %s\n', outDir);
disp(eventMetrics);

function T = buildMspcEventMetrics(W, mspcRisk)
% 함수 설명:
%   MSPC 위험, 수작업 위험 프록시, 하이브리드 위험을 동일한 제어기 지표로 비교합니다.
%
% 입력:
%   W (테이블, 비어 있을 수 없음: Phase 2 윈도우별 특징, 품질, 위험 라벨입니다.)
%   mspcRisk (수치형 벡터, 비어 있을 수 없음: MSPC 점수를 정규화한 위험 관측값입니다.)
%
% 출력:
%   T (테이블: 시나리오와 위험 소스별 알림, 요청, 탐지, 스위칭 지표를 담습니다.)
%
% 예외:
%   필수 열이 없거나 입력 길이가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 시나리오별로 세 가지 위험 관측값을 구성합니다.
%   2. 품질 가중 관찰자와 적응형 제어기를 동일 파라미터로 실행합니다.
%   3. 에피소드 탐지, 액션 부담, 정책 전환 지표를 계산합니다.
%   4. 위험 소스별 결과 행을 테이블로 병합합니다.
    P = phase_control_params();
    observerParams = observerParamsFromConfig(P);
    controllerParams = controllerParamsFromConfig(P);
    methods = ["risk_proxy"; "mspc"; "hybrid"];
    scenarios = unique(string(W.scenario), 'stable');
    rows = cell(numel(methods) * numel(scenarios), 1);
    rowIdx = 1;

    for s = 1:numel(scenarios)
        idxScenario = string(W.scenario) == scenarios(s);
        Ws = W(idxScenario, :);
        risks = {Ws.risk_proxy, mspcRisk(idxScenario), max(Ws.risk_proxy, mspcRisk(idxScenario))};

        for m = 1:numel(methods)
            O = quality_weighted_observer(risks{m}, Ws.q, Ws.coverage, observerParams);
            C = adaptive_threshold_controller(risks{m}, O.x_hat, O.U, Ws.q, controllerParams, Ws.coverage);
            windowMinutes = median((Ws.stop_sec - Ws.start_sec) / 60, 'omitnan');
            durationDays = (max(Ws.stop_sec) - min(Ws.start_sec)) / (24 * 3600);
            durationDays = max(durationDays, eps);
            M = compute_detection_metrics(C.adaptive_alert, C.request_more_data, Ws.true_risk, Ws.q, ...
                windowMinutes, durationDays, P.mergeGapWindows, P.qMinDirectAlert, ...
                Ws.true_low_quality, C.request_confirmation);

            actionMask = C.adaptive_alert | C.request_more_data | C.request_confirmation;
            actionDetection = episodeDetectionCounts(actionMask, Ws.true_risk);
            policyTransitionCount = count_policy_transitions(C.policy);
            actionSwitchCount = count_binary_switches(actionMask);
            directAlertSwitchCount = count_binary_switches(C.adaptive_alert);
            controllerSwitchCountDeprecated = countPolicyEpisodeSwitches(actionMask, P.mergeGapWindows);

            rows{rowIdx} = table(scenarios(s), methods(m), ...
                mean(risks{m}, 'omitnan'), max(risks{m}, [], 'omitnan'), ...
                nnz(C.adaptive_alert), height(extract_binary_episodes(C.adaptive_alert, 12)), ...
                M.false_direct_alert_episode_count, M.false_alert_episode_count, ...
                M.request_episode_count, ...
                M.false_request_episode_count, M.confirmation_episode_count, ...
                M.false_confirmation_episode_count, M.action_episode_count, ...
                M.false_action_episode_count, M.nonrisk_request_episode_count, ...
                M.nonrisk_confirmation_episode_count, M.nonrisk_action_episode_count, ...
                M.detected_risk_episode_count, ...
                M.missed_risk_episode_count, actionDetection.detected_risk_episode_count, ...
                actionDetection.missed_risk_episode_count, policyTransitionCount, ...
                actionSwitchCount, directAlertSwitchCount, controllerSwitchCountDeprecated, ...
                nnz(C.request_more_data), nnz(C.request_confirmation), ...
                nnz(C.adaptive_alert & Ws.q < P.qMinDirectAlert), ...
                'VariableNames', {'scenario', 'risk_source', 'mean_observation', 'max_observation', ...
                'direct_alert_count', 'direct_alert_episode_count', ...
                'false_direct_alert_episode_count', 'false_alert_episode_count', ...
                'request_episode_count', 'false_request_episode_count', ...
                'confirmation_episode_count', 'false_confirmation_episode_count', ...
                'action_episode_count', 'false_action_episode_count', ...
                'nonrisk_request_episode_count', 'nonrisk_confirmation_episode_count', ...
                'nonrisk_action_episode_count', ...
                'detected_risk_episode_count', 'missed_risk_episode_count', ...
                'action_detected_risk_episode_count', 'action_missed_risk_episode_count', ...
                'policy_transition_count', 'action_switch_count', ...
                'direct_alert_switch_count', 'controller_switch_count_deprecated', ...
                'request_more_data_count', 'request_confirmation_count', ...
                'low_quality_direct_alert_count'});
            rowIdx = rowIdx + 1;
        end
    end

    T = vertcat(rows{:});
end

function params = observerParamsFromConfig(P)
% 함수 설명:
%   공통 설정 구조체에서 MSPC 비교에 필요한 관찰자 파라미터를 추출합니다.
%
% 입력:
%   P (구조체, 비어 있을 수 없음: phase_control_params가 반환한 공통 설정입니다.)
%
% 출력:
%   params (구조체: 품질 가중 관찰자에 전달할 alpha 값을 담습니다.)
%
% 예외:
%   baseObserverGain 필드가 없으면 MATLAB 기본 예외가 발생할 수 있습니다.
    params = struct();
    params.alpha = P.baseObserverGain;
end

function ensurePhase2Outputs(phase2Root)
% 함수 설명:
%   Phase 3 실행에 필요한 Phase 2 윈도우 지표 파일이 없으면 Phase 2 데모를 실행합니다.
%
% 입력:
%   phase2Root (문자형 또는 문자열, 비어 있을 수 없음: Phase 2 루트 경로입니다.)
%
% 출력:
%   반환값은 없으며, 필요 시 window_metrics.csv를 생성합니다.
%
% 예외:
%   Phase 2 데모 실행이나 파일 생성에 실패하면 MATLAB 예외가 전파될 수 있습니다.
    phase2Csv = fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv');
    if ~isfile(phase2Csv)
        run(fullfile(phase2Root, 'scripts', 'run_phase2_demo.m'));
    end
end

function params = controllerParamsFromConfig(P)
% 함수 설명:
%   공통 설정 구조체에서 적응형 임계값 제어기에 필요한 필드를 추출합니다.
%
% 입력:
%   P (구조체, 비어 있을 수 없음: phase_control_params가 반환한 공통 설정입니다.)
%
% 출력:
%   params (구조체: 임계값, 품질 조건, 불응 구간, 정책 유지 설정을 담습니다.)
%
% 예외:
%   필요한 설정 필드가 없으면 MATLAB 기본 예외가 발생할 수 있습니다.
    params = struct();
    params.fixedThreshold = P.fixedThreshold;
    params.baseThreshold = P.tauBase;
    params.minQualityForAlert = P.qMinDirectAlert;
    params.minCoverageForAlert = P.cMinDirectAlert;
    params.maxUncertaintyForAlert = P.uMaxDirectAlert;
    params.alertMargin = P.alertMargin;
    params.refractoryWindows = P.refractoryWindows;
    params.requestRefractoryWindows = P.requestRefractoryWindows;
    params.confirmationRefractoryWindows = P.confirmationRefractoryWindows;
    params.policyDwellWindows = P.policyDwellWindows;
    params.burdenWindow = P.burdenWindow;
    params.tauMin = P.tauMin;
    params.tauMax = P.tauMax;
end

function counts = episodeDetectionCounts(actionMask, trueRisk)
% 함수 설명:
%   전체 액션 마스크가 실제 위험 에피소드를 몇 개 탐지했는지 계산합니다.
%
% 입력:
%   actionMask (논리형 벡터, 비어 있을 수 없음: 알림, 추가 데이터 요청, 확인 요청의 합집합입니다.)
%   trueRisk (논리형 벡터, 비어 있을 수 없음: 실제 위험 에피소드 라벨입니다.)
%
% 출력:
%   counts (구조체: 탐지된 위험 에피소드 수와 놓친 위험 에피소드 수를 담습니다.)
%
% 예외:
%   두 벡터 길이가 맞지 않으면 인덱싱 예외가 발생할 수 있습니다.
    actionMask = logical(actionMask(:));
    trueRisk = logical(trueRisk(:));
    riskEpisodes = extract_binary_episodes(trueRisk, 0);

    detected = 0;
    for i = 1:height(riskEpisodes)
        idx = riskEpisodes.start_idx(i):riskEpisodes.stop_idx(i);
        if any(actionMask(idx))
            detected = detected + 1;
        end
    end

    counts = struct();
    counts.detected_risk_episode_count = detected;
    counts.missed_risk_episode_count = height(riskEpisodes) - detected;
end

function switchCount = countPolicyEpisodeSwitches(actionMask, mergeGapWindows)
% 함수 설명:
%   액션 에피소드 개수를 기반으로 이전 방식의 정책 스위칭 근사값을 계산합니다.
%
% 입력:
%   actionMask (논리형 벡터, 비어 있을 수 없음: 전체 액션 발생 여부입니다.)
%   mergeGapWindows (수치형 스칼라, 비어 있을 수 없음: 같은 에피소드로 병합할 최대 간격입니다.)
%
% 출력:
%   switchCount (수치형 스칼라: 에피소드 시작과 종료를 전환으로 본 근사 스위칭 수입니다.)
%
% 예외:
%   입력 형식이 에피소드 추출 함수 요구 조건과 맞지 않으면 MATLAB 예외가 발생할 수 있습니다.
    actionEpisodes = extract_binary_episodes(logical(actionMask(:)), mergeGapWindows);
    switchCount = 2 * height(actionEpisodes);
    if ~isempty(actionMask) && actionMask(1)
        switchCount = switchCount - 1;
    end
    if ~isempty(actionMask) && actionMask(end)
        switchCount = switchCount - 1;
    end
end

function plotMspcTrajectory(W, S, figDir)
% 함수 설명:
%   시나리오별 MSPC 이상 점수 궤적을 그림으로 저장합니다.
%
% 입력:
%   W (테이블, 비어 있을 수 없음: 시나리오와 시간축 정보를 담은 윈도우 지표입니다.)
%   S (테이블, 비어 있을 수 없음: MSPC 점수와 관련 지표입니다.)
%   figDir (문자형 또는 문자열, 비어 있을 수 없음: 그림 저장 폴더입니다.)
%
% 출력:
%   반환값은 없으며, figure_06_mspc_score_trajectory.png를 저장합니다.
%
% 예외:
%   필수 열이 없거나 그림 저장 경로가 유효하지 않으면 MATLAB 예외가 발생할 수 있습니다.
    scenarios = ["normal", "low_quality_artifact", "high_risk_irregular"];
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
    tl = tiledlayout(f, numel(scenarios), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'MSPC anomaly score trajectory', 'FontWeight', 'bold');

    for i = 1:numel(scenarios)
        idx = string(W.scenario) == scenarios(i);
        nexttile;
        plot(W.day0_6(idx), S.mspc_score(idx), 'Color', [0.48 0.23 0.72], 'LineWidth', 1.2); hold on;
        yline(1, ':', '95% NOC limit', 'Color', [0.25 0.25 0.25]);
        ylabel(strrep(scenarios(i), '_', '\_'));
        grid on;
    end
    xlabel('normalized day 0-6');

    exportgraphics(f, fullfile(figDir, 'figure_06_mspc_score_trajectory.png'), 'Resolution', 180);
    close(f);
end

function plotRiskVsMspc(C, figDir)
% 함수 설명:
%   고위험 불규칙 시나리오에서 수작업 위험 프록시와 MSPC 위험 관측값을 비교해 그림으로 저장합니다.
%
% 입력:
%   C (테이블, 비어 있을 수 없음: 위험 프록시, MSPC 위험, 하이브리드 위험 비교 결과입니다.)
%   figDir (문자형 또는 문자열, 비어 있을 수 없음: 그림 저장 폴더입니다.)
%
% 출력:
%   반환값은 없으며, figure_07_risk_proxy_vs_mspc.png를 저장합니다.
%
% 예외:
%   필수 열이 없거나 그림 저장 경로가 유효하지 않으면 MATLAB 예외가 발생할 수 있습니다.
    idx = C.scenario == "high_risk_irregular";

    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 620]);
    tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Hand-crafted risk proxy vs MSPC observation', 'FontWeight', 'bold');

    nexttile;
    plot(C.day0_6(idx), C.risk_proxy(idx), 'Color', [0.65 0.18 0.18], 'LineWidth', 1.2); hold on;
    plot(C.day0_6(idx), C.mspc_risk(idx), 'Color', [0.48 0.23 0.72], 'LineWidth', 1.2);
    plot(C.day0_6(idx), C.hybrid_risk(idx), 'Color', [0.10 0.32 0.70], 'LineWidth', 1.2);
    ylabel('observation');
    legend({'risk proxy', 'MSPC risk', 'hybrid'}, 'Location', 'northwest');
    grid on;

    nexttile;
    scatter(C.risk_proxy, C.mspc_risk, 12, double(C.true_risk), 'filled');
    xlabel('risk proxy');
    ylabel('MSPC risk');
    grid on;

    exportgraphics(f, fullfile(figDir, 'figure_07_risk_proxy_vs_mspc.png'), 'Resolution', 180);
    close(f);
end
