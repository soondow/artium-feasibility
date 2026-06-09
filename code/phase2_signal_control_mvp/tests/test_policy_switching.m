% 테스트 설명:
%   정책 유지 시간과 불응 구간이 잦은 정책 전환을 억제하는지 검증합니다.
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

B = readtable(fullfile(phase2Root, 'outputs', 'tables', 'baseline_vs_proposed.csv'));
highRiskProposed = B(string(B.scenario) == "high_risk_irregular" ...
    & string(B.method) == "quality_aware_controller", :);

assert(height(highRiskProposed) == 1, 'Expected one high-risk proposed metrics row.');
assert(ismember("policy_transition_count", string(B.Properties.VariableNames)), ...
    'baseline_vs_proposed.csv must include policy_transition_count.');
assert(highRiskProposed.policy_transition_count <= 30, ...
    'Policy switching is too frequent in high-risk scenario.');
