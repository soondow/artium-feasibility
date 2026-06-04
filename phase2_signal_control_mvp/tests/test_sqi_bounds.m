T = readtable(fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv'));

assert(all(T.q >= 0 & T.q <= 1), 'q_k must be bounded in [0, 1]');
assert(all(T.coverage >= 0 & T.coverage <= 1), 'coverage c_k must be bounded in [0, 1]');

lowq = T(string(T.scenario) == "low_quality_artifact", :);
lowqMask = logical(lowq.true_low_quality);
assert(mean(lowq.q(lowqMask), 'omitnan') < mean(lowq.q(~lowqMask), 'omitnan'), ...
    'Artifact segment should reduce signal quality.');

missing = T(string(T.scenario) == "missing_burst", :);
missingMask = logical(missing.true_low_quality);
assert(mean(missing.coverage(missingMask), 'omitnan') ...
    < mean(missing.coverage(~missingMask), 'omitnan'), ...
    'Missing burst should reduce coverage.');
