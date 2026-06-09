% 테스트 설명:
%   품질 가중 관찰자의 상태, 불확실성, gain이 허용 범위 안에 머무르는지 검증합니다.
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

assert(all(T.x_hat >= 0 & T.x_hat <= 1), 'x_hat must be bounded in [0, 1]');
assert(all(T.U >= 0 & T.U <= 1), 'U must be bounded in [0, 1]');

O = quality_weighted_observer([0.8; 0.8], [1.0; 0.2], [1.0; 1.0], []);
assert(O.observer_gain(2) < O.observer_gain(1), ...
    'Observer gain must decrease under low signal quality.');
