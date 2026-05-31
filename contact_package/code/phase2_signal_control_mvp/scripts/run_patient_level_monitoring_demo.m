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
