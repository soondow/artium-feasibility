phase2Root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(phase2Root, 'functions'));

tmpPath = fullfile(tempdir, 'phase2_public_rri_import_smoke.csv');
t = (0:119)';
rri = 800 + 20 * sin(2 * pi * t / 30);
T = table(t, rri, 'VariableNames', {'time_sec', 'rri_ms'});
writetable(T, tmpPath);

S = import_public_rri_csv(tmpPath, 'ScenarioName', "public_smoke_test");
assert(S.scenario == "public_smoke_test", 'Scenario name was not preserved.');
assert(numel(S.rri_ms) == height(T), 'Imported RRI length mismatch.');
assert(all(S.rri_ms > 0), 'Imported RRI values must be positive.');
assert(all(diff(S.time_sec) >= 0), 'Imported time_sec must be monotonic.');

W = segment_rri_windows(S, 60, 30);
assert(height(W) >= 2, 'Imported public RRI stream should segment into windows.');
