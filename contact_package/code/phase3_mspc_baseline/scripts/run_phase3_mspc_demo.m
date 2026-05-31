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
    params = struct();
    params.alpha = P.baseObserverGain;
end

function ensurePhase2Outputs(phase2Root)
    phase2Csv = fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv');
    if ~isfile(phase2Csv)
        run(fullfile(phase2Root, 'scripts', 'run_phase2_demo.m'));
    end
end

function params = controllerParamsFromConfig(P)
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
