% 테스트 설명:
%   최종 정책 라벨이 직접 알림, 추가 데이터 요청, 확인 요청 마스크와 일관되는지 검증합니다.
%
% 입력:
%   테스트 내부에서 정의한 합성 데이터, 프로젝트 함수, 또는 기존 산출물을 사용합니다.
%
% 출력:
%   조건을 만족하면 조용히 종료하고, 실패하면 assert 또는 error 예외가 발생합니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase2Root = fileparts(testDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(repoRoot, 'config'));

outputPath = fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv');
assert(isfile(outputPath), 'window_metrics.csv not found. Run run_phase2_demo.m first.');

T = readtable(outputPath);
policy = string(T.policy);
P = phase_control_params();

idxAlertPolicy = policy == "alert";
idxMoreDataPolicy = policy == "request_more_data";
idxConfirmationPolicy = policy == "request_confirmation";
idxObservePolicy = policy == "observe";

assert(all(T.adaptive_alert(idxAlertPolicy) == 1), ...
    'policy=alert must imply adaptive_alert=1.');

assert(all(T.request_more_data(idxMoreDataPolicy) == 1), ...
    'policy=request_more_data must imply request_more_data=1.');

assert(all(T.request_confirmation(idxConfirmationPolicy) == 1), ...
    'policy=request_confirmation must imply request_confirmation=1.');

assert(all(T.adaptive_alert(idxObservePolicy) == 0 ...
        & T.request_more_data(idxObservePolicy) == 0 ...
        & T.request_confirmation(idxObservePolicy) == 0), ...
    'policy=observe must imply no action mask.');

idxLowQuality = T.q < P.qMinDirectAlert;
assert(all(~(idxLowQuality & idxAlertPolicy)), ...
    'Low-quality windows must not have policy=alert.');
