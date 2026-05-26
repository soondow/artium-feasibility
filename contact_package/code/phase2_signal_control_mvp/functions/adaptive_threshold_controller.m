function C = adaptive_threshold_controller(riskProxy, xHat, U, q, params, coverage)
%ADAPTIVE_THRESHOLD_CONTROLLER Compare raw fixed alerts with quality-aware alerts.
%
% The fixed baseline thresholds raw HRV risk directly. The proposed
% controller thresholds the observer state only when the signal is reliable.
% Suspicious but unreliable windows are routed to confirmation or additional
% data collection instead of becoming direct alerts.

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

    % Final policy synchronization: policy labels must always be derived
    % from final action masks, never only from intermediate candidates.
    policy = deriveFinalPolicy(adaptiveAlert, requestMoreData, requestConfirmation);

    C = table(fixedThreshold, adaptiveThreshold, fixedAlert, adaptiveAlert, ...
        requestMoreData, requestConfirmation, policy, ...
        'VariableNames', {'fixed_threshold', 'adaptive_threshold', 'fixed_alert', ...
        'adaptive_alert', 'request_more_data', 'request_confirmation', 'policy'});
end

function s = withDefault(s, name, value)
    if ~isfield(s, name) || isempty(s.(name))
        s.(name) = value;
    end
end

function policy = deriveFinalPolicy(adaptiveAlert, requestMoreData, requestConfirmation)
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
