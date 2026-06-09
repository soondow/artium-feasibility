% 테스트 설명:
%   MSPC 평가 지표가 실제 시간 길이를 사용해 일 단위 부담을 계산하는지 검증합니다.
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
phase3Root = fileparts(testDir);
scriptPath = fullfile(phase3Root, 'scripts', 'run_phase3_mspc_demo.m');
txt = fileread(scriptPath);

assert(~contains(txt, 'max(Ws.day0_6) - min(Ws.day0_6)'), ...
    'Phase 3 durationDays must not use the normalized day0_6 plotting axis.');
assert(contains(txt, 'max(Ws.stop_sec) - min(Ws.start_sec)'), ...
    'Phase 3 durationDays must use real start_sec/stop_sec duration.');
