thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase2Root = fileparts(testDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(repoRoot, 'config'));

outputPath = fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv');
assert(isfile(outputPath), 'window_metrics.csv not found. Run run_phase2_demo.m first.');

T = readtable(outputPath);
policy = string(T.policy);
P = phase_control_params();

idxAlertPolicy = policy == "alert";
idxMoreDataPolicy = policy == "request_more_data";
idxConfirmationPolicy = policy == "request_confirmation";
idxObservePolicy = policy == "observe";

assert(all(T.adaptive_alert(idxAlertPolicy) == 1), ...
    'policy=alert must imply adaptive_alert=1.');

assert(all(T.request_more_data(idxMoreDataPolicy) == 1), ...
    'policy=request_more_data must imply request_more_data=1.');

assert(all(T.request_confirmation(idxConfirmationPolicy) == 1), ...
    'policy=request_confirmation must imply request_confirmation=1.');

assert(all(T.adaptive_alert(idxObservePolicy) == 0 ...
        & T.request_more_data(idxObservePolicy) == 0 ...
        & T.request_confirmation(idxObservePolicy) == 0), ...
    'policy=observe must imply no action mask.');

idxLowQuality = T.q < P.qMinDirectAlert;
assert(all(~(idxLowQuality & idxAlertPolicy)), ...
    'Low-quality windows must not have policy=alert.');
