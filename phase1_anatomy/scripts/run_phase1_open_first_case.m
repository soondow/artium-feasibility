clear; clc; close all;

% 이 스크립트 자신의 실제 위치를 기준으로 프로젝트 루트 찾기
thisFile  = which(mfilename);
scriptDir = fileparts(thisFile);
repoRoot  = fileparts(fileparts(scriptDir));

% config 폴더 추가
addpath(fullfile(repoRoot, 'config'));

% 경로 구조체 불러오기
P = paths_local();

disp("=== repoRoot ===")
disp(repoRoot)
disp("=== P.dataRaw ===")
disp(P.dataRaw)

% raw 폴더 존재 여부 확인
if ~isfolder(P.dataRaw)
    error('P.dataRaw 폴더가 존재하지 않습니다: %s', P.dataRaw);
end

% raw 폴더 안 하위 폴더(환자 폴더) 찾기
d = dir(P.dataRaw);
isSub = [d.isdir];
names = {d(isSub).name};
names = names(~ismember(names, {'.','..'}));

disp("=== raw 폴더 안 하위 폴더 ===")
disp(names')

if isempty(names)
    error(['P.dataRaw 안에 환자 폴더가 없습니다.' newline ...
           '예상 구조: data_external/atriaseg_raw/Case_001/lgemri.nrrd']);
end

% 첫 번째 환자 폴더 선택
caseName = names{1};
casePath = fullfile(P.dataRaw, caseName);

imgPath = fullfile(casePath, 'lgemri.nrrd');
labPath = fullfile(casePath, 'laendo.nrrd');

if ~isfile(imgPath)
    error('MRI 파일이 없습니다: %s', imgPath);
end

if ~isfile(labPath)
    error('라벨 파일이 없습니다: %s', labPath);
end

% NRRD 메타데이터 읽기
imgInfo = nrrdinfo(imgPath);
labInfo = nrrdinfo(labPath);

% 실제 볼륨 읽기
imgVol = nrrdread(imgPath);
labVol = nrrdread(labPath);

disp("=== Loaded case ===")
disp(caseName)
disp("MRI size:")
disp(size(imgVol))
disp("Label size:")
disp(size(labVol))

labMask = labVol > 0;
midSlice = round(size(imgVol,3)/2);

figure;
imshow(imgVol(:,:,midSlice), []);
title(['MRI middle slice - ', caseName]);

figure;
imshow(imgVol(:,:,midSlice), []);
hold on;
contour(labMask(:,:,midSlice), [0.5 0.5], 'r', 'LineWidth', 1.5);
title(['MRI + Label overlay - ', caseName]);