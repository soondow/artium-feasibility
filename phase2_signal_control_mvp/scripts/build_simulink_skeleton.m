clear; clc;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
run(fullfile(scriptDir, 'build_simulink_testbench.m'));
