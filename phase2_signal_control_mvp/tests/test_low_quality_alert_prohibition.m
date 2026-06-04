T = readtable(fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv'));
P = phase_control_params();
qMin = P.qMinDirectAlert;
suspiciousLevel = 0.52;

idxLowQ = T.q < qMin;
assert(all(T.adaptive_alert(idxLowQ) == 0), ...
    'Direct alert must be prohibited under low signal quality.');

idxSuspiciousLowQ = idxLowQ & (T.x_hat > suspiciousLevel | T.risk_proxy > 0.62);
routeMask = T.request_confirmation == 1 | T.request_more_data == 1;
assert(all(routeMask(idxSuspiciousLowQ)), ...
    'All suspicious low-quality observations must be routed to confirmation or more data.');

idxInjectedLowQualityNonRisk = logical(T.true_low_quality) & ~logical(T.true_risk);
assert(all(~(T.adaptive_alert & idxInjectedLowQualityNonRisk)), ...
    'No direct false alert should occur in injected low-quality non-risk windows.');
