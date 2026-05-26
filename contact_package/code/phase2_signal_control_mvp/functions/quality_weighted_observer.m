function O = quality_weighted_observer(riskProxy, q, coverage, params)
%QUALITY_WEIGHTED_OBSERVER signal quality가 낮을 때 state update를 완화한다.
%
% riskProxy는 HRV/irregularity feature에서 나온 observation stream이다.
% observer는 q*coverage를 measurement confidence gate로 사용한다.

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
    if ~isfield(s, name) || isempty(s.(name))
        s.(name) = value;
    end
end
