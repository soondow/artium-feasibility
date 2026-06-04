function P = paths_local()
    P.repoRoot  = fileparts(fileparts(mfilename('fullpath')));
    P.dataRaw   = fullfile(P.repoRoot, 'data_external', 'atriaseg_raw');
    P.dataNifti = fullfile(P.repoRoot, 'data_external', 'atriaseg_nifti');

    P.phase1Root = fullfile(P.repoRoot, 'phase1_anatomy');
    P.outTable   = fullfile(P.phase1Root, 'outputs', 'tables');
    P.outPng     = fullfile(P.phase1Root, 'outputs', 'preview_png');
end