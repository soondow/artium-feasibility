function M = compute_detection_metrics(alertMask, requestMask, trueRisk, q, ...
    windowMinutes, durationDays, mergeGapWindows, qMin, trueLowQuality, confirmationMask)
%COMPUTE_DETECTION_METRICS episode 단위 모니터링 부담을 요약한다.
%
% 투명성을 위해 window 단위 count도 보존하지만, false alarm 부담은
% overlapping window가 같은 event에서 반복 발화할 때 rate가 부풀려지지 않도록
% 연속 alert episode 단위로 보고한다.
%
% alertMask는 direct alert이고 requestMask는 request_more_data이다. 선택 입력인
% confirmationMask는 request_confirmation이다.

    if nargin < 5 || isempty(windowMinutes)
        windowMinutes = 0.5;
    end

    if nargin < 6 || isempty(durationDays)
        durationDays = [];
    end

    if nargin < 7 || isempty(mergeGapWindows)
        mergeGapWindows = 12;
    end

    if nargin < 8 || isempty(qMin)
        qMin = 0.88;
    end

    if nargin < 9 || isempty(trueLowQuality)
        trueLowQuality = false(size(alertMask(:)));
    end

    if nargin < 10 || isempty(confirmationMask)
        confirmationMask = false(size(alertMask(:)));
    end

    alertMask = logical(alertMask(:));
    requestMask = logical(requestMask(:));
    trueRisk = logical(trueRisk(:));
    q = q(:);
    trueLowQuality = logical(trueLowQuality(:));
    confirmationMask = logical(confirmationMask(:));

    if isempty(durationDays)
        durationDays = max(numel(alertMask) * windowMinutes / (60 * 24), eps);
    else
        durationDays = max(durationDays, eps);
    end

    alertEpisodes = extract_binary_episodes(alertMask, mergeGapWindows);
    requestEpisodes = extract_binary_episodes(requestMask, mergeGapWindows);
    confirmationEpisodes = extract_binary_episodes(confirmationMask, mergeGapWindows);
    actionMask = alertMask | requestMask | confirmationMask;
    actionEpisodes = extract_binary_episodes(actionMask, mergeGapWindows);
    riskEpisodes = extract_binary_episodes(trueRisk, 0);

    detectionLatencyMin = NaN;
    detectionLatencyWindows = [];
    detectedEpisodes = 0;

    for i = 1:height(riskEpisodes)
        startIdx = riskEpisodes.start_idx(i);
        stopIdx = riskEpisodes.stop_idx(i);
        hit = find(alertMask(startIdx:stopIdx), 1, 'first');
        if ~isempty(hit)
            detectedEpisodes = detectedEpisodes + 1;
            detectionLatencyWindows(end + 1, 1) = hit - 1; %#ok<AGROW>
            if isnan(detectionLatencyMin)
                detectionLatencyMin = (hit - 1) * windowMinutes;
            end
        end
    end

    lowQualityAlertEpisodeCount = 0;

    for i = 1:height(alertEpisodes)
        idx = alertEpisodes.start_idx(i):alertEpisodes.stop_idx(i);
        lowQualityByQ = mean(q(idx), 'omitnan') < qMin;
        lowQualityByLabel = any(trueLowQuality(idx));
        if lowQualityByQ || lowQualityByLabel
            lowQualityAlertEpisodeCount = lowQualityAlertEpisodeCount + 1;
        end
    end

    alertEpisodeCount = height(alertEpisodes);
    falseDirectAlertEpisodeCount = countFalseEpisodes(alertEpisodes, trueRisk);
    falseRequestEpisodeCount = countFalseEpisodes(requestEpisodes, trueRisk);
    falseConfirmationEpisodeCount = countFalseEpisodes(confirmationEpisodes, trueRisk);
    falseActionEpisodeCount = countFalseEpisodes(actionEpisodes, trueRisk);

    if alertEpisodeCount > 0
        lowQualityAlertRatio = lowQualityAlertEpisodeCount / alertEpisodeCount;
    else
        lowQualityAlertRatio = 0;
    end

    M = struct();
    M.window_alert_count = nnz(alertMask);
    M.alert_episode_count = alertEpisodeCount;
    M.false_alarm_window_count = nnz(alertMask & ~trueRisk);
    M.false_alarm_episode_count = falseDirectAlertEpisodeCount;
    M.false_alarm_episodes_per_day = falseDirectAlertEpisodeCount / durationDays;
    M.false_alert_episode_count = falseDirectAlertEpisodeCount;
    M.false_direct_alert_episode_count = falseDirectAlertEpisodeCount;
    M.direct_alert_episode_count = alertEpisodeCount;
    M.detected_risk_episodes = detectedEpisodes;
    M.detected_risk_episode_count = detectedEpisodes;
    M.total_risk_episodes = height(riskEpisodes);
    M.missed_risk_episode_count = height(riskEpisodes) - detectedEpisodes;
    M.detection_latency_min = detectionLatencyMin;
    M.mean_detection_latency_windows = mean(detectionLatencyWindows, 'omitnan');
    M.low_quality_alert_episode_ratio = lowQualityAlertRatio;
    M.low_quality_alert_episode_count = lowQualityAlertEpisodeCount;
    M.request_episode_count = height(requestEpisodes);
    M.false_request_episode_count = falseRequestEpisodeCount;
    M.nonrisk_request_episode_count = falseRequestEpisodeCount;
    M.confirmation_episode_count = height(confirmationEpisodes);
    M.false_confirmation_episode_count = falseConfirmationEpisodeCount;
    M.nonrisk_confirmation_episode_count = falseConfirmationEpisodeCount;
    M.action_episode_count = height(actionEpisodes);
    M.false_action_episode_count = falseActionEpisodeCount;
    M.nonrisk_action_episode_count = falseActionEpisodeCount;
    M.action_episodes_per_day = height(actionEpisodes) / durationDays;
    M.request_windows_per_day = nnz(requestMask) / durationDays;
    M.confirmation_windows_per_day = nnz(confirmationMask) / durationDays;
    M.monitoring_request_windows = nnz(requestMask | confirmationMask);
    M.monitoring_request_episodes = height(extract_binary_episodes(requestMask | confirmationMask, mergeGapWindows));
end

function n = countFalseEpisodes(episodes, trueRisk)
    n = 0;
    for i = 1:height(episodes)
        idx = episodes.start_idx(i):episodes.stop_idx(i);
        if ~any(trueRisk(idx))
            n = n + 1;
        end
    end
end
