function M = compute_detection_metrics(alertMask, requestMask, trueRisk, q, ...
    windowMinutes, durationDays, mergeGapWindows, qMin, trueLowQuality, confirmationMask)
% 함수 설명:
%   윈도우 단위 액션 결과를 에피소드 단위 탐지 성능과 사용자 부담 지표로 요약합니다.
%
% 입력:
%   alertMask (논리형 벡터, 비어 있을 수 없음: 직접 알림 발생 여부입니다.)
%   requestMask (논리형 벡터, 비어 있을 수 없음: 추가 데이터 요청 발생 여부입니다.)
%   trueRisk (논리형 벡터, 비어 있을 수 없음: 실제 위험 에피소드 라벨입니다.)
%   q (수치형 벡터, 비어 있을 수 없음: 각 윈도우의 신호 품질 점수입니다.)
%   windowMinutes (수치형 스칼라, 비어 있을 수 있음: 윈도우 시간 간격입니다.)
%   durationDays (수치형 스칼라, 비어 있을 수 있음: 평가 기간 일수입니다.)
%   mergeGapWindows (수치형 스칼라, 비어 있을 수 있음: 같은 에피소드로 병합할 최대 빈 윈도우 수입니다.)
%   qMin (수치형 스칼라, 비어 있을 수 있음: 낮은 품질 직접 알림 판정 기준입니다.)
%   trueLowQuality (논리형 벡터, 비어 있을 수 있음: 실제 낮은 품질 구간 라벨입니다.)
%   confirmationMask (논리형 벡터, 비어 있을 수 있음: 확인 요청 발생 여부입니다.)
%
% 출력:
%   M (구조체: 알림 수, 에피소드 수, 거짓 알림률, 탐지 지연, 요청 부담, 낮은 품질 알림 비율을 담습니다.)
%
% 예외:
%   입력 벡터 길이가 서로 맞지 않으면 인덱싱 오류가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 직접 알림, 요청, 확인 요청, 전체 액션, 실제 위험 마스크를 에피소드로 변환합니다.
%   2. 실제 위험 에피소드 안에서 최초 직접 알림을 찾아 탐지 수와 지연 시간을 계산합니다.
%   3. 위험 라벨과 겹치지 않는 액션 에피소드를 거짓 부담으로 집계합니다.
%   4. 낮은 품질 구간에서 발생한 직접 알림 비율과 일 단위 요청 부담을 계산합니다.

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
            detectionLatencyWindows(end + 1, 1) = hit - 1;
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
% 함수 설명:
%   실제 위험 구간과 겹치지 않는 에피소드 개수를 계산합니다.
%
% 입력:
%   episodes (테이블 또는 수치형 행렬, 비어 있을 수 없음: 시작 및 종료 인덱스를 포함한 에피소드 목록입니다.)
%   trueRisk (논리형 벡터, 비어 있을 수 없음: 실제 위험 에피소드 라벨입니다.)
%
% 출력:
%   n (수치형 스칼라: 조건에 맞는 에피소드 개수입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    n = 0;
    for i = 1:height(episodes)
        idx = episodes.start_idx(i):episodes.stop_idx(i);
        if ~any(trueRisk(idx))
            n = n + 1;
        end
    end
end
