function O = quality_weighted_observer(riskProxy, q, coverage, params)
% 함수 설명:
%   위험 관측값을 신호 품질과 커버리지로 가중해 위험 상태와 불확실성을 추정합니다.
%
% 입력:
%   riskProxy (수치형 벡터, 비어 있을 수 없음: HRV 특징 또는 MSPC에서 계산한 위험 관측값입니다.)
%   q (수치형 벡터, 비어 있을 수 없음: 각 윈도우의 신호 품질 점수입니다.)
%   coverage (수치형 벡터, 비어 있을 수 있음: 각 윈도우의 유효 샘플 커버리지입니다.)
%   params (구조체, 비어 있을 수 있음: 임계값, 관찰자 이득, 불응 구간 등 선택 설정입니다. 비어 있으면 기본값을 사용합니다.)
%
% 출력:
%   O (테이블: x_hat, U, observer_gain, observer_residual 컬럼을 가진 관찰자 결과입니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
%
% 처리 절차:
%   1. 누락된 설정값을 기본값으로 보완하고 입력을 열 벡터로 정규화합니다.
%   2. 품질과 커버리지를 곱해 관측 신뢰도를 계산하고 관찰자 이득을 제한합니다.
%   3. 이전 상태에서 표류가 적용된 예측값을 만들고 현재 관측으로 보정합니다.
%   4. 낮은 신뢰도와 큰 잔차는 불확실성을 높이고 높은 관찰자 이득은 불확실성을 낮춥니다.

    if nargin < 4 || isempty(params)
        params = struct();
    end

    params = withDefault(params, 'alpha', 0.58);
    params = withDefault(params, 'drift', 0.94);
    params = withDefault(params, 'baselineRisk', 0.18);
    params = withDefault(params, 'processNoise', 0.025);
    params = withDefault(params, 'lowQualityGain', 0.34);
    params = withDefault(params, 'residualGain', 0.12);
    params = withDefault(params, 'uncertaintyPersistence', 0.72);

    riskProxy = riskProxy(:);
    q = q(:);
    coverage = coverage(:);
    n = numel(riskProxy);

    xHat = nan(n, 1);
    U = nan(n, 1);
    gain = nan(n, 1);
    residual = nan(n, 1);

    xPrev = params.baselineRisk;
    uPrev = 0.45;

    for k = 1:n
        obs = riskProxy(k);
        if isnan(obs)
            obs = xPrev;
        end

        confidence = min(max(q(k) * coverage(k), 0), 1);
        gain(k) = params.alpha * confidence;

        xPred = params.drift * xPrev + (1 - params.drift) * params.baselineRisk;
        residual(k) = abs(obs - xPred);
        xHat(k) = xPred + gain(k) * (obs - xPred);
        xHat(k) = min(max(xHat(k), 0), 1);

        U(k) = params.uncertaintyPersistence * uPrev ...
            + params.processNoise ...
            + params.lowQualityGain * (1 - confidence) ...
            + params.residualGain * residual(k) ...
            - 0.10 * gain(k);
        U(k) = min(max(U(k), 0.03), 1);

        xPrev = xHat(k);
        uPrev = U(k);
    end

    O = table(xHat, U, gain, residual, ...
        'VariableNames', {'x_hat', 'U', 'observer_gain', 'observer_residual'});
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
