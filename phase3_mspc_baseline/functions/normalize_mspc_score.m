function risk = normalize_mspc_score(mspcScore)
%NORMALIZE_MSPC_SCORE Map MSPC anomaly score to a bounded risk observation.
%
% mspcScore = 1 corresponds to the empirical 95% normal-operation limit.
% The bounded mapping keeps MSPC as an observation candidate, not a final
% decision. The Phase 2 controller still applies quality and safety gates.

    % Use a saturating map so extreme MSPC residuals cannot bypass the Phase 2
    % quality and uncertainty gates by producing an unbounded risk value.
    risk = 0.12 + 0.58 * (1 - exp(-0.75 * mspcScore));
    risk = min(max(risk, 0), 1);
end
