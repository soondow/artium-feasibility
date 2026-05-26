thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase3Root = fileparts(testDir);

S = readtable(fullfile(phase3Root, 'outputs', 'mspc_scores.csv'));
normalMask = string(S.scenario) == "normal" & S.q >= 0.90 & S.coverage >= 0.95 ...
    & ~logical(S.true_risk);

assert(any(normalMask), 'No high-quality normal MSPC windows found.');
assert(median(S.mspc_score(normalMask), 'omitnan') < 1.0, ...
    'Normal high-quality MSPC median should remain below the NOC limit.');
