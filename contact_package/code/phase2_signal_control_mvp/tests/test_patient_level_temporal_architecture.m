% 테스트 설명:
%   환자 단위 요약 테이블이 Model A/B 시간 구조와 필수 출력 범위를 만족하는지 검증합니다.
%
% 입력:
%   patient_level_monitoring_summary.csv 파일을 사용합니다.
%
% 출력:
%   assert 기반 검증 결과를 테스트 러너에 전달합니다.
%
% 예외:
%   필수 파일, 필수 열, 값 범위, 시간 정보 분리 조건을 만족하지 않으면 assert 예외가 발생합니다.


phase2Root = fileparts(fileparts(mfilename('fullpath')));
tablePath = fullfile(phase2Root, 'outputs', 'tables', 'patient_level_monitoring_summary.csv');
assert(isfile(tablePath), 'patient_level_monitoring_summary.csv must exist.');

P = readtable(tablePath);
requiredColumns = ["patient_id", "scenario", "b_0_56", "U_patient", ...
    "A_patient", "coverage_summary", "modelA_early_risk_state", ...
    "modelA_monitoring_reliability", "suggested_monitoring_policy", ...
    "modelA_input_set", "ERAF_0_90_proxy", "modelB_refined_risk_state"];
assert(all(ismember(requiredColumns, string(P.Properties.VariableNames))), ...
    'Patient-level summary is missing required Model A/B columns.');

assert(all(P.b_0_56 >= 0), 'b_0_56 must be nonnegative.');
assert(all(P.U_patient >= 0 & P.U_patient <= 1), 'U_patient must be bounded in [0, 1].');
assert(all(P.coverage_summary >= 0 & P.coverage_summary <= 1), ...
    'coverage_summary must be bounded in [0, 1].');
assert(all(P.modelA_early_risk_state >= 0 & P.modelA_early_risk_state <= 1), ...
    'Model A risk-state output must be bounded in [0, 1].');
assert(all(P.modelB_refined_risk_state >= 0 & P.modelB_refined_risk_state <= 1), ...
    'Model B risk-state output must be bounded in [0, 1].');

inputSet = string(P.modelA_input_set);
assert(~any(contains(inputSet, "ERAF", 'IgnoreCase', true)), ...
    'Model A input set must not include ERAF/day-90 information.');
assert(~any(contains(inputSet, "day90", 'IgnoreCase', true)), ...
    'Model A input set must not include day-90 information.');

normal = P(string(P.scenario) == "normal", :);
lowq = P(string(P.scenario) == "low_quality_artifact", :);
assert(height(normal) == 1 && height(lowq) == 1, ...
    'Expected normal and low_quality_artifact rows.');
assert(lowq.modelA_monitoring_reliability < normal.modelA_monitoring_reliability, ...
    'Low-quality artifact should reduce Model A monitoring reliability.');
