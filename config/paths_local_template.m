function P = paths_local_template()
%PATHS_LOCAL_TEMPLATE Copy to paths_local.m before rerunning Phase 1.
%
% The contact package excludes raw MRI/label files. Edit P.dataRaw to point
% to a local folder containing case subfolders with lgemri.nrrd and
% laendo.nrrd before running phase1_anatomy scripts.

    thisFile = mfilename('fullpath');
    configDir = fileparts(thisFile);
    P.repoRoot = fileparts(configDir);

    P.dataRaw = fullfile(P.repoRoot, 'data_external', 'atriaseg_raw');
    P.phase1Root = fullfile(P.repoRoot, 'phase1_anatomy');

    P.outTable = fullfile(P.phase1Root, 'outputs', 'tables');
    P.outPng = fullfile(P.phase1Root, 'outputs', 'preview_png');
end
