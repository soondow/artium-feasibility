clear; clc;

thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase2Root = fileparts(testDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));
addpath(testDir);

fprintf('\nRunning Phase 2 demo and Simulink testbench before tests...\n');
run(fullfile(phase2Root, 'scripts', 'run_phase2_demo.m'));

thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase2Root = fileparts(testDir);
repoRoot = fileparts(phase2Root);
addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));
addpath(testDir);

run(fullfile(phase2Root, 'scripts', 'build_simulink_testbench.m'));
run(fullfile(phase2Root, 'scripts', 'run_patient_level_monitoring_demo.m'));

thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase2Root = fileparts(testDir);
repoRoot = fileparts(phase2Root);
addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));
addpath(testDir);

fprintf('\nRunning Phase 2 safety and verification tests...\n');

testFiles = [
    "test_sqi_bounds"
    "test_observer_bounds"
    "test_low_quality_alert_prohibition"
    "test_policy_mask_consistency"
    "test_episode_metrics"
    "test_request_burden_metrics"
    "test_policy_switching"
    "test_threshold_bounds"
    "test_simulink_step_policy"
    "test_patient_level_temporal_architecture"
    "test_public_rri_import_template"
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
outPath = fullfile(phase2Root, 'outputs', 'tables', 'phase2_test_results.csv');
writetable(results, outPath);

if any(status == "FAIL")
    error('One or more Phase 2 tests failed. See %s', outPath);
end

fprintf('\nAll Phase 2 tests passed.\n');
fprintf('Saved test results: %s\n', outPath);
