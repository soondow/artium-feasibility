% 테스트 설명:
%   Simulink step 테스트벤치 로그에서 낮은 품질 고위험 구간이 직접 알림으로 처리되지 않는지 검증합니다.
%
% 입력:
%   테스트 내부에서 정의한 합성 데이터, 프로젝트 함수, 또는 기존 산출물을 사용합니다.
%
% 출력:
%   조건을 만족하면 조용히 종료하고, 실패하면 assert 또는 error 예외가 발생합니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


T = readtable(fullfile(phase2Root, 'outputs', 'simulink', 'simulink_step_testbench_log.csv'));

qMin = 0.88;
suspiciousLevel = 0.62;
idx = T.q < qMin & T.risk_proxy > suspiciousLevel;

assert(any(idx), 'Simulink testbench should contain suspicious low-quality input.');
assert(all(T.direct_alert(idx) == 0), ...
    'Simulink testbench violated low-quality direct-alert prohibition.');
assert(any(T.request_confirmation(idx) == 1), ...
    'Simulink testbench should request confirmation under suspicious low-quality input.');
