function C = adaptive_threshold_controller(riskProxy, xHat, U, q, params, coverage)
% 함수 설명:
%   위험 관측값, 관찰자 상태, 불확실성, 신호 품질을 결합해 고정 알림과 적응형 정책을 계산합니다.
%
% 입력:
%   riskProxy (수치형 벡터, 비어 있을 수 없음: HRV 특징 또는 MSPC에서 계산한 위험 관측값입니다.)
%   xHat (수치형 벡터, 비어 있을 수 없음: 품질 가중 관찰자가 추정한 위험 상태입니다.)
%   U (수치형 벡터, 비어 있을 수 없음: 관찰자 불확실성입니다.)
%   q (수치형 벡터, 비어 있을 수 없음: 각 윈도우의 신호 품질 점수입니다.)
%   params (구조체, 비어 있을 수 있음: 임계값, 관찰자 이득, 불응 구간 등 선택 설정입니다. 비어 있으면 기본값을 사용합니다.)
%   coverage (수치형 벡터, 비어 있을 수 있음: 각 윈도우의 유효 샘플 커버리지입니다.)
%
% 출력:
%   C (테이블: 고정 임계값, 적응 임계값, 알림 마스크, 요청 마스크, 최종 정책 라벨을 담습니다.)
%
% 예외:
%   입력 벡터 길이가 서로 맞지 않으면 인덱싱 또는 테이블 생성 오류가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 누락된 설정값을 기본 파라미터로 보완하고 입력을 열 벡터로 정규화합니다.
%   2. 최근 알림 부담, 불확실성, 낮은 품질 패널티를 반영해 적응 임계값을 계산합니다.
%   3. 신뢰 가능한 관측만 직접 알림 후보로 허용하고 약한 근거는 요청 정책으로 분기합니다.
%   4. 불응 구간과 정책 유지 조건으로 반복 알림과 정책 흔들림을 줄입니다.
%   5. 최종 액션 마스크에서 정책 라벨을 다시 생성해 로그와 지표의 의미를 일치시킵니다.

    if nargin < 5 || isempty(params)
        params = struct();
    end

    if nargin < 6 || isempty(coverage)
        coverage = ones(size(q(:)));
    end

    params = withDefault(params, 'fixedThreshold', 0.62);
    params = withDefault(params, 'baseThreshold', 0.52);
    params = withDefault(params, 'uncertaintyGain', 0.28);
    params = withDefault(params, 'lowQualityGain', 0.18);
    params = withDefault(params, 'burdenGain', 0.10);
    params = withDefault(params, 'minQualityForAlert', 0.88);
    params = withDefault(params, 'minCoverageForAlert', 0.80);
    params = withDefault(params, 'maxUncertaintyForAlert', 0.44);
    params = withDefault(params, 'requestQuality', 0.72);
    params = withDefault(params, 'requestCoverage', 0.70);
    params = withDefault(params, 'confirmationQuality', 0.88);
    params = withDefault(params, 'confirmationCoverage', 0.85);
    params = withDefault(params, 'requestUncertainty', 0.66);
    params = withDefault(params, 'confirmationUncertainty', 0.44);
    params = withDefault(params, 'alertMargin', 0.08);
    params = withDefault(params, 'refractoryWindows', 6);
    params = withDefault(params, 'requestRefractoryWindows', 6);
    params = withDefault(params, 'confirmationRefractoryWindows', 6);
    params = withDefault(params, 'policyDwellWindows', 6);
    params = withDefault(params, 'burdenWindow', 18);
    params = withDefault(params, 'tauMin', 0.42);
    params = withDefault(params, 'tauMax', 0.92);

    riskProxy = riskProxy(:);
    xHat = xHat(:);
    U = U(:);
    q = q(:);
    coverage = coverage(:);
    n = numel(xHat);

    fixedThreshold = repmat(params.fixedThreshold, n, 1);
    adaptiveThreshold = nan(n, 1);
    fixedAlert = false(n, 1);
    adaptiveAlert = false(n, 1);
    requestMoreData = false(n, 1);
    requestConfirmation = false(n, 1);
    policy = strings(n, 1);

    lastAdaptiveAlert = -inf;
    lastRequestStart = -inf;
    lastConfirmationStart = -inf;
    lastPolicyChange = -inf;
    lastPolicy = "observe";

    for k = 1:n
        raw = riskProxy(k);
        if isnan(raw)
            raw = 0;
        end

        fixedAlert(k) = raw >= fixedThreshold(k);

        burdenFirst = max(1, k - params.burdenWindow);
        recentBurden = mean(adaptiveAlert(burdenFirst:k));

        adaptiveThreshold(k) = params.baseThreshold ...
            + params.uncertaintyGain * U(k) ...
            + params.lowQualityGain * (1 - q(k)) ...
            + params.burdenGain * recentBurden;
        adaptiveThreshold(k) = min(max(adaptiveThreshold(k), params.tauMin), params.tauMax);

        suspicious = raw >= params.fixedThreshold || xHat(k) >= params.baseThreshold;
        reliableForAlert = q(k) >= params.minQualityForAlert ...
            && coverage(k) >= params.minCoverageForAlert ...
            && U(k) <= params.maxUncertaintyForAlert;

        requestMoreData(k) = suspicious && (q(k) < params.requestQuality ...
            || coverage(k) < params.requestCoverage ...
            || U(k) > params.requestUncertainty);
        requestConfirmation(k) = suspicious && ~requestMoreData(k) ...
            && (q(k) < params.confirmationQuality ...
            || coverage(k) < params.confirmationCoverage ...
            || U(k) > params.confirmationUncertainty);

        candidate = xHat(k) >= adaptiveThreshold(k) + params.alertMargin && reliableForAlert ...
            && ~requestMoreData(k) && ~requestConfirmation(k);
        alertReady = (k - lastAdaptiveAlert) > params.refractoryWindows;
        if candidate && alertReady
            adaptiveAlert(k) = true;
            lastAdaptiveAlert = k;
        elseif candidate && ~alertReady
            requestConfirmation(k) = true;
        end

        candidatePolicy = "observe";
        if adaptiveAlert(k)
            candidatePolicy = "alert";
        elseif requestMoreData(k)
            candidatePolicy = "request_more_data";
        elseif requestConfirmation(k)
            candidatePolicy = "request_confirmation";
        end

        if candidatePolicy == "request_more_data" && lastPolicy ~= "request_more_data" ...
                && lastPolicy ~= "observe" ...
                && lastPolicy ~= "alert" ...
                && (k - lastRequestStart) <= params.requestRefractoryWindows
            candidatePolicy = lastPolicy;
        elseif candidatePolicy == "request_confirmation" && lastPolicy ~= "request_confirmation" ...
                && lastPolicy ~= "observe" ...
                && lastPolicy ~= "alert" ...
                && (k - lastConfirmationStart) <= params.confirmationRefractoryWindows
            candidatePolicy = lastPolicy;
        elseif candidatePolicy ~= "observe" && lastPolicy ~= "observe" ...
                && candidatePolicy ~= "alert" && lastPolicy ~= "alert" ...
                && candidatePolicy ~= lastPolicy ...
                && (k - lastPolicyChange) < params.policyDwellWindows
            candidatePolicy = lastPolicy;
        elseif candidatePolicy == "observe" && suspicious ...
                && (lastPolicy == "request_more_data" || lastPolicy == "request_confirmation") ...
                && (k - lastPolicyChange) < params.policyDwellWindows
            candidatePolicy = lastPolicy;
        end

        if candidatePolicy == "request_more_data"
            requestMoreData(k) = true;
            requestConfirmation(k) = false;
            if lastPolicy ~= "request_more_data"
                lastRequestStart = k;
            end
        elseif candidatePolicy == "request_confirmation"
            requestMoreData(k) = false;
            requestConfirmation(k) = true;
            if lastPolicy ~= "request_confirmation"
                lastConfirmationStart = k;
            end
        elseif candidatePolicy == "observe"
            requestMoreData(k) = false;
            requestConfirmation(k) = false;
        end

        if candidatePolicy ~= lastPolicy
            lastPolicyChange = k;
            lastPolicy = candidatePolicy;
        end

        policy(k) = candidatePolicy;
    end

    policy = deriveFinalPolicy(adaptiveAlert, requestMoreData, requestConfirmation);

    C = table(fixedThreshold, adaptiveThreshold, fixedAlert, adaptiveAlert, ...
        requestMoreData, requestConfirmation, policy, ...
        'VariableNames', {'fixed_threshold', 'adaptive_threshold', 'fixed_alert', ...
        'adaptive_alert', 'request_more_data', 'request_confirmation', 'policy'});
