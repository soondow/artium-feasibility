% 테스트 설명:
%   적응 임계값이 설정된 최솟값과 최댓값 범위를 벗어나지 않는지 검증합니다.
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
tauMin = P.tauMin;
tauMax = P.tauMax;
maxDeltaTau = 0.15;

tau = T.adaptive_threshold;
assert(all(tau >= tauMin & tau <= tauMax), 'Adaptive threshold out of bounds');

deltaTau = abs(diff(tau));
assert(all(deltaTau <= maxDeltaTau + eps), 'Threshold changes too abruptly');
