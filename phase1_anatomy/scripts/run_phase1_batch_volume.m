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
% AtriaSeg 원자료에는 보조 폴더가 섞일 수 있으므로 실제 case만 남긴다.
% Case_### 규칙을 강제해야 volume-only 결과도 full feature table과 같은 cohort를 사용한다.
caseNames = caseNames(~cellfun('isempty', regexp(caseNames, '^Case_\d{3}$', 'once')));
caseNames = sort(caseNames);

if isempty(caseNames)
    error('P.dataRaw에 데이터 안보임.');
end

disp("===batch 대상 케이스===")
disp(caseNames')

nCase = numel(caseNames);
% split metadata를 함께 저장해 volume-only table도 train/test 구분을 잃지 않게 한다.
% 이후 PHASE1 결과를 보조 covariate로 사용할 때 temporal/data split 혼동을 줄이기 위함이다.
[case_split, source_set, source_id] = lookup_atriaseg_split(repoRoot, caseNames);

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

        % overlay는 volume 계산 검증을 위한 대표 preview만 저장한다.
        % 모든 case 이미지를 저장하면 산출물 크기만 커지고 batch table 검토에는 큰 도움이 없다.
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

T = table(patient_id, case_split, source_set, source_id, la_volume_ml, ...
          img_size_x, img_size_y, img_size_z, ...
          spacing_x, spacing_y, spacing_z, ...
          status, message);

outCsv = fullfile(P.outTable, 'x_anat_volume_only.csv');
writetable(T, outCsv);

fprintf('\n저장함: %s\n', outCsv);

disp(T)

