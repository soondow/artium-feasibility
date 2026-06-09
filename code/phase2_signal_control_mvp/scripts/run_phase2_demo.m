% 스크립트 설명:
%   Phase 2 합성 RRI 시나리오 전체를 실행해 품질, HRV 특징, 관찰자, 제어기, 평가 지표와 그림을 생성합니다.
%
% 입력:
%   프로젝트 설정 경로, 내부 함수, 스크립트 안에서 정의한 파라미터를 사용합니다.
%
% 출력:
%   콘솔 로그, CSV 테이블, 그림, 또는 Simulink 산출물을 생성할 수 있습니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


clear; clc; close all;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
phase2Root = fileparts(scriptDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));

figDir = fullfile(phase2Root, 'figures');
tableDir = fullfile(phase2Root, 'outputs', 'tables');

if ~exist(figDir, 'dir')
    mkdir(figDir);
end

if ~exist(tableDir, 'dir')
    mkdir(tableDir);
end

scenarios = ["normal", "low_quality_artifact", "high_risk_irregular", ...
    "missing_burst", "near_threshold_noise"];
scenarioSeeds = [11, 22, 33, 44, 55];
durationMinutes = 240;
beatsPerWindow = 60;
strideBeats = 30;
P = phase_control_params();
qMin = P.qMinDirectAlert;
tauMin = P.tauMin;
tauMax = P.tauMax;
mergeGapWindows = P.mergeGapWindows;
observerParams = observerParamsFromConfig(P);
controllerParams = controllerParamsFromConfig(P);

allTables = cell(numel(scenarios), 1);
summaryRows = cell(numel(scenarios) * 2, 1);
summaryIdx = 1;

for s = 1:numel(scenarios)
    S = generate_synthetic_rri(scenarios(s), ...
        'DurationMinutes', durationMinutes, ...
        'Seed', scenarioSeeds(s));
    W = segment_rri_windows(S, beatsPerWindow, strideBeats);
    T = processScenarioWindows(W, scenarios(s));

    O = quality_weighted_observer(T.risk_proxy, T.q, T.coverage, observerParams);
    C = adaptive_threshold_controller(T.risk_proxy, O.x_hat, O.U, T.q, controllerParams, T.coverage);
    scenarioTable = [T O C];

    windowMinutes = median((scenarioTable.stop_sec - scenarioTable.start_sec) / 60, 'omitnan');
    metricDurationDays = (max(scenarioTable.stop_sec) - min(scenarioTable.start_sec)) / (24 * 3600);
    fixedMetrics = compute_detection_metrics(scenarioTable.fixed_alert, false(height(scenarioTable), 1), ...
        scenarioTable.true_risk, scenarioTable.q, windowMinutes, metricDurationDays, mergeGapWindows, ...
        qMin, scenarioTable.true_low_quality, false(height(scenarioTable), 1));
    proposedMetrics = compute_detection_metrics(scenarioTable.adaptive_alert, scenarioTable.request_more_data, ...
        scenarioTable.true_risk, scenarioTable.q, windowMinutes, metricDurationDays, mergeGapWindows, ...
        qMin, scenarioTable.true_low_quality, scenarioTable.request_confirmation);

    summaryRows{summaryIdx} = metricsToTable(scenarios(s), "fixed_raw_threshold", fixedMetrics, ...
        scenarioTable, scenarioTable.fixed_alert, false(height(scenarioTable), 1), false(height(scenarioTable), 1), ...
        qMin);
    summaryIdx = summaryIdx + 1;
    summaryRows{summaryIdx} = metricsToTable(scenarios(s), "quality_aware_controller", proposedMetrics, ...
        scenarioTable, scenarioTable.adaptive_alert, scenarioTable.request_more_data, ...
        scenarioTable.request_confirmation, qMin);
    summaryIdx = summaryIdx + 1;

    allTables{s} = scenarioTable;
end

windowMetrics = vertcat(allTables{:});
baselineVsProposed = vertcat(summaryRows{:});
passFailSummary = buildPassFailSummary(windowMetrics, baselineVsProposed, qMin, tauMin, tauMax);
alertLog = windowMetrics(windowMetrics.fixed_alert | windowMetrics.adaptive_alert ...
    | windowMetrics.request_more_data | windowMetrics.request_confirmation, ...
    {'scenario', 'window_id', 'time_min', 'day0_6', 'q', 'coverage', 'risk_proxy', ...
    'x_hat', 'U', 'fixed_threshold', 'adaptive_threshold', 'fixed_alert', ...
    'adaptive_alert', 'request_more_data', 'request_confirmation', 'policy', ...
    'true_risk', 'true_low_quality'});

writetable(windowMetrics, fullfile(tableDir, 'window_metrics.csv'));
writetable(baselineVsProposed, fullfile(tableDir, 'baseline_vs_proposed.csv'));
writetable(alertLog, fullfile(tableDir, 'alert_log.csv'));
writetable(passFailSummary, fullfile(tableDir, 'phase2_pass_fail_summary.csv'));

plotPipelineFigure(figDir);
plotQualityObserverFigure(windowMetrics, figDir);
plotThresholdComparisonFigure(windowMetrics, figDir);
plotAlertLogFigure(windowMetrics, figDir);

