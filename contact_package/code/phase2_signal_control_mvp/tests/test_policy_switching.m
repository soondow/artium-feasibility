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
