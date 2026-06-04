function T = compare_risk_proxy_vs_mspc(windowMetrics, mspcRisk)
%COMPARE_RISK_PROXY_VS_MSPC Build side-by-side observation candidates.
%
% MSPC is compared as another observation stream, not as the final alert
% decision. The Phase 2 controller is still responsible for quality gates,
% confirmation routing, and false-alert burden control.

    riskProxy = windowMetrics.risk_proxy;
    % The hybrid stream is intentionally simple for baseline comparison; if it
    % increases false alerts, later work should calibrate MSPC before fusion.
    hybridRisk = max(riskProxy, mspcRisk);

    T = table(windowMetrics.scenario, windowMetrics.window_id, windowMetrics.day0_6, ...
        riskProxy, mspcRisk, hybridRisk, windowMetrics.q, windowMetrics.coverage, ...
        windowMetrics.true_risk, windowMetrics.true_low_quality, ...
        'VariableNames', {'scenario', 'window_id', 'day0_6', ...
        'risk_proxy', 'mspc_risk', 'hybrid_risk', 'q', 'coverage', ...
        'true_risk', 'true_low_quality'});
end
