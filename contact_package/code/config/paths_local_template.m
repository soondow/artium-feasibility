function P = paths_local_template()
%PATHS_LOCAL_TEMPLATE Phase 1을 다시 실행하기 전에 paths_local.m으로 복사한다.
%
% contact package에는 원본 MRI/라벨 파일이 포함되지 않는다. Phase1 스크립트를
% 실행하기 전에 lgemri.nrrd와 laendo.nrrd가 들어 있는 case 하위 폴더를
% 포함한 로컬 폴더를 가리키도록 P.dataRaw를 수정한다.

    thisFile = mfilename('fullpath');
    configDir = fileparts(thisFile);
    P.repoRoot = fileparts(configDir);

    P.dataRaw = fullfile(P.repoRoot, 'data_external', 'atriaseg_raw');
    P.phase1Root = fullfile(P.repoRoot, 'phase1_anatomy');

    P.outTable = fullfile(P.phase1Root, 'outputs', 'tables');
    P.outPng = fullfile(P.phase1Root, 'outputs', 'preview_png');
end
