% 스크립트 설명:
%   로컬 AtriaSeg 원천 데이터에서 첫 번째 케이스를 열어 MRI와 라벨 볼륨을 빠르게 확인합니다.
%
% 입력:
%   프로젝트 설정 경로와 로컬 원천 데이터 폴더를 사용합니다.
%
% 출력:
%   선택한 케이스의 볼륨 크기 로그, 중간 슬라이스 영상, 라벨 오버레이 그림을 표시합니다.
%
% 예외:
%   원천 데이터 폴더, MRI 파일, 라벨 파일, NRRD 읽기 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


clear; clc; close all;

thisFile  = which(mfilename);
scriptDir = fileparts(thisFile);
repoRoot  = fileparts(fileparts(scriptDir));

addpath(fullfile(repoRoot, 'config'));

P = paths_local();

disp("=== repoRoot ===")
disp(repoRoot)
disp("=== P.dataRaw ===")
disp(P.dataRaw)

if ~isfolder(P.dataRaw)
    error('P.dataRaw 폴더가 존재하지 않습니다: %s', P.dataRaw);
end

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

imgInfo = nrrdinfo(imgPath);
labInfo = nrrdinfo(labPath);

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
