% 스크립트 설명:
%   Case_001의 MRI와 라벨을 읽고 좌심방 부피를 계산해 단일 케이스 파이프라인을 점검합니다.
%
% 입력:
%   프로젝트 설정 경로, 내부 함수, 스크립트 안에서 정의한 파라미터를 사용합니다.
%
% 출력:
%   콘솔 로그, CSV 테이블, 그림, 또는 Simulink 산출물을 생성할 수 있습니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


addpath(fullfile(pwd, 'config'));
P = paths_local();

addpath(fullfile(P.phase1Root, 'functions'));

imgPath = fullfile(P.dataNifti, 'case_001_img.nii.gz');
labPath = fullfile(P.dataNifti, 'case_001_lab.nii.gz');

[img, lab, infoImg, infoLab] = load_case_nifti(imgPath, labPath);

laVol = compute_la_volume(lab, infoLab);

if ~exist(P.outTable, 'dir')
    mkdir(P.outTable);
end

T = table("case_001", laVol, 'VariableNames',{'patiend_id',"la_volume_ml"});
writetable(T, fullfile(P.outTable, 'phase1_case001.csv'));

disp(T)
fprintf('LA volume = %.2f mL\n', laVol);
