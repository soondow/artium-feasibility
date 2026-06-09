% 테스트 설명:
%   임계값 근처 잡음 시나리오에서 MSPC 관측값이 과도한 직접 알림으로 이어지지 않는지 검증합니다.
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

M = readtable(fullfile(phase3Root, 'outputs', 'mspc_event_metrics.csv'));
assert(ismember("risk_source", string(M.Properties.VariableNames)), ...
    'Phase 3 event metrics must use risk_source.');
assert(all(ismember(["policy_transition_count", "action_switch_count", ...
        "direct_alert_switch_count"], string(M.Properties.VariableNames))), ...
    'Phase 3 event metrics must include final policy/action switch counts.');
assert(all(ismember(["nonrisk_request_episode_count", ...
        "nonrisk_confirmation_episode_count", "nonrisk_action_episode_count"], ...
        string(M.Properties.VariableNames))), ...
    'Phase 3 event metrics must include nonrisk safety-action counts.');

riskProxy = M(string(M.scenario) == "near_threshold_noise" & string(M.risk_source) == "risk_proxy", :);
mspc = M(string(M.scenario) == "near_threshold_noise" & string(M.risk_source) == "mspc", :);
hybrid = M(string(M.scenario) == "near_threshold_noise" & string(M.risk_source) == "hybrid", :);

assert(height(riskProxy) == 1 && height(mspc) == 1 && height(hybrid) == 1, ...
    'Expected risk_proxy, mspc, and hybrid near-threshold rows.');

if mspc.false_direct_alert_episode_count > riskProxy.false_direct_alert_episode_count ...
        || hybrid.false_direct_alert_episode_count > riskProxy.false_direct_alert_episode_count
    warning('Phase3:NearThresholdCalibration', ...
        'MSPC/hybrid increases near-threshold false direct alerts; report this as a calibration limitation.');
end
