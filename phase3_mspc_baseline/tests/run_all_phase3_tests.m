clear; clc;

thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase3Root = fileparts(testDir);
repoRoot = fileparts(phase3Root);
phase2Root = fullfile(repoRoot, 'phase2_signal_control_mvp');

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(phase3Root, 'functions'));
addpath(testDir);

fprintf('\nRunning Phase 3 MSPC demo before tests...\n');
run(fullfile(phase3Root, 'scripts', 'run_phase3_mspc_demo.m'));

thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase3Root = fileparts(testDir);
repoRoot = fileparts(phase3Root);
phase2Root = fullfile(repoRoot, 'phase2_signal_control_mvp');

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(phase3Root, 'functions'));
addpath(testDir);

fprintf('\nRunning Phase 3 verification tests...\n');

testFiles = [
    "test_mspc_normal_score_low"
    "test_mspc_high_risk_score_increase"
    "test_mspc_near_threshold_warning"
    "test_mspc_duration_uses_real_time"
];

testName = strings(numel(testFiles), 1);
status = strings(numel(testFiles), 1);
message = strings(numel(testFiles), 1);

for k = 1:numel(testFiles)
    testName(k) = testFiles(k);
    try
        run(fullfile(testDir, testFiles(k) + ".m"));
        status(k) = "PASS";
        message(k) = "";
        fprintf('PASS %s\n', testFiles(k));
    catch ME
        status(k) = "FAIL";
        message(k) = string(ME.message);
        fprintf('FAIL %s: %s\n', testFiles(k), ME.message);
    end
end

results = table(testName, status, message);
outPath = fullfile(phase3Root, 'outputs', 'phase3_test_results.csv');
writetable(results, outPath);

if any(status == "FAIL")
    error('One or more Phase 3 tests failed. See %s', outPath);
end

fprintf('\nAll Phase 3 tests passed.\n');
fprintf('Saved test results: %s\n', outPath);