end

function s = withDefault(s, name, value)
% 함수 설명:
%   구조체 필드가 없거나 비어 있을 때 지정한 기본값을 채웁니다.
%
% 입력:
%   s (구조체, 비어 있을 수 없음: 기본값을 적용할 설정 구조체입니다.)
%   name (문자열, 비어 있을 수 없음: 확인할 필드명입니다.)
%   value (임의 값, 비어 있을 수 있음: 필드가 없거나 비어 있을 때 대입할 기본값입니다.)
%
% 출력:
%   s (구조체: 기본값이 보완된 설정 구조체입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    if ~isfield(s, name) || isempty(s.(name))
        s.(name) = value;
    end
end

function policy = deriveFinalPolicy(adaptiveAlert, requestMoreData, requestConfirmation)
% 함수 설명:
%   최종 액션 마스크의 우선순위에 따라 정책 라벨을 재구성합니다.
%
% 입력:
%   adaptiveAlert (논리형 벡터, 비어 있을 수 없음: 직접 알림 마스크입니다.)
%   requestMoreData (논리형 벡터, 비어 있을 수 없음: 추가 데이터 요청 마스크입니다.)
%   requestConfirmation (논리형 벡터, 비어 있을 수 없음: 확인 요청 마스크입니다.)
%
% 출력:
%   policy (문자열 배열: 액션 마스크 우선순위로 결정한 최종 정책 라벨입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    n = numel(adaptiveAlert);
    policy = strings(n, 1);

    for k = 1:n
        if adaptiveAlert(k)
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
