% 스크립트 설명:
%   Phase 2 윈도우 및 이벤트 산출물을 환자 단위 Model A/B 모니터링 요약으로 변환합니다.
%
% 입력:
%   window_metrics.csv와 baseline_vs_proposed.csv를 사용하며, 없으면 Phase 2 데모를 먼저 실행합니다.
%
% 출력:
%   patient_level_monitoring_summary.csv를 저장하고 요약 테이블을 콘솔에 표시합니다.
%
% 예외:
%   데모 실행, CSV 읽기, 환자 단위 요약 생성, CSV 저장 중 발생한 MATLAB 예외가 전파될 수 있습니다.


clear; clc;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
phase2Root = fileparts(scriptDir);
repoRoot = fileparts(phase2Root);

addpath(fullfile(phase2Root, 'functions'));
addpath(fullfile(repoRoot, 'config'));

tableDir = fullfile(phase2Root, 'outputs', 'tables');
if ~exist(tableDir, 'dir')
    mkdir(tableDir);
end

windowCsv = fullfile(tableDir, 'window_metrics.csv');
eventCsv = fullfile(tableDir, 'baseline_vs_proposed.csv');

if ~isfile(windowCsv) || ~isfile(eventCsv)
    run(fullfile(phase2Root, 'scripts', 'run_phase2_demo.m'));
end

windowMetrics = readtable(windowCsv);
eventMetrics = readtable(eventCsv);
patientSummary = build_patient_level_monitoring_summary(windowMetrics, eventMetrics);

outPath = fullfile(tableDir, 'patient_level_monitoring_summary.csv');
writetable(patientSummary, outPath);

fprintf('Saved patient-level monitoring scaffold: %s\n', outPath);
disp(patientSummary);
