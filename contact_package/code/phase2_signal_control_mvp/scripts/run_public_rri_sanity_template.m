clear; clc;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
phase2Root = fileparts(scriptDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));

csvPath = getenv('PUBLIC_RRI_CSV');
if isempty(csvPath)
    warning(['Set PUBLIC_RRI_CSV to a local ECG/PPG-derived RRI CSV path before running this template. ', ...
        'Expected columns include rri_ms, ibi_ms, rr_ms, rr_interval_ms, nn_ms, or interval_ms.']);
    return;
end

S = import_public_rri_csv(csvPath);
W = segment_rri_windows(S, 60, 30);

q = nan(height(W), 1);
coverage = nan(height(W), 1);
nBeats = nan(height(W), 1);
meanNN = nan(height(W), 1);
rmssd = nan(height(W), 1);
riskProxy = nan(height(W), 1);
featureStatus = strings(height(W), 1);

for k = 1:height(W)
    Q = compute_signal_quality(W.rri_ms{k});
    F = extract_hrv_features(W.rri_ms{k}, Q.range_valid_mask);
    q(k) = Q.q;
    coverage(k) = Q.coverage;
    nBeats(k) = F.n_beats;
    meanNN(k) = F.meanNN_ms;
    rmssd(k) = F.RMSSD_ms;
    riskProxy(k) = F.irregularity_index;
    featureStatus(k) = F.status;
end

outTable = table(W.window_id, W.start_sec, W.stop_sec, q, coverage, ...
    nBeats, meanNN, rmssd, riskProxy, featureStatus, ...
    'VariableNames', {'window_id', 'start_sec', 'stop_sec', 'q', 'coverage', ...
    'n_beats', 'meanNN_ms', 'RMSSD_ms', 'risk_proxy', 'feature_status'});

tableDir = fullfile(phase2Root, 'outputs', 'tables');
if ~exist(tableDir, 'dir')
    mkdir(tableDir);
end

outPath = fullfile(tableDir, 'public_rri_window_sanity.csv');
writetable(outTable, outPath);
fprintf('Saved public RRI sanity table: %s\n', outPath);
