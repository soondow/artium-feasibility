thisFile = mfilename('fullpath');
testDir = fileparts(thisFile);
phase3Root = fileparts(testDir);
scriptPath = fullfile(phase3Root, 'scripts', 'run_phase3_mspc_demo.m');
txt = fileread(scriptPath);

assert(~contains(txt, 'max(Ws.day0_6) - min(Ws.day0_6)'), ...
    'Phase 3 durationDays must not use the normalized day0_6 plotting axis.');
assert(contains(txt, 'max(Ws.stop_sec) - min(Ws.start_sec)'), ...
    'Phase 3 durationDays must use real start_sec/stop_sec duration.');
