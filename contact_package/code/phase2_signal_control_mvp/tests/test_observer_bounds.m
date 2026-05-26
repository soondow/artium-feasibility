T = readtable(fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv'));

assert(all(T.x_hat >= 0 & T.x_hat <= 1), 'x_hat must be bounded in [0, 1]');
assert(all(T.U >= 0 & T.U <= 1), 'U must be bounded in [0, 1]');

O = quality_weighted_observer([0.8; 0.8], [1.0; 0.2], [1.0; 1.0], []);
assert(O.observer_gain(2) < O.observer_gain(1), ...
    'Observer gain must decrease under low signal quality.');

