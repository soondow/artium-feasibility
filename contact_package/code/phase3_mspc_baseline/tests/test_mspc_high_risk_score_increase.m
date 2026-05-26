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
