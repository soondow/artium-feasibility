function params = phase_control_params()
% 함수 설명:
%   Phase 2와 Phase 3에서 공유하는 관찰자-제어기 기본 파라미터를 구성합니다.
%
% 입력:
%   없음.
%
% 출력:
%   params (구조체: 직접 알림 허용 조건, 적응 임계값, 불응 구간, 정책 유지 시간, 윈도우 병합 기준을 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

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
