function P = build_patient_level_monitoring_summary(windowMetrics, eventMetrics)
%BUILD_PATIENT_LEVEL_MONITORING_SUMMARY Build a patient-level Model A/B scaffold.
%
% This table is an architecture scaffold for the research plan. In the
% current package each synthetic scenario is treated as a patient-like
% monitoring record. ERAF_0_90_proxy is reserved for the Model B landmark
% update and is not used by Model A.

    windowMetrics.scenario = string(windowMetrics.scenario);
    eventMetrics.scenario = string(eventMetrics.scenario);
    eventMetrics.method = string(eventMetrics.method);

    proposed = eventMetrics(eventMetrics.method == "quality_aware_controller", :);
    scenarios = unique(windowMetrics.scenario, 'stable');
    rows = cell(numel(scenarios), 1);

    for i = 1:numel(scenarios)
        scenario = scenarios(i);
        W = windowMetrics(windowMetrics.scenario == scenario, :);
        E = proposed(proposed.scenario == scenario, :);
        if height(E) ~= 1
            error('Expected one proposed event-metric row for scenario: %s', scenario);
        end

        durationDays = (max(W.stop_sec) - min(W.start_sec)) / (24 * 3600);
        durationDays = max(durationDays, eps);
        meanCoverage = mean(W.coverage, 'omitnan');
        meanQ = mean(W.q, 'omitnan');
        meanU = mean(W.U, 'omitnan');
        uPatient = percentile_local(W.U, 90);
        validTimeDays = max(durationDays * meanCoverage, eps);

        b_0_56 = E.action_episode_count / validTimeDays;
        aPatient = E.direct_alert_episode_count;
        maxRiskState = max(W.x_hat, [], 'omitnan');
        monitoringReliability = clip01(meanQ * meanCoverage * (1 - meanU));
        burdenIndex = clip01(b_0_56 / 12);

        modelA = clip01(0.45 * maxRiskState ...
            + 0.25 * burdenIndex ...
            + 0.20 * uPatient ...
            + 0.10 * (1 - meanCoverage));

        erafProxy = any(W.true_risk);
        monitoringIntensity = clip01(0.35 * burdenIndex ...
            + 0.35 * uPatient ...
            + 0.30 * (1 - monitoringReliability));
        modelB = clip01(0.65 * modelA ...
            + 0.25 * double(erafProxy) ...
            + 0.10 * monitoringIntensity);

        policy = recommend_policy(modelA, monitoringReliability, uPatient, aPatient);

        rows{i} = table( ...
            "synthetic_" + scenario, scenario, height(W), durationDays, validTimeDays, ...
            b_0_56, uPatient, aPatient, meanQ, meanCoverage, meanU, ...
            modelA, monitoringReliability, policy, ...
            "b_0_56;U_patient;A_patient;mean_q;coverage_summary", ...
            erafProxy, monitoringIntensity, modelB, ...
            "ModelA_output;ERAF_0_90_proxy;monitoring_intensity_proxy", ...
            'VariableNames', {'patient_id', 'scenario', 'window_count', ...
            'duration_days', 'valid_time_days', 'b_0_56', 'U_patient', ...
            'A_patient', 'mean_q', 'coverage_summary', 'mean_uncertainty', ...
            'modelA_early_risk_state', 'modelA_monitoring_reliability', ...
            'suggested_monitoring_policy', 'modelA_input_set', ...
            'ERAF_0_90_proxy', 'monitoring_intensity_proxy', ...
            'modelB_refined_risk_state', 'modelB_input_set'});
    end

    P = vertcat(rows{:});
end

function y = percentile_local(x, pct)
    x = sort(x(~isnan(x)));
    if isempty(x)
        y = NaN;
        return;
    end
    idx = 1 + (numel(x) - 1) * pct / 100;
    lo = floor(idx);
    hi = ceil(idx);
    if lo == hi
        y = x(lo);
    else
        y = x(lo) + (idx - lo) * (x(hi) - x(lo));
    end
end

function y = clip01(x)
    y = min(max(x, 0), 1);
end

function policy = recommend_policy(modelA, reliability, uncertainty, directAlertEpisodes)
    if reliability < 0.45 || uncertainty > 0.60
        policy = "request_more_data";
    elseif modelA >= 0.60 && directAlertEpisodes > 0 && reliability >= 0.60
        policy = "clinician_review";
    elseif modelA >= 0.45 || uncertainty > 0.40
        policy = "request_confirmation";
    else
        policy = "routine_monitoring";
    end
end
