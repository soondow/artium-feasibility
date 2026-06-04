function params = phase_control_params()
%PHASE_CONTROL_PARAMS Shared Phase 2/3 observer-controller constants.
%
% These defaults are used for synthetic stress-test reproducibility. They
% are engineering feasibility parameters, not calibrated clinical limits.

    params.qMinDirectAlert = 0.88;
    params.cMinDirectAlert = 0.80;
    params.uMaxDirectAlert = 0.44;

    % Direct alerts require quality, coverage, and uncertainty gates.
    % These are safety constraints for routing weak evidence to confirmation.
    params.fixedThreshold = 0.62;
    params.baseObserverGain = 0.58;
    params.tauBase = 0.52;
    params.tauMin = 0.42;
    params.tauMax = 0.92;

    % Refractory and dwell windows limit repeated actions from overlapping
    % windows, so reported burden better matches user-facing episodes.
    params.refractoryWindows = 24;
    params.requestRefractoryWindows = 6;
    params.confirmationRefractoryWindows = 6;
    params.policyDwellWindows = 6;
    params.burdenWindow = 18;

    params.mergeGapWindows = 12;
    params.defaultWindowMinutes = 0.5;
    params.alertMargin = 0.08;
end
