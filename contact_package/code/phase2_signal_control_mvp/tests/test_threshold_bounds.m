T = readtable(fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv'));

P = phase_control_params();
tauMin = P.tauMin;
tauMax = P.tauMax;
maxDeltaTau = 0.15;

tau = T.adaptive_threshold;
assert(all(tau >= tauMin & tau <= tauMax), 'Adaptive threshold out of bounds');

deltaTau = abs(diff(tau));
assert(all(deltaTau <= maxDeltaTau + eps), 'Threshold changes too abruptly');
