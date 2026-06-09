% 스크립트 설명:
%   AtriaSeg 케이스 전체에 대해 좌심방 부피만 일괄 계산하고 volume-only 테이블을 저장합니다.
%
% 입력:
%   프로젝트 설정 경로, 내부 함수, 스크립트 안에서 정의한 파라미터를 사용합니다.
%
% 출력:
%   콘솔 처리 로그, 일부 케이스의 오버레이 PNG, 좌심방 부피 CSV를 생성합니다.
%
% 예외:
%   데이터 폴더, NRRD 파일, 메타데이터 필드, 결과 저장 경로 문제에서 발생한 MATLAB 예외가 전파될 수 있습니다.


clear; clc; close all;

thisFile = which(mfilename);
scriptDir = fileparts(thisFile);
repoRoot = fileparts(fileparts(scriptDir));

addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'phase1_anatomy', 'functions'));

P = paths_local();

disp("===repoRoot===")
disp(repoRoot)
disp("===P.dataRaw===")
disp(P.dataRaw)

if ~isfolder(P.dataRaw)
    error('P.dataRaw 폴더 없다: %s', P.dataRaw);
end

d = dir(P.dataRaw);
isSub = [d.isdir];
caseNames = {d(isSub).name};
caseNames = caseNames(~ismember(caseNames, {'.','..'}));
caseNames = sort(caseNames);

if isempty(caseNames)
    error('P.dataRaw에 데이터 안보임.');
end

disp("===batch 대상 케이스===")
disp(caseNames')

nCase = numel(caseNames);

patient_id = strings(nCase,1);
la_volume_ml = nan(nCase,1);

img_size_x = nan(nCase,1);
img_size_y = nan(nCase,1);
img_size_z = nan(nCase,1);

spacing_x = nan(nCase,1);
spacing_y = nan(nCase,1);
spacing_z = nan(nCase,1);

status = strings(nCase,1);
message = strings(nCase,1);

if ~exist(P.outTable, 'dir')
    mkdir(P.outTable);
end

if ~exist(P.outPng, 'dir')
    mkdir(P.outPng);
end

for i = 1:nCase
    caseName = caseNames{i};
    patient_id(i) = string(caseName);

    fprintf('\n[%d/%d] Processing %s ...\n', i, nCase, caseName);

    try
        casePath = fullfile(P.dataRaw, caseName);

        imgPath = fullfile(casePath, 'lgemri.nrrd');
        labPath = fullfile(casePath, 'laendo.nrrd');

        if ~isfile(imgPath)
            error('Mri 파일 없음: %s', imgPath);
        end

        if ~isfile(labPath)
            error('라벨 파일 없음: %s', labPath);
        end
        
        imgInfo = nrrdinfo(imgPath);
        labInfo = nrrdinfo(labPath);

        imgVol = nrrdread(imgPath);
        labVol = nrrdread(labPath);

        sz = size(imgVol);
        img_size_x(i) = sz(1);
        img_size_y(i) = sz(2);
        img_size_z(i) = sz(3);

        if isfield(labInfo, 'PixelDimensions')
            spacing = labInfo.PixelDimensions;
            spacing_x(i) = spacing(1);
            spacing_y(i) = spacing(2);
            spacing_z(i) = spacing(3);
        end

        la_volume_ml(i) = compute_la_volume_nrrd(labVol, labInfo);

        status(i) = "OK";
        message(i) = "";

        if i <= 5
            midSlice = round(size(imgVol,3)/2);
            labMask = labVol > 0;

            f = figure('Visible','off');
            imshow(imgVol(:,:,midSlice), []);
            hold on;
            contour(double(labMask(:,:,midSlice)), [0.5 0.5], 'r', 'LineWidth', 1.5);
            title(['MRI + Label overlay - ', caseName]);

            saveas(f, fullfile(P.outPng, char(caseName + "_overlay_mid.png")));
            close(f);
        end

        fprintf('  -> LA volume = %.2f mL\n', la_volume_ml(i));
    catch ME
        status(i) = "Error";
        message(i) = string(ME.message);
        fprintf('  -> Error: %s\n', ME.message);
    end
end

T = table(patient_id, la_volume_ml, ...
          img_size_x, img_size_y, img_size_z, ...
          spacing_x, spacing_y, spacing_z, ...
          status, message);

outCsv = fullfile(P.outTable, 'x_anat_volume_only.csv');
writetable(T, outCsv);

fprintf('\n저장함: %s\n', outCsv);

disp(T)
