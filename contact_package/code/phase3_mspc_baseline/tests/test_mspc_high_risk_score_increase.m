% 테스트 설명:
%   고위험 불규칙 구간에서 MSPC 점수가 정상 기준보다 증가하는지 검증합니다.
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

S = readtable(fullfile(phase3Root, 'outputs', 'mspc_scores.csv'));
normalMask = string(S.scenario) == "normal" & S.q >= 0.90 & S.coverage >= 0.95 ...
    & ~logical(S.true_risk);
highRiskMask = string(S.scenario) == "high_risk_irregular" & logical(S.true_risk);

assert(any(normalMask), 'No high-quality normal MSPC windows found.');
assert(any(highRiskMask), 'No high-risk MSPC windows found.');
assert(mean(S.mspc_risk(highRiskMask), 'omitnan') > mean(S.mspc_risk(normalMask), 'omitnan'), ...
    'MSPC risk observation should increase during the high-risk synthetic segment.');
