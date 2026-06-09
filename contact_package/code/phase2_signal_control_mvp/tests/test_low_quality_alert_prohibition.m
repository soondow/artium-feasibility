% 테스트 설명:
%   낮은 품질 구간에서 직접 알림이 금지되고 요청 정책으로 라우팅되는지 검증합니다.
%
% 입력:
%   테스트 내부에서 정의한 합성 데이터, 프로젝트 함수, 또는 기존 산출물을 사용합니다.
%
% 출력:
%   조건을 만족하면 조용히 종료하고, 실패하면 assert 또는 error 예외가 발생합니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


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