fprintf('Phase 2 MVP complete.\n');
fprintf('Tables: %s\n', tableDir);
fprintf('Figures: %s\n', figDir);
disp(baselineVsProposed);

function T = processScenarioWindows(W, scenario)
% 함수 설명:
%   시나리오 윈도우별 신호 품질과 HRV 특징을 계산해 Phase 2 기본 지표 테이블을 만듭니다.
%
% 입력:
%   W (값, 비어 있을 수 없음: 함수 계산에 필요한 입력값입니다.)
%   scenario (문자열, 비어 있을 수 없음: 생성하거나 실행할 시나리오 이름입니다.)
%
% 출력:
%   T (테이블: 함수 목적에 따른 비교 결과, 전처리 결과, 또는 윈도우별 파이프라인 결과를 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    n = height(W);

    q = nan(n, 1);
    coverage = nan(n, 1);
    missingRatio = nan(n, 1);
    artifactRatio = nan(n, 1);
    continuityScore = nan(n, 1);

    nBeats = nan(n, 1);
    meanNN = nan(n, 1);
    sdnn = nan(n, 1);
    rmssd = nan(n, 1);
    pnn50 = nan(n, 1);
    cvRri = nan(n, 1);
    sd1 = nan(n, 1);
    sd2 = nan(n, 1);
    riskProxy = nan(n, 1);
    featureStatus = strings(n, 1);

    for k = 1:n
        rri = W.rri_ms{k};
        Q = compute_signal_quality(rri);
        F = extract_hrv_features(rri, Q.range_valid_mask);

        q(k) = Q.q;
        coverage(k) = Q.coverage;
        missingRatio(k) = Q.missing_ratio;
        artifactRatio(k) = Q.artifact_ratio;
        continuityScore(k) = Q.continuity_score;

        nBeats(k) = F.n_beats;
        meanNN(k) = F.meanNN_ms;
        sdnn(k) = F.SDNN_ms;
        rmssd(k) = F.RMSSD_ms;
        pnn50(k) = F.pNN50;
        cvRri(k) = F.CV_RRI;
        sd1(k) = F.SD1_ms;
        sd2(k) = F.SD2_ms;
        riskProxy(k) = F.irregularity_index;
        featureStatus(k) = F.status;
    end

    timeMin = W.start_sec / 60;
    day0_6 = 6 * (timeMin - min(timeMin)) / max(eps, (max(timeMin) - min(timeMin)));

    T = table(repmat(string(scenario), n, 1), W.window_id, W.start_sec, W.stop_sec, timeMin, day0_6, ...
        W.true_risk, W.true_low_quality, q, coverage, missingRatio, artifactRatio, continuityScore, ...
        nBeats, meanNN, sdnn, rmssd, pnn50, cvRri, sd1, sd2, riskProxy, featureStatus, ...
        'VariableNames', {'scenario', 'window_id', 'start_sec', 'stop_sec', 'time_min', 'day0_6', ...
        'true_risk', 'true_low_quality', 'q', 'coverage', 'missing_ratio', 'artifact_ratio', ...
        'continuity_score', 'n_beats', 'meanNN_ms', 'SDNN_ms', 'RMSSD_ms', 'pNN50', ...
        'CV_RRI', 'SD1_ms', 'SD2_ms', 'risk_proxy', 'feature_status'});
end

function params = observerParamsFromConfig(P)
% 함수 설명:
%   공유 설정 구조체에서 관찰자 함수에 필요한 파라미터만 추출합니다.
%
% 입력:
%   P (값, 비어 있을 수 없음: 함수 계산에 필요한 입력값입니다.)
%
% 출력:
%   params (구조체: 직접 알림 허용 조건, 적응 임계값, 불응 구간, 정책 유지 시간, 윈도우 병합 기준을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    params = struct();
    params.alpha = P.baseObserverGain;
end

function params = controllerParamsFromConfig(P)
% 함수 설명:
%   공유 설정 구조체에서 적응형 제어기에 필요한 파라미터만 추출합니다.
%
% 입력:
%   P (값, 비어 있을 수 없음: 함수 계산에 필요한 입력값입니다.)
%
% 출력:
%   params (구조체: 직접 알림 허용 조건, 적응 임계값, 불응 구간, 정책 유지 시간, 윈도우 병합 기준을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
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

function T = metricsToTable(scenario, method, M, scenarioTable, directAlert, requestMoreData, requestConfirmation, qMin)
% 함수 설명:
%   구조체 형태의 평가 지표와 윈도우 결과를 비교 가능한 단일 행 테이블로 변환합니다.
%
% 입력:
%   scenario (문자열, 비어 있을 수 없음: 생성하거나 실행할 시나리오 이름입니다.)
%   method (문자열, 비어 있을 수 없음: 비교 대상 방법 이름입니다.)
%   M (값, 비어 있을 수 없음: 함수 계산에 필요한 입력값입니다.)
%   scenarioTable (테이블, 비어 있을 수 없음: 한 시나리오의 윈도우별 품질, 위험, 정책 결과입니다.)
%   directAlert (논리형 벡터, 비어 있을 수 없음: 직접 알림 마스크입니다.)
%   requestMoreData (논리형 벡터, 비어 있을 수 없음: 추가 데이터 요청 마스크입니다.)
%   requestConfirmation (논리형 벡터, 비어 있을 수 없음: 확인 요청 마스크입니다.)
%   qMin (수치형 스칼라, 비어 있을 수 있음: 낮은 품질 직접 알림 판정 기준입니다.)
%
% 출력:
%   T (테이블: 함수 목적에 따른 비교 결과, 전처리 결과, 또는 윈도우별 파이프라인 결과를 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    directAlert = logical(directAlert(:));
    requestMoreData = logical(requestMoreData(:));
    requestConfirmation = logical(requestConfirmation(:));

    mergeGapWindows = 12;
    directAlertEpisodes = extract_binary_episodes(directAlert, 12);
    lowQualityDirectAlertCount = nnz(directAlert & scenarioTable.q < qMin);

    actionMask = directAlert | requestMoreData | requestConfirmation;
    finalPolicy = derivePolicyFromMasks(directAlert, requestMoreData, requestConfirmation);
    policyTransitionCount = count_policy_transitions(finalPolicy);
    actionSwitchCount = count_binary_switches(actionMask);
    directAlertSwitchCount = count_binary_switches(directAlert);
    controllerSwitchCountDeprecated = countPolicyEpisodeSwitches(actionMask, mergeGapWindows);
    directDetection = episodeDetectionCounts(directAlert, scenarioTable.true_risk);
    actionDetection = episodeDetectionCounts(actionMask, scenarioTable.true_risk);

    T = table(string(scenario), string(method), ...
        M.window_alert_count, height(directAlertEpisodes), ...
        M.false_direct_alert_episode_count, height(directAlertEpisodes), ...
        M.false_alert_episode_count, ...
        nnz(requestMoreData), nnz(requestConfirmation), ...
        M.request_episode_count, M.false_request_episode_count, ...
        M.confirmation_episode_count, M.false_confirmation_episode_count, ...
        M.action_episode_count, M.false_action_episode_count, ...
        M.nonrisk_request_episode_count, M.nonrisk_confirmation_episode_count, ...
        M.nonrisk_action_episode_count, ...
        M.detected_risk_episode_count, M.missed_risk_episode_count, ...
        directDetection.detected_risk_episode_count, directDetection.missed_risk_episode_count, ...
        actionDetection.detected_risk_episode_count, actionDetection.missed_risk_episode_count, ...
        M.mean_detection_latency_windows, lowQualityDirectAlertCount, ...
        M.low_quality_alert_episode_count, policyTransitionCount, actionSwitchCount, ...
        directAlertSwitchCount, controllerSwitchCountDeprecated, ...
        M.request_windows_per_day, M.confirmation_windows_per_day, M.action_episodes_per_day, ...
        mean(scenarioTable.q, 'omitnan'), mean(scenarioTable.coverage, 'omitnan'), ...
        mean(scenarioTable.U, 'omitnan'), mean(scenarioTable.x_hat, 'omitnan'), ...
        max(scenarioTable.x_hat, [], 'omitnan'), mean(scenarioTable.adaptive_threshold, 'omitnan'), ...
        M.false_alarm_window_count, M.false_alarm_episodes_per_day, ...
        M.low_quality_alert_episode_ratio, M.monitoring_request_episodes, ...
        'VariableNames', {'scenario', 'method', ...
        'window_alert_count', 'alert_episode_count', ...
        'false_direct_alert_episode_count', 'direct_alert_episode_count', ...
        'false_alert_episode_count', ...
        'request_more_data_count', 'request_confirmation_count', ...
        'request_episode_count', 'false_request_episode_count', ...
        'confirmation_episode_count', 'false_confirmation_episode_count', ...
        'action_episode_count', 'false_action_episode_count', ...
        'nonrisk_request_episode_count', 'nonrisk_confirmation_episode_count', ...
        'nonrisk_action_episode_count', ...
        'detected_risk_episode_count', 'missed_risk_episode_count', ...
        'direct_alert_detected_risk_episode_count', 'direct_alert_missed_risk_episode_count', ...
        'action_detected_risk_episode_count', 'action_missed_risk_episode_count', ...
        'mean_detection_latency_windows', 'low_quality_direct_alert_count', ...
        'low_quality_alert_episode_count', 'policy_transition_count', ...
        'action_switch_count', 'direct_alert_switch_count', 'controller_switch_count_deprecated', ...
        'request_windows_per_day', 'confirmation_windows_per_day', 'action_episodes_per_day', ...
        'mean_q', 'mean_coverage', ...
        'mean_uncertainty', 'mean_x_hat', 'max_x_hat', 'mean_tau', ...
        'false_alert_window_count', 'false_alert_episodes_per_day', ...
        'low_quality_alert_episode_ratio', 'monitoring_request_episodes'});
end

function policy = derivePolicyFromMasks(directAlert, requestMoreData, requestConfirmation)
% 함수 설명:
%   직접 알림, 추가 데이터 요청, 확인 요청 마스크의 우선순위로 정책 라벨을 생성합니다.
%
% 입력:
%   directAlert (논리형 벡터, 비어 있을 수 없음: 직접 알림 마스크입니다.)
%   requestMoreData (논리형 벡터, 비어 있을 수 없음: 추가 데이터 요청 마스크입니다.)
%   requestConfirmation (논리형 벡터, 비어 있을 수 없음: 확인 요청 마스크입니다.)
%
% 출력:
%   policy (문자열 배열: 액션 마스크 우선순위로 결정한 최종 정책 라벨입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    n = numel(directAlert);
    policy = strings(n, 1);

    for k = 1:n
        if directAlert(k)
            policy(k) = "alert";
        elseif requestMoreData(k)
            policy(k) = "request_more_data";
        elseif requestConfirmation(k)
            policy(k) = "request_confirmation";
        else
            policy(k) = "observe";
        end
    end
end

function switchCount = countPolicyEpisodeSwitches(actionMask, mergeGapWindows)
% 함수 설명:
%   병합된 액션 에피소드를 기준으로 정책 전환 부담을 근사 계산합니다.
%
% 입력:
%   actionMask (논리형 벡터, 비어 있을 수 없음: 직접 알림과 요청 정책을 합친 액션 마스크입니다.)
%   mergeGapWindows (수치형 스칼라, 비어 있을 수 있음: 같은 에피소드로 병합할 최대 빈 윈도우 수입니다.)
%
% 출력:
%   switchCount (수치형 스칼라: 인접 원소가 달라지는 횟수입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    actionEpisodes = extract_binary_episodes(logical(actionMask(:)), mergeGapWindows);
    switchCount = 2 * height(actionEpisodes);
    if ~isempty(actionMask) && actionMask(1)
        switchCount = switchCount - 1;
    end
    if ~isempty(actionMask) && actionMask(end)
        switchCount = switchCount - 1;
    end
end

function counts = episodeDetectionCounts(actionMask, trueRisk)
% 함수 설명:
%   액션 마스크가 실제 위험 에피소드를 몇 개 탐지했는지 계산합니다.
%
% 입력:
%   actionMask (논리형 벡터, 비어 있을 수 없음: 직접 알림과 요청 정책을 합친 액션 마스크입니다.)
%   trueRisk (논리형 벡터, 비어 있을 수 없음: 실제 위험 에피소드 라벨입니다.)
%
% 출력:
%   counts (값: 함수 계산 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
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

function T = buildPassFailSummary(windowMetrics, baselineVsProposed, qMin, tauMin, tauMax)
% 함수 설명:
%   Phase 2 데모 결과에서 핵심 안전 조건과 성능 조건의 통과 여부를 요약합니다.
%
% 입력:
%   windowMetrics (테이블, 비어 있을 수 없음: Phase 2 윈도우 특징, 품질, 라벨 컬럼을 포함한 테이블입니다.)
%   baselineVsProposed (테이블, 비어 있을 수 없음: 고정 기준선과 제안 정책의 비교 지표입니다.)
%   qMin (수치형 스칼라, 비어 있을 수 있음: 낮은 품질 직접 알림 판정 기준입니다.)
%   tauMin (수치형 스칼라, 비어 있을 수 없음: 적응 임계값의 하한입니다.)
%   tauMax (수치형 스칼라, 비어 있을 수 없음: 적응 임계값의 상한입니다.)
%
% 출력:
%   T (테이블: 함수 목적에 따른 비교 결과, 전처리 결과, 또는 윈도우별 파이프라인 결과를 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    rows = {};
    rows(end + 1, :) = passFailRow('sqi_bounds', 'all', '0 <= q_k <= 1', ...
        all(windowMetrics.q >= 0 & windowMetrics.q <= 1), 'all bounded', 'all bounded', ...
        'Signal quality index remains bounded.');
    rows(end + 1, :) = passFailRow('coverage_bounds', 'all', '0 <= c_k <= 1', ...
        all(windowMetrics.coverage >= 0 & windowMetrics.coverage <= 1), 'all bounded', 'all bounded', ...
        'Coverage remains bounded.');
    rows(end + 1, :) = passFailRow('observer_bounds', 'all', '0 <= x_hat_k <= 1 and 0 <= U_k <= 1', ...
        all(windowMetrics.x_hat >= 0 & windowMetrics.x_hat <= 1) ...
        && all(windowMetrics.U >= 0 & windowMetrics.U <= 1), ...
        'all bounded', 'all bounded', 'Observer states remain bounded.');
    rows(end + 1, :) = passFailRow('threshold_bounds', 'all', 'tau_min <= tau_k <= tau_max', ...
        all(windowMetrics.adaptive_threshold >= tauMin & windowMetrics.adaptive_threshold <= tauMax), ...
        sprintf('[%.2f, %.2f]', min(windowMetrics.adaptive_threshold), max(windowMetrics.adaptive_threshold)), ...
        sprintf('[%.2f, %.2f]', tauMin, tauMax), 'Adaptive threshold remains bounded.');

    rows = addScenarioChecks(rows, windowMetrics, baselineVsProposed, qMin);

    T = cell2table(rows, 'VariableNames', ...
        {'test_name', 'scenario', 'condition', 'observed_value', 'expected_value', 'pass', 'comment'});
    T.test_name = string(T.test_name);
    T.scenario = string(T.scenario);
    T.condition = string(T.condition);
    T.observed_value = string(T.observed_value);
    T.expected_value = string(T.expected_value);
    if iscell(T.pass)
        T.pass = logical([T.pass{:}])';
    else
        T.pass = logical(T.pass);
    end
    T.comment = string(T.comment);
end

function rows = addScenarioChecks(rows, W, B, qMin)
% 함수 설명:
%   시나리오별 기대 조건을 pass/fail 요약 행으로 누적합니다.
%
% 입력:
%   rows (셀 배열, 비어 있을 수 있음: 누적 중인 pass/fail 결과 행 목록입니다.)
%   W (값, 비어 있을 수 없음: 함수 계산에 필요한 입력값입니다.)
%   B (테이블, 비어 있을 수 없음: 방법별 성능 비교 지표 테이블입니다.)
%   qMin (수치형 스칼라, 비어 있을 수 있음: 낮은 품질 직접 알림 판정 기준입니다.)
%
% 출력:
%   rows (값: 함수 계산 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    normalFixed = findMetricRow(B, "normal", "fixed_raw_threshold");
    normalProposed = findMetricRow(B, "normal", "quality_aware_controller");
    lowqProposed = findMetricRow(B, "low_quality_artifact", "quality_aware_controller");
    highRiskProposed = findMetricRow(B, "high_risk_irregular", "quality_aware_controller");
    missingProposed = findMetricRow(B, "missing_burst", "quality_aware_controller");
    thresholdFixed = findMetricRow(B, "near_threshold_noise", "fixed_raw_threshold");
    thresholdProposed = findMetricRow(B, "near_threshold_noise", "quality_aware_controller");

    rows(end + 1, :) = passFailRow('normal_false_alert', 'normal', ...
        'proposed false_alert_episode_count <= fixed', ...
        normalProposed.false_alert_episode_count <= normalFixed.false_alert_episode_count, ...
        normalProposed.false_alert_episode_count, normalFixed.false_alert_episode_count, ...
        'Normal baseline should not create extra proposed false alerts.');

    rows(end + 1, :) = passFailRow('low_quality_alert_prohibition', 'low_quality_artifact', ...
        'proposed direct_alert_episode_count = 0', ...
        lowqProposed.direct_alert_episode_count == 0, ...
        lowqProposed.direct_alert_episode_count, 0, ...
        'Suspicious low-quality artifact is not converted into direct alerts.');

    rows(end + 1, :) = passFailRow('low_quality_direct_alert_count', 'low_quality_artifact', ...
        'q_k < q_min implies direct_alert = 0', ...
        lowqProposed.low_quality_direct_alert_count == 0, ...
        lowqProposed.low_quality_direct_alert_count, 0, ...
        'Core safety invariant for low-quality direct-alert prohibition.');

    rows(end + 1, :) = passFailRow('confirmation_routing', 'low_quality_artifact', ...
        'request_confirmation_count + request_more_data_count >= 1', ...
        (lowqProposed.request_confirmation_count + lowqProposed.request_more_data_count) >= 1, ...
        lowqProposed.request_confirmation_count + lowqProposed.request_more_data_count, '>=1', ...
        'Low-quality suspicious windows are routed to confirmation or more data.');

    lowqW = W(W.scenario == "low_quality_artifact", :);
    artifactUIncrease = mean(lowqW.U(lowqW.true_low_quality), 'omitnan') > mean(lowqW.U(~lowqW.true_low_quality), 'omitnan');
    rows(end + 1, :) = passFailRow('artifact_uncertainty_increase', 'low_quality_artifact', ...
        'mean U_k during artifact > outside artifact', artifactUIncrease, ...
        mean(lowqW.U(lowqW.true_low_quality), 'omitnan'), ...
        mean(lowqW.U(~lowqW.true_low_quality), 'omitnan'), ...
        'Uncertainty rises when signal quality is degraded.');

    rows(end + 1, :) = passFailRow('high_risk_detection', 'high_risk_irregular', ...
        'detected_risk_episode_count >= 1 and missed = 0', ...
        highRiskProposed.detected_risk_episode_count >= 1 && highRiskProposed.missed_risk_episode_count == 0, ...
        sprintf('%d detected, %d missed', highRiskProposed.detected_risk_episode_count, highRiskProposed.missed_risk_episode_count), ...
        '>=1 detected, 0 missed', 'High-risk irregular episode is detected.');

    rows(end + 1, :) = passFailRow('high_risk_latency_finite', 'high_risk_irregular', ...
        'mean_detection_latency_windows is finite', ...
        isfinite(highRiskProposed.mean_detection_latency_windows), ...
        highRiskProposed.mean_detection_latency_windows, 'finite', ...
        'Detection latency is defined for detected high-risk episode.');

    missingW = W(W.scenario == "missing_burst", :);
    missingCoverageDrop = mean(missingW.coverage(missingW.true_low_quality), 'omitnan') ...
        < mean(missingW.coverage(~missingW.true_low_quality), 'omitnan');
    rows(end + 1, :) = passFailRow('missing_burst_coverage_drop', 'missing_burst', ...
        'coverage during burst < outside burst', missingCoverageDrop, ...
        mean(missingW.coverage(missingW.true_low_quality), 'omitnan'), ...
        mean(missingW.coverage(~missingW.true_low_quality), 'omitnan'), ...
        'Coverage decreases during missing burst.');

    rows(end + 1, :) = passFailRow('missing_burst_alert_suppression', 'missing_burst', ...
        'low_quality_direct_alert_count = 0', ...
        missingProposed.low_quality_direct_alert_count == 0, ...
        missingProposed.low_quality_direct_alert_count, 0, ...
        'Direct alerts remain suppressed under low coverage/quality.');

    rows(end + 1, :) = passFailRow('near_threshold_alert_burden', 'near_threshold_noise', ...
        'proposed alert_episode_count < fixed alert_episode_count', ...
        thresholdProposed.alert_episode_count < thresholdFixed.alert_episode_count, ...
        thresholdProposed.alert_episode_count, thresholdFixed.alert_episode_count, ...
        'Refractory control reduces near-threshold alert burden.');

    rows(end + 1, :) = passFailRow('near_threshold_switching', 'near_threshold_noise', ...
        'proposed policy_transition_count <= fixed', ...
        thresholdProposed.policy_transition_count <= thresholdFixed.policy_transition_count, ...
        thresholdProposed.policy_transition_count, thresholdFixed.policy_transition_count, ...
        'Final policy transitions do not exceed fixed-threshold switching.');

    lowQDirect = nnz(W.adaptive_alert & W.q < qMin);
    rows(end + 1, :) = passFailRow('global_low_quality_alert_prohibition', 'all', ...
        'all q_k < q_min windows have direct_alert = 0', ...
        lowQDirect == 0, lowQDirect, 0, ...
        'No proposed direct alert is emitted below q_min.');

    injectedLowQualityFalseAlert = nnz(W.adaptive_alert & logical(W.true_low_quality) & ~logical(W.true_risk));
    rows(end + 1, :) = passFailRow('injected_low_quality_false_alert_prohibition', 'all', ...
        'adaptive_alert & true_low_quality & ~true_risk = 0', ...
        injectedLowQualityFalseAlert == 0, injectedLowQualityFalseAlert, 0, ...
        'No direct false alert is emitted in injected low-quality non-risk windows.');

    rows(end + 1, :) = passFailRow('high_risk_action_detection', 'high_risk_irregular', ...
        'direct alert or request action detects risk episode', ...
        highRiskProposed.action_detected_risk_episode_count >= 1 ...
        && highRiskProposed.action_missed_risk_episode_count == 0, ...
        sprintf('%d detected, %d missed', highRiskProposed.action_detected_risk_episode_count, highRiskProposed.action_missed_risk_episode_count), ...
        '>=1 detected, 0 missed', 'Monitoring action detection is tracked separately from direct alerts.');

    rows(end + 1, :) = passFailRow('request_burden_metrics', 'low_quality_artifact', ...
        'request/action episode metrics are present and nonnegative', ...
        lowqProposed.request_episode_count >= 1 ...
        && lowqProposed.action_episode_count >= lowqProposed.request_episode_count ...
        && lowqProposed.nonrisk_action_episode_count >= 0, ...
        sprintf('request=%d, action=%d, nonrisk_action=%d', ...
        lowqProposed.request_episode_count, lowqProposed.action_episode_count, ...
        lowqProposed.nonrisk_action_episode_count), ...
        'request>=1, action>=request, nonrisk_action>=0', ...
        'Request and total monitoring-action burden are reported separately.');

    rows(end + 1, :) = passFailRow('high_risk_policy_transition_limit', 'high_risk_irregular', ...
        'policy_transition_count <= 30', ...
        highRiskProposed.policy_transition_count <= 30, ...
        highRiskProposed.policy_transition_count, 30, ...
        'Final policy transitions should remain bounded during high-risk monitoring.');
end

function row = passFailRow(testName, scenario, condition, passValue, observedValue, expectedValue, comment)
% 함수 설명:
%   단일 검증 조건의 관측값, 기대값, 통과 여부를 표준 행 형식으로 만듭니다.
%
% 입력:
%   testName (문자열, 비어 있을 수 없음: 검증 조건 이름입니다.)
%   scenario (문자열, 비어 있을 수 없음: 생성하거나 실행할 시나리오 이름입니다.)
%   condition (문자열, 비어 있을 수 없음: 검증 조건 설명입니다.)
%   passValue (논리형 값, 비어 있을 수 없음: 조건 통과 여부입니다.)
%   observedValue (임의 값, 비어 있을 수 있음: 실제 관측값입니다.)
%   expectedValue (임의 값, 비어 있을 수 있음: 기대값 또는 기준값입니다.)
%   comment (문자열, 비어 있을 수 있음: 검증 결과의 해석 설명입니다.)
%
% 출력:
%   row (값: 함수 계산 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    row = {string(testName), string(scenario), string(condition), ...
        stringifyValue(observedValue), stringifyValue(expectedValue), logical(passValue), string(comment)};
end

function row = findMetricRow(T, scenario, method)
% 함수 설명:
%   시나리오와 방법 이름에 해당하는 평가 지표 행을 하나만 조회합니다.
%
% 입력:
%   T (테이블, 비어 있을 수 없음: 실제 RRI 또는 파이프라인 결과를 담은 테이블입니다.)
%   scenario (문자열, 비어 있을 수 없음: 생성하거나 실행할 시나리오 이름입니다.)
%   method (문자열, 비어 있을 수 없음: 비교 대상 방법 이름입니다.)
%
% 출력:
%   row (값: 함수 계산 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    row = T(T.scenario == scenario & T.method == method, :);
    if height(row) ~= 1
        error('Expected exactly one metric row for %s / %s.', scenario, method);
    end
end

function out = stringifyValue(value)
% 함수 설명:
%   테이블 저장을 위해 다양한 값 타입을 문자열 표현으로 변환합니다.
%
% 입력:
%   value (임의 값, 비어 있을 수 있음: 필드가 없거나 비어 있을 때 대입할 기본값입니다.)
%
% 출력:
%   out (값: 함수 계산 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    if isstring(value) || ischar(value)
        out = string(value);
    elseif isnumeric(value) || islogical(value)
        if isscalar(value)
            if isnan(value)
                out = "NaN";
            else
                out = string(value);
            end
        else
            out = mat2str(value);
        end
    else
        out = string(value);
    end
end

function plotPipelineFigure(figDir)
% 함수 설명:
%   Phase 2 품질 인식 모니터링 파이프라인 개요 그림을 저장합니다.
%
% 입력:
%   figDir (문자열, 비어 있을 수 없음: 그림 산출물을 저장할 폴더 경로입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1800 520]);
    ax = axes(f);
    axis(ax, [0 1 0 1]);
    axis(ax, 'off');
    hold(ax, 'on');

    labels = {sprintf('Signal\nInput Bus'), sprintf('SQI\nEstimator'), ...
        sprintf('HRV Feature\nExtraction'), sprintf('Risk-State\nObserver'), ...
        sprintf('Adaptive Threshold\nController'), sprintf('Alert Policy\nLogger')};
    x = linspace(0.035, 0.815, numel(labels));
    y = 0.44;
    w = 0.145;
    h = 0.25;

    for i = 1:numel(labels)
        rectangle(ax, 'Position', [x(i), y, w, h], 'Curvature', 0.08, ...
            'FaceColor', [0.93 0.96 1.00], 'EdgeColor', [0.12 0.32 0.70], 'LineWidth', 1.4);
        text(ax, x(i) + w / 2, y + h / 2, labels{i}, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.08 0.16 0.35]);
        if i < numel(labels)
            x0 = x(i) + w + 0.012;
            dx = x(i + 1) - x0 - 0.012;
            quiver(ax, x0, y + h / 2, dx, 0, 0, ...
                'Color', [0.35 0.40 0.50], 'LineWidth', 1.4, 'MaxHeadSize', 0.50);
        end
    end

    text(ax, 0.5, 0.82, 'Quality-aware RRI monitoring-policy MVP', ...
        'HorizontalAlignment', 'center', 'FontSize', 17, 'FontWeight', 'bold', 'Color', [0.08 0.10 0.15]);
    text(ax, 0.5, 0.22, 'q_k and coverage gate observer updates; U_k raises threshold or requests more data under uncertainty.', ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.28 0.34]);
    axis(ax, [0 1 0 1]);
    axis(ax, 'off');

    exportgraphics(f, fullfile(figDir, 'figure_01_pipeline.png'), 'Resolution', 180);
    close(f);
end

function plotQualityObserverFigure(T, figDir)
% 함수 설명:
%   낮은 품질 인공물 시나리오에서 관찰자 상태와 불확실성 변화를 시각화합니다.
%
% 입력:
%   T (테이블, 비어 있을 수 없음: 실제 RRI 또는 파이프라인 결과를 담은 테이블입니다.)
%   figDir (문자열, 비어 있을 수 없음: 그림 산출물을 저장할 폴더 경로입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    Tq = T(T.scenario == "low_quality_artifact", :);

    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
    tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Quality effect on observer update', 'FontWeight', 'bold');

    nexttile;
    plot(Tq.day0_6, Tq.risk_proxy, 'Color', [0.65 0.18 0.18], 'LineWidth', 1.0); hold on;
    plot(Tq.day0_6, Tq.x_hat, 'Color', [0.10 0.32 0.70], 'LineWidth', 1.6);
    ylabel('risk');
    legend({'raw HRV risk', 'x\_hat'}, 'Location', 'northwest');
    grid on;

    nexttile;
    plot(Tq.day0_6, Tq.q, 'Color', [0.00 0.45 0.30], 'LineWidth', 1.4); hold on;
    plot(Tq.day0_6, Tq.coverage, '--', 'Color', [0.25 0.55 0.45], 'LineWidth', 1.1);
    ylabel('quality');
    ylim([0 1.05]);
    legend({'q\_k', 'coverage'}, 'Location', 'southwest');
    grid on;

    nexttile;
    plot(Tq.day0_6, Tq.U, 'Color', [0.48 0.23 0.72], 'LineWidth', 1.5);
    ylabel('U\_k');
    xlabel('normalized day 0-6');
    ylim([0 1.05]);
    grid on;

    exportgraphics(f, fullfile(figDir, 'figure_02_quality_observer_trajectory.png'), 'Resolution', 180);
    close(f);
end

function plotThresholdComparisonFigure(T, figDir)
% 함수 설명:
%   고정 임계값과 적응형 품질 인식 제어기의 알림 차이를 시각화합니다.
%
% 입력:
%   T (테이블, 비어 있을 수 없음: 실제 RRI 또는 파이프라인 결과를 담은 테이블입니다.)
%   figDir (문자열, 비어 있을 수 없음: 그림 산출물을 저장할 폴더 경로입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    Ta = T(T.scenario == "low_quality_artifact", :);

    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 720]);
    tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Fixed raw threshold vs adaptive quality-aware controller', 'FontWeight', 'bold');

    nexttile;
    plot(Ta.day0_6, Ta.risk_proxy, 'Color', [0.65 0.18 0.18], 'LineWidth', 1.0); hold on;
    plot(Ta.day0_6, Ta.x_hat, 'Color', [0.10 0.32 0.70], 'LineWidth', 1.5);
    plot(Ta.day0_6, Ta.fixed_threshold, ':', 'Color', [0.20 0.20 0.20], 'LineWidth', 1.3);
    plot(Ta.day0_6, Ta.adaptive_threshold, '--', 'Color', [0.48 0.23 0.72], 'LineWidth', 1.4);
    ylabel('score');
    legend({'raw risk', 'x\_hat', 'fixed threshold', 'adaptive threshold'}, 'Location', 'northwest');
    grid on;

    nexttile;
    stem(Ta.day0_6, double(Ta.fixed_alert), 'Color', [0.65 0.18 0.18], 'Marker', 'none'); hold on;
    stem(Ta.day0_6, 1.1 * double(Ta.adaptive_alert), 'Color', [0.10 0.32 0.70], 'Marker', 'none');
    stem(Ta.day0_6, 0.65 * double(Ta.request_confirmation), 'Color', [0.85 0.55 0.10], 'Marker', 'none');
    stem(Ta.day0_6, 0.45 * double(Ta.request_more_data), 'Color', [0.48 0.23 0.72], 'Marker', 'none');
    xlabel('normalized day 0-6');
    ylabel('policy event');
    ylim([0 1.35]);
    yticks([0 0.45 0.65 1 1.1]);
    yticklabels({'none', 'more data', 'confirm', 'fixed alert', 'adaptive alert'});
    grid on;

    exportgraphics(f, fullfile(figDir, 'figure_03_fixed_vs_adaptive_threshold.png'), 'Resolution', 180);
    close(f);
end

function plotAlertLogFigure(T, figDir)
% 함수 설명:
%   고위험 불규칙 시나리오의 위험, 품질, 불확실성, 정책 이벤트 궤적을 시각화합니다.
%
% 입력:
%   T (테이블, 비어 있을 수 없음: 실제 RRI 또는 파이프라인 결과를 담은 테이블입니다.)
%   figDir (문자열, 비어 있을 수 없음: 그림 산출물을 저장할 폴더 경로입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    Th = T(T.scenario == "high_risk_irregular", :);

    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 820]);
    tl = tiledlayout(f, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Day 0-6 synthetic high-risk trajectory', 'FontWeight', 'bold');

    nexttile;
    area(Th.day0_6, double(Th.true_risk), 'FaceColor', [1.00 0.88 0.78], 'EdgeColor', 'none'); hold on;
    plot(Th.day0_6, Th.risk_proxy, 'Color', [0.65 0.18 0.18], 'LineWidth', 1.0);
    plot(Th.day0_6, Th.x_hat, 'Color', [0.10 0.32 0.70], 'LineWidth', 1.4);
    ylabel('risk');
    ylim([0 1.1]);
    legend({'true risk episode', 'raw risk', 'x\_hat'}, 'Location', 'northwest');
    grid on;

    nexttile;
    plot(Th.day0_6, Th.q, 'Color', [0.00 0.45 0.30], 'LineWidth', 1.3);
    ylabel('q\_k');
    ylim([0 1.05]);
    grid on;

    nexttile;
    plot(Th.day0_6, Th.U, 'Color', [0.48 0.23 0.72], 'LineWidth', 1.3);
    ylabel('U\_k');
    ylim([0 1.05]);
    grid on;

    nexttile;
    stem(Th.day0_6, double(Th.fixed_alert), 'Color', [0.65 0.18 0.18], 'Marker', 'none'); hold on;
    stem(Th.day0_6, 1.1 * double(Th.adaptive_alert), 'Color', [0.10 0.32 0.70], 'Marker', 'none');
    stem(Th.day0_6, 0.65 * double(Th.request_confirmation), 'Color', [0.85 0.55 0.10], 'Marker', 'none');
    stem(Th.day0_6, 0.45 * double(Th.request_more_data), 'Color', [0.48 0.23 0.72], 'Marker', 'none');
    xlabel('day');
    ylabel('events');
    ylim([0 1.35]);
    yticks([0 0.45 0.65 1 1.1]);
    yticklabels({'none', 'more data', 'confirm', 'fixed alert', 'adaptive alert'});
    grid on;

    exportgraphics(f, fullfile(figDir, 'figure_04_alert_log_day0_6.png'), 'Resolution', 180);
    close(f);
end
