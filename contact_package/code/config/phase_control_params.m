function params = phase_control_params()
%PHASE_CONTROL_PARAMS Phase 2/3 관찰자-제어기 공통 상수.
%
% 이 기본값은 합성 스트레스 테스트 재현성을 위해 사용한다. 이 값들은
% 보정된 임상 한계가 아니라 공학적 타당성 확인용 파라미터이다.

    params.qMinDirectAlert = 0.88;
    params.cMinDirectAlert = 0.80;
    params.uMaxDirectAlert = 0.44;

    params.fixedThreshold = 0.62;
    params.baseObserverGain = 0.58;
    params.tauBase = 0.52;
    params.tauMin = 0.42;
    params.tauMax = 0.92;

    params.refractoryWindows = 24;
    params.requestRefractoryWindows = 6;
    params.confirmationRefractoryWindows = 6;
    params.policyDwellWindows = 6;
    params.burdenWindow = 18;

    params.mergeGapWindows = 12;
    params.defaultWindowMinutes = 0.5;
    params.alertMargin = 0.08;
end
