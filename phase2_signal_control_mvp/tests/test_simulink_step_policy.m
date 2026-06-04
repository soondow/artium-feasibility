T = readtable(fullfile(phase2Root, 'outputs', 'simulink', 'simulink_step_testbench_log.csv'));

qMin = 0.88;
suspiciousLevel = 0.62;
idx = T.q < qMin & T.risk_proxy > suspiciousLevel;

assert(any(idx), 'Simulink testbench should contain suspicious low-quality input.');
assert(all(T.direct_alert(idx) == 0), ...
    'Simulink testbench violated low-quality direct-alert prohibition.');
assert(any(T.request_confirmation(idx) == 1), ...
    'Simulink testbench should request confirmation under suspicious low-quality input.');

