function P = build_patient_level_monitoring_summary(windowMetrics, eventMetrics)
% 함수 설명:
%   윈도우 지표와 이벤트 지표를 환자 단위 Model A/B 모니터링 요약 테이블로 변환합니다.
%
% 입력:
%   windowMetrics (테이블, 비어 있을 수 없음: 시나리오별 윈도우 품질, 위험 상태, 커버리지 지표입니다.)
%   eventMetrics (테이블, 비어 있을 수 없음: 시나리오별 제어기 액션 에피소드 요약입니다.)
%
% 출력:
%   P (테이블: 환자 단위 위험 상태, 모니터링 신뢰도, 정책 추천, Model B 보정 프록시를 담습니다.)
%
% 예외:
%   필수 시나리오 행이 없거나 테이블 필드가 맞지 않으면 error 또는 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 합성 시나리오를 환자형 모니터링 기록으로 간주해 시나리오별 윈도우를 모읍니다.
%   2. 유효 관찰 시간, 액션 부담, 환자 단위 불확실성, 직접 알림 수를 계산합니다.
%   3. Model A는 day-90/ERAF 정보를 쓰지 않고 초기 위험 상태와 모니터링 신뢰도를 산출합니다.
%   4. Model B 보정 프록시는 ERAF_0_90_proxy와 모니터링 강도를 별도 필드로 보존합니다.
%   5. Model A 출력과 신뢰도에 따라 모니터링 정책을 추천합니다.

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
% 함수 설명:
%   입력 벡터에서 지정한 백분위수 값을 선형 보간으로 계산합니다.
%
% 입력:
%   x (수치형 벡터, 비어 있을 수 있음: 백분위수를 계산할 값입니다.)
%   pct (수치형 스칼라, 비어 있을 수 없음: 0에서 100 사이의 백분위수입니다.)
%
% 출력:
%   y (수치형 스칼라: 계산된 백분위수 값이며, 유효 값이 없으면 NaN입니다.)
%
% 예외:
%   pct가 수치 연산에 부적합하면 MATLAB 기본 예외가 발생할 수 있습니다.
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
% 함수 설명:
%   입력값을 0 이상 1 이하 범위로 제한합니다.
%
% 입력:
%   x (수치형 배열 또는 스칼라, 비어 있을 수 있음: 제한할 값입니다.)
%
% 출력:
%   y (수치형 배열 또는 스칼라: 0과 1 사이로 제한된 값입니다.)
%
% 예외:
%   입력이 수치 비교를 지원하지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    y = min(max(x, 0), 1);
end

function policy = recommend_policy(modelA, reliability, uncertainty, directAlertEpisodes)
% 함수 설명:
%   Model A 위험 상태, 모니터링 신뢰도, 불확실성, 직접 알림 수로 권장 정책을 선택합니다.
%
% 입력:
%   modelA (수치형 스칼라, 비어 있을 수 없음: 초기 위험 상태 점수입니다.)
%   reliability (수치형 스칼라, 비어 있을 수 없음: 모니터링 신뢰도입니다.)
%   uncertainty (수치형 스칼라, 비어 있을 수 없음: 환자 단위 불확실성입니다.)
%   directAlertEpisodes (수치형 스칼라, 비어 있을 수 없음: 직접 알림 에피소드 수입니다.)
%
% 출력:
%   policy (문자열 스칼라: 추가 데이터 요청, 임상 검토, 확인 요청, 루틴 모니터링 중 하나입니다.)
%
% 예외:
%   입력이 수치 비교를 지원하지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
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
