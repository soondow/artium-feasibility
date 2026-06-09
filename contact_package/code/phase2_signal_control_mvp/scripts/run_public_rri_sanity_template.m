% 스크립트 설명:
%   환경 변수로 지정한 공개 RRI CSV를 가져와 Phase 2 특징 추출 가능성을 점검합니다.
%
% 입력:
%   PUBLIC_RRI_CSV 환경 변수에 저장된 외부 ECG/PPG 기반 RRI CSV 경로를 사용합니다.
%
% 출력:
%   public_rri_window_sanity.csv에 윈도우별 품질, HRV 특징, 위험 프록시를 저장합니다.
%
% 예외:
%   CSV 스키마, 파일 경로, 윈도우 분할, 특징 추출, CSV 저장 중 발생한 MATLAB 예외가 전파될 수 있습니다.


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
